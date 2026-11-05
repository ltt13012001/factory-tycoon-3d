## The branch itself, in the middle of its scenery: land for sale, a survey
## crew, a building site, or the finished plant (an open-topped hall with
## one production line per line bought, a warehouse, an office with the
## country's flag, trucks and staff). Rebuilt only when what it shows
## changes (see BranchView); the goods on the belts are one MultiMesh.
class_name BranchCompound
extends Node3D

const HALL_MIN := Vector2(-21, -14)
const HALL_MAX := Vector2(5, 6)
const LOT_MIN := Vector2(-24, -17)
const LOT_MAX := Vector2(24, 16)

var lamp_material: Material
var window_material: Material

var _paint := Palette.surface("paint")
var _steel := Palette.surface("steel")
var _paving := Palette.surface("paving")
var _goods: MultiMeshInstance3D
## Per running line: [belt start x, belt end x, z]
var _belts: Array[Vector3] = []
var _running := false
var _speed := 1.0
var _time := 0.0
var _label: Label3D


func build(sim: Simulation, l: LocationDef, s: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	_belts.clear()
	_goods = null
	var b := MeshBatch.new()
	var flat := MeshBatch.new()
	var status: String = "" if s.is_empty() else s.status
	match status:
		ExpansionManager.READY:
			_plant(b, flat, sim, l, s)
		ExpansionManager.BUILDING:
			_lot(b, flat, true)
			_construction(b, flat, s)
		ExpansionManager.SURVEYED, ExpansionManager.LAND:
			_lot(b, flat, true)
			_stakes(b)
		ExpansionManager.SURVEYING:
			_lot(b, flat, false)
			_surveyors(b)
		_:
			_lot(b, flat, false)
			_for_sale(b)
	b.build(self)
	flat.build(self, false)
	Palette.label3d(self, l.display_name.to_upper(), Vector3(0, 15.5, 0), 64, Color.WHITE)
	_label = Palette.label3d(self, "", Vector3(0, 12.8, 0), 40, Color("ffe082"))
	update_label(sim, l, s)


func update_label(sim: Simulation, l: LocationDef, s: Dictionary) -> void:
	if _label == null:
		return
	var ex := sim.expansion
	var text := ""
	var color := Color("ffe082")
	var status: String = "" if s.is_empty() else s.status
	match status:
		"":
			var reason := ex.block_reason(l.id)
			text = "Đất dự kiến · %s" % ("bấm Mở rộng để khảo sát" if reason == "" else reason)
		ExpansionManager.SURVEYING:
			text = "Đang khảo sát thị trường"
		ExpansionManager.SURVEYED, ExpansionManager.LAND:
			text = "Đã khảo sát · sức mua %d%%" % int(s.market)
		ExpansionManager.BUILDING:
			text = "Đang xây %d%%" % (100 - int(s.ticks_left) * 100 / maxi(1, int(s.total_ticks)))
		ExpansionManager.READY:
			text = "%d/%d dây chuyền · %d công nhân" % [int(s.lines), l.max_lines, ex.workers(s)]
			if s.head == "":
				text += " · chưa có giám đốc, chưa sản xuất"
				color = Color("ffab91")
			else:
				text = "%s · %s · lãi %s/ngày" % [s.head, text, Fmt.money(ex.daily_income(s) - ex.daily_cost(s))]
				color = Color("b9f6ca")
	_label.text = text
	_label.modulate = color


func _process(delta: float) -> void:
	if _goods == null or not _running or TimeManager.speed == 0:
		return
	_time += delta * minf(2.0, float(TimeManager.speed)) * _speed
	var mm := _goods.multimesh
	var i := 0
	for belt in _belts:
		var length := belt.y - belt.x
		for k in 4:
			var x := belt.x + fmod(_time * 1.3 + k * length / 4.0, length)
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(x, 1.13, belt.z)))
			i += 1


# --- Land, survey, building site ---------------------------------------------------

func _lot(b: MeshBatch, flat: MeshBatch, fenced: bool) -> void:
	if fenced:
		flat.box(Vector3(LOT_MAX.x - LOT_MIN.x, 0.05, LOT_MAX.y - LOT_MIN.y), Vector3(0, 0.03, (LOT_MIN.y + LOT_MAX.y) / 2.0), Color("b8b2a4"), _paving)
		_fence(b)
	flat.box(Vector3(8.0, 0.06, 2.6), Vector3(14.0, 0.035, 17.4), Color("6d7177"), _paving)


