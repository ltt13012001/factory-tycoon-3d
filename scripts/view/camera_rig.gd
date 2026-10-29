## Isometric camera: Q/E rotate in 90° steps, mouse wheel zooms, left, right
## or middle drag (or WASD / arrow keys) pans, left click selects or places.
## Touch: one finger drags to pan (and glides on after a flick), a tap selects
## or places, two fingers pinch to zoom, move to pan and twist to turn freely.
## The HUD can also pan, zoom, turn and jump to a place (EventBus).
extends Node3D

const PITCH := -35.264
const MIN_SIZE := 12.0
const MAX_SIZE := 130.0
const PAN_SPEED := 22.0
## The whole site, including the plots east of the first factory.
const BOUNDS := Rect2(-75, -60, 190, 115)
## How fast a flicked camera slows down (per second).
const GLIDE_DAMPING := 4.0
## A touch that moves further than this (in screen pixels) is a drag, not a tap.
const TAP_SLOP := 14.0
## Two-finger twist (degrees) before the camera starts turning with the fingers.
const TWIST_START := 12.0

var camera: Camera3D
var build_mode := false

var _yaw_target := 45.0
var _size_target := 30.0
var _dragging := false
var _touches := {}  # finger index -> screen position
var _tap_pos := Vector2.ZERO
var _tap_valid := false
var _twist := 0.0
var _velocity := Vector2.ZERO  # screen-space pan speed after a flick
var _pad := Vector2.ZERO
var _focus := Vector3.INF
var _mouse_down := false
var _mouse_dragged := false
var _press_pos := Vector2.ZERO
var _last_drag_ms := 0


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
	EventBus.camera_focus_requested.connect(focus_on)
	EventBus.camera_pad_changed.connect(func(d): _pad = d)
	EventBus.camera_zoom_requested.connect(func(f): _size_target = clampf(_size_target * f, MIN_SIZE, MAX_SIZE))


func _process(delta: float) -> void:
	rotation_degrees.y = lerpf(rotation_degrees.y, _yaw_target, minf(1.0, delta * 8.0))
	camera.size = lerpf(camera.size, _size_target, minf(1.0, delta * 10.0))
	var input := Vector2(
		Input.get_axis(&"ui_left", &"ui_right") + _key_axis(KEY_A, KEY_D),
		Input.get_axis(&"ui_up", &"ui_down") + _key_axis(KEY_W, KEY_S))
	input += _pad
	if input.length() > 0.0 and not _ui_has_focus():
		_focus = Vector3.INF
		_pan(input.limit_length(1.0) * PAN_SPEED * delta * (camera.size / 34.0))
	if _velocity.length() > 0.5 and _touches.is_empty():
		_pan(_velocity * delta)
		_velocity *= maxf(0.0, 1.0 - GLIDE_DAMPING * delta)
	if _focus != Vector3.INF:
		position = position.lerp(_focus, minf(1.0, delta * 5.0))
		if position.distance_to(_focus) < 0.05:
			_focus = Vector3.INF


## Glides the camera to a point (and zoom level, 0 keeps the current one).
func focus_on(target: Vector3, zoom: float = 0.0) -> void:
	_velocity = Vector2.ZERO
	_focus = Vector3(clampf(target.x, BOUNDS.position.x, BOUNDS.end.x), 0, clampf(target.z, BOUNDS.position.y, BOUNDS.end.y))
	if zoom > 0.0:
		_size_target = clampf(zoom, MIN_SIZE, MAX_SIZE)


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


## Rotates the camera by 45° steps (negative turns left).
func rotate_step(steps: int) -> void:
	_yaw_target += 45.0 * steps


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
					_mouse_down = true
					_mouse_dragged = false
					_press_pos = event.position
				elif _mouse_down:
					_mouse_down = false
					if not _mouse_dragged:
						_click(event.position)
	elif event is InputEventMouseMotion and (_dragging or _mouse_down):
		if _mouse_down and not _mouse_dragged and event.position.distance_to(_press_pos) < TAP_SLOP:
			return
		_mouse_dragged = _mouse_down or _mouse_dragged
		_focus = Vector3.INF
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
			_velocity = Vector2.ZERO
			_focus = Vector3.INF
		else:
			_touches.erase(event.index)
			if Time.get_ticks_msec() - _last_drag_ms > 90 or not _touches.is_empty():
				_velocity = Vector2.ZERO  # the finger stopped before lifting
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
		var step: Vector2 = -event.relative * _units_per_px() * Vector2(1, 1.6)
		_pan(step)
		# Remember the finger's speed so a flick keeps the camera gliding.
		var dt := maxf(get_process_delta_time(), 1.0 / 120.0)
		_velocity = _velocity.lerp(step / dt, 0.5)
		_last_drag_ms = Time.get_ticks_msec()
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
	# Twisting turns the camera freely once the fingers clearly rotate.
	var turn := wrapf(rad_to_deg((a_new - b).angle() - (a_old - b).angle()), -180.0, 180.0)
	_twist += turn
	if absf(_twist) >= TWIST_START:
		_yaw_target += turn
		rotation_degrees.y = _yaw_target


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
	if kind == "site":
		EventBus.site_selected.emit("lot_%d" % id)
		return
	EventBus.selection_changed.emit(kind, id)
