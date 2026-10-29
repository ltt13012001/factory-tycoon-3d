## A worker (or the owner) as a capsule with a hard hat. Position follows
## the simulation: operators stand at their machine, warehouse workers walk
## each haul leg in step with the job's remaining ticks, technicians and the
## owner walk to the machine they are repairing.
extends Node3D

const WALK_SPEED := 3.5

var employee_id := 0
var role := ""
var idle_index := 0

var _visual: Node3D
var _carry: MeshInstance3D
var _phase_key := ""
var _phase_start := Vector3.ZERO
var _phase_route := PackedVector3Array()
var _walk_target := Vector3.INF
var _walk_route := PackedVector3Array()
var _time := 0.0
var _moving := false
var _working := false  # hammering animation while repairing

# Owner only
var _owner_target_machine := 0
var _owner_wait := 0.0


func _ready() -> void:
	var color := Palette.OPERATOR
	match role:
		"warehouse":
			color = Palette.WAREHOUSE
		"owner":
			color = Palette.OWNER
		"technician":
			color = Palette.TECHNICIAN
		"manager":
			color = Palette.MANAGER
	_visual = Node3D.new()
	add_child(_visual)
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.3
	cap.height = 1.2
	body.mesh = cap
	body.position = Vector3(0, 0.6, 0)
	body.material_override = Palette.mat(color)
	_visual.add_child(body)
	Palette.sphere(_visual, 0.24, Vector3(0, 1.42, 0), Palette.SKIN)
	if role == "owner":
		Palette.box(_visual, Vector3(0.12, 0.35, 0.05), Vector3(0, 0.95, 0.29), Color("c62828"))
	else:
		Palette.sphere(_visual, 0.27, Vector3(0, 1.55, 0), Palette.HELMET).scale = Vector3(1, 0.55, 1)
	_carry = Palette.box(_visual, Vector3(0.5, 0.4, 0.4), Vector3(0, 0.9, 0.45), Palette.BOX)
	_carry.visible = false
	if role == "technician":
		Palette.box(_visual, Vector3(0.45, 0.25, 0.2), Vector3(0.38, 0.45, 0), Color("d32f2f"))
	if role == "manager":
		# Tie and clipboard
		Palette.box(_visual, Vector3(0.1, 0.38, 0.05), Vector3(0, 0.95, 0.29), Color("1565c0"))
		Palette.box(_visual, Vector3(0.3, 0.4, 0.04), Vector3(0.32, 0.85, 0.2), Color("8d6e63"))
	if role != "owner":
		Palette.pick_body(self, Vector3(0.8, 1.8, 0.8), Vector3(0, 0.9, 0), "worker", employee_id)


func _process(delta: float) -> void:
	_time += delta
	var sim: Simulation = GameManager.sim
	var before := position
	if role == "owner":
		_update_owner(sim, delta)
	else:
		var e := sim.state.find_by_id(sim.state.employees, employee_id)
		if e.is_empty():
			return
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
		var look := Vector3(moved.x, 0, moved.z)
		if look.length() > 0.0001:
			rotation.y = lerp_angle(rotation.y, atan2(look.x, look.z), minf(1.0, delta * 12.0))
	_visual.position.y = absf(sin(_time * 12.0)) * 0.12 if _moving else 0.0
	_visual.rotation.x = sin(_time * 14.0) * 0.25 if _working and not _moving else 0.0


## Where idle operators and technicians wait: the break room once it exists.
func _idle_spot(sim: Simulation, fallback: Vector3, step: Vector3) -> Vector3:
	if sim.buildings.level("break_room") > 0:
		var offset := idle_index + (0 if role == "operator" else 4)
		return FactoryLayout.BREAK_IDLE + Vector3((offset % 3) * 0.9, 0, (offset / 3) * 1.3)
	return fallback + step * idle_index


## Stand beside a machine's control side, facing it.
func _work_spot(m: Dictionary) -> Vector3:
	return FactoryLayout.slot_position(int(m.slot)) + Vector3(-1.6, 0, 1.2)


func _update_operator(sim: Simulation, e: Dictionary, delta: float) -> void:
	_working = false
	var target := _idle_spot(sim, FactoryLayout.OPERATOR_IDLE, Vector3(0, 0, -0.9))
	if e.machine_id != 0:
		var m := sim.state.find_by_id(sim.state.machines, int(e.machine_id))
		if not m.is_empty():
			target = FactoryLayout.operator_spot(int(m.slot))
	_walk(target, delta)
	if not _moving and e.machine_id != 0:
		rotation.y = lerp_angle(rotation.y, PI, minf(1.0, delta * 8.0))


func _update_technician(sim: Simulation, e: Dictionary, delta: float) -> void:
	var job: Dictionary = e.job
	var target := _idle_spot(sim, FactoryLayout.TECH_IDLE, Vector3(0.9, 0, 0))
	var m := {}
	if not job.is_empty() and job.kind == "repair":
		m = sim.state.find_by_id(sim.state.machines, int(job.machine_id))
		if not m.is_empty():
			target = _work_spot(m)
	_walk(target, delta)
	_working = not m.is_empty() and position.distance_to(target) < 0.3
	if _working:
		rotation.y = lerp_angle(rotation.y, atan2(1.6, -1.2), minf(1.0, delta * 8.0))


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
		rotation.y = lerp_angle(rotation.y, PI, minf(1.0, delta * 6.0))


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
	var leg := float(sim.buildings.haul_leg_ticks())
	var frac := sim.tick_fraction() if TimeManager.speed > 0 else 0.0
	var t := (leg - int(job.ticks_left) + frac) / leg
	position = FactoryLayout.point_along(_phase_start, _phase_route, t)
	_carry.visible = job.phase == "to_dest" and int(job.qty) > 0
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
	_working = false
	var repairing := {}
	for m in sim.state.machines:
		if int(m.repairer_id) == ProductionManager.OWNER:
			repairing = m
			break
	if not repairing.is_empty():
		target = _work_spot(repairing)
		_working = position.distance_to(target) < 0.3
		if _working:
			rotation.y = lerp_angle(rotation.y, atan2(1.6, -1.2), minf(1.0, delta * 8.0))
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


## Walks toward target at a fixed speed, routing through doorways.
func _walk(target: Vector3, delta: float) -> void:
	if target.distance_to(_walk_target) > 0.05:
		_walk_target = target
		_walk_route = FactoryLayout.route(position, target)
	var step := WALK_SPEED * delta * maxf(1.0, TimeManager.speed)
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
