extends Control
## 허브 메인 화면: 왼쪽 사이드바(유니티 허브 배치) + 오른쪽 페이지

const PAGES := [
	{"id": "projects", "title": "프로젝트", "icon": "project_list"},
	{"id": "installs", "title": "설치", "icon": "download"},
]
const BASE_SIZE := Vector2(1180, 720)
const MIN_SIZE := Vector2(940, 580)

var _pages := {}
var _nav := {}
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _settings_dialog: SettingsDialog


func _ready() -> void:
	var hub_theme := HubTheme.get_theme()
	ThemeDB.get_default_theme().merge_with(hub_theme)
	theme = hub_theme
	RenderingServer.set_default_clear_color(HubTheme.BG)
	get_window().title = "Godot Hub"
	apply_ui_scale(true)
	get_tree().auto_accept_quit = false
	get_window().files_dropped.connect(_on_files_dropped)
	Hub.toast.connect(show_toast)
	Hub.settings_changed.connect(apply_ui_scale.bind(false))
	_build()

	var start := "projects"
	var dialog := ""
	var shot := ""
	var delay := 1.5
	var es_search := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hub-shot-delay="):
			delay = arg.trim_prefix("--hub-shot-delay=").to_float()
		if arg.begins_with("--hub-page="):
			start = arg.trim_prefix("--hub-page=")
		elif arg.begins_with("--hub-dialog="):
			dialog = arg.trim_prefix("--hub-dialog=")
		elif arg.begins_with("--hub-select="):
			var idx := arg.trim_prefix("--hub-select=").to_int()
			_select_row.call_deferred(idx)
		elif arg.begins_with("--hub-es-search="):
			es_search = arg.trim_prefix("--hub-es-search=")
		elif arg.begins_with("--hub-screenshot="):
			shot = arg.trim_prefix("--hub-screenshot=")
	show_page(start if _pages.has(start) else "projects")
	match dialog:
		"new":
			_pages.projects.open_new_project()
		"install":
			_pages.installs.open_install_dialog()
		"settings":
			_open_settings()
		"properties":
			if not Hub.installs.is_empty():
				_pages.installs._show_properties(Hub.sorted_installs()[0])
		"editor-settings":
			if not Hub.installs.is_empty():
				_pages.installs.open_editor_settings(Hub.sorted_installs()[0], es_search)
	if shot != "":
		_take_screenshot(shot, delay)


func _build() -> void:
	# 고도 프로젝트 매니저 배치: 위쪽 탭 바 / 페이지 / 아래 상태 줄
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	root.add_child(_build_top_bar())

	var content := PanelContainer.new()
	content.theme_type_variation = "ContentPanel"
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)
	_pages.projects = ProjectsPage.new()
	_pages.installs = InstallsPage.new()
	for id in _pages:
		content.add_child(_pages[id])
	_pages.projects.go_to_installs.connect(show_page.bind("installs"))

	var status := PanelContainer.new()
	status.theme_type_variation = "StatusBarPanel"
	var sh := HBoxContainer.new()
	status.add_child(sh)
	sh.add_child(HubUI.spacer())
	sh.add_child(HubUI.label("Godot Hub v" + Hub.HUB_VERSION, "DimLabel"))
	root.add_child(status)

	# 다운로드 진행 상황은 왼쪽 아래에 떠 있게
	var dl := MarginContainer.new()
	dl.anchor_top = 1.0
	dl.anchor_bottom = 1.0
	dl.offset_left = 12
	dl.offset_right = 332
	dl.offset_bottom = -34
	dl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dl_panel := PanelContainer.new()
	dl_panel.theme_type_variation = "ToastPanel"
	var downloads := DownloadsPanel.new()
	dl_panel.add_child(downloads)
	downloads.visibility_changed.connect(func() -> void: dl_panel.visible = downloads.visible)
	dl.add_child(dl_panel)
	add_child(dl)
	dl_panel.visible = downloads.visible

	# 오른쪽 아래 알림
	_toast = PanelContainer.new()
	_toast.theme_type_variation = "ToastPanel"
	_toast.anchor_left = 1.0
	_toast.anchor_top = 1.0
	_toast.anchor_right = 1.0
	_toast.anchor_bottom = 1.0
	_toast.offset_left = -24
	_toast.offset_top = -24
	_toast.offset_right = -24
	_toast.offset_bottom = -24
	_toast.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	_toast_label = Label.new()
	_toast.add_child(_toast_label)
	add_child(_toast)


