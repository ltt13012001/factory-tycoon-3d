## The optional buildings (warehouse annex, hall expansion, sales office,
## solar car-park canopy, break room) and the construction site with
## scaffolding, builders and a progress label while one is being built.
extends Node3D

const SITES := {
	"warehouse_expansion": [FactoryLayout.ANNEX_MIN, FactoryLayout.ANNEX_MAX, 3.6],
	"hall_expansion": [Vector2(-18, -1.2), Vector2(6, 5), 1.4],
	"sales_office": [FactoryLayout.SALES_OFFICE_MIN, FactoryLayout.SALES_OFFICE_MAX, 2.6],
	"solar_roof": [FactoryLayout.PARKING_MIN, FactoryLayout.PARKING_MAX, 3.4],
	"break_room": [FactoryLayout.BREAK_ROOM_MIN, FactoryLayout.BREAK_ROOM_MAX, 2.6],
}
const SCAFFOLD := Color("f39c12")
const GLASS := Color(0.55, 0.8, 0.95, 0.55)

var _built := {}  # construction id -> Node3D shown once level >= 1
var _locked_zone: Node3D  # hall row three, until the hall expansion is built
var _site: Node3D
var _site_id := ""
var _site_ghost: MeshInstance3D
var _site_label: Label3D
var _builders: Array[Node3D] = []
var _time := 0.0


func _ready() -> void:
	_build_parking()
	_built["warehouse_expansion"] = _build_annex()
	_built["hall_expansion"] = _build_hall_row()
	_built["sales_office"] = _build_sales_office()
	_built["solar_roof"] = _build_solar_canopy()
	_built["break_room"] = _build_break_room()
	for id in _built:
		_built[id].visible = false
	EventBus.construction_finished.connect(_on_finished)


func _process(delta: float) -> void:
	_time += delta
	var sim: Simulation = GameManager.sim
	if sim == null:
		return
	for id in _built:
		var on := sim.buildings.level(id) > 0
		if _built[id].visible != on:
			_built[id].visible = on
	_locked_zone.visible = sim.buildings.level("hall_expansion") == 0
	_sync_site(sim, delta)


