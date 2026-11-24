class_name AssetStorePage
extends MarginContainer
## 에셋 스토어 탭: 고도 에셋 라이브러리(godotengine.org/asset-library)의 프로젝트 · 템플릿 · 데모를
## 고도 프로젝트 매니저의 "에셋 스토어" 탭처럼 찾아보고, 받아서 새 프로젝트로 추가한다.

const API := "https://godotengine.org/asset-library/api"
const PAGE_SIZE := 40
const ICON_SIZE := 64
const SORTS := [["updated", "최근 업데이트"], ["name", "이름순"], ["rating", "평점순"], ["cost", "라이선스순"]]

var _search: LineEdit
var _sort: OptionButton
var _category: OptionButton
var _version: OptionButton
var _grid: GridContainer
var _scroll: ScrollContainer
var _status: Label
var _retry: Button
var _prev: Button
var _next: Button
var _page_label: Label
var _page := 0
var _pages := 1
var _search_timer: Timer
var _list_req: HTTPRequest
var _icon_cache := {}  # url -> Texture2D (null = 실패)
var _icon_waiting := {}  # url -> [TextureRect]
var _icon_queue: Array = []
var _icon_busy := 0
var _loaded := false


func _ready() -> void:
	add_theme_constant_override("margin_left", 8)
	add_theme_constant_override("margin_right", 8)
	add_theme_constant_override("margin_top", 8)
	add_theme_constant_override("margin_bottom", 8)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	# ── 도구 줄: [검색........] 정렬 [ ] 분류 [ ] 버전 [ ] ──
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 6)
	root.add_child(toolbar)
	_search = LineEdit.new()
	_search.placeholder_text = L.t("템플릿 · 프로젝트 · 데모 검색")
	_search.right_icon = HubIcons.icon("search", 16, false)
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_t: String) -> void: _search_timer.start())
	toolbar.add_child(_search)
	_sort = _option(toolbar, L.t("정렬:"))
	for s in SORTS:
		_sort.add_item(L.t(s[1]))
	_category = _option(toolbar, L.t("분류:"))
	_category.add_item(L.t("전체"))
	_category.set_item_metadata(0, "")
	_version = _option(toolbar, L.t("Godot 버전:"))
	_fill_versions()

	_search_timer = Timer.new()
	_search_timer.one_shot = true
	_search_timer.wait_time = 0.4
	_search_timer.timeout.connect(func() -> void:
		_page = 0
		_request_list())
	add_child(_search_timer)

	# ── 목록 (카드 두 줄) ──
	var list_panel := PanelContainer.new()
	list_panel.theme_type_variation = "ListPanel"
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(list_panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_panel.add_child(_scroll)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(vb)
	_status = HubUI.label("", "DimLabel")
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_status)
	# 목록을 못 불러왔을 때 다시 시도
	_retry = Button.new()
	_retry.text = L.t("목록 새로고침")
	_retry.icon = HubIcons.icon("refresh")
	_retry.focus_mode = Control.FOCUS_NONE
	_retry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_retry.visible = false
	_retry.pressed.connect(func() -> void:
		if _category.item_count <= 1:
			_request_categories()
		_request_list())
	vb.add_child(_retry)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	vb.add_child(_grid)

	# ── 페이지 넘기기 ──
	var pager := HBoxContainer.new()
	pager.alignment = BoxContainer.ALIGNMENT_CENTER
	pager.add_theme_constant_override("separation", 10)
	root.add_child(pager)
	_prev = Button.new()
	_prev.text = L.t("이전")
	_prev.focus_mode = Control.FOCUS_NONE
	_prev.pressed.connect(func() -> void:
		_page = maxi(0, _page - 1)
		_request_list())
	pager.add_child(_prev)
	_page_label = HubUI.label("", "DimLabel")
	pager.add_child(_page_label)
	_next = Button.new()
	_next.text = L.t("다음")
	_next.focus_mode = Control.FOCUS_NONE
	_next.pressed.connect(func() -> void:
		_page = mini(_pages - 1, _page + 1)
		_request_list())
	pager.add_child(_next)

	_list_req = HTTPRequest.new()
	_list_req.timeout = 20
	_list_req.request_completed.connect(_on_list)
	add_child(_list_req)
	resized.connect(func() -> void: _grid.columns = 2 if size.x > 820 else 1)
	visibility_changed.connect(_on_shown)
	Hub.installs_changed.connect(_fill_versions)
	_on_shown.call_deferred()  # 처음부터 이 탭으로 열린 경우


