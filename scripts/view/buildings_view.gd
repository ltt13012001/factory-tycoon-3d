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
	# Scaffolding poles and rails
	var poles_x := maxi(2, ceili(size.x / 3.0) + 1)
	var poles_z := maxi(2, ceili(size.y / 3.0) + 1)
	for ix in poles_x:
		for iz in poles_z:
			if ix != 0 and ix != poles_x - 1 and iz != 0 and iz != poles_z - 1:
				continue
			var p := Vector3(min_c.x + size.x * ix / (poles_x - 1), h / 2.0 + 0.3, min_c.y + size.y * iz / (poles_z - 1))
			Palette.box(_site, Vector3(0.1, h + 0.6, 0.1), p, SCAFFOLD)
	var levels := maxi(1, int(h / 1.2))
	for l in levels + 1:
		var y := 0.3 + (h + 0.3) * l / levels
		Palette.box(_site, Vector3(size.x, 0.08, 0.08), Vector3(c.x, y, min_c.y), SCAFFOLD)
		Palette.box(_site, Vector3(size.x, 0.08, 0.08), Vector3(c.x, y, max_c.y), SCAFFOLD)
		Palette.box(_site, Vector3(0.08, 0.08, size.y), Vector3(min_c.x, y, c.y), SCAFFOLD)
		Palette.box(_site, Vector3(0.08, 0.08, size.y), Vector3(max_c.x, y, c.y), SCAFFOLD)
	# Barrier cones at the corners and a pile of materials
	for corner in [min_c, Vector2(max_c.x, min_c.y), Vector2(min_c.x, max_c.y), max_c]:
		Palette.cylinder(_site, 0.22, 0.6, Vector3(corner.x, 0.3, corner.y), Color("ff6d00"), 0.03)
	Palette.box(_site, Vector3(1.2, 0.4, 0.8), Vector3(min_c.x + 0.9, 0.2, max_c.y - 0.7), Color("9e9e9e"))
	Palette.box(_site, Vector3(1.4, 0.15, 0.5), Vector3(min_c.x + 0.9, 0.48, max_c.y - 0.7), Color("a1887f"))
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

func _floor(parent: Node3D, min_c: Vector2, max_c: Vector2, color: Color, h: float = 0.07) -> void:
	var size := max_c - min_c
	var c := (max_c + min_c) / 2.0
	Palette.box(parent, Vector3(size.x, h, size.y), Vector3(c.x, h / 2.0, c.y), color)


## Low cut-away walls on the four sides, with one doorway gap.
func _room_walls(parent: Node3D, min_c: Vector2, max_c: Vector2, door_side: String, door_from: float, door_to: float) -> void:
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
		var b: Vector2 = sides[side][1]
		var horizontal: bool = side == "n" or side == "s"
		var spans := [[a.x, b.x]] if horizontal else [[a.y, b.y]]
		if side == door_side:
			spans = [[spans[0][0], door_from], [door_to, spans[0][1]]]
		for span in spans:
			var l: float = span[1] - span[0]
			if l <= 0.05:
				continue
			var mid: float = (span[0] + span[1]) / 2.0
			var pos := Vector3(mid, height / 2.0, a.y) if horizontal else Vector3(a.x, height / 2.0, mid)
			var size := Vector3(l, height, t) if horizontal else Vector3(t, height, l)
			Palette.box(parent, size, pos, Palette.WALL)
			Palette.box(parent, Vector3(size.x + 0.04, 0.12, size.z + 0.04), pos + Vector3(0, height / 2.0, 0), Palette.WALL_TRIM)


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
	_floor(n, FactoryLayout.PARKING_MIN, FactoryLayout.PARKING_MAX, Color("50555c"), 0.04)
	for i in 7:
		var x := FactoryLayout.PARKING_MIN.x + 1.0 + i * 2.0
		Palette.box(n, Vector3(0.1, 0.05, 2.6), Vector3(x, 0.05, 8.9), Color("eeeeee"))
	Palette.label3d(n, "Bãi đỗ xe", Vector3(-4.5, 1.2, 12), 32)
	# Staff cars
	var colors := [Color("d32f2f"), Color("eceff1"), Color("1976d2"), Color("455a64")]
	for i in colors.size():
		_car(n, Vector3(FactoryLayout.PARKING_MIN.x + 2.0 + i * 4.0, 0, 9.0), PI, colors[i])


