## Reads and writes the single save slot as JSON. Autosaves every 60 s
## and when the game closes.
extends Node

const SAVE_DIR := "user://saves/"
const SAVE_PATH := SAVE_DIR + "slot_1.json"
const AUTOSAVE_SECONDS := 60.0

var _timer := 0.0


func _ready() -> void:
	get_tree().auto_accept_quit = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()


func _process(delta: float) -> void:
	if GameManager.sim == null:
		return
	_timer += delta
	if _timer >= AUTOSAVE_SECONDS:
		_timer = 0.0
		save_game()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	if GameManager.sim == null:
		return false
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write save: %s" % FileAccess.get_open_error())
		return false
	f.store_string(GameManager.sim.to_json())
	f.close()
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	return GameManager.sim.load_json(text)


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