func _option(parent: Control, label: String) -> OptionButton:
	var l := HubUI.label(label)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(l)
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	opt.item_selected.connect(func(_i: int) -> void:
		_page = 0
		_request_list())
	parent.add_child(opt)
	return opt


## 설치된 에디터 버전(주.부)으로 거른다. 처음에는 가장 새 버전
func _fill_versions() -> void:
	var keep := str(_version.get_item_metadata(_version.selected)) if _version.item_count > 0 else ""
	_version.clear()
	var seen := {}
	for inst in Hub.sorted_installs():
		var v := GodotVersion.parse(inst.get("version", ""))
		if not v.valid or v.major < 3:
			continue
		var mm := "%d.%d" % [v.major, v.minor]
		if not seen.has(mm):
			seen[mm] = true
			_version.add_item(mm)
			_version.set_item_metadata(_version.item_count - 1, mm)
	_version.add_item(L.t("모든 버전"))
	_version.set_item_metadata(_version.item_count - 1, "")
	_version.select(0)
	for i in _version.item_count:
		if keep != "" and str(_version.get_item_metadata(i)) == keep:
			_version.select(i)


func _on_shown() -> void:
	if is_visible_in_tree() and not _loaded:
		_loaded = true
		_request_categories()
		_request_list()
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--hub-asset="):  # 개발용: 이 에셋의 자세히 보기 창을 바로 연다
				_open_detail(arg.trim_prefix("--hub-asset="))


# ─────────────────────────── 목록 ───────────────────────────

func _request_categories() -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		req.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			return
		var data: Variant = JSON.parse_string(body.get_string_from_utf8())
		if data is Dictionary:
			for c in data.get("categories", []):
				_category.add_item(str(c.get("name", "")))
				_category.set_item_metadata(_category.item_count - 1, str(c.get("id", ""))))
	req.request(API + "/configure?type=project", _headers())


func _request_list() -> void:
	_list_req.cancel_request()
	var q := PackedStringArray(["type=project", "max_results=%d" % PAGE_SIZE, "page=%d" % _page,
		"sort=" + SORTS[_sort.selected][0]])
	if _search.text.strip_edges() != "":
		q.append("filter=" + _search.text.strip_edges().uri_encode())
	var cat := str(_category.get_item_metadata(_category.selected)) if _category.item_count > 0 else ""
	if cat != "":
		q.append("category=" + cat)
	var ver := str(_version.get_item_metadata(_version.selected)) if _version.item_count > 0 else ""
	if ver != "":
		q.append("godot_version=" + ver)
	_status.text = L.t("불러오는 중...")
	_status.visible = true
	_retry.visible = false
	_prev.disabled = true
	_next.disabled = true
	var err := _list_req.request(API + "/asset?" + "&".join(q), _headers())
	if err != OK:
		_status.text = L.t("요청을 보내지 못했어요 (%s)") % error_string(err)


func _on_list(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	for c in _grid.get_children():
		c.queue_free()
	var data: Variant = JSON.parse_string(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS and code == 200 else null
	if not (data is Dictionary):
		_status.text = L.t("에셋 목록을 불러오지 못했어요. 인터넷 연결을 확인해 주세요.")
		_status.visible = true
		_retry.visible = true
		return
	var items: Array = data.get("result", [])
	_pages = maxi(1, int(data.get("pages", 1)))
	_page_label.text = "%d / %d" % [_page + 1, _pages]
	_prev.disabled = _page <= 0
	_next.disabled = _page >= _pages - 1
	_status.visible = items.is_empty()
	_status.text = L.t("조건에 맞는 에셋이 없어요.")
	for a in items:
		_grid.add_child(_build_card(a))
	_scroll.scroll_vertical = 0


func _build_card(a: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = "PmRow"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.mouse_entered.connect(func() -> void: card.theme_type_variation = "PmRowHover")
	card.mouse_exited.connect(func() -> void: card.theme_type_variation = "PmRow")
	card.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_open_detail(str(a.get("asset_id", ""))))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hb)
	var icon := _icon_rect(str(a.get("icon_url", "")), ICON_SIZE)
	hb.add_child(icon)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)
	var title := HubUI.label(str(a.get("title", "")), "TitleLabel")
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	vb.add_child(title)
	var cat := HubUI.label("%s  ·  %s" % [a.get("category", ""), a.get("author", "")], "DimLabel")
	cat.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cat.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	vb.add_child(cat)
	var meta := HubUI.label("Godot %s  ·  %s  ·  %s" % [a.get("godot_version", "?"), a.get("cost", ""), a.get("version_string", "")], "DimLabel")
	meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	meta.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	vb.add_child(meta)
	return card


