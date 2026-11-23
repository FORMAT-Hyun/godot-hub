class_name HubTheme
extends RefCounted
## 고도 4 기본 에디터 테마 색(#363d4a 계열 + 하늘색 강조)을 바탕으로 만든 허브 테마.

const BG := Color("#1d2128")
const SIDEBAR := Color("#262b34")
const PANEL := Color("#2b313b")
const ROW := Color("#2a303a")
const ROW_HOVER := Color("#363d4a")
const BORDER := Color("#3b4250")
const BUTTON := Color("#3a414e")
const BUTTON_HOVER := Color("#454d5c")
const BUTTON_PRESSED := Color("#30363f")
const FIELD := Color("#1f232a")
const ACCENT := Color("#70bafa")
const PRIMARY := Color("#478cbf")
const PRIMARY_HOVER := Color("#549acd")
const TEXT := Color("#e0e0e0")
const TEXT_DIM := Color("#97a0ae")
const TEXT_DISABLED := Color("#666e7c")
const WARNING := Color("#ffde66")
const ERROR := Color("#ff786b")
const SUCCESS := Color("#73e68c")
const DOTNET := Color("#b98cff")

static var _theme: Theme
static var bold_font: Font


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func box(bg: Color, radius := 4, border := Color.TRANSPARENT, border_width := 0, margin_h := 8.0, margin_v := 4.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if border_width > 0:
		sb.border_color = border
		sb.set_border_width_all(border_width)
	sb.content_margin_left = margin_h
	sb.content_margin_right = margin_h
	sb.content_margin_top = margin_v
	sb.content_margin_bottom = margin_v
	return sb


static func _make_font(weight: int) -> SystemFont:
	var kr := SystemFont.new()
	kr.font_names = PackedStringArray(["Noto Sans KR", "Malgun Gothic", "Apple SD Gothic Neo", "NanumGothic"])
	kr.font_weight = weight
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans", "Segoe UI", "Malgun Gothic"])
	font.font_weight = weight
	var fallbacks: Array[Font] = [kr]
	font.fallbacks = fallbacks
	return font


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font = _make_font(400)
	t.default_font_size = 14
	bold_font = _make_font(700)

	# ── 글자 ──────────────────────────────────────
	t.set_color("font_color", "Label", TEXT)
	_label_variation(t, "HeaderLabel", bold_font, 22, TEXT)
	_label_variation(t, "TitleLabel", bold_font, 15, TEXT)
	_label_variation(t, "DimLabel", null, 12, TEXT_DIM)
	_label_variation(t, "ColumnLabel", null, 12, TEXT_DIM)
	_label_variation(t, "SectionLabel", bold_font, 13, TEXT_DIM)

	# ── 기본 버튼 ─────────────────────────────────
	var focus := box(Color.TRANSPARENT, 4, ACCENT, 1)
	focus.draw_center = false
	for type in ["Button", "OptionButton", "MenuButton"]:
		_button_styles(t, type,
			box(BUTTON, 4, BORDER, 1, 10, 5),
			box(BUTTON_HOVER, 4, BORDER, 1, 10, 5),
			box(BUTTON_PRESSED, 4, BORDER, 1, 10, 5),
			box(BUTTON.darkened(0.25), 4, BORDER.darkened(0.2), 1, 10, 5),
			focus, TEXT, TEXT)
		t.set_constant("h_separation", type, 6)
		t.set_constant("icon_max_width", type, 16)

	# Unity Hub의 파란 "New project" 버튼 자리 → 고도 블루
	t.set_type_variation("PrimaryButton", "Button")
	_button_styles(t, "PrimaryButton",
		box(PRIMARY, 4, Color.TRANSPARENT, 0, 14, 6),
		box(PRIMARY_HOVER, 4, Color.TRANSPARENT, 0, 14, 6),
		box(PRIMARY.darkened(0.15), 4, Color.TRANSPARENT, 0, 14, 6),
		box(PRIMARY.darkened(0.45), 4, Color.TRANSPARENT, 0, 14, 6),
		focus, Color.WHITE, Color.WHITE)

	# 테두리 없는 아이콘 버튼 (즐겨찾기, ⋯, ⚙)
	t.set_type_variation("FlatButton", "Button")
	_button_styles(t, "FlatButton",
		box(Color.TRANSPARENT, 4, Color.TRANSPARENT, 0, 6, 4),
		box(Color(1, 1, 1, 0.07), 4, Color.TRANSPARENT, 0, 6, 4),
		box(Color(1, 1, 1, 0.12), 4, Color.TRANSPARENT, 0, 6, 4),
		box(Color.TRANSPARENT, 4, Color.TRANSPARENT, 0, 6, 4),
		focus, TEXT, TEXT)

	# 사이드바 메뉴
	t.set_type_variation("SidebarButton", "Button")
	var side_pressed := box(Color(ACCENT, 0.13), 4, Color.TRANSPARENT, 0, 12, 8)
	side_pressed.border_width_left = 3
	side_pressed.border_color = ACCENT
	_button_styles(t, "SidebarButton",
		box(Color.TRANSPARENT, 4, Color.TRANSPARENT, 0, 12, 8),
		box(Color(1, 1, 1, 0.06), 4, Color.TRANSPARENT, 0, 12, 8),
		side_pressed,
		box(Color.TRANSPARENT, 4, Color.TRANSPARENT, 0, 12, 8),
		StyleBoxEmpty.new(), TEXT_DIM, TEXT)
	t.set_stylebox("hover_pressed", "SidebarButton", side_pressed)
	t.set_color("font_pressed_color", "SidebarButton", ACCENT)
	t.set_color("font_hover_pressed_color", "SidebarButton", ACCENT)
	t.set_color("icon_pressed_color", "SidebarButton", ACCENT)
	t.set_color("icon_hover_pressed_color", "SidebarButton", ACCENT)
	t.set_constant("h_separation", "SidebarButton", 10)

	# 필터 칩 (전체 / Stable / ...)
	t.set_type_variation("ChipButton", "Button")
	var chip_on := box(Color(PRIMARY, 0.35), 12, PRIMARY, 1, 12, 3)
	_button_styles(t, "ChipButton",
		box(Color.TRANSPARENT, 12, BORDER, 1, 12, 3),
		box(Color(1, 1, 1, 0.06), 12, BORDER, 1, 12, 3),
		chip_on,
		box(Color.TRANSPARENT, 12, BORDER, 1, 12, 3),
		StyleBoxEmpty.new(), TEXT_DIM, TEXT)
	t.set_stylebox("hover_pressed", "ChipButton", chip_on)
	t.set_color("font_pressed_color", "ChipButton", Color.WHITE)
	t.set_color("font_hover_pressed_color", "ChipButton", Color.WHITE)
	t.set_font_size("font_size", "ChipButton", 13)

	# ── 입력창 ────────────────────────────────────
	var field_focus := box(Color.TRANSPARENT, 4, ACCENT, 1, 8, 5)
	field_focus.draw_center = false
	t.set_stylebox("normal", "LineEdit", box(FIELD, 4, BORDER, 1, 8, 5))
	t.set_stylebox("focus", "LineEdit", field_focus)
	t.set_stylebox("read_only", "LineEdit", box(FIELD.darkened(0.1), 4, BORDER, 1, 8, 5))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", TEXT_DISABLED)
	t.set_color("caret_color", "LineEdit", TEXT)
	t.set_color("selection_color", "LineEdit", Color(ACCENT, 0.35))

	# CheckBox는 Button을 상속하므로 위 버튼 배경이 따라오지 않게 비워 둔다
	for type in ["CheckBox", "CheckButton"]:
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			var empty := StyleBoxEmpty.new()
			empty.content_margin_left = 2
			empty.content_margin_right = 4
			empty.content_margin_top = 3
			empty.content_margin_bottom = 3
			t.set_stylebox(state, type, empty)
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_pressed_color", type, TEXT)
		t.set_color("font_hover_pressed_color", type, Color.WHITE)

	# ── 패널 ──────────────────────────────────────
	_panel_variation(t, "ContentPanel", box(BG, 0, Color.TRANSPARENT, 0, 0, 0))
	var side := box(SIDEBAR, 0, Color.TRANSPARENT, 0, 12, 14)
	side.border_width_right = 1
	side.border_color = BORDER
	_panel_variation(t, "SidebarPanel", side)
	_panel_variation(t, "SidePanel", box(SIDEBAR, 6, BORDER, 1, 14, 12))
	_panel_variation(t, "RowPanel", box(ROW, 6, Color.TRANSPARENT, 0, 10, 8))
	_panel_variation(t, "RowPanelHover", box(ROW_HOVER, 6, Color.TRANSPARENT, 0, 10, 8))
	_panel_variation(t, "RowPanelSelected", box(Color(ACCENT, 0.16), 6, Color(ACCENT, 0.6), 1, 10, 8))
	_panel_variation(t, "CardPanel", box(PANEL, 8, BORDER, 1, 14, 12))
	_panel_variation(t, "CardPanelHover", box(ROW_HOVER, 8, BORDER.lightened(0.15), 1, 14, 12))
	_panel_variation(t, "CardPanelSelected", box(Color(PRIMARY, 0.18), 8, ACCENT, 2, 14, 12))
	# 고도 프로젝트 매니저 배치: 위쪽 탭 바 · 목록 칸 · 아래 상태 줄
	var top := box(SIDEBAR, 0, Color.TRANSPARENT, 0, 14, 6)
	top.border_width_bottom = 1
	top.border_color = BORDER
	_panel_variation(t, "TopBarPanel", top)
	var status := box(SIDEBAR, 0, Color.TRANSPARENT, 0, 12, 3)
	status.border_width_top = 1
	status.border_color = BORDER
	_panel_variation(t, "StatusBarPanel", status)
	_panel_variation(t, "ListPanel", box(FIELD, 4, BORDER, 1, 4, 4))
	_panel_variation(t, "PmRow", box(Color.TRANSPARENT, 4, Color.TRANSPARENT, 0, 10, 6))
	_panel_variation(t, "PmRowHover", box(Color(1, 1, 1, 0.05), 4, Color.TRANSPARENT, 0, 10, 6))
	_panel_variation(t, "PmRowSelected", box(Color(ACCENT, 0.14), 4, Color(ACCENT, 0.45), 1, 10, 6))
	t.set_type_variation("TopTabButton", "Button")
	var tab_on := box(Color.TRANSPARENT, 4, Color.TRANSPARENT, 0, 10, 5)
	_button_styles(t, "TopTabButton",
		box(Color.TRANSPARENT, 4, Color.TRANSPARENT, 0, 10, 5),
		box(Color(1, 1, 1, 0.06), 4, Color.TRANSPARENT, 0, 10, 5),
		tab_on,
		box(Color.TRANSPARENT, 4, Color.TRANSPARENT, 0, 10, 5),
		StyleBoxEmpty.new(), TEXT, Color.WHITE)
	t.set_stylebox("hover_pressed", "TopTabButton", tab_on)
	for c in ["font_pressed_color", "font_hover_pressed_color", "icon_pressed_color", "icon_hover_pressed_color"]:
		t.set_color(c, "TopTabButton", ACCENT)
	t.set_font("font", "TopTabButton", bold_font)
	t.set_font_size("font_size", "TopTabButton", 15)
	t.set_constant("h_separation", "TopTabButton", 6)

	var toast := box(PANEL, 6, BORDER, 1, 16, 10)
	toast.shadow_color = Color(0, 0, 0, 0.45)
	toast.shadow_size = 10
	_panel_variation(t, "ToastPanel", toast)

	# ── 팝업 메뉴 ─────────────────────────────────
	t.set_stylebox("panel", "PopupMenu", box(PANEL, 6, BORDER, 1, 4, 4))
	t.set_stylebox("hover", "PopupMenu", box(ROW_HOVER, 4, Color.TRANSPARENT, 0, 6, 4))
	var sep := StyleBoxLine.new()
	sep.color = BORDER
	sep.grow_begin = -4
	sep.grow_end = -4
	t.set_stylebox("separator", "PopupMenu", sep)
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_color("font_disabled_color", "PopupMenu", TEXT_DISABLED)
	t.set_constant("v_separation", "PopupMenu", 8)
	t.set_constant("item_start_padding", "PopupMenu", 8)
	t.set_constant("item_end_padding", "PopupMenu", 12)
	t.set_constant("icon_max_width", "PopupMenu", 16)

	# ── 창 / 대화상자 ─────────────────────────────
	var win := box(PANEL, 6, BORDER, 1, 0, 0)
	win.expand_margin_left = 1
	win.expand_margin_right = 1
	win.expand_margin_bottom = 1
	win.expand_margin_top = 32
	win.shadow_color = Color(0, 0, 0, 0.5)
	win.shadow_size = 16
	t.set_stylebox("embedded_border", "Window", win)
	t.set_stylebox("embedded_unfocused_border", "Window", win)
	t.set_constant("title_height", "Window", 32)
	t.set_color("title_color", "Window", TEXT)
	t.set_font("title_font", "Window", bold_font)
	t.set_stylebox("panel", "AcceptDialog", box(PANEL, 0, Color.TRANSPARENT, 0, 16, 12))
	t.set_constant("buttons_separation", "AcceptDialog", 10)
	t.set_stylebox("panel", "TooltipPanel", box(PANEL, 4, BORDER, 1, 8, 5))
	t.set_color("font_color", "TooltipLabel", TEXT)

	# ── 트리 (에디터 설정 분류) ─────────────────────
	t.set_stylebox("panel", "Tree", box(FIELD, 4, BORDER, 1, 4, 4))
	t.set_stylebox("focus", "Tree", StyleBoxEmpty.new())
	t.set_stylebox("selected", "Tree", box(Color(ACCENT, 0.18), 3))
	t.set_stylebox("selected_focus", "Tree", box(Color(ACCENT, 0.25), 3))
	t.set_stylebox("cursor", "Tree", StyleBoxEmpty.new())
	t.set_stylebox("cursor_unfocused", "Tree", StyleBoxEmpty.new())
	t.set_color("font_color", "Tree", TEXT)
	t.set_color("font_selected_color", "Tree", Color.WHITE)
	t.set_constant("v_separation", "Tree", 6)

	# ── 스크롤바 / 진행바 / 구분선 ──────────────────
	for type in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", type, box(Color.TRANSPARENT, 0, Color.TRANSPARENT, 0, 3, 3))
		t.set_stylebox("scroll_focus", type, box(Color.TRANSPARENT, 0, Color.TRANSPARENT, 0, 3, 3))
		t.set_stylebox("grabber", type, box(Color("#4a5263"), 4, Color.TRANSPARENT, 0, 3, 3))
		t.set_stylebox("grabber_highlight", type, box(Color("#5c6577"), 4, Color.TRANSPARENT, 0, 3, 3))
		t.set_stylebox("grabber_pressed", type, box(Color(ACCENT, 0.7), 4, Color.TRANSPARENT, 0, 3, 3))
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	t.set_stylebox("background", "ProgressBar", box(FIELD, 3, Color.TRANSPARENT, 0, 0, 0))
	t.set_stylebox("fill", "ProgressBar", box(PRIMARY, 3, Color.TRANSPARENT, 0, 0, 0))
	var hline := StyleBoxLine.new()
	hline.color = BORDER
	t.set_stylebox("separator", "HSeparator", hline)
	var vline := StyleBoxLine.new()
	vline.color = BORDER
	vline.vertical = true
	t.set_stylebox("separator", "VSeparator", vline)
	return t


static func _label_variation(t: Theme, name: String, font: Font, size: int, color: Color) -> void:
	t.set_type_variation(name, "Label")
	if font:
		t.set_font("font", name, font)
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, color)


