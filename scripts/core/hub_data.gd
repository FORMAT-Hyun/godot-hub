extends Node
## 오토로드 "Hub": 설정 · 설치된 에디터 · 프로젝트 목록을 저장하고 관리한다.

signal projects_changed
signal installs_changed
signal settings_changed
signal running_changed
signal toast(message: String)

const HUB_VERSION := "0.1.3"
const SCAN_MAX_DEPTH := 5
const SCAN_SKIP := ["node_modules", "$RECYCLE.BIN", "System Volume Information", "Windows",
	"Program Files", "Program Files (x86)", "AppData", "Library", "build", "addons"]

const NEW_PROJECT_HEADER := "; Engine configuration file.\n; It's best edited using the editor UI and not directly,\n; since the parameters that go here are not all obvious.\n;\n; Format:\n;   [section] ; section goes between []\n;   param=value ; assign values to parameters\n\n"

var data_dir := "user://hub_data"
var settings: Dictionary = {}
var installs: Array = []
var projects: Array = []
## 허브에서 연 에디터: 프로젝트 경로 -> PID
var running: Dictionary = {}

var _info_cache: Dictionary = {}
var _icon_cache: Dictionary = {}
var _scan_thread: Thread
var _copy_thread: Thread


func _enter_tree() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hub-data="):
			data_dir = arg.trim_prefix("--hub-data=")
	DirAccess.make_dir_recursive_absolute(data_dir.path_join("cache"))
	settings = default_settings()
	var s: Variant = _read_json("settings.json")
	if s is Dictionary:
		settings.merge(s, true)
	var i: Variant = _read_json("installs.json")
	if i is Array:
		installs = i
	var p: Variant = _read_json("projects.json")
	if p is Array:
		projects = p


func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = 2.0
	timer.autostart = true
	timer.timeout.connect(_poll_running)
	add_child(timer)


func _exit_tree() -> void:
	if _scan_thread and _scan_thread.is_started():
		_scan_thread.wait_to_finish()
	if _copy_thread and _copy_thread.is_started():
		_copy_thread.wait_to_finish()


# ─────────────────────────── 설정 ───────────────────────────

func default_settings() -> Dictionary:
	var base := OS.get_environment("LOCALAPPDATA")
	if base == "":
		base = OS.get_user_data_dir()
	return {
		"install_dir": normalize_path(base.path_join("GodotHub").path_join("Editors")),
		"project_dir": normalize_path(OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join("Godot Projects")),
		"after_launch": 0,  # 0: 그대로, 1: 최소화, 2: 허브 종료
		"self_contained": true,
		"github_token": "",
		"sort": 0,
		"default_editor": "",
		"ui_scale": 0.0,  # 0 = 자동
		"editor_settings_mode": 0,  # 0: 허브 안 설정 창, 1: 고도 에디터의 설정 창
	}


func save_settings() -> void:
	_write_json("settings.json", settings)
	settings_changed.emit()


# ─────────────────────────── 경로 ───────────────────────────

static func normalize_path(path: String) -> String:
	var p := path.strip_edges().replace("\\", "/").simplify_path()
	if p.length() > 3 and p.ends_with("/"):
		p = p.trim_suffix("/")
	return p


static func same_path(a: String, b: String) -> bool:
	return normalize_path(a).to_lower() == normalize_path(b).to_lower()


# ─────────────────────────── 에디터(설치) ───────────────────────────

func find_install(id: String) -> Dictionary:
	if id == "":
		return {}
	for inst in installs:
		if inst.get("id", "") == id:
			return inst
	return {}


func find_install_by_version(tag: String, mono: bool) -> Dictionary:
	for inst in installs:
		if inst.get("version", "") == tag and bool(inst.get("mono", false)) == mono:
			return inst
	return {}


func install_label(inst: Dictionary) -> String:
	var s: String = inst.get("version", "?")
	if s == "":
		s = "알 수 없는 버전"
	if inst.get("mono", false):
		s += " .NET"
	return s


