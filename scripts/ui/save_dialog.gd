## Menu → Sao lưu / chuyển máy: shows the save as a text code to copy (and,
## in the browser, a file to download), and takes a pasted code to continue
## a game from another device or browser.
class_name SaveDialog
extends AcceptDialog

var _code: TextEdit
var _paste: TextEdit
var _status: Label


func _init() -> void:
	title = "Sao lưu tiến trình"
	ok_button_text = "Đóng"
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(520, 0)
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var info := UiTheme.label("Game tự lưu mỗi 30 giây, cuối mỗi ngày và khi bạn chuyển ứng dụng. Muốn chơi tiếp trên máy khác hoặc trình duyệt khác: sao chép mã dưới đây, mở game ở đó rồi dán vào ô bên dưới.", 14, UiTheme.MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(info)
	v.add_child(UiTheme.label("Mã lưu của game hiện tại", 15, UiTheme.TEXT, true))
	_code = TextEdit.new()
	_code.editable = false
	_code.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_code.custom_minimum_size.y = 90
	v.add_child(_code)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(UiTheme.button("Sao chép mã", func():
		DisplayServer.clipboard_set(_code.text)
		_say("Đã sao chép mã lưu.", true)))
	if OS.has_feature("web"):
		h.add_child(UiTheme.button("Tải file lưu", func():
			SaveManager.download_save()
			_say("Đã tải file lưu về máy.", true)))
	v.add_child(h)
	v.add_child(HSeparator.new())
	v.add_child(UiTheme.label("Dán mã lưu để chơi tiếp", 15, UiTheme.TEXT, true))
	_paste = TextEdit.new()
	_paste.placeholder_text = "Dán mã bắt đầu bằng FT3D1: hoặc nội dung file lưu"
	_paste.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_paste.custom_minimum_size.y = 70
	v.add_child(_paste)
	var h2 := HBoxContainer.new()
	h2.add_theme_constant_override("separation", 6)
	h2.add_child(UiTheme.button("Dán từ bộ nhớ tạm", func(): _paste.text = DisplayServer.clipboard_get()))
	var load_btn := UiTheme.button("Tải mã này", _import)
	load_btn.add_theme_color_override("font_color", UiTheme.GOOD)
	h2.add_child(load_btn)
	v.add_child(h2)
	_status = UiTheme.label("", 14, UiTheme.GOOD)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)


func open() -> void:
	_code.text = SaveManager.export_code()
	_paste.text = ""
	_status.text = "" if SaveManager.storage_is_persistent() else "Trình duyệt này không giữ dữ liệu sau khi đóng trang (ví dụ cửa sổ ẩn danh). Hãy sao chép mã lưu trước khi thoát."
	_status.add_theme_color_override("font_color", UiTheme.WARN)
	var vp := get_viewport().get_visible_rect().size / get_tree().root.content_scale_factor
	popup_centered(Vector2(minf(600, vp.x - 24), 0))


func _import() -> void:
	var r := SaveManager.import_code(_paste.text)
	_say(r.message, r.ok)
	if r.ok:
		_code.text = SaveManager.export_code()
		EventBus.selection_changed.emit("", 0)
		EventBus.toast.emit(r.message, true)


func _say(text: String, good: bool) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", UiTheme.GOOD if good else UiTheme.BAD)
