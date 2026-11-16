## Cài đặt: every option of the game in one window, opened from the
## Cài đặt button in the top bar and from the title screen: language,
## graphics, interface size, saving and backups, starting over.
class_name SettingsPanel
extends Control

var _hud: Node
var _box: VBoxContainer
var _from_title := false


func _init(hud: Node) -> void:
	_hud = hud
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.09, 0.12, 0.17, 0.98), 14, 18))
	center.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(600, 0)
	panel.add_child(scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 10)
	scroll.add_child(_box)
	resized.connect(_fit)


## from_title: opened over the title screen, so the in-game items
## (save now, start over) are left out.
func open(from_title := false) -> void:
	_from_title = from_title
	_build()
	visible = true
	_fit.call_deferred()


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Fits the window to short phone screens; the content scrolls.
func _fit() -> void:
	var scroll: ScrollContainer = _box.get_parent()
	var want := _box.get_combined_minimum_size().y
	scroll.custom_minimum_size.y = minf(want, size.y - 80)
	scroll.custom_minimum_size.x = minf(600, size.x - 60)


func _build() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	var head := HBoxContainer.new()
	var title := UiTheme.label(tr("Cài đặt"), 22, UiTheme.TEXT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UiTheme.button("✕", close))
	_box.add_child(head)

	_section(tr("Ngôn ngữ") + ("" if tr("Ngôn ngữ") == "Language" else " · Language"))
	var langs := GridContainer.new()
	langs.columns = 3
	langs.add_theme_constant_override("h_separation", 6)
	langs.add_theme_constant_override("v_separation", 6)
	for l in I18n.languages:
		var code: String = l[0]
		var b := UiTheme.button(l[1], func(): _hud._change_language(code))
		b.toggle_mode = true
		b.set_pressed_no_signal(code == I18n.current())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 46
		langs.add_child(b)
	_box.add_child(langs)

	_section(tr("Đồ họa (máy yếu chọn Thấp)"))
	var g := HBoxContainer.new()
	g.add_theme_constant_override("separation", 6)
	var choices := [[-1, tr("Tự động (%s)") % tr(Graphics.NAMES[Graphics.tier]) if Graphics.auto else tr("Tự động")]]
	for i in Graphics.NAMES.size():
		choices.append([i, tr(Graphics.NAMES[i])])
	for c in choices:
		var tier: int = c[0]
		var b := UiTheme.button(c[1], func(): _set_graphics(tier))
		b.toggle_mode = true
		b.set_pressed_no_signal(Graphics.auto if tier < 0 else (not Graphics.auto and Graphics.tier == tier))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 46
		g.add_child(b)
	_box.add_child(g)

	_section(tr("Cỡ chữ và nút"))
	var s := HBoxContainer.new()
	s.add_theme_constant_override("separation", 6)
	s.add_child(UiTheme.button(tr("Chữ nhỏ hơn (A−)"), func():
		_hud.set_ui_scale(_hud._ui_scale - 0.1)
		_build.call_deferred()))
	var pct := UiTheme.label("%d%%" % roundi(_hud._ui_scale * 100), 18, UiTheme.TEXT, true)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pct.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(pct)
	s.add_child(UiTheme.button(tr("Chữ to hơn (A+)"), func():
		_hud.set_ui_scale(_hud._ui_scale + 0.1)
		_build.call_deferred()))
	_box.add_child(s)

	_section(tr("Lưu game"))
	var info := tr("Game tự lưu mỗi 30 giây, cuối mỗi ngày và khi bạn chuyển ứng dụng.")
	if SaveManager.last_saved > 0.0:
		var ago := int(Time.get_unix_time_from_system() - SaveManager.last_saved)
		info += tr(" (tự lưu %s trước)") % (tr("%d giây") % ago if ago < 60 else tr("%d phút") % (ago / 60))
	var il := UiTheme.label(info, 14, UiTheme.MUTED)
	il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(il)
	var sv := HBoxContainer.new()
	sv.add_theme_constant_override("separation", 6)
	if not _from_title:
		sv.add_child(UiTheme.button(tr("Lưu game"), func():
			var saved := SaveManager.save_game()
			_hud.show_toast(tr("Đã lưu game.") if saved else tr("Không lưu được! Thử Cài đặt → Sao lưu để giữ mã lưu."), saved)
			_build.call_deferred()))
	sv.add_child(UiTheme.button(tr("Sao lưu / chuyển máy khác"), func(): _hud._save_dialog.open()))
	_box.add_child(sv)

	if not _from_title:
		_section(tr("Ván chơi"))
		var gm := HBoxContainer.new()
		gm.add_theme_constant_override("separation", 6)
		gm.add_child(UiTheme.button(tr("Màn hình chính"), func():
			close()
			_hud.show_title()))
		var restart := UiTheme.button(tr("Chơi lại từ đầu"), func():
			close()
			_hud._confirm.popup_centered())
		restart.add_theme_color_override("font_color", UiTheme.BAD)
		gm.add_child(restart)
		_box.add_child(gm)

	var ver := UiTheme.label(tr("Phiên bản %s") % ProjectSettings.get_setting("application/config/version", ""), 12, UiTheme.MUTED)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_box.add_child(ver)
	_fit.call_deferred()


func _section(text: String) -> void:
	_box.add_child(HSeparator.new())
	_box.add_child(UiTheme.label(text, 16, UiTheme.WARN, true))


func _set_graphics(tier: int) -> void:
	var g: Graphics = get_tree().current_scene.get_node("Graphics")
	g.set_tier(tier)
	_hud.show_toast(tr("Đồ họa: %s%s") % [tr("Tự động – ") if Graphics.auto else "", tr(Graphics.NAMES[Graphics.tier])], true)
	_build.call_deferred()