## 최신 버전이 앞에 오도록 정렬한 복사본
func sorted_installs() -> Array:
	var arr := installs.duplicate()
	arr.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var c := GodotVersion.compare(a.get("version", ""), b.get("version", ""))
		if c != 0:
			return c > 0
		return not bool(a.get("mono", false)) and bool(b.get("mono", false)))
	return arr


func editor_install_dir(tag: String, mono: bool) -> String:
	return normalize_path(str(settings.install_dir).path_join(tag + ("-mono" if mono else "")))


func add_install(rec: Dictionary) -> Dictionary:
	var base_id := "%s%s" % [rec.get("version", "custom"), "-mono" if rec.get("mono", false) else ""]
	var id := base_id
	var n := 2
	while not find_install(id).is_empty():
		id = "%s-%d" % [base_id, n]
		n += 1
	rec["id"] = id
	if not rec.has("added"):
		rec["added"] = int(Time.get_unix_time_from_system())
	installs.append(rec)
	# 에디터가 지정되지 않은 프로젝트에 새 에디터를 자동으로 연결
	for proj in projects:
		if find_install(proj.get("editor", "")).is_empty():
			proj["editor"] = best_install_for(project_info(proj.path))
	if str(settings.get("default_editor", "")) == "" and GodotVersion.is_stable(str(rec.get("version", ""))):
		settings.default_editor = id
		_write_json("settings.json", settings)
	_save_installs()
	_save_projects()
	installs_changed.emit()
	projects_changed.emit()
	return rec


## delete_files: 허브가 받은 에디터면 설치 폴더를 휴지통으로 옮긴다
func remove_install(id: String, delete_files: bool) -> String:
	var inst := find_install(id)
	if inst.is_empty():
		return ""
	if delete_files and inst.get("managed", false):
		var dir: String = inst.get("path", "")
		if DirAccess.dir_exists_absolute(dir):
			var err := OS.move_to_trash(ProjectSettings.globalize_path(dir))
			if err != OK:
				return "설치 폴더를 휴지통으로 옮기지 못했어요 (%s).\n에디터가 실행 중이면 닫고 다시 시도해 주세요." % error_string(err)
	installs.erase(inst)
	if settings.get("default_editor", "") == id:
		settings.default_editor = ""
		_write_json("settings.json", settings)
	_save_installs()
	installs_changed.emit()
	projects_changed.emit()
	return ""


func set_default_install(id: String) -> void:
	settings.default_editor = id
	save_settings()
	installs_changed.emit()


## 받은(등록한) 시각. 예전 기록에는 없으므로 실행 파일의 수정 시각으로 대신한다
func install_added(inst: Dictionary) -> int:
	var t := int(inst.get("added", 0))
	if t <= 0 and FileAccess.file_exists(str(inst.get("exe", ""))):
		t = int(FileAccess.get_modified_time(str(inst.get("exe", ""))))
	return t


func is_self_contained(inst: Dictionary) -> bool:
	var d := str(inst.get("exe", "")).get_base_dir()
	return FileAccess.file_exists(d.path_join("._sc_")) or FileAccess.file_exists(d.path_join("_sc_"))


## 그 에디터가 설정(editor_settings-*.tres)을 저장하는 폴더
## 독립 모드면 exe 옆 editor_data, 아니면 %APPDATA%\Godot
func editor_settings_dir(inst: Dictionary) -> String:
	if is_self_contained(inst):
		return str(inst.get("exe", "")).get_base_dir().path_join("editor_data")
	return normalize_path(OS.get_config_dir().path_join("Godot"))


## 그 버전의 에디터 설정 파일. 아직 에디터를 한 번도 안 열었으면 ""
func editor_settings_file(inst: Dictionary) -> String:
	var dir := editor_settings_dir(inst)
	var v := GodotVersion.parse(inst.get("version", ""))
	# 4.3 이후: editor_settings-4.3.tres, 이전: editor_settings-4.tres
	for name in ["editor_settings-%d.%d.tres" % [v.major, v.minor], "editor_settings-%d.tres" % v.major]:
		if FileAccess.file_exists(dir.path_join(name)):
			return dir.path_join(name)
	return ""


