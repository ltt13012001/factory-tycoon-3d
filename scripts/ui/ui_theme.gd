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

static var _fonts := {}


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
	t.default_font_size = 15
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())
	t.set_color("font_color", "Label", TEXT)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := panel_style(BG_LIGHT, 7, 8)
		sb.content_margin_top = 5
		sb.content_margin_bottom = 5
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
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	var sep := StyleBoxLine.new()
	sep.color = Color(1, 1, 1, 0.12)
	t.set_stylebox("separator", "HSeparator", sep)
	return t


static func label(text: String, size: int = 15, color: Color = TEXT, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", font(600))
	return l


static func button(text: String, callback: Callable, disabled: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(callback)
	return b