func _fence(b: MeshBatch) -> void:
	var post := Color("8d969d")
	var x := LOT_MIN.x
	while x <= LOT_MAX.x:
		b.box(Vector3(0.1, 1.8, 0.1), Vector3(x, 0.9, LOT_MIN.y), post, _steel)
		if x < 10.0 or x > 18.0:
			b.box(Vector3(0.1, 1.8, 0.1), Vector3(x, 0.9, LOT_MAX.y), post, _steel)
		x += 3.0
	var z := LOT_MIN.y
	while z <= LOT_MAX.y:
		for sx in [LOT_MIN.x, LOT_MAX.x]:
			b.box(Vector3(0.1, 1.8, 0.1), Vector3(sx, 0.9, z), post, _steel)
		z += 3.0
	var w := LOT_MAX.x - LOT_MIN.x
	var d := LOT_MAX.y - LOT_MIN.y
	b.box(Vector3(w, 0.06, 0.04), Vector3(0, 1.7, LOT_MIN.y), post, _steel)
	b.box(Vector3(10.0 - LOT_MIN.x, 0.06, 0.04), Vector3((LOT_MIN.x + 10.0) / 2.0, 1.7, LOT_MAX.y), post, _steel)
	b.box(Vector3(LOT_MAX.x - 18.0, 0.06, 0.04), Vector3((LOT_MAX.x + 18.0) / 2.0, 1.7, LOT_MAX.y), post, _steel)
	for sx in [LOT_MIN.x, LOT_MAX.x]:
		b.box(Vector3(0.04, 0.06, d), Vector3(sx, 1.7, (LOT_MIN.y + LOT_MAX.y) / 2.0), post, _steel)


func _for_sale(b: MeshBatch) -> void:
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var p := Vector3(c.x * 22.0, 0, c.y * 15.0)
		b.box(Vector3(0.15, 1.0, 0.15), p + Vector3(0, 0.5, 0), Color("eceff1"), _paint)
		b.box(Vector3(0.18, 0.2, 0.18), p + Vector3(0, 0.9, 0), Color("d32f2f"), _paint)
	var board := Vector3(14.0, 0, 15.0)
	for x in [-1.6, 1.6]:
		b.box(Vector3(0.14, 3.0, 0.14), board + Vector3(x, 1.5, 0), Color("6d4c41"))
	b.box(Vector3(3.8, 1.6, 0.1), board + Vector3(0, 2.4, 0), Color("f9a825"), _paint)
	b.box(Vector3(3.5, 1.3, 0.11), board + Vector3(0, 2.4, 0), Color("fff8e1"), _paint)


func _stakes(b: MeshBatch) -> void:
	for x in [-20.0, 4.0, 20.0]:
		for z in [-14.0, 6.0]:
			b.box(Vector3(0.12, 0.8, 0.12), Vector3(x, 0.4, z), Color("ff7043"), _paint)
	b.box(Vector3(40.0, 0.02, 0.06), Vector3(0, 0.75, -14.0), Color("ff7043"))
	b.box(Vector3(40.0, 0.02, 0.06), Vector3(0, 0.75, 6.0), Color("ff7043"))
	b.box(Vector3(2.4, 0.9, 1.4), Vector3(14.0, 0.45, 11.0), Color("eceff1"), _paint)  # site container
	b.box(Vector3(6.0, 2.6, 2.4), Vector3(14.0, 1.3, 11.0), Color("1565c0"), _paint)


func _surveyors(b: MeshBatch) -> void:
	# Two surveyors with a total station on a tripod and a ranging pole.
	for p in [Vector3(-6, 0, 2), Vector3(8, 0, -6)]:
		for k in 3:
			var a := k * TAU / 3.0
			b.bar(p + Vector3(cos(a) * 0.5, 0, sin(a) * 0.5), p + Vector3(0, 1.4, 0), 0.04, Color("f9a825"), _paint)
		b.box(Vector3(0.3, 0.3, 0.3), p + Vector3(0, 1.6, 0), Color("ffca28"), _paint)
		b.box(Vector3(0.4, 0.7, 0.26), p + Vector3(0.8, 1.05, 0.4), Color("ff7043"))
		b.sphere(0.16, p + Vector3(0.8, 1.55, 0.4), Color("e3b08a"))
		b.cylinder(0.3, 0.15, p + Vector3(0.8, 1.7, 0.4), Color("fdd835"), _paint, 0.0, Vector3.ZERO, 10)
	b.box(Vector3(0.06, 2.6, 0.06), Vector3(1, 1.3, -2), Color("d32f2f"), _paint)
	BuildingsView._car(self, Vector3(14.0, 0, 11.0), PI / 2, Color("eceff1"), lamp_material)


