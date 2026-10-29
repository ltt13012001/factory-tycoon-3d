## Builds the factory lot and keeps the dynamic 3D objects (machines,
## workers, trucks, stock piles, buildings) in sync with the simulation state.
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
var _finished_piles: Array[MeshInstance3D] = []
var _dock_piles: Array[Node3D] = []
var _buildings: Node3D
var _slot_pads: Array[Node3D] = []
var _select_ring: MeshInstance3D
var _selected_kind := ""
var _selected_id := 0
var _solid := MeshBatch.new()
var _flat := MeshBatch.new()
var _back_wall: Node3D
var _back_wall_low: Node3D
var _pallet_shared: Mesh
var _bag_shared: Mesh


func _ready() -> void:
	_build_ground()
	_build_back_wall()
	_build_back_wall_low()
	_build_hall()
	_build_warehouse()
	_build_dock_and_office()
	_build_rest_area()
	_solid.build(self)
	_flat.build(self, false)
	_build_slot_pads()
	_buildings = preload("res://scripts/view/buildings_view.gd").new()
	add_child(_buildings)
	_build_annex_piles()
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
	_update_back_wall()


# --- Static world ------------------------------------------------------------
# Everything that never moves is merged into a few meshes (see MeshBatch):
# _solid for props that cast shadows, _flat for ground, floors and paint that
# do not, and the tall back wall, which hides when the camera looks from the
# north so it never blocks the view.

func _build_ground() -> void:
	var ground := Palette.surface("ground")
	var paving := Palette.surface("paving")
	var z := FactoryLayout.ROAD_Z
	_flat.box(Vector3(420, 0.2, 380), Vector3(0, -0.1, 0), Palette.GRASS, ground)
	# Road: asphalt, dashed centre line, edge lines, kerbs and manholes
	_flat.box(Vector3(420, 0.06, 6), Vector3(0, 0.03, z), Palette.ROAD, paving)
	for i in range(-42, 43):
		_flat.box(Vector3(2.6, 0.012, 0.16), Vector3(i * 5.0, 0.064, z), Color("eeeeea"))
	for side in [-1.0, 1.0]:
		_flat.box(Vector3(420, 0.012, 0.12), Vector3(0, 0.064, z + side * 2.65), Color("d8d4c8"))
	for span in [Vector2(-210, -1.2), Vector2(3.2, 12.8), Vector2(19.2, 210)]:
		_kerb(span, z - 3.05)
	_kerb(Vector2(-210, 210), z + 3.05)
	for x in [-38.0, -6.0, 27.0, 58.0]:
		_flat.cylinder(0.45, 0.02, Vector3(x, 0.065, z + 1.3), Color("55534f"), Palette.surface("steel"), -1.0, Vector3.ZERO, 14)
	# Concrete yard with expansion joints
	var lot_size := FactoryLayout.LOT_MAX - FactoryLayout.LOT_MIN
	var lot_center := (FactoryLayout.LOT_MAX + FactoryLayout.LOT_MIN) / 2.0
	_flat.box(Vector3(lot_size.x, 0.03, lot_size.y), Vector3(lot_center.x, 0.015, lot_center.y), Color("a9adb0"), paving)
	var joint := Color("8a8e91")
	for x in range(int(FactoryLayout.LOT_MIN.x) + 6, int(FactoryLayout.LOT_MAX.x), 6):
		_flat.box(Vector3(0.05, 0.034, lot_size.y), Vector3(x, 0.017, lot_center.y), joint)
	for zz in range(int(FactoryLayout.LOT_MIN.y) + 6, int(FactoryLayout.LOT_MAX.y), 6):
		_flat.box(Vector3(lot_size.x, 0.034, 0.05), Vector3(lot_center.x, 0.017, zz), joint)
	# Driveways from the road to the dock and to the car park
	_flat.box(Vector3(6, 0.05, 2.4), Vector3(16, 0.025, 15.0), Palette.ROAD, paving)
	_flat.box(Vector3(4, 0.05, 2.4), Vector3(1, 0.025, 15.0), Palette.ROAD, paving)
	# Fence with gaps at the driveways
	var a := FactoryLayout.LOT_MIN
	var b := FactoryLayout.LOT_MAX
	_fence(Vector3(a.x, 0, a.y), Vector3(b.x, 0, a.y))
	_fence(Vector3(a.x, 0, a.y), Vector3(a.x, 0, b.y))
	_fence(Vector3(b.x, 0, a.y), Vector3(b.x, 0, b.y))
	_fence(Vector3(a.x, 0, b.y), Vector3(-1, 0, b.y))
	_fence(Vector3(3, 0, b.y), Vector3(13, 0, b.y))
	_fence(Vector3(19, 0, b.y), Vector3(b.x, 0, b.y))


func _kerb(span: Vector2, z: float) -> void:
	_flat.box(Vector3(span.y - span.x, 0.15, 0.22), Vector3((span.x + span.y) / 2.0, 0.075, z), Color("b4b1a9"), Palette.surface("paving"))


