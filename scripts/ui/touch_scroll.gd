## Lets a finger drag its parent ScrollContainer even when the drag starts on
## a button or card inside it, and keeps that button from being pressed by
## the drag. Mouse and wheel scrolling are left to the ScrollContainer.
class_name TouchScroll
extends Node

## A touch that moves further than this (in pixels) scrolls instead of tapping.
const SLOP := 12.0

var _index := -1
var _start := Vector2.ZERO
var _dragging := false
var _offset := 0.0


static func attach(scroll: ScrollContainer) -> void:
	scroll.add_child(TouchScroll.new())


func _input(event: InputEvent) -> void:
	var scroll := get_parent() as ScrollContainer
	if event is InputEventScreenTouch:
		if event.pressed:
			if _index == -1 and scroll.is_visible_in_tree() and scroll.get_global_rect().has_point(event.position):
				_index = event.index
				_start = event.position
				_dragging = false
		elif event.index == _index:
			_index = -1
			if _dragging:
				_dragging = false
				get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag and event.index == _index:
		if not _dragging:
			if event.position.distance_to(_start) < SLOP:
				return
			_dragging = true
			_offset = scroll.scroll_vertical
			_release_pressed_button()
		_offset = clampf(_offset - event.relative.y, 0.0, scroll.get_v_scroll_bar().max_value)
		scroll.scroll_vertical = roundi(_offset)
		get_viewport().set_input_as_handled()
		return
	# While dragging, the mouse events the touchscreen emulates must not reach
	# the button under the finger, or lifting the finger would press it.
	if _dragging and (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION:
		get_viewport().set_input_as_handled()


## Moves the emulated mouse off the button the drag started on and lets go,
## so the button sees a press that ended outside it and does nothing.
func _release_pressed_button() -> void:
	var away := Vector2(-10000, -10000)
	var motion := InputEventMouseMotion.new()
	motion.position = away
	motion.global_position = away
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(motion)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = away
	up.global_position = away
	get_viewport().push_input(up)