func _on_finished(data: Dictionary) -> void:
	var node: Node3D = _built.get(data.id)
	if node == null:
		return
	node.visible = true
	node.scale = Vector3(1, 0.05, 1)
	create_tween().tween_property(node, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- Construction site -----------------------------------------------------------

func _sync_site(sim: Simulation, delta: float) -> void:
	var c: Dictionary = sim.state.construction
	var id: String = "" if c.is_empty() else String(c.id)
	if id != _site_id:
		if _site:
			_site.queue_free()
			_site = null
		_site_id = id
		if id != "" and SITES.has(id):
			_make_site(id)
	if _site == null:
		return
	var done := 1.0 - float(c.ticks_left) / maxf(1.0, float(c.total_ticks))
	_site_ghost.scale.y = maxf(0.02, done)
	_site_ghost.position.y = _site_ghost.mesh.size.y * _site_ghost.scale.y / 2.0
	var d: ConstructionDef = sim.content.constructions[id]
	_site_label.text = "Đang xây %s  %d%%" % [d.display_name, roundi(done * 100.0)]
	var speed := maxf(1.0, TimeManager.speed) if TimeManager.speed > 0 else 0.0
	for i in _builders.size():
		var b := _builders[i]
		var a: float = b.get_meta("angle") + delta * 0.6 * speed
		b.set_meta("angle", a)
		var r: Vector2 = b.get_meta("radius")
		b.position = Vector3(cos(a) * r.x, 0, sin(a) * r.y) + b.get_meta("center")
		b.rotation.y = -a
		b.get_child(0).position.y = absf(sin(_time * 10.0 + i)) * 0.1 * minf(1.0, speed)


func _make_site(id: String) -> void:
	var min_c: Vector2 = SITES[id][0]
	var max_c: Vector2 = SITES[id][1]
	var h: float = SITES[id][2]
	var size := max_c - min_c
	var c := (max_c + min_c) / 2.0
	_site = Node3D.new()
	add_child(_site)
	# Ghost volume that rises with progress
	_site_ghost = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size.x - 0.4, h, size.y - 0.4)
	_site_ghost.mesh = bm
	_site_ghost.material_override = Palette.mat(Color(0.95, 0.75, 0.35, 0.45))
	_site_ghost.position = Vector3(c.x, 0, c.y)
	_site.add_child(_site_ghost)
	# Scaffolding poles, rails and planks, merged into one mesh
	var sb := MeshBatch.new()
	var steel := Palette.surface("steel")
	var poles_x := maxi(2, ceili(size.x / 3.0) + 1)
	var poles_z := maxi(2, ceili(size.y / 3.0) + 1)
	for ix in poles_x:
		for iz in poles_z:
			if ix != 0 and ix != poles_x - 1 and iz != 0 and iz != poles_z - 1:
				continue
			var p := Vector3(min_c.x + size.x * ix / (poles_x - 1), h / 2.0 + 0.3, min_c.y + size.y * iz / (poles_z - 1))
			sb.cylinder(0.05, h + 0.6, p, SCAFFOLD, steel, -1.0, Vector3.ZERO, 6)
	var levels := maxi(1, int(h / 1.2))
	for l in levels + 1:
		var y := 0.3 + (h + 0.3) * l / levels
		sb.box(Vector3(size.x, 0.08, 0.08), Vector3(c.x, y, min_c.y), SCAFFOLD, steel)
		sb.box(Vector3(size.x, 0.08, 0.08), Vector3(c.x, y, max_c.y), SCAFFOLD, steel)
		sb.box(Vector3(0.08, 0.08, size.y), Vector3(min_c.x, y, c.y), SCAFFOLD, steel)
		sb.box(Vector3(0.08, 0.08, size.y), Vector3(max_c.x, y, c.y), SCAFFOLD, steel)
	# Barrier cones at the corners and a pile of materials
	for corner in [min_c, Vector2(max_c.x, min_c.y), Vector2(min_c.x, max_c.y), max_c]:
		sb.cylinder(0.22, 0.6, Vector3(corner.x, 0.3, corner.y), Color("ff6d00"), Palette.surface("paint"), 0.03)
		sb.cylinder(0.16, 0.1, Vector3(corner.x, 0.33, corner.y), Color("f5f5f5"), Palette.surface("paint"), 0.13)
	sb.box(Vector3(1.2, 0.4, 0.8), Vector3(min_c.x + 0.9, 0.2, max_c.y - 0.7), Color("9e9e9e"), Palette.surface("paving"))
	sb.box(Vector3(1.4, 0.15, 0.5), Vector3(min_c.x + 0.9, 0.48, max_c.y - 0.7), Color("a1887f"))
	# Walkway planks on the long sides and diagonal braces
	for z in [min_c.y - 0.35, max_c.y + 0.35]:
		for l in range(1, levels + 1):
			sb.box(Vector3(size.x, 0.05, 0.5), Vector3(c.x, 0.3 + (h + 0.3) * l / levels - 0.06, z), Color("a1887f"))
		sb.bar(Vector3(min_c.x, 0.3, z), Vector3(max_c.x, h + 0.3, z), 0.06, SCAFFOLD, steel, true)
	sb.build(_site)
	_site_label = Palette.label3d(_site, "", Vector3(c.x, h + 1.6, c.y), 40, Color("ffd54f"))
	# Two builders walking around the site
	_builders.clear()
	for i in 2:
		var b := Node3D.new()
		var v := Node3D.new()
		b.add_child(v)
		var body := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.28
		cap.height = 1.15
		body.mesh = cap
		body.position = Vector3(0, 0.58, 0)
		body.material_override = Palette.mat(Color("ff7043"))
		v.add_child(body)
		Palette.sphere(v, 0.22, Vector3(0, 1.36, 0), Palette.SKIN)
		Palette.sphere(v, 0.25, Vector3(0, 1.48, 0), Color("fff176")).scale = Vector3(1, 0.55, 1)
		b.set_meta("angle", i * PI)
		b.set_meta("radius", Vector2(size.x / 2.0 + 0.7, size.y / 2.0 + 0.7))
		b.set_meta("center", Vector3(c.x, 0, c.y))
		_site.add_child(b)
		_builders.append(b)


