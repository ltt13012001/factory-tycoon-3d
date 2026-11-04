## Reads and writes the save slot as JSON, and keeps it safe:
## - every save goes to a temporary file first and is renamed over the slot,
##   so a phone that kills the game half-way through a write never leaves a
##   cut-off file; the previous save is kept as a backup;
## - in the browser the save is also copied into localStorage, because some
##   browsers (Safari in a page inside another page, private windows) do not
##   keep the game's file storage between visits;
## - loading takes the newest copy that reads back cleanly; a save that
##   cannot be read is set aside, never overwritten by a fresh game;
## - the game saves every 30 s, at the end of every game day, when it closes
##   and whenever a phone or browser tab goes to the background;
## - the player can copy the whole save as a text code and paste it back on
##   another device or browser (Menu → Sao lưu).
extends Node

const SAVE_DIR := "user://saves/"
const SAVE_PATH := SAVE_DIR + "slot_1.json"
const BACKUP_PATH := SAVE_DIR + "slot_1.bak.json"
const TEMP_PATH := SAVE_DIR + "slot_1.tmp"
const AUTOSAVE_SECONDS := 30.0
const WEB_KEY := "ft3d-save-1"
## Text codes start with this so a pasted code is recognised.
const CODE_PREFIX := "FT3D1:"

## Unix time of the last successful save (0 = not saved in this session).
var last_saved := 0.0
## What happened when the game started: "" (new game), "loaded", "backup"
## (main file unreadable, backup used), "broken" (nothing readable, files set
## aside), "newer" (save from a newer game version, set aside).
var load_note := ""

var _timer := 0.0
var _web_callback: JavaScriptObject


func _ready() -> void:
	get_tree().auto_accept_quit = false
	EventBus.day_ended.connect(func(_d): save_game.call_deferred())
	if OS.has_feature("web"):
		# iPhone and iPad Safari often skip blur events when the player
		# switches app or closes the tab; pagehide / visibilitychange fire.
		_web_callback = JavaScriptBridge.create_callback(func(_args): save_game())
		var window := JavaScriptBridge.get_interface("window")
		var document := JavaScriptBridge.get_interface("document")
		if window and document:
			window.addEventListener("pagehide", _web_callback)
			document.addEventListener("visibilitychange", _web_callback)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED or (what == NOTIFICATION_APPLICATION_FOCUS_OUT and (OS.has_feature("mobile") or OS.has_feature("web"))):
		save_game()


func _process(delta: float) -> void:
	if GameManager.sim == null:
		return
	_timer += delta
	if _timer >= AUTOSAVE_SECONDS:
		save_game()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH) or _web_read() != ""


## False when the browser forgets the game's files and localStorage after
## the page closes (private window, storage blocked): saves only last
## for this visit, so the player should keep a code (Menu → Sao lưu).
func storage_is_persistent() -> bool:
	if not OS.has_feature("web"):
		return true
	return OS.is_userfs_persistent() or _web_storage_works()


func save_game() -> bool:
	_timer = 0.0
	if GameManager.sim == null:
		return false
	var text := save_text(GameManager.sim)
	var ok := write_slot(text)
	if OS.has_feature("web"):
		ok = _web_write(text) or ok
	if ok:
		last_saved = Time.get_unix_time_from_system()
	return ok


## The save as JSON, with the time it was written (ignored when loading).
static func save_text(sim: Simulation) -> String:
	var d := sim.to_save_dict()
	d["saved_at"] = int(Time.get_unix_time_from_system())
	return JSON.stringify(d, "", true)


