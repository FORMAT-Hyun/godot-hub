class_name EditorSettingsDialog
extends ConfirmationDialog
## 고도 에디터의 "에디터 설정" 창을 허브 안에서 보여 준다.
## 왼쪽: 분류 트리 / 오른쪽: 설정 값 (고도 에디터 설정 창과 같은 배치)
##
## 설정 이름·목록 항목·범위·기본값·단축키 목록은 그 버전 에디터에서 뽑아 온 정보(SettingsHelper)를 쓴다.
## 정보가 아직 없거나 설정 파일이 없는 버전이면 처음 열 때 에디터를 화면 없이 잠깐 실행해 만든다.

const EDITOR_WIDTH := 300.0
const BASIC_USAGE := 1 << 27  # PROPERTY_USAGE_EDITOR_BASIC_SETTING
const SC_PREFIX := "#sc/"
const DUMP_TIMEOUT := 120.0
const SPECIAL_KEYS := ["shortcuts", "builtin_action_overrides"]

var _file := EditorSettingsFile.new()
var _inst: Dictionary = {}
var _meta: Dictionary = {}
var _words: Dictionary = {}
var _props: Array = []  # {key, type, hint, hint_string, usage, value, default, has_default}
var _changes := {}  # key -> 새 값
var _shortcuts: Array = []  # {id, name, category, is_action, default(Array 또는 null)}
var _sc_file := {}  # id -> 파일에 저장된 덮어쓴 이벤트 목록
var _sc_changes := {}  # id -> 새 이벤트 목록, 또는 false(기본값으로 되돌리기)

var _search: LineEdit
var _advanced: CheckBox
var _reload_btn: Button
var _tree: Tree
var _list: VBoxContainer
var _scroll: ScrollContainer
var _info: Label
var _current := ""

var _dump_pid := 0
var _dump_time := 0.0
var _dump_timer: Timer
var _file_dialog: FileDialog
var _file_target: Callable
var _text_dialog: ConfirmationDialog
var _text_edit: TextEdit
var _text_target: Dictionary
var _key_dialog: ConfirmationDialog
var _key_label: Label
var _key_event: InputEventKey
var _key_target := ""
var _key_append := false


func _init() -> void:
	ok_button_text = L.t("저장")
	cancel_button_text = L.t("닫기")
	min_size = Vector2i(1000, 640)


func _ready() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)
	_search = LineEdit.new()
	_search.placeholder_text = L.t("설정 · 단축키 검색")
	_search.right_icon = HubIcons.icon("search", 16, false)
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_t: String) -> void: _show_list())
	top.add_child(_search)
	_advanced = CheckBox.new()
	_advanced.text = L.t("고급 설정")
	_advanced.tooltip_text = L.t("고도 에디터처럼 자주 안 쓰는 설정도 보여 줘요")
	_advanced.focus_mode = Control.FOCUS_NONE
	_advanced.toggled.connect(func(_on: bool) -> void: _build_tree())
	top.add_child(_advanced)
	_reload_btn = Button.new()
	_reload_btn.icon = HubIcons.icon("refresh")
	_reload_btn.tooltip_text = L.t("이 버전 에디터에서 설정 정보를 다시 읽어 와요")
	_reload_btn.focus_mode = Control.FOCUS_NONE
	_reload_btn.pressed.connect(func() -> void: _start_dump())
	top.add_child(_reload_btn)
	var open_file := Button.new()
	open_file.text = L.t("파일 위치")
	open_file.icon = HubIcons.icon("folder")
	open_file.focus_mode = Control.FOCUS_NONE
	open_file.pressed.connect(func() -> void:
		if _file.path != "":
			OS.shell_show_in_file_manager(ProjectSettings.globalize_path(_file.path)))
	top.add_child(open_file)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)
	_tree = Tree.new()
	_tree.hide_root = true
	_tree.custom_minimum_size.x = 230
	_tree.item_selected.connect(_on_tree_selected)
	split.add_child(_tree)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	_scroll.add_child(_list)

	_info = HubUI.label("", "DimLabel")
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size.x = 900
	root.add_child(_info)
	confirmed.connect(_save)

	_dump_timer = Timer.new()
	_dump_timer.wait_time = 0.5
	_dump_timer.timeout.connect(_poll_dump)
	add_child(_dump_timer)
	_build_side_dialogs()


