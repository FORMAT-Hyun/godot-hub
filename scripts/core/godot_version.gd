class_name GodotVersion
extends RefCounted
## 고도 버전 문자열("4.3-stable", "4.2.2-rc1", "4.5-dev3", "4.3.stable.mono")을 다루는 도우미

const CHANNEL_RANK := {"dev": 0, "alpha": 1, "beta": 2, "rc": 3, "stable": 4}

static var _re: RegEx


static func parse(tag: String) -> Dictionary:
	if _re == null:
		_re = RegEx.create_from_string("^(\\d+)\\.(\\d+)(?:\\.(\\d+))?(?:\\.\\d+)?[-.]?([a-z]+)?(\\d*)")
	var result := {"major": 0, "minor": 0, "patch": 0, "channel": "stable", "num": 0, "valid": false}
	var m := _re.search(tag.strip_edges().to_lower())
	if m == null:
		return result
	result.major = m.get_string(1).to_int()
	result.minor = m.get_string(2).to_int()
	result.patch = m.get_string(3).to_int()
	var ch := m.get_string(4)
	result.channel = ch if CHANNEL_RANK.has(ch) else "stable"
	result.num = m.get_string(5).to_int()
	result.valid = true
	return result


## a가 더 새로우면 1, 같으면 0, 더 오래되면 -1
static func compare(a: String, b: String) -> int:
	var pa := parse(a)
	var pb := parse(b)
	for k in ["major", "minor", "patch"]:
		if pa[k] != pb[k]:
			return 1 if pa[k] > pb[k] else -1
	var ra: int = CHANNEL_RANK[pa.channel]
	var rb: int = CHANNEL_RANK[pb.channel]
	if ra != rb:
		return 1 if ra > rb else -1
	if pa.num != pb.num:
		return 1 if pa.num > pb.num else -1
	return 0


## "4.3-stable" -> "4.3"
static func short(tag: String) -> String:
	var p := parse(tag)
	if not p.valid:
		return tag
	return "%d.%d" % [p.major, p.minor]


static func is_stable(tag: String) -> bool:
	return parse(tag).channel == "stable"
