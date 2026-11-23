class_name HubIcons
extends RefCounted
## 고도 엔진 기본(에디터) 아이콘. SVG 원본은 GodotIconData에 있다.
## 흰색으로 바꿔 둔 아이콘을 버튼 테마의 icon_*_color로 칠해서 쓴다.

static var _cache := {}


## size: 화면에 보일 논리 크기(px). 버튼·메뉴용은 선명하도록 2배 해상도로 그리고
## 테마의 icon_max_width로 크기를 맞춘다. 크기 제한이 없는 곳(LineEdit 등)은 hidpi=false.
static func icon(name: String, size := 16, hidpi := true) -> Texture2D:
	var key := "%s@%d%s" % [name, size, "x2" if hidpi else ""]
	if _cache.has(key):
		return _cache[key]
	if not GodotIconData.SVG.has(name):
		push_warning("아이콘 없음: " + name)
		return null
	var svg: String = GodotIconData.SVG[name]
	var img := Image.new()
	var err := img.load_svg_from_string(svg, float(size) / 16.0 * (2.0 if hidpi else 1.0))
	if err != OK:
		return null
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