# ─────────────────────────── 열기 · 정보 준비 ───────────────────────────

## 설치된 에디터의 설정 창 열기. 열 수 없으면 오류 메시지를 돌려준다.
func open_for(inst: Dictionary) -> String:
	var v := GodotVersion.parse(inst.get("version", ""))
	var old: bool = v.valid and v.major < 4
	_inst = inst
	_changes.clear()
	_sc_changes.clear()
	_search.text = ""
	title = L.t("에디터 설정 — Godot ") + Hub.install_label(inst)
	if old:
		# Godot 3: 정보를 뽑을 수 없으므로 설정 파일만 보여 준다
		if Hub.editor_settings_file(inst) == "":
			return L.t("아직 이 버전의 에디터 설정 파일이 없어요.\nGodot 3은 그 버전으로 에디터를 한 번 열어야 만들어져요.")
		_meta = {}
		_reload_btn.visible = false
		_load_data()
		popup_centered()
		return ""
	_reload_btn.visible = true
	_meta = SettingsHelper.load_meta(inst)
	popup_centered()
	if _meta.is_empty() or _settings_path() == "":
		_start_dump()
	else:
		_load_data()
	return ""


## 검색어를 넣어 둔다 (개발용 --hub-es-search)
func set_search(text: String) -> void:
	_search.text = text
	_show_list()


func _settings_path() -> String:
	var p := str(_meta.get("file", ""))
	if p != "" and FileAccess.file_exists(p):
		return Hub.normalize_path(p)
	return Hub.editor_settings_file(_inst)


func _start_dump() -> void:
	if _dump_pid > 0:
		return
	var r := SettingsHelper.start_dump(_inst)
	if r.error != "":
		_show_message(r.error)
		return
	_dump_pid = r.pid
	_dump_time = 0.0
	_tree.clear()
	_show_message(L.t("이 버전의 에디터에서 설정 정보를 읽어 오는 중이에요...\n(버전마다 처음 한 번만, 몇 초 걸려요. 설정 파일이 없으면 이때 만들어져요.)"))
	get_ok_button().disabled = true
	_dump_timer.start()


func _poll_dump() -> void:
	_dump_time += _dump_timer.wait_time
	var running := OS.is_process_running(_dump_pid)
	if running and _dump_time < DUMP_TIMEOUT:
		return  # 에디터가 정보를 다 쓰고 끝날 때까지 기다린다
	_dump_timer.stop()
	if running:
		OS.kill(_dump_pid)
	_dump_pid = 0
	_meta = SettingsHelper.load_meta(_inst)
	if _meta.is_empty():
		_show_message(L.t("설정 정보를 읽지 못했어요.\n이 버전 에디터가 정상적으로 실행되는지 확인해 주세요."))
		if Hub.editor_settings_file(_inst) != "":
			_load_data()  # 설정 파일만이라도 보여 준다
		return
	_load_data()


func _load_data() -> void:
	var path := _settings_path()
	if path == "" or _file.load_file(path) != OK:
		_show_message(L.t("에디터 설정 파일을 찾지 못했어요."))
		return
	_words = _meta.get("words", {})
	if _words.is_empty():
		_words = _borrow_words()
	_props.clear()
	if _meta.has("props"):
		for p in _meta.props:
			var key := str(p.name)
			var prop := {"key": key, "type": int(p.type), "hint": int(p.hint), "hint_string": str(p.hint_string),
				"usage": int(p.usage), "has_default": p.has("default")}
			prop.value = _file.value(key) if _file.has(key) else str_to_var(str(p.value))
			prop.default = str_to_var(str(p.default)) if prop.has_default else null
			_props.append(prop)
	else:
		for key in _file.order:
			if str(key).contains("/") and not SPECIAL_KEYS.has(key):
				var val: Variant = _file.value(key)
				_props.append({"key": key, "type": typeof(val), "hint": 0, "hint_string": "", "usage": BASIC_USAGE,
					"value": val, "default": null, "has_default": false})
	_load_shortcuts()
	# "고급 설정" 구분은 버전에 따라 없을 수 있다 (4.0 등). 없으면 모두 보여 준다.
	var has_basic := false
	for p in _props:
		if (int(p.usage) & BASIC_USAGE) != 0:
			has_basic = true
			break
	_advanced.visible = _meta.has("props") and has_basic
	_build_tree()
	_update_info()