const BuildingsView := preload("res://scripts/view/buildings_view.gd")


func _construction(b: MeshBatch, flat: MeshBatch, s: Dictionary) -> void:
	var progress := 100 - int(s.ticks_left) * 100 / maxi(1, int(s.total_ticks))
	var lo := HALL_MIN
	var hi := HALL_MAX
	flat.box(Vector3(hi.x - lo.x, 0.3, hi.y - lo.y), Vector3((lo.x + hi.x) / 2.0, 0.15, (lo.y + hi.y) / 2.0), Color("9e9e9e"), _paving)
	var h := 7.0 * clampf(progress / 60.0, 0.15, 1.0)
	var x := lo.x
	while x <= hi.x + 0.1:
		for z in [lo.y, hi.y]:
			b.box(Vector3(0.4, h, 0.4), Vector3(x, 0.3 + h / 2.0, z), Color("e65100"), _paint)
		if progress >= 60:
			b.box(Vector3(0.3, 0.45, hi.y - lo.y), Vector3(x, 7.3, (lo.y + hi.y) / 2.0), Color("e65100"), _paint)
		x += 6.5
	if progress >= 80:
		for z in [lo.y, hi.y]:
			b.box(Vector3(hi.x - lo.x, 3.0, 0.15), Vector3((lo.x + hi.x) / 2.0, 1.8, z), Color("cfd8dc"), _steel)
	# Office going up next door: scaffolding round a concrete frame.
	var oh := 6.0 * clampf(progress / 100.0, 0.2, 1.0)
	b.box(Vector3(12.0, oh, 7.0), Vector3(15.0, oh / 2.0, 8.0), Color("b0b5b8"), _paving)
	for sx in [8.6, 21.4]:
		for sz in [4.2, 11.8]:
			b.box(Vector3(0.08, oh + 1.5, 0.08), Vector3(sx, (oh + 1.5) / 2.0, sz), Color("8d969d"), _steel)
	# Tower crane
	var c := Vector3(-24.0, 0, -18.0)
	b.box(Vector3(1.1, 22.0, 1.1), c + Vector3(0, 11.0, 0), Color("fbc02d"), _paint)
	b.box(Vector3(20.0, 0.7, 0.7), c + Vector3(7.0, 22.4, 0), Color("fbc02d"), _paint)
	b.box(Vector3(2.4, 1.4, 1.4), c + Vector3(-3.2, 21.8, 0), Color("616161"), _steel)
	b.bar(c + Vector3(13.0, 22.0, 0), c + Vector3(13.0, 12.0, 0), 0.05, Color("424242"))
	b.box(Vector3(2.0, 0.4, 0.4), c + Vector3(13.0, 11.8, 0), Color("e65100"), _paint)
	for k in 4:
		Palette.pallet(b, Vector3(-4.0 + k * 1.6, 0.3, 11.0))
		b.box(Vector3(1.0, 0.5, 1.0), Vector3(-4.0 + k * 1.6, 0.7, 11.0), Color("90a4ae"), _steel)
	for k in 3:
		var p := Vector3(-14.0 + k * 6.0, 0.3, 8.5)
		b.box(Vector3(0.4, 0.75, 0.26), p + Vector3(0, 1.0, 0), Color("ff7043"))
		b.sphere(0.16, p + Vector3(0, 1.55, 0), Color("e3b08a"))
		b.cylinder(0.3, 0.15, p + Vector3(0, 1.72, 0), Color("fdd835"), _paint, 0.0, Vector3.ZERO, 10)


# --- The finished plant -----------------------------------------------------------