## Writes text to the slot without ever leaving a half-written file: the
## temporary file is written and read back first, the current save becomes
## the backup, then the temporary file takes its place.
static func write_slot(text: String, dir := SAVE_DIR) -> bool:
	var slot := dir + "slot_1.json"
	var backup := dir + "slot_1.bak.json"
	var temp := dir + "slot_1.tmp"
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(temp, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write save: %s" % FileAccess.get_open_error())
		return false
	f.store_string(text)
	f.close()
	if FileAccess.get_file_as_string(temp) != text:
		push_error("Save did not read back correctly.")
		DirAccess.remove_absolute(temp)
		return false
	if FileAccess.file_exists(slot):
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(backup)
		DirAccess.rename_absolute(slot, backup)
	var err := DirAccess.rename_absolute(temp, slot)
	if err != OK:
		push_error("Cannot replace save: %s" % err)
		return false
	return true


## Loads the newest readable copy (slot, backup, browser storage). Returns
## false when there is nothing to load or nothing readable.
func load_game() -> bool:
	var result := load_best(GameManager.sim, [
		["slot", FileAccess.get_file_as_string(SAVE_PATH) if FileAccess.file_exists(SAVE_PATH) else ""],
		["backup", FileAccess.get_file_as_string(BACKUP_PATH) if FileAccess.file_exists(BACKUP_PATH) else ""],
		["web", _web_read()],
	])
	load_note = result.note
	if result.note == "broken" or result.note == "newer":
		_set_aside(result.note)
	return result.ok


## Picks the copy with the latest game time among those that parse and
## migrate, and loads it into sim. copies: [[name, text], ...].
## Returns {ok, note, source}.
static func load_best(sim: Simulation, copies: Array) -> Dictionary:
	var best := {}
	var best_name := ""
	var any := false
	var newer := false
	for c in copies:
		var text: String = c[1]
		if text.strip_edges() == "":
			continue
		any = true
		var parsed = JSON.parse_string(text)
		if not parsed is Dictionary:
			continue
		if int(parsed.get("save_version", 0)) > SaveMigrations.CURRENT_VERSION:
			newer = true
			continue
		if best.is_empty() or _newer_than(parsed, best):
			best = parsed
			best_name = c[0]
	if best.is_empty():
		return {"ok": false, "note": ("newer" if newer else ("broken" if any else "")), "source": ""}
	if not sim.load_save_dict(best):
		return {"ok": false, "note": "broken", "source": ""}
	return {"ok": true, "note": "loaded" if best_name != "backup" else "backup", "source": best_name}


static func _newer_than(a: Dictionary, b: Dictionary) -> bool:
	var ta := int(a.get("tick", 0))
	var tb := int(b.get("tick", 0))
	if ta != tb:
		return ta > tb
	return int(a.get("saved_at", 0)) > int(b.get("saved_at", 0))


## Keeps unreadable saves next to the slot so a fresh game never wipes them.
func _set_aside(note: String) -> void:
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	for p in [SAVE_PATH, BACKUP_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.rename_absolute(p, p.get_basename() + ".%s-%s.json" % [note, stamp])
	var old := _web_read()
	if old != "":
		_web_set(WEB_KEY + "-" + note, old)
		_web_set(WEB_KEY, "")


func delete_save() -> void:
	for p in [SAVE_PATH, BACKUP_PATH, TEMP_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	if OS.has_feature("web"):
		_web_set(WEB_KEY, "")
	last_saved = 0.0


# --- Save codes: copy the save to another device or browser -------------------

## The current game as one line of text (compressed JSON in base64).
func export_code() -> String:
	return encode(save_text(GameManager.sim))


static func encode(json: String) -> String:
	var raw := json.to_utf8_buffer()
	var packed := raw.compress(FileAccess.COMPRESSION_GZIP)
	return CODE_PREFIX + str(raw.size()) + ":" + Marshalls.raw_to_base64(packed)


## Reads a code made by encode() (or plain save JSON) back to JSON; "" if
## it is not a save.
static func decode(code: String) -> String:
	var t := code.strip_edges()
	if t.begins_with("{"):
		return t
	if not t.begins_with(CODE_PREFIX):
		return ""
	t = t.trim_prefix(CODE_PREFIX)
	var colon := t.find(":")
	if colon < 0:
		return ""
	var size := t.left(colon).to_int()
	var packed := Marshalls.base64_to_raw(t.substr(colon + 1).replace(" ", "").replace("\n", ""))
	if size <= 0 or packed.is_empty():
		return ""
	var raw := packed.decompress(size, FileAccess.COMPRESSION_GZIP)
	return raw.get_string_from_utf8()


## Loads a pasted code into the running game and saves it. Returns a message
## for the player and whether it worked.
func import_code(code: String) -> Dictionary:
	var json := decode(code)
	var parsed = JSON.parse_string(json) if json != "" else null
	if not parsed is Dictionary or not parsed.has("tick"):
		return {"ok": false, "message": "Mã lưu không đúng. Hãy dán lại toàn bộ mã."}
	if int(parsed.get("save_version", 0)) > SaveMigrations.CURRENT_VERSION:
		return {"ok": false, "message": "Mã lưu từ bản game mới hơn. Hãy cập nhật game."}
	# Keep the current game as the backup in case the code was the wrong one.
	save_game()
	if not GameManager.sim.load_save_dict(parsed):
		return {"ok": false, "message": "Không đọc được mã lưu."}
	save_game()
	return {"ok": true, "message": "Đã tải tiến trình từ mã lưu (ngày %d)." % GameManager.sim.day()}


## Browser only: downloads the save as a file the player can keep.
func download_save() -> void:
	if OS.has_feature("web"):
		var text := save_text(GameManager.sim)
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), "factory-tycoon-ngay-%d.json" % GameManager.sim.day(), "application/json")


# --- Browser storage -------------------------------------------------------------

func _web_storage_works() -> bool:
	if not OS.has_feature("web"):
		return false
	var probe = JavaScriptBridge.eval("(function(){try{localStorage.setItem('ft3d-probe','1');localStorage.removeItem('ft3d-probe');return true;}catch(e){return false;}})()", true)
	return probe == true


func _web_write(text: String) -> bool:
	return _web_set(WEB_KEY, text)


func _web_read() -> String:
	if not OS.has_feature("web"):
		return ""
	var v = JavaScriptBridge.eval("(function(){try{return localStorage.getItem('%s')||'';}catch(e){return '';}})()" % WEB_KEY, true)
	return v if v is String else ""


func _web_set(key: String, text: String) -> bool:
	if not OS.has_feature("web"):
		return false
	# A JSON string literal is a valid JavaScript string literal.
	var ok = JavaScriptBridge.eval("(function(){try{%s;return true;}catch(e){return false;}})()" % (
		("localStorage.removeItem(%s)" % JSON.stringify(key)) if text == "" else
		("localStorage.setItem(%s,%s)" % [JSON.stringify(key), JSON.stringify(text)])), true)
	return ok == true
