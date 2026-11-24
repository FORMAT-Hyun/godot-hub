extends Node
## 오토로드 "Downloads": 에디터 · 내보내기 템플릿 다운로드 큐 (한 번에 하나씩)

signal jobs_changed
signal job_updated(job: Dictionary)

const ACTIVE_STATES := ["queued", "downloading", "extracting"]

## {id, kind("editor" | "templates" | "asset"), tag, mono, url, size, file, title, state, progress, downloaded, message, tmp}
var jobs: Array = []

var _current: Dictionary = {}
var _http: HTTPRequest
var _thread: Thread
var _next_id := 1
var _tick := 0.0


func _ready() -> void:
	set_process(false)


func _exit_tree() -> void:
	if _http:
		_http.cancel_request()
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


func is_active() -> bool:
	for j in jobs:
		if ACTIVE_STATES.has(j.state):
			return true
	return false


func is_busy_with(tag: String, mono: bool, kind: String) -> bool:
	for j in jobs:
		if j.tag == tag and j.mono == mono and j.kind == kind and ACTIVE_STATES.has(j.state):
			return true
	return false


## 설치된 에디터의 내보내기 템플릿(.tpz)을 받아 그 에디터가 찾는 폴더에 풀어 준다
func install_templates(inst: Dictionary) -> void:
	var tag := str(inst.get("version", ""))
	var mono := bool(inst.get("mono", false))
	if tag == "" or not GodotVersion.parse(tag).valid:
		Hub.toast.emit(L.t("버전을 알 수 없는 에디터라 템플릿을 받을 수 없어요"))
		return
	if is_busy_with(tag, mono, "templates"):
		return
	var url := Hub.templates_url(inst)
	_enqueue("templates", tag, mono, {"url": url, "name": url.get_file(), "size": 0, "dest": Hub.templates_dir(inst)})


## 에셋 라이브러리의 프로젝트(템플릿 · 데모)를 받아 dest 폴더에 새 프로젝트로 풀고 목록에 추가한다
func install_asset(asset: Dictionary, dest: String) -> void:
	var url := str(asset.get("download_url", ""))
	if url == "":
		Hub.toast.emit(L.t("다운로드 주소가 없는 에셋이에요"))
		return
	var tag := "asset-" + str(asset.get("asset_id", ""))
	if is_busy_with(tag, false, "asset"):
		return
	_enqueue("asset", tag, false, {"url": url, "name": tag + ".zip", "size": 0,
		"title": str(asset.get("title", tag)), "dest": Hub.normalize_path(dest)})


func install_editor(release: Dictionary, mono: bool) -> void:
	var tag: String = release.get("tag", "")
	var assets: Dictionary = release.get("assets", {})
	var asset: Dictionary = assets.get("mono" if mono else "std", {})
	if asset.is_empty():
		Hub.toast.emit(L.t("이 버전에는 Windows용 %s 빌드가 없어요") % (".NET" if mono else L.t("표준")))
		return
	if not Hub.find_install_by_version(tag, mono).is_empty():
		Hub.toast.emit(L.t("이미 설치된 버전이에요"))
	elif not is_busy_with(tag, mono, "editor"):
		_enqueue("editor", tag, mono, asset)


func cancel(id: int) -> void:
	for j in jobs:
		if j.id != id:
			continue
		match j.state:
			"queued":
				j.state = "canceled"
			"downloading":
				if _http:
					_http.cancel_request()
					_http.queue_free()
					_http = null
				set_process(false)
				j.state = "canceled"
				if j.has("tmp"):
					DirAccess.remove_absolute(j.tmp)
				_current = {}
				call_deferred("_start_next")
	jobs_changed.emit()


func dismiss(id: int) -> void:
	for j in jobs:
		if j.id == id and not ACTIVE_STATES.has(j.state):
			jobs.erase(j)
			jobs_changed.emit()
			return


func _enqueue(kind: String, tag: String, mono: bool, asset: Dictionary) -> void:
	var job := {
		"id": _next_id, "kind": kind, "tag": tag, "mono": mono,
		"url": asset.get("url", ""), "size": int(asset.get("size", 0)), "file": asset.get("name", ""),
		"state": "queued", "progress": 0.0, "downloaded": 0, "message": "",
	}
	job["title"] = str(asset.get("title", "Godot %s%s%s" % [tag, " .NET" if mono else "", L.t(" 템플릿") if kind == "templates" else ""]))
	if asset.has("dest"):
		job["dest"] = asset.dest
		# 실패했을 때 지워도 되는지: 받기 전에 비어 있던(없던) 폴더만 지운다
		job["dest_was_empty"] = _is_empty_dir(asset.dest)
	_next_id += 1
	jobs.append(job)
	jobs_changed.emit()
	_start_next()