func _plant(b: MeshBatch, flat: MeshBatch, sim: Simulation, l: LocationDef, s: Dictionary) -> void:
	_lot(b, flat, true)
	var abroad := l.region == ExpansionManager.ABROAD
	var accent := Color("1565c0") if not abroad else Color("00897b")
	_hall(b, flat, accent)
	_lines(b, flat, l, s, accent, sim.expansion.staffed_lines(s), sim.expansion.crew_per_line(s))
	_warehouse(b, flat)
	_office(b, l, s)
	_yard(b, flat)
	# Automation: one storage silo per level behind the hall.
	for k in int(s.automation):
		var p := Vector3(-17.0 + k * 4.2, 0, -15.6)
		b.cylinder(1.0, 6.0, p + Vector3(0, 3.0, 0), Color("dfe3e6"), _steel, -1.0, Vector3.ZERO, 14)
		b.sphere(1.0, p + Vector3(0, 6.0, 0), Color("cfd4d8"), _steel, Vector3(1, 0.5, 1), 12, 6)
		b.bar(p + Vector3(0, 5.5, 0.9), p + Vector3(0, 5.5, 1.6) + Vector3(0, 0, 0), 0.18, Color("90a4ae"), _steel, true)


func _hall(b: MeshBatch, flat: MeshBatch, accent: Color) -> void:
	var wall := Color("dfe0dc")
	var trim := Color("37474f")
	var lo := HALL_MIN
	var hi := HALL_MAX
	var w := hi.x - lo.x
	var d := hi.y - lo.y
	var c := Vector3((lo.x + hi.x) / 2.0, 0, (lo.y + hi.y) / 2.0)
	flat.box(Vector3(w, 0.06, d), c + Vector3(0, 0.07, 0), Color("aab0ae"), Palette.surface("floor"))
	# Tall back wall with a band of windows and the company stripe; side
	# walls; a low front wall so the camera sees the lines inside.
	b.box(Vector3(w, 7.0, 0.3), Vector3(c.x, 3.5, lo.y), wall, _paint)
	b.box(Vector3(w + 0.1, 0.8, 0.34), Vector3(c.x, 6.2, lo.y), accent, _paint)
	for i in 6:
		b.box(Vector3(3.0, 1.3, 0.05), Vector3(lo.x + 2.6 + i * 4.2, 4.3, lo.y + 0.17), Color("8fb6d6"), window_material)
	for side in [-1, 1]:
		b.box(Vector3(0.3, 3.2, d), Vector3(c.x + side * w / 2.0, 1.6, c.z), wall, _paint)
		b.box(Vector3(0.34, 0.3, d), Vector3(c.x + side * w / 2.0, 3.2, c.z), accent, _paint)
	b.box(Vector3(w - 5.0, 1.2, 0.3), Vector3(c.x - 2.5, 0.6, hi.y), wall, _paint)
	b.box(Vector3(0.4, 1.5, 0.4), Vector3(hi.x - 5.0, 0.75, hi.y), trim, _paint)
	# Walkway marking along the front
	flat.box(Vector3(w - 1.0, 0.012, 1.2), Vector3(c.x, 0.11, hi.y - 1.0), Color("4f9a63"))


