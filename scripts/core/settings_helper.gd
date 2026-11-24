class_name SettingsHelper
extends RefCounted
## 고도의 진짜 "에디터 설정" 창을 허브에서 띄운다.
## 버전별 빈 도우미 프로젝트(허브 데이터 폴더 안)를 만들고, 그 버전 에디터로 연다.
## 도우미 프로젝트의 플러그인이 에디터 본창을 숨기고 설정 창만 보여 준다.
##
## 또 허브 안 설정 창이 쓸 "설정 정보"(목록 항목 이름, 범위, 기본값, 한국어 이름, 단축키 목록)를
## 그 버전 에디터를 화면 없이(--headless) 잠깐 실행해서 뽑아 온다 (dump).
## 설정 파일이 아직 없는 버전이면 이때 만들어진다.

const PLUGIN_SOURCE := """@tool
extends EditorPlugin
## Godot Hub 설정 도우미 플러그인.
## 허브가 만든 빈 도우미 프로젝트에서만 켜진다.
## 에디터 본창은 화면 밖으로 치우고 고도의 "에디터 설정" 창만 띄운 뒤,
## 그 창을 닫으면 설정을 저장하고 에디터를 종료한다.


func _enter_tree() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hub-dump="):
			_dump.call_deferred(a.substr(11))
			return
	var main := get_tree().root
	main.mode = Window.MODE_WINDOWED
	main.size = Vector2i(320, 200)
	main.position = Vector2i(-30000, -30000)
	_open.call_deferred()


func _open() -> void:
	await get_tree().process_frame
	var main := get_tree().root
	var dialogs := main.find_children("*", "EditorSettingsDialog", true, false)
	var menu: PopupMenu = null
	for bar in main.find_children("*", "MenuBar", true, false):
		if bar.get_node_or_null("Editor") is PopupMenu:
			menu = bar.get_node("Editor")
	if dialogs.is_empty() or menu == null:
		_show_editor()  # 이 버전에서 메뉴를 못 찾으면 에디터를 그냥 보여 준다
		return
	var dlg: Window = dialogs[0]
	menu.id_pressed.emit(menu.get_item_id(0))  # 편집기 > 편집기 설정...
	await get_tree().process_frame
	if not dlg.visible or dlg.is_embedded():
		_show_editor()  # 단일 창 모드면 설정 창이 본창 안에 그려지므로 본창을 보여 준다
		return
	var rect := DisplayServer.screen_get_usable_rect(DisplayServer.get_primary_screen())
	dlg.position = rect.position + (rect.size - dlg.size) / 2
	dlg.visibility_changed.connect(_on_dialog_visibility.bind(dlg))
	# 다른 창 뒤에 깔리지 않도록 잠깐 항상 위로 올렸다가 되돌린다
	dlg.always_on_top = true
	dlg.move_to_foreground()
	dlg.grab_focus()
	await get_tree().create_timer(0.5).timeout
	dlg.always_on_top = false


func _show_editor() -> void:
	get_tree().root.mode = Window.MODE_MAXIMIZED


func _on_dialog_visibility(dlg: Window) -> void:
	if dlg.visible:
		return
	ResourceSaver.save(get_editor_interface().get_editor_settings())
	get_tree().quit()


# ── 허브 안 설정 창용 정보 뽑기 ──

func _dump(out_path: String) -> void:
	await get_tree().process_frame
	var es = get_editor_interface().get_editor_settings()
	var data = {"file": "", "props": [], "words": {}, "shortcuts": [], "overridden": []}
	var pdom = null
	var edom = null
	if TranslationServer.has_method("get_or_add_domain"):
		pdom = TranslationServer.call("get_or_add_domain", "godot.properties")
		edom = TranslationServer.call("get_or_add_domain", "godot.editor")
	for p in es.get_property_list():
		var name = String(p.name)
		if not (p.usage & PROPERTY_USAGE_EDITOR) or not name.contains("/"):
			continue
		var item = {"name": name, "type": p.type, "hint": p.hint, "hint_string": p.hint_string, "usage": p.usage}
		item["value"] = var_to_str(es.get_setting(name))
		if es.property_can_revert(name):
			item["default"] = var_to_str(es.property_get_revert(name))
		data.props.append(item)
		if pdom != null:
			for w in name.split("/"):
				var cap = w.capitalize()
				if not data.words.has(cap):
					var t = pdom.translate(cap)
					if t != cap:
						data.words[cap] = t
	for key in ["shortcuts", "builtin_action_overrides"]:
		var arr = es.get(key)
		if arr is Array:
			for d in arr:
				if d is Dictionary and d.has("name"):
					data.overridden.append(String(d.name))
	for dlg in get_tree().root.find_children("*", "EditorSettingsDialog", true, false):
		# 4.4 이하는 설정 창을 열기 전까지 단축키 목록이 비어 있어서 직접 채운다
		if dlg.has_method("_update_shortcuts"):
			dlg.call("_update_shortcuts")
		for tree in dlg.find_children("*", "Tree", true, false):
			if tree.get_root() != null:
				_dump_shortcuts(tree.get_root(), "", edom, data.shortcuts)
	if es.resource_path != "":
		if not FileAccess.file_exists(es.resource_path):
			ResourceSaver.save(es)
		data.file = ProjectSettings.globalize_path(es.resource_path)
	var f = FileAccess.open(out_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
		f.close()
	get_tree().quit()


func _dump_shortcuts(item, category, edom, out) -> void:
	var child = item.get_first_child()
	while child != null:
		if String(child.get_meta("type", "")) == "shortcut":
			var text = child.get_text(0)
			var cat = category
			if edom != null:
				text = edom.translate(text)
				cat = edom.translate(cat)
			out.append({"id": String(child.get_meta("shortcut_identifier", "")), "name": text, "category": cat,
				"is_action": bool(child.get_meta("is_action", false)), "events": var_to_str(child.get_meta("events", []))})
		elif child.get_first_child() != null:
			_dump_shortcuts(child, child.get_text(0), edom, out)
		child = child.get_next()
"""