func _start_next() -> void:
	if not _current.is_empty():
		return
	for j in jobs:
		if j.state == "queued":
			_current = j
			break
	if _current.is_empty():
		return
	var tmp_dir := str(Hub.settings.install_dir).path_join("_downloads")
	DirAccess.make_dir_recursive_absolute(tmp_dir)
	_current["tmp"] = tmp_dir.path_join(str(_current.file) + ".part")
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.download_file = _current.tmp
	_http.download_chunk_size = 256 * 1024
	_http.request_completed.connect(_on_downloaded)
	add_child(_http)
	var err := _http.request(_current.url, PackedStringArray(["User-Agent: GodotHub-Launcher"]))
	if err != OK:
		_http.queue_free()
		_http = null
		_fail(_current, L.t("다운로드를 시작하지 못했어요 (%s)") % error_string(err))
		return
	_current.state = "downloading"
	_tick = 1.0
	set_process(true)
	jobs_changed.emit()


func _process(delta: float) -> void:
	if _current.is_empty() or _http == null or _current.state != "downloading":
		return
	_tick += delta
	if _tick < 0.25:
		return
	_tick = 0.0
	var total: int = _current.size
	if _http.get_body_size() > 0:
		total = _http.get_body_size()
	var got := _http.get_downloaded_bytes()
	_current.downloaded = got
	_current.size = total
	_current.progress = clampf(float(got) / total, 0.0, 1.0) if total > 0 else -1.0
	job_updated.emit(_current)


