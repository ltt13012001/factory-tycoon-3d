## A machine built from primitives, one look per MachineDef.model:
## basic, blow, industrial, press, auto. Shows status light, cycle bar,
## reason label, level pips, wear, smoke when broken, sparks when repaired,
## and the pallet of finished units in the product's colour and shape.
extends Node3D

const STATUS_TEXT := {
	"running": "",
	"no_operator": "Thiếu công nhân",
	"no_material": "Thiếu nguyên liệu",
	"output_full": "Pallet đầy",
	"broken": "HỎNG! Bấm để sửa",
	"repairing": "Đang sửa…",
}
const STEEL := Color("b9c0c6")
const HEATER := Color("6b4a2e")
const HAZARD := Color("f2c12e")

var machine_id := 0
var _body: Node3D
var _moving: Node3D  # part animated while running
var _model := "basic"
var _light: MeshInstance3D  # signal tower lamp, coloured by status
var _bar_fill: MeshInstance3D
var _bar_root: Node3D
var _label: Label3D
var _units: Array[MeshInstance3D] = []
var _pips: Array[MeshInstance3D] = []
var _smoke: CPUParticles3D
var _sparks: CPUParticles3D
var _time := 0.0
var _build_anim := 0.0
# Used while building the model
var _b: MeshBatch
var _paint: Material
var _steel: Material


func _ready() -> void:
	var sim: Simulation = GameManager.sim
	var m := sim.state.find_by_id(sim.state.machines, machine_id)
	var d: MachineDef = sim.content.machines[m.def_id]
	var p: ProductDef = sim.content.products[d.output_product_id]
	_model = d.model
	_body = Node3D.new()
	add_child(_body)
	match _model:
		"blow":
			_build_blow(d.color)
		"industrial":
			_build_industrial(d.color)
		"press":
			_build_press(d.color)
		"auto":
			_build_auto(d.color)
		_:
			_build_basic(d.color)

	var top := 3.85 if _model == "press" else 3.3  # clear of the press cylinders
	_bar_root = Node3D.new()
	_bar_root.position = Vector3(0, top, 0)
	add_child(_bar_root)
	Palette.box(_bar_root, Vector3(1.8, 0.16, 0.16), Vector3.ZERO, Color(0, 0, 0, 0.6))
	_bar_fill = Palette.box(_bar_root, Vector3(1.8, 0.18, 0.18), Vector3.ZERO, Palette.STATUS_RUN)
	for i in 3:
		var pip := Palette.box(self, Vector3(0.22, 0.22, 0.22), Vector3(-0.3 + i * 0.3, top + 0.4, 0), Color("ffd23f"))
		pip.material_override = Palette.mat(Color("ffd23f"), 1.2)
		_pips.append(pip)
	_label = Palette.label3d(self, "", Vector3(0, top + 1.0, 0), 40, Palette.STATUS_WARN)

	var pallet := Node3D.new()
	pallet.position = Vector3(1.9, 0, 0)
	add_child(pallet)
	var deck := MeshBatch.new()
	Palette.pallet(deck, Vector3(0, 0.03, 0), Vector2(1.2, 1.2))
	deck.build(pallet)
	var cap := d.output_buffer_capacity
	for i in cap:
		var u: MeshInstance3D
		match p.id:
			"water_bottle":
				var layer := i / 9
				var cell := i % 9
				u = Palette.cylinder(pallet, 0.13, 0.42, Vector3(-0.38 + (cell % 3) * 0.38, 0.36 + layer * 0.44, -0.38 + (cell / 3) * 0.38), p.color)
			"storage_shelf":
				u = Palette.box(pallet, Vector3(1.05, 0.12, 0.9), Vector3(0, 0.22 + i * 0.16, 0), p.color)
			_:
				var layer := i / 9
				var cell := i % 9
				u = Palette.box(pallet, Vector3(0.34, 0.3, 0.34), Vector3(-0.38 + (cell % 3) * 0.38, 0.32 + layer * 0.32, -0.38 + (cell / 3) * 0.38), p.color)
		u.visible = false
		_units.append(u)

	_smoke = _particles(Color(0.25, 0.25, 0.25, 0.8), 0.35, Vector3(0, 2.2, 0), 1.4)
	_sparks = _particles(Color(1.0, 0.85, 0.3), 0.08, Vector3(-0.9, 1.0, 0.8), 3.0)
	_sparks.material_override = Palette.mat(Color(1.0, 0.85, 0.3), 3.0)
	scale = Vector3(1, 0.01, 1)