## Steel posts and rails with see-through chain-link netting on a low kerb.
func _fence(a: Vector3, b: Vector3) -> void:
	var steel := Palette.surface("steel")
	var post := Color("7d868c")
	var length := a.distance_to(b)
	var along_x := absf(a.x - b.x) > absf(a.z - b.z)
	var mid := (a + b) / 2.0
	var posts := maxi(1, int(length / 2.5))
	for i in posts + 1:
		var p := a.lerp(b, float(i) / posts)
		_solid.cylinder(0.05, 1.9, p + Vector3(0, 0.95, 0), post, steel, -1.0, Vector3.ZERO, 6)
	_solid.bar(a + Vector3(0, 1.86, 0), b + Vector3(0, 1.86, 0), 0.06, post, steel, true)
	_flat.box(Vector3(length, 0.12, 0.22) if along_x else Vector3(0.22, 0.12, length), mid + Vector3(0, 0.06, 0), Color("a3a19b"), Palette.surface("paving"))
	_flat.box(Vector3(length, 1.72, 0.02) if along_x else Vector3(0.02, 1.72, length), mid + Vector3(0, 0.98, 0), Color(0.48, 0.53, 0.56, 0.3), Palette.surface("mesh"))


func _floor(min_c: Vector2, max_c: Vector2, color: Color, h: float = 0.06, kind := "floor") -> void:
	var size := max_c - min_c
	var c := (max_c + min_c) / 2.0
	_flat.box(Vector3(size.x, h, size.y), Vector3(c.x, h / 2.0, c.y), color, Palette.surface(kind))


## Painted rectangle outline on a floor.
func _outline(a: Vector2, b: Vector2, color: Color, w := 0.08, y := 0.065) -> void:
	var c := (a + b) / 2.0
	var s := b - a
	_flat.box(Vector3(s.x, 0.01, w), Vector3(c.x, y, a.y), color)
	_flat.box(Vector3(s.x, 0.01, w), Vector3(c.x, y, b.y), color)
	_flat.box(Vector3(w, 0.01, s.y), Vector3(a.x, y, c.y), color)
	_flat.box(Vector3(w, 0.01, s.y), Vector3(b.x, y, c.y), color)


static func _span_size(horizontal: bool, length: float, height: float, depth: float) -> Vector3:
	return Vector3(length, height, depth) if horizontal else Vector3(depth, height, length)


## Low cut-away walls on the rectangle edges: concrete plinth, ribbed metal
## cladding and a steel coping, leaving the given gaps open with a pair of
## yellow bollards at each doorway. Sides listed in skip are not built.
## gaps: Array of [side, from, to] with side in "n","s","e","w".
func _walls(min_c: Vector2, max_c: Vector2, gaps: Array, height: float = 1.2, skip := "") -> void:
	var t := 0.25
	var sides := {
		"n": [Vector2(min_c.x, min_c.y), Vector2(max_c.x, min_c.y)],
		"s": [Vector2(min_c.x, max_c.y), Vector2(max_c.x, max_c.y)],
		"w": [Vector2(min_c.x, min_c.y), Vector2(min_c.x, max_c.y)],
		"e": [Vector2(max_c.x, min_c.y), Vector2(max_c.x, max_c.y)],
	}
	for side in sides:
		if skip.contains(side):
			continue
		var a: Vector2 = sides[side][0]
		var b: Vector2 = sides[side][1]
		var horizontal: bool = side == "n" or side == "s"
		var fixed := a.y if horizontal else a.x
		var start := a.x if horizontal else a.y
		var end := b.x if horizontal else b.y
		var cuts := []
		for g in gaps:
			if g[0] == side:
				cuts.append([float(g[1]), float(g[2])])
				for k in 2:
					var v: float = g[1 + k] + (0.18 if k == 0 else -0.18)
					var p := Vector3(v, 0, fixed) if horizontal else Vector3(fixed, 0, v)
					_bollard(p)
		cuts.sort_custom(func(p, q): return p[0] < q[0])
		var cursor := start
		cuts.append([end, end])
		for cut in cuts:
			if cut[0] > cursor:
				_wall_piece(horizontal, fixed, cursor, cut[0], height, t)
			cursor = maxf(cursor, cut[1])


func _wall_piece(horizontal: bool, fixed: float, from: float, to: float, height: float, t: float) -> void:
	var l := to - from
	var mid := (from + to) / 2.0
	var c := Vector3(mid, 0, fixed) if horizontal else Vector3(fixed, 0, mid)
	var plinth := 0.35
	var clad := height - plinth
	_solid.box(_span_size(horizontal, l, plinth, t + 0.06), c + Vector3(0, plinth / 2.0, 0), Color("a19e97"), Palette.surface("paving"))
	_solid.box(_span_size(horizontal, l, clad, t), c + Vector3(0, plinth + clad / 2.0, 0), Palette.WALL)
	var ribs := int(l / 0.55)
	for i in ribs:
		var along := from + (i + 0.5) * l / ribs
		var rp := Vector3(along, 0, fixed) if horizontal else Vector3(fixed, 0, along)
		_solid.box(_span_size(horizontal, 0.07, clad - 0.04, t + 0.05), rp + Vector3(0, plinth + clad / 2.0, 0), Palette.WALL.darkened(0.07))
	_solid.box(_span_size(horizontal, l + 0.04, 0.1, t + 0.08), c + Vector3(0, height + 0.05, 0), Palette.WALL_TRIM, Palette.surface("steel"))