func set_self_contained(inst: Dictionary, enabled: bool) -> void:
	var d := str(inst.get("exe", "")).get_base_dir()
	if enabled:
		var f := FileAccess.open(d.path_join("._sc_"), FileAccess.WRITE)
		if f == null:
			toast.emit("독립 모드 파일을 만들 수 없어요 (권한을 확인해 주세요)")
			return
		f.close()
	else:
		for n in ["._sc_", "_sc_"]:
			if FileAccess.file_exists(d.path_join(n)):
				DirAccess.remove_absolute(d.path_join(n))
	installs_changed.emit()


func projects_using(id: String) -> int:
	var n := 0
	for proj in projects:
		if proj.get("editor", "") == id:
			n += 1
	return n


func find_editor_exe(dir: String) -> String:
	var found: Array = []
	_collect_exe(dir, found, 0)
	for exe in found:
		if str(exe).get_file().to_lower().begins_with("godot"):
			return exe
	return found[0] if not found.is_empty() else ""


func _collect_exe(dir: String, out: Array, depth: int) -> void:
	for f in DirAccess.get_files_at(dir):
		var lower := f.to_lower()
		if lower.ends_with(".exe") and not lower.contains("_console"):
			out.append(dir.path_join(f))
	if depth < 2:
		for sub in DirAccess.get_directories_at(dir):
			_collect_exe(dir.path_join(sub), out, depth + 1)


## 파일 이름에서 버전을 읽고, 안 되면 실행해서(--version) 알아낸다
func detect_version(exe: String) -> Dictionary:
	var re := RegEx.create_from_string("(?i)godot_v(\\d+(?:\\.\\d+)+-[a-z]+\\d*)(_mono)?")
	for s in [exe.get_file(), exe.get_base_dir().get_file()]:
		var m := re.search(s)
		if m:
			return {"version": m.get_string(1).to_lower(), "mono": m.get_string(2) != "" or _has_godotsharp(exe)}
	var console := exe.get_basename() + "_console.exe"
	var target := console if FileAccess.file_exists(console) else exe
	var out: Array = []
	if OS.execute(target, PackedStringArray(["--version"]), out, true) == 0 and not out.is_empty():
		var lines := str(out[0]).strip_edges().split("\n")
		var parts := lines[lines.size() - 1].strip_edges().split(".")
		var nums: Array = []
		var channel := ""
		for part in parts:
			if part.is_valid_int() and channel == "":
				nums.append(part)
			elif channel == "":
				channel = part
		if nums.size() >= 2 and channel != "":
			return {"version": ".".join(nums) + "-" + channel, "mono": parts.has("mono")}
	return {"version": "", "mono": _has_godotsharp(exe)}


func _has_godotsharp(exe: String) -> bool:
	return DirAccess.dir_exists_absolute(exe.get_base_dir().path_join("GodotSharp"))


## "위치 지정": 이미 PC에 있는 고도 실행 파일을 등록
func register_exe(path: String) -> String:
	var exe := normalize_path(path)
	if exe.to_lower().ends_with("_console.exe"):
		var gui := exe.substr(0, exe.length() - "_console.exe".length()) + ".exe"
		if FileAccess.file_exists(gui):
			exe = gui
	if not FileAccess.file_exists(exe):
		return "파일을 찾을 수 없어요:\n" + exe
	for inst in installs:
		if same_path(inst.get("exe", ""), exe):
			return "이미 등록된 에디터예요."
	var v := detect_version(exe)
	add_install({"version": v.version, "mono": v.mono, "path": exe.get_base_dir(), "exe": exe, "managed": false})
	toast.emit("%s 를 등록했어요" % install_label(v))
	return ""


# ─────────────────────────── 프로젝트 ───────────────────────────

func find_project(path: String) -> int:
	for i in projects.size():
		if same_path(projects[i].get("path", ""), path):
			return i
	return -1


