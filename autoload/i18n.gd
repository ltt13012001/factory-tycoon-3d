## Game languages. The game is written in Vietnamese: every text in the code
## is the Vietnamese original, wrapped in tr(), and each other language is a
## JSON file in data/i18n/ that maps the Vietnamese text to its translation.
## Adding a language = adding one file (see data/i18n/README.md), no code.
##
## The choice is kept in user://settings.cfg. A first start picks the
## device language when the game has it, otherwise English; a player who
## already has a save from before languages existed stays in Vietnamese.
extends Node

signal language_changed(code: String)

const I18N_DIR := "res://data/i18n/"
const SETTINGS_PATH := "user://settings.cfg"
const SOURCE := "vi"
const SOURCE_NAME := "Tiếng Việt"

## [code, name in its own language], in menu order. Filled from the files.
var languages: Array = []
var _translations := {}


func _ready() -> void:
	languages = [[SOURCE, SOURCE_NAME]]
	_load_files()
	var code := _saved_language()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
			code = a.trim_prefix("--lang=")
	if code == "" or not has_language(code):
		code = _first_start_language()
	TranslationServer.set_locale(code)


func _load_files() -> void:
	var names := []
	for f in DirAccess.get_files_at(I18N_DIR):
		var n := f.trim_suffix(".remap")
		if n.ends_with(".json") and not names.has(n):
			names.append(n)
	names.sort()
	var found := []
	for n in names:
		var text := FileAccess.get_file_as_string(I18N_DIR + n)
		var data = JSON.parse_string(text)
		if typeof(data) != TYPE_DICTIONARY or not data.has("_language"):
			push_warning("i18n: skipping %s (not a language file)" % n)
			continue
		var meta: Dictionary = data._language
		var t := Translation.new()
		t.locale = str(meta.code)
		var strings: Dictionary = data.get("strings", {})
		for k in strings:
			var v := str(strings[k])
			if v != "":
				t.add_message(k, v)
		TranslationServer.add_translation(t)
		_translations[t.locale] = t
		found.append([t.locale, str(meta.name), int(meta.get("order", 50))])
	found.sort_custom(func(a, b): return a[2] < b[2])
	for f in found:
		languages.append([f[0], f[1]])


func has_language(code: String) -> bool:
	for l in languages:
		if l[0] == code:
			return true
	return false


## The language in use, as its code ("vi", "en", "zh_CN", ...).
func current() -> String:
	var loc := TranslationServer.get_locale()
	for l in languages:
		if l[0] == loc:
			return loc
	# The engine may report "en_US" for "en" and the like.
	for l in languages:
		if loc.begins_with(l[0]) or l[0].begins_with(loc):
			return l[0]
	return SOURCE


func language_name(code: String) -> String:
	for l in languages:
		if l[0] == code:
			return l[1]
	return code


## Switches language and remembers it. Texts already on screen change when
## the scene is rebuilt (the HUD does that right after, see hud.gd).
func set_language(code: String) -> void:
	if not has_language(code):
		return
	TranslationServer.set_locale(code)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("ui", "language", code)
	cfg.save(SETTINGS_PATH)
	UiTheme.clear_fonts()
	language_changed.emit(code)


func _saved_language() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return ""
	return str(cfg.get_value("ui", "language", ""))


func _first_start_language() -> String:
	if SaveManager.has_save():
		return SOURCE
	var os_lang := OS.get_locale_language()
	var os_full := OS.get_locale()
	for l in languages:
		if l[0] == os_full or l[0] == os_lang or l[0].split("_")[0] == os_lang:
			return l[0]
	return "en" if has_language("en") else SOURCE
