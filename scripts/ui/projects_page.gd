class_name ProjectsPage
extends MarginContainer
## 프로젝트 페이지 (고도 프로젝트 매니저와 같은 배치: 도구 줄 · 목록 · 오른쪽 메뉴)

signal go_to_installs

const SORT_NAMES := ["최근 수정순", "이름순", "추가한 순"]
const DONATE_URL := "https://fund.godotengine.org/"

var _list: VBoxContainer
var _scroll: ScrollContainer
var _search: LineEdit
var _sort: OptionButton
var _empty: CenterContainer
var _empty_title: Label
var _empty_desc: Label
var _dir_dialog: FileDialog
var _new_dialog: NewProjectDialog
var _refresh_queued := false
var _selected := ""

# 오른쪽 메뉴 버튼
var _btn_edit: Button
var _btn_edit_options: MenuButton
var _btn_run: Button
var _btn_rename: Button
var _btn_duplicate: Button
var _btn_tags: Button
var _btn_remove: Button
var _btn_remove_missing: Button


func _ready() -> void:
	add_theme_constant_override("margin_left", 8)
	add_theme_constant_override("margin_right", 8)
	add_theme_constant_override("margin_top", 8)
	add_theme_constant_override("margin_bottom", 8)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	# ── 도구 줄 (고도 프로젝트 매니저 배치): [만들기] [가져오기] [스캔] [필터........] 정렬: [ ] ──
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 4)
	root.add_child(toolbar)
	toolbar.add_child(_tool_button(L.t("만들기"), "plus", L.t("새 프로젝트 만들기"), open_new_project))
	toolbar.add_child(_tool_button(L.t("가져오기"), "load", L.t("기존 프로젝트 폴더 가져오기"), func() -> void:
		_dir_dialog.title = L.t("가져올 고도 프로젝트 폴더 선택")
		_dir_dialog.popup_centered()))
	toolbar.add_child(_tool_button(L.t("스캔"), "search", L.t("폴더 안의 프로젝트를 모두 찾아 추가"), func() -> void:
		_dir_dialog.title = L.t("프로젝트를 찾을 폴더 선택")
		_dir_dialog.popup_centered()))
	_search = LineEdit.new()
	_search.placeholder_text = L.t("프로젝트 필터 (태그는 tag:이름)")
	_search.right_icon = HubIcons.icon("search", 16, false)
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_t: String) -> void: _queue_refresh())
	toolbar.add_child(_search)
	var sort_lbl := HubUI.label(L.t("  정렬:"))
	sort_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toolbar.add_child(sort_lbl)
	_sort = OptionButton.new()
	for n in SORT_NAMES:
		_sort.add_item(n)
	_sort.custom_minimum_size.x = 170
	_sort.select(clampi(int(Hub.settings.get("sort", 0)), 0, SORT_NAMES.size() - 1))
	_sort.focus_mode = Control.FOCUS_NONE
	_sort.item_selected.connect(func(i: int) -> void:
		Hub.settings.sort = i
		Hub.save_settings()
		_queue_refresh())
	toolbar.add_child(_sort)

	# ── 본문: 왼쪽 목록 칸 + 오른쪽 메뉴 ──
	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 6)
	root.add_child(main)
	var list_panel := PanelContainer.new()
	list_panel.theme_type_variation = "ListPanel"
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(list_panel)
	main.add_child(_build_side_menu())

	# 목록
	var body := Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_panel.add_child(body)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	_scroll.add_child(_list)

	_empty = CenterContainer.new()
	_empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 10)
	ev.alignment = BoxContainer.ALIGNMENT_CENTER
	_empty.add_child(ev)
	var big := HubUI.icon_rect(HubIcons.icon("folder", 56), 56, HubTheme.TEXT_DISABLED)
	big.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ev.add_child(big)
	_empty_title = HubUI.label("", "TitleLabel")
	_empty_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ev.add_child(_empty_title)
	_empty_desc = HubUI.label("", "DimLabel")
	_empty_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ev.add_child(_empty_desc)
	body.add_child(_empty)

	_dir_dialog = HubUI.dir_dialog(self, L.t("고도 프로젝트 폴더 선택"), Hub.import_path)

	Hub.projects_changed.connect(_queue_refresh)
	Hub.installs_changed.connect(_queue_refresh)
	Hub.running_changed.connect(_queue_refresh)
	_refresh()


