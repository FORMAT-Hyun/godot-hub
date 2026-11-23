class_name ProjectRow
extends PanelContainer
## 프로젝트 목록의 한 줄: ★ · 아이콘 · 이름/경로 · 수정일 · 에디터 버전 · ⋯

signal action(path: String, what: String, arg: String)

const MODIFIED_WIDTH := 130.0
const EDITOR_WIDTH := 210.0

var path := ""
var _hover := false
var _selected := false
var _menu_btn: MenuButton
var _versions_menu: PopupMenu


func _ready() -> void:
	_update_style()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var rec := Hub.get_project(path)
	var info := Hub.project_info(path)
	var fav := bool(rec.get("favorite", false))

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hb)

	# ★ 즐겨찾기
	var star := HubUI.flat_icon_button("star_fill" if fav else "star", "즐겨찾기 해제" if fav else "즐겨찾기")
	star.custom_minimum_size = Vector2(28, 28)
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if fav:
		for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
			star.add_theme_color_override(c, HubTheme.WARNING)
	else:
		star.add_theme_color_override("icon_normal_color", HubTheme.TEXT_DISABLED)
	star.pressed.connect(Hub.toggle_favorite.bind(path))
	hb.add_child(star)

	# 아이콘
	var tex := Hub.project_icon(path)
	if tex:
		hb.add_child(HubUI.icon_rect(tex, 40))
	else:
		hb.add_child(HubUI.icon_rect(HubIcons.icon("logo", 40), 40))

	# 이름 + 경로
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(name_row)
	name_row.clip_contents = true
	name_row.add_child(HubUI.label(str(info.name), "TitleLabel"))
	if not info.valid:
		name_row.add_child(HubUI.tag("찾을 수 없음", HubTheme.ERROR))
	if Hub.is_running(path):
		name_row.add_child(HubUI.tag("열려 있음", HubTheme.SUCCESS))
	if info.csharp:
		name_row.add_child(HubUI.tag("C#", HubTheme.DOTNET))
	for t in info.get("tags", []):
		name_row.add_child(HubUI.tag(str(t), HubTheme.TEXT_DIM))
	var sub := path.replace("/", "\\")
	if info.version != "":
		sub = "Godot %s%s   ·   %s" % [info.version, (" " + str(info.renderer)) if info.renderer != "" else "", sub]
	var path_lbl := HubUI.label(sub, "DimLabel")
	path_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	path_lbl.tooltip_text = path.replace("/", "\\")
	vb.add_child(path_lbl)

	# 수정일
	var mod := HubUI.label(HubUI.rel_time(Hub.project_modified(path)), "", MODIFIED_WIDTH)
	mod.add_theme_color_override("font_color", HubTheme.TEXT_DIM)
	mod.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(mod)

	# 에디터 버전
	hb.add_child(_build_editor_option(rec, info))

	# ⋯ 메뉴
	_menu_btn = MenuButton.new()
	_menu_btn.icon = HubIcons.icon("more")
	_menu_btn.theme_type_variation = "FlatButton"
	_menu_btn.flat = false
	_menu_btn.focus_mode = Control.FOCUS_NONE
	_menu_btn.tooltip_text = "더 보기"
	_menu_btn.custom_minimum_size = Vector2(32, 28)
	_menu_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_menu_btn.about_to_popup.connect(_fill_menu)
	_menu_btn.get_popup().id_pressed.connect(_on_menu)
	_versions_menu = PopupMenu.new()
	_versions_menu.id_pressed.connect(_on_version_menu)
	_menu_btn.get_popup().add_child(_versions_menu)
	hb.add_child(_menu_btn)