## Godot 4.3 이하는 에디터 번역을 꺼낼 수 없어서, 다른 버전에서 같은 언어로 받아 둔 이름을 빌려 쓴다
func _borrow_words() -> Dictionary:
	var dir := SettingsHelper.meta_path(_inst).get_base_dir()
	var best := {}
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with("." + L.current + ".json"):
			continue
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(f)))
		if d is Dictionary and d.get("words", {}) is Dictionary and d.get("words", {}).size() > best.size():
			best = d.words
	return best


func _load_shortcuts() -> void:
	_shortcuts.clear()
	_sc_file.clear()
	var arr: Variant = _file.value("shortcuts")
	if arr is Array:
		for d in arr:
			if d is Dictionary and d.has("name"):
				_sc_file[str(d.name)] = d.get("shortcuts", [])
	arr = _file.value("builtin_action_overrides")
	if arr is Array:
		for d in arr:
			if d is Dictionary and d.has("name"):
				_sc_file[str(d.name)] = d.get("events", [])
	var overridden: Array = _meta.get("overridden", [])
	for s in _meta.get("shortcuts", []):
		var id := str(s.id)
		if id == "":
			continue
		var def: Variant = null  # 뽑을 때 이미 바뀌어 있던 단축키는 기본값을 모른다
		if not overridden.has(id):
			def = str_to_var(str(s.events))
		_shortcuts.append({"id": id, "name": str(s.name), "category": str(s.category), "is_action": bool(s.is_action), "default": def})


func _show_message(text: String) -> void:
	for c in _list.get_children():
		c.queue_free()
	var l := HubUI.label(text, "DimLabel")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 500
	_list.add_child(l)


# ─────────────────────────── 이름 ───────────────────────────

func _tr(word: String) -> String:
	var cap := word.capitalize()
	return str(_words.get(cap, cap))


func _section_label(key: String) -> String:
	return _tr(key.get_file())


func _is_visible_prop(p: Dictionary) -> bool:
	return _advanced.button_pressed or not _advanced.visible or (p.usage & BASIC_USAGE) != 0


# ─────────────────────────── 트리 ───────────────────────────

func _build_tree() -> void:
	var keep := _current
	_tree.clear()
	var root := _tree.create_item()
	var sections := {}
	for p in _props:
		if not _is_visible_prop(p):
			continue
		var parts := str(p.key).split("/")
		var sec := parts[0]
		var sub := parts[1] if parts.size() > 2 else "_general"
		if not sections.has(sec):
			var item := _tree.create_item(root)
			item.set_text(0, _tr(sec))
			item.set_tooltip_text(0, sec.capitalize())
			item.set_metadata(0, "")
			item.set_selectable(0, false)
			item.set_custom_color(0, HubTheme.TEXT_DIM)
			sections[sec] = {"item": item, "subs": {}}
		if not sections[sec].subs.has(sub):
			var child := _tree.create_item(sections[sec].item)
			child.set_text(0, L.t("일반") if sub == "_general" else _tr(sub))
			child.set_tooltip_text(0, "General" if sub == "_general" else sub.capitalize())
			child.set_metadata(0, sec + "/" + sub)
			sections[sec].subs[sub] = child
	if not _shortcuts.is_empty():
		var item := _tree.create_item(root)
		item.set_text(0, L.t("단축키"))
		item.set_metadata(0, "")
		item.set_selectable(0, false)
		item.set_custom_color(0, HubTheme.TEXT_DIM)
		var cats := {}
		for s in _shortcuts:
			if not cats.has(s.category):
				var child := _tree.create_item(item)
				child.set_text(0, s.category)
				child.set_metadata(0, SC_PREFIX + s.category)
				cats[s.category] = child
	# 전에 보던 곳, 없으면 고도처럼 Interface > Editor
	var first: TreeItem = _find_item(root, keep) if keep != "" else null
	if first == null and sections.has("interface") and sections.interface.subs.has("editor"):
		first = sections.interface.subs.editor
	if first == null and root.get_first_child() and root.get_first_child().get_first_child():
		first = root.get_first_child().get_first_child()
	if first:
		first.select(0)
		_on_tree_selected()
	else:
		_show_list()


