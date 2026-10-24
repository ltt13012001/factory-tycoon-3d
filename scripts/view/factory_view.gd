## Builds the static factory lot and keeps the dynamic 3D objects (machines,
## workers, trucks, stock piles) in sync with the simulation state.
extends Node3D

const MachineScene := preload("res://scenes/machines/injection_molder.tscn")
const WorkerScene := preload("res://scenes/actors/worker.tscn")
const TruckScene := preload("res://scenes/actors/truck.tscn")

## Supplier trucks appear this many ticks before the delivery arrives.
const SUPPLIER_APPROACH_TICKS := 40

var _machines := {}
var _workers := {}
var _supplier_trucks := {}
var _customer_trucks := {}
var _owner: Node3D
var _raw_piles: Array[Node3D] = []
var _finished_piles: Array[Node3D] = []
var _dock_piles: Array[Node3D] = []
var _slot_pads: Array[Node3D] = []
var _select_ring: MeshInstance3D
var _selected_kind := ""
var _selected_id := 0


func _ready() -> void:
	_build_ground()
	_build_hall()
	_build_warehouse()
	_build_dock_and_office()
	_build_slot_pads()
	_select_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.1
	torus.outer_radius = 1.25
	_select_ring.mesh = torus
	_select_ring.material_override = Palette.mat(Palette.SELECT, 1.5)
	_select_ring.visible = false
	add_child(_select_ring)
	_owner = WorkerScene.instantiate()
	_owner.role = "owner"
	_owner.position = FactoryLayout.OWNER_DESK
	add_child(_owner)
	EventBus.selection_changed.connect(_on_selection_changed)
	EventBus.build_mode_changed.connect(_on_build_mode)
	EventBus.inspect_requested.connect(func(id): _owner.inspect_machine(id))
	EventBus.order_completed.connect(_on_order_completed)
	EventBus.unit_defective.connect(_on_defect)
	EventBus.game_loaded.connect(func(_d): _reset_dynamic())


func _process(delta: float) -> void:
	var sim: Simulation = GameManager.sim
	if sim == null:
		return
	_sync_machines(sim)
	_sync_workers(sim)
	_sync_trucks(sim, delta)
	_sync_piles(sim)
	_update_selection_ring(sim)


# --- Static world ------------------------------------------------------------

func _build_ground() -> void:
	Palette.box(self, Vector3(160, 0.2, 120), Vector3(0, -0.1, 0), Palette.GRASS)
	Palette.box(self, Vector3(160, 0.04, 6), Vector3(0, 0.02, FactoryLayout.ROAD_Z), Palette.ROAD)
	for i in range(-15, 16):
		Palette.box(self, Vector3(2.2, 0.05, 0.18), Vector3(i * 5.0, 0.03, FactoryLayout.ROAD_Z), Color("f2f2f2"))
	var lot_size := FactoryLayout.LOT_MAX - FactoryLayout.LOT_MIN
	var lot_center := (FactoryLayout.LOT_MAX + FactoryLayout.LOT_MIN) / 2.0
	Palette.box(self, Vector3(lot_size.x, 0.03, lot_size.y), Vector3(lot_center.x, 0.015, lot_center.y), Palette.CONCRETE)
	# Driveway from the road to the dock
	Palette.box(self, Vector3(6, 0.035, 6), Vector3(16, 0.02, 15.5), Palette.ROAD)
	# Fence with a gap at the driveway
	var y := 0.6
	_fence(Vector3(FactoryLayout.LOT_MIN.x, y, FactoryLayout.LOT_MIN.y), Vector3(FactoryLayout.LOT_MAX.x, y, FactoryLayout.LOT_MIN.y))
	_fence(Vector3(FactoryLayout.LOT_MIN.x, y, FactoryLayout.LOT_MIN.y), Vector3(FactoryLayout.LOT_MIN.x, y, FactoryLayout.LOT_MAX.y))
	_fence(Vector3(FactoryLayout.LOT_MAX.x, y, FactoryLayout.LOT_MIN.y), Vector3(FactoryLayout.LOT_MAX.x, y, FactoryLayout.LOT_MAX.y))
	_fence(Vector3(FactoryLayout.LOT_MIN.x, y, FactoryLayout.LOT_MAX.y), Vector3(13, y, FactoryLayout.LOT_MAX.y))
	_fence(Vector3(19, y, FactoryLayout.LOT_MAX.y), Vector3(FactoryLayout.LOT_MAX.x, y, FactoryLayout.LOT_MAX.y))
	# A few trees outside the lot
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 26:
		var p := Vector3(rng.randf_range(-60, 60), 0, rng.randf_range(-45, 45))
		if p.x > -28 and p.x < 28 and p.z > -20 and p.z < 25:
			continue
		Palette.cylinder(self, 0.25, 1.6, p + Vector3(0, 0.8, 0), Color("7a5432"))
		Palette.sphere(self, 1.3, p + Vector3(0, 2.4, 0), Color("4f8a3c"))


