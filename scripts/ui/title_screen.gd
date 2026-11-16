## Màn hình chính: the first thing the player sees when the game opens,
## over the live factory. Continue the saved game, start a new one, open
## Cài đặt or pick a language. The game stays paused until it closes.
class_name TitleScreen
extends Control

## Set once the player leaves the title screen, so rebuilding the scene for
## a language change in the middle of a game goes straight back to it.
static var dismissed := false

var _hud: Node
var _confirm: ConfirmationDialog
var _speed_before := 1
## Short screens (a phone held sideways): smaller title, no tagline,
## one-line game card and lower buttons, so it all fits above the languages.
var _compact := false
var _col: VBoxContainer


func _init(hud: Node) -> void:
	_hud = hud
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func open() -> void:
	dismissed = false
	_speed_before = maxi(1, TimeManager.speed)
	TimeManager.set_speed(0)
	_compact = false
	_build()
	visible = true
	_fit.call_deferred()


func _fit() -> void:
	if not _compact and _col and _col.get_combined_minimum_size().y > size.y - 90:
		_compact = true
		_build()


func close(new_game := false) -> void:
	dismissed = true
	visible = false
	TimeManager.set_speed(_speed_before)
	_hud.title_closed(new_game)


func _process(_delta: float) -> void:
	# Space or another key must not start the game behind the title screen.
	if visible and TimeManager.speed != 0:
		TimeManager.set_speed(0)


func _build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.06, 0.1, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var shade := TextureRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.texture = _shade_texture()
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	col.offset_left = 64
	col.offset_right = 64 + 560
	col.offset_bottom = -76  # the languages row
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 8 if _compact else 12)
	add_child(col)
	_col = col

	var title := UiTheme.label(tr("Quản Lý Nhà Máy"), 30 if _compact else 44, Color.WHITE, true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("outline_size", 8)
	col.add_child(title)
	var sub := UiTheme.label("FACTORY TYCOON 3D", 18, UiTheme.WARN, true)
	sub.add_theme_constant_override("outline_size", 6)
	sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	col.add_child(sub)
	var tag := UiTheme.label(tr("Từ một xưởng nhựa nhỏ thành tập đoàn đa quốc gia."), 16, Color(1, 1, 1, 0.85))
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(tag)
	var gap := Control.new()
	gap.custom_minimum_size.y = 12
	col.add_child(gap)
	tag.visible = not _compact
	gap.visible = not _compact

	var sim := GameManager.sim
	var has_game := SaveManager.load_note in ["loaded", "backup"] or sim.day() > 1 or sim.state.tutorial_step > 0
	if has_game:
		var card := PanelContainer.new()
		card.custom_minimum_size.x = 320
		card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		card.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.09, 0.12, 0.17, 0.8), 10, 12))
		var cv: BoxContainer = HBoxContainer.new() if _compact else VBoxContainer.new()
		cv.add_theme_constant_override("separation", 10 if _compact else 2)
		if not _compact:
			cv.add_child(UiTheme.label(tr("Ván đang chơi"), 13, UiTheme.MUTED))
		cv.add_child(UiTheme.label("%s · %s" % [tr("Ngày %d") % sim.day(), sim.expansion.tier_name()], 17, UiTheme.TEXT, true))
		cv.add_child(UiTheme.label(Fmt.money(sim.state.cash), 17, UiTheme.GOOD if sim.state.cash >= 0 else UiTheme.BAD, true))
		card.add_child(cv)
		col.add_child(card)
		col.add_child(_big(tr("Chơi tiếp"), func(): close(), true))
		col.add_child(_big(tr("Chơi mới"), func(): _confirm.popup_centered()))
	else:
		col.add_child(_big(tr("Bắt đầu chơi"), func(): close(), true))
	col.add_child(_big(tr("Cài đặt"), func(): _hud.open_settings(true)))

	# Languages along the bottom, each in its own script, so anyone can find theirs.
	var langs := HFlowContainer.new()
	langs.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	langs.offset_left = 64
	langs.offset_right = -24
	langs.offset_top = -64
	langs.offset_bottom = -16
	langs.add_theme_constant_override("h_separation", 6)
	for l in I18n.languages:
		var code: String = l[0]
		var b := UiTheme.button(l[1], func(): _hud._change_language(code))
		b.toggle_mode = true
		b.set_pressed_no_signal(code == I18n.current())
		langs.add_child(b)
	add_child(langs)

	_confirm = ConfirmationDialog.new()
	_confirm.title = tr("Chơi lại từ đầu?")
	_confirm.dialog_text = tr("Tiến trình hiện tại sẽ bị xóa. Kim cương và quản lý cấp cao được giữ lại.")
	_confirm.ok_button_text = tr("Chơi lại")
	_confirm.cancel_button_text = tr("Hủy")
	_confirm.confirmed.connect(func():
		GameManager.new_game()
		EventBus.selection_changed.emit("", 0)
		close(true)
		_hud.show_toast(tr("Bắt đầu game mới."), true))
	add_child(_confirm)


func _big(text: String, callback: Callable, primary := false) -> Button:
	var b := UiTheme.button(text, callback)
	b.custom_minimum_size = Vector2(320, 46 if _compact else 58)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.add_theme_font_size_override("font_size", roundi((17 if _compact else 20) * UiTheme.TEXT_SCALE))
	b.add_theme_font_override("font", UiTheme.font(600))
	if primary:
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, UiTheme.panel_style(UiTheme.ACCENT.lightened(0.1 if st == "hover" else 0.0), 10, 10))
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
	return b


## Dark on the left, where the title and buttons are, fading to the scene.
static func _shade_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0.04, 0.06, 0.1, 0.92))
	g.set_color(1, Color(0.04, 0.06, 0.1, 0.0))
	g.add_point(0.45, Color(0.04, 0.06, 0.1, 0.7))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 4
	return t