func get_project(path: String) -> Dictionary:
	var i := find_project(path)
	return projects[i] if i >= 0 else {}


func project_info(path: String, refresh := false) -> Dictionary:
	if refresh or not _info_cache.has(path):
		_info_cache[path] = ProjectReader.read(path)
	return _info_cache[path]


func project_icon(path: String) -> Texture2D:
	var icon_path: String = project_info(path).get("icon", "")
	if icon_path == "":
		return null
	var key := "%s|%d" % [icon_path, FileAccess.get_modified_time(icon_path)]
	if not _icon_cache.has(key):
		_icon_cache[key] = ProjectReader.load_icon(icon_path, 80)
	return _icon_cache[key]


func project_modified(path: String) -> int:
	var rec := get_project(path)
	return maxi(ProjectReader.modified_time(path), int(rec.get("last_opened", 0)))


func refresh_infos() -> void:
	_info_cache.clear()
	projects_changed.emit()


func add_project(dir: String, save_now := true) -> bool:
	dir = normalize_path(dir)
	if not FileAccess.file_exists(dir.path_join("project.godot")):
		return false
	if find_project(dir) >= 0:
		return false
	var info := project_info(dir, true)
	projects.append({
		"path": dir, "editor": best_install_for(info), "favorite": false,
		"last_opened": 0, "added": int(Time.get_unix_time_from_system()),
	})
	if save_now:
		_save_projects()
		projects_changed.emit()
	return true


func remove_project(path: String) -> void:
	var i := find_project(path)
	if i >= 0:
		projects.remove_at(i)
		_save_projects()
		projects_changed.emit()


## 프로젝트 이름 바꾸기 (고도처럼 project.godot 의 config/name 만 바꾸고 폴더는 그대로)
func rename_project(path: String, new_name: String) -> String:
	var err := ProjectReader.set_application_value(path, "config/name", ProjectReader.quote(new_name))
	if err != OK:
		return "이름을 바꾸지 못했어요 (%s)" % error_string(err)
	_info_cache.erase(path)
	projects_changed.emit()
	return ""


## 태그 설정 (project.godot 의 config/tags, 고도처럼 소문자 · 정렬)
func set_project_tags(path: String, tags: Array) -> String:
	var clean: Array = []
	for t in tags:
		var s := str(t).strip_edges().to_lower().replace(" ", "_")
		if s != "" and not clean.has(s):
			clean.append(s)
	clean.sort()
	var raw := ""
	if not clean.is_empty():
		raw = "PackedStringArray(%s)" % ", ".join(clean.map(func(s: String) -> String: return ProjectReader.quote(s)))
	var err := ProjectReader.set_application_value(path, "config/tags", raw)
	if err != OK:
		return "태그를 저장하지 못했어요 (%s)" % error_string(err)
	_info_cache.erase(path)
	projects_changed.emit()
	return ""


## 목록에서 제거. delete_files 면 프로젝트 폴더를 휴지통으로 옮긴다.
func erase_project(path: String, delete_files: bool) -> String:
	if delete_files and DirAccess.dir_exists_absolute(path):
		var err := OS.move_to_trash(ProjectSettings.globalize_path(path))
		if err != OK:
			return "프로젝트 폴더를 휴지통으로 옮기지 못했어요 (%s).\n에디터에서 열려 있으면 닫고 다시 시도해 주세요." % error_string(err)
	remove_project(path)
	return ""


## project.godot 가 사라진 프로젝트를 목록에서 모두 뺀다. 뺀 개수를 돌려준다.
func remove_missing_projects() -> int:
	var before := projects.size()
	projects = projects.filter(func(p: Dictionary) -> bool:
		return FileAccess.file_exists(str(p.get("path", "")).path_join("project.godot")))
	var removed := before - projects.size()
	if removed > 0:
		_save_projects()
		projects_changed.emit()
	return removed


func missing_project_count() -> int:
	var n := 0
	for p in projects:
		if not FileAccess.file_exists(str(p.get("path", "")).path_join("project.godot")):
			n += 1
	return n