func _find_item(item: TreeItem, meta: String) -> TreeItem:
	var c := item.get_first_child()
	while c:
		if str(c.get_metadata(0)) == meta:
			return c
		var f := _find_item(c, meta)
		if f:
			return f
		c = c.get_next()
	return null


func _on_tree_selected() -> void:
	var item := _tree.get_selected()
	if item == null:
		return
	_current = str(item.get_metadata(0))
	_show_list()
	_scroll.scroll_vertical = 0


func _matches_prefix(key: String) -> bool:
	var parts := key.split("/")
	if _current.ends_with("/_general"):
		return parts.size() == 2 and _current.begins_with(parts[0] + "/")
	return parts.size() > 2 and key.begins_with(_current + "/")


# ─────────────────────────── 오른쪽 목록 ───────────────────────────

func _show_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	var q := _search.text.strip_edges().to_lower()
	var rows: Array = []
	for i in _props.size():
		var p: Dictionary = _props[i]
		var key: String = p.key
		var parts := key.split("/")
		var group := ""
		if q != "":
			if not (key.to_lower().contains(q) or key.get_file().capitalize().to_lower().contains(q) or _section_label(key).to_lower().contains(q)):
				continue
			group = " > ".join(Array(parts.slice(0, parts.size() - 1)).map(func(s: String) -> String: return _tr(s)))
		else:
			if _current.begins_with(SC_PREFIX) or not _matches_prefix(key) or not _is_visible_prop(p):
				continue
			if parts.size() > 3:
				group = " > ".join(Array(parts.slice(2, parts.size() - 1)).map(func(s: String) -> String: return _tr(s)))
		rows.append({"p": p, "group": group, "i": i})
	for s in _shortcuts:
		if q != "":
			if not (s.name.to_lower().contains(q) or s.id.to_lower().contains(q) or _events_text(_sc_current(s)).to_lower().contains(q)):
				continue
			rows.append({"s": s, "group": L.t("단축키 > ") + s.category, "i": 100000 + rows.size()})
		elif _current == SC_PREFIX + s.category:
			rows.append({"s": s, "group": "", "i": rows.size()})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.group != b.group:
			return a.group < b.group
		return a.i < b.i)
	var last_group := ""
	var shown := 0
	for r in rows:
		var group: String = r.group
		if group != last_group and group != "":
			var header := HubUI.label(group, "SectionLabel")
			header.add_theme_color_override("font_color", HubTheme.ACCENT)
			if shown > 0:
				_list.add_child(HubUI.vspace(6))
			_list.add_child(header)
			last_group = group
		_list.add_child(_build_shortcut_row(r.s) if r.has("s") else _build_row(r.p))
		shown += 1
		if shown >= 400:
			_list.add_child(HubUI.label(L.t("결과가 너무 많아요. 검색어를 더 자세히 적어 주세요."), "DimLabel"))
			break
	if shown == 0:
		_list.add_child(HubUI.label(L.t("표시할 설정이 없어요."), "DimLabel"))


func _value_of(p: Dictionary) -> Variant:
	return _changes.get(p.key, p.value)


static func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) == TYPE_FLOAT or typeof(b) == TYPE_FLOAT:
		if typeof(a) in [TYPE_FLOAT, TYPE_INT] and typeof(b) in [TYPE_FLOAT, TYPE_INT]:
			return is_equal_approx(float(a), float(b))
	return var_to_str(a) == var_to_str(b)


func _build_row(p: Dictionary) -> Control:
	var key: String = p.key
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_lbl := HubUI.label(_section_label(key))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.custom_minimum_size.x = 160
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.tooltip_text = key
	name_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(name_lbl)
	var revert := HubUI.flat_icon_button("refresh", L.t("기본값으로 되돌리기"))
	var refresh := func() -> void:
		var v: Variant = _value_of(p)
		var show: bool = p.has_default and not _same(v, p.default)
		revert.modulate.a = 1.0 if show else 0.0  # 숨겨도 자리는 남겨 줄을 맞춘다
		revert.disabled = not show
		if _changes.has(key):
			name_lbl.add_theme_color_override("font_color", HubTheme.ACCENT)
		else:
			name_lbl.remove_theme_color_override("font_color")
	var editor := _build_editor(p, func(v: Variant) -> void:
		_set_change(p, v)
		refresh.call())
	editor.custom_minimum_size.x = EDITOR_WIDTH
	editor.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(editor)
	revert.pressed.connect(func() -> void:
		_set_change(p, p.default)
		_show_list())
	row.add_child(revert)
	refresh.call()
	return row