func _fence(a: Vector3, b: Vector3) -> void:
	var mid := (a + b) / 2.0
	var len := a.distance_to(b)
	var along_x := absf(a.x - b.x) > absf(a.z - b.z)
	Palette.box(self, Vector3(len, 0.08, 0.08) if along_x else Vector3(0.08, 0.08, len), mid + Vector3(0, 0.4, 0), Palette.WALL_TRIM)
	var posts := int(len / 3.0)
	for i in posts + 1:
		Palette.box(self, Vector3(0.12, 1.2, 0.12), a.lerp(b, float(i) / maxf(posts, 1)) + Vector3(0, 0, 0), Palette.WALL_TRIM)


func _floor(min_c: Vector2, max_c: Vector2, color: Color, h: float = 0.06) -> void:
	var size := max_c - min_c
	var c := (max_c + min_c) / 2.0
	Palette.box(self, Vector3(size.x, h, size.y), Vector3(c.x, h / 2.0, c.y), color)


## Low walls on the rectangle edges, leaving the given gaps open.
## gaps: Array of [side, from, to] with side in "n","s","e","w".
func _walls(min_c: Vector2, max_c: Vector2, gaps: Array, height: float = 1.1) -> void:
	var t := 0.25
	var sides := {
		"n": [Vector2(min_c.x, min_c.y), Vector2(max_c.x, min_c.y)],
		"s": [Vector2(min_c.x, max_c.y), Vector2(max_c.x, max_c.y)],
		"w": [Vector2(min_c.x, min_c.y), Vector2(min_c.x, max_c.y)],
		"e": [Vector2(max_c.x, min_c.y), Vector2(max_c.x, max_c.y)],
	}
	for side in sides:
		var a: Vector2 = sides[side][0]
		var b: Vector2 = sides[side][1]
		var horizontal: bool = side == "n" or side == "s"
		var start := a.x if horizontal else a.y
		var end := b.x if horizontal else b.y
		var cuts := []
		for g in gaps:
			if g[0] == side:
				cuts.append([g[1], g[2]])
		cuts.sort_custom(func(p, q): return p[0] < q[0])
		var cursor := start
		cuts.append([end, end])
		for cut in cuts:
			if cut[0] > cursor:
				var l: float = cut[0] - cursor
				var mid: float = (cursor + cut[0]) / 2.0
				var pos := Vector3(mid, height / 2.0, a.y) if horizontal else Vector3(a.x, height / 2.0, mid)
				var size := Vector3(l, height, t) if horizontal else Vector3(t, height, l)
				Palette.box(self, size, pos, Palette.WALL)
				Palette.box(self, Vector3(size.x + 0.04, 0.12, size.z + 0.04), pos + Vector3(0, height / 2.0, 0), Palette.WALL_TRIM)
			cursor = maxf(cursor, cut[1])


func _build_hall() -> void:
	_floor(FactoryLayout.HALL_MIN, FactoryLayout.HALL_MAX, Palette.HALL_FLOOR)
	_walls(FactoryLayout.HALL_MIN, FactoryLayout.HALL_MAX, [["e", -8, 0], ["s", -8, -4]])
	Palette.label3d(self, "XƯỞNG SẢN XUẤT", Vector3(-6, 0.3, -12.8), 90, Color("2b3440")).billboard = BaseMaterial3D.BILLBOARD_DISABLED
	# Yellow walkway lines
	Palette.box(self, Vector3(23, 0.07, 0.12), Vector3(-6, 0.04, -4), Palette.STATUS_WARN)
	# Scrap bin
	Palette.box(self, Vector3(1.2, 0.9, 1.0), FactoryLayout.SCRAP_BIN + Vector3(0, 0.45, 0), Palette.SCRAP)
	Palette.label3d(self, "Phế phẩm", FactoryLayout.SCRAP_BIN + Vector3(0, 1.4, 0), 32)