func _bollard(p: Vector3) -> void:
	var paint := Palette.surface("paint")
	_solid.cylinder(0.09, 1.0, p + Vector3(0, 0.5, 0), Color("f2c12e"), paint, -1.0, Vector3.ZERO, 10)
	_solid.cylinder(0.095, 0.12, p + Vector3(0, 0.78, 0), Color("26292c"), paint, -1.0, Vector3.ZERO, 10)
	_solid.cylinder(0.095, 0.12, p + Vector3(0, 0.5, 0), Color("26292c"), paint, -1.0, Vector3.ZERO, 10)


## Tall back wall along the north side of the hall and warehouse: plinth,
## cladding, ribbon windows, steel columns, pipes, cable tray and the
## factory sign. Shown only while the camera looks at it from the south.
func _build_back_wall() -> void:
	_back_wall = Node3D.new()
	add_child(_back_wall)
	var b := MeshBatch.new()
	var steel := Palette.surface("steel")
	var paint := Palette.surface("paint")
	var x0 := FactoryLayout.HALL_MIN.x
	var x1 := FactoryLayout.WAREHOUSE_MAX.x
	var z := FactoryLayout.HALL_MIN.y
	var length := x1 - x0
	var cx := (x0 + x1) / 2.0
	var top := 5.6
	var clad := Color("c3c9ce")
	b.box(Vector3(length, 0.8, 0.32), Vector3(cx, 0.4, z), Color("a19e97"), Palette.surface("paving"))
	b.box(Vector3(length, 2.6, 0.25), Vector3(cx, 2.1, z), clad)
	b.box(Vector3(length, 1.0, 0.1), Vector3(cx, 3.9, z), Color("5f7d96"), paint)
	b.box(Vector3(length, 1.2, 0.25), Vector3(cx, 5.0, z), clad)
	b.box(Vector3(length + 0.1, 0.14, 0.36), Vector3(cx, top + 0.07, z), Palette.WALL_TRIM, steel)
	b.box(Vector3(length, 0.08, 0.32), Vector3(cx, 3.42, z), Palette.WALL_TRIM, steel)
	for i in int(length / 1.5) + 1:
		b.box(Vector3(0.07, 1.0, 0.16), Vector3(x0 + i * 1.5, 3.9, z), Palette.WALL_TRIM, steel)
	for i in int(length / 0.6):
		var x := x0 + 0.3 + i * 0.6
		b.box(Vector3(0.07, 2.56, 0.05), Vector3(x, 2.1, z + 0.14), clad.darkened(0.08))
		b.box(Vector3(0.07, 1.16, 0.05), Vector3(x, 5.0, z + 0.14), clad.darkened(0.08))
	# Painted steel H-columns with stub roof beams
	var col := Color("3d5a78")
	for x in [x0 + 0.2, -12.0, -6.0, 0.0, 6.0, 13.0, x1 - 0.2]:
		b.box(Vector3(0.36, top, 0.05), Vector3(x, top / 2.0, z + 0.2), col, paint)
		b.box(Vector3(0.36, top, 0.05), Vector3(x, top / 2.0, z + 0.5), col, paint)
		b.box(Vector3(0.05, top, 0.3), Vector3(x, top / 2.0, z + 0.35), col, paint)
		b.box(Vector3(0.5, 0.05, 0.5), Vector3(x, 0.025, z + 0.35), Color("555b60"), steel)
		b.box(Vector3(0.22, 0.45, 1.6), Vector3(x, top - 0.2, z + 1.1), col, paint)
	# Eave strip of roof sheeting with a gutter
	b.box(Vector3(length, 0.08, 1.9), Vector3(cx, top + 0.05, z + 0.95), Color("9aa3ab"), steel, Vector3(0.06, 0, 0))
	b.box(Vector3(length, 0.14, 0.14), Vector3(cx, top - 0.02, z + 1.92), Color("7c858d"), steel)
	# Water and fire mains, compressed air and a cable tray along the wall
	b.bar(Vector3(x0 + 0.3, 2.75, z + 0.72), Vector3(x1 - 0.3, 2.75, z + 0.72), 0.14, Color("2f6db5"), paint, true)
	b.bar(Vector3(x0 + 0.3, 3.0, z + 0.72), Vector3(x1 - 0.3, 3.0, z + 0.72), 0.14, Color("c0392b"), paint, true)
	b.bar(Vector3(x0 + 0.3, 2.55, z + 0.62), Vector3(x1 - 0.3, 2.55, z + 0.62), 0.07, Color("3a9b5c"), paint, true)
	b.box(Vector3(length - 0.6, 0.06, 0.4), Vector3(cx, 3.25, z + 0.55), Color("8d969d"), steel)
	for i in 4:
		b.box(Vector3(length - 0.6, 0.05, 0.05), Vector3(cx, 3.31, z + 0.42 + i * 0.09), Color("26292c"), Palette.surface("rubber"))
	# Electrical cabinets, a fire point and an air compressor
	for x in [-10.9, -10.1, 2.3, 3.1]:
		b.box(Vector3(0.75, 2.0, 0.45), Vector3(x, 1.0, z + 0.4), Color("b8bec4"), paint)
		b.box(Vector3(0.02, 1.8, 0.02), Vector3(x, 1.0, z + 0.63), Color("6d747a"))
		b.box(Vector3(0.14, 0.12, 0.01), Vector3(x + 0.2, 1.62, z + 0.63), Color("f2c12e"))
		b.box(Vector3(0.04, 0.22, 0.04), Vector3(x + 0.28, 1.0, z + 0.645), Color("26292c"))
		b.bar(Vector3(x, 2.0, z + 0.4), Vector3(x, 3.2, z + 0.4), 0.12, Color("8d969d"), steel)
	b.box(Vector3(0.7, 0.9, 0.25), Vector3(-3.6, 1.5, z + 0.3), Color("c62828"), paint)
	b.box(Vector3(0.5, 0.5, 0.02), Vector3(-3.6, 1.55, z + 0.43), Color("e8e4dc"))
	b.cylinder(0.09, 0.5, Vector3(-3.0, 0.3, z + 0.32), Color("d32f2f"), paint)
	b.cylinder(0.03, 0.08, Vector3(-3.0, 0.59, z + 0.32), Color("26292c"))
	b.build(_back_wall)
	var sign := Palette.label3d(_back_wall, "XƯỞNG SẢN XUẤT", Vector3(-6, 5.0, z + 0.2), 44, Color("1f2a36"))
	sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sign.no_depth_test = false
	sign.outline_size = 0
	var sign2 := Palette.label3d(_back_wall, "KHO HÀNG", Vector3(13, 5.0, z + 0.2), 44, Color("1f2a36"))
	sign2.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sign2.no_depth_test = false
	sign2.outline_size = 0