## 프로젝트 복제: 폴더를 통째로 복사(.godot 캐시 제외)하고 이름을 바꿔 목록에 추가. 스레드에서 복사한다.
func duplicate_project(src: String, dest: String, new_name: String) -> String:
	src = normalize_path(src)
	dest = normalize_path(dest)
	if DirAccess.dir_exists_absolute(dest) and (DirAccess.get_files_at(dest).size() + DirAccess.get_directories_at(dest).size()) > 0:
		return "같은 이름의 폴더가 이미 있고 비어 있지 않아요:\n" + dest
	if (dest.to_lower() + "/").begins_with(src.to_lower() + "/"):
		return "프로젝트 폴더 안으로는 복제할 수 없어요."
	if _copy_thread and _copy_thread.is_alive():
		return "이미 다른 프로젝트를 복제하는 중이에요."
	if _copy_thread and _copy_thread.is_started():
		_copy_thread.wait_to_finish()
	_copy_thread = Thread.new()
	_copy_thread.start(_copy_worker.bind(src, dest, new_name, str(get_project(src).get("editor", ""))))
	toast.emit("'%s' 복제 중..." % new_name)
	return ""


func _copy_worker(src: String, dest: String, new_name: String, editor: String) -> void:
	var err := _copy_dir(src, dest)
	call_deferred("_copy_done", err, dest, new_name, editor)


func _copy_dir(src: String, dest: String) -> Error:
	var err := DirAccess.make_dir_recursive_absolute(dest)
	if err != OK:
		return err
	for f in DirAccess.get_files_at(src):
		err = DirAccess.copy_absolute(src.path_join(f), dest.path_join(f))
		if err != OK:
			return err
	for d in DirAccess.get_directories_at(src):
		if d == ".godot":
			continue
		err = _copy_dir(src.path_join(d), dest.path_join(d))
		if err != OK:
			return err
	return OK


func _copy_done(err: Error, dest: String, new_name: String, editor: String) -> void:
	_copy_thread.wait_to_finish()
	_copy_thread = null
	if err != OK:
		toast.emit("복제하지 못했어요 (%s)" % error_string(err))
		return
	ProjectReader.set_application_value(dest, "config/name", ProjectReader.quote(new_name))
	projects.append({
		"path": dest, "editor": editor, "favorite": false,
		"last_opened": 0, "added": int(Time.get_unix_time_from_system()),
	})
	_info_cache.erase(dest)
	_save_projects()
	projects_changed.emit()
	toast.emit("'%s'(으)로 복제했어요" % new_name)


func set_project_editor(path: String, id: String) -> void:
	var rec := get_project(path)
	if rec.is_empty():
		return
	rec["editor"] = id
	_save_projects()
	projects_changed.emit()


func toggle_favorite(path: String) -> void:
	var rec := get_project(path)
	if rec.is_empty():
		return
	rec["favorite"] = not bool(rec.get("favorite", false))
	_save_projects()
	projects_changed.emit()


## 프로젝트에 가장 잘 맞는 설치 에디터 id ("" = 맞는 게 없음)
func best_install_for(info: Dictionary) -> String:
	if installs.is_empty():
		return ""
	var want_mono: bool = info.get("csharp", false)
	var cands := sorted_installs()
	var mono_match := cands.filter(func(i: Dictionary) -> bool: return bool(i.get("mono", false)) == want_mono)
	if not mono_match.is_empty():
		cands = mono_match
	var parts := str(info.get("version", "")).split(".")
	var major := parts[0].to_int() if parts.size() >= 1 and parts[0].is_valid_int() else -1
	var minor := parts[1].to_int() if parts.size() >= 2 and parts[1].is_valid_int() else -1
	if major < 0:
		var def := find_install(settings.get("default_editor", ""))
		return def.id if not def.is_empty() else _prefer_stable(cands).get("id", "")
	var same := cands.filter(func(i: Dictionary) -> bool:
		var v := GodotVersion.parse(i.get("version", ""))
		return v.major == major and (minor < 0 or v.minor == minor))
	if not same.is_empty():
		return _prefer_stable(same).get("id", "")
	# 같은 메이저 안에서 가장 가까운 상위 버전
	var newer := cands.filter(func(i: Dictionary) -> bool:
		var v := GodotVersion.parse(i.get("version", ""))
		return v.major == major and v.minor > minor)
	if not newer.is_empty():
		return newer[newer.size() - 1].get("id", "")
	return ""


