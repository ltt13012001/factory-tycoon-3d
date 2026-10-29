## A worker (or the owner) as a small person: legs, arms, body in the role's
## colour, a face and a hard hat. Position follows the simulation:
## operators stand at their machine, warehouse workers walk each haul leg in
## step with the job's remaining ticks, technicians and the owner walk to
## the machine they are repairing. Staff with nothing to do sit in the rest
## area, go home through the gate after the shift and gather in the yard
## with signs during a strike. A speech bubble shows what they think.
extends Node3D

const WALK_SPEED := 3.5
const BODY_SCALE := 1.15
const PANTS := Color("34495e")
const SHOES := Color("2b2b2b")
const SKINS := [Color("f1c9a5"), Color("e0ac83"), Color("c68c60"), Color("f5d6b8")]
const HAIRS := [Color("1f1a17"), Color("3b2a20"), Color("2b2b2b"), Color("5a3b26")]
const BUBBLE_COLORS := {
	"happy": Color("e8f8e3"), "calm": Color("ffffff"), "tired": Color("e3e8f2"),
	"sad": Color("dcecff"), "angry": Color("ffe0dc"),
}

var employee_id := 0
var role := ""
var idle_index := 0
## Seat in the rest area and place in a strike picket, set by FactoryView.
var rest_index := 0

var _visual: Node3D
var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _legs: Array[Node3D] = []  # [left thigh, left shin, right thigh, right shin]
var _arms: Array[Node3D] = []  # [left, right]
var _mouth: MeshInstance3D
var _brows: Array[MeshInstance3D] = []
var _carry: MeshInstance3D
var _sign: Node3D
var _bubble: Node3D
var _bubble_label: Label3D
var _bubble_bg: MeshInstance3D
var _bubble_text := ""
var _bubble_timer := 0.0
var _bubble_next := 0.0
var _phase_key := ""
var _phase_start := Vector3.ZERO
var _phase_route := PackedVector3Array()
var _walk_target := Vector3.INF
var _walk_route := PackedVector3Array()
var _time := 0.0
var _stride := 0.0
var _moving := false
## Pose for this frame: stand, sit, operate, repair, strike.
var _pose := "stand"
var _carrying := false
var _face_yaw := INF  # yaw to turn to once standing still
var _kind := "calm"

# Owner only
var _owner_target_machine := 0
var _owner_wait := 0.0