func _build_top_bar() -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "TopBarPanel"
	var hb := HBoxContainer.new()
	panel.add_child(hb)

	# 왼쪽: 로고 · 이름 (가운데 탭이 정확히 가운데 오도록 양쪽을 같은 비율로 늘린다)
	var left := HBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.0
	left.add_theme_constant_override("separation", 6)
	hb.add_child(left)
	var logo := HubUI.icon_rect(HubIcons.icon("logo", 24), 24)
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.add_child(logo)
	var title := HubUI.label("GODOT", "TitleLabel")
	title.add_theme_font_size_override("font_size", 19)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.add_child(title)
	var hub := HubUI.label("HUB", "DimLabel")
	hub.add_theme_font_size_override("font_size", 13)
	hub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.add_child(hub)

	# 가운데: 프로젝트 · 설치 탭
	var center := HBoxContainer.new()
	center.add_theme_constant_override("separation", 12)
	hb.add_child(center)
	var group := ButtonGroup.new()
	for p in PAGES:
		var b := Button.new()
		b.text = p.title
		b.icon = HubIcons.icon(p.icon)
		b.toggle_mode = true
		b.button_group = group
		b.theme_type_variation = "TopTabButton"
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(show_page.bind(p.id))
		center.add_child(b)
		_nav[p.id] = b

	# 오른쪽: 설정
	var right := HBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	right.alignment = BoxContainer.ALIGNMENT_END
	hb.add_child(right)
	var gear := Button.new()
	gear.text = "설정"
	gear.icon = HubIcons.icon("gear")
	gear.theme_type_variation = "FlatButton"
	gear.focus_mode = Control.FOCUS_NONE
	gear.pressed.connect(_open_settings)
	right.add_child(gear)
	return panel


func show_page(id: String) -> void:
	for k in _pages:
		_pages[k].visible = k == id
	_nav[id].button_pressed = true


func show_toast(message: String) -> void:
	_toast_label.text = message
	_toast.reset_size()
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(3.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)


func apply_ui_scale(initial := false) -> void:
	var s := float(Hub.settings.get("ui_scale", 0.0))
	if s <= 0.0:
		s = clampf(snappedf(DisplayServer.screen_get_dpi() / 96.0, 0.25), 1.0, 2.0)
	var win := get_window()
	if is_equal_approx(win.content_scale_factor, s) and not initial:
		return
	win.content_scale_factor = s
	win.min_size = Vector2i(MIN_SIZE * s)
	if initial and s > 1.0:
		var usable := DisplayServer.screen_get_usable_rect(win.current_screen)
		win.size = Vector2i(BASE_SIZE * s).min(usable.size - Vector2i(40, 40))
		win.move_to_center()


func _open_settings() -> void:
	if _settings_dialog == null:
		_settings_dialog = SettingsDialog.new()
		add_child(_settings_dialog)
	_settings_dialog.popup_centered()


func _on_files_dropped(files: PackedStringArray) -> void:
	for f in files:
		Hub.import_path(f)
	show_page("projects")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if Downloads.is_active():
			HubUI.confirm(self, "Godot Hub 종료", "다운로드가 진행 중이에요.\n지금 종료하면 다운로드가 취소돼요.", "종료", get_tree().quit)
		else:
			get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and is_node_ready():
		Hub.refresh_infos()


## 개발용: --hub-select=N 이면 N번째 프로젝트를 선택해 둔다
func _select_row(idx: int) -> void:
	await get_tree().process_frame
	var items: Array = _pages.projects._sorted_projects()
	if idx < items.size():
		_pages.projects._select(items[idx].rec.path)


## 개발용: --hub-screenshot=경로 를 주면 화면을 PNG로 저장하고 종료
func _take_screenshot(path: String, delay: float) -> void:
	# 저전력 모드에서는 화면이 안 바뀌면 다시 그리지 않아 frame_post_draw가 오지 않는다
	OS.low_processor_usage_mode = false
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