func _build_editor_option(rec: Dictionary, info: Dictionary) -> Control:
	var opt := OptionButton.new()
	opt.custom_minimum_size.x = EDITOR_WIDTH
	opt.fit_to_longest_item = false
	opt.clip_text = true
	opt.focus_mode = Control.FOCUS_NONE
	opt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var current := str(rec.get("editor", ""))
	var insts := Hub.sorted_installs()
	if Hub.find_install(current).is_empty():
		var want := str(info.version) if info.version != "" else "?"
		opt.add_icon_item(HubIcons.icon("warning"), "설치 필요 (%s)" % want)
		opt.set_item_metadata(0, "")
		opt.add_theme_color_override("font_color", HubTheme.WARNING)
		opt.add_theme_color_override("font_hover_color", HubTheme.WARNING)
		opt.tooltip_text = "이 프로젝트에 맞는 에디터가 설치되어 있지 않아요"
	for inst in insts:
		opt.add_item(Hub.install_label(inst))
		var idx := opt.item_count - 1
		opt.set_item_metadata(idx, inst.id)
		if _mismatch(info, inst):
			opt.set_item_icon(idx, HubIcons.icon("warning"))
		if inst.id == current:
			opt.select(idx)
			if _mismatch(info, inst):
				opt.tooltip_text = "프로젝트 버전(%s)과 에디터 버전이 달라요" % info.version
	if insts.is_empty():
		opt.add_item("에디터 설치하기...")
		opt.set_item_metadata(opt.item_count - 1, "#install")
	opt.item_selected.connect(func(idx: int) -> void:
		var id := str(opt.get_item_metadata(idx))
		if id == "#install":
			action.emit(path, "install", "")
		elif id != "":
			Hub.set_project_editor(path, id))
	return opt


func _mismatch(info: Dictionary, inst: Dictionary) -> bool:
	var pv := str(info.get("version", ""))
	if pv == "" or pv.ends_with(".x"):
		return pv.ends_with(".x") and not str(inst.get("version", "")).begins_with(pv.left(1))
	return GodotVersion.short(inst.get("version", "")) != pv


func set_hover(on: bool) -> void:
	if on != _hover:
		_hover = on
		_update_style()


func set_selected(on: bool) -> void:
	_selected = on
	_update_style()


func _update_style() -> void:
	if _selected:
		theme_type_variation = "RowPanelSelected"
	else:
		theme_type_variation = "RowPanelHover" if _hover else "RowPanel"


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			action.emit(path, "open", "")
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			action.emit(path, "select", "")
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			action.emit(path, "select", "")
			_menu_btn.show_popup()
			accept_event()


func _fill_menu() -> void:
	var pm := _menu_btn.get_popup()
	pm.clear(false)
	pm.add_icon_item(HubIcons.icon("edit"), "에디터로 열기", 0)
	pm.add_icon_item(HubIcons.icon("play"), "게임 실행", 1)
	_versions_menu.clear()
	var insts := Hub.sorted_installs()
	for i in insts.size():
		_versions_menu.add_item(Hub.install_label(insts[i]), 100 + i)
		_versions_menu.set_item_metadata(_versions_menu.item_count - 1, insts[i].id)
	pm.add_submenu_node_item("다른 버전으로 열기", _versions_menu)
	pm.set_item_disabled(pm.item_count - 1, insts.is_empty())
	pm.add_separator()
	pm.add_icon_item(HubIcons.icon("folder"), "탐색기에서 보기", 2)
	pm.add_icon_item(HubIcons.icon("copy"), "경로 복사", 3)
	pm.add_separator()
	pm.add_icon_item(HubIcons.icon("trash"), "목록에서 제거", 4)


func _on_menu(id: int) -> void:
	match id:
		0:
			action.emit(path, "open", "")
		1:
			action.emit(path, "run", "")
		2:
			action.emit(path, "show", "")
		3:
			action.emit(path, "copy", "")
		4:
			action.emit(path, "remove", "")


func _on_version_menu(id: int) -> void:
	var idx := _versions_menu.get_item_index(id)
	action.emit(path, "open", str(_versions_menu.get_item_metadata(idx)))
