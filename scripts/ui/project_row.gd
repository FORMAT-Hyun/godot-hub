class_name ProjectRow
extends PanelContainer
## 프로젝트 목록의 한 줄 (고도 프로젝트 매니저와 같은 모양)
## ☆ · 아이콘 · 이름 / 📁 경로 · 에디터 버전 · 수정 시각
## 왼쪽 클릭: 선택, 두 번 클릭: 열기, 오른쪽 클릭: 메뉴

signal action(path: String, what: String, arg: String)

const ICON_SIZE := 56
const DATE_WIDTH := 150.0

var path := ""
var _hover := false
var _selected := false
var _menu: PopupMenu
var _versions_menu: PopupMenu


func _ready() -> void:
	_update_style()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var rec := Hub.get_project(path)
	var info := Hub.project_info(path)
	var fav := bool(rec.get("favorite", false))
	var missing: bool = not info.valid

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hb)

	# ☆ 즐겨찾기
	var star := HubUI.flat_icon_button("star_fill" if fav else "star", "즐겨찾기 해제" if fav else "즐겨찾기")
	star.custom_minimum_size = Vector2(26, 26)
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if fav:
		for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
			star.add_theme_color_override(c, HubTheme.WARNING)
	star.pressed.connect(Hub.toggle_favorite.bind(path))
	hb.add_child(star)

	# 아이콘
	var tex := Hub.project_icon(path)
	var icon := HubUI.icon_rect(tex if tex else HubIcons.icon("logo", ICON_SIZE), ICON_SIZE)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if missing:
		icon.modulate = Color(1, 1, 1, 0.35)
	hb.add_child(icon)

	# 이름 / 경로
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 10)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.clip_contents = true
	vb.add_child(name_row)
	var name_lbl := HubUI.label("프로젝트가 누락됨" if missing else str(info.name), "TitleLabel")
	if missing:
		name_lbl.add_theme_color_override("font_color", HubTheme.TEXT_DISABLED)
	name_row.add_child(name_lbl)
	if Hub.is_running(path):
		name_row.add_child(HubUI.tag("열려 있음", HubTheme.SUCCESS))
	if info.csharp:
		name_row.add_child(HubUI.tag("C#", HubTheme.DOTNET))
	for t in info.get("tags", []):
		name_row.add_child(HubUI.tag(str(t), HubTheme.TEXT_DIM))

	var path_row := HBoxContainer.new()
	path_row.add_theme_constant_override("separation", 8)
	path_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(path_row)
	var folder := HubUI.icon_rect(HubIcons.icon("folder"), 16, HubTheme.ERROR if missing else HubTheme.TEXT_DIM)
	folder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	path_row.add_child(folder)
	var path_lbl := HubUI.label(path.replace("\\", "/"), "DimLabel")
	path_lbl.add_theme_font_size_override("font_size", 13)
	path_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	path_lbl.tooltip_text = path.replace("/", "\\")
	path_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	if missing:
		path_lbl.add_theme_color_override("font_color", HubTheme.TEXT_DISABLED)
	path_row.add_child(path_lbl)

	# 에디터 버전 · 수정 시각 (매니저에서 "4.7  2026-11-23 22:53:05" 자리)
	if missing:
		path_row.add_child(HubUI.icon_rect(HubIcons.icon("warning"), 16, HubTheme.WARNING))
		path_row.add_child(HubUI.label("?", "DimLabel"))
		var no_date := HubUI.label("날짜가 누락됨", "DimLabel", DATE_WIDTH)
		no_date.add_theme_font_size_override("font_size", 13)
		no_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		path_row.add_child(no_date)
	else:
		path_row.add_child(_build_editor_option(rec, info))
		var date := HubUI.label(_date_text(Hub.project_modified(path)), "DimLabel", DATE_WIDTH)
		date.add_theme_font_size_override("font_size", 13)
		date.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		path_row.add_child(date)

	# 오른쪽 클릭 메뉴
	_menu = PopupMenu.new()
	_menu.id_pressed.connect(_on_menu)
	_versions_menu = PopupMenu.new()
	_versions_menu.id_pressed.connect(_on_version_menu)
	_menu.add_child(_versions_menu)
	add_child(_menu)


## 이 프로젝트를 열 에디터. 글자처럼 보이지만 눌러서 바꿀 수 있다
func _build_editor_option(rec: Dictionary, info: Dictionary) -> Control:
	var opt := OptionButton.new()
	opt.flat = true
	opt.fit_to_longest_item = false
	opt.focus_mode = Control.FOCUS_NONE
	opt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	opt.add_theme_font_size_override("font_size", 14)
	var current := str(rec.get("editor", ""))
	var insts := Hub.sorted_installs()
	opt.tooltip_text = "이 프로젝트를 열 에디터 (눌러서 바꾸기)"
	if Hub.find_install(current).is_empty():
		var want := str(info.version) if info.version != "" else "?"
		opt.add_icon_item(HubIcons.icon("warning"), want)
		opt.set_item_metadata(0, "")
		opt.add_theme_color_override("font_color", HubTheme.WARNING)
		opt.add_theme_color_override("font_hover_color", HubTheme.WARNING)
		opt.tooltip_text = "이 프로젝트에 맞는 에디터(%s)가 설치되어 있지 않아요" % want
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


static func _date_text(unix: int) -> String:
	if unix <= 0:
		return "-"
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	return Time.get_datetime_string_from_unix_time(unix + bias * 60, true)


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
		theme_type_variation = "PmRowSelected"
	else:
		theme_type_variation = "PmRowHover" if _hover else "PmRow"


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
			_fill_menu()
			_menu.popup(Rect2i(Vector2i(DisplayServer.mouse_get_position()), Vector2i.ZERO))
			accept_event()


func _fill_menu() -> void:
	_menu.clear(false)
	_menu.add_icon_item(HubIcons.icon("edit"), "에디터로 열기", 0)
	_menu.add_icon_item(HubIcons.icon("play"), "게임 실행", 1)
	_versions_menu.clear()
	var insts := Hub.sorted_installs()
	for i in insts.size():
		_versions_menu.add_item(Hub.install_label(insts[i]), 100 + i)
		_versions_menu.set_item_metadata(_versions_menu.item_count - 1, insts[i].id)
	_menu.add_submenu_node_item("다른 버전으로 열기", _versions_menu)
	_menu.set_item_disabled(_menu.item_count - 1, insts.is_empty())
	_menu.add_separator()
	_menu.add_icon_item(HubIcons.icon("folder"), "탐색기에서 보기", 2)
	_menu.add_icon_item(HubIcons.icon("copy"), "경로 복사", 3)
	_menu.add_separator()
	_menu.add_icon_item(HubIcons.icon("trash"), "목록에서 제거", 4)


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