static func _panel_variation(t: Theme, name: String, sb: StyleBox) -> void:
	t.set_type_variation(name, "PanelContainer")
	t.set_stylebox("panel", name, sb)


static func _button_styles(t: Theme, type: String, normal: StyleBox, hover: StyleBox, pressed: StyleBox,
		disabled: StyleBox, focus: StyleBox, font_color: Color, hover_color: Color) -> void:
	t.set_stylebox("normal", type, normal)
	t.set_stylebox("hover", type, hover)
	t.set_stylebox("pressed", type, pressed)
	t.set_stylebox("hover_pressed", type, pressed)
	t.set_stylebox("disabled", type, disabled)
	t.set_stylebox("focus", type, focus)
	t.set_color("font_color", type, font_color)
	t.set_color("font_hover_color", type, hover_color)
	t.set_color("font_pressed_color", type, hover_color)
	t.set_color("font_hover_pressed_color", type, hover_color)
	t.set_color("font_focus_color", type, font_color)
	t.set_color("font_disabled_color", type, TEXT_DISABLED)
	t.set_color("icon_normal_color", type, font_color)
	t.set_color("icon_hover_color", type, hover_color)
	t.set_color("icon_pressed_color", type, hover_color)
	t.set_color("icon_hover_pressed_color", type, hover_color)
	t.set_color("icon_focus_color", type, font_color)
	t.set_color("icon_disabled_color", type, TEXT_DISABLED)
