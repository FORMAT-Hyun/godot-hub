class_name ProjectReader
extends RefCounted
## project.godot 파일에서 이름 · 버전 · 아이콘 · 렌더러를 읽는다.
## 고도 3/4 형식이 섞여 있어도 안전하도록 필요한 키만 줄 단위로 파싱한다.

const RENDERERS := {"Forward Plus": "Forward+", "Mobile": "Mobile", "GL Compatibility": "Compatibility"}

static var _quoted_re: RegEx


static func read(dir: String) -> Dictionary:
	var info := {
		"valid": false, "name": dir.get_file(), "config_version": 0, "version": "",
		"features": [], "tags": [], "renderer": "", "icon": "", "csharp": false,
	}
	var f := FileAccess.open(dir.path_join("project.godot"), FileAccess.READ)
	if f == null:
		return info
	info.valid = true
	var section := ""
	var icon_value := ""
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "" or line.begins_with(";"):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			section = line.substr(1, line.length() - 2)
			continue
		var eq := line.find("=")
		if eq < 0:
			continue
		var key := line.substr(0, eq).strip_edges()
		var value := line.substr(eq + 1).strip_edges()
		if section == "" and key == "config_version":
			info.config_version = value.to_int()
		elif section == "application":
			match key:
				"config/name":
					info.name = _unquote(value)
				"config/icon":
					icon_value = _unquote(value)
				"config/features":
					info.features = _quoted_list(value)
				"config/tags":
					info.tags = _quoted_list(value)
		elif section == "dotnet" and key == "project/assembly_name":
			info.csharp = true
		elif section == "mono":
			info.csharp = true

	for feat in info.features:
		var s := str(feat)
		if s == "C#":
			info.csharp = true
		elif RENDERERS.has(s):
			info.renderer = RENDERERS[s]
		elif info.version == "" and s.is_valid_float() and s.contains("."):
			info.version = s
	if info.version == "":
		match int(info.config_version):
			4:
				info.version = "3.x"
			5:
				info.version = "4.x"
	if not info.csharp:
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".csproj"):
				info.csharp = true
				break
	info.icon = _resolve_icon(dir, icon_value)
	return info


static func _resolve_icon(dir: String, value: String) -> String:
	if value.begins_with("res://"):
		var p := dir.path_join(value.trim_prefix("res://"))
		if FileAccess.file_exists(p):
			return p
	for name in ["icon.svg", "icon.png", "icon.webp"]:
		var p := dir.path_join(name)
		if FileAccess.file_exists(p):
			return p
	return ""


## project.godot 의 [application] 섹션 값 하나를 바꾸거나 추가한다 (나머지 줄은 그대로).
## raw: 파일에 쓸 값 그대로 (예: "\"이름\"", "PackedStringArray(\"a\")"). "" 이면 그 줄을 지운다.
static func set_application_value(dir: String, key: String, raw: String) -> Error:
	var path := dir.path_join("project.godot")
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var lines := FileAccess.get_file_as_string(path).split("\n")
	var section := ""
	var app_start := -1
	var app_end := -1
	var found := -1
	for i in lines.size():
		var line := lines[i].strip_edges()
		if line.begins_with("[") and line.ends_with("]"):
			if section == "application":
				app_end = i
			section = line.substr(1, line.length() - 2)
			if section == "application":
				app_start = i
			continue
		if section == "application" and line.begins_with(key + "="):
			found = i
	if section == "application" and app_end < 0:
		app_end = lines.size()
	var new_line := "%s=%s" % [key, raw]
	if found >= 0:
		if raw == "":
			lines.remove_at(found)
		else:
			lines[found] = new_line
	elif raw != "":
		if app_start < 0:
			lines.append("")
			lines.append("[application]")
			lines.append("")
			lines.append(new_line)
		else:
			# 섹션 끝의 빈 줄 앞에 넣는다
			var at := app_end
			while at - 1 > app_start and lines[at - 1].strip_edges() == "":
				at -= 1
			lines.insert(at, new_line)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string("\n".join(lines))
	f.close()
	return OK


static func quote(text: String) -> String:
	return JSON.stringify(text)


static func _unquote(value: String) -> String:
	if value.length() >= 2 and value.begins_with("\"") and value.ends_with("\""):
		return value.substr(1, value.length() - 2).c_unescape()
	return value


static func _quoted_list(value: String) -> Array:
	if _quoted_re == null:
		_quoted_re = RegEx.create_from_string("\"((?:[^\"\\\\]|\\\\.)*)\"")
	var out: Array = []
	for m in _quoted_re.search_all(value):
		out.append(m.get_string(1).c_unescape())
	return out


## 고도가 프로젝트를 열고 닫을 때 갱신하는 파일들 중 가장 최근 수정 시각
static func modified_time(dir: String) -> int:
	var t := 0
	for rel in ["project.godot", ".godot/editor/project_metadata.cfg", ".godot/editor/editor_layout.cfg"]:
		var p := dir.path_join(rel)
		if FileAccess.file_exists(p):
			t = maxi(t, FileAccess.get_modified_time(p))
	return t


static func load_icon(path: String, max_size := 64) -> Texture2D:
	if path == "" or not FileAccess.file_exists(path):
		return null
	var img := Image.new()
	if img.load(path) != OK or img.is_empty():
		return null
	var longest := maxi(img.get_width(), img.get_height())
	if longest > max_size:
		var s := float(max_size) / longest
		img.resize(maxi(1, roundi(img.get_width() * s)), maxi(1, roundi(img.get_height() * s)), Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)