func _lines(b: MeshBatch, flat: MeshBatch, l: LocationDef, s: Dictionary, accent: Color, staffed: int, crew_size: int) -> void:
	var rows := int(ceil(l.max_lines / 2.0))
	var gap := minf(3.0, 18.0 / rows)
	var lines := int(s.lines)
	var auto := int(s.automation)
	var running: bool = s.head != ""
	var bodies := [Color("3d7cc9"), Color("2e9e8f"), Color("5c6bc0")]
	var shirts := [Color("1565c0"), Color("f57c00"), Color("2e7d32")]
	for i in l.max_lines:
		var col := i % 2
		var row := i / 2
		var x0 := HALL_MIN.x + 1.6 + col * 12.6
		var x1 := x0 + 10.6
		var z := HALL_MIN.y + 1.6 + row * gap
		if i >= lines:
			for zz in [z - 0.9, z + 0.9]:
				flat.box(Vector3(x1 - x0, 0.02, 0.1), Vector3((x0 + x1) / 2.0, 0.11, zz), Color("e3b51f"))
			for xx in [x0, x1]:
				flat.box(Vector3(0.1, 0.02, 1.8), Vector3(xx, 0.11, z), Color("e3b51f"))
			continue
		var body: Color = bodies[(i / 2) % bodies.size()]
		# Moulding machine: body, hopper, control panel with a status light
		b.box(Vector3(2.6, 1.5, 1.3), Vector3(x0 + 1.3, 0.85, z), body, _paint)
		b.box(Vector3(2.6, 0.12, 1.32), Vector3(x0 + 1.3, 1.62, z), accent.darkened(0.3), _paint)
		b.cylinder(0.32, 0.8, Vector3(x0 + 0.6, 2.05, z), Color("cfd8dc"), _steel, 0.12, Vector3.ZERO, 10)
		b.box(Vector3(0.5, 0.6, 0.08), Vector3(x0 + 2.0, 1.2, z + 0.69), Color("263238"), Palette.surface("screen"))
		var light := Palette.STATUS_RUN if running else Palette.STATUS_WARN
		b.sphere(0.09, Vector3(x0 + 2.4, 1.9, z + 0.4), light, Palette.mat(light, 1.6), Vector3.ONE, 6, 4)
		# Conveyor on legs with rollers, then the packing station
		var bs := x0 + 2.7
		var be := x1 - 1.5
		b.box(Vector3(be - bs, 0.14, 0.7), Vector3((bs + be) / 2.0, 0.98, z), Color("2b3440"), Palette.surface("rubber"))
		for side in [-0.38, 0.38]:
			b.box(Vector3(be - bs, 0.12, 0.06), Vector3((bs + be) / 2.0, 1.05, z + side), Color("9aa5ad"), _steel)
		var lx := bs + 0.5
		while lx < be:
			for side in [-0.33, 0.33]:
				b.box(Vector3(0.06, 0.9, 0.06), Vector3(lx, 0.45, z + side), Color("9aa5ad"), _steel)
			lx += 2.0
		b.box(Vector3(1.3, 1.3, 1.3), Vector3(x1 - 0.75, 0.75, z), Color("eceff1"), _paint)
		Palette.pallet(b, Vector3(x1 - 0.75, 0.08, z + 1.0 if row < rows - 1 else z - 1.0), Vector2(1.0, 0.6))
		_belts.append(Vector3(bs, be, z))
		# Robot arm at the machine from automation level 2.
		if auto >= 2:
			var r := Vector3(x0 + 2.9, 0, z - 0.75)
			b.cylinder(0.25, 0.5, r + Vector3(0, 0.25, 0), Color("f57c00"), _paint, -1.0, Vector3.ZERO, 10)
			b.bar(r + Vector3(0, 0.5, 0), r + Vector3(0.2, 1.6, 0.1), 0.18, Color("f57c00"), _paint, true)
			b.bar(r + Vector3(0.2, 1.6, 0.1), r + Vector3(-0.4, 1.4, 0.7), 0.14, Color("f57c00"), _paint, true)
		# The branch's factory workers: a full crew on each staffed line;
		# the other lines run on their machines alone.
		var crew := crew_size if i < staffed else 0
		for k in crew:
			var p := Vector3(x0 + 1.2 + k * 6.0, 0.08, z + 0.85)
			_person(b, p, shirts[k], PI, Color("ffd23f"))
	_running = running
	_speed = 1.0 + auto * 0.2
	if not _belts.is_empty():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var box := MeshBatch.new()
		box.box(Vector3(0.42, 0.3, 0.42), Vector3.ZERO, Color("c8a46e"))
		mm.mesh = box.build_mesh()
		mm.instance_count = _belts.size() * 4
		var i := 0
		for belt in _belts:
			for k in 4:
				mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(belt.x + k * (belt.y - belt.x) / 4.0, 1.13, belt.z)))
				i += 1
		_goods = MultiMeshInstance3D.new()
		_goods.multimesh = mm
		add_child(_goods)


func _person(b: MeshBatch, p: Vector3, shirt: Color, yaw: float, hat: Color) -> void:
	var o := b.origin
	b.origin = Transform3D(Basis(Vector3.UP, yaw), p)
	for sx in [-0.11, 0.11]:
		b.box(Vector3(0.14, 0.75, 0.16), Vector3(sx, 0.38, 0), Color("37474f"))
	b.box(Vector3(0.42, 0.55, 0.26), Vector3(0, 1.03, 0), shirt)
	b.sphere(0.17, Vector3(0, 1.48, 0), Color("e3b08a"), null, Vector3.ONE, 8, 5)
	b.sphere(0.2, Vector3(0, 1.56, 0), hat, _paint, Vector3(1, 0.75, 1), 8, 4)
	b.origin = o