# ─────────────────────────── 오른쪽 메뉴 (고도 프로젝트 매니저와 같은 구성) ───────────────────────────

func _build_side_menu() -> Control:
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 176
	side.add_theme_constant_override("separation", 6)

	# [편집] [v]
	var edit_row := HBoxContainer.new()
	edit_row.add_theme_constant_override("separation", 4)
	side.add_child(edit_row)
	_btn_edit = _side_button(L.t("편집"), "edit", func() -> void: _open(_selected, "", true))
	_btn_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_row.add_child(_btn_edit)
	_btn_edit_options = MenuButton.new()
	_btn_edit_options.flat = false
	_btn_edit_options.icon = HubIcons.icon("collapse")
	_btn_edit_options.tooltip_text = L.t("옵션")
	_btn_edit_options.focus_mode = Control.FOCUS_NONE
	_btn_edit_options.about_to_popup.connect(_fill_edit_options)
	_btn_edit_options.get_popup().id_pressed.connect(_on_edit_option)
	edit_row.add_child(_btn_edit_options)

	_btn_run = _side_button(L.t("실행"), "play", func() -> void: _open(_selected, "", false))
	side.add_child(_btn_run)
	_btn_rename = _side_button(L.t("이름 바꾸기"), "rename", _rename_selected)
	side.add_child(_btn_rename)
	_btn_duplicate = _side_button(L.t("복제"), "duplicate", _duplicate_selected)
	side.add_child(_btn_duplicate)
	_btn_tags = _side_button(L.t("태그 설정"), "tags", _tags_selected)
	side.add_child(_btn_tags)
	_btn_remove = _side_button(L.t("제거"), "trash", _remove_selected)
	side.add_child(_btn_remove)
	_btn_remove_missing = _side_button(L.t("누락된 부분 제거"), "clear", _remove_missing)
	side.add_child(_btn_remove_missing)

	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(fill)
	var donate := _side_button(L.t("기부"), "heart", func() -> void: OS.shell_open(DONATE_URL))
	donate.tooltip_text = L.t("Godot 엔진 개발 후원 (fund.godotengine.org)")
	side.add_child(donate)
	return side


func _tool_button(text: String, icon_name: String, tip: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.icon = HubIcons.icon(icon_name)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_pressed)
	return b


func _side_button(text: String, icon_name: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.icon = HubIcons.icon(icon_name)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_pressed)
	return b


func _update_side_menu() -> void:
	var has := _selected != "" and Hub.find_project(_selected) >= 0
	var valid := has and FileAccess.file_exists(_selected.path_join("project.godot"))
	for b in [_btn_edit, _btn_edit_options, _btn_run, _btn_rename, _btn_duplicate, _btn_tags]:
		b.disabled = not valid
	_btn_remove.disabled = not has
	_btn_remove_missing.disabled = Hub.missing_project_count() == 0


func _fill_edit_options() -> void:
	var pm := _btn_edit_options.get_popup()
	pm.clear()
	pm.add_item(L.t("자세한 로그 모드로 편집 (--verbose)"), 0)
	pm.add_item(L.t("복구 모드로 편집 (--recovery-mode)"), 1)
	var insts := Hub.sorted_installs()
	if not insts.is_empty():
		pm.add_separator(L.t("다른 버전으로 편집"))
		for i in insts.size():
			pm.add_item("Godot " + Hub.install_label(insts[i]), 100 + i)
			pm.set_item_metadata(pm.item_count - 1, insts[i].id)


