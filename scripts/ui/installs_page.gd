class_name InstallsPage
extends MarginContainer
## 설치 페이지 (고도 프로젝트 매니저의 "에셋 스토어" 탭 자리)

const FILTERS := [["all", "전체"], ["stable", "Stable"], ["pre", "프리릴리스"], ["mono", ".NET"]]

var _filter := "all"
var _list: VBoxContainer
var _empty: CenterContainer
var _file_dialog: FileDialog
var _install_dialog: InstallEditorDialog
var _editor_settings_dialog: EditorSettingsDialog
var _refresh_queued := false
var _selected := ""  # 선택한 에디터 id
var _rows := {}  # id -> 줄
var _side := {}  # 오른쪽 메뉴 버튼


func _ready() -> void:
	add_theme_constant_override("margin_left", 8)
	add_theme_constant_override("margin_right", 8)
	add_theme_constant_override("margin_top", 8)
	add_theme_constant_override("margin_bottom", 8)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	# ── 도구 줄 (프로젝트 페이지와 같은 배치): [에디터 설치] [위치 지정]  ...  전체 · Stable · 프리릴리스 · .NET ──
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 4)
	root.add_child(toolbar)
	var install := Button.new()
	install.text = "에디터 설치"
	install.icon = HubIcons.icon("download")
	install.theme_type_variation = "PrimaryButton"
	install.focus_mode = Control.FOCUS_NONE
	install.pressed.connect(open_install_dialog)
	toolbar.add_child(install)
	var locate := Button.new()
	locate.text = "위치 지정"
	locate.icon = HubIcons.icon("load")
	locate.tooltip_text = "이미 PC에 있는 고도 실행 파일(.exe)을 등록해요"
	locate.focus_mode = Control.FOCUS_NONE
	locate.pressed.connect(func() -> void: _file_dialog.popup_centered())
	toolbar.add_child(locate)
	toolbar.add_child(HubUI.spacer())
	var group := ButtonGroup.new()
	for f in FILTERS:
		var b := Button.new()
		b.text = f[1]
		b.toggle_mode = true
		b.button_group = group
		b.theme_type_variation = "ChipButton"
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.button_pressed = f[0] == _filter
		b.pressed.connect(func() -> void:
			_filter = f[0]
			_refresh())
		toolbar.add_child(b)

	# ── 본문: 왼쪽 목록 칸 + 오른쪽 메뉴 (프로젝트 탭과 같은 배치) ──
	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 6)
	root.add_child(main)
	var list_panel := PanelContainer.new()
	list_panel.theme_type_variation = "ListPanel"
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(list_panel)
	main.add_child(_build_side_menu())
	var body := Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_panel.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_list)

	_empty = CenterContainer.new()
	_empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 10)
	_empty.add_child(ev)
	var big := HubUI.icon_rect(HubIcons.icon("cube", 56), 56, HubTheme.TEXT_DISABLED)
	big.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ev.add_child(big)
	var t := HubUI.label("설치된 에디터가 없어요", "TitleLabel")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ev.add_child(t)
	var d := HubUI.label("'에디터 설치'로 원하는 버전을 받거나,\n'위치 지정'으로 이미 있는 Godot 실행 파일을 등록하세요.", "DimLabel")
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ev.add_child(d)
	body.add_child(_empty)

	_file_dialog = FileDialog.new()
	_file_dialog.title = "Godot 실행 파일 선택"
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.use_native_dialog = true
	_file_dialog.filters = PackedStringArray(["*.exe ; Godot 실행 파일"])
	_file_dialog.file_selected.connect(func(p: String) -> void:
		var err := Hub.register_exe(p)
		if err != "":
			HubUI.alert(self, "등록하지 못했어요", err))
	add_child(_file_dialog)

	Hub.installs_changed.connect(_queue_refresh)
	Hub.projects_changed.connect(_queue_refresh)
	Hub.settings_changed.connect(_queue_refresh)
	Downloads.jobs_changed.connect(_queue_refresh)
	_refresh()


