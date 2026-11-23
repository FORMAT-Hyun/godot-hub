class_name NewProjectDialog
extends ConfirmationDialog
## 새 프로젝트 창 (유니티 허브의 템플릿 선택 화면 구도: 분류 · 템플릿 카드 · 설정 패널)

signal project_created(path: String, install_id: String)

var templates := [
	{"id": "forward", "title": "3D", "renderer": "Forward+", "feature": "Forward Plus", "cat": "3d", "badge": "3D",
		"color": Color("#478cbf"), "desc": "데스크톱·콘솔용 고품질 3D예요.\n최신 그래픽 기능을 모두 쓸 수 있어요. (Vulkan / Direct3D 12)"},
	{"id": "mobile", "title": "3D 모바일", "renderer": "Mobile", "feature": "Mobile", "cat": "3d", "badge": "M",
		"color": Color("#4fa38f"), "desc": "모바일·저사양 기기용 3D예요.\nForward+보다 가볍고 대부분의 기능을 지원해요."},
	{"id": "compat", "title": "2D / 웹", "renderer": "Compatibility", "feature": "GL Compatibility", "cat": "2d", "badge": "2D",
		"color": Color("#d08a3e"), "desc": "2D 게임과 웹 내보내기에 가장 잘 맞아요.\n오래된 기기까지 가장 넓게 지원해요. (OpenGL)"},
]

var _selected := "forward"
var _category := "all"
var _cards := {}
var _sel_title: Label
var _sel_desc: Label
var _editor_opt: OptionButton
var _name_edit: LineEdit
var _location_edit: LineEdit
var _preview: Label
var _vcs_opt: OptionButton
var _error: Label
var _dir_dialog: FileDialog


func _init() -> void:
	title = "새 프로젝트"
	ok_button_text = "프로젝트 생성"
	cancel_button_text = "취소"
	dialog_hide_on_ok = false
	min_size = Vector2i(920, 560)


func _ready() -> void:
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	# ── 왼쪽: 분류 ──
	var cats := VBoxContainer.new()
	cats.custom_minimum_size.x = 140
	cats.add_theme_constant_override("separation", 2)
	root.add_child(cats)
	cats.add_child(HubUI.label("템플릿", "SectionLabel"))
	cats.add_child(HubUI.vspace(4))
	var group := ButtonGroup.new()
	for c in [["all", "전체"], ["3d", "3D"], ["2d", "2D"]]:
		var b := Button.new()
		b.text = c[1]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = c[0] == _category
		b.theme_type_variation = "SidebarButton"
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void:
			_category = c[0]
			_apply_category())
		cats.add_child(b)

	# ── 가운데: 템플릿 카드 ──
	var center := ScrollContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(center)
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 12)
	center.add_child(flow)
	for t in templates:
		var card := _build_card(t)
		_cards[t.id] = card
		flow.add_child(card)

	# ── 오른쪽: 설정 ──
	var side := PanelContainer.new()
	side.theme_type_variation = "SidePanel"
	side.custom_minimum_size.x = 300
	root.add_child(side)
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 6)
	side.add_child(form)
	_sel_title = HubUI.label("", "TitleLabel")
	form.add_child(_sel_title)
	# 자동 줄바꿈 라벨은 너비를 정해 줘야 높이가 제대로 계산된다
	_sel_desc = HubUI.label("", "DimLabel", 270)
	_sel_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(_sel_desc)
	form.add_child(HubUI.vspace(4))
	form.add_child(HSeparator.new())

	form.add_child(HubUI.label("에디터 버전", "SectionLabel"))
	_editor_opt = OptionButton.new()
	_editor_opt.fit_to_longest_item = false
	_editor_opt.item_selected.connect(func(_i: int) -> void: _validate())
	form.add_child(_editor_opt)

	form.add_child(HubUI.label("프로젝트 이름", "SectionLabel"))
	_name_edit = LineEdit.new()
	_name_edit.text_changed.connect(func(_t: String) -> void: _validate())
	form.add_child(_name_edit)

	form.add_child(HubUI.label("위치", "SectionLabel"))
	var loc := HBoxContainer.new()
	form.add_child(loc)
	_location_edit = LineEdit.new()
	_location_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_location_edit.text_changed.connect(func(_t: String) -> void: _validate())
	loc.add_child(_location_edit)
	var browse := Button.new()
	browse.icon = HubIcons.icon("load")
	browse.tooltip_text = "폴더 선택"
	browse.pressed.connect(func() -> void: _dir_dialog.popup_centered())
	loc.add_child(browse)
	_preview = HubUI.label("", "DimLabel", 270)
	_preview.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	form.add_child(_preview)

	form.add_child(HubUI.label("버전 관리", "SectionLabel"))
	_vcs_opt = OptionButton.new()
	_vcs_opt.add_item("없음")
	_vcs_opt.add_item("Git (.gitignore 포함)")
	form.add_child(_vcs_opt)

	_error = HubUI.label("", "", 270)
	_error.add_theme_color_override("font_color", HubTheme.ERROR)
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(_error)

	_dir_dialog = HubUI.dir_dialog(self, "프로젝트를 만들 위치", func(dir: String) -> void:
		_location_edit.text = Hub.normalize_path(dir).replace("/", "\\")
		_validate())

	about_to_popup.connect(_reset)
	confirmed.connect(_create)
	_select(_selected)