func _prefer_stable(arr: Array) -> Dictionary:
	for i in arr:
		if GodotVersion.is_stable(i.get("version", "")):
			return i
	return arr[0] if not arr.is_empty() else {}


## 에디터(또는 게임) 실행. 실패하면 오류 메시지를 돌려준다.
## extra: 추가 실행 옵션 (예: "--verbose", "--recovery-mode")
func open_project(path: String, install_id: String, editor := true, extra := PackedStringArray()) -> String:
	var inst := find_install(install_id)
	if inst.is_empty():
		return "이 프로젝트에 지정된 에디터가 없어요.\n설치 페이지에서 에디터를 설치하거나 위치를 지정한 뒤, 목록에서 에디터 버전을 골라 주세요."
	var exe: String = inst.get("exe", "")
	if not FileAccess.file_exists(exe):
		return "에디터 실행 파일을 찾을 수 없어요:\n" + exe
	if not DirAccess.dir_exists_absolute(path):
		return "프로젝트 폴더를 찾을 수 없어요:\n" + path
	var args := PackedStringArray(["--path", path])
	if editor:
		args.append("--editor")
	args.append_array(extra)
	var pid := OS.create_process(exe, args)
	if pid <= 0:
		return "에디터를 실행하지 못했어요."
	if editor:
		running[normalize_path(path)] = pid
		running_changed.emit()
	var rec := get_project(path)
	if not rec.is_empty():
		rec["last_opened"] = int(Time.get_unix_time_from_system())
		_save_projects()
		projects_changed.emit()
	match int(settings.get("after_launch", 0)):
		1:
			get_window().mode = Window.MODE_MINIMIZED
		2:
			get_tree().quit()
	return ""


func is_running(path: String) -> bool:
	return running.has(normalize_path(path))


func _poll_running() -> void:
	var changed := false
	for path in running.keys():
		if not OS.is_process_running(int(running[path])):
			running.erase(path)
			changed = true
	if changed:
		running_changed.emit()
		projects_changed.emit()


## 드래그&드롭이나 가져오기로 받은 경로 처리
func import_path(path: String) -> void:
	var p := normalize_path(path)
	if p.get_file() == "project.godot":
		p = p.get_base_dir()
	if FileAccess.file_exists(p.path_join("project.godot")):
		if add_project(p):
			toast.emit("프로젝트를 추가했어요: " + project_info(p).name)
		else:
			toast.emit("이미 목록에 있는 프로젝트예요")
	elif DirAccess.dir_exists_absolute(p):
		scan_folder(p)
	else:
		toast.emit("고도 프로젝트가 아니에요: " + p.get_file())


func scan_folder(root: String) -> void:
	if _scan_thread and _scan_thread.is_alive():
		toast.emit("이미 프로젝트를 찾는 중이에요")
		return
	if _scan_thread and _scan_thread.is_started():
		_scan_thread.wait_to_finish()
	_scan_thread = Thread.new()
	_scan_thread.start(_scan_worker.bind(normalize_path(root)))
	toast.emit("프로젝트를 찾는 중...")


func _scan_worker(root: String) -> void:
	var found: Array = []
	_scan_dir(root, 0, found)
	call_deferred("_scan_done", found)


func _scan_dir(dir: String, depth: int, found: Array) -> void:
	if FileAccess.file_exists(dir.path_join("project.godot")):
		found.append(dir)
		return
	if depth >= SCAN_MAX_DEPTH:
		return
	for sub in DirAccess.get_directories_at(dir):
		if sub.begins_with(".") or SCAN_SKIP.has(sub):
			continue
		_scan_dir(dir.path_join(sub), depth + 1, found)