# --- Finished buildings -----------------------------------------------------------
# Each building is merged into one mesh (see MeshBatch).

func _floor(b: MeshBatch, min_c: Vector2, max_c: Vector2, color: Color, h: float = 0.07, kind := "floor") -> void:
	var size := max_c - min_c
	var c := (max_c + min_c) / 2.0
	b.box(Vector3(size.x, h, size.y), Vector3(c.x, h / 2.0, c.y), color, Palette.surface(kind))


## Low cut-away walls on the four sides, with one doorway gap: concrete
## plinth, rendered wall, a band of windows and a coping.
func _room_walls(b: MeshBatch, min_c: Vector2, max_c: Vector2, door_side: String, door_from: float, door_to: float) -> void:
	var t := 0.22
	var height := 1.1
	var sides := {
		"n": [Vector2(min_c.x, min_c.y), Vector2(max_c.x, min_c.y)],
		"s": [Vector2(min_c.x, max_c.y), Vector2(max_c.x, max_c.y)],
		"w": [Vector2(min_c.x, min_c.y), Vector2(min_c.x, max_c.y)],
		"e": [Vector2(max_c.x, min_c.y), Vector2(max_c.x, max_c.y)],
	}
	for side in sides:
		var a: Vector2 = sides[side][0]
		var e: Vector2 = sides[side][1]
		var horizontal: bool = side == "n" or side == "s"
		var spans := [[a.x, e.x]] if horizontal else [[a.y, e.y]]
		if side == door_side:
			spans = [[spans[0][0], door_from], [door_to, spans[0][1]]]
		for span in spans:
			var l: float = span[1] - span[0]
			if l <= 0.05:
				continue
			var mid: float = (span[0] + span[1]) / 2.0
			var pos := Vector3(mid, 0, a.y) if horizontal else Vector3(a.x, 0, mid)
			var size := Vector3(l, 1, t) if horizontal else Vector3(t, 1, l)
			b.box(Vector3(size.x + 0.04, 0.3, size.z + 0.04), pos + Vector3(0, 0.15, 0), Color("a19e97"), Palette.surface("paving"))
			b.box(Vector3(size.x, height - 0.3, size.z), pos + Vector3(0, 0.3 + (height - 0.3) / 2.0, 0), Palette.WALL)
			var glass := Vector3(size.x - 0.3, 0.3, size.z + 0.02) if horizontal else Vector3(size.x + 0.02, 0.3, size.z - 0.3)
			if l > 1.0:
				b.box(glass, pos + Vector3(0, 0.78, 0), Color("4d6378"), Palette.surface("paint"))
			b.box(Vector3(size.x + 0.04, 0.08, size.z + 0.04), pos + Vector3(0, height + 0.04, 0), Palette.WALL_TRIM, Palette.surface("steel"))


func _person(parent: Node3D, pos: Vector3, color: Color, yaw: float, sitting: bool = false) -> void:
	var p := Node3D.new()
	p.position = pos
	p.rotation.y = yaw
	parent.add_child(p)
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.28
	cap.height = 0.9 if sitting else 1.2
	body.mesh = cap
	body.position = Vector3(0, 0.75 if sitting else 0.6, 0)
	body.material_override = Palette.mat(color)
	p.add_child(body)
	Palette.sphere(p, 0.23, Vector3(0, 1.4 if sitting else 1.42, 0), Palette.SKIN)


