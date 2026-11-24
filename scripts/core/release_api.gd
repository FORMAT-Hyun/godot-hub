extends Node
## 오토로드 "Releases": GitHub(godotengine/godot-builds)에서 고도 릴리스 목록을 받아 캐시한다.

signal releases_updated
signal fetch_failed(message: String)

const API_URL := "https://api.github.com/repos/godotengine/godot-builds/releases?per_page=100&page=%d"
const CACHE_SECONDS := 6 * 3600
const MAX_PAGES := 6

## [{tag, prerelease, date, assets: {std, mono}}] 최신 순
var releases: Array = []
var fetched_at := 0
var busy := false

var _http: HTTPRequest
var _page := 1
var _acc: Array = []


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.timeout = 60.0
	_http.request_completed.connect(_on_page_completed)
	add_child(_http)
	var cached: Variant = null
	var path := _cache_path()
	if FileAccess.file_exists(path):
		cached = JSON.parse_string(FileAccess.get_file_as_string(path))
	if cached is Dictionary and cached.get("releases") is Array:
		releases = cached.releases
		fetched_at = int(cached.get("fetched_at", 0))


func _cache_path() -> String:
	return Hub.data_dir.path_join("cache/releases.json")


func is_stale() -> bool:
	return releases.is_empty() or int(Time.get_unix_time_from_system()) - fetched_at > CACHE_SECONDS


func refresh(force := false) -> void:
	if busy:
		return
	if not force and not is_stale():
		releases_updated.emit()
		return
	busy = true
	_acc = []
	_page = 1
	_request_page()


func find(tag: String) -> Dictionary:
	for r in releases:
		if r.get("tag", "") == tag:
			return r
	return {}


func _request_page() -> void:
	var headers := PackedStringArray(["User-Agent: GodotHub-Launcher", "Accept: application/vnd.github+json"])
	var token := str(Hub.settings.get("github_token", "")).strip_edges()
	if token != "":
		headers.append("Authorization: Bearer " + token)
	var err := _http.request(API_URL % _page, headers)
	if err != OK:
		_fail(L.t("요청을 보내지 못했어요 (%s)") % error_string(err))


func _on_page_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_fail(L.t("인터넷 연결을 확인해 주세요 (오류 %d)") % result)
		return
	if code == 403 or code == 429:
		_fail(L.t("GitHub 요청 한도를 넘었어요. 잠시 후 다시 시도하거나 설정에서 GitHub 토큰을 넣어 주세요."))
		return
	if code != 200:
		_fail(L.t("GitHub 응답 오류 (HTTP %d)") % code)
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not data is Array:
		_fail(L.t("릴리스 목록을 읽지 못했어요"))
		return
	for r in data:
		var rec := _convert(r)
		if not rec.is_empty():
			_acc.append(rec)
	if data.size() >= 100 and _page < MAX_PAGES:
		_page += 1
		call_deferred("_request_page")
		return
	_acc.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return GodotVersion.compare(a.tag, b.tag) > 0)
	releases = _acc
	fetched_at = int(Time.get_unix_time_from_system())
	busy = false
	var f := FileAccess.open(_cache_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"fetched_at": fetched_at, "releases": releases}))
	releases_updated.emit()


func _convert(r: Dictionary) -> Dictionary:
	var tag: String = r.get("tag_name", "")
	var assets := {}
	for a in r.get("assets", []):
		var name: String = a.get("name", "")
		var info := {"name": name, "url": a.get("browser_download_url", ""), "size": int(a.get("size", 0))}
		if name.ends_with("_mono_win64.zip"):
			assets.mono = info
		elif name.ends_with("_win64.exe.zip"):
			assets.std = info
	if not (assets.has("std") or assets.has("mono")):
		return {}
	return {
		"tag": tag,
		"prerelease": not GodotVersion.is_stable(tag),
		"date": str(r.get("published_at", "")).substr(0, 10),
		"assets": assets,
	}


func _fail(message: String) -> void:
	busy = false
	fetch_failed.emit(message)