func _warehouse(b: MeshBatch, flat: MeshBatch) -> void:
	var c := Vector3(15.0, 0, -8.0)
	var size := Vector3(14.0, 7.5, 12.0)
	b.box(size, c + Vector3(0, size.y / 2.0, 0), Color("cfd6dc"), _paint)
	# Ribbed cladding and a shallow pitched roof
	for k in 15:
		b.box(Vector3(0.12, size.y - 0.4, 0.06), c + Vector3(-size.x / 2.0 + 0.5 + k * 0.93, size.y / 2.0, size.z / 2.0 + 0.03), Color("b9c2c9"), _steel)
	b.prism(Vector3(size.x + 0.6, 1.2, size.z + 0.6), c + Vector3(0, size.y + 0.6, 0), Color("6b7782"), _steel, 0.5, Vector3(0, PI / 2, 0))
	# Two roller doors with a loading dock
	for x in [-3.2, 3.2]:
		b.box(Vector3(3.6, 4.2, 0.08), c + Vector3(x, 2.1, size.z / 2.0 + 0.05), Color("78909c"), _steel)
		for k in 10:
			b.box(Vector3(3.6, 0.04, 0.1), c + Vector3(x, 0.3 + k * 0.4, size.z / 2.0 + 0.08), Color("607d8b"))
	b.box(Vector3(size.x, 1.0, 1.6), c + Vector3(0, 0.5, size.z / 2.0 + 0.8), Color("9e9e9e"), _paving)
	# A truck backed up to the dock
	var m := MeshBatch.new()
	m.box(Vector3(2.4, 2.8, 6.5), Vector3(0, 2.0, -1.4), Color("eceff1"), _paint)
	m.box(Vector3(2.3, 2.2, 2.0), Vector3(0, 1.6, 3.0), Color("c62828"), _paint)
	for z in [-3.4, -1.8, 3.0]:
		for x in [-1.05, 1.05]:
			m.cylinder(0.48, 0.35, Vector3(x, 0.48, z), Color("17181a"), Palette.surface("rubber"), -1.0, Vector3(0, 0, PI / 2), 12)
	var t := Node3D.new()
	t.position = c + Vector3(-3.2, 0, size.z / 2.0 + 5.3)
	add_child(t)
	m.build(t)
	flat.box(Vector3(size.x, 0.012, 0.15), c + Vector3(0, 0.08, size.z / 2.0 + 9.0), Color("f2f2ee"))


func _office(b: MeshBatch, l: LocationDef, s: Dictionary) -> void:
	var c := Vector3(15.0, 0, 8.5)
	var size := Vector3(14.0, 6.6, 6.0)
	b.box(size, c + Vector3(0, size.y / 2.0, 0), Color("eef0f1"), _paint)
	# Glass curtain wall in front, two floors of windows
	for f in 2:
		b.box(Vector3(size.x - 1.0, 2.2, 0.06), c + Vector3(0, 1.6 + f * 3.1, size.z / 2.0 + 0.03), Color("8fb6d6"), window_material)
		b.box(Vector3(size.x, 0.25, 0.3), c + Vector3(0, 2.95 + f * 3.1, size.z / 2.0 + 0.1), Color("37474f"), _paint)
	b.box(Vector3(size.x + 0.4, 0.4, size.z + 0.4), c + Vector3(0, size.y + 0.2, 0), Color("37474f"), _paint)
	# Company sign on the roof
	b.box(Vector3(8.0, 1.4, 0.2), c + Vector3(0, size.y + 1.3, 0), Color("1565c0"), _paint)
	b.box(Vector3(7.6, 1.0, 0.22), c + Vector3(0, size.y + 1.3, 0), Color("fff3c4"), lamp_material)
	# Flags: the country's and the company's, by the entrance.
	var pole := c + Vector3(-size.x / 2.0 - 1.5, 0, size.z / 2.0 + 1.0)
	for k in 2:
		var p := pole + Vector3(0, 0, -k * 1.6)
		b.cylinder(0.05, 6.0, p + Vector3(0, 3.0, 0), Color("cfd8dc"), _steel)
		if k == 0:
			_flag(b, l.country, p + Vector3(0.75, 5.4, 0))
		else:
			b.box(Vector3(1.4, 0.9, 0.03), p + Vector3(0.75, 5.4, 0), Color("1565c0"))
			b.box(Vector3(0.5, 0.5, 0.04), p + Vector3(0.75, 5.4, 0), Color("ffd23f"))
	if s.head != "":
		_person(b, c + Vector3(-2.0, 0.08, size.z / 2.0 + 1.6), Color("37474f"), 0.4, Color("2b2420"))


