class_name InstallsPage
extends MarginContainer
## 설치 페이지 (유니티 허브의 Installs 화면 배치)

const FILTERS := [["all", "전체"], ["stable", "Stable"], ["pre", "프리릴리스"], ["mono", ".NET"]]

var _filter := "all"
var _list: VBoxContainer
var _empty: CenterContainer
var _file_dialog: FileDialog
var _install_dialog: InstallEditorDialog
var _editor_settings_dialog: EditorSettingsDialog
var _refresh_queued := false


func _ready() -> void:
	add_theme_constant_override("margin_left", 28)
	add_theme_constant_override("margin_right", 28)
	add_theme_constant_override("margin_top", 22)
	add_theme_constant_override("margin_bottom", 16)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)
	header.add_child(HubUI.label("설치", "HeaderLabel"))
	header.add_child(HubUI.spacer())
	var locate := Button.new()
	locate.text = "위치 지정"
	locate.icon = HubIcons.icon("load")
	locate.tooltip_text = "이미 PC에 있는 고도 실행 파일(.exe)을 등록해요"
	locate.focus_mode = Control.FOCUS_NONE
	locate.pressed.connect(func() -> void: _file_dialog.popup_centered())
	header.add_child(locate)
	var install := Button.new()
	install.text = "에디터 설치"
	install.icon = HubIcons.icon("download")
	install.theme_type_variation = "PrimaryButton"
	install.focus_mode = Control.FOCUS_NONE
	install.pressed.connect(open_install_dialog)
	header.add_child(install)

	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	root.add_child(chips)
	var group := ButtonGroup.new()
	for f in FILTERS:
		var b := Button.new()
		b.text = f[1]
		b.toggle_mode = true
		b.button_group = group
		b.theme_type_variation = "ChipButton"
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = f[0] == _filter
		b.pressed.connect(func() -> void:
			_filter = f[0]
			_refresh())
		chips.add_child(b)

	var body := Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
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
		_list.add_child(_build_row(inst))
		shown += 1
	_empty.visible = Hub.installs.is_empty()
	if shown == 0 and not Hub.installs.is_empty():
		var l := HubUI.label("이 조건에 맞는 에디터가 없어요.", "DimLabel")
		_list.add_child(l)


func _build_row(inst: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.theme_type_variation = "RowPanel"
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	row.add_child(hb)
	var exists := FileAccess.file_exists(str(inst.get("exe", "")))
	var mono := bool(inst.get("mono", false))
	hb.add_child(HubUI.icon_rect(HubIcons.icon("logo", 34), 34))

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 2)
	hb.add_child(vb)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	vb.add_child(title_row)
	var version := str(inst.get("version", ""))
	title_row.add_child(HubUI.label("Godot " + (version if version != "" else "(버전 알 수 없음)"), "TitleLabel"))
	if mono:
		title_row.add_child(HubUI.tag(".NET", HubTheme.DOTNET))
	if version != "" and not GodotVersion.is_stable(version):
		title_row.add_child(HubUI.tag("프리릴리스", HubTheme.WARNING))
	if Hub.settings.get("default_editor", "") == inst.id:
		title_row.add_child(HubUI.tag("기본", HubTheme.ACCENT))
	if not exists:
		title_row.add_child(HubUI.tag("파일 없음", HubTheme.ERROR))
	# 화면에는 짧게 한 줄만, 자세한 내용(경로 · 종류 · 독립 모드)은 마우스를 올리면 보여 준다
	var used := Hub.projects_using(inst.id)
	vb.add_child(HubUI.label("프로젝트 %d개" % used if used > 0 else "사용하는 프로젝트 없음", "DimLabel"))
	var details: Array = [".NET" if mono else "표준"]
	if Hub.is_self_contained(inst):
		details.append("독립 모드")
	if not inst.get("managed", false):
		details.append("직접 등록")
	row.tooltip_text = "%s\n%s" % [str(inst.get("exe", "")).replace("/", "\\"), "  ·  ".join(details)]
	row.custom_minimum_size.y = 72  # 글자를 줄여도 줄 높이는 그대로
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var gear := MenuButton.new()
	gear.icon = HubIcons.icon("gear")
	gear.theme_type_variation = "FlatButton"
	gear.flat = false
	gear.focus_mode = Control.FOCUS_NONE
	gear.tooltip_text = "관리"
	gear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pm := gear.get_popup()
	pm.add_icon_item(HubIcons.icon("gear"), "에디터 설정 열기", 0)
	pm.add_icon_item(HubIcons.icon("star"), "기본 버전으로 설정", 1)
	pm.set_item_disabled(pm.get_item_index(1), Hub.settings.get("default_editor", "") == inst.id)
	pm.add_check_item("독립 모드 (설정을 이 버전 폴더에 따로 저장)", 2)
	pm.set_item_checked(pm.get_item_index(2), Hub.is_self_contained(inst))
	pm.add_separator()
	pm.add_icon_item(HubIcons.icon("folder"), "설치 폴더 열기", 4)
	pm.add_separator()
	pm.add_icon_item(HubIcons.icon("trash"), "제거" if inst.get("managed", false) else "목록에서 제거", 5)
	pm.id_pressed.connect(_on_menu.bind(inst))
	hb.add_child(gear)
	return row


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
