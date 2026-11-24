extends Node
## 내보내기 템플릿 설치 · 제거 테스트 (실제로 받는다).
## 실행: godot --headless --path . res://tests/test_templates.tscn -- --hub-data=<테스트 폴더> --test-exe=<독립 모드 에디터 exe> --test-version=4.0-stable [--test-mono]

var _inst := {}


func _ready() -> void:
	var version := "4.0-stable"
	var mono := false
	var exe := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-version="):
			version = arg.trim_prefix("--test-version=")
		elif arg == "--test-mono":
			mono = true
		elif arg.begins_with("--test-exe="):
			exe = Hub.normalize_path(arg.trim_prefix("--test-exe="))
	_inst = {"id": "tpl-test", "version": version, "mono": mono, "exe": exe}
	print("템플릿 폴더: ", Hub.templates_dir(_inst))
	print("주소: ", Hub.templates_url(_inst))
	_check("처음엔 없음", not Hub.has_templates(_inst))
	Downloads.install_templates(_inst)
	var last := -1
	while Downloads.is_active():
		await get_tree().create_timer(1.0).timeout
		for j in Downloads.jobs:
			var pct := int(j.progress * 100)
			if pct / 10 != last:
				last = pct / 10
				print("  %s %d%%" % [j.state, pct])
	for j in Downloads.jobs:
		if j.state == "error":
			print("오류: ", j.message)
	_check("설치됨 (version.txt)", Hub.has_templates(_inst))
	if Hub.has_templates(_inst):
		print("version.txt = ", FileAccess.get_file_as_string(Hub.templates_dir(_inst).path_join("version.txt")).strip_edges())
		print("파일 수 = ", DirAccess.get_files_at(Hub.templates_dir(_inst)).size())
	_check("제거", Hub.remove_templates(_inst) == "" and not Hub.has_templates(_inst))
	print("DONE")
	get_tree().quit()


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
