extends Node
## 새 프로젝트 창으로 프로젝트를 만들어 project.godot 내용을 확인한다.
## 실행: godot --headless --path . res://tests/test_new_project.tscn -- --hub-data=<테스트 폴더> --test-exe=<에디터 exe> --test-dir=<만들 위치>


func _ready() -> void:
	var exe := ""
	var dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-exe="):
			exe = arg.trim_prefix("--test-exe=")
		elif arg.begins_with("--test-dir="):
			dir = Hub.normalize_path(arg.trim_prefix("--test-dir="))
	if Hub.installs.is_empty():
		Hub.register_exe(exe)
	DirAccess.make_dir_recursive_absolute(dir)
	var d := NewProjectDialog.new()
	add_child(d)
	d.popup_centered()
	await get_tree().process_frame
	# 1) 폴더 만들기 켜짐 + Mobile + Git
	d._path_edit.text = dir
	d._name_edit.text = "My Mobile Game"
	d._select_renderer("mobile")
	d._vcs_opt.select(1)
	d._validate()
	d._create()
	var p1 := dir.path_join("My Mobile Game")
	var t1 := FileAccess.get_file_as_string(p1.path_join("project.godot"))
	_check("폴더 만들기: 하위 폴더에 생성", FileAccess.file_exists(p1.path_join("project.godot")))
	_check("Mobile 렌더러", t1.contains("\"Mobile\"") and t1.contains("rendering_method=\"mobile\""))
	_check("Git 파일", FileAccess.file_exists(p1.path_join(".gitignore")))
	_check("목록에 추가", Hub.find_project(p1) >= 0)
	# 2) 폴더 만들기 꺼짐 + Compatibility: 고른 폴더 그 자체에 생성
	var p2 := dir.path_join("empty_target")
	DirAccess.make_dir_recursive_absolute(p2)
	d.popup_centered()
	await get_tree().process_frame
	d._path_edit.text = p2
	d._create_folder.button_pressed = false
	d._name_edit.text = "Web Game"
	d._select_renderer("compat")
	d._validate()
	d._create()
	var t2 := FileAccess.get_file_as_string(p2.path_join("project.godot"))
	_check("폴더 만들기 꺼짐: 고른 폴더에 생성", t2.contains("config/name=\"Web Game\""))
	_check("Compatibility 렌더러", t2.contains("gl_compatibility"))
	# 3) 비어 있지 않은 폴더는 막는다
	d.popup_centered()
	await get_tree().process_frame
	d._path_edit.text = p2
	d._create_folder.button_pressed = false
	d._name_edit.text = "X"
	_check("비어 있지 않은 폴더 막음", d._validate() != "")
	print("DONE")
	get_tree().quit()


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