static func _car(parent: Node3D, pos: Vector3, yaw: float, color: Color) -> Node3D:
	var car := Node3D.new()
	car.position = pos
	car.rotation.y = yaw
	parent.add_child(car)
	Palette.box(car, Vector3(1.6, 0.55, 3.4), Vector3(0, 0.55, 0), color)
	Palette.box(car, Vector3(1.4, 0.5, 1.8), Vector3(0, 1.05, -0.2), color.darkened(0.1))
	Palette.box(car, Vector3(1.42, 0.38, 1.6), Vector3(0, 1.07, -0.2), Color("90caf9"))
	for x in [-0.8, 0.8]:
		for z in [-1.1, 1.1]:
			var w := Palette.cylinder(car, 0.32, 0.25, Vector3(x, 0.32, z), Color("212121"))
			w.rotation.z = PI / 2
	return car


func _build_annex() -> Node3D:
	var n := Node3D.new()
	add_child(n)
	var min_c := Vector2(20.0, FactoryLayout.ANNEX_MIN.y)
	_floor(n, min_c, FactoryLayout.ANNEX_MAX, Color("9fb4c9"))
	_room_walls(n, min_c, FactoryLayout.ANNEX_MAX, "w", 0, 0)
	# Pallet racks: blue uprights, orange beams, four levels
	for half in [[-12.0, -4.0], [-4.0, 4.0]]:
		for x in [20.7, 23.3]:
			for z in [half[0] + 0.3, (half[0] + half[1]) / 2.0, half[1] - 0.3]:
				Palette.box(n, Vector3(0.1, 3.5, 0.1), Vector3(x, 1.75, z), Color("1e5aa8"))
		for level in 4:
			var y := 0.06 + level * 0.85
			if level > 0:
				Palette.box(n, Vector3(2.7, 0.06, half[1] - half[0] - 0.6), Vector3(22.0, y, (half[0] + half[1]) / 2.0), Color("e67e22"))
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
	_floor(_locked_zone, Vector2(-17.8, -1.2), Vector2(5.8, 4.8), Color("8e8a83"), 0.08)
	for i in 12:
		var x := -17 + i * 2.0
		var stripe := Palette.box(_locked_zone, Vector3(0.35, 0.1, 6.0), Vector3(x, 0.05, 1.8), Color("6f6b64"))
		stripe.rotation.y = 0.5
	for x in range(-17, 6, 3):
		Palette.cylinder(_locked_zone, 0.2, 0.6, Vector3(x, 0.3, -1.2), Color("ff6d00"), 0.03)
	Palette.box(_locked_zone, Vector3(23.5, 0.08, 0.08), Vector3(-6, 0.55, -1.2), Color("ffca28"))
	Palette.label3d(_locked_zone, "Khu mở rộng (Xây dựng → Mở rộng xưởng)", Vector3(-6, 1.4, 1.8), 30, Color("ffe082"))
	return n