func _set_change(p: Dictionary, value: Variant) -> void:
	if _same(value, p.value):
		_changes.erase(p.key)
	else:
		_changes[p.key] = value
	_update_info()


## 값 종류와 고도가 알려 준 힌트에 맞는 입력칸
func _build_editor(p: Dictionary, on_change: Callable) -> Control:
	var value: Variant = _value_of(p)
	var type: int = p.type
	var hint: int = p.hint
	var hs: String = p.hint_string
	if type == TYPE_BOOL:
		var cb := CheckBox.new()
		cb.text = L.t("켜짐")
		cb.button_pressed = bool(value)
		cb.toggled.connect(func(on: bool) -> void: on_change.call(on))
		return cb
	if hint == PROPERTY_HINT_ENUM and type in [TYPE_INT, TYPE_STRING, TYPE_STRING_NAME]:
		return _enum_editor(value, type, hs, on_change)
	if hint == PROPERTY_HINT_FLAGS and type == TYPE_INT:
		return _flags_editor(int(value), hs, on_change)
	if type == TYPE_INT or type == TYPE_FLOAT:
		var sb := SpinBox.new()
		sb.min_value = -1000000
		sb.max_value = 1000000
		sb.step = 1.0 if type == TYPE_INT else 0.001
		sb.allow_greater = true
		sb.allow_lesser = true
		if hint == PROPERTY_HINT_RANGE:
			var parts := hs.split(",")
			if parts.size() >= 2:
				sb.allow_greater = false
				sb.allow_lesser = false
				sb.min_value = parts[0].to_float()
				sb.max_value = parts[1].to_float()
			if parts.size() >= 3 and parts[2].is_valid_float():
				sb.step = parts[2].to_float()
			for extra in parts.slice(2):
				extra = extra.strip_edges()
				if extra == "or_greater":
					sb.allow_greater = true
				elif extra == "or_less":
					sb.allow_lesser = true
				elif extra.begins_with("suffix:"):
					sb.suffix = extra.trim_prefix("suffix:")
				elif extra == "degrees":
					sb.suffix = "°"
		sb.value = float(value)
		sb.value_changed.connect(func(v: float) -> void: on_change.call(int(v) if type == TYPE_INT else v))
		return sb
	if type == TYPE_STRING or type == TYPE_STRING_NAME:
		var le := LineEdit.new()
		le.text = str(value)
		if hint == PROPERTY_HINT_PLACEHOLDER_TEXT:
			le.placeholder_text = hs
		le.text_changed.connect(func(t: String) -> void: on_change.call(t))
		if hint in [PROPERTY_HINT_GLOBAL_FILE, PROPERTY_HINT_GLOBAL_DIR, PROPERTY_HINT_FILE, PROPERTY_HINT_DIR]:
			var hb := HBoxContainer.new()
			le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hb.add_child(le)
			var b := Button.new()
			b.icon = HubIcons.icon("load")
			b.tooltip_text = L.t("찾아보기")
			b.focus_mode = Control.FOCUS_NONE
			var is_dir := hint in [PROPERTY_HINT_GLOBAL_DIR, PROPERTY_HINT_DIR]
			b.pressed.connect(func() -> void:
				_pick_path(is_dir, hs, func(path: String) -> void:
					le.text = path
					on_change.call(path)))
			hb.add_child(b)
			return hb
		return le
	if type == TYPE_COLOR and value is Color:
		var cp := ColorPickerButton.new()
		cp.color = value
		cp.edit_alpha = hint != PROPERTY_HINT_COLOR_NO_ALPHA
		cp.custom_minimum_size.y = 28
		cp.color_changed.connect(func(c: Color) -> void: on_change.call(c))
		return cp
	# 배열 · 사전 · 벡터 같은 값은 글자로 편집
	var box := HBoxContainer.new()
	var ro := LineEdit.new()
	ro.text = var_to_str(value).replace("\n", " ")
	ro.editable = false
	ro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(ro)
	var eb := Button.new()
	eb.icon = HubIcons.icon("edit")
	eb.tooltip_text = L.t("값 편집")
	eb.focus_mode = Control.FOCUS_NONE
	eb.pressed.connect(func() -> void:
		_edit_text(p, func(v: Variant) -> void:
			ro.text = var_to_str(v).replace("\n", " ")
			on_change.call(v)))
	box.add_child(eb)
	return box