func _ready() -> void:
	var shirt := Palette.OPERATOR
	match role:
		"warehouse":
			shirt = Palette.WAREHOUSE
		"owner":
			shirt = Palette.OWNER
		"technician":
			shirt = Palette.TECHNICIAN
		"manager":
			shirt = Palette.MANAGER
	var seed := employee_id if role != "owner" else 3
	var skin: Color = SKINS[seed % SKINS.size()]
	var hair: Color = HAIRS[(seed / 2) % HAIRS.size()]
	_visual = Node3D.new()
	_visual.scale = Vector3.ONE * BODY_SCALE
	add_child(_visual)

	# Legs: thigh and shin pivots so the worker can walk and sit.
	_hips = Node3D.new()
	_hips.position = Vector3(0, 0.9, 0)
	_visual.add_child(_hips)
	var pants := PANTS if role != "manager" else Color("37474f")
	for side in [-1, 1]:
		var thigh := Node3D.new()
		thigh.position = Vector3(0.11 * side, 0, 0)
		_hips.add_child(thigh)
		_capsule(thigh, 0.085, 0.5, Vector3(0, -0.22, 0), pants)
		var shin := Node3D.new()
		shin.position = Vector3(0, -0.44, 0)
		thigh.add_child(shin)
		_capsule(shin, 0.075, 0.5, Vector3(0, -0.21, 0), pants)
		Palette.box(shin, Vector3(0.14, 0.09, 0.26), Vector3(0, -0.43, 0.05), SHOES)
		_legs.append(thigh)
		_legs.append(shin)

	# Body, arms and head hang off the torso pivot at the hips.
	_torso = Node3D.new()
	_torso.position = Vector3(0, 0.9, 0)
	_visual.add_child(_torso)
	var body := _capsule(_torso, 0.21, 0.66, Vector3(0, 0.3, 0), shirt)
	body.scale = Vector3(1, 1, 0.72)
	Palette.box(_torso, Vector3(0.4, 0.07, 0.3), Vector3(0, 0.03, 0), Color("3e2723"))  # belt
	match role:
		"warehouse":
			# Hi-vis stripes
			for y in [0.2, 0.38]:
				Palette.box(_torso, Vector3(0.43, 0.05, 0.31), Vector3(0, y, 0), Color("e0f2f1"))
		"technician":
			Palette.box(_torso, Vector3(0.45, 0.12, 0.33), Vector3(0, 0.06, 0), Color("6d4c41"))  # tool belt
			Palette.box(_torso, Vector3(0.08, 0.16, 0.06), Vector3(0.2, 0.0, 0.14), Color("b0bec5"))
		"manager", "owner":
			Palette.box(_torso, Vector3(0.09, 0.36, 0.04), Vector3(0, 0.36, 0.15), Color("c62828") if role == "owner" else Color("1565c0"))
		_:
			Palette.box(_torso, Vector3(0.16, 0.14, 0.03), Vector3(0.09, 0.42, 0.15), shirt.darkened(0.25))  # pocket
	for side in [-1, 1]:
		var arm := Node3D.new()
		arm.position = Vector3(0.28 * side, 0.55, 0)
		_torso.add_child(arm)
		_capsule(arm, 0.068, 0.56, Vector3(0, -0.25, 0), shirt)
		Palette.sphere(arm, 0.075, Vector3(0, -0.56, 0), skin)
		_arms.append(arm)
	if role == "manager":
		Palette.box(_arms[1], Vector3(0.04, 0.34, 0.26), Vector3(0, -0.52, 0.12), Color("8d6e63"))  # clipboard

	_head = Node3D.new()
	_head.position = Vector3(0, 0.78, 0)
	_torso.add_child(_head)
	Palette.cylinder(_head, 0.07, 0.12, Vector3(0, -0.07, 0), skin)
	Palette.sphere(_head, 0.17, Vector3(0, 0.1, 0), skin)
	for side in [-1, 1]:
		Palette.sphere(_head, 0.026, Vector3(0.065 * side, 0.13, 0.152), Color("1b1b1b"))
		var brow := Palette.box(_head, Vector3(0.07, 0.018, 0.02), Vector3(0.065 * side, 0.185, 0.155), hair)
		_brows.append(brow)
	_mouth = Palette.box(_head, Vector3(0.08, 0.02, 0.02), Vector3(0, 0.04, 0.158), Color("7b2d26"))
	Palette.sphere(_head, 0.035, Vector3(0, 0.09, 0.17), skin.darkened(0.08))  # nose
	if role == "owner" or role == "manager":
		var cap := Palette.sphere(_head, 0.18, Vector3(0, 0.17, -0.015), hair)
		cap.scale = Vector3(1, 0.62, 1)
	else:
		var helmet := Palette.sphere(_head, 0.195, Vector3(0, 0.17, 0), Palette.HELMET if role != "technician" else Color("eceff1"))
		helmet.scale = Vector3(1, 0.68, 1)
		Palette.cylinder(_head, 0.23, 0.025, Vector3(0, 0.15, 0.03), Palette.HELMET if role != "technician" else Color("eceff1"))
		if seed % 2 == 1:
			Palette.sphere(_head, 0.08, Vector3(0, 0.08, -0.18), hair)  # hair bun

	_carry = Palette.box(_torso, Vector3(0.5, 0.4, 0.4), Vector3(0, 0.3, 0.42), Palette.BOX)
	_carry.visible = false
	if role != "owner":
		_build_sign()
		Palette.pick_body(self, Vector3(0.8, 2.0, 0.8), Vector3(0, 1.0, 0), "worker", employee_id)
	_build_bubble()
	_bubble_next = 2.0 + fmod(employee_id * 2.3, 9.0)