func _build_parking() -> void:
	var n := Node3D.new()
	add_child(n)
	var b := MeshBatch.new()
	var a := FactoryLayout.PARKING_MIN
	var e := FactoryLayout.PARKING_MAX
	_floor(b, a, e, Color("4f545a"), 0.04, "paving")
	for i in 8:
		var x := a.x + 1.0 + i * 2.0
		b.box(Vector3(0.1, 0.01, 2.6), Vector3(x, 0.045, 8.9), Color("eeeeee"))
	for i in 7:
		b.box(Vector3(1.0, 0.1, 0.18), Vector3(a.x + 2.0 + i * 2.0, 0.09, 7.85), Color("9a9893"), Palette.surface("paving"))
	# Accessible bay marking and a light pole
	b.box(Vector3(1.6, 0.01, 2.4), Vector3(e.x - 1.0, 0.043, 8.9), Color("2f6db5"))
	b.cylinder(0.06, 4.5, Vector3(e.x - 0.3, 2.25, e.y - 0.4), Color("6d747a"), Palette.surface("steel"), -1.0, Vector3.ZERO, 8)
	b.box(Vector3(0.6, 0.1, 0.25), Vector3(e.x - 0.55, 4.45, e.y - 0.4), Color("3a3f44"), Palette.surface("steel"))
	b.build(n, false)
	Palette.label3d(n, "Bãi đỗ xe", Vector3(-4.5, 1.2, 12), 32)
	# Staff cars
	var colors := [Color("b71c1c"), Color("eceff1"), Color("1565c0"), Color("455a64"), Color("2e2e2e")]
	for i in 4:
		_car(n, Vector3(a.x + 2.0 + i * 4.0, 0, 9.0), PI, colors[i])
	var bike := MeshBatch.new()
	for k in 2:
		bike.cylinder(0.3, 0.05, Vector3(e.x - 1.6, 0.3, 11.8 + k * 0.95), Color("1d2125"), Palette.surface("rubber"), -1.0, Vector3(0, 0, PI / 2), 12)
	bike.box(Vector3(0.12, 0.25, 0.9), Vector3(e.x - 1.6, 0.6, 12.27), colors[4], Palette.surface("paint"))
	bike.box(Vector3(0.3, 0.08, 0.5), Vector3(e.x - 1.6, 0.78, 12.15), Color("1d2125"))
	bike.build(n)


## A car, merged into one mesh. Faces +Z. lamp is the headlight material
## (the street-lamp material, so traffic headlights come on at night).
static func _car(parent: Node3D, pos: Vector3, yaw: float, color: Color, lamp: Material = null) -> Node3D:
	var car := Node3D.new()
	car.position = pos
	car.rotation.y = yaw
	parent.add_child(car)
	var b := MeshBatch.new()
	var paint := Palette.surface("paint")
	var rubber := Palette.surface("rubber")
	var screen := Palette.surface("screen")
	var glass := Color("26323e")
	var dark := Color("1d2125")
	b.box(Vector3(1.7, 0.5, 3.9), Vector3(0, 0.6, 0), color, paint)
	b.box(Vector3(1.66, 0.12, 1.0), Vector3(0, 0.88, 1.3), color, paint, Vector3(0.08, 0, 0))
	b.box(Vector3(1.45, 0.48, 1.9), Vector3(0, 1.08, -0.2), color, paint)
	b.box(Vector3(1.4, 0.44, 0.06), Vector3(0, 1.06, 0.77), glass, paint, Vector3(-0.55, 0, 0))
	b.box(Vector3(1.4, 0.42, 0.06), Vector3(0, 1.06, -1.17), glass, paint, Vector3(0.5, 0, 0))
	for x in [-0.73, 0.73]:
		b.box(Vector3(0.03, 0.34, 1.6), Vector3(x, 1.1, -0.2), glass, paint)
		b.box(Vector3(0.12, 0.08, 0.1), Vector3(x * 1.12, 1.0, 0.65), dark)
	for z in [-1.97, 1.97]:
		b.box(Vector3(1.72, 0.18, 0.1), Vector3(0, 0.42, z), dark, rubber)
	for x in [-0.6, 0.6]:
		b.box(Vector3(0.36, 0.13, 0.04), Vector3(x, 0.7, 1.96), Color("fff3c4"), lamp if lamp != null else screen)
		b.box(Vector3(0.32, 0.12, 0.04), Vector3(x, 0.72, -1.96), Color("c62828"), screen)
	for x in [-0.8, 0.8]:
		for z in [-1.25, 1.25]:
			b.cylinder(0.34, 0.24, Vector3(x, 0.34, z), Color("17181a"), rubber, -1.0, Vector3(0, 0, PI / 2), 14)
			b.cylinder(0.2, 0.25, Vector3(x, 0.34, z), Color("b9c0c6"), Palette.surface("steel"), -1.0, Vector3(0, 0, PI / 2), 8)
	b.build(car)
	return car