func _build_card(t: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = "CardPanel"
	card.custom_minimum_size = Vector2(190, 0)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vb)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", HubTheme.box(t.color, 6, Color.TRANSPARENT, 0, 0, 0))
	badge.custom_minimum_size = Vector2(160, 84)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bl := Label.new()
	bl.text = t.badge
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bl.add_theme_font_override("font", HubTheme.bold_font)
	bl.add_theme_font_size_override("font_size", 30)
	bl.add_theme_color_override("font_color", Color.WHITE)
	badge.add_child(bl)
	vb.add_child(badge)
	vb.add_child(HubUI.label(t.title, "TitleLabel"))
	vb.add_child(HubUI.label("렌더러: " + str(t.renderer), "DimLabel"))
	card.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_select(t.id))
	return card


func _select(id: String) -> void:
	_selected = id
	for t in templates:
		_cards[t.id].theme_type_variation = "CardPanelSelected" if t.id == id else "CardPanel"
		if t.id == id:
			_sel_title.text = "%s  (%s)" % [t.title, t.renderer]
			_sel_desc.text = t.desc


func _apply_category() -> void:
	for t in templates:
		_cards[t.id].visible = _category == "all" or t.cat == _category


func _reset() -> void:
	_editor_opt.clear()
	var default_id := str(Hub.settings.get("default_editor", ""))
	for inst in Hub.sorted_installs():
		_editor_opt.add_item(Hub.install_label(inst))
		_editor_opt.set_item_metadata(_editor_opt.item_count - 1, inst.id)
		if inst.id == default_id:
			_editor_opt.select(_editor_opt.item_count - 1)
	var parent := str(Hub.settings.get("project_dir", ""))
	_location_edit.text = parent.replace("/", "\\")
	var name := "NewGame"
	var n := 2
	while DirAccess.dir_exists_absolute(Hub.normalize_path(parent).path_join(name)):
		name = "NewGame%d" % n
		n += 1
	_name_edit.text = name
	_validate()
	_name_edit.call_deferred("grab_focus")
	_name_edit.call_deferred("select_all")


func _target_dir() -> String:
	var folder := _name_edit.text.strip_edges().validate_filename()
	return Hub.normalize_path(_location_edit.text).path_join(folder)


func _validate() -> String:
	var err := ""
	var name := _name_edit.text.strip_edges()
	var target := _target_dir()
	if _editor_opt.item_count == 0:
		err = "설치된 에디터가 없어요. 먼저 설치 페이지에서 에디터를 추가해 주세요."
	elif name == "":
		err = "프로젝트 이름을 입력해 주세요."
	elif _location_edit.text.strip_edges() == "":
		err = "위치를 골라 주세요."
	elif DirAccess.dir_exists_absolute(target) and \
			(DirAccess.get_files_at(target).size() + DirAccess.get_directories_at(target).size()) > 0:
		err = "같은 이름의 폴더가 이미 있고 비어 있지 않아요."
	_preview.text = "만들어질 폴더: " + target.replace("/", "\\")
	_error.text = err
	get_ok_button().disabled = err != ""
	return err


func _create() -> void:
	if _validate() != "":
		return
	var install_id := str(_editor_opt.get_selected_metadata())
	var feature := ""
	for t in templates:
		if t.id == _selected:
			feature = t.feature
	var target := _target_dir()
	var err := Hub.create_project(_name_edit.text.strip_edges(), target, install_id, feature, _vcs_opt.selected == 1)
	if err != "":
		_error.text = err
		return
	hide()
	project_created.emit(target, install_id)
