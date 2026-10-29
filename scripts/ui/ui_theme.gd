## Builds the shared UI Theme and the Vietnamese-capable font
## (Be Vietnam Pro, SIL OFL, split into latin / latin-ext / vietnamese subsets).
class_name UiTheme
extends RefCounted

const BG := Color(0.09, 0.12, 0.17, 0.92)
const BG_LIGHT := Color(0.16, 0.2, 0.27, 0.95)
const ACCENT := Color("3d8bfd")
const GOOD := Color("4cd07d")
const BAD := Color("ff6b6b")
const WARN := Color("ffd166")
const TEXT := Color("eef2f7")
const MUTED := Color("9aa7b8")

## Every UI text size is multiplied by this, so text reads well at 1280x720.
const TEXT_SCALE := 1.2

static var _fonts := {}
static var _grabber: Texture2D


## True on phones and tablets, including the web build opened on a touch
## screen (Safari on iPad reports itself as a Mac, so check for touch), or
## with `-- --mobile` on desktop, for testing.
static func is_mobile() -> bool:
	if OS.has_feature("web") and DisplayServer.is_touchscreen_available():
		return true
	return OS.has_feature("mobile") or "--mobile" in OS.get_cmdline_user_args()


## Interface scale that keeps text and buttons a comfortable size on a small
## screen: about 190 logical pixels per inch of the screen's short side, but
## never less than 1.2 times the desktop size. Pass `-- --dpi=400` to test it on desktop.
static func auto_ui_scale() -> float:
	if not is_mobile():
		return 1.0
	if OS.has_feature("web"):
		# Browsers hide the real DPI: a short side under 600 CSS pixels is a phone.
		var css_short := float(JavaScriptBridge.eval("Math.min(screen.width, screen.height)", true))
		return 1.5 if css_short > 0.0 and css_short < 600.0 else 1.2
	var dpi := DisplayServer.screen_get_dpi()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dpi="):
			dpi = a.trim_prefix("--dpi=").to_int()
	var screen := DisplayServer.screen_get_size()
	var short_px := float(mini(screen.x, screen.y))
	var long_px := float(maxi(screen.x, screen.y))
	if short_px <= 0.0 or dpi <= 0:
		return 1.4
	# Logical height at scale 1 with the "expand" stretch aspect, in landscape.
	var base_h := short_px / minf(long_px / 1280.0, short_px / 720.0)
	var target_h := clampf(short_px / dpi * 190.0, 480.0, base_h)
	return clampf(snappedf(base_h / target_h, 0.1), 1.2, 1.8)


static func font(weight: int = 400) -> Font:
	if _fonts.has(weight):
		return _fonts[weight]
	var base := "res://assets/fonts/be-vietnam-pro-%s-%d-normal.woff2"
	var f: FontFile = load(base % ["latin", weight]).duplicate()
	f.fallbacks = [load(base % ["vietnamese", weight]), load(base % ["latin-ext", weight])]
	_fonts[weight] = f
	return f


static func panel_style(color: Color = BG, radius: int = 10, pad: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	return sb


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = font(400)
	t.default_font_size = 18
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())
	t.set_color("font_color", "Label", TEXT)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := panel_style(BG_LIGHT, 8, 12)
		sb.content_margin_top = 7
		sb.content_margin_bottom = 7
		match state:
			"hover":
				sb.bg_color = BG_LIGHT.lightened(0.15)
			"pressed":
				sb.bg_color = ACCENT
			"disabled":
				sb.bg_color = Color(0.2, 0.22, 0.26, 0.6)
			"focus":
				sb.draw_center = false
				sb.border_color = ACCENT
				sb.set_border_width_all(1)
		t.set_stylebox(state, "Button", sb)
	t.set_color("font_color", "Button", TEXT)
	t.set_font_size("font_size", "Button", 18)
	t.set_font_size("font_size", "CheckButton", 18)
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_font_size("title_font_size", "Window", 20)
	var bar_bg := panel_style(Color(1, 1, 1, 0.12), 4, 0)
	var bar_fill := panel_style(GOOD, 4, 0)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	var sep := StyleBoxLine.new()
	sep.color = Color(1, 1, 1, 0.12)
	t.set_stylebox("separator", "HSeparator", sep)
	return t


static func label(text: String, size: int = 15, color: Color = TEXT, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", roundi(size * TEXT_SCALE))
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", font(600))
	return l


static func toggle(text: String, on: bool, callback: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(callback)
	return c


static func bar(value: float, max_value: float, color: Color = GOOD, height: int = 10) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.max_value = max_value
	pb.value = value
	pb.show_percentage = false
	pb.custom_minimum_size.y = height
	pb.add_theme_stylebox_override("fill", panel_style(color, 4, 0))
	return pb


static func button(text: String, callback: Callable, disabled: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(callback)
	return b


## A horizontal slider with a large, finger-friendly handle. callback gets
## the new value (int) whenever it changes.
static func slider(min_value: int, max_value: int, step: int, value: int, callback: Callable) -> HSlider:
	var sl := HSlider.new()
	sl.min_value = min_value
	sl.max_value = max_value
	sl.step = step
	sl.value = value
	sl.focus_mode = Control.FOCUS_NONE
	sl.custom_minimum_size = Vector2(240, 40)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var track := panel_style(Color(1, 1, 1, 0.18), 4, 0)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := panel_style(ACCENT, 4, 0)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	sl.add_theme_stylebox_override("slider", track)
	sl.add_theme_stylebox_override("grabber_area", fill)
	sl.add_theme_stylebox_override("grabber_area_highlight", fill)
	var g := _grabber_texture()
	for k in ["grabber", "grabber_highlight", "grabber_disabled"]:
		sl.add_theme_icon_override(k, g)
	sl.value_changed.connect(func(v): callback.call(int(v)))
	return sl


## A round white handle, drawn once.
static func _grabber_texture() -> Texture2D:
	if _grabber:
		return _grabber
	const R := 14
	var img := Image.create(R * 2, R * 2, false, Image.FORMAT_RGBA8)
	for y in R * 2:
		for x in R * 2:
			var d := Vector2(x + 0.5 - R, y + 0.5 - R).length()
			var a := clampf(R - d, 0.0, 1.0)
			var c := Color.WHITE if d < R - 3 else ACCENT.lightened(0.2)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, a))
	_grabber = ImageTexture.create_from_image(img)
	return _grabber


## A row of buttons where the one matching `current` is highlighted.
static func choice(options: Array, labels: Array, current, callback: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	for i in options.size():
		var opt = options[i]
		var b := button(labels[i], func(): callback.call(opt))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if opt == current:
			b.add_theme_stylebox_override("normal", panel_style(ACCENT, 8, 12))
			b.add_theme_color_override("font_color", Color.WHITE)
		h.add_child(b)
	return h
