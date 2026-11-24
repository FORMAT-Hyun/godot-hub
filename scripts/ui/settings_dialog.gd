class_name SettingsDialog
extends ConfirmationDialog
## 설정 창

const SCALES := [[0.0, "자동"], [1.0, "100%"], [1.25, "125%"], [1.5, "150%"], [1.75, "175%"], [2.0, "200%"]]

var _install_dir: LineEdit
var _project_dir: LineEdit
var _after: OptionButton
var _scale: OptionButton
var _self_contained: CheckBox
var _es_mode: OptionButton
var _lang: OptionButton
var _token: LineEdit
var _dir_dialog: FileDialog
var _browse_target: LineEdit


func _init() -> void:
	title = L.t("설정")
	ok_button_text = L.t("저장")
	cancel_button_text = L.t("취소")
	min_size = Vector2i(640, 0)


func _ready() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 10)
	add_child(grid)

	_install_dir = _path_row(grid, L.t("에디터 설치 경로"))
	_project_dir = _path_row(grid, L.t("새 프로젝트 기본 위치"))

	grid.add_child(HubUI.label(L.t("에디터를 연 뒤 허브는")))
	_after = OptionButton.new()
	for t in [L.t("그대로 두기"), L.t("최소화"), L.t("종료")]:
		_after.add_item(t)
	grid.add_child(_after)

	grid.add_child(HubUI.label(L.t("화면 배율")))
	_scale = OptionButton.new()
	for s in SCALES:
		_scale.add_item(s[1])
	grid.add_child(_scale)

	grid.add_child(HubUI.label(L.t("독립 모드")))
	_self_contained = CheckBox.new()
	_self_contained.text = L.t("새로 받는 에디터의 설정을 버전 폴더 안에 따로 저장 (._sc_)")
	grid.add_child(_self_contained)

	grid.add_child(HubUI.label(L.t("에디터 설정 창")))
	_es_mode = OptionButton.new()
	_es_mode.add_item(L.t("허브 안 설정 창 (빠름, 설정 파일을 직접 편집)"))
	_es_mode.add_item(L.t("고도 에디터의 설정 창 (그 버전 에디터를 실행)"))
	grid.add_child(_es_mode)

	# 언어: 이름은 번역하지 않고 그 언어로 쓴 이름을 보여 준다
	var lang_label := L.t("언어")
	grid.add_child(HubUI.label(lang_label if lang_label == "Language" else lang_label + " / Language"))
	_lang = OptionButton.new()
	_lang.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_lang.add_item(L.t("시스템 언어 따르기"))
	_lang.set_item_metadata(0, "")
	for l in L.LANGUAGES:
		_lang.add_item(l[1])
		_lang.set_item_metadata(_lang.item_count - 1, l[0])
	grid.add_child(_lang)

	grid.add_child(HubUI.label(L.t("GitHub 토큰 (선택)")))
	_token = LineEdit.new()
	_token.secret = true
	_token.placeholder_text = L.t("요청 한도(시간당 60회)를 늘리고 싶을 때만")
	grid.add_child(_token)

	grid.add_child(HubUI.label(L.t("데이터 폴더")))
	var data_btn := Button.new()
	data_btn.text = L.t("허브 데이터 폴더 열기")
	data_btn.icon = HubIcons.icon("external")
	data_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	data_btn.pressed.connect(func() -> void: OS.shell_open(ProjectSettings.globalize_path(Hub.data_dir)))
	grid.add_child(data_btn)

	_dir_dialog = HubUI.dir_dialog(self, L.t("폴더 선택"), func(dir: String) -> void:
		if _browse_target:
			_browse_target.text = Hub.normalize_path(dir).replace("/", "\\"))
	about_to_popup.connect(_load)
	confirmed.connect(_save)


func _path_row(grid: GridContainer, text: String) -> LineEdit:
	grid.add_child(HubUI.label(text))
	var hb := HBoxContainer.new()
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var edit := LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(edit)
	var b := Button.new()
	b.icon = HubIcons.icon("load")
	b.tooltip_text = L.t("폴더 선택")
	b.pressed.connect(func() -> void:
		_browse_target = edit
		_dir_dialog.popup_centered())
	hb.add_child(b)
	grid.add_child(hb)
	return edit


func _load() -> void:
	var s := Hub.settings
	_install_dir.text = str(s.install_dir).replace("/", "\\")
	_project_dir.text = str(s.project_dir).replace("/", "\\")
	_after.select(clampi(int(s.get("after_launch", 0)), 0, 2))
	var cur := float(s.get("ui_scale", 0.0))
	_scale.select(0)
	for i in SCALES.size():
		if is_equal_approx(SCALES[i][0], cur):
			_scale.select(i)
	_self_contained.button_pressed = bool(s.get("self_contained", true))
	_token.text = str(s.get("github_token", ""))
	_es_mode.select(clampi(int(s.get("editor_settings_mode", 0)), 0, 1))
	_lang.select(0)
	for i in _lang.item_count:
		if str(_lang.get_item_metadata(i)) == str(s.get("language", "")):
			_lang.select(i)


func _save() -> void:
	var s := Hub.settings
	if _install_dir.text.strip_edges() != "":
		s.install_dir = Hub.normalize_path(_install_dir.text)
	if _project_dir.text.strip_edges() != "":
		s.project_dir = Hub.normalize_path(_project_dir.text)
	s.after_launch = _after.selected
	s.ui_scale = SCALES[_scale.selected][0]
	s.self_contained = _self_contained.button_pressed
	s.github_token = _token.text.strip_edges()
	s.editor_settings_mode = _es_mode.selected
	var old_lang := str(s.get("language", ""))
	s.language = str(_lang.get_item_metadata(_lang.selected))
	Hub.save_settings()
	if s.language != old_lang:
		# 언어가 바뀌면 화면을 새 언어로 다시 만든다
		L.apply(s.language)
		get_tree().call_deferred("reload_current_scene")
		return
	Hub.toast.emit(L.t("설정을 저장했어요"))