func _build_warehouse() -> void:
	_floor(FactoryLayout.WAREHOUSE_MIN, Vector2(FactoryLayout.WAREHOUSE_MAX.x, -4.5), Palette.WAREHOUSE_RAW)
	_floor(Vector2(FactoryLayout.WAREHOUSE_MIN.x, -4.5), FactoryLayout.WAREHOUSE_MAX, Palette.WAREHOUSE_FINISHED)
	_walls(FactoryLayout.WAREHOUSE_MIN, FactoryLayout.WAREHOUSE_MAX, [["w", -8, 0], ["s", 13, 17]])
	Palette.label3d(self, "Kho nguyên liệu", Vector3(16, 2.2, -11), 40)
	Palette.label3d(self, "Kho thành phẩm", Vector3(16, 2.2, -3), 40)
	for i in 24:
		var p := Node3D.new()
		p.position = FactoryLayout.RAW_STACK_ORIGIN + Vector3((i % 6) * 1.1, (i / 12) * 0.75, ((i / 6) % 2) * 1.2)
		Palette.cylinder(p, 0.45, 0.7, Vector3(0, 0.4, 0), Palette.PELLET_BAG)
		p.visible = false
		add_child(p)
		_raw_piles.append(p)
	for i in 30:
		var p := Node3D.new()
		p.position = FactoryLayout.FINISHED_STACK_ORIGIN + Vector3((i % 6) * 1.1, (i / 18) * 0.85, ((i / 6) % 3) * 1.2)
		Palette.box(p, Vector3(1.0, 0.12, 1.0), Vector3(0, 0.06, 0), Palette.PALLET)
		Palette.box(p, Vector3(0.9, 0.6, 0.9), Vector3(0, 0.45, 0), Palette.BOX)
		p.visible = false
		add_child(p)
		_finished_piles.append(p)


func _build_dock_and_office() -> void:
	_floor(FactoryLayout.DOCK_MIN, FactoryLayout.DOCK_MAX, Palette.DOCK, 0.05)
	Palette.label3d(self, "Bãi giao nhận", Vector3(16, 1.8, 7), 40)
	for i in 24:
		var p := Node3D.new()
		p.position = FactoryLayout.DOCK_STACK_ORIGIN + Vector3((i % 6) * 1.0, (i / 12) * 0.7, ((i / 6) % 2) * 1.1)
		Palette.cylinder(p, 0.42, 0.65, Vector3(0, 0.35, 0), Palette.PELLET_BAG)
		p.visible = false
		add_child(p)
		_dock_piles.append(p)
	_floor(FactoryLayout.OFFICE_MIN, FactoryLayout.OFFICE_MAX, Palette.OFFICE)
	_walls(FactoryLayout.OFFICE_MIN, FactoryLayout.OFFICE_MAX, [["n", -15, -12]])
	Palette.label3d(self, "Văn phòng", Vector3(-13.5, 2.0, 12.5), 40)
	Palette.box(self, Vector3(2.0, 0.8, 1.0), FactoryLayout.OWNER_DESK + Vector3(0, 0.4, 1.0), Color("8d6e63"))
	Palette.box(self, Vector3(0.7, 0.45, 0.06), FactoryLayout.OWNER_DESK + Vector3(0, 1.05, 1.2), Color("263238"))
	Palette.box(self, Vector3(1.0, 1.8, 0.5), Vector3(-17, 0.9, 12.3), Color("90a4ae"))


func _build_slot_pads() -> void:
	for slot in GameManager.sim.config.machine_slots:
		var pad := Node3D.new()
		pad.position = FactoryLayout.slot_position(slot)
		var mi := Palette.box(pad, Vector3(4.6, 0.05, 2.4), Vector3(0.9, 0.08, 0), Color(0.3, 0.9, 0.4, 0.45))
		mi.material_override = Palette.mat(Color(0.3, 0.9, 0.4, 0.45))
		Palette.label3d(pad, "Đặt máy ở đây", Vector3(0, 1.2, 0), 36, Color("b9ffc8"))
		Palette.pick_body(pad, Vector3(4.6, 0.6, 2.4), Vector3(0.9, 0.3, 0), "slot", slot)
		pad.visible = false
		pad.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(pad)
		_slot_pads.append(pad)


