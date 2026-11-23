extends Node
## 프로젝트 이름 바꾸기 · 태그 · 복제 · 누락 제거 테스트.
## 실행: godot --headless --path . res://tests/test_project_ops.tscn -- --hub-data=<테스트 폴더> --test-project=<프로젝트 폴더>

var _src := ""
var _finished := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-project="):
			_src = Hub.normalize_path(arg.trim_prefix("--test-project="))
	if Hub.find_project(_src) < 0:
		Hub.add_project(_src)
	_check("이름 바꾸기", Hub.rename_project(_src, "이름 \"바뀐\" 프로젝트") == "" and Hub.project_info(_src, true).name == "이름 \"바뀐\" 프로젝트")
	_check("태그", Hub.set_project_tags(_src, ["RPG", " 2d ", "rpg"]) == "" and Hub.project_info(_src, true).tags == ["2d", "rpg"])
	_check("태그 지우기", Hub.set_project_tags(_src, []) == "" and Hub.project_info(_src, true).tags.is_empty())
	Hub.set_project_tags(_src, ["demo"])
	print(FileAccess.get_file_as_string(_src.path_join("project.godot")))
	var dest := _src.get_base_dir().path_join("복제 테스트")
	var err := Hub.duplicate_project(_src, dest, "복제된 프로젝트")
	_check("복제 시작", err == "")
	Hub.projects_changed.connect(func() -> void:
		if Hub.find_project(dest) >= 0 and not _finished:
			_finished = true
			_check("복제 완료", Hub.project_info(dest, true).name == "복제된 프로젝트" and not DirAccess.dir_exists_absolute(dest.path_join(".godot")))
			Hub.projects.append({"path": "C:/없는/폴더", "editor": ""})
			_check("누락 제거", Hub.remove_missing_projects() == 1)
			print("DONE")
			get_tree().quit())
	get_tree().create_timer(30).timeout.connect(func() -> void:
		print("FAIL: 시간 초과")
		get_tree().quit(1))


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