## 에디터 설정 창 열기. 허브 설정의 "에디터 설정 창"에 따라
## 0: 허브 안 설정 창(설정 파일 직접 편집), 1: 고도 에디터의 진짜 설정 창
func open_editor_settings(inst: Dictionary, search := "") -> void:
	if int(Hub.settings.get("editor_settings_mode", 0)) == 0:
		if _editor_settings_dialog == null:
			_editor_settings_dialog = EditorSettingsDialog.new()
			add_child(_editor_settings_dialog)
		var msg := _editor_settings_dialog.open_for(inst)
		if search != "":
			_editor_settings_dialog.set_search(search)
		if msg != "":
			HubUI.alert(self, "에디터 설정", msg)
		return
	var err := SettingsHelper.open(inst)
	if err != "":
		HubUI.alert(self, "에디터 설정", err)
	else:
		Hub.toast.emit("Godot %s 에디터 설정 창을 여는 중..." % Hub.install_label(inst))


func open_install_dialog() -> void:
	if _install_dialog == null:
		_install_dialog = InstallEditorDialog.new()
		add_child(_install_dialog)
	_install_dialog.popup_centered()


func _queue_refresh() -> void:
	if not _refresh_queued:
		_refresh_queued = true
		call_deferred("_refresh")


func _refresh() -> void:
	_refresh_queued = false
	for c in _list.get_children():
		c.queue_free()
	_rows.clear()
	if Hub.find_install(_selected).is_empty():
		_selected = ""
	var shown := 0
	for inst in Hub.sorted_installs():
		var stable := GodotVersion.is_stable(inst.get("version", ""))
		var mono := bool(inst.get("mono", false))
		match _filter:
			"stable":
				if not stable:
					continue
			"pre":
				if stable:
					continue
			"mono":
				if not mono:
					continue
		var row := _build_row(inst)
		_list.add_child(row)
		_rows[inst.id] = row
		shown += 1
	_empty.visible = Hub.installs.is_empty()
	if shown == 0 and not Hub.installs.is_empty():
		var l := HubUI.label("이 조건에 맞는 에디터가 없어요.", "DimLabel")
		_list.add_child(l)
	_select(_selected)


# ─────────────────────────── 목록 줄 (고도 프로젝트 매니저 줄 모양) ───────────────────────────

func _build_row(inst: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.theme_type_variation = "PmRow"
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hb)
	var exists := FileAccess.file_exists(str(inst.get("exe", "")))
	var mono := bool(inst.get("mono", false))
	var is_default: bool = Hub.settings.get("default_editor", "") == inst.id

	# ☆ = 기본 버전 (프로젝트 탭의 즐겨찾기 자리)
	var star := HubUI.flat_icon_button("star_fill" if is_default else "star", "기본 버전" if is_default else "기본 버전으로 설정")
	star.custom_minimum_size = Vector2(26, 26)
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if is_default:
		for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
			star.add_theme_color_override(c, HubTheme.WARNING)
	star.pressed.connect(func() -> void: Hub.set_default_install(inst.id))
	hb.add_child(star)

	var icon := HubUI.icon_rect(HubIcons.icon("logo", 56), 56)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not exists:
		icon.modulate = Color(1, 1, 1, 0.35)
	hb.add_child(icon)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 10)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(title_row)
	var version := str(inst.get("version", ""))
	var name_lbl := HubUI.label("Godot " + (version if version != "" else "(버전 알 수 없음)"), "TitleLabel")
	if not exists:
		name_lbl.add_theme_color_override("font_color", HubTheme.TEXT_DISABLED)
	title_row.add_child(name_lbl)
	if mono:
		title_row.add_child(HubUI.tag(".NET", HubTheme.DOTNET))
	if version != "" and not GodotVersion.is_stable(version):
		title_row.add_child(HubUI.tag("프리릴리스", HubTheme.WARNING))
	if is_default:
		title_row.add_child(HubUI.tag("기본", HubTheme.ACCENT))
	if not exists:
		title_row.add_child(HubUI.tag("파일 없음", HubTheme.ERROR))

	# 둘째 줄: 개발자 · 종류 ... 받은 날짜 (매니저의 경로 · 수정 시각 자리)
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 8)
	info_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(info_row)
	var cube := HubUI.icon_rect(HubIcons.icon("cube"), 16, HubTheme.TEXT_DIM)
	cube.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_row.add_child(cube)
	var dev := HubUI.label("Godot Engine  ·  " + (".NET" if mono else "표준"), "DimLabel")
	dev.add_theme_font_size_override("font_size", 13)
	dev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(dev)
	var added := Hub.install_added(inst)
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	var date_text := Time.get_datetime_string_from_unix_time(added + bias * 60, true) if added > 0 else "날짜 모름"
	var date := HubUI.label(date_text, "DimLabel", ProjectRow.DATE_WIDTH)
	date.add_theme_font_size_override("font_size", 13)
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_row.add_child(date)

	# 마우스: 올리면 강조, 클릭 선택, 두 번 클릭 속성, 오른쪽 클릭 메뉴
	var id: String = inst.id
	row.mouse_entered.connect(func() -> void: _style_row(id, true))
	row.mouse_exited.connect(func() -> void: _style_row(id, false))
	row.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
				_select(id)
				_show_properties(inst)
			elif event.button_index == MOUSE_BUTTON_LEFT:
				_select(id)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_select(id)
				_popup_menu(inst))
	return row