## 목록 항목: "A,B:5" (정수) 또는 "값/이름;..." (문자열)
static func _enum_options(type: int, hs: String) -> Array:
	var out: Array = []
	if type == TYPE_INT:
		var next := 0
		for part in hs.split(","):
			var label := part
			var c := part.rfind(":")
			if c > 0 and part.substr(c + 1).is_valid_int():
				label = part.substr(0, c)
				next = part.substr(c + 1).to_int()
			out.append([label, next])
			next += 1
	else:
		var sep := ";" if hs.begins_with(";") else ","
		for part in hs.split(sep, false):
			if sep == ";" and part.contains("/"):
				out.append([part.substr(part.find("/") + 1), part.substr(0, part.find("/"))])
			else:
				out.append([part, part])
	return out


func _enum_editor(value: Variant, type: int, hs: String, on_change: Callable) -> Control:
	var opt := OptionButton.new()
	opt.fit_to_longest_item = false
	opt.clip_text = true
	var options := _enum_options(type, hs)
	var found := false
	for o in options:
		opt.add_item(str(o[0]))
		opt.set_item_metadata(opt.item_count - 1, o[1])
		if str(o[1]) == str(value):
			opt.select(opt.item_count - 1)
			found = true
	if not found:
		opt.add_item("(%s)" % str(value))
		opt.set_item_metadata(opt.item_count - 1, value)
		opt.select(opt.item_count - 1)
	opt.item_selected.connect(func(idx: int) -> void: on_change.call(opt.get_item_metadata(idx)))
	return opt


func _flags_editor(value: int, hs: String, on_change: Callable) -> Control:
	var mb := MenuButton.new()
	mb.flat = false
	mb.clip_text = true
	var pm := mb.get_popup()
	pm.hide_on_checkable_item_selection = false
	var bit := 1
	var bits: Array = []
	for part in hs.split(","):
		var label := part
		var c := part.rfind(":")
		if c > 0 and part.substr(c + 1).is_valid_int():
			label = part.substr(0, c)
			bit = part.substr(c + 1).to_int()
		pm.add_check_item(label)
		pm.set_item_checked(pm.item_count - 1, (value & bit) != 0)
		bits.append(bit)
		bit <<= 1
	var state := [value]
	var update_text := func() -> void:
		var names: Array = []
		for i in pm.item_count:
			if pm.is_item_checked(i):
				names.append(pm.get_item_text(i))
		mb.text = ", ".join(names) if not names.is_empty() else L.t("없음")
	update_text.call()
	pm.index_pressed.connect(func(i: int) -> void:
		pm.set_item_checked(i, not pm.is_item_checked(i))
		state[0] = state[0] ^ int(bits[i])
		update_text.call()
		on_change.call(state[0]))
	return mb


# ─────────────────────────── 단축키 ───────────────────────────

func _sc_current(s: Dictionary) -> Variant:
	if _sc_changes.has(s.id):
		var c: Variant = _sc_changes[s.id]
		return c if c is Array else s.default
	if _sc_file.has(s.id):
		return _sc_file[s.id]
	return s.default


func _sc_overridden(s: Dictionary) -> bool:
	if _sc_changes.has(s.id):
		return _sc_changes[s.id] is Array
	return _sc_file.has(s.id)


static func _events_text(events: Variant) -> String:
	if events == null:
		return L.t("기본값")
	var names: Array = []
	for e in events:
		if e is InputEvent:
			names.append(e.as_text().replace(" - Physical", ""))
	return ", ".join(names) if not names.is_empty() else L.t("없음")