func _on_edit_option(id: int) -> void:
	match id:
		0:
			_open(_selected, "", true, PackedStringArray(["--verbose"]))
		1:
			HubUI.confirm(self, L.t("복구 모드"), L.t("복구 모드에서는 플러그인·툴 스크립트 같은 코드가 실행되지 않아요.\n프로젝트를 열 때 에디터가 멈추거나 튕길 때 써요.\n\n복구 모드로 열까요?"),
				L.t("열기"), _open.bind(_selected, "", true, PackedStringArray(["--recovery-mode"])))
		_:
			var pm := _btn_edit_options.get_popup()
			_open(_selected, str(pm.get_item_metadata(pm.get_item_index(id))), true)


func _rename_selected() -> void:
	var path := _selected
	var current := str(Hub.project_info(path).name)
	HubUI.prompt(self, L.t("프로젝트 이름 바꾸기"), L.t("새 이름 (폴더 이름은 바뀌지 않아요)"), current, L.t("이름 바꾸기"),
		func(text: String) -> void:
			if text.strip_edges() == "":
				return
			var err := Hub.rename_project(path, text.strip_edges())
			if err != "":
				HubUI.alert(self, L.t("이름 바꾸기"), err))


func _tags_selected() -> void:
	var path := _selected
	var info := Hub.project_info(path)
	var all_tags: Array = []
	for rec in Hub.projects:
		for t in Hub.project_info(rec.path).get("tags", []):
			if not all_tags.has(t):
				all_tags.append(t)
	all_tags.sort()
	var hint := L.t("쉼표로 구분해서 입력해요.")
	if not all_tags.is_empty():
		hint += L.t("\n쓰고 있는 태그: ") + ", ".join(all_tags)
	HubUI.prompt(self, L.t("태그 설정 — ") + str(info.name), hint, ", ".join(info.get("tags", [])), L.t("저장"),
		func(text: String) -> void:
			var err := Hub.set_project_tags(path, Array(text.split(",", false)))
			if err != "":
				HubUI.alert(self, L.t("태그 설정"), err))


func _duplicate_selected() -> void:
	var src := _selected
	var name := str(Hub.project_info(src).name) + L.t(" (복사본)")
	var d := ConfirmationDialog.new()
	d.title = L.t("프로젝트 복제")
	d.ok_button_text = L.t("복제")
	d.cancel_button_text = L.t("취소")
	d.dialog_hide_on_ok = false
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	d.add_child(vb)
	vb.add_child(HubUI.label(L.t("프로젝트 이름"), "SectionLabel"))
	var name_edit := LineEdit.new()
	name_edit.text = name
	vb.add_child(name_edit)
	vb.add_child(HubUI.label(L.t("만들 위치"), "SectionLabel"))
	var loc := LineEdit.new()
	loc.text = src.get_base_dir().replace("/", "\\")
	vb.add_child(loc)
	var preview := HubUI.label("", "DimLabel", 420)
	preview.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	vb.add_child(preview)
	var target := func() -> String:
		return Hub.normalize_path(loc.text).path_join(name_edit.text.strip_edges().validate_filename())
	var update := func(_t: String) -> void:
		preview.text = L.t("복사될 폴더: ") + str(target.call()).replace("/", "\\") + L.t("\n(.godot 캐시 폴더는 복사하지 않아요)")
	name_edit.text_changed.connect(update)
	loc.text_changed.connect(update)
	update.call("")
	d.confirmed.connect(func() -> void:
		var new_name := name_edit.text.strip_edges()
		if new_name == "":
			return
		var err := Hub.duplicate_project(src, target.call(), new_name)
		if err != "":
			HubUI.alert(self, L.t("프로젝트 복제"), err)
		else:
			d.hide())
	d.visibility_changed.connect(func() -> void:
		if not d.visible:
			d.queue_free())
	add_child(d)
	d.popup_centered(Vector2i(460, 0))
	name_edit.call_deferred("grab_focus")
	name_edit.call_deferred("select_all")


