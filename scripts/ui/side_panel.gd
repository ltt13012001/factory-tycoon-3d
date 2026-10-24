## Base for the left-hand management panels. Rebuilds its content when the
## data it shows changes (checked 4 times a second), never mid-click.
class_name SidePanel
extends PanelContainer

var title := ""
var _box: VBoxContainer
var _signature := ""
var _timer := 0.0


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_box)
	visibility_changed.connect(refresh)


func _process(delta: float) -> void:
	if not visible or GameManager.sim == null:
		return
	_timer += delta
	if _timer < 0.25:
		return
	_timer = 0.0
	var sig := signature(GameManager.sim)
	if sig != _signature and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_signature = sig
		_rebuild()


func refresh() -> void:
	_signature = ""
	_timer = 1.0


func _rebuild() -> void:
	for c in _box.get_children():
		c.queue_free()
	_box.add_child(UiTheme.label(title, 20, UiTheme.TEXT, true))
	build(_box, GameManager.sim)


## Override: a string that changes whenever the panel should redraw.
func signature(_sim: Simulation) -> String:
	return ""


## Override: add the panel's controls to box.
func build(_b: VBoxContainer, _sim: Simulation) -> void:
	pass


# --- Helpers ---------------------------------------------------------------

func card(b: VBoxContainer) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.BG_LIGHT, 8, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	pc.add_child(v)
	b.add_child(pc)
	return v


func row(parent: Container, left: String, right: String, right_color: Color = UiTheme.TEXT) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := UiTheme.label(left, 14, UiTheme.MUTED)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(UiTheme.label(right, 14, right_color))
	parent.add_child(h)
	return h


func buttons(parent: Container, items: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	for b in items:
		h.add_child(b)
	parent.add_child(h)
	return h


func wrap_label(text: String, size: int = 13, color: Color = UiTheme.MUTED) -> Label:
	var l := UiTheme.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 380
	return l
