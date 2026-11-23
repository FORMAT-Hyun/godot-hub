extends Node
## 허브 안 에디터 설정 창 테스트: 목록 값·단축키를 저장한 뒤, 그 버전 에디터가 실제로 그 값을 읽는지 확인한다.
## 설정 파일이 없는 새 버전에서 정보 뽑기로 파일이 만들어지는지도 확인한다.
## 실행: godot --headless --path . res://tests/test_editor_settings.tscn -- --hub-data=<테스트 폴더> --test-exe=<독립 모드 에디터 exe> [--test-new-exe=<설정 파일 없는 독립 모드 exe>]

var _inst := {}
var _new_inst := {}
var _version := "4.7-stable"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-version="):
			_version = arg.trim_prefix("--test-version=")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-exe="):
			_inst = {"id": "test-es-" + _version, "version": _version, "exe": Hub.normalize_path(arg.trim_prefix("--test-exe="))}
		elif arg.begins_with("--test-new-exe="):
			_new_inst = {"id": "test-new-" + _version, "version": _version, "exe": Hub.normalize_path(arg.trim_prefix("--test-new-exe="))}
	print("버전 ", _version)
	var had_file := Hub.editor_settings_file(_inst) != ""
	var dlg := EditorSettingsDialog.new()
	add_child(dlg)
	dlg.open_for(_inst)
	await _wait_dump(dlg)
	if not had_file:
		_check("설정 파일 없던 버전: 파일 만들어짐", Hub.editor_settings_file(_inst) != "" and dlg._file.path != "")
	_check("정보 읽기 (설정 %d개, 단축키 %d개, 한국어 이름 %d개)" % [dlg._props.size(), dlg._shortcuts.size(), dlg._words.size()], not dlg._props.is_empty() and not dlg._shortcuts.is_empty())
	var tab: Dictionary = {}
	for p in dlg._props:
		if p.key == "text_editor/behavior/indent/type":
			tab = p
	_check("목록 항목", not tab.is_empty() and tab.hint == PROPERTY_HINT_ENUM and EditorSettingsDialog._enum_options(tab.type, tab.hint_string)[1][0] == "Spaces")
	if tab.is_empty():
		print("FAIL 설정을 못 찾음"); get_tree().quit(); return
	var new_val := 1 if int(tab.value) != 1 else 0
	dlg._set_change(tab, new_val)
	var ev := InputEventKey.new()
	ev.device = -1
	ev.keycode = KEY_K
	ev.ctrl_pressed = true
	ev.shift_pressed = true
	dlg._sc_changes["editor/save_scene"] = [ev]
	dlg._save()
	# 에디터로 다시 읽어서 확인
	DirAccess.remove_absolute(SettingsHelper.meta_path(_inst))
	dlg.open_for(_inst)
	await _wait_dump(dlg)
	for p in dlg._props:
		if p.key == "text_editor/behavior/indent/type":
			_check("목록 값 저장 (에디터가 읽음)", int(p.value) == new_val)
	var got := ""
	for s in dlg._meta.shortcuts:
		if s.id == "editor/save_scene":
			got = EditorSettingsDialog._events_text(str_to_var(s.events))
	_check("단축키 저장 (에디터가 읽음): " + got, got == "Ctrl+Shift+K")
	# 에디터가 다시 저장한 파일(SubResource 형식)에서도 읽히는지
	var file_text := FileAccess.get_file_as_string(dlg._file.path)
	var from_file := EditorSettingsDialog._events_text(dlg._sc_file.get("editor/save_scene", []))
	_check("에디터가 쓴 형식 읽기 (SubResource %s): %s" % [file_text.contains("SubResource("), from_file], from_file == "Ctrl+Shift+K")
	# 되돌리기
	for s in dlg._shortcuts:
		if s.id == "editor/save_scene":
			dlg._sc_changes[s.id] = false
	dlg._save()
	_check("단축키 되돌리기", not dlg._sc_file.has("editor/save_scene"))
	if not _new_inst.is_empty():
		var nd := EditorSettingsDialog.new()
		add_child(nd)
		_check("새 버전: 파일 없음", Hub.editor_settings_file(_new_inst) == "")
		nd.open_for(_new_inst)
		await _wait_dump(nd)
		_check("새 버전: 파일 만들어짐", Hub.editor_settings_file(_new_inst) != "" and not nd._props.is_empty())
	print("DONE")
	get_tree().quit()


func _wait_dump(dlg: EditorSettingsDialog) -> void:
	await get_tree().process_frame
	var t := 0
	while dlg._dump_pid > 0 and t < 1200:
		await get_tree().create_timer(0.1).timeout
		t += 1


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