func _build_sales_office() -> Node3D:
	var n := Node3D.new()
	add_child(n)
	var a := FactoryLayout.SALES_OFFICE_MIN
	var b := FactoryLayout.SALES_OFFICE_MAX
	_floor(n, a, b, Color("b0bec5"))
	_room_walls(n, a, b, "e", -10.8, -8.8)
	for i in 2:
		var z := -11.6 + i * 2.8
		Palette.box(n, Vector3(1.5, 0.75, 0.9), Vector3(-22.2, 0.38, z), Color("8d6e63"))
		Palette.box(n, Vector3(0.06, 0.45, 0.7), Vector3(-22.7, 1.0, z), Color("263238"))
		Palette.box(n, Vector3(0.03, 0.38, 0.6), Vector3(-22.66, 1.0, z), Color("4fc3f7"))
		_person(n, Vector3(-21.4, 0, z), Color("5c6bc0"), -PI / 2, true)
	Palette.box(n, Vector3(1.0, 1.6, 0.5), Vector3(-20.0, 0.8, -12.4), Color("90a4ae"))
	Palette.cylinder(n, 0.3, 0.6, Vector3(-20.0, 0.3, -6.7), Color("6d4c41"))
	Palette.sphere(n, 0.5, Vector3(-20.0, 1.0, -6.7), Color("43a047"))
	Palette.label3d(n, "Phòng kinh doanh", Vector3(-21.2, 2.4, -9.5), 34)
	return n


func _build_break_room() -> Node3D:
	var n := Node3D.new()
	add_child(n)
	var a := FactoryLayout.BREAK_ROOM_MIN
	var b := FactoryLayout.BREAK_ROOM_MAX
	_floor(n, a, b, Color("d7ccc8"))
	_room_walls(n, a, b, "e", -1.5, 1.5)
	Palette.cylinder(n, 0.8, 0.75, Vector3(-21.6, 0.38, 1.0), Color("a1887f"))
	for k in 4:
		var ang := k * PI / 2.0
		Palette.cylinder(n, 0.22, 0.45, Vector3(-21.6 + cos(ang) * 1.15, 0.23, 1.0 + sin(ang) * 1.15), Color("ef6c00"))
	Palette.box(n, Vector3(0.8, 1.9, 0.7), Vector3(-23.0, 0.95, 2.4), Color("c62828"))
	var glow := Palette.box(n, Vector3(0.05, 1.2, 0.5), Vector3(-22.58, 1.2, 2.4), Color("ffecb3"))
	glow.material_override = Palette.mat(Color("ffecb3"), 1.5)
	Palette.box(n, Vector3(0.9, 0.5, 2.2), Vector3(-23.0, 0.25, -1.6), Color("5d4037"))
	Palette.box(n, Vector3(0.3, 0.5, 2.2), Vector3(-23.3, 0.7, -1.6), Color("5d4037"))
	Palette.box(n, Vector3(0.5, 0.9, 0.5), Vector3(-19.6, 0.45, -2.5), Color("eceff1"))
	Palette.label3d(n, "Phòng nghỉ", Vector3(-21.2, 2.4, 0), 34)
	return n


func _build_solar_canopy() -> Node3D:
	var n := Node3D.new()
	add_child(n)
	var a := FactoryLayout.PARKING_MIN
	var b := FactoryLayout.PARKING_MAX
	for x in range(int(a.x) + 1, int(b.x), 4):
		for z in [a.y + 0.5, b.y - 1.0]:
			Palette.box(n, Vector3(0.18, 3.0, 0.18), Vector3(x, 1.5, z), Color("b0bec5"))
	for row in 2:
		var panel := Palette.box(n, Vector3(b.x - a.x, 0.1, 2.6), Vector3((a.x + b.x) / 2.0, 3.1, a.y + 1.6 + row * 2.7), Color("1a3a6b"))
		panel.rotation.x = -0.2
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("1a3a6b")
		m.metallic = 0.6
		m.roughness = 0.25
		panel.material_override = m
		for k in 6:
			Palette.box(n, Vector3(0.05, 0.12, 2.6), Vector3(a.x + 1.0 + k * 2.4, 3.12, a.y + 1.6 + row * 2.7), Color("cfd8dc")).rotation.x = -0.2
	Palette.label3d(n, "Điện mặt trời", Vector3((a.x + b.x) / 2.0, 4.4, (a.y + b.y) / 2.0), 34, Color("fff59d"))
	return n