func _on_build_mode(active: bool) -> void:
	var sim: Simulation = GameManager.sim
	for slot in _slot_pads.size():
		var free := sim.production.machine_in_slot(slot).is_empty()
		var show := active and free
		_slot_pads[slot].visible = show
		_slot_pads[slot].process_mode = Node.PROCESS_MODE_INHERIT if show else Node.PROCESS_MODE_DISABLED
		for c in _slot_pads[slot].get_children():
			if c is StaticBody3D:
				c.collision_layer = 1 if show else 0


# --- Dynamic objects -----------------------------------------------------------

func _reset_dynamic() -> void:
	for dict in [_machines, _workers, _supplier_trucks, _customer_trucks]:
		for k in dict:
			dict[k].queue_free()
		dict.clear()


func _sync_machines(sim: Simulation) -> void:
	var seen := {}
	for m in sim.state.machines:
		seen[m.id] = true
		if not _machines.has(m.id):
			var d: MachineDef = sim.content.machines[m.def_id]
			var scene: PackedScene = load(d.view_scene) if d.view_scene != "" else MachineScene
			var v: Node3D = scene.instantiate()
			v.machine_id = m.id
			v.position = FactoryLayout.slot_position(int(m.slot))
			add_child(v)
			Palette.pick_body(v, Vector3(4.2, 2.5, 1.8), Vector3(0.8, 1.2, 0), "machine", m.id)
			_machines[m.id] = v
	for id in _machines.keys():
		if not seen.has(id):
			_machines[id].queue_free()
			_machines.erase(id)


func _sync_workers(sim: Simulation) -> void:
	var seen := {}
	var idle := {"operator": 0, "warehouse": 0}
	for e in sim.state.employees:
		seen[e.id] = true
		if not _workers.has(e.id):
			var w: Node3D = WorkerScene.instantiate()
			w.employee_id = e.id
			w.role = e.role
			w.position = FactoryLayout.WAREHOUSE_IDLE if e.role == "warehouse" else FactoryLayout.OPERATOR_IDLE
			if sim.state.tick > 0:
				w.position = FactoryLayout.DOOR_HALL_YARD + Vector3(0, 0, 3)  # new hires walk in from the yard
			add_child(w)
			_workers[e.id] = w
		_workers[e.id].idle_index = idle[e.role]
		idle[e.role] += 1
	for id in _workers.keys():
		if not seen.has(id):
			_workers[id].queue_free()
			_workers.erase(id)


func _sync_trucks(sim: Simulation, delta: float) -> void:
	var frac := sim.tick_fraction() if TimeManager.speed > 0 else 0.0
	var now := float(sim.state.tick) + frac
	# Supplier trucks: drive in so they reach the stop exactly on arrival,
	# wait while the dock still holds material, then drive away east.
	for p in sim.state.purchases:
		var left := float(p.arrive_tick) - now
		if left <= SUPPLIER_APPROACH_TICKS and not _supplier_trucks.has(p.id):
			_supplier_trucks[p.id] = _spawn_truck(Palette.TRUCK_SUPPLIER)
	for id in _supplier_trucks.keys():
		var truck: Node3D = _supplier_trucks[id]
		var purchase := sim.state.find_by_id(sim.state.purchases, id)
		if not purchase.is_empty():
			var t := 1.0 - clampf((float(purchase.arrive_tick) - now) / SUPPLIER_APPROACH_TICKS, 0.0, 1.0)
			_place_truck(truck, FactoryLayout.ROAD_WEST.lerp(FactoryLayout.TRUCK_STOP, ease(t, 0.5)), PI / 2, delta)
			truck.set_cargo_visible(true)
		elif sim.state.dock > 0 and not truck.has_meta("leaving"):
			_place_truck(truck, FactoryLayout.TRUCK_STOP, PI / 2, 0.0)
			truck.set_cargo_visible(true)
		else:
			truck.set_cargo_visible(false)
			var progress: float = truck.get_meta("leaving", 0.0) + delta * maxf(1, TimeManager.speed) / 6.0
			truck.set_meta("leaving", progress)
			_place_truck(truck, FactoryLayout.TRUCK_STOP.lerp(Vector3(70, 0, FactoryLayout.TRUCK_STOP.z), ease(progress, 2.0)), PI / 2, delta)
			if progress >= 1.0:
				truck.queue_free()
				_supplier_trucks.erase(id)
	# Customer trucks: in from the east, load, leave west. Paid on leaving.
	var total := float(sim.config.customer_truck_ticks)
	for o in sim.state.orders:
		if o.status == "shipping" and not _customer_trucks.has(o.id):
			_customer_trucks[o.id] = _spawn_truck(Palette.TRUCK_CUSTOMER)
	for id in _customer_trucks.keys():
		var truck: Node3D = _customer_trucks[id]
		var o := sim.state.find_by_id(sim.state.orders, id)
		if o.is_empty() or o.status != "shipping":
			truck.queue_free()
			_customer_trucks.erase(id)
			continue
		var t := clampf((total - float(o.ship_ticks_left) + frac) / total, 0.0, 1.0)
		var east := Vector3(70, 0, FactoryLayout.TRUCK_STOP.z)
		var west := Vector3(-70, 0, FactoryLayout.TRUCK_STOP.z)
		if t < 0.35:
			_place_truck(truck, east.lerp(FactoryLayout.TRUCK_STOP, ease(t / 0.35, 0.5)), -PI / 2, delta)
			truck.set_cargo_visible(false)
		elif t < 0.75:
			_place_truck(truck, FactoryLayout.TRUCK_STOP, -PI / 2, 0.0)
			truck.set_cargo_visible(t > 0.55)
		else:
			_place_truck(truck, FactoryLayout.TRUCK_STOP.lerp(west, ease((t - 0.75) / 0.25, 2.0)), -PI / 2, delta)
			truck.set_cargo_visible(true)


