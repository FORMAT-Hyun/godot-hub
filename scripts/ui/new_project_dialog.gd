class_name NewProjectDialog
extends ConfirmationDialog
## 새 프로젝트 창 — 고도 프로젝트 매니저의 "새 프로젝트 만들기" 창과 같은 구성:
## 프로젝트 이름 · 프로젝트 경로(+ 폴더 만들기) · 상태 · 렌더러(설명) · 버전 관리 메타데이터 · 만들고 편집.
## 허브에만 있는 것: 맨 위의 에디터 버전 선택.

signal project_created(path: String, install_id: String)

# 고도 4.x 렌더러 (feature = project.godot의 config/features 값)
var renderers := [
	{"id": "forward", "name": "Forward+", "feature": "Forward Plus",
		"desc": L.t("• 데스크톱 플랫폼만 지원해요.\n• 고급 3D 그래픽을 쓸 수 있어요.\n• 크고 복잡한 씬까지 확장할 수 있어요.\n• RenderingDevice 백엔드를 써요.\n• 단순한 씬은 상대적으로 느려요.")},
	{"id": "mobile", "name": "Mobile", "feature": "Mobile",
		"desc": L.t("• 데스크톱 + 모바일 플랫폼을 지원해요.\n• 3D 그래픽이 Forward+보다 덜 고급이에요.\n• 복잡한 씬에서는 확장성이 떨어져요.\n• RenderingDevice 백엔드를 써요.\n• 단순한 씬을 빠르게 그려요.")},
	{"id": "compat", "name": "Compatibility", "feature": "GL Compatibility",
		"desc": L.t("• 데스크톱, 모바일 + 웹 플랫폼을 지원해요.\n• 3D 그래픽이 가장 단순해요.\n• 저사양 · 오래된 기기를 위한 렌더러예요.\n• OpenGL 3 백엔드를 써요 (OpenGL 3.3 / ES 3.0 / WebGL2).\n• 단순한 씬을 가장 빠르게 그려요.")},
]

var _renderer := "forward"
var _editor_opt: OptionButton
var _name_edit: LineEdit
var _path_edit: LineEdit
var _create_folder: CheckBox
var _status_icon: TextureRect
var _status: Label
var _renderer_buttons := {}
var _renderer_desc: Label
var _vcs_opt: OptionButton
var _dir_dialog: FileDialog


func _init() -> void:
	title = L.t("새 프로젝트 만들기")
	ok_button_text = L.t("만들고 편집")
	cancel_button_text = L.t("취소")
	dialog_hide_on_ok = false
	min_size = Vector2i(640, 0)


func _ready() -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	add_child(vb)

	# 에디터 버전 (허브에만 있는 항목)
	vb.add_child(HubUI.label(L.t("에디터 버전:")))
	_editor_opt = OptionButton.new()
	_editor_opt.fit_to_longest_item = false
	_editor_opt.item_selected.connect(func(_i: int) -> void: _validate())
	vb.add_child(_editor_opt)
	vb.add_child(HubUI.vspace(4))

	# 프로젝트 이름
	vb.add_child(HubUI.label(L.t("프로젝트 이름:")))
	_name_edit = LineEdit.new()
	_name_edit.text_changed.connect(func(_t: String) -> void: _validate())
	vb.add_child(_name_edit)
	vb.add_child(HubUI.vspace(4))

	# 프로젝트 경로 [찾아보기]  ☑ 폴더 만들기
	vb.add_child(HubUI.label(L.t("프로젝트 경로:")))
	var path_row := HBoxContainer.new()
	path_row.add_theme_constant_override("separation", 6)
	vb.add_child(path_row)
	_path_edit = LineEdit.new()
	_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_edit.text_changed.connect(func(_t: String) -> void: _validate())
	path_row.add_child(_path_edit)
	var browse := Button.new()
	browse.text = L.t("찾아보기")
	browse.icon = HubIcons.icon("load")
	browse.focus_mode = Control.FOCUS_NONE
	browse.pressed.connect(func() -> void: _dir_dialog.popup_centered())
	path_row.add_child(browse)
	_create_folder = CheckBox.new()
	_create_folder.text = L.t("폴더 만들기")
	_create_folder.button_pressed = true
	_create_folder.focus_mode = Control.FOCUS_NONE
	_create_folder.toggled.connect(func(_on: bool) -> void: _validate())
	path_row.add_child(_create_folder)

	# 상태 줄 (아이콘 + 문구)
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 6)
	vb.add_child(status_row)
	_status_icon = HubUI.icon_rect(HubIcons.icon("check"), 16)
	_status_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_row.add_child(_status_icon)
	_status = HubUI.label("", "", 560)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_row.add_child(_status)
	vb.add_child(HubUI.vspace(4))

	# 렌더러: 왼쪽 선택 단추 · 오른쪽 설명
	vb.add_child(HubUI.label(L.t("렌더러:")))
	var rend := HBoxContainer.new()
	rend.add_theme_constant_override("separation", 16)
	vb.add_child(rend)
	var radios := VBoxContainer.new()
	radios.custom_minimum_size.x = 160
	rend.add_child(radios)
	var group := ButtonGroup.new()
	for r in renderers:
		var cb := CheckBox.new()
		cb.text = r.name
		cb.button_group = group
		cb.button_pressed = r.id == _renderer
		cb.focus_mode = Control.FOCUS_NONE
		cb.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		cb.pressed.connect(func() -> void: _select_renderer(r.id))
		radios.add_child(cb)
		_renderer_buttons[r.id] = cb
	rend.add_child(VSeparator.new())
	_renderer_desc = HubUI.label("", "", 400)
	_renderer_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_renderer_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rend.add_child(_renderer_desc)
	var note := HubUI.label(L.t("렌더러는 나중에 바꿀 수 있지만, 씬을 조정해야 할 수도 있어요."), "DimLabel", 600)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(note)
	vb.add_child(HubUI.vspace(4))

	# 버전 관리 메타데이터
	var vcs_row := HBoxContainer.new()
	vcs_row.add_theme_constant_override("separation", 8)
	vb.add_child(vcs_row)
	var vcs_label := HubUI.label(L.t("버전 관리 메타데이터:"))
	vcs_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vcs_row.add_child(vcs_label)
	_vcs_opt = OptionButton.new()
	_vcs_opt.add_item(L.t("없음"))
	_vcs_opt.add_item("Git")
	_vcs_opt.focus_mode = Control.FOCUS_NONE
	vcs_row.add_child(_vcs_opt)

	_dir_dialog = HubUI.dir_dialog(self, L.t("프로젝트를 만들 위치"), func(dir: String) -> void:
		_path_edit.text = Hub.normalize_path(dir).replace("/", "\\")
		_validate())

	about_to_popup.connect(_reset)
	confirmed.connect(_create)
	_select_renderer(_renderer)