## Low-wall stand-in for the back wall while the camera looks from the north.
func _build_back_wall_low() -> void:
	_back_wall_low = Node3D.new()
	add_child(_back_wall_low)
	var keep := _solid
	_solid = MeshBatch.new()
	_wall_piece(true, FactoryLayout.HALL_MIN.y, FactoryLayout.HALL_MIN.x, FactoryLayout.WAREHOUSE_MAX.x, 1.2, 0.25)
	_solid.build(_back_wall_low)
	_solid = keep
	_back_wall_low.visible = false


func _update_back_wall() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var from_south := cam.global_transform.basis.z.z > 0.05
	if _back_wall.visible != from_south:
		_back_wall.visible = from_south
		_back_wall_low.visible = not from_south


## Shaded rest area west of the office: two benches at a picnic table, a
## water cooler, plants. Idle staff sit here when there is no work.
func _build_rest_area() -> void:
	var a := FactoryLayout.REST_MIN
	var e := FactoryLayout.REST_MAX
	var paint := Palette.surface("paint")
	var steel := Palette.surface("steel")
	_floor(a, e, Color("b9a58a"), 0.05, "paving")
	_outline(a + Vector2(0.15, 0.15), e - Vector2(0.15, 0.15), Color("f2c12e"), 0.08, 0.055)
	# Benches (seat 0.45 m) facing a long table
	for z in [7.15, 10.65]:
		_solid.box(Vector3(4.2, 0.07, 0.42), Vector3(-21.1, 0.44, z), Color("a1714a"))
		for x in [-22.9, -21.1, -19.3]:
			_solid.box(Vector3(0.08, 0.42, 0.36), Vector3(x, 0.21, z), Color("5d6a72"), steel)
	_solid.box(Vector3(4.2, 0.07, 1.4), Vector3(-21.1, 0.76, 8.9), Color("c08a5a"))
	for x in [-22.9, -19.3]:
		_solid.box(Vector3(0.1, 0.74, 1.1), Vector3(x, 0.37, 8.9), Color("5d6a72"), steel)
	# Cups, a thermos and a fruit plate on the table
	for k in 4:
		_solid.cylinder(0.05, 0.11, Vector3(-22.4 + k * 0.9, 0.85, 8.55 + (k % 2) * 0.7), Color("eceff1"), paint, 0.06, Vector3.ZERO, 8)
	_solid.cylinder(0.09, 0.32, Vector3(-21.0, 0.95, 8.9), Color("c62828"), paint, -1.0, Vector3.ZERO, 10)
	_solid.cylinder(0.25, 0.03, Vector3(-20.2, 0.81, 8.9), Color("fafafa"), paint, -1.0, Vector3.ZERO, 14)
	for k in 3:
		_solid.sphere(0.07, Vector3(-20.28 + k * 0.08, 0.86, 8.86 + (k % 2) * 0.08), Color("ff9800").lerp(Color("8bc34a"), k / 2.0), paint)
	# Open pergola on four posts (open slats, so the people below stay visible)
	for x in [a.x + 0.4, e.x - 0.4]:
		for z in [6.1, 11.7]:
			_solid.cylinder(0.07, 2.7, Vector3(x, 1.35, z), Color("8d969d"), steel, -1.0, Vector3.ZERO, 8)
		_solid.box(Vector3(0.12, 0.14, 5.9), Vector3(x, 2.7, 8.9), Color("2e8b57"), paint)
	for k in 5:
		_solid.box(Vector3(e.x - a.x - 0.4, 0.08, 0.08), Vector3((a.x + e.x) / 2.0, 2.8, 6.1 + k * 1.4), Color("2e8b57"), paint)
	# Water cooler and a bin
	_solid.box(Vector3(0.42, 1.0, 0.42), Vector3(-19.1, 0.5, 12.6), Color("eceff1"), paint)
	_solid.cylinder(0.17, 0.45, Vector3(-19.1, 1.23, 12.6), Color("64b5f6"), Palette.surface("glass"), -1.0, Vector3.ZERO, 12)
	_solid.cylinder(0.2, 0.55, Vector3(-19.1, 0.28, 5.2), Color("43a047"), paint, 0.17, Vector3.ZERO, 10)
	# Potted plants on the corners
	for p in [Vector3(-23.2, 0, 5.1), Vector3(-23.2, 0, 13.0)]:
		_solid.cylinder(0.28, 0.45, p + Vector3(0, 0.22, 0), Color("8d6e63"), paint, 0.22, Vector3.ZERO, 10)
		_solid.sphere(0.42, p + Vector3(0, 0.75, 0), Color("4caf50"), null, Vector3(1, 1.2, 1), 8, 5)
	Palette.label3d(self, "Khu nghỉ ngơi", Vector3(-21.1, 3.5, 8.9), 30, Color("c8f7c5"))


