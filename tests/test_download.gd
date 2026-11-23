extends Node
## 다운로드 → 압축 해제 → 설치 등록까지 실제로 돌려 보는 테스트.
## 실행: godot --headless --path . res://tests/test_download.tscn -- --hub-data=<테스트 폴더> [--test-tag=2.0.3-stable]

var _tag := "2.0.3-stable"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-tag="):
			_tag = arg.trim_prefix("--test-tag=")
	get_tree().create_timer(300).timeout.connect(func() -> void:
		print("FAIL: 시간 초과")
		get_tree().quit(2))
	Releases.fetch_failed.connect(func(m: String) -> void:
		print("FAIL: ", m)
		get_tree().quit(1))
	Releases.releases_updated.connect(_on_releases, CONNECT_ONE_SHOT)
	Releases.refresh(false)


func _on_releases() -> void:
	print("릴리스 개수: ", Releases.releases.size())
	var rel := Releases.find(_tag)
	if rel.is_empty():
		print("FAIL: 릴리스 없음 ", _tag)
		get_tree().quit(1)
		return
	Downloads.jobs_changed.connect(_check)
	Downloads.install_editor(rel, false)


func _check() -> void:
	for j in Downloads.jobs:
		print("작업: ", j.title, " / ", j.state, " ", j.message)
		if j.state == "done":
			var inst := Hub.find_install_by_version(_tag, false)
			print("OK: 설치됨 ", inst.get("exe", "?"), "  독립모드=", Hub.is_self_contained(inst))
			get_tree().quit(0)
		elif j.state == "error":
			print("FAIL: ", j.message)
			get_tree().quit(1)