const PLUGIN_CFG := "[plugin]\nname=\"Godot Hub Settings Helper\"\ndescription=\"\"\nauthor=\"Godot Hub\"\nversion=\"1.0\"\nscript=\"plugin.gd\"\n"


## 성공하면 "", 실패하면 오류 메시지
static func open(inst: Dictionary) -> String:
	var r := _prepare(inst)
	if r.error != "":
		return r.error
	var pid := OS.create_process(r.exe, PackedStringArray(["--path", r.dir, "--editor"]))
	if pid <= 0:
		return L.t("에디터를 실행하지 못했어요.")
	return ""


## 허브 안 설정 창이 쓰는 설정 정보 캐시 파일 (버전 × 허브 언어마다 하나).
## 설정 이름 · 단축키 이름은 그 언어로 뽑아 둔다.
static func meta_path(inst: Dictionary, lang := "") -> String:
	if lang == "":
		lang = L.current
	var name := "%s.%s.json" % [str(inst.get("id", "unknown")).validate_filename(), lang]
	return Hub.data_dir.path_join("settings_meta").path_join(name)


## 캐시된 설정 정보. 없으면 빈 사전
static func load_meta(inst: Dictionary) -> Dictionary:
	var p := meta_path(inst)
	if not FileAccess.file_exists(p):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	return d if d is Dictionary else {}


## 설정 정보 뽑기를 시작한다 (그 버전 에디터를 화면 없이 실행). {pid, error}
static func start_dump(inst: Dictionary) -> Dictionary:
	var r := _prepare(inst)
	if r.error != "":
		return {"pid": 0, "error": r.error}
	var out := meta_path(inst)
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	if FileAccess.file_exists(out):
		DirAccess.remove_absolute(out)
	# --language: 사용자의 에디터 언어 설정은 그대로 두고, 이번 실행만 허브 언어로 띄워 그 언어 이름을 뽑는다
	var args := PackedStringArray(["--headless", "--editor", "--language", L.current, "--path", r.dir,
		"--", "--hub-dump=" + ProjectSettings.globalize_path(out)])
	var pid := OS.create_process(r.exe, args)
	if pid <= 0:
		return {"pid": 0, "error": L.t("에디터를 실행하지 못했어요.")}
	return {"pid": pid, "error": ""}


## 도우미 프로젝트를 준비한다. {exe, dir(전역 경로), error}
static func _prepare(inst: Dictionary) -> Dictionary:
	var exe := str(inst.get("exe", ""))
	if not FileAccess.file_exists(exe):
		return {"error": L.t("에디터 실행 파일을 찾을 수 없어요:\n") + exe}
	var v := GodotVersion.parse(inst.get("version", ""))
	if v.valid and v.major < 4:
		return {"error": L.t("Godot 3 이하 버전은 지원하지 않아요.")}
	var ver := ("%d.%d" % [v.major, v.minor]) if v.valid else "4.x"
	var dir := Hub.data_dir.path_join("settings_helper").path_join(ver + ("-mono" if inst.get("mono", false) else ""))
	var addon := dir.path_join("addons/godot_hub_settings")
	DirAccess.make_dir_recursive_absolute(addon)
	var project := "config_version=5\n\n[application]\n\nconfig/name=\"Godot Hub 설정 도우미\"\n"
	project += "config/features=PackedStringArray(\"%s\")\n\n" % ver
	project += "[editor_plugins]\n\nenabled=PackedStringArray(\"res://addons/godot_hub_settings/plugin.cfg\")\n"
	var ok := _write(dir.path_join("project.godot"), project) \
		and _write(addon.path_join("plugin.cfg"), PLUGIN_CFG) \
		and _write(addon.path_join("plugin.gd"), PLUGIN_SOURCE)
	if not ok:
		return {"error": L.t("도우미 프로젝트를 만들 수 없어요:\n") + dir}
	return {"exe": exe, "dir": ProjectSettings.globalize_path(dir), "error": ""}


static func _write(path: String, text: String) -> bool:
	if FileAccess.file_exists(path) and FileAccess.get_file_as_string(path) == text:
		return true
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true