func _build_annex() -> Node3D:
	var n := Node3D.new()
	add_child(n)
	var b := MeshBatch.new()
	var steel := Palette.surface("steel")
	var paint := Palette.surface("paint")
	var min_c := Vector2(20.0, FactoryLayout.ANNEX_MIN.y)
	_floor(b, min_c, FactoryLayout.ANNEX_MAX, Color("a3b4c4"))
	_room_walls(b, min_c, FactoryLayout.ANNEX_MAX, "w", 0, 0)
	# Pallet racks: blue uprights with diagonal bracing, orange beams
	for half in [[-12.0, -4.0], [-4.0, 4.0]]:
		var z0: float = half[0] + 0.3
		var z1: float = half[1] - 0.3
		for x in [20.7, 23.3]:
			for z in [z0, (z0 + z1) / 2.0, z1]:
				b.box(Vector3(0.1, 3.5, 0.1), Vector3(x, 1.75, z), Color("1e5aa8"), paint)
				b.box(Vector3(0.25, 0.03, 0.25), Vector3(x, 0.015, z), Color("1e5aa8"), steel)
			for k in 2:
				var za: float = z0 if k == 0 else (z0 + z1) / 2.0
				var zb: float = (z0 + z1) / 2.0 if k == 0 else z1
				b.bar(Vector3(x, 0.3, za), Vector3(x, 3.2, zb), 0.04, Color("1e5aa8"), paint)
		for level in 4:
			var y := 0.06 + level * 0.85
			if level > 0:
				for x in [20.75, 23.25]:
					b.box(Vector3(0.1, 0.12, z1 - z0), Vector3(x, y - 0.06, (z0 + z1) / 2.0), Color("e67e22"), paint)
				b.box(Vector3(2.5, 0.03, z1 - z0), Vector3(22.0, y - 0.02, (z0 + z1) / 2.0), Color("9aa3ab"), steel)
	b.build(n)
	Palette.label3d(n, "Kho mở rộng", Vector3(22, 4.4, -4), 36)
	return n


func _build_hall_row() -> Node3D:
	# The unlocked third row: light floor markings.
	var n := Node3D.new()
	add_child(n)
	for i in 3:
		var p := FactoryLayout.slot_position(6 + i)
		Palette.box(n, Vector3(5.0, 0.07, 0.1), p + Vector3(0.9, 0.04, -1.5), Palette.STATUS_WARN)
	# Locked look: hatched floor, tape, cones and a sign.
	_locked_zone = Node3D.new()
	add_child(_locked_zone)
	var b := MeshBatch.new()
	_floor(b, Vector2(-17.8, -1.2), Vector2(5.8, 4.8), Color("8e8a83"), 0.08, "paving")
	for i in 12:
		var x := -17 + i * 2.0
		b.box(Vector3(0.35, 0.01, 6.0), Vector3(x, 0.085, 1.8), Color("6f6b64"), null, Vector3(0, 0.5, 0))
	for x in range(-17, 6, 3):
		b.cylinder(0.2, 0.6, Vector3(x, 0.3, -1.2), Color("ff6d00"), Palette.surface("paint"), 0.03)
		b.box(Vector3(0.45, 0.04, 0.45), Vector3(x, 0.02, -1.2), Color("26292c"), Palette.surface("rubber"))
		b.cylinder(0.15, 0.08, Vector3(x, 0.38, -1.2), Color("f5f5f5"), Palette.surface("paint"), 0.12)
	b.box(Vector3(23.5, 0.06, 0.03), Vector3(-6, 0.55, -1.2), Color("ffca28"))
	b.build(_locked_zone)
	Palette.label3d(_locked_zone, "Khu mở rộng (Xây dựng → Mở rộng xưởng)", Vector3(-6, 1.4, 1.8), 30, Color("ffe082"))
	return n


