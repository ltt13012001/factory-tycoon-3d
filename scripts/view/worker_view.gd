## A worker (or the owner) as a capsule with a hard hat. Position follows
## the simulation: operators stand at their machine, warehouse workers walk
## each haul leg in step with the job's remaining ticks.
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
		if role == "operator":
			_update_operator(sim, e, delta)
		else:
			_update_warehouse(sim, e, delta)
	var moved := position - before
	_moving = moved.length() > 0.001
	if _moving:
		var look := Vector3(moved.x, 0, moved.z)
		if look.length() > 0.0001:
			rotation.y = lerp_angle(rotation.y, atan2(look.x, look.z), minf(1.0, delta * 12.0))
	_visual.position.y = absf(sin(_time * 12.0)) * 0.12 if _moving else 0.0


func _update_operator(sim: Simulation, e: Dictionary, delta: float) -> void:
	var target := FactoryLayout.OPERATOR_IDLE + Vector3(idle_index * 0.9, 0, 0)
	if e.machine_id != 0:
		var m := sim.state.find_by_id(sim.state.machines, int(e.machine_id))
		if not m.is_empty():
			target = FactoryLayout.operator_spot(int(m.slot))
	_walk(target, delta)
	if not _moving and e.machine_id != 0:
		rotation.y = lerp_angle(rotation.y, PI, minf(1.0, delta * 8.0))


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
	var leg := float(sim.config.haul_leg_ticks)
	var frac := sim.tick_fraction() if TimeManager.speed > 0 else 0.0
	var t := (leg - int(job.ticks_left) + frac) / leg
	position = FactoryLayout.point_along(_phase_start, _phase_route, t)
	_carry.visible = job.phase == "to_dest" and int(job.qty) > 0
	_carry.material_override = Palette.mat(Palette.PELLET_BAG if job.kind == "unload" else Palette.BOX)


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
	if _owner_target_machine != 0:
		var m := sim.state.find_by_id(sim.state.machines, _owner_target_machine)
		if m.is_empty():
			_owner_target_machine = 0
		else:
			target = FactoryLayout.slot_position(int(m.slot)) + Vector3(-1.6, 0, 1.2)
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