func _select_renderer(id: String) -> void:
	_renderer = id
	for r in renderers:
		_renderer_buttons[r.id].set_pressed_no_signal(r.id == id)
		if r.id == id:
			_renderer_desc.text = r.desc


func _reset() -> void:
	_editor_opt.clear()
	var default_id := str(Hub.settings.get("default_editor", ""))
	for inst in Hub.sorted_installs():
		_editor_opt.add_item(Hub.install_label(inst))
		_editor_opt.set_item_metadata(_editor_opt.item_count - 1, inst.id)
		if inst.id == default_id:
			_editor_opt.select(_editor_opt.item_count - 1)
	var parent := str(Hub.settings.get("project_dir", ""))
	_path_edit.text = parent.replace("/", "\\")
	_create_folder.button_pressed = true
	var name := L.t("새 게임 프로젝트")
	var base := name
	var n := 2
	while DirAccess.dir_exists_absolute(Hub.normalize_path(parent).path_join(name.validate_filename())):
		name = "%s %d" % [base, n]
		n += 1
	_name_edit.text = name
	_validate()
	_name_edit.call_deferred("grab_focus")
	_name_edit.call_deferred("select_all")


## 폴더 만들기를 켜면 <경로>/<이름>, 끄면 경로 그 자체가 프로젝트 폴더
func _target_dir() -> String:
	var base := Hub.normalize_path(_path_edit.text)
	if _create_folder.button_pressed:
		return base.path_join(_name_edit.text.strip_edges().validate_filename())
	return base


func _validate() -> String:
	var err := ""
	var ok_msg := ""
	var name := _name_edit.text.strip_edges()
	var target := _target_dir()
	var not_empty := DirAccess.dir_exists_absolute(target) and \
		(DirAccess.get_files_at(target).size() + DirAccess.get_directories_at(target).size()) > 0
	if _editor_opt.item_count == 0:
		err = L.t("설치된 에디터가 없어요. 먼저 설치 페이지에서 에디터를 추가해 주세요.")
	elif name == "":
		err = L.t("프로젝트 이름을 입력해 주세요.")
	elif _path_edit.text.strip_edges() == "":
		err = L.t("위치를 골라 주세요.")
	elif not_empty:
		err = L.t("같은 이름의 폴더가 이미 있고 비어 있지 않아요.") if _create_folder.button_pressed else L.t("선택한 폴더가 비어 있지 않아요.")
	elif _create_folder.button_pressed:
		ok_msg = L.t("프로젝트 폴더가 자동으로 만들어져요.") + "\n" + target.replace("/", "\\")
	else:
		ok_msg = L.t("선택한 폴더 안에 프로젝트를 만들어요.") + "\n" + target.replace("/", "\\")
	if err != "":
		_status.text = err
		_status.add_theme_color_override("font_color", HubTheme.ERROR)
		_status_icon.texture = HubIcons.icon("warning")
		_status_icon.modulate = HubTheme.ERROR
	else:
		_status.text = ok_msg
		_status.add_theme_color_override("font_color", HubTheme.SUCCESS)
		_status_icon.texture = HubIcons.icon("check")
		_status_icon.modulate = HubTheme.SUCCESS
	get_ok_button().disabled = err != ""
	return err


func _create() -> void:
	if _validate() != "":
		return
	var install_id := str(_editor_opt.get_selected_metadata())
	var feature := ""
	for r in renderers:
		if r.id == _renderer:
			feature = r.feature
	var target := _target_dir()
	var err := Hub.create_project(_name_edit.text.strip_edges(), target, install_id, feature, _vcs_opt.selected == 1)
	if err != "":
		_status.text = err
		_status.add_theme_color_override("font_color", HubTheme.ERROR)
		return
	hide()
	project_created.emit(target, install_id)