func _build_sales_office() -> Node3D:
	var n := Node3D.new()
	add_child(n)
	var b := MeshBatch.new()
	var paint := Palette.surface("paint")
	var screen := Palette.surface("screen")
	var a := FactoryLayout.SALES_OFFICE_MIN
	var e := FactoryLayout.SALES_OFFICE_MAX
	_floor(b, a, e, Color("9fb0bb"))
	_room_walls(b, a, e, "e", -10.8, -8.8)
	for i in 2:
		var z := -11.6 + i * 2.8
		b.box(Vector3(1.5, 0.05, 0.9), Vector3(-22.2, 0.74, z), Color("d7ccc8"))
		b.box(Vector3(1.4, 0.7, 0.05), Vector3(-22.85, 0.36, z), Color("8d6e63"))
		for dz in [-0.4, 0.4]:
			b.box(Vector3(1.4, 0.7, 0.04), Vector3(-22.2, 0.36, z + dz), Color("8d6e63"))
		b.box(Vector3(0.05, 0.4, 0.65), Vector3(-22.7, 1.04, z), Color("1d2125"), paint)
		b.box(Vector3(0.01, 0.34, 0.58), Vector3(-22.67, 1.04, z), Color("4fc3f7"), screen)
		b.box(Vector3(0.18, 0.02, 0.45), Vector3(-22.35, 0.77, z), Color("2a2e33"))
		_person(n, Vector3(-21.4, 0, z), Color("5c6bc0"), -PI / 2, true)
	b.box(Vector3(1.0, 1.6, 0.5), Vector3(-20.0, 0.8, -12.4), Color("90a4ae"), paint)
	b.box(Vector3(0.9, 0.6, 0.02), Vector3(-20.6, 1.5, -12.65), Color("f5f5f5"))
	b.cylinder(0.3, 0.6, Vector3(-20.0, 0.3, -6.7), Color("b07a54"), null, 0.34)
	for k in 4:
		var ang := k * TAU / 4.0
		b.sphere(0.32, Vector3(-20.0 + cos(ang) * 0.18, 1.0 + (k % 2) * 0.15, -6.7 + sin(ang) * 0.18), Color("43a047").darkened(0.08 * k), null, Vector3(1, 1.3, 1), 8, 5)
	b.build(n)
	Palette.label3d(n, "Phòng kinh doanh", Vector3(-21.2, 2.4, -9.5), 34)
	return n