func _build_hall() -> void:
	var a := FactoryLayout.HALL_MIN
	var b := FactoryLayout.HALL_MAX
	_floor(a, b, Palette.HALL_FLOOR)
	_walls(a, b, [["e", -8, 0], ["s", -8, -4], ["w", -1.5, 1.5]], 1.2, "n")
	# Machine bays outlined in yellow, walkways between the rows
	for slot in FactoryLayout.MAX_SLOTS:
		var p := FactoryLayout.slot_position(slot)
		_outline(Vector2(p.x - 1.55, p.z - 1.1), Vector2(p.x + 2.7, p.z + 1.1), Color("e3b51f"))
	for zz in [-7.3, -5.3, -1.7, 0.3]:
		_flat.box(Vector3(b.x - a.x - 0.8, 0.01, 0.1), Vector3((a.x + b.x) / 2.0, 0.065, zz), Color("3f9d5a"))
	_build_workshop_corner()
	# Scrap skip: a tapered steel bin with offcuts in it
	var paint := Palette.surface("paint")
	var bin := FactoryLayout.SCRAP_BIN
	_solid.cylinder(0.62, 0.85, bin + Vector3(0, 0.5, 0), Color("b23a2e"), paint, 0.8, Vector3(0, PI / 4, 0), 4)
	_solid.box(Vector3(1.2, 0.08, 1.0), bin + Vector3(0, 0.06, 0), Color("4a4f54"), Palette.surface("steel"))
	for k in 5:
		_solid.box(Vector3(0.22, 0.16, 0.22), bin + Vector3(-0.3 + k * 0.15, 0.86, -0.15 + (k % 2) * 0.3), Palette.SCRAP.lightened(0.1 * (k % 3)), null, Vector3(0, k * 0.7, 0.3))
	Palette.label3d(self, "Phế phẩm", bin + Vector3(0, 1.5, 0), 32)


## Workbench, tool trolley and air compressor along the west wall.
func _build_workshop_corner() -> void:
	var paint := Palette.surface("paint")
	var steel := Palette.surface("steel")
	var x := FactoryLayout.HALL_MIN.x + 0.5
	# Workbench with a vice and a red tool chest
	_solid.box(Vector3(0.7, 0.06, 1.8), Vector3(x, 0.9, -6.2), Color("a0764e"))
	for dz in [-0.82, 0.82]:
		for dx in [-0.28, 0.28]:
			_solid.box(Vector3(0.05, 0.87, 0.05), Vector3(x + dx, 0.435, -6.2 + dz), Color("4a5560"), steel)
	_solid.box(Vector3(0.62, 0.04, 1.7), Vector3(x, 0.25, -6.2), Color("6d747a"), steel)
	_solid.box(Vector3(0.18, 0.14, 0.12), Vector3(x + 0.15, 1.0, -5.6), Color("3d5a78"), paint)
	_solid.box(Vector3(0.4, 0.3, 0.6), Vector3(x - 0.05, 1.08, -6.6), Color("c62828"), paint)
	_solid.box(Vector3(0.41, 0.02, 0.61), Vector3(x - 0.05, 1.12, -6.6), Color("8e1c1c"), paint)
	# Air compressor with its receiver tank
	_solid.box(Vector3(0.7, 0.9, 0.9), Vector3(x, 0.45, -3.6), Color("2f6db5"), paint)
	_solid.box(Vector3(0.5, 0.3, 0.02), Vector3(x + 0.36, 0.65, -3.6), Color("1c2a36"), Palette.surface("screen"))
	_solid.cylinder(0.3, 1.1, Vector3(x + 0.05, 0.4, -2.5), Color("8d969d"), steel, -1.0, Vector3(PI / 2, 0, 0), 12)
	_solid.box(Vector3(0.5, 0.1, 0.9), Vector3(x + 0.05, 0.05, -2.5), Color("4a4f54"), steel)