func _build_shortcut_row(s: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_lbl := HubUI.label(s.name)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.custom_minimum_size.x = 160
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.tooltip_text = s.id
	name_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	if _sc_changes.has(s.id):
		name_lbl.add_theme_color_override("font_color", HubTheme.ACCENT)
	row.add_child(name_lbl)
	var keys := Button.new()
	keys.text = _events_text(_sc_current(s))
	keys.tooltip_text = L.t("눌러서 단축키 바꾸기")
	keys.alignment = HORIZONTAL_ALIGNMENT_LEFT
	keys.clip_text = true
	keys.focus_mode = Control.FOCUS_NONE
	keys.custom_minimum_size.x = EDITOR_WIDTH - 72
	if _sc_current(s) == null:
		keys.add_theme_color_override("font_color", HubTheme.TEXT_DIM)
	keys.pressed.connect(_capture_key.bind(s.id, false))
	row.add_child(keys)
	var add := HubUI.flat_icon_button("plus", L.t("단축키 하나 더 추가"))
	add.pressed.connect(_capture_key.bind(s.id, true))
	row.add_child(add)
	var clear := HubUI.flat_icon_button("clear", L.t("단축키 지우기"))
	clear.pressed.connect(func() -> void:
		_sc_changes[s.id] = []
		_after_sc_change())
	row.add_child(clear)
	var revert := HubUI.flat_icon_button("refresh", L.t("기본값으로 되돌리기"))
	revert.pressed.connect(func() -> void:
		if _sc_file.has(s.id):
			_sc_changes[s.id] = false
		else:
			_sc_changes.erase(s.id)
		_after_sc_change())
	if not _sc_overridden(s):
		revert.modulate.a = 0.0
		revert.disabled = true
	row.add_child(revert)
	return row


func _after_sc_change() -> void:
	_update_info()
	var scroll := _scroll.scroll_vertical
	_show_list()
	await get_tree().process_frame
	_scroll.scroll_vertical = scroll


func _capture_key(id: String, append: bool) -> void:
	_key_target = id
	_key_append = append
	_key_event = null
	_key_label.text = L.t("누를 키 조합을 입력하세요")
	_key_dialog.get_ok_button().disabled = true
	_key_dialog.popup_centered()


func _on_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	_key_dialog.set_input_as_handled()
	var k := InputEventKey.new()
	k.device = -1
	k.keycode = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
	k.ctrl_pressed = event.ctrl_pressed
	k.shift_pressed = event.shift_pressed
	k.alt_pressed = event.alt_pressed
	k.meta_pressed = event.meta_pressed
	_key_event = k
	_key_label.text = k.as_text()
	_key_dialog.get_ok_button().disabled = k.keycode in [KEY_CTRL, KEY_SHIFT, KEY_ALT, KEY_META]


func _on_key_confirmed() -> void:
	if _key_event == null:
		return
	var s: Dictionary = {}
	for x in _shortcuts:
		if x.id == _key_target:
			s = x
	if s.is_empty():
		return
	var events: Array = []
	if _key_append:
		var cur: Variant = _sc_current(s)
		if cur is Array:
			events = cur.duplicate()
	events.append(_key_event)
	_sc_changes[s.id] = events
	_after_sc_change()


# ─────────────────────────── 보조 창 ───────────────────────────

func _build_side_dialogs() -> void:
	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.use_native_dialog = true
	_file_dialog.file_selected.connect(func(p: String) -> void: _file_target.call(p.replace("/", "\\")))
	_file_dialog.dir_selected.connect(func(p: String) -> void: _file_target.call(p.replace("/", "\\")))
	add_child(_file_dialog)

	_text_dialog = ConfirmationDialog.new()
	_text_dialog.title = L.t("값 편집")
	_text_dialog.ok_button_text = L.t("적용")
	_text_dialog.cancel_button_text = L.t("취소")
	_text_dialog.min_size = Vector2i(560, 360)
	var vb := VBoxContainer.new()
	_text_dialog.add_child(vb)
	var hint := HubUI.label(L.t("고도 형식으로 적어 주세요. 예: [\"a\", \"b\"], {\"키\": 1}, Vector2(1, 2)"), "DimLabel")
	vb.add_child(hint)
	_text_edit = TextEdit.new()
	_text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_text_edit)
	_text_dialog.confirmed.connect(_on_text_confirmed)
	add_child(_text_dialog)

	_key_dialog = ConfirmationDialog.new()
	_key_dialog.title = L.t("단축키 입력")
	_key_dialog.ok_button_text = L.t("확인")
	_key_dialog.cancel_button_text = L.t("취소")
	_key_dialog.dialog_close_on_escape = false
	_key_dialog.min_size = Vector2i(360, 0)
	_key_label = HubUI.label("", "TitleLabel")
	_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key_label.custom_minimum_size = Vector2(320, 60)
	_key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_key_dialog.add_child(_key_label)
	_key_dialog.get_ok_button().focus_mode = Control.FOCUS_NONE
	_key_dialog.get_cancel_button().focus_mode = Control.FOCUS_NONE
	_key_dialog.window_input.connect(_on_key_input)
	_key_dialog.confirmed.connect(_on_key_confirmed)
	add_child(_key_dialog)