func _build_break_room() -> Node3D:
	var n := Node3D.new()
	add_child(n)
	var b := MeshBatch.new()
	var paint := Palette.surface("paint")
	var a := FactoryLayout.BREAK_ROOM_MIN
	var e := FactoryLayout.BREAK_ROOM_MAX
	_floor(b, a, e, Color("c9b8a6"))
	_room_walls(b, a, e, "e", -1.5, 1.5)
	b.cylinder(0.8, 0.05, Vector3(-21.6, 0.74, 1.0), Color("eceff1"), paint, -1.0, Vector3.ZERO, 20)
	b.cylinder(0.07, 0.72, Vector3(-21.6, 0.36, 1.0), Color("6d747a"), Palette.surface("steel"), -1.0, Vector3.ZERO, 8)
	for k in 4:
		var ang := k * PI / 2.0
		var c := Vector3(-21.6 + cos(ang) * 1.15, 0, 1.0 + sin(ang) * 1.15)
		b.cylinder(0.22, 0.06, c + Vector3(0, 0.45, 0), Color("ef6c00"), paint, -1.0, Vector3.ZERO, 12)
		b.cylinder(0.03, 0.43, c + Vector3(0, 0.215, 0), Color("6d747a"), Palette.surface("steel"), -1.0, Vector3.ZERO, 6)
	# Vending machine, sofa and a fridge
	b.box(Vector3(0.8, 1.9, 0.7), Vector3(-23.0, 0.95, 2.4), Color("c62828"), paint)
	b.box(Vector3(0.6, 0.12, 0.05), Vector3(-22.58, 1.75, 2.4), Color("eceff1"), Palette.surface("screen"), Vector3(0, PI / 2, 0))
	b.box(Vector3(0.9, 0.5, 2.2), Vector3(-23.0, 0.25, -1.6), Color("5d4037"))
	b.box(Vector3(0.3, 0.5, 2.2), Vector3(-23.3, 0.7, -1.6), Color("5d4037"))
	for k in 2:
		b.box(Vector3(0.75, 0.15, 1.0), Vector3(-22.95, 0.55, -2.15 + k * 1.1), Color("795548"))
	b.box(Vector3(0.5, 0.9, 0.5), Vector3(-19.6, 0.45, -2.5), Color("eceff1"), paint)
	b.box(Vector3(0.02, 0.3, 0.02), Vector3(-19.33, 0.6, -2.35), Color("90a4ae"), Palette.surface("steel"))
	b.build(n)
	var glow := Palette.box(n, Vector3(0.05, 1.2, 0.5), Vector3(-22.58, 1.0, 2.4), Color("ffecb3"))
	glow.material_override = Palette.mat(Color("ffecb3"), 1.5)
	Palette.label3d(n, "Phòng nghỉ", Vector3(-21.2, 2.4, 0), 34)
	return n


func _build_solar_canopy() -> Node3D:
	var n := Node3D.new()
	add_child(n)
	var b := MeshBatch.new()
	var steel := Palette.surface("steel")
	var a := FactoryLayout.PARKING_MIN
	var e := FactoryLayout.PARKING_MAX
	for x in range(int(a.x) + 1, int(e.x), 4):
		for z in [a.y + 0.5, e.y - 1.0]:
			b.box(Vector3(0.18, 3.0, 0.18), Vector3(x, 1.5, z), Color("b0bec5"), steel)
		b.box(Vector3(0.14, 0.2, e.y - a.y - 1.0), Vector3(x, 3.0, (a.y + e.y) / 2.0 - 0.25), Color("90a4ae"), steel)
	var cells := Palette.surface("solar")
	for row in 2:
		var zc := a.y + 1.6 + row * 2.7
		b.box(Vector3(e.x - a.x, 0.08, 2.6), Vector3((a.x + e.x) / 2.0, 3.12, zc), Color("1b2f52"), cells, Vector3(-0.2, 0, 0))
		for k in 7:
			b.box(Vector3(0.04, 0.1, 2.6), Vector3(a.x + 0.1 + k * (e.x - a.x - 0.2) / 6.0, 3.13, zc), Color("cfd8dc"), steel, Vector3(-0.2, 0, 0))
		b.box(Vector3(e.x - a.x, 0.1, 0.04), Vector3((a.x + e.x) / 2.0, 3.13, zc), Color("cfd8dc"), steel, Vector3(-0.2, 0, 0))
	b.build(n)
	Palette.label3d(n, "Điện mặt trời", Vector3((a.x + e.x) / 2.0, 4.4, (a.y + e.y) / 2.0), 34, Color("fff59d"))
	return n