func _scan_done(found: Array) -> void:
	_scan_thread.wait_to_finish()
	_scan_thread = null
	var added := 0
	for d in found:
		if add_project(d, false):
			added += 1
	_save_projects()
	projects_changed.emit()
	if added > 0:
		toast.emit("프로젝트 %d개를 추가했어요" % added)
	elif found.is_empty():
		toast.emit("이 폴더에서 고도 프로젝트를 찾지 못했어요")
	else:
		toast.emit("찾은 프로젝트가 모두 이미 목록에 있어요")


## 새 프로젝트 만들기. 성공하면 "" 를 돌려준다.
func create_project(project_name: String, dir: String, install_id: String, feature: String, use_git: bool) -> String:
	dir = normalize_path(dir)
	var inst := find_install(install_id)
	if inst.is_empty():
		return "에디터를 골라 주세요."
	var err := DirAccess.make_dir_recursive_absolute(dir)
	if err != OK:
		return "폴더를 만들 수 없어요 (%s)" % error_string(err)
	var ver := GodotVersion.parse(inst.get("version", ""))
	var text := NEW_PROJECT_HEADER
	if ver.major >= 4 or not ver.valid:
		text += "config_version=5\n\n[application]\n\nconfig/name=%s\n" % JSON.stringify(project_name)
		text += "config/features=PackedStringArray(\"%d.%d\", \"%s\")\n" % [ver.major, ver.minor, feature]
		text += "config/icon=\"res://icon.svg\"\n"
		match feature:
			"Mobile":
				text += "\n[rendering]\n\nrenderer/rendering_method=\"mobile\"\n"
			"GL Compatibility":
				text += "\n[rendering]\n\nrenderer/rendering_method=\"gl_compatibility\"\nrenderer/rendering_method.mobile=\"gl_compatibility\"\n"
	else:
		text += "config_version=4\n\n[application]\n\nconfig/name=%s\nconfig/icon=\"res://icon.svg\"\n" % JSON.stringify(project_name)
		if feature == "GL Compatibility":
			text += "\n[rendering]\n\nquality/driver/driver_name=\"GLES2\"\n"
	if not _write_text(dir.path_join("project.godot"), text):
		return "project.godot 파일을 쓸 수 없어요."
	var icon := FileAccess.get_file_as_string("res://icon.svg")
	_write_text(dir.path_join("icon.svg"), icon)
	if ver.major >= 4:
		_write_text(dir.path_join(".editorconfig"), "root = true\n\n[*]\ncharset = utf-8\n")
	if use_git:
		_write_text(dir.path_join(".gitignore"), "# Godot 4+ specific ignores\n.godot/\n/android/\n")
		_write_text(dir.path_join(".gitattributes"), "# Normalize EOL for all files that Git considers text files.\n* text=auto eol=lf\n")
		var out: Array = []
		if OS.execute("git", PackedStringArray(["init", ProjectSettings.globalize_path(dir)]), out, true) != 0:
			toast.emit("Git을 찾지 못해 git init은 건너뛰었어요")
	projects.append({
		"path": dir, "editor": install_id, "favorite": false,
		"last_opened": 0, "added": int(Time.get_unix_time_from_system()),
	})
	_info_cache.erase(dir)
	_save_projects()
	projects_changed.emit()
	return ""


# ─────────────────────────── 저장 ───────────────────────────

func _save_installs() -> void:
	_write_json("installs.json", installs)


func _save_projects() -> void:
	_write_json("projects.json", projects)


func _read_json(file: String) -> Variant:
	var path := data_dir.path_join(file)
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _write_json(file: String, data: Variant) -> void:
	var path := data_dir.path_join(file)
	var tmp := path + ".tmp"
	if _write_text(tmp, JSON.stringify(data, "\t")):
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		DirAccess.rename_absolute(tmp, path)


func _write_text(path: String, text: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true