func _remove_selected() -> void:
	var path := _selected
	var d := ConfirmationDialog.new()
	d.title = L.t("프로젝트 제거")
	d.ok_button_text = L.t("제거")
	d.cancel_button_text = L.t("취소")
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	d.add_child(vb)
	var msg := HubUI.label(L.t("'%s'을(를) 목록에서 제거할까요?") % Hub.project_info(path).name, "", 420)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(msg)
	var delete_check := CheckBox.new()
	delete_check.text = L.t("프로젝트 폴더 내용도 삭제 (휴지통으로 이동)")
	delete_check.visible = DirAccess.dir_exists_absolute(path)
	vb.add_child(delete_check)
	d.confirmed.connect(func() -> void:
		var err := Hub.erase_project(path, delete_check.button_pressed)
		if err != "":
			HubUI.alert(self, L.t("프로젝트 제거"), err))
	d.visibility_changed.connect(func() -> void:
		if not d.visible:
			d.queue_free())
	add_child(d)
	d.popup_centered(Vector2i(460, 0))


func _remove_missing() -> void:
	var n := Hub.missing_project_count()
	HubUI.confirm(self, L.t("누락된 프로젝트 제거"), L.t("폴더를 찾을 수 없는 프로젝트 %d개를 목록에서 제거할까요?\n프로젝트 파일은 건드리지 않아요.") % n, L.t("제거"),
		func() -> void: Hub.toast.emit(L.t("누락된 프로젝트 %d개를 목록에서 제거했어요") % Hub.remove_missing_projects()))


# ─────────────────────────── 목록 ───────────────────────────

func _fixed(width: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.x = width
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func open_new_project() -> void:
	if _new_dialog == null:
		_new_dialog = NewProjectDialog.new()
		_new_dialog.project_created.connect(func(path: String, install_id: String) -> void:
			_selected = path
			_launch(path, install_id, true))
		add_child(_new_dialog)
	_new_dialog.popup_centered()


func _queue_refresh() -> void:
	if not _refresh_queued:
		_refresh_queued = true
		call_deferred("_refresh")


func _refresh() -> void:
	_refresh_queued = false
	var scroll_pos := _scroll.scroll_vertical
	for c in _list.get_children():
		c.queue_free()
	var items := _sorted_projects()
	if Hub.find_project(_selected) < 0:
		_selected = ""
	for item in items:
		var row := ProjectRow.new()
		row.path = item.rec.path
		row.action.connect(_on_row_action)
		_list.add_child(row)
		row.set_selected(Hub.same_path(row.path, _selected))
	_empty.visible = items.is_empty()
	if Hub.projects.is_empty():
		_empty_title.text = L.t("아직 등록된 프로젝트가 없어요")
		_empty_desc.text = L.t("'가져오기'·'스캔'으로 기존 프로젝트를 추가하거나 '만들기'로 새로 만드세요.\n프로젝트 폴더를 이 창에 끌어다 놓아도 돼요.")
	else:
		_empty_title.text = L.t("검색 결과가 없어요")
		_empty_desc.text = L.t("다른 이름이나 경로로 검색해 보세요.")
	_update_side_menu()
	await get_tree().process_frame
	_scroll.scroll_vertical = scroll_pos


func _sorted_projects() -> Array:
	var q := _search.text.strip_edges().to_lower()
	var tag_q := ""
	if q.begins_with("tag:"):
		tag_q = q.trim_prefix("tag:").strip_edges()
		q = ""
	var arr: Array = []
	for rec in Hub.projects:
		var path: String = rec.get("path", "")
		var info := Hub.project_info(path)
		var name := str(info.get("name", path.get_file()))
		var tags: Array = info.get("tags", [])
		if tag_q != "" and not tags.any(func(t: String) -> bool: return t.contains(tag_q)):
			continue
		if q != "" and not (name.to_lower().contains(q) or path.to_lower().contains(q) or tags.has(q)):
			continue
		arr.append({"rec": rec, "name": name, "mod": Hub.project_modified(path)})
	var mode := _sort.selected
	arr.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var fa := bool(a.rec.get("favorite", false))
		var fb := bool(b.rec.get("favorite", false))
		if fa != fb:
			return fa
		match mode:
			1:
				return str(a.name).naturalnocasecmp_to(str(b.name)) < 0
			2:
				return float(a.rec.get("added", 0)) > float(b.rec.get("added", 0))
		return int(a.mod) > int(b.mod))
	return arr


