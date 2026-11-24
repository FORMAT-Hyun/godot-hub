class_name L
extends RefCounted
## 다국어. 코드에는 한국어 원문을 쓰고 L.t("원문")으로 번역한다.
## 번역은 res://i18n/keys.json(원문 목록)과 res://i18n/<언어>.json(같은 순서의 번역 목록)에 있다.
## 버튼 · 라벨에 그대로 넣는 고정 문자열은 고도가 자동으로 번역해 준다(auto translate).

const KEYS_PATH := "res://i18n/keys.json"

## 고도 에디터가 지원하는 언어 전부 (코드, 그 언어로 쓴 이름)
const LANGUAGES := [
	["en", "English"],
	["ar", "العربية"],
	["bg", "Български"],
	["bn", "বাংলা"],
	["ca", "Català"],
	["cs", "Čeština"],
	["de", "Deutsch"],
	["el", "Ελληνικά"],
	["eo", "Esperanto"],
	["es", "Español"],
	["es_AR", "Español (Argentina)"],
	["et", "Eesti"],
	["fa", "فارسی"],
	["fi", "Suomi"],
	["fr", "Français"],
	["ga", "Gaeilge"],
	["gl", "Galego"],
	["he", "עברית"],
	["hu", "Magyar"],
	["id", "Bahasa Indonesia"],
	["it", "Italiano"],
	["ja", "日本語"],
	["ka", "ქართული"],
	["ko", "한국어"],
	["nl", "Nederlands"],
	["pl", "Polski"],
	["pt", "Português"],
	["pt_BR", "Português (Brasil)"],
	["ro", "Română"],
	["ru", "Русский"],
	["sk", "Slovenčina"],
	["sv", "Svenska"],
	["ta", "தமிழ்"],
	["th", "ไทย"],
	["tok", "Toki Pona"],
	["tr", "Türkçe"],
	["uk", "Українська"],
	["vi", "Tiếng Việt"],
	["zh_Hans", "简体中文"],
	["zh_Hant", "繁體中文"],
]

static var current := "ko"
static var _translation: Translation


static func t(text: String) -> String:
	return String(TranslationServer.translate(text))


## lang: "" 이면 시스템 언어를 따른다. 지원하지 않는 언어면 영어.
static func apply(lang: String) -> void:
	var code := lang if lang != "" else _system_language()
	if _translation:
		TranslationServer.remove_translation(_translation)
		_translation = null
	current = code
	if code != "ko":
		_translation = _load(code)
		if _translation == null:
			current = "en"
			_translation = _load("en")
		if _translation:
			TranslationServer.add_translation(_translation)
	TranslationServer.set_locale(current)


static func _system_language() -> String:
	var loc := OS.get_locale()  # 예: ko_KR, zh_CN, pt_BR
	var lang := OS.get_locale_language()
	if lang == "zh":
		return "zh_Hant" if loc.contains("TW") or loc.contains("HK") or loc.contains("Hant") else "zh_Hans"
	for l in LANGUAGES:
		if l[0] == loc:
			return loc
	for l in LANGUAGES:
		if l[0] == lang:
			return lang
	return "en"


static func _load(code: String) -> Translation:
	var keys: Variant = JSON.parse_string(FileAccess.get_file_as_string(KEYS_PATH))
	var path := "res://i18n/%s.json" % code
	if not (keys is Array) or not FileAccess.file_exists(path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var values: Variant = data.get("strings", []) if data is Dictionary else data
	if not (values is Array):
		return null
	var tr := Translation.new()
	tr.locale = code
	for i in mini(keys.size(), values.size()):
		var v := str(values[i])
		if v != "":
			tr.add_message(str(keys[i]), v)
	return tr
