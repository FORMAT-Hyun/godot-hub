extends Node
## 에셋 스토어에서 프로젝트를 실제로 받아 새 프로젝트로 추가되는지 확인한다.
## 실행: godot --headless --path . res://tests/test_asset.tscn -- --hub-data=<테스트 폴더> --test-dest=<만들 폴더> [--test-asset=<에셋 id>]


func _ready() -> void:
	var id := "5610"
	var dest := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-asset="):
			id = arg.trim_prefix("--test-asset=")
		elif arg.begins_with("--test-dest="):
			dest = Hub.normalize_path(arg.trim_prefix("--test-dest="))
	var req := HTTPRequest.new()
	add_child(req)
	req.request(AssetStorePage.API + "/asset/" + id, AssetStorePage._headers())
	var res: Array = await req.request_completed
	var a: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	_check("에셋 정보", a is Dictionary and str(a.get("download_url", "")) != "")
	print("에셋: ", a.title, "  ", a.download_url)
	Downloads.install_asset(a, dest)
	while Downloads.is_active():
		await get_tree().create_timer(0.5).timeout
	for j in Downloads.jobs:
		if j.state == "error":
			print("오류: ", j.message)
	_check("project.godot 생김", FileAccess.file_exists(dest.path_join("project.godot")))
	_check("프로젝트 목록에 추가됨", Hub.find_project(dest) >= 0)
	_check("감싼 폴더 없이 바로 풀림", not DirAccess.get_files_at(dest).is_empty())
	print("DONE")
	get_tree().quit()


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