func _build_warehouse() -> void:
	var a := FactoryLayout.WAREHOUSE_MIN
	var b := FactoryLayout.WAREHOUSE_MAX
	_floor(a, Vector2(b.x, -4.5), Palette.WAREHOUSE_RAW)
	_floor(Vector2(a.x, -4.5), b, Palette.WAREHOUSE_FINISHED)
	_walls(a, b, [["s", 13, 17]], 1.2, "nw")
	_outline(Vector2(12.4, -11.7), Vector2(19.5, -9.0), Color("e3b51f"))
	_outline(Vector2(12.4, -3.1), Vector2(19.5, 0.7), Color("e3b51f"))
	_flat.box(Vector3(b.x - a.x, 0.01, 0.1), Vector3((a.x + b.x) / 2.0, 0.065, -4.5), Color("e3b51f"))
	Palette.label3d(self, "Kho nguyên liệu", Vector3(16, 2.2, -11), 40)
	Palette.label3d(self, "Kho thành phẩm", Vector3(16, 2.2, -3), 40)
	_forklift(Vector3(8.2, 0, -10.4), 0.0)
	# Roller door frame over the loading doorway
	var steel := Palette.surface("steel")
	for x in [12.9, 17.1]:
		_solid.box(Vector3(0.2, 3.2, 0.3), Vector3(x, 1.6, b.y), Color("3d5a78"), Palette.surface("paint"))
	_solid.box(Vector3(4.4, 0.5, 0.5), Vector3(15, 3.35, b.y), Color("9aa3ab"), steel)
	_solid.box(Vector3(4.0, 0.25, 0.08), Vector3(15, 2.98, b.y + 0.05), Color("b8bec4"), steel)
	_solid.box(Vector3(0.22, 0.3, 0.12), Vector3(17.4, 1.3, b.y + 0.2), Color("f2c12e"), Palette.surface("paint"))
	for i in 24:
		_raw_piles.append(_raw_pile(FactoryLayout.RAW_STACK_ORIGIN + Vector3((i % 6) * 1.1, (i / 12) * 0.75, ((i / 6) % 2) * 1.2)))
	for i in 30:
		_finished_piles.append(_finished_pile(FactoryLayout.FINISHED_STACK_ORIGIN + Vector3((i % 6) * 1.1, (i / 18) * 0.85, ((i / 6) % 3) * 1.2)))


## A parked counterbalance forklift.
func _forklift(pos: Vector3, yaw: float) -> void:
	var keep := _solid.origin
	_solid.origin = Transform3D(Basis(Vector3.UP, yaw), pos)
	var paint := Palette.surface("paint")
	var steel := Palette.surface("steel")
	var rubber := Palette.surface("rubber")
	var body := Color("f2a516")
	_solid.box(Vector3(1.1, 0.7, 1.8), Vector3(0, 0.6, 0), body, paint)
	_solid.box(Vector3(1.1, 0.6, 0.5), Vector3(0, 0.65, -0.85), Color("3a3f44"), paint)
	_solid.box(Vector3(0.5, 0.25, 0.5), Vector3(0, 1.05, -0.2), Color("26292c"), rubber)
	_solid.box(Vector3(0.45, 0.5, 0.1), Vector3(0, 1.25, -0.45), Color("26292c"), rubber)
	for x in [-0.5, 0.5]:
		for zz in [-0.4, 0.75]:
			_solid.bar(Vector3(x, 0.95, zz), Vector3(x, 2.1, zz * 0.9), 0.06, Color("3a3f44"), steel)
		_solid.cylinder(0.27, 0.22, Vector3(x * 1.08, 0.27, 0.55), Color("1f2124"), rubber, -1.0, Vector3(0, 0, PI / 2), 12)
		_solid.cylinder(0.22, 0.2, Vector3(x * 1.06, 0.22, -0.6), Color("1f2124"), rubber, -1.0, Vector3(0, 0, PI / 2), 12)
	_solid.box(Vector3(1.1, 0.06, 1.3), Vector3(0, 2.12, 0.15), Color("3a3f44"), steel)
	for x in [-0.3, 0.3]:
		_solid.box(Vector3(0.1, 2.2, 0.1), Vector3(x, 1.15, 1.0), Color("3a3f44"), steel)
		_solid.box(Vector3(0.1, 0.04, 1.0), Vector3(x, 0.08, 1.55), Color("5a6066"), steel)
	_solid.box(Vector3(0.8, 0.08, 0.06), Vector3(0, 2.2, 1.0), Color("3a3f44"), steel)
	_solid.box(Vector3(0.12, 0.1, 0.06), Vector3(0, 2.18, 0.2), Color("ff9800"), Palette.surface("screen"))
	_solid.origin = keep


## A pallet with one load on it; the load's colour shows which product it is.
func _finished_pile(pos: Vector3) -> MeshInstance3D:
	var p := Node3D.new()
	p.position = pos
	var deck := MeshInstance3D.new()
	deck.mesh = _pallet_mesh()
	p.add_child(deck)
	var load := Palette.box(p, Vector3(0.9, 0.6, 0.9), Vector3(0, 0.45, 0), Palette.BOX)
	p.visible = false
	add_child(p)
	return load