# ─────────────────────────── 아이콘 (한 번에 몇 개씩만 받는다) ───────────────────────────

func _icon_rect(url: String, px: int) -> TextureRect:
	var r := TextureRect.new()
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.texture = HubIcons.icon("logo", px)
	if url == "":
		return r
	if _icon_cache.has(url):
		if _icon_cache[url]:
			r.texture = _icon_cache[url]
		return r
	if not _icon_waiting.has(url):
		_icon_waiting[url] = []
		_icon_queue.append(url)
	_icon_waiting[url].append(r)
	_pump_icons()
	return r


func _pump_icons() -> void:
	while _icon_busy < 4 and not _icon_queue.is_empty():
		var url: String = _icon_queue.pop_front()
		_icon_busy += 1
		var req := HTTPRequest.new()
		req.timeout = 15
		add_child(req)
		req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
			req.queue_free()
			_icon_busy -= 1
			var tex: Texture2D = null
			if result == HTTPRequest.RESULT_SUCCESS and code == 200:
				tex = _decode_image(body)
			_icon_cache[url] = tex
			for r in _icon_waiting.get(url, []):
				if is_instance_valid(r) and tex:
					r.texture = tex
			_icon_waiting.erase(url)
			_pump_icons())
		if req.request(url, _headers()) != OK:
			req.queue_free()
			_icon_busy -= 1
			_icon_cache[url] = null


static func _decode_image(body: PackedByteArray) -> Texture2D:
	if body.size() < 8:
		return null
	var img := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if body[0] == 0x89 and body[1] == 0x50:
		err = img.load_png_from_buffer(body)
	elif body[0] == 0xFF and body[1] == 0xD8:
		err = img.load_jpg_from_buffer(body)
	elif body.slice(0, 4).get_string_from_ascii() == "RIFF":
		err = img.load_webp_from_buffer(body)
	elif body.slice(0, 256).get_string_from_utf8().contains("<svg"):
		err = img.load_svg_from_buffer(body)
	if err != OK:
		return null
	if img.get_width() > 256 or img.get_height() > 256:
		img.resize(128, int(128.0 * img.get_height() / maxi(1, img.get_width())), Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


static func _headers() -> PackedStringArray:
	return PackedStringArray(["User-Agent: GodotHub-Launcher", "Accept: application/json"])


# ─────────────────────────── 자세히 보기 · 받기 ───────────────────────────

func _open_detail(id: String) -> void:
	var req := HTTPRequest.new()
	req.timeout = 20
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		req.queue_free()
		var data: Variant = JSON.parse_string(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS and code == 200 else null
		if not (data is Dictionary):
			HubUI.alert(self, L.t("에셋 스토어"), L.t("에셋 정보를 불러오지 못했어요."))
			return
		_show_detail(data))
	req.request(API + "/asset/" + id, _headers())
	Hub.toast.emit(L.t("불러오는 중..."))


func _show_detail(a: Dictionary) -> void:
	var d := ConfirmationDialog.new()
	d.title = str(a.get("title", ""))
	d.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	d.ok_button_text = L.t("받아서 프로젝트로 추가")
	d.cancel_button_text = L.t("닫기")
	d.add_button(L.t("웹에서 보기"), false, "web")
	d.custom_action.connect(func(_x: StringName) -> void:
		var url := str(a.get("browse_url", ""))
		if url == "":
			url = "https://godotengine.org/asset-library/asset/" + str(a.get("asset_id", ""))
		OS.shell_open(url))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	d.add_child(vb)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	vb.add_child(top)
	top.add_child(_icon_rect(str(a.get("icon_url", "")), 96))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info)
	var t := HubUI.label(str(a.get("title", "")), "TitleLabel")
	t.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	info.add_child(t)
	for line in [
		"%s: %s" % [L.t("만든 사람"), a.get("author", "")],
		"%s: %s  ·  %s: %s" % [L.t("분류"), a.get("category", ""), L.t("버전"), a.get("version_string", "")],
		"Godot %s  ·  %s: %s" % [a.get("godot_version", "?"), L.t("라이선스"), a.get("cost", "")],
	]:
		var l := HubUI.label(line, "DimLabel")
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		info.add_child(l)
	var desc := RichTextLabel.new()
	desc.text = str(a.get("description", "")).replace("\r", "")
	desc.fit_content = false
	desc.selection_enabled = true
	desc.custom_minimum_size = Vector2(620, 260)
	desc.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	vb.add_child(desc)
	d.confirmed.connect(func() -> void: _ask_location(a))
	d.visibility_changed.connect(func() -> void:
		if not d.visible:
			d.queue_free())
	add_child(d)
	d.popup_centered()