func _pick_path(is_dir: bool, filters: String, on_pick: Callable) -> void:
	_file_target = on_pick
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR if is_dir else FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.title = L.t("폴더 선택") if is_dir else L.t("파일 선택")
	_file_dialog.clear_filters()
	if not is_dir and filters.strip_edges() != "":
		_file_dialog.add_filter(filters.replace(",", ", "))
	_file_dialog.popup_centered_ratio(0.6)


func _edit_text(p: Dictionary, on_done: Callable) -> void:
	_text_target = {"p": p, "done": on_done}
	_text_edit.text = var_to_str(_value_of(p))
	_text_dialog.popup_centered()


func _on_text_confirmed() -> void:
	var p: Dictionary = _text_target.p
	var text := _text_edit.text.strip_edges()
	var v: Variant = str_to_var(text)
	var want := typeof(p.value)
	if (v == null and text != "null") or (want != TYPE_NIL and typeof(v) != want):
		HubUI.alert(self, L.t("값 편집"), L.t("값을 읽을 수 없어요. 원래 값과 같은 형식(%s)으로 적어 주세요.") % type_string(want))
		return
	_text_target.done.call(v)


# ─────────────────────────── 저장 ───────────────────────────

func _change_count() -> int:
	return _changes.size() + _sc_changes.size()


func _update_info() -> void:
	var msg := _file.path.replace("/", "\\")
	if _change_count() > 0:
		msg = L.t("바뀐 설정 %d개  ·  이 버전의 에디터가 열려 있으면 닫은 뒤 저장하세요 (에디터가 닫힐 때 설정을 덮어써요)") % _change_count()
	_info.text = msg
	get_ok_button().disabled = _change_count() == 0


func _save() -> void:
	var out := {}
	for p in _props:
		if _changes.has(p.key):
			out[p.key] = var_to_str(_changes[p.key])
	if not _sc_changes.is_empty():
		var sc_arr: Array = []
		var act_arr: Array = []
		var by_id := {}
		for s in _shortcuts:
			by_id[s.id] = s
		var merged := _sc_file.duplicate()
		for id in _sc_changes:
			if _sc_changes[id] is Array:
				merged[id] = _sc_changes[id]
			else:
				merged.erase(id)
		for id in merged:
			var is_action: bool = by_id.has(id) and by_id[id].is_action
			if is_action:
				act_arr.append({"name": id, "events": merged[id]})
			else:
				sc_arr.append({"name": id, "shortcuts": merged[id]})
		out["shortcuts"] = var_to_str(sc_arr)
		out["builtin_action_overrides"] = var_to_str(act_arr)
	var count := _change_count()
	var err := _file.save(out)
	if err != OK:
		HubUI.alert(get_parent(), L.t("저장하지 못했어요"), L.t("에디터 설정을 저장하지 못했어요 (%s)") % error_string(err))
		return
	Hub.toast.emit(L.t("에디터 설정 %d개를 저장했어요 (원본은 .bak 으로 백업)") % count)
	for p in _props:
		if _changes.has(p.key):
			p.value = _changes[p.key]
	_changes.clear()
	_sc_changes.clear()
	_load_shortcuts()
	_update_info()