func _style_row(id: String, hover: bool) -> void:
	var row: Control = _rows.get(id)
	if row == null or not is_instance_valid(row):
		return
	row.set_meta("hover", hover)
	if id == _selected:
		row.theme_type_variation = "PmRowSelected"
	else:
		row.theme_type_variation = "PmRowHover" if hover else "PmRow"


func _select(id: String) -> void:
	_selected = id
	for k in _rows:
		_style_row(k, bool(_rows[k].get_meta("hover", false)))
	_update_side_menu()


func _popup_menu(inst: Dictionary) -> void:
	var pm := PopupMenu.new()
	pm.add_icon_item(HubIcons.icon("gear"), "에디터 설정 열기", 0)
	pm.add_icon_item(HubIcons.icon("star"), "기본 버전으로 설정", 1)
	pm.set_item_disabled(pm.get_item_index(1), Hub.settings.get("default_editor", "") == inst.id)
	pm.add_check_item("독립 모드 (설정을 이 버전 폴더에 따로 저장)", 2)
	pm.set_item_checked(pm.get_item_index(2), Hub.is_self_contained(inst))
	pm.add_separator()
	pm.add_icon_item(HubIcons.icon("folder"), "설치 폴더 열기", 4)
	pm.add_icon_item(HubIcons.icon("more"), "속성", 6)
	pm.add_separator()
	pm.add_icon_item(HubIcons.icon("trash"), "제거" if inst.get("managed", false) else "목록에서 제거", 5)
	pm.id_pressed.connect(_on_menu.bind(inst))
	pm.popup_hide.connect(pm.queue_free)
	add_child(pm)
	pm.popup(Rect2i(Vector2i(DisplayServer.mouse_get_position()), Vector2i.ZERO))


# ─────────────────────────── 오른쪽 메뉴 ───────────────────────────

func _build_side_menu() -> Control:
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 176
	side.add_theme_constant_override("separation", 6)
	_side.settings = _side_button(side, "에디터 설정", "gear", 0)
	_side.default = _side_button(side, "기본 버전으로", "star", 1)
	_side.sc = _side_button(side, "독립 모드", "check", 2)
	_side.sc.tooltip_text = "에디터 설정을 이 버전 폴더 안에 따로 저장해요 (._sc_)"
	_side.folder = _side_button(side, "설치 폴더 열기", "folder", 4)
	_side.props = _side_button(side, "속성", "more", 6)
	_side.remove = _side_button(side, "제거", "trash", 5)
	return side


func _side_button(parent: Control, text: String, icon_name: String, menu_id: int) -> Button:
	var b := Button.new()
	b.text = text
	b.icon = HubIcons.icon(icon_name)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void:
		var inst := Hub.find_install(_selected)
		if not inst.is_empty():
			_on_menu(menu_id, inst))
	parent.add_child(b)
	return b


func _update_side_menu() -> void:
	if _side.is_empty():
		return
	var inst := Hub.find_install(_selected)
	var has := not inst.is_empty()
	var exists := has and FileAccess.file_exists(str(inst.get("exe", "")))
	for k in _side:
		_side[k].disabled = not has
	_side.settings.disabled = not exists
	_side.folder.disabled = not exists
	_side.sc.disabled = not exists
	_side.default.disabled = not has or Hub.settings.get("default_editor", "") == _selected
	var sc: bool = has and Hub.is_self_contained(inst)
	_side.sc.text = "독립 모드: 켜짐" if sc else "독립 모드: 꺼짐"
	_side.sc.icon = HubIcons.icon("check" if sc else "close")
	_side.remove.text = "제거" if not has or inst.get("managed", false) else "목록에서 제거"