## Simple flags of the countries in the game, 1.4 x 0.9 m.
func _flag(b: MeshBatch, country: String, p: Vector3) -> void:
	var w := 1.4
	var h := 0.9
	var stripes_h := func(colors: Array) -> void:
		for i in colors.size():
			b.box(Vector3(w, h / colors.size(), 0.03), p + Vector3(0, h / 2.0 - (i + 0.5) * h / colors.size(), 0), colors[i])
	var stripes_v := func(colors: Array) -> void:
		for i in colors.size():
			b.box(Vector3(w / colors.size(), h, 0.03), p + Vector3(-w / 2.0 + (i + 0.5) * w / colors.size(), 0, 0), colors[i])
	match country:
		"Việt Nam":
			b.box(Vector3(w, h, 0.03), p, Color("da251d"))
			b.sphere(0.2, p + Vector3(0, 0, 0.02), Color("ffcd00"), null, Vector3(1, 1, 0.15), 5, 3)
		"Đức":
			stripes_h.call([Color("111111"), Color("dd0000"), Color("ffce00")])
		"Thái Lan":
			stripes_h.call([Color("a51931"), Color("f4f5f8"), Color("2d2a4a"), Color("2d2a4a"), Color("f4f5f8"), Color("a51931")])
		"Indonesia":
			stripes_h.call([Color("ce1126"), Color("ffffff")])
		"Ấn Độ":
			stripes_h.call([Color("ff9933"), Color("ffffff"), Color("138808")])
			b.cylinder(0.12, 0.01, p + Vector3(0, 0, 0.02), Color("000080"), null, -1.0, Vector3(PI / 2, 0, 0), 10)
		"Mexico":
			stripes_v.call([Color("006847"), Color("ffffff"), Color("ce1126")])
		"Hoa Kỳ":
			var reds := []
			for i in 7:
				reds.append(Color("b22234") if i % 2 == 0 else Color("ffffff"))
			stripes_h.call(reds)
			b.box(Vector3(0.6, 0.5, 0.035), p + Vector3(-w / 2.0 + 0.3, h / 2.0 - 0.25, 0), Color("3c3b6e"))
		_:
			b.box(Vector3(w, h, 0.03), p, Color("eceff1"))


func _yard(b: MeshBatch, flat: MeshBatch) -> void:
	# Car park in front of the hall, a guard booth at the gate.
	for k in 6:
		var x := -19.0 + k * 3.2
		flat.box(Vector3(0.1, 0.012, 4.6), Vector3(x - 1.6, 0.08, 11.5), Color("f2f2ee"))
		if k % 2 == 0 or k == 3:
			var cols := [Color("eceff1"), Color("c62828"), Color("212121"), Color("1565c0")]
			BuildingsView._car(self, Vector3(x, 0, 11.5), 0.0, cols[k % cols.size()], lamp_material)
	b.box(Vector3(2.2, 2.6, 2.2), Vector3(20.5, 1.3, 14.3), Color("eceff1"), _paint)
	b.box(Vector3(2.5, 0.25, 2.5), Vector3(20.5, 2.7, 14.3), Color("37474f"), _paint)
	b.box(Vector3(1.4, 0.8, 0.05), Vector3(20.5, 1.6, 15.42), Color("8fb6d6"), window_material)
	b.box(Vector3(7.0, 0.12, 0.12), Vector3(14.0, 1.0, 16.3), Color("e53935"), _paint)
	# Plants along the front fence
	for x in [-20.0, -14.0, -8.0, -2.0, 4.0]:
		b.box(Vector3(2.0, 0.4, 0.8), Vector3(x, 0.2, 14.9), Color("9a9893"), _paving)
		b.sphere(0.55, Vector3(x, 0.65, 14.9), Color("3f7a34"), null, Vector3(1.6, 0.7, 0.7), 8, 5)