func _capsule(parent: Node, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = radius
	cap.height = height
	cap.radial_segments = 10
	cap.rings = 4
	mi.mesh = cap
	mi.position = pos
	mi.material_override = Palette.mat(color)
	parent.add_child(mi)
	return mi


## A protest sign held up during a strike.
func _build_sign() -> void:
	_sign = Node3D.new()
	_sign.position = Vector3(0, -0.55, 0.05)
	_arms[1].add_child(_sign)
	Palette.cylinder(_sign, 0.025, 0.9, Vector3(0, -0.3, 0), Color("8d6e63"))
	Palette.box(_sign, Vector3(0.95, 0.6, 0.03), Vector3(0, -0.9, 0), Color("fafafa"))
	var l := Label3D.new()
	l.text = "TĂNG\nLƯƠNG!"
	l.font = UiTheme.font(600)
	l.font_size = 48
	l.pixel_size = 0.0062
	l.modulate = Color("c62828")
	l.outline_size = 0
	l.position = Vector3(0, -0.9, 0.02)
	l.rotation = Vector3(PI, 0, 0)  # upright once the arm is raised
	_sign.add_child(l)
	_sign.visible = false


## Speech bubble over the head: a rounded white card that always faces the
## camera, with the text on top.
func _build_bubble() -> void:
	_bubble = Node3D.new()
	_bubble.position = Vector3(0, 2.75, 0)
	add_child(_bubble)
	_bubble_bg = MeshInstance3D.new()
	_bubble_bg.mesh = QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.albedo_texture = _bubble_texture()
	m.render_priority = 1
	_bubble_bg.material_override = m
	_bubble.add_child(_bubble_bg)
	_bubble_label = Label3D.new()
	_bubble_label.font = UiTheme.font(600)
	_bubble_label.font_size = 40
	_bubble_label.pixel_size = 0.012
	_bubble_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble_label.no_depth_test = true
	_bubble_label.render_priority = 2
	_bubble_label.outline_size = 0
	_bubble_label.modulate = Color("263238")
	_bubble.add_child(_bubble_label)
	_bubble.visible = false


static var _bubble_tex: Texture2D


## Rounded rectangle with a small tail at the bottom, drawn once.
static func _bubble_texture() -> Texture2D:
	if _bubble_tex:
		return _bubble_tex
	const W := 128
	const H := 64
	const R := 18.0
	const TAIL := 12
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var body_h := H - TAIL
	for y in H:
		for x in W:
			var a := 0.0
			if y < body_h:
				var cx := clampf(x + 0.5, R, W - R)
				var cy := clampf(y + 0.5, R, body_h - R)
				a = clampf(R - Vector2(x + 0.5 - cx, y + 0.5 - cy).length(), 0.0, 1.0)
			else:
				# Tail: a small triangle under the middle
				var half := (H - y) * 0.9
				a = 1.0 if absf(x + 0.5 - W / 2.0) < half else 0.0
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_bubble_tex = ImageTexture.create_from_image(img)
	return _bubble_tex


func _process(delta: float) -> void:
	_time += delta
	var sim: Simulation = GameManager.sim
	var before := position
	_pose = "stand"
	_carrying = false
	_face_yaw = INF
	var e := {}
	if role == "owner":
		_update_owner(sim, delta)
	else:
		e = sim.state.find_by_id(sim.state.employees, employee_id)
		if e.is_empty():
			return
		if not _update_common(sim, e, delta):
			match role:
				"operator":
					_update_operator(sim, e, delta)
				"technician":
					_update_technician(sim, e, delta)
				"manager":
					_update_manager(sim, delta)
				_:
					_update_warehouse(sim, e, delta)
	var moved := position - before
	_moving = moved.length() > 0.001
	if _moving:
		_stride += moved.length() / BODY_SCALE * 4.2
		var look := Vector3(moved.x, 0, moved.z)
		if look.length() > 0.0001:
			rotation.y = lerp_angle(rotation.y, atan2(look.x, look.z), minf(1.0, delta * 12.0))
	elif _face_yaw != INF:
		rotation.y = lerp_angle(rotation.y, _face_yaw, minf(1.0, delta * 8.0))
	_animate(delta)
	if role != "owner":
		_update_bubble(sim, e, delta)


## Off shift, strike and rest apply to every role. Returns true when one
## of them decided where the worker goes this frame.
func _update_common(sim: Simulation, e: Dictionary, delta: float) -> bool:
	_sign.visible = false
	if e.get("off", false):
		_phase_key = ""
		_carry.visible = false
		if not visible:
			return true
		_walk(FactoryLayout.STAFF_GATE, delta)
		if position.distance_to(FactoryLayout.STAFF_GATE) < 0.1:
			visible = false  # gone home
		return true
	if not visible:
		# Back in the morning: walk in from the gate.
		position = FactoryLayout.STAFF_GATE
		_walk_target = Vector3.INF
		visible = true
	if sim.employees.on_strike() and role != "manager":
		_phase_key = ""
		_carry.visible = false
		var spot := FactoryLayout.picket_spot(rest_index)
		_walk(spot, delta)
		if position.distance_to(spot) < 0.2:
			_pose = "strike"
			_sign.visible = true
			_face_yaw = 0.0
		return true
	if e.get("rest", false) and (role != "warehouse" or e.job.is_empty()):
		_phase_key = ""
		_carry.visible = false
		var seat := FactoryLayout.rest_seat(rest_index, sim.buildings.level("break_room") > 0)
		_walk(seat[0], delta)
		if position.distance_to(seat[0]) < 0.15:
			_pose = "sit" if seat[2] else "stand"
			_face_yaw = seat[1]
		return true
	return false


## Where idle operators and technicians wait for a moment before they go
## to the rest area.
func _idle_spot(fallback: Vector3, step: Vector3) -> Vector3:
	return fallback + step * idle_index


## Stand beside a machine's control side, facing it.
func _work_spot(m: Dictionary) -> Vector3:
	return FactoryLayout.slot_position(int(m.slot)) + Vector3(-1.6, 0, 1.2)


func _update_operator(sim: Simulation, e: Dictionary, delta: float) -> void:
	var target := _idle_spot(FactoryLayout.OPERATOR_IDLE, Vector3(0, 0, -0.9))
	var m := {}
	if e.machine_id != 0:
		m = sim.state.find_by_id(sim.state.machines, int(e.machine_id))
		if not m.is_empty():
			target = FactoryLayout.operator_spot(int(m.slot))
	_walk(target, delta)
	if not _moving and not m.is_empty() and position.distance_to(target) < 0.2:
		_face_yaw = PI
		if m.status == ProductionManager.RUNNING:
			_pose = "operate"


func _update_technician(sim: Simulation, e: Dictionary, delta: float) -> void:
	var job: Dictionary = e.job
	var target := _idle_spot(FactoryLayout.TECH_IDLE, Vector3(0.9, 0, 0))
	var m := {}
	if not job.is_empty() and job.kind == "repair":
		m = sim.state.find_by_id(sim.state.machines, int(job.machine_id))
		if not m.is_empty():
			target = _work_spot(m)
	_walk(target, delta)
	if not m.is_empty() and position.distance_to(target) < 0.3:
		_pose = "repair"
		_face_yaw = atan2(1.6, -1.2)


## The factory manager walks from machine to machine, pausing at each.
func _update_manager(sim: Simulation, delta: float) -> void:
	var ms := sim.state.machines
	if ms.is_empty():
		_walk(FactoryLayout.OPERATOR_IDLE + Vector3(1.0, 0, 0), delta)
		return
	var visit := int(_time / 7.0) % ms.size()
	var m: Dictionary = ms[visit]
	var target := FactoryLayout.slot_position(int(m.slot)) + Vector3(0.6, 0, 2.2)
	_walk(target, delta)
	if not _moving:
		_face_yaw = PI


func _update_warehouse(sim: Simulation, e: Dictionary, delta: float) -> void:
	var job: Dictionary = e.job
	if job.is_empty():
		_phase_key = ""
		_carry.visible = false
		_walk(FactoryLayout.WAREHOUSE_IDLE + Vector3(0, 0, idle_index * 0.9), delta)
		return
	var key := "%s_%s_%s" % [job.kind, job.phase, job.machine_id]
	if key != _phase_key:
		_phase_key = key
		_phase_start = position
		_phase_route = FactoryLayout.route(position, _job_destination(sim, job))
		_walk_target = Vector3.INF
	var t := 1.0
	if int(job.get("wait", 0)) == 0:
		# Walk in step with the trip's ticks. A worker waiting at a full store
		# stands still at the door (t = 1): this used to jitter every tick.
		var leg := float(maxi(1, int(job.get("leg", sim.buildings.haul_leg_ticks()))))
		var frac := sim.tick_fraction() if TimeManager.speed > 0 and not sim.employees.on_strike() else 0.0
		t = (leg - int(job.ticks_left) + frac) / leg
	position = FactoryLayout.point_along(_phase_start, _phase_route, t)
	_carrying = job.phase == "to_dest" and int(job.qty) > 0
	_carry.visible = _carrying
	var color := Palette.PELLET_BAG
	if job.kind != "unload" and sim.content.products.has(job.get("product_id", "")):
		color = sim.content.products[job.product_id].color
	_carry.material_override = Palette.mat(color)


func _job_destination(sim: Simulation, job: Dictionary) -> Vector3:
	if job.kind == "unload":
		return FactoryLayout.DOCK_PICKUP if job.phase == "to_source" else FactoryLayout.RAW_DROP
	if job.phase == "to_dest":
		return FactoryLayout.FINISHED_DROP
	var m := sim.state.find_by_id(sim.state.machines, int(job.machine_id))
	if m.is_empty():
		return FactoryLayout.WAREHOUSE_IDLE
	return FactoryLayout.pallet_spot(int(m.slot)) + Vector3(0, 0, 1.0)


func inspect_machine(machine_id: int) -> void:
	_owner_target_machine = machine_id
	_owner_wait = 4.0


func _update_owner(sim: Simulation, delta: float) -> void:
	var target := FactoryLayout.OWNER_DESK
	var repairing := {}
	for m in sim.state.machines:
		if int(m.repairer_id) == ProductionManager.OWNER:
			repairing = m
			break
	if not repairing.is_empty():
		target = _work_spot(repairing)
		if position.distance_to(target) < 0.3:
			_pose = "repair"
			_face_yaw = atan2(1.6, -1.2)
	elif _owner_target_machine != 0:
		var m := sim.state.find_by_id(sim.state.machines, _owner_target_machine)
		if m.is_empty():
			_owner_target_machine = 0
		else:
			target = _work_spot(m)
			if position.distance_to(target) < 0.2:
				_owner_wait -= delta
				if _owner_wait <= 0.0:
					_owner_target_machine = 0
	_walk(target, delta)


## Limb poses for walking, carrying, sitting, working and striking.
func _animate(delta: float) -> void:
	var k := minf(1.0, delta * 14.0)
	var legs := [0.0, 0.0, 0.0, 0.0]  # thigh / shin angles (left, right)
	var arms := [0.0, 0.0]
	var arm_z := [0.06, -0.06]
	var lean := 0.0
	var lift := 0.0
	var head_yaw := sin(_time * 0.7 + employee_id) * 0.25
	if _moving:
		var s := sin(_stride)
		legs = [s * 0.6, maxf(0.0, -s) * 0.7, -s * 0.6, maxf(0.0, s) * 0.7]
		arms = [-s * 0.5, s * 0.5]
		lift = absf(cos(_stride)) * 0.04
		head_yaw = 0.0
	match _pose:
		"sit":
			legs = [-PI / 2.0, PI / 2.0, -PI / 2.0, PI / 2.0]
			arms = [-0.7, -0.7 + (0.9 if fmod(_time + employee_id, 9.0) < 1.6 else 0.0) * -1.0]
			lift = FactoryLayout.SEAT_HEIGHT / BODY_SCALE - 0.9 + 0.05
		"operate":
			arms = [-1.05 + sin(_time * 5.0) * 0.18, -1.05 - sin(_time * 5.0) * 0.18]
			lean = 0.08
			head_yaw = 0.0
		"repair":
			arms = [-0.9, -1.7 + sin(_time * 14.0) * 0.6]
			lean = 0.35
			head_yaw = 0.0
		"strike":
			arms = [-1.2 - absf(sin(_time * 4.0 + employee_id)) * 1.6, -PI + 0.15]
			lift = absf(sin(_time * 4.0 + employee_id)) * 0.08
			head_yaw = 0.0
	if _carrying:
		arms = [-1.25, -1.25]
		arm_z = [0.25, -0.25]
	for i in 4:
		_legs[i].rotation.x = lerp_angle(_legs[i].rotation.x, legs[i], k)
	for i in 2:
		_arms[i].rotation.x = lerp_angle(_arms[i].rotation.x, arms[i], k)
		_arms[i].rotation.z = lerp_angle(_arms[i].rotation.z, arm_z[i], k)
	_torso.rotation.x = lerp_angle(_torso.rotation.x, lean, k)
	_head.rotation.y = lerp_angle(_head.rotation.y, head_yaw, minf(1.0, delta * 3.0))
	_visual.position.y = lerpf(_visual.position.y, lift * BODY_SCALE, k)
	# Breathing
	_torso.scale.y = 1.0 + sin(_time * 2.2 + employee_id) * 0.012
	_set_face(_kind)


func _set_face(kind: String) -> void:
	match kind:
		"happy":
			_mouth.scale = Vector3(1.3, 1.6, 1)
			_brows[0].rotation.z = 0.0
			_brows[1].rotation.z = 0.0
		"angry":
			_mouth.scale = Vector3(1.1, 2.2, 1)
			_brows[0].rotation.z = -0.5
			_brows[1].rotation.z = 0.5
		"sad", "tired":
			_mouth.scale = Vector3(0.7, 0.8, 1)
			_brows[0].rotation.z = 0.35
			_brows[1].rotation.z = -0.35
		_:
			_mouth.scale = Vector3.ONE
			_brows[0].rotation.z = 0.0
			_brows[1].rotation.z = 0.0


## Shows a thought now and then (always while it is urgent: a strike, a
## broken machine, a full store).
func _update_bubble(sim: Simulation, e: Dictionary, delta: float) -> void:
	var t := Thoughts.pick(sim, e) if not e.is_empty() and visible else {"text": "", "kind": "calm", "urgent": false}
	_kind = t.kind
	if t.text == "":
		_bubble.visible = false
		return
	if t.urgent:
		if sim.employees.on_strike() and _quiet_striker():
			_bubble.visible = false
		else:
			_show_bubble(t)
		return
	if _bubble_timer > 0.0:
		_bubble_timer -= delta
		if _bubble_timer <= 0.0:
			_bubble.visible = false
			_bubble_next = 7.0 + fmod(employee_id * 3.7 + _time, 9.0)
		elif t.text != _bubble_text:
			_show_bubble(t)
		return
	_bubble_next -= delta
	if _bubble_next <= 0.0:
		_bubble_timer = 4.0
		_show_bubble(t)


## During a strike only every third person shouts at a time, in turns, so
## the bubbles do not pile up.
func _quiet_striker() -> bool:
	return (rest_index + Time.get_ticks_msec() / 3000) % 3 != 0


func _show_bubble(t: Dictionary) -> void:
	if not _bubble.visible:
		_bubble.scale = Vector3.ONE * 0.2
		create_tween().tween_property(_bubble, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bubble.visible = true
	if t.text == _bubble_text:
		return
	_bubble_text = t.text
	_bubble_label.text = t.text
	var font := _bubble_label.font
	var w := font.get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _bubble_label.font_size).x * _bubble_label.pixel_size
	var h := _bubble_label.font_size * _bubble_label.pixel_size * 1.25
	var q: QuadMesh = _bubble_bg.mesh
	q.size = Vector2(w + 0.5, (h + 0.26) * 64.0 / 52.0)
	_bubble_bg.position = Vector3(0, -q.size.y * 6.0 / 64.0, 0)  # text centred on the card, tail below
	var m: StandardMaterial3D = _bubble_bg.material_override
	m.albedo_color = BUBBLE_COLORS.get(t.kind, Color.WHITE)


## Walks toward target at a fixed speed, routing through doorways.
func _walk(target: Vector3, delta: float) -> void:
	if target.distance_to(_walk_target) > 0.05:
		_walk_target = target
		_walk_route = FactoryLayout.route(position, target)
	var step := WALK_SPEED * delta * maxf(1.0, TimeManager.speed * TimeManager.night_factor())
	while step > 0.0 and _walk_route.size() > 0:
		var next := _walk_route[0]
		var dist := position.distance_to(next)
		if dist <= step:
			position = next
			step -= dist
			_walk_route.remove_at(0)
		else:
			position += (next - position) / dist * step
			step = 0.0
