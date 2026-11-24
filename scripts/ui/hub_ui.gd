class_name HubUI
extends RefCounted
## 화면을 코드로 만들 때 쓰는 작은 도우미 모음


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func vspace(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = height
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func label(text: String, variation := "", min_width := 0.0) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if min_width > 0.0:
		l.custom_minimum_size.x = min_width
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func tag(text: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", HubTheme.box(Color(color, 0.14), 3, Color(color, 0.45), 1, 6, 0))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", 11)
	p.add_child(l)
	return p


static func icon_rect(tex: Texture2D, size: float, color := Color.WHITE) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.self_modulate = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


static func flat_icon_button(icon_name: String, tooltip: String) -> Button:
	var b := Button.new()
	b.theme_type_variation = "FlatButton"
	b.icon = HubIcons.icon(icon_name)
	b.tooltip_text = tooltip
	b.focus_mode = Control.FOCUS_NONE
	return b


static func confirm(parent: Node, title: String, text: String, ok_text: String, on_ok: Callable) -> void:
	var d := ConfirmationDialog.new()
	d.title = title
	d.dialog_text = text
	d.dialog_autowrap = true
	d.ok_button_text = ok_text
	d.cancel_button_text = L.t("취소")
	d.confirmed.connect(on_ok)
	d.visibility_changed.connect(func() -> void:
		if not d.visible:
			d.queue_free())
	parent.add_child(d)
	d.popup_centered(Vector2i(460, 0))


## 한 줄 입력 창. 확인을 누르면 on_ok(입력한 글자)를 부른다.
static func prompt(parent: Node, title: String, message: String, initial: String, ok_text: String, on_ok: Callable) -> void:
	var d := ConfirmationDialog.new()
	d.title = title
	d.ok_button_text = ok_text
	d.cancel_button_text = L.t("취소")
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	d.add_child(vb)
	var msg := label(message, "DimLabel", 420)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(msg)
	var edit := LineEdit.new()
	edit.text = initial
	vb.add_child(edit)
	edit.text_submitted.connect(func(_t: String) -> void:
		d.hide()
		on_ok.call(edit.text))
	d.confirmed.connect(func() -> void: on_ok.call(edit.text))
	d.visibility_changed.connect(func() -> void:
		if not d.visible:
			d.queue_free())
	parent.add_child(d)
	d.popup_centered(Vector2i(460, 0))
	edit.call_deferred("grab_focus")
	edit.call_deferred("select_all")


static func alert(parent: Node, title: String, text: String) -> void:
	var d := AcceptDialog.new()
	d.title = title
	d.dialog_text = text
	d.dialog_autowrap = true
	d.ok_button_text = L.t("확인")
	d.visibility_changed.connect(func() -> void:
		if not d.visible:
			d.queue_free())
	parent.add_child(d)
	d.popup_centered(Vector2i(460, 0))


static func dir_dialog(parent: Node, title: String, on_selected: Callable) -> FileDialog:
	var d := FileDialog.new()
	d.title = title
	d.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	d.access = FileDialog.ACCESS_FILESYSTEM
	d.use_native_dialog = true
	d.dir_selected.connect(on_selected)
	parent.add_child(d)
	return d


static func rel_time(unix: int) -> String:
	if unix <= 0:
		return "-"
	var diff := int(Time.get_unix_time_from_system()) - unix
	if diff < 60:
		return L.t("방금 전")
	if diff < 3600:
		return L.t("%d분 전") % floori(diff / 60.0)
	if diff < 86400:
		return L.t("%d시간 전") % floori(diff / 3600.0)
	if diff < 172800:
		return L.t("어제")
	if diff < 86400 * 30:
		return L.t("%d일 전") % floori(diff / 86400.0)
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(unix + bias)
	return "%04d. %02d. %02d." % [d.year, d.month, d.day]


static func human_size(bytes: int) -> String:
	if bytes <= 0:
		return "-"
	if bytes >= 1024 * 1024 * 1024:
		return "%.1f GB" % (bytes / 1073741824.0)
	return "%.0f MB" % (bytes / 1048576.0)
