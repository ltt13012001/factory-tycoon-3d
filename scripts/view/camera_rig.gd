## Isometric camera: Q/E rotate in 90° steps, mouse wheel zooms, right or
## middle drag (or WASD / arrow keys) pans, left click selects or places.
## Touch: one finger drags to pan, a tap selects or places, two fingers pinch
## to zoom, move to pan and twist to rotate.
extends Node3D

const PITCH := -35.264
const MIN_SIZE := 12.0
const MAX_SIZE := 90.0
const PAN_SPEED := 22.0
const BOUNDS := Rect2(-50, -40, 100, 80)
## A touch that moves further than this (in screen pixels) is a drag, not a tap.
const TAP_SLOP := 14.0
## Two-finger twist (degrees) that turns the camera one 90° step.
const TWIST_STEP := 40.0

var camera: Camera3D
var build_mode := false

var _yaw_target := 45.0
var _size_target := 30.0
var _dragging := false
var _touches := {}  # finger index -> screen position
var _tap_pos := Vector2.ZERO
var _tap_valid := false
var _twist := 0.0


func _ready() -> void:
	rotation_degrees = Vector3(0, _yaw_target, 0)
	position = Vector3(-2, 0, 0)
	var pitch := Node3D.new()
	pitch.rotation_degrees.x = PITCH
	add_child(pitch)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = _size_target
	camera.position = Vector3(0, 0, 80)
	camera.near = 1.0
	camera.far = 300.0
	pitch.add_child(camera)
	camera.make_current()
	EventBus.build_mode_changed.connect(func(active): build_mode = active)
	EventBus.camera_rotate_requested.connect(rotate_step)


func _process(delta: float) -> void:
	rotation_degrees.y = lerpf(rotation_degrees.y, _yaw_target, minf(1.0, delta * 8.0))
	camera.size = lerpf(camera.size, _size_target, minf(1.0, delta * 10.0))
	var input := Vector2(
		Input.get_axis(&"ui_left", &"ui_right") + _key_axis(KEY_A, KEY_D),
		Input.get_axis(&"ui_up", &"ui_down") + _key_axis(KEY_W, KEY_S))
	if input.length() > 0.0 and not _ui_has_focus():
		_pan(input.limit_length(1.0) * PAN_SPEED * delta * (camera.size / 34.0))


func _key_axis(neg: Key, pos: Key) -> float:
	return (1.0 if Input.is_physical_key_pressed(pos) else 0.0) - (1.0 if Input.is_physical_key_pressed(neg) else 0.0)


func _ui_has_focus() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit


func _pan(screen_delta: Vector2) -> void:
	var right := global_transform.basis.x
	var forward := -global_transform.basis.z
	right.y = 0
	forward.y = 0
	position += right.normalized() * screen_delta.x - forward.normalized() * screen_delta.y
	position.x = clampf(position.x, BOUNDS.position.x, BOUNDS.end.x)
	position.z = clampf(position.z, BOUNDS.position.y, BOUNDS.end.y)


## Rotates the camera by 90° steps (negative turns left).
func rotate_step(steps: int) -> void:
	_yaw_target += 90.0 * steps


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_touch(event)
		return
	# Touchscreens also send emulated mouse events; the touch handler above
	# already deals with them.
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_Q:
				_yaw_target -= 90.0
			KEY_E:
				_yaw_target += 90.0
			KEY_SPACE:
				TimeManager.toggle_pause()
			KEY_ESCAPE:
				if build_mode:
					EventBus.build_mode_changed.emit(false)
				else:
					EventBus.selection_changed.emit("", 0)
	elif event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_size_target = clampf(_size_target * 0.9, MIN_SIZE, MAX_SIZE)
			MOUSE_BUTTON_WHEEL_DOWN:
				_size_target = clampf(_size_target * 1.1, MIN_SIZE, MAX_SIZE)
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_dragging = event.pressed
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_click(event.position)
	elif event is InputEventMouseMotion and _dragging:
		_pan(-event.relative * _units_per_px() * Vector2(1, 1.6))
	elif event is InputEventMagnifyGesture:
		_size_target = clampf(_size_target / event.factor, MIN_SIZE, MAX_SIZE)
	elif event is InputEventPanGesture:
		_pan(event.delta * 0.5)


func _touch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			_tap_valid = _touches.size() == 1
			_tap_pos = event.position
			_twist = 0.0
		else:
			_touches.erase(event.index)
			if _tap_valid and _touches.is_empty() and not event.canceled:
				_click(event.position)
			_tap_valid = false
		return
	if not _touches.has(event.index):
		return
	if _touches.size() == 1:
		if _tap_valid and event.position.distance_to(_tap_pos) < TAP_SLOP:
			return
		_tap_valid = false
		_touches[event.index] = event.position
		_pan(-event.relative * _units_per_px() * Vector2(1, 1.6))
		return
	# Two (or more) fingers: use the first two.
	_tap_valid = false
	var keys := _touches.keys()
	var other: int = keys[1] if keys[0] == event.index else keys[0]
	var a_old: Vector2 = _touches[event.index]
	var b: Vector2 = _touches[other]
	var a_new: Vector2 = event.position
	_touches[event.index] = a_new
	var d_old := a_old.distance_to(b)
	var d_new := a_new.distance_to(b)
	if d_old > 1.0 and d_new > 1.0:
		_size_target = clampf(_size_target * d_old / d_new, MIN_SIZE, MAX_SIZE)
		camera.size = _size_target
	_pan(-(a_new - a_old) * 0.5 * _units_per_px() * Vector2(1, 1.6))
	_twist += rad_to_deg((a_new - b).angle() - (a_old - b).angle())
	_twist = wrapf(_twist, -180.0, 180.0)
	if absf(_twist) >= TWIST_STEP:
		rotate_step(1 if _twist > 0 else -1)
		_twist = 0.0


func _units_per_px() -> float:
	return camera.size / get_viewport().get_visible_rect().size.y


func _click(screen_pos: Vector2) -> void:
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 400.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var body: Object = hit.get("collider")
	var kind := ""
	var id := 0
	if body and body.has_meta("select_kind"):
		kind = body.get_meta("select_kind")
		id = body.get_meta("select_id")
	if build_mode:
		if kind == "slot":
			if GameManager.buy_machine(id).ok:
				EventBus.build_mode_changed.emit(false)
		return
	if kind == "slot":
		return
	EventBus.selection_changed.emit(kind, id)
