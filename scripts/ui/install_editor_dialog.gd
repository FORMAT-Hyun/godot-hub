class_name InstallEditorDialog
extends AcceptDialog
## "에디터 설치" 창: 공식 릴리스 / 프리릴리스 / 아카이브 탭에서 버전을 골라 설치

const TABS := [["stable", "공식 릴리스"], ["pre", "프리릴리스"], ["archive", "아카이브"]]
const MAX_ROWS := 60

var _tab := "stable"
var _list: VBoxContainer
var _status: Label
var _path_edit: LineEdit
var _dir_dialog: FileDialog
var _refresh_btn: Button
var _queued := false


func _init() -> void:
	title = "에디터 설치"
	ok_button_text = "닫기"
	min_size = Vector2i(780, 560)


func _ready() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	root.add_child(top)
	var group := ButtonGroup.new()
	for t in TABS:
		var b := Button.new()
		b.text = t[1]
		b.toggle_mode = true
		b.button_group = group
		b.theme_type_variation = "ChipButton"
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = t[0] == _tab
		b.pressed.connect(func() -> void:
			_tab = t[0]
			_rebuild())
		top.add_child(b)
	top.add_child(HubUI.spacer())
	_status = HubUI.label("", "DimLabel")
	top.add_child(_status)
	_refresh_btn = HubUI.flat_icon_button("refresh", "목록 새로고침")
	_refresh_btn.pressed.connect(func() -> void:
		Releases.refresh(true)
		_rebuild())
	top.add_child(_refresh_btn)

	# 설치 위치
	var loc := HBoxContainer.new()
	loc.add_theme_constant_override("separation", 8)
	root.add_child(loc)
	loc.add_child(HubUI.label("설치 위치", "SectionLabel"))
	_path_edit = LineEdit.new()
	_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_edit.editable = false
	loc.add_child(_path_edit)
	var browse := Button.new()
	browse.text = "경로 지정"
	browse.icon = HubIcons.icon("load")
	browse.focus_mode = Control.FOCUS_NONE
	browse.pressed.connect(func() -> void: _dir_dialog.popup_centered())
	loc.add_child(browse)
	_dir_dialog = HubUI.dir_dialog(self, "에디터를 설치할 폴더", func(dir: String) -> void:
		Hub.settings.install_dir = Hub.normalize_path(dir)
		Hub.save_settings()
		_update_path())
	root.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)

	about_to_popup.connect(func() -> void:
		Releases.refresh(false)
		_update_path()
		_rebuild())
	Releases.releases_updated.connect(_queue_rebuild)
	Releases.fetch_failed.connect(_on_fetch_failed)
	Downloads.jobs_changed.connect(_queue_rebuild)
	Hub.installs_changed.connect(_queue_rebuild)


func _update_path() -> void:
	_path_edit.text = str(Hub.settings.install_dir).replace("/", "\\")
	_path_edit.tooltip_text = "새로 받는 에디터는 이 폴더 안에 버전별로 설치돼요.\n이미 설치된 에디터는 옮겨지지 않아요."


func _queue_rebuild() -> void:
	if visible and not _queued:
		_queued = true
		call_deferred("_rebuild")


func _on_fetch_failed(message: String) -> void:
	_rebuild()
	_status.text = message
	_status.add_theme_color_override("font_color", HubTheme.ERROR)
	if Releases.releases.is_empty():
		HubUI.alert(self, "목록을 불러오지 못했어요", message)


func _rebuild() -> void:
	_queued = false
	for c in _list.get_children():
		c.queue_free()
	_status.remove_theme_color_override("font_color")
	if Releases.busy:
		_status.text = "목록을 불러오는 중..."
	elif Releases.fetched_at > 0:
		_status.text = "마지막 갱신: " + HubUI.rel_time(Releases.fetched_at)
	else:
		_status.text = ""
	_refresh_btn.disabled = Releases.busy
	if Releases.releases.is_empty():
		var l := HubUI.label("목록을 불러오는 중이에요..." if Releases.busy else "목록이 비어 있어요. 오른쪽 위 새로고침을 눌러 주세요.", "DimLabel")
		_list.add_child(l)
		return
	var count := 0
	for rel in Releases.releases:
		var p := GodotVersion.parse(rel.get("tag", ""))
		var pre := bool(rel.get("prerelease", false))
		match _tab:
			"stable":
				if pre or p.major < 4:
					continue
			"pre":
				if not pre:
					continue
			"archive":
				if pre or p.major >= 4:
					continue
		_list.add_child(_build_row(rel))
		count += 1
		if count >= MAX_ROWS:
			break
	if count == 0:
		_list.add_child(HubUI.label("표시할 버전이 없어요.", "DimLabel"))


func _build_row(rel: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.theme_type_variation = "RowPanel"
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	row.add_child(hb)
	var tag: String = rel.get("tag", "")
	hb.add_child(HubUI.icon_rect(HubIcons.icon("logo", 24), 24))
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 0)
	hb.add_child(vb)
	vb.add_child(HubUI.label("Godot " + tag, "TitleLabel"))
	vb.add_child(HubUI.label(str(rel.get("date", "")).replace("-", ". ") + ".", "DimLabel"))
	var assets: Dictionary = rel.get("assets", {})
	hb.add_child(_install_button(rel, false, assets.get("std", {})))
	hb.add_child(_install_button(rel, true, assets.get("mono", {})))
	return row


func _install_button(rel: Dictionary, mono: bool, asset: Dictionary) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.x = 150
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var kind := ".NET" if mono else "표준"
	var tag: String = rel.get("tag", "")
	if asset.is_empty():
		b.text = "%s 없음" % kind
		b.disabled = true
	elif not Hub.find_install_by_version(tag, mono).is_empty():
		b.text = "%s 설치됨" % kind
		b.icon = HubIcons.icon("check")
		b.disabled = true
	elif Downloads.is_busy_with(tag, mono, "editor"):
		b.text = "%s 받는 중..." % kind
		b.disabled = true
	else:
		b.text = "%s  (%s)" % [kind, HubUI.human_size(int(asset.get("size", 0)))]
		b.icon = HubIcons.icon("download")
		if not mono:
			b.theme_type_variation = "PrimaryButton"
		b.tooltip_text = asset.get("name", "")
		b.pressed.connect(func() -> void:
			Downloads.install_editor(rel, mono))
	return b