## A bulk bag of pellets on a pallet.
func _raw_pile(pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.position = pos
	var mi := MeshInstance3D.new()
	mi.mesh = _bag_mesh()
	p.add_child(mi)
	p.visible = false
	add_child(p)
	return p


func _pallet_mesh() -> Mesh:
	if _pallet_shared == null:
		var b := MeshBatch.new()
		Palette.pallet(b, Vector3.ZERO)
		_pallet_shared = b.build_mesh()
	return _pallet_shared


func _bag_mesh() -> Mesh:
	if _bag_shared == null:
		var b := MeshBatch.new()
		Palette.pallet(b, Vector3.ZERO, Vector2(0.95, 0.95))
		b.box(Vector3(0.84, 0.5, 0.84), Vector3(0, 0.37, 0), Palette.PELLET_BAG)
		b.cylinder(0.42, 0.07, Vector3(0, 0.655, 0), Palette.PELLET_BAG.darkened(0.06), null, 0.16, Vector3(0, PI / 4, 0), 4)
		for c in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
			b.box(Vector3(0.05, 0.14, 0.05), Vector3(c.x * 0.38, 0.66, c.y * 0.38), Color("d8c9a0"))
		b.box(Vector3(0.3, 0.2, 0.01), Vector3(0, 0.4, 0.425), Color("4a7fb5"))
		_bag_shared = b.build_mesh()
	return _bag_shared


## Extra stock spots on the racks of the warehouse annex (shown once it is
## built and the main warehouse spots are full).
func _build_annex_piles() -> void:
	for i in 48:
		var level := i / 16
		var cell := i % 16
		_raw_piles.append(_raw_pile(Vector3(21.3 + (cell % 2) * 1.2, 0.1 + level * 0.85, -11.4 + (cell / 2) * 0.95)))
	for i in 64:
		var level := i / 16
		var cell := i % 16
		_finished_piles.append(_finished_pile(Vector3(21.3 + (cell % 2) * 1.2, 0.1 + level * 0.85, -3.4 + (cell / 2) * 0.95)))


func _build_dock_and_office() -> void:
	var a := FactoryLayout.DOCK_MIN
	var b := FactoryLayout.DOCK_MAX
	_floor(a, b, Palette.DOCK, 0.05, "paving")
	_outline(a + Vector2(0.15, 0.15), b - Vector2(0.15, 0.15), Color("e3b51f"), 0.18, 0.055)
	for i in 9:
		_flat.box(Vector3(0.18, 0.01, 1.2), Vector3(a.x + 0.8 + i * 1.1, 0.055, b.y - 0.75), Color("e3b51f"), null, Vector3(0, 0.6, 0))
	for x in [a.x + 0.2, b.x - 0.2]:
		_bollard(Vector3(x, 0, b.y - 0.2))
		_bollard(Vector3(x, 0, a.y + 0.2))
	# Hand pallet truck waiting by the stack
	var steel := Palette.surface("steel")
	_solid.box(Vector3(0.18, 0.08, 1.15), Vector3(19.6, 0.05, 9.2), Color("d32f2f"), Palette.surface("paint"))
	_solid.box(Vector3(0.18, 0.08, 1.15), Vector3(20.1, 0.05, 9.2), Color("d32f2f"), Palette.surface("paint"))
	_solid.box(Vector3(0.65, 0.3, 0.2), Vector3(19.85, 0.2, 8.55), Color("d32f2f"), Palette.surface("paint"))
	_solid.bar(Vector3(19.85, 0.3, 8.5), Vector3(19.85, 1.15, 8.2), 0.05, Color("3a3f44"), steel)
	_solid.box(Vector3(0.35, 0.05, 0.05), Vector3(19.85, 1.17, 8.19), Color("26292c"), Palette.surface("rubber"))
	Palette.label3d(self, "Bãi giao nhận", Vector3(16, 1.8, 7), 40)
	for i in 24:
		var p := Node3D.new()
		p.position = FactoryLayout.DOCK_STACK_ORIGIN + Vector3((i % 6) * 1.0, (i / 12) * 0.7, ((i / 6) % 2) * 1.1)
		var mi := MeshInstance3D.new()
		mi.mesh = _bag_mesh()
		p.add_child(mi)
		p.visible = false
		add_child(p)
		_dock_piles.append(p)
	_build_office()


func _build_office() -> void:
	var a := FactoryLayout.OFFICE_MIN
	var b := FactoryLayout.OFFICE_MAX
	_floor(a, b, Palette.OFFICE)
	_walls(a, b, [["n", -15, -12]], 1.1)
	# Rug, the owner's desk with a monitor, visitor chairs, shelves, a sofa
	# and plants
	var paint := Palette.surface("paint")
	var steel := Palette.surface("steel")
	var screen := Palette.surface("screen")
	var desk := FactoryLayout.OWNER_DESK + Vector3(0, 0, 1.0)
	_flat.box(Vector3(4.2, 0.01, 2.8), Vector3(desk.x, 0.065, desk.z), Color("7b4f3a"))
	_solid.box(Vector3(2.0, 0.06, 1.0), desk + Vector3(0, 0.76, 0), Color("6d4c41"))
	_solid.box(Vector3(0.06, 0.73, 0.9), desk + Vector3(-0.95, 0.365, 0), Color("5d4037"))
	_solid.box(Vector3(0.5, 0.6, 0.9), desk + Vector3(0.7, 0.36, 0), Color("5d4037"))
	_solid.box(Vector3(0.75, 0.45, 0.04), desk + Vector3(0, 1.05, 0.25), Color("1d2125"), paint)
	_solid.box(Vector3(0.69, 0.39, 0.01), desk + Vector3(0, 1.05, 0.225), Color("5aa9e6"), screen)
	_solid.box(Vector3(0.08, 0.2, 0.08), desk + Vector3(0, 0.88, 0.28), Color("1d2125"), steel)
	_solid.box(Vector3(0.5, 0.02, 0.18), desk + Vector3(0, 0.8, -0.15), Color("2a2e33"))
	for dx in [-0.5, 0.5]:
		_chair(desk + Vector3(dx, 0, 1.2), PI)
	_solid.box(Vector3(1.0, 1.8, 0.45), Vector3(-17, 0.9, 12.5), Color("90a4ae"), paint)
	_solid.box(Vector3(1.8, 2.0, 0.4), Vector3(-10.4, 1.0, 12.6), Color("8d6e63"))
	for shelf in 4:
		_solid.box(Vector3(1.7, 0.03, 0.36), Vector3(-10.4, 0.45 + shelf * 0.45, 12.55), Color("5d4037"))
		for k in 6:
			_solid.box(Vector3(0.1, 0.32, 0.26), Vector3(-11.1 + k * 0.26, 0.63 + shelf * 0.45, 12.55), [Color("c0392b"), Color("2f6db5"), Color("e3b51f"), Color("3a9b5c")][(k + shelf) % 4])
	_solid.box(Vector3(0.8, 0.4, 2.0), Vector3(-17.4, 0.3, 8.6), Color("546e7a"))
	_solid.box(Vector3(0.25, 0.45, 2.0), Vector3(-17.7, 0.7, 8.6), Color("546e7a"))
	for p in [Vector3(-17.4, 0, 6.6), Vector3(-9.6, 0, 6.6)]:
		_plant(p)
	_solid.cylinder(0.16, 1.0, Vector3(-9.6, 0.5, 9.5), Color("eceff1"), paint)
	_solid.cylinder(0.14, 0.35, Vector3(-9.6, 1.17, 9.5), Color("90caf9"), Palette.surface("glass"))


func _chair(p: Vector3, yaw: float) -> void:
	var keep := _solid.origin
	_solid.origin = Transform3D(Basis(Vector3.UP, yaw), p)
	_solid.box(Vector3(0.45, 0.08, 0.45), Vector3(0, 0.45, 0), Color("263238"))
	_solid.box(Vector3(0.45, 0.5, 0.06), Vector3(0, 0.75, -0.2), Color("263238"))
	_solid.cylinder(0.03, 0.4, Vector3(0, 0.22, 0), Color("90a4ae"), Palette.surface("steel"), -1.0, Vector3.ZERO, 6)
	_solid.cylinder(0.25, 0.04, Vector3(0, 0.03, 0), Color("37474f"), null, -1.0, Vector3.ZERO, 5)
	_solid.origin = keep


func _plant(p: Vector3) -> void:
	_solid.cylinder(0.22, 0.45, p + Vector3(0, 0.225, 0), Color("b07a54"), null, 0.27)
	for k in 5:
		var ang := k * TAU / 5.0
		_solid.sphere(0.22, p + Vector3(cos(ang) * 0.15, 0.75 + (k % 2) * 0.18, sin(ang) * 0.15), Color("3f7a34").lightened(0.06 * (k % 3)), null, Vector3(1, 1.3, 1), 8, 5)
	_solid.sphere(0.2, p + Vector3(0, 1.05, 0), Color("4f8a3c"), null, Vector3.ONE, 8, 5)


func _build_slot_pads() -> void:
	for slot in FactoryLayout.MAX_SLOTS:
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
		var show := active and free and slot < sim.buildings.machine_slots()
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
			var v: Node3D = MachineScene.instantiate()
			v.machine_id = m.id
			v.position = FactoryLayout.slot_position(int(m.slot))
			add_child(v)
			Palette.pick_body(v, Vector3(4.4, 3.0, 2.4), Vector3(0.8, 1.4, 0), "machine", m.id)
			_machines[m.id] = v
	for id in _machines.keys():
		if not seen.has(id):
			_machines[id].queue_free()
			_machines.erase(id)


func _sync_workers(sim: Simulation) -> void:
	var seen := {}
	var idle := {"operator": 0, "warehouse": 0, "technician": 0}
	var rest := 0
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
		_workers[e.id].idle_index = idle.get(e.role, 0)
		idle[e.role] = idle.get(e.role, 0) + 1
		if e.role != EmployeeManager.MANAGER:
			_workers[e.id].rest_index = rest
			rest += 1
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
	# One pallet per started batch of each product, in the product's colour.
	var i := 0
	for pid in sim.content.products:
		var qty := sim.state.finished_of(pid)
		if qty <= 0:
			continue
		var m := Palette.mat(sim.content.products[pid].color)
		for k in ceili(float(qty) / cfg.haul_finished_batch):
			if i >= _finished_piles.size():
				break
			_finished_piles[i].material_override = m
			_finished_piles[i].get_parent().visible = true
			i += 1
	for k in range(i, _finished_piles.size()):
		_finished_piles[k].get_parent().visible = false


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