func _on_downloaded(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	set_process(false)
	var job := _current
	if _http:
		_http.queue_free()
		_http = null
	if job.is_empty() or job.state != "downloading":
		return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		var why := ("HTTP %d" % code) if code > 0 else (L.t("네트워크 오류 %d") % result)
		if code == 404 and job.kind == "templates":
			why = L.t("이 버전은 공식 템플릿 파일이 없어요")
		DirAccess.remove_absolute(job.tmp)
		_fail(job, L.t("다운로드 실패 (%s)") % why)
		return
	job.state = "extracting"
	job.progress = 0.0
	jobs_changed.emit()
	_thread = Thread.new()
	if job.kind == "templates":
		_thread.start(_extract_templates.bind(job.tmp, job.dest))
		return
	if job.kind == "asset":
		_thread.start(_extract_asset.bind(job.tmp, job.dest))
		return
	job["dest"] = Hub.editor_install_dir(job.tag, job.mono)
	job["dest_was_empty"] = _is_empty_dir(job.dest)
	_thread.start(_extract_editor.bind(job.tmp, job.dest))


# ── 작업 스레드에서 실행된다 ──

func _extract_editor(zip_path: String, dest: String) -> Dictionary:
	var zr := ZIPReader.new()
	if zr.open(zip_path) != OK:
		return _done({"ok": false, "msg": L.t("압축 파일이 손상됐어요. 다시 받아 주세요.")})
	DirAccess.make_dir_recursive_absolute(dest)
	var files := zr.get_files()
	for i in files.size():
		var name := files[i]
		if name.split("/").has(".."):
			continue
		var out := dest.path_join(name)
		if name.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(out)
			continue
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f == null:
			zr.close()
			return _done({"ok": false, "msg": L.t("파일을 쓸 수 없어요:\n") + out})
		f.store_buffer(zr.read_file(name))
		f.close()
		if i % 10 == 0:
			call_deferred("_on_extract_progress", float(i) / files.size())
	zr.close()
	return _done({"ok": true})


## 에셋 zip에서 project.godot가 있는 폴더를 찾아 그 안의 내용만 dest에 푼다
## (GitHub 압축 파일은 보통 "저장소-커밋/" 폴더 하나로 감싸져 있다)
func _extract_asset(zip_path: String, dest: String) -> Dictionary:
	var zr := ZIPReader.new()
	if zr.open(zip_path) != OK:
		return _done({"ok": false, "msg": L.t("압축 파일이 손상됐어요. 다시 받아 주세요.")})
	var files := zr.get_files()
	var prefix := ""
	var best := 1 << 30
	for name in files:
		if name.get_file() == "project.godot" and name.count("/") < best:
			best = name.count("/")
			prefix = name.get_base_dir()
			if prefix != "":
				prefix += "/"
	if best == 1 << 30:
		zr.close()
		return _done({"ok": false, "msg": L.t("이 에셋에는 project.godot가 없어서 프로젝트로 열 수 없어요")})
	DirAccess.make_dir_recursive_absolute(dest)
	for i in files.size():
		var name := files[i]
		if not name.begins_with(prefix) or name.ends_with("/") or name.split("/").has(".."):
			continue
		var out := dest.path_join(name.substr(prefix.length()))
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f == null:
			zr.close()
			return _done({"ok": false, "msg": L.t("파일을 쓸 수 없어요:\n") + out})
		f.store_buffer(zr.read_file(name))
		f.close()
		if i % 10 == 0:
			call_deferred("_on_extract_progress", float(i + 1) / files.size())
	zr.close()
	return _done({"ok": true})


## .tpz 안의 templates/ 폴더 내용을 dest에 바로 푼다
func _extract_templates(tpz_path: String, dest: String) -> Dictionary:
	var zr := ZIPReader.new()
	if zr.open(tpz_path) != OK:
		return _done({"ok": false, "msg": L.t("템플릿 파일이 손상됐어요. 다시 받아 주세요.")})
	var files := zr.get_files()
	DirAccess.make_dir_recursive_absolute(dest)
	for i in files.size():
		var name := files[i]
		if name.split("/").has("..") or name.ends_with("/"):
			continue
		var rel := name.trim_prefix("templates/")
		var out := dest.path_join(rel)
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f == null:
			zr.close()
			return _done({"ok": false, "msg": L.t("파일을 쓸 수 없어요:\n") + out})
		f.store_buffer(zr.read_file(name))
		f.close()
		call_deferred("_on_extract_progress", float(i + 1) / files.size())
	zr.close()
	if not FileAccess.file_exists(dest.path_join("version.txt")):
		return _done({"ok": false, "msg": L.t("템플릿 파일 안에 version.txt가 없어요")})
	return _done({"ok": true})


func _done(res: Dictionary) -> Dictionary:
	call_deferred("_on_extract_done", res)
	return res


# ── 다시 메인 스레드 ──

func _on_extract_progress(p: float) -> void:
	if not _current.is_empty() and _current.state == "extracting":
		_current.progress = p
		job_updated.emit(_current)


func _on_extract_done(res: Dictionary) -> void:
	if _thread:
		_thread.wait_to_finish()
		_thread = null
	var job := _current
	if job.is_empty():
		return
	DirAccess.remove_absolute(job.tmp)
	if not res.get("ok", false):
		if job.get("dest_was_empty", false) and str(job.get("dest", "")) != "":
			_remove_dir(str(job.dest))
		_fail(job, str(res.get("msg", L.t("설치 실패"))))
		return
	if job.kind == "asset":
		job.state = "done"
		job.progress = 1.0
		Hub.add_project(job.dest)
		Hub.toast.emit(L.t("'%s' 프로젝트를 추가했어요") % job.title)
		_finish_current()
		get_tree().create_timer(8.0).timeout.connect(dismiss.bind(int(job.id)))
		return
	if job.kind == "templates":
		job.state = "done"
		job.progress = 1.0
		Hub.toast.emit(L.t("%s 설치 완료") % job.title)
		Hub.installs_changed.emit()
		_finish_current()
		get_tree().create_timer(8.0).timeout.connect(dismiss.bind(int(job.id)))
		return
	var exe := Hub.find_editor_exe(job.dest)
	if exe == "":
		_fail(job, L.t("압축을 풀었지만 실행 파일을 찾지 못했어요"))
		return
	if Hub.settings.get("self_contained", true):
		var f := FileAccess.open(exe.get_base_dir().path_join("._sc_"), FileAccess.WRITE)
		if f:
			f.close()
	Hub.add_install({"version": job.tag, "mono": job.mono, "path": job.dest, "exe": exe, "managed": true})
	job.state = "done"
	job.progress = 1.0
	Hub.toast.emit(L.t("%s 설치 완료") % job.title)
	_finish_current()
	var id: int = job.id
	get_tree().create_timer(8.0).timeout.connect(dismiss.bind(id))


static func _is_empty_dir(dir: String) -> bool:
	if not DirAccess.dir_exists_absolute(dir):
		return true
	return DirAccess.get_files_at(dir).is_empty() and DirAccess.get_directories_at(dir).is_empty()


## 반쯤 풀린 폴더 지우기 (실패했을 때만)
static func _remove_dir(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_remove_dir(dir.path_join(d))
	DirAccess.remove_absolute(dir)


func _fail(job: Dictionary, message: String) -> void:
	job.state = "error"
	job.message = message
	if is_same(job, _current):
		_finish_current()
	else:
		jobs_changed.emit()


func _finish_current() -> void:
	_current = {}
	jobs_changed.emit()
	_start_next()