func _particles(color: Color, size: float, pos: Vector3, speed: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = 16
	p.lifetime = 1.6
	p.emitting = false
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	p.mesh = mesh
	p.material_override = Palette.mat(color)
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = speed * 0.6
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, 0.3, 0) if speed < 2.0 else Vector3(0, -6, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	add_child(p)
	return p


# --- Models --------------------------------------------------------------------
# Each model is merged into one mesh (see MeshBatch) with only the animated
# part and the status light kept as separate nodes. The machine faces +Z,
# where its operator stands; the output pallet is on the +X side.

func _begin() -> void:
	_b = MeshBatch.new()
	_paint = Palette.surface("paint")
	_steel = Palette.surface("steel")


func _finish() -> void:
	_b.build(_body)
	_b = null


## Base frame with levelling feet and a yellow/black stripe on the front.
func _base(size: Vector3) -> void:
	_b.box(size, Vector3(0, size.y / 2.0 + 0.05, 0), Palette.MACHINE_DARK, _paint)
	for x in [-1, 1]:
		for z in [-1, 1]:
			_b.cylinder(0.07, 0.05, Vector3(x * (size.x / 2.0 - 0.12), 0.025, z * (size.z / 2.0 - 0.1)), Color("3a3f44"), _steel, -1.0, Vector3.ZERO, 8)
	var n := int(size.x / 0.16)
	for i in n:
		var c := HAZARD if i % 2 == 0 else Color("1d2125")
		_b.box(Vector3(size.x / n, 0.1, 0.01), Vector3(-size.x / 2.0 + (i + 0.5) * size.x / n, 0.2, size.z / 2.0 + 0.005), c)


## Pellet hopper: throat, cone, drum and lid. Returns the height of the lid.
func _hopper(pos: Vector3, s: float = 1.0) -> float:
	var col := Color("cfd4d8")
	_b.cylinder(0.09 * s, 0.2 * s, pos + Vector3(0, 0.1 * s, 0), STEEL, _steel)
	_b.cylinder(0.1 * s, 0.45 * s, pos + Vector3(0, 0.425 * s, 0), col, _steel, 0.3 * s, Vector3.ZERO, 14)
	_b.cylinder(0.3 * s, 0.3 * s, pos + Vector3(0, 0.8 * s, 0), col, _steel, -1.0, Vector3.ZERO, 14)
	_b.cylinder(0.32 * s, 0.05 * s, pos + Vector3(0, 0.975 * s, 0), Color("8d969d"), _steel, -1.0, Vector3.ZERO, 14)
	_b.box(Vector3(0.14, 0.18, 0.01) * s, pos + Vector3(0, 0.8 * s, 0.3 * s), Color("2f6db5"))
	return pos.y + 1.0 * s


## Horizontal plasticising barrel with heater bands, pointing -X.
func _barrel(from_x: float, to_x: float, y: float, r: float) -> void:
	var length := to_x - from_x
	_b.cylinder(r, length, Vector3((from_x + to_x) / 2.0, y, 0), STEEL, _steel, -1.0, Vector3(0, 0, PI / 2), 12)
	var bands := int(length / 0.2)
	for i in bands:
		_b.cylinder(r * 1.28, 0.11, Vector3(from_x + 0.12 + i * (length - 0.2) / maxf(1, bands - 1), y, 0), HEATER, _steel, -1.0, Vector3(0, 0, PI / 2), 12)
	_b.cylinder(r * 0.6, 0.16, Vector3(from_x - 0.08, y, 0), STEEL, _steel, r * 0.25, Vector3(0, 0, PI / 2), 10)


## Control panel on a pedestal: touch screen, buttons and an emergency stop.
func _panel(pos: Vector3, yaw := 0.0) -> void:
	var keep := _b.origin
	_b.origin = Transform3D(Basis(Vector3.UP, yaw), pos)
	_b.box(Vector3(0.1, 1.1, 0.1), Vector3(0, 0.55, 0), Color("3a3f44"), _paint)
	_b.box(Vector3(0.55, 0.42, 0.14), Vector3(0, 1.3, 0.02), Color("d5d9dc"), _paint, Vector3(-0.25, 0, 0))
	_b.box(Vector3(0.4, 0.26, 0.01), Vector3(0, 1.34, 0.095), Color("2b8fd6"), Palette.surface("screen"), Vector3(-0.25, 0, 0))
	_b.box(Vector3(0.3, 0.06, 0.01), Vector3(-0.02, 1.36, 0.1), Color("7dd87d"), Palette.surface("screen"), Vector3(-0.25, 0, 0))
	_b.cylinder(0.045, 0.05, Vector3(0.2, 1.16, 0.11), Color("d32f2f"), _paint, -1.0, Vector3(PI / 2 - 0.25, 0, 0), 10)
	_b.cylinder(0.025, 0.04, Vector3(-0.15, 1.15, 0.1), Color("43a047"), _paint, -1.0, Vector3(PI / 2 - 0.25, 0, 0), 8)
	_b.cylinder(0.025, 0.04, Vector3(-0.05, 1.15, 0.1), Color("eceff1"), _paint, -1.0, Vector3(PI / 2 - 0.25, 0, 0), 8)
	_b.origin = keep


## Signal tower: a pole with the status lamp on top (the lamp's colour is
## set every frame from the machine status).
func _stack_light(pos: Vector3) -> void:
	_b.cylinder(0.025, 0.35, pos + Vector3(0, 0.175, 0), Color("3a3f44"), _steel, -1.0, Vector3.ZERO, 6)
	_b.cylinder(0.075, 0.05, pos + Vector3(0, 0.025, 0), Color("26292c"), _paint, -1.0, Vector3.ZERO, 10)
	_b.cylinder(0.08, 0.04, pos + Vector3(0, 0.62, 0), Color("26292c"), _paint, -1.0, Vector3.ZERO, 10)
	_light = Palette.cylinder(_body, 0.08, 0.24, pos + Vector3(0, 0.48, 0), Palette.STATUS_RUN)
	_light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Glass window with a dark frame on a face pointing +Z.
func _window(center: Vector3, size: Vector2) -> void:
	_b.box(Vector3(size.x + 0.08, size.y + 0.08, 0.02), center - Vector3(0, 0, 0.012), Color("1d2125"))
	_b.box(Vector3(size.x, size.y, 0.02), center, Color.WHITE, Palette.surface("glass"))


## Injection moulding machines: clamping unit with tie bars on the left,
## injection unit with barrel and hopper on the right.
func _build_basic(color: Color) -> void:
	_begin()
	_base(Vector3(2.5, 0.45, 1.25))
	var guard := color
	_b.box(Vector3(1.15, 0.95, 1.15), Vector3(-0.6, 0.975, 0), guard, _paint)
	_window(Vector3(-0.62, 1.05, 0.585), Vector2(0.7, 0.45))
	_b.box(Vector3(0.04, 0.32, 0.05), Vector3(-0.17, 1.02, 0.6), Color("26292c"))
	for x in [-1.2, 0.03]:
		_b.box(Vector3(0.13, 1.2, 1.15), Vector3(x, 1.08, 0), color.darkened(0.25), _paint)
	for z in [-0.38, 0.38]:
		_b.bar(Vector3(-1.25, 1.58, z), Vector3(0.08, 1.58, z), 0.08, STEEL, _steel, true)
	_b.box(Vector3(1.0, 0.42, 0.72), Vector3(0.62, 0.71, 0), color, _paint)
	_barrel(0.14, 0.94, 1.18, 0.11)
	_b.cylinder(0.17, 0.3, Vector3(1.08, 1.18, 0), color.darkened(0.25), _paint, -1.0, Vector3(0, 0, PI / 2), 12)
	_b.cylinder(0.17, 0.42, Vector3(0.62, 0.62, -0.47), Color("2f3a46"), _paint, -1.0, Vector3(0, 0, PI / 2), 12)
	var lid := _hopper(Vector3(0.72, 1.3, 0), 0.9)
	_panel(Vector3(-0.05, 0, 0.72))
	_stack_light(Vector3(-1.05, 1.45, 0.42))
	_b.bar(Vector3(-0.05, 0.5, 0.7), Vector3(-0.05, 0.5, 0.55), 0.04, Color("1d2125"), Palette.surface("rubber"), true)
	_finish()
	_moving = Node3D.new()
	_moving.position = Vector3(0.72, lid + 0.05, 0)
	_body.add_child(_moving)
	Palette.box(_moving, Vector3(0.18, 0.12, 0.18), Vector3(0, 0.03, 0), Color("2f3a46"))
	Palette.box(_moving, Vector3(0.42, 0.04, 0.05), Vector3(0, 0.1, 0), STEEL)


## Blow moulder: cabinet with the preform feeder on the left, a glass
## enclosure with the turning mould carousel on the right.
func _build_blow(color: Color) -> void:
	_begin()
	_base(Vector3(2.5, 0.3, 1.5))
	_b.box(Vector3(1.1, 1.7, 1.3), Vector3(-0.65, 1.2, 0), color, _paint)
	_b.box(Vector3(0.01, 1.5, 0.01), Vector3(-0.65, 1.2, 0.655), Color("1d2125"))
	for i in 5:
		_b.box(Vector3(0.4, 0.03, 0.01), Vector3(-0.9, 0.55 + i * 0.07, 0.656), Color("1d2125"))
	_b.box(Vector3(0.42, 0.3, 0.01), Vector3(-0.42, 1.55, 0.656), Color("2b8fd6"), Palette.surface("screen"))
	# Preform hopper on the roof with a chute into the enclosure
	_b.box(Vector3(0.85, 0.5, 0.9), Vector3(-0.72, 2.3, 0), color.lightened(0.12), _paint)
	_b.box(Vector3(0.95, 0.06, 1.0), Vector3(-0.72, 2.58, 0), Color("8d969d"), _steel)
	_b.bar(Vector3(-0.3, 2.2, 0), Vector3(0.45, 1.75, 0), 0.14, STEEL, _steel)
	# Glass enclosure with a steel frame
	var c := Vector3(0.6, 0.95, 0)
	var s := Vector3(1.2, 1.3, 1.3)
	_b.box(s, c, Color.WHITE, Palette.surface("glass"))
	for x in [-1, 1]:
		for z in [-1, 1]:
			_b.box(Vector3(0.06, s.y, 0.06), c + Vector3(x * s.x / 2.0, 0, z * s.z / 2.0), Color("3a3f44"), _steel)
	for z in [-1, 1]:
		_b.box(Vector3(s.x, 0.06, 0.06), c + Vector3(0, s.y / 2.0, z * s.z / 2.0), Color("3a3f44"), _steel)
	for x in [-1, 1]:
		_b.box(Vector3(0.06, 0.06, s.z), c + Vector3(x * s.x / 2.0, s.y / 2.0, 0), Color("3a3f44"), _steel)
	_b.box(Vector3(s.x, 0.08, s.z), c + Vector3(0, s.y / 2.0 + 0.04, 0), color.darkened(0.2), _paint)
	# Chilled water lines
	_b.bar(Vector3(-0.1, 1.9, -0.5), Vector3(0.6, 1.66, -0.5), 0.06, Color("2f6db5"), _paint, true)
	_b.bar(Vector3(-0.1, 1.8, -0.36), Vector3(0.6, 1.66, -0.36), 0.06, Color("c0392b"), _paint, true)
	_stack_light(Vector3(-1.1, 2.05, 0.5))
	_panel(Vector3(0.6, 0, 0.88))
	_finish()
	_moving = Node3D.new()
	_moving.position = Vector3(0.6, 0.35, 0)
	_body.add_child(_moving)
	Palette.cylinder(_moving, 0.48, 0.06, Vector3(0, 0.03, 0), Color("8d969d"))
	for i in 3:
		var a := TAU * i / 3.0
		Palette.cylinder(_moving, 0.13, 0.45, Vector3(cos(a) * 0.3, 0.28, sin(a) * 0.3), Color("8fd9c4"))
		Palette.cylinder(_moving, 0.05, 0.14, Vector3(cos(a) * 0.3, 0.57, sin(a) * 0.3), Color("b3e5fc"))


## Large injection moulder with a sprue-picker robot and an exit conveyor.
func _build_industrial(color: Color) -> void:
	_begin()
	_base(Vector3(2.9, 0.5, 1.6))
	_b.box(Vector3(1.5, 1.25, 1.45), Vector3(-0.65, 1.175, 0), color, _paint)
	_window(Vector3(-0.95, 1.25, 0.73), Vector2(0.55, 0.55))
	_window(Vector3(-0.33, 1.25, 0.73), Vector2(0.55, 0.55))
	for x in [-1.42, 0.12]:
		_b.box(Vector3(0.16, 1.45, 1.45), Vector3(x, 1.25, 0), color.darkened(0.25), _paint)
	for z in [-0.48, 0.48]:
		_b.bar(Vector3(-1.5, 1.88, z), Vector3(0.2, 1.88, z), 0.12, STEEL, _steel, true)
	_b.box(Vector3(1.25, 0.5, 0.8), Vector3(0.8, 0.8, 0), color, _paint)
	_barrel(0.25, 1.3, 1.32, 0.14)
	_b.box(Vector3(1.0, 0.45, 0.3), Vector3(0.8, 0.78, -0.62), Color("2f3a46"), _paint)
	var lid := _hopper(Vector3(0.62, 1.48, 0), 1.15)
	_b.cylinder(0.2, 0.35, Vector3(0.62, lid + 0.17, 0), Color("eceff1"), _paint)
	_b.bar(Vector3(0.62, lid + 0.3, 0), Vector3(1.3, lid + 0.3, -0.6), 0.06, Color("90a4ae"), _steel, true)
	# Sprue picker: a beam over the mould with a vertical arm
	_b.box(Vector3(0.14, 1.2, 0.14), Vector3(-0.65, 2.4, -0.7), Color("3a3f44"), _steel)
	_b.box(Vector3(0.16, 0.16, 1.5), Vector3(-0.65, 3.0, -0.05), Color("f39c12"), _paint)
	_b.box(Vector3(0.1, 0.7, 0.1), Vector3(-0.65, 2.6, 0.2), Color("3a3f44"), _steel)
	_b.box(Vector3(0.3, 0.06, 0.2), Vector3(-0.65, 2.24, 0.2), Color("f39c12"), _paint)
	# Exit conveyor frame
	for z in [-0.45, 0.45]:
		_b.box(Vector3(0.06, 0.7, 0.06), Vector3(1.4, 0.35, z), Color("3a3f44"), _steel)
		_b.box(Vector3(0.6, 0.08, 0.04), Vector3(1.4, 0.72, z * 1.1), Color("8d969d"), _steel)
	_panel(Vector3(-0.1, 0, 0.92))
	_stack_light(Vector3(-1.3, 1.95, 0.6))
	_finish()
	_moving = Node3D.new()
	_moving.position = Vector3(1.4, 0.75, 0)
	_body.add_child(_moving)
	Palette.box(_moving, Vector3(0.5, 0.06, 0.95), Vector3.ZERO, Color("222222"))
	for i in 3:
		Palette.box(_moving, Vector3(0.2, 0.06, 0.2), Vector3(0, 0.06, -0.3 + i * 0.3), color.lightened(0.3))


## Hydraulic press: bed, four columns, crown with cylinders, moving ram,
## light curtains and a two-hand control.
func _build_press(color: Color) -> void:
	_begin()
	_base(Vector3(2.6, 0.4, 1.8))
	_b.box(Vector3(1.85, 0.12, 1.3), Vector3(0, 0.51, 0), Color("c9ced3"), _steel)
	for i in 4:
		_b.box(Vector3(1.85, 0.02, 0.05), Vector3(0, 0.575, -0.45 + i * 0.3), Color("6d747a"))
	for x in [-1.05, 1.05]:
		for z in [-0.7, 0.7]:
			_b.cylinder(0.11, 2.3, Vector3(x, 1.6, z), STEEL, _steel)
			_b.cylinder(0.16, 0.12, Vector3(x, 2.76, z), Color("3a3f44"), _steel, -1.0, Vector3.ZERO, 8)
	_b.box(Vector3(2.5, 0.45, 1.7), Vector3(0, 2.95, 0), color, _paint)
	_b.box(Vector3(2.52, 0.08, 1.72), Vector3(0, 2.72, 0), color.darkened(0.3), _paint)
	for x in [-0.5, 0.5]:
		_b.cylinder(0.24, 0.32, Vector3(x, 3.33, 0), Color("2f3a46"), _paint, -1.0, Vector3.ZERO, 14)
		_b.cylinder(0.27, 0.05, Vector3(x, 3.5, 0), STEEL, _steel, -1.0, Vector3.ZERO, 14)
	_b.box(Vector3(0.6, 0.35, 0.5), Vector3(0.95, 3.35, -0.5), Color("2f3a46"), _paint)
	_b.bar(Vector3(0.5, 3.45, -0.2), Vector3(0.95, 3.45, -0.4), 0.05, Color("1d2125"), Palette.surface("rubber"), true)
	# Light curtains on the operator side
	for x in [-1.22, 1.22]:
		_b.box(Vector3(0.07, 1.6, 0.07), Vector3(x, 1.3, 0.95), HAZARD, _paint)
		_b.box(Vector3(0.02, 1.4, 0.02), Vector3(x - signf(x) * 0.04, 1.3, 0.95), Color("ff5252"), Palette.surface("screen"))
	# Two-hand control station
	_b.box(Vector3(0.08, 1.0, 0.08), Vector3(0, 0.5, 1.25), Color("3a3f44"), _paint)
	_b.box(Vector3(0.8, 0.12, 0.25), Vector3(0, 1.05, 1.25), HAZARD, _paint)
	for x in [-0.28, 0.28]:
		_b.cylinder(0.05, 0.05, Vector3(x, 1.13, 1.25), Color("d32f2f"), _paint, -1.0, Vector3.ZERO, 10)
	_b.cylinder(0.04, 0.05, Vector3(0, 1.13, 1.25), Color("43a047"), _paint, -1.0, Vector3.ZERO, 10)
	_stack_light(Vector3(-1.05, 3.18, 0.7))
	_finish()
	_moving = Node3D.new()
	_moving.position = Vector3(0, 2.2, 0)
	_body.add_child(_moving)
	Palette.box(_moving, Vector3(1.8, 0.35, 1.3), Vector3.ZERO, color.darkened(0.3))
	Palette.box(_moving, Vector3(1.5, 0.08, 1.1), Vector3(0, -0.2, 0), Color("c9ced3"))
	Palette.cylinder(_moving, 0.15, 0.6, Vector3(0, 0.45, 0), Color("dfe3e6"))


## Compact moulder served by a six-axis robot arm behind a safety screen.
func _build_auto(color: Color) -> void:
	_begin()
	_base(Vector3(2.6, 0.2, 1.7))
	_b.box(Vector3(1.6, 1.1, 1.3), Vector3(-0.4, 0.8, 0), color, _paint)
	_window(Vector3(-0.55, 0.9, 0.655), Vector2(0.8, 0.45))
	_b.box(Vector3(0.6, 0.35, 0.01), Vector3(-0.4, 1.36, 0.656), Color("1d2125"))
	var lid := _hopper(Vector3(-0.75, 1.35, 0), 0.75)
	_b.bar(Vector3(-0.75, lid, 0), Vector3(-0.1, lid + 0.25, -0.4), 0.05, Color("90a4ae"), _steel, true)
	# Robot pedestal, part table and the safety screen behind the cell
	_b.cylinder(0.27, 0.35, Vector3(0.9, 0.38, 0.5), Color("e8e8e8"), _paint, -1.0, Vector3.ZERO, 14)
	_b.box(Vector3(1.0, 0.08, 0.6), Vector3(0.9, 0.95, -0.1), Color("3a3f44"), _steel)
	for x in [0.45, 1.35]:
		_b.box(Vector3(0.06, 0.85, 0.06), Vector3(x, 0.5, -0.1), Color("3a3f44"), _steel)
	for x in [0.15, 1.3]:
		_b.box(Vector3(0.06, 1.7, 0.06), Vector3(x, 0.95, -0.82), HAZARD, _paint)
	_b.box(Vector3(1.15, 1.5, 0.02), Vector3(0.72, 1.0, -0.82), Color(0.95, 0.78, 0.2, 0.35), Palette.surface("mesh"))
	_b.box(Vector3(1.15, 0.05, 0.05), Vector3(0.72, 1.78, -0.82), HAZARD, _paint)
	_panel(Vector3(-1.05, 0, 0.78))
	_stack_light(Vector3(-1.1, 1.35, 0.5))
	_finish()
	# The arm turns on its base; the pieces are merged into one mesh too.
	_moving = Node3D.new()
	_moving.position = Vector3(0.9, 0.55, 0.5)
	_body.add_child(_moving)
	var arm := MeshBatch.new()
	var orange := Color("f39c12")
	arm.cylinder(0.22, 0.2, Vector3(0, 0.1, 0), orange, _paint, -1.0, Vector3.ZERO, 14)
	arm.sphere(0.13, Vector3(0, 0.28, 0), Color("3a3f44"), _paint)
	arm.bar(Vector3(0, 0.28, 0), Vector3(0.12, 0.98, 0), 0.17, orange, _paint)
	arm.sphere(0.1, Vector3(0.12, 0.98, 0), Color("3a3f44"), _paint)
	arm.bar(Vector3(0.12, 0.98, 0), Vector3(0.75, 0.9, 0), 0.13, orange, _paint)
	arm.cylinder(0.06, 0.12, Vector3(0.8, 0.9, 0), Color("3a3f44"), _steel, -1.0, Vector3(0, 0, PI / 2), 10)
	arm.box(Vector3(0.12, 0.2, 0.26), Vector3(0.88, 0.84, 0), Color("333333"), _steel)
	arm.box(Vector3(0.05, 0.14, 0.04), Vector3(0.88, 0.7, -0.09), Color("8d969d"), _steel)
	arm.box(Vector3(0.05, 0.14, 0.04), Vector3(0.88, 0.7, 0.09), Color("8d969d"), _steel)
	arm.build(_moving)


# --- Per frame -------------------------------------------------------------------

func _process(delta: float) -> void:
	var speed := float(TimeManager.speed)
	_time += delta * maxf(speed, 0.0)
	if _build_anim < 1.0:
		_build_anim = minf(1.0, _build_anim + delta * 1.5)
		scale = Vector3(1, maxf(0.01, ease(_build_anim, 0.4)), 1)
	var sim: Simulation = GameManager.sim
	var m := sim.state.find_by_id(sim.state.machines, machine_id)
	if m.is_empty():
		return
	var running: bool = m.status == "running" and speed > 0
	_body.position = Vector3(sin(_time * 40.0) * 0.012, 0, 0) if running else Vector3.ZERO
	_animate(running)
	var color := Palette.STATUS_RUN
	match m.status:
		"no_operator", "output_full", "repairing":
			color = Palette.STATUS_WARN
		"no_material", "broken":
			color = Palette.STATUS_STOP
	var blink: bool = m.status == "broken" and int(_time * 3.0 + Time.get_ticks_msec() / 300.0) % 2 == 0
	_light.material_override = Palette.mat(color, 0.2 if blink else 2.5)
	var cycle := sim.production.cycle_ticks(m)
	var progress := 0.0
	if m.in_cycle:
		progress = clampf((cycle - int(m.ticks_left) + (sim.tick_fraction() if running else 0.0)) / cycle, 0.0, 1.0)
	if m.status == "repairing":
		var total := sim.config.repair_walk_ticks + sim.production.def_of(m).repair_ticks
		progress = 1.0 - float(m.repair_ticks_left) / total
		_bar_fill.material_override = Palette.mat(Palette.STATUS_WARN)
	else:
		_bar_fill.material_override = Palette.mat(Palette.STATUS_RUN)
	_bar_root.visible = m.in_cycle or m.status == "repairing"
	_bar_fill.scale = Vector3(maxf(progress, 0.01), 1, 1)
	_bar_fill.position.x = -0.9 + 0.9 * progress
	var text: String = STATUS_TEXT.get(m.status, "")
	if text == "" and int(m.condition) < 30:
		text = "Cần bảo trì (%d%%)" % m.condition
		color = Palette.STATUS_WARN
	_label.text = text
	_label.modulate = color
	for i in _pips.size():
		_pips[i].visible = i < int(m.level) and int(m.level) > 1
	var shown := mini(int(m.buffer), _units.size())
	for i in _units.size():
		_units[i].visible = i < shown
	_smoke.emitting = m.status == "broken"
	_sparks.emitting = m.status == "repairing" and int(m.repair_ticks_left) <= sim.production.def_of(m).repair_ticks


func _animate(running: bool) -> void:
	if _moving == null or not running:
		return
	match _model:
		"press":
			_moving.position.y = 1.25 + absf(sin(_time * 3.0)) * 0.95
		"auto":
			_moving.rotation.y = sin(_time * 2.0) * 1.4
		"blow":
			_moving.rotation.y += 0.05
		"industrial":
			_moving.position.y = 0.75 + sin(_time * 20.0) * 0.02
		_:
			_moving.rotation.y += 0.15