func _spawn_truck(color: Color) -> Node3D:
	var truck: Node3D = TruckScene.instantiate()
	truck.color = color
	truck.position = Vector3(1000, 0, 0)
	add_child(truck)
	return truck


func _place_truck(truck: Node3D, pos: Vector3, yaw: float, delta: float) -> void:
	var moved := truck.position.distance_to(pos)
	truck.position = pos
	truck.rotation.y = yaw
	if delta > 0.0 and moved < 50.0:
		truck.spin_wheels(moved / 0.45)


func _sync_piles(sim: Simulation) -> void:
	var cfg := sim.config
	_show_count(_raw_piles, ceili(float(sim.state.raw) / cfg.haul_raw_batch))
	_show_count(_dock_piles, ceili(float(sim.state.dock) / cfg.haul_raw_batch))
	_show_count(_finished_piles, ceili(float(sim.state.finished) / cfg.haul_finished_batch))


func _show_count(nodes: Array[Node3D], n: int) -> void:
	for i in nodes.size():
		nodes[i].visible = i < n


# --- Selection and effects -----------------------------------------------------

func _on_selection_changed(kind: String, id: int) -> void:
	_selected_kind = kind
	_selected_id = id


func _update_selection_ring(sim: Simulation) -> void:
	var target: Node3D = null
	if _selected_kind == "machine":
		target = _machines.get(_selected_id)
	elif _selected_kind == "worker":
		target = _workers.get(_selected_id)
	_select_ring.visible = target != null
	if target:
		_select_ring.position = target.position + Vector3(0, 0.12, 0)
		_select_ring.scale = Vector3.ONE * (2.0 if _selected_kind == "machine" else 0.6)


func _on_order_completed(data: Dictionary) -> void:
	var text := "+" + Fmt.money(int(data.value) - int(data.penalty))
	_float_text(text, FactoryLayout.TRUCK_STOP + Vector3(0, 4, 0), UiTheme.GOOD)


func _on_defect(data: Dictionary) -> void:
	var v: Node3D = _machines.get(data.id)
	if v == null:
		return
	var cube := Palette.box(self, Vector3(0.3, 0.3, 0.3), v.position + Vector3(1.2, 1.2, 0), Palette.SCRAP)
	var tw := create_tween()
	tw.tween_property(cube, "position", FactoryLayout.SCRAP_BIN + Vector3(0, 1.0, 0), 0.8).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(cube.queue_free)


func _float_text(text: String, pos: Vector3, color: Color) -> void:
	var l := Palette.label3d(self, text, pos, 64, color)
	var tw := create_tween().set_parallel()
	tw.tween_property(l, "position", pos + Vector3(0, 3, 0), 2.5)
	tw.tween_property(l, "modulate:a", 0.0, 2.5).set_delay(0.8)
	tw.chain().tween_callback(l.queue_free)