## 행 위에 마우스가 있는지 직접 계산 (자식 버튼 위에서도 강조가 유지되도록)
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and is_visible_in_tree():
		var pos := get_global_mouse_position()
		var in_scroll := _scroll.get_global_rect().has_point(pos)
		for row in _list.get_children():
			if row is ProjectRow:
				row.set_hover(in_scroll and row.get_global_rect().has_point(pos))


func _select(path: String) -> void:
	_selected = path
	for row in _list.get_children():
		if row is ProjectRow:
			row.set_selected(Hub.same_path(row.path, path))
	_update_side_menu()


func _on_row_action(path: String, what: String, arg: String) -> void:
	match what:
		"select":
			_select(path)
		"open":
			_select(path)
			_open(path, arg, true)
		"run":
			_open(path, arg, false)
		"show":
			OS.shell_show_in_file_manager(ProjectSettings.globalize_path(path.path_join("project.godot")))
		"copy":
			DisplayServer.clipboard_set(path.replace("/", "\\"))
			Hub.toast.emit(L.t("경로를 복사했어요"))
		"remove":
			_select(path)
			_remove_selected()
		"install":
			go_to_installs.emit()


func _open(path: String, install_id: String, editor: bool, extra := PackedStringArray()) -> void:
	if path == "":
		return
	if install_id == "":
		install_id = Hub.get_project(path).get("editor", "")
	var inst := Hub.find_install(install_id)
	if inst.is_empty():
		HubUI.alert(self, L.t("에디터가 없어요"), L.t("이 프로젝트에 지정된 에디터가 없어요.\n'에디터 버전'에서 버전을 고르거나, 설치 페이지에서 에디터를 설치해 주세요."))
		return
	var info := Hub.project_info(path, true)
	if not info.valid:
		HubUI.alert(self, L.t("프로젝트를 찾을 수 없어요"), L.t("project.godot 파일이 없어요:\n") + path)
		return
	var warn := ""
	if editor:
		warn = _version_warning(info, inst)
		if Hub.is_running(path):
			warn = L.t("이 프로젝트는 이미 에디터에서 열려 있는 것 같아요.\n하나 더 열까요?\n\n") + warn
	if warn != "":
		HubUI.confirm(self, L.t("프로젝트 열기"), warn.strip_edges(), L.t("열기"), _launch.bind(path, install_id, editor, extra))
	else:
		_launch(path, install_id, editor, extra)


func _launch(path: String, install_id: String, editor: bool, extra := PackedStringArray()) -> void:
	var err := Hub.open_project(path, install_id, editor, extra)
	if err != "":
		HubUI.alert(self, L.t("실행하지 못했어요"), err)


func _version_warning(info: Dictionary, inst: Dictionary) -> String:
	var pv := str(info.get("version", ""))
	var ev := GodotVersion.parse(inst.get("version", ""))
	var parts := pv.split(".")
	if pv == "" or not ev.valid or not parts[0].is_valid_int():
		return ""
	var ver_text := str(inst.version)
	if parts[0].to_int() != ev.major:
		return L.t("이 프로젝트는 Godot %s용이에요.\nGodot %s(으)로 열면 프로젝트가 변환되어, 원래 버전에서 다시 열 수 없게 될 수 있어요.\n\n먼저 백업해 두는 걸 추천해요. 계속할까요?") % [pv, ver_text]
	if parts.size() > 1 and parts[1].is_valid_int():
		var pmin := parts[1].to_int()
		if ev.minor > pmin:
			return L.t("이 프로젝트는 Godot %s에서 저장됐어요.\nGodot %s(으)로 열고 저장하면 %s에서는 제대로 열리지 않을 수 있어요. 계속할까요?") % [pv, ver_text, pv]
		if ev.minor < pmin:
			return L.t("이 프로젝트는 더 새로운 Godot %s에서 저장됐어요.\n이전 버전(%s)으로 열면 일부 기능이 깨질 수 있어요. 계속할까요?") % [pv, ver_text]
	return ""