func _on_menu(id: int, inst: Dictionary) -> void:
	match id:
		0:
			open_editor_settings(inst)
		1:
			Hub.set_default_install(inst.id)
		2:
			Hub.set_self_contained(inst, not Hub.is_self_contained(inst))
		4:
			OS.shell_show_in_file_manager(ProjectSettings.globalize_path(str(inst.get("exe", ""))))
		5:
			_confirm_remove(inst)
		6:
			_show_properties(inst)


## 에디터 속성 창: 버전 · 종류 · 받은 날짜 · 경로 · 크기 · 쓰는 프로젝트
func _show_properties(inst: Dictionary) -> void:
	var d := AcceptDialog.new()
	d.title = "속성 — Godot " + Hub.install_label(inst)
	d.ok_button_text = "닫기"
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	d.add_child(grid)
	var exe := str(inst.get("exe", ""))
	var added := Hub.install_added(inst)
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	var names: Array = []
	for rec in Hub.projects:
		if rec.get("editor", "") == inst.id:
			names.append(str(Hub.project_info(rec.path).name))
	var rows := [
		["버전", "Godot " + str(inst.get("version", "?"))],
		["종류", ".NET (C#)" if inst.get("mono", false) else "표준"],
		["개발자", "Godot Engine"],
		["받은 날짜", Time.get_datetime_string_from_unix_time(added + bias * 60, true) if added > 0 else "모름"],
		["설치 방식", "허브에서 설치" if inst.get("managed", false) else "직접 등록"],
		["기본 버전", "예" if Hub.settings.get("default_editor", "") == inst.id else "아니요"],
		["독립 모드", "켜짐 (설정을 이 폴더에 따로 저장)" if Hub.is_self_contained(inst) else "꺼짐"],
		["폴더 크기", HubUI.human_size(_dir_size(exe.get_base_dir())) if FileAccess.file_exists(exe) else "파일 없음"],
		["쓰는 프로젝트", ("%d개: %s" % [names.size(), ", ".join(names)]) if not names.is_empty() else "없음"],
	]
	for r in rows:
		var k := HubUI.label(r[0], "DimLabel")
		k.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		grid.add_child(k)
		var v := HubUI.label(r[1], "", 380)
		v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grid.add_child(v)
	grid.add_child(HubUI.label("실행 파일", "DimLabel"))
	var path_row := HBoxContainer.new()
	var path_edit := LineEdit.new()
	path_edit.text = exe.replace("/", "\\")
	path_edit.editable = false
	path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_row.add_child(path_edit)
	var copy := HubUI.flat_icon_button("copy", "경로 복사")
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(path_edit.text)
		Hub.toast.emit("경로를 복사했어요"))
	path_row.add_child(copy)
	grid.add_child(path_row)
	d.visibility_changed.connect(func() -> void:
		if not d.visible:
			d.queue_free())
	add_child(d)
	d.popup_centered(Vector2i(560, 0))


static func _dir_size(dir: String) -> int:
	var total := 0
	for f in DirAccess.get_files_at(dir):
		var fa := FileAccess.open(dir.path_join(f), FileAccess.READ)
		if fa:
			total += fa.get_length()
	for sub in DirAccess.get_directories_at(dir):
		total += _dir_size(dir.path_join(sub))
	return total


func _confirm_remove(inst: Dictionary) -> void:
	var label := Hub.install_label(inst)
	var used := Hub.projects_using(inst.id)
	var note := ("\n\n이 버전을 쓰는 프로젝트 %d개는 에디터를 다시 골라야 해요." % used) if used > 0 else ""
	if inst.get("managed", false):
		HubUI.confirm(self, "에디터 제거", "Godot %s 을(를) 제거할까요?\n설치 폴더를 휴지통으로 옮겨요.\n%s%s" % [label, str(inst.path).replace("/", "\\"), note],
			"제거", _do_remove.bind(inst.id, true))
	else:
		HubUI.confirm(self, "목록에서 제거", "Godot %s 을(를) 목록에서 제거할까요?\n직접 등록한 에디터라 파일은 그대로 둬요.%s" % [label, note],
			"제거", _do_remove.bind(inst.id, false))


func _do_remove(id: String, delete_files: bool) -> void:
	var err := Hub.remove_install(id, delete_files)
	if err != "":
		HubUI.alert(self, "제거하지 못했어요", err)
