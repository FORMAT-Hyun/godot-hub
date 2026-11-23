class_name EditorSettingsFile
extends RefCounted
## 고도 에디터 설정 파일(editor_settings-*.tres)을 읽고, 바뀐 줄만 고쳐서 다시 쓴다.
## 나머지 줄은 손대지 않으므로 고도가 쓴 형식이 그대로 유지된다.
## 파일에 없는 설정은 [resource] 끝에 새 줄로 넣는다.

const SKIP_KEYS := ["resource_local_to_scene", "resource_name", "script"]

var path := ""
var raw := {}  # key -> 파일에 적힌 값 문자열
var order: Array = []  # 파일에 나온 순서대로 key
var _pos := {}  # key -> [줄 번호, 줄 수]
var _subs := {}  # 고도가 따로 적어 둔 하위 리소스(단축키 입력 등): id -> Object(...) 문자열
var _lines: PackedStringArray


func load_file(p: String) -> Error:
	path = p
	if not FileAccess.file_exists(p):
		return ERR_FILE_NOT_FOUND
	_lines = FileAccess.get_file_as_string(p).split("\n")
	raw.clear()
	order.clear()
	_pos.clear()
	_subs.clear()
	var in_resource := false
	var sub_id := ""
	var sub_props: Array = []
	var sub_type := ""
	var i := 0
	while i < _lines.size():
		var line := _lines[i]
		if line.begins_with("["):
			if sub_id != "":
				_subs[sub_id] = "Object(%s%s)" % [sub_type, "".join(sub_props)]
			sub_id = ""
			in_resource = line.begins_with("[resource]")
			if line.begins_with("[sub_resource"):
				sub_type = _attr(line, "type")
				sub_id = _attr(line, "id")
				sub_props = []
			i += 1
			continue
		var eq := line.find(" = ")
		if sub_id != "" and eq > 0:
			sub_props.append(",%s:%s" % [JSON.stringify(line.substr(0, eq)), line.substr(eq + 3)])
			i += 1
			continue
		if not in_resource or eq <= 0:
			i += 1
			continue
		var key := line.substr(0, eq)
		var value := line.substr(eq + 3)
		var count := 1
		while _open_depth(value) > 0 and i + count < _lines.size():
			value += "\n" + _lines[i + count]
			count += 1
		if not SKIP_KEYS.has(key):
			raw[key] = value
			order.append(key)
			_pos[key] = [i, count]
		i += count
	return OK


func has(key: String) -> bool:
	return raw.has(key)


## 파일에 적힌 값을 Variant로 (읽을 수 없으면 null).
## SubResource("id") 참조는 그 내용을 Object(...)로 풀어서 읽는다.
func value(key: String) -> Variant:
	var text := str(raw.get(key, ""))
	if text.contains("SubResource("):
		var re := RegEx.create_from_string(r"SubResource\(\s*\"([^\"]+)\"\s*\)")
		var out := ""
		var last := 0
		for m in re.search_all(text):
			out += text.substr(last, m.get_start() - last) + str(_subs.get(m.get_string(1), "null"))
			last = m.get_end()
		text = out + text.substr(last)
	return str_to_var(text)


static func _attr(line: String, name: String) -> String:
	var at := line.find(name + "=\"")
	if at < 0:
		return ""
	at += name.length() + 2
	return line.substr(at, line.find("\"", at) - at)


## changes: key -> 새 값 문자열(var_to_str 형식). 원본은 .bak 으로 남긴다.
func save(changes: Dictionary) -> Error:
	if changes.is_empty():
		return OK
	var out := Array(_lines)
	var existing: Array = []
	var added: Array = []
	for key in changes:
		if _pos.has(key):
			existing.append(key)
		else:
			added.append(key)
	# 아래 줄부터 고쳐야 위쪽 줄 번호가 안 바뀐다
	existing.sort_custom(func(a: String, b: String) -> bool: return _pos[a][0] > _pos[b][0])
	for key in existing:
		var at: int = _pos[key][0]
		for n in _pos[key][1]:
			out.remove_at(at)
		out.insert(at, "%s = %s" % [key, changes[key]])
	if not added.is_empty():
		# [resource] 부분의 마지막 값 뒤에 넣는다
		var at := out.size()
		while at > 0 and str(out[at - 1]).strip_edges() == "":
			at -= 1
		for key in added:
			out.insert(at, "%s = %s" % [key, changes[key]])
			at += 1
	if FileAccess.file_exists(path):
		var backup := DirAccess.copy_absolute(path, path + ".bak")
		if backup != OK:
			return backup
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string("\n".join(PackedStringArray(out)))
	f.close()
	return load_file(path)


## 아직 닫히지 않은 괄호 · 문자열 개수 (여러 줄 값 판단용)
static func _open_depth(s: String) -> int:
	var depth := 0
	var in_string := false
	var escaped := false
	for ch in s:
		if in_string:
			if escaped:
				escaped = false
			elif ch == "\\":
				escaped = true
			elif ch == "\"":
				in_string = false
		elif ch == "\"":
			in_string = true
		elif ch in "{[(":
			depth += 1
		elif ch in "}])":
			depth -= 1
	return depth + (1 if in_string else 0)