## 어디에 어떤 이름으로 만들지 묻고 받기 시작
func _ask_location(a: Dictionary) -> void:
	var d := ConfirmationDialog.new()
	d.title = L.t("프로젝트로 추가")
	d.ok_button_text = L.t("받기")
	d.cancel_button_text = L.t("취소")
	d.dialog_hide_on_ok = false
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	d.add_child(vb)
	vb.add_child(HubUI.label(L.t("프로젝트 이름"), "SectionLabel"))
	var name_edit := LineEdit.new()
	name_edit.text = str(a.get("title", "project")).validate_filename()
	vb.add_child(name_edit)
	vb.add_child(HubUI.label(L.t("위치"), "SectionLabel"))
	var row := HBoxContainer.new()
	vb.add_child(row)
	var loc := LineEdit.new()
	loc.text = str(Hub.settings.get("project_dir", "")).replace("/", "\\")
	loc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(loc)
	var browse := Button.new()
	browse.icon = HubIcons.icon("load")
	browse.focus_mode = Control.FOCUS_NONE
	row.add_child(browse)
	var dir_dialog := HubUI.dir_dialog(d, L.t("폴더 선택"), func(dir: String) -> void: loc.text = Hub.normalize_path(dir).replace("/", "\\"))
	browse.pressed.connect(func() -> void: dir_dialog.popup_centered())
	var preview := HubUI.label("", "DimLabel", 460)
	preview.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	vb.add_child(preview)
	var target := func() -> String:
		return Hub.normalize_path(loc.text).path_join(name_edit.text.strip_edges().validate_filename())
	var update := func(_t: String) -> void:
		preview.text = L.t("만들어질 폴더: ") + str(target.call()).replace("/", "\\")
	name_edit.text_changed.connect(update)
	loc.text_changed.connect(update)
	update.call("")
	d.confirmed.connect(func() -> void:
		var dest: String = target.call()
		if name_edit.text.strip_edges() == "":
			HubUI.alert(d, L.t("프로젝트로 추가"), L.t("프로젝트 이름을 입력해 주세요."))
			return
		if DirAccess.dir_exists_absolute(dest) and not (DirAccess.get_files_at(dest).is_empty() and DirAccess.get_directories_at(dest).is_empty()):
			HubUI.alert(d, L.t("프로젝트로 추가"), L.t("같은 이름의 폴더가 이미 있고 비어 있지 않아요."))
			return
		Downloads.install_asset(a, dest)
		Hub.toast.emit(L.t("%s 받는 중...") % str(a.get("title", "")))
		d.hide())
	d.visibility_changed.connect(func() -> void:
		if not d.visible:
			d.queue_free())
	add_child(d)
	d.popup_centered(Vector2i(500, 0))
	name_edit.call_deferred("grab_focus")
