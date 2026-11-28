class_name AboutDialog
extends AcceptDialog
## "Godot Hub 정보" 창: 아래 상태 줄의 버전을 누르면 뜬다.
## 버전 · 만든 엔진 · 언어 · 데이터 폴더, 업데이트 확인, 링크(GitHub · 릴리즈 노트 · 문제 신고 · 서드파티 라이선스).

const REPO := "FORMAT-Hyun/godot-hub"
const REPO_URL := "https://github.com/" + REPO
const LATEST_API := "https://api.github.com/repos/" + REPO + "/releases/latest"

var _update_label: Label
var _update_btn: Button
var _latest_url := REPO_URL + "/releases/latest"
var _req: HTTPRequest
var _checked := false


func _init() -> void:
	title = L.t("Godot Hub 정보")
	ok_button_text = L.t("닫기")
	min_size = Vector2i(520, 0)


func _ready() -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	add_child(vb)

	# 로고 · 이름 · 버전
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	vb.add_child(head)
	head.add_child(HubUI.icon_rect(HubIcons.icon("logo", 64), 64))
	var name_vb := VBoxContainer.new()
	name_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(name_vb)
	var name_lbl := HubUI.label("Godot Hub", "HeaderLabel")
	name_lbl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name_vb.add_child(name_lbl)
	var ver := HubUI.label("v" + Hub.HUB_VERSION, "DimLabel")
	ver.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name_vb.add_child(ver)
	var desc := HubUI.label(L.t("고도 엔진 프로젝트와 에디터 버전을 한 곳에서 관리하는 런처예요."), "", 480)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(desc)

	# 정보 표
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	vb.add_child(grid)
	var engine := Engine.get_version_info()
	var lang_name := L.current
	for l in L.LANGUAGES:
		if l[0] == L.current:
			lang_name = l[1]
	_row(grid, L.t("버전"), Hub.HUB_VERSION)
	_row(grid, L.t("만든 엔진"), "Godot %s" % str(engine.get("string", "")).get_slice(" ", 0))
	_row(grid, L.t("언어"), lang_name)
	grid.add_child(HubUI.label(L.t("데이터 폴더"), "DimLabel"))
	var data_btn := Button.new()
	data_btn.text = L.t("열기")
	data_btn.icon = HubIcons.icon("folder")
	data_btn.focus_mode = Control.FOCUS_NONE
	data_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	data_btn.tooltip_text = ProjectSettings.globalize_path(Hub.data_dir)
	data_btn.pressed.connect(func() -> void: OS.shell_open(ProjectSettings.globalize_path(Hub.data_dir)))
	grid.add_child(data_btn)

	# 업데이트 확인
	var upd := HBoxContainer.new()
	upd.add_theme_constant_override("separation", 8)
	vb.add_child(upd)
	_update_label = HubUI.label("", "DimLabel")
	_update_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_update_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	upd.add_child(_update_label)
	_update_btn = Button.new()
	_update_btn.text = L.t("받기")
	_update_btn.icon = HubIcons.icon("download")
	_update_btn.theme_type_variation = "PrimaryButton"
	_update_btn.focus_mode = Control.FOCUS_NONE
	_update_btn.visible = false
	_update_btn.pressed.connect(func() -> void: OS.shell_open(_latest_url))
	upd.add_child(_update_btn)

	# 링크
	var links := HFlowContainer.new()
	links.add_theme_constant_override("h_separation", 6)
	links.add_theme_constant_override("v_separation", 6)
	vb.add_child(links)
	_link(links, "GitHub", "external", REPO_URL)
	_link(links, L.t("릴리즈 노트"), "external", REPO_URL + "/releases")
	_link(links, L.t("문제 신고"), "external", REPO_URL + "/issues")
	_link(links, L.t("서드파티 라이선스"), "external", REPO_URL + "/blob/main/THIRD_PARTY.md")

	var note := HubUI.label(L.t("비공식 프로그램이에요. Godot 이름과 로고는 Godot Foundation의 상표예요."), "DimLabel", 480)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(note)

	_req = HTTPRequest.new()
	_req.timeout = 15
	_req.request_completed.connect(_on_latest)
	add_child(_req)
	about_to_popup.connect(_check_update)


func _row(grid: GridContainer, key: String, value: String) -> void:
	grid.add_child(HubUI.label(key, "DimLabel"))
	var v := HubUI.label(value)
	v.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	grid.add_child(v)


func _link(parent: Control, text: String, icon_name: String, url: String) -> void:
	var b := Button.new()
	b.text = text
	b.icon = HubIcons.icon(icon_name)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = url
	b.pressed.connect(func() -> void: OS.shell_open(url))
	parent.add_child(b)


# ─────────────────────────── 업데이트 확인 (이 저장소의 최신 릴리즈) ───────────────────────────

func _check_update() -> void:
	if _checked or _req.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	_update_label.text = L.t("업데이트 확인 중...")
	_update_label.remove_theme_color_override("font_color")
	var headers := PackedStringArray(["User-Agent: GodotHub-Launcher", "Accept: application/vnd.github+json"])
	var token := str(Hub.settings.get("github_token", "")).strip_edges()
	if token != "":
		headers.append("Authorization: Bearer " + token)
	if _req.request(LATEST_API, headers) != OK:
		_update_label.text = L.t("업데이트를 확인하지 못했어요.")


func _on_latest(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	var data: Variant = JSON.parse_string(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS and code == 200 else null
	if not (data is Dictionary) or str(data.get("tag_name", "")) == "":
		_update_label.text = L.t("업데이트를 확인하지 못했어요.")
		return
	_checked = true
	var latest := str(data.tag_name).trim_prefix("v")
	_latest_url = str(data.get("html_url", _latest_url))
	if is_newer(latest, Hub.HUB_VERSION):
		_update_label.text = L.t("새 버전 %s이(가) 나왔어요.") % ("v" + latest)
		_update_label.add_theme_color_override("font_color", HubTheme.SUCCESS)
		_update_btn.visible = true
	else:
		_update_label.text = L.t("최신 버전이에요.")
		_update_btn.visible = false


## "0.2.10" 이 "0.2.9" 보다 새 버전인지 (숫자끼리 비교)
static func is_newer(a: String, b: String) -> bool:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := pa[i].to_int() if i < pa.size() else 0
		var y := pb[i].to_int() if i < pb.size() else 0
		if x != y:
			return x > y
	return false
