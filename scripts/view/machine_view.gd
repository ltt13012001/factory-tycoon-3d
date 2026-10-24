## Placeholder machine built from primitives, one look per MachineDef.model:
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

var machine_id := 0
var _body: Node3D
var _moving: Node3D  # part animated while running
var _model := "basic"
var _light: MeshInstance3D
var _bar_fill: MeshInstance3D
var _bar_root: Node3D
var _label: Label3D
var _units: Array[MeshInstance3D] = []
var _pips: Array[MeshInstance3D] = []
var _smoke: CPUParticles3D
var _sparks: CPUParticles3D
var _time := 0.0
var _build_anim := 0.0


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

	_bar_root = Node3D.new()
	_bar_root.position = Vector3(0, 3.3, 0)
	add_child(_bar_root)
	Palette.box(_bar_root, Vector3(1.8, 0.16, 0.16), Vector3.ZERO, Color(0, 0, 0, 0.6))
	_bar_fill = Palette.box(_bar_root, Vector3(1.8, 0.18, 0.18), Vector3.ZERO, Palette.STATUS_RUN)
	for i in 3:
		var pip := Palette.box(self, Vector3(0.22, 0.22, 0.22), Vector3(-0.3 + i * 0.3, 3.7, 0), Color("ffd23f"))
		pip.material_override = Palette.mat(Color("ffd23f"), 1.2)
		_pips.append(pip)
	_label = Palette.label3d(self, "", Vector3(0, 4.3, 0), 40, Palette.STATUS_WARN)

	var pallet := Node3D.new()
	pallet.position = Vector3(1.9, 0, 0)
	add_child(pallet)
	Palette.box(pallet, Vector3(1.2, 0.15, 1.2), Vector3(0, 0.075, 0), Palette.PALLET)
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

func _build_basic(color: Color) -> void:
	Palette.box(_body, Vector3(2.4, 0.25, 1.6), Vector3(0, 0.125, 0), Palette.MACHINE_DARK)
	Palette.box(_body, Vector3(2.2, 1.2, 1.3), Vector3(0, 0.85, 0), color)
	Palette.box(_body, Vector3(0.9, 0.5, 1.32), Vector3(-0.5, 0.95, 0), Palette.MACHINE_DARK)
	Palette.cylinder(_body, 0.12, 0.6, Vector3(0.6, 1.75, 0), Palette.MACHINE_DARK)
	Palette.cylinder(_body, 0.15, 0.7, Vector3(0.6, 2.3, 0), Palette.PELLET_BAG, 0.55)
	Palette.box(_body, Vector3(0.5, 0.3, 0.05), Vector3(-0.5, 0.95, 0.67), Color("9fe3ff"))
	_light = Palette.sphere(_body, 0.16, Vector3(-0.9, 1.6, 0.5), Palette.STATUS_RUN, 2.0)
	_moving = Node3D.new()
	_moving.position = Vector3(0.6, 2.75, 0)
	_body.add_child(_moving)
	Palette.box(_moving, Vector3(0.5, 0.08, 0.08), Vector3.ZERO, Palette.MACHINE_DARK)


func _build_blow(color: Color) -> void:
	Palette.box(_body, Vector3(2.5, 0.25, 1.6), Vector3(0, 0.125, 0), Palette.MACHINE_DARK)
	Palette.box(_body, Vector3(1.1, 1.6, 1.3), Vector3(-0.65, 1.05, 0), color)
	var dome := Palette.cylinder(_body, 0.55, 1.2, Vector3(0.55, 0.85, 0), Color(0.7, 0.95, 1.0, 0.45))
	dome.material_override = Palette.mat(Color(0.7, 0.95, 1.0, 0.45))
	Palette.cylinder(_body, 0.58, 0.12, Vector3(0.55, 1.5, 0), color)
	Palette.cylinder(_body, 0.2, 0.9, Vector3(-0.65, 2.3, 0), Palette.PELLET_BAG, 0.45)
	_moving = Node3D.new()
	_moving.position = Vector3(0.55, 0.6, 0)
	_body.add_child(_moving)
	for i in 3:
		var a := TAU * i / 3.0
		Palette.cylinder(_moving, 0.1, 0.4, Vector3(cos(a) * 0.3, 0.2, sin(a) * 0.3), Color("8fd9c4"))
	_light = Palette.sphere(_body, 0.16, Vector3(-0.65, 1.95, 0.66), Palette.STATUS_RUN, 2.0)


func _build_industrial(color: Color) -> void:
	Palette.box(_body, Vector3(2.8, 0.3, 1.8), Vector3(0, 0.15, 0), Palette.MACHINE_DARK)
	Palette.box(_body, Vector3(2.6, 1.5, 1.5), Vector3(0, 1.05, 0), color)
	for x in [-0.9, -0.3, 0.3, 0.9]:
		Palette.box(_body, Vector3(0.3, 0.08, 1.52), Vector3(x, 0.4, 0), Color("ffd23f"))
	Palette.cylinder(_body, 0.16, 0.8, Vector3(0.5, 2.1, 0.3), Palette.MACHINE_DARK)
	Palette.cylinder(_body, 0.18, 0.7, Vector3(0.5, 2.7, 0.3), Palette.PELLET_BAG, 0.5)
	Palette.cylinder(_body, 0.16, 0.8, Vector3(0.5, 2.1, -0.3), Palette.MACHINE_DARK)
	Palette.cylinder(_body, 0.18, 0.7, Vector3(0.5, 2.7, -0.3), Palette.PELLET_BAG, 0.5)
	Palette.box(_body, Vector3(0.8, 0.6, 0.05), Vector3(-0.6, 1.2, 0.77), Color("9fe3ff"))
	_moving = Node3D.new()
	_moving.position = Vector3(1.4, 0.75, 0)
	_body.add_child(_moving)
	Palette.box(_moving, Vector3(0.5, 0.1, 1.0), Vector3.ZERO, Color("222222"))
	_light = Palette.sphere(_body, 0.18, Vector3(-1.1, 1.95, 0.6), Palette.STATUS_RUN, 2.0)


func _build_press(color: Color) -> void:
	Palette.box(_body, Vector3(2.6, 0.4, 1.8), Vector3(0, 0.2, 0), Palette.MACHINE_DARK)
	for x in [-1.05, 1.05]:
		for z in [-0.7, 0.7]:
			Palette.box(_body, Vector3(0.2, 2.6, 0.2), Vector3(x, 1.5, z), Palette.MACHINE_DARK)
	Palette.box(_body, Vector3(2.5, 0.4, 1.7), Vector3(0, 2.9, 0), color)
	Palette.box(_body, Vector3(1.8, 0.2, 1.3), Vector3(0, 0.55, 0), Color("cfcfcf"))
	_moving = Node3D.new()
	_moving.position = Vector3(0, 2.2, 0)
	_body.add_child(_moving)
	Palette.box(_moving, Vector3(1.8, 0.35, 1.3), Vector3.ZERO, color.darkened(0.3))
	Palette.cylinder(_moving, 0.15, 0.6, Vector3(0, 0.45, 0), Color("aaaaaa"))
	_light = Palette.sphere(_body, 0.18, Vector3(-1.05, 3.25, 0.7), Palette.STATUS_RUN, 2.0)


func _build_auto(color: Color) -> void:
	Palette.box(_body, Vector3(2.6, 0.25, 1.7), Vector3(0, 0.125, 0), Palette.MACHINE_DARK)
	Palette.box(_body, Vector3(1.6, 1.1, 1.3), Vector3(-0.4, 0.8, 0), color)
	Palette.box(_body, Vector3(1.0, 0.12, 0.6), Vector3(0.9, 0.95, 0), Color("333333"))
	Palette.cylinder(_body, 0.25, 0.3, Vector3(0.9, 0.4, 0.5), Color("e8e8e8"))
	_moving = Node3D.new()
	_moving.position = Vector3(0.9, 0.55, 0.5)
	_body.add_child(_moving)
	Palette.box(_moving, Vector3(0.18, 1.0, 0.18), Vector3(0, 0.5, 0), Color("f39c12"))
	Palette.box(_moving, Vector3(0.9, 0.16, 0.16), Vector3(0.4, 1.0, 0), Color("f39c12"))
	Palette.box(_moving, Vector3(0.2, 0.3, 0.3), Vector3(0.85, 0.85, 0), Color("333333"))
	Palette.cylinder(_body, 0.15, 0.7, Vector3(-0.4, 1.7, 0), Palette.PELLET_BAG, 0.5)
	_light = Palette.sphere(_body, 0.16, Vector3(-1.1, 1.45, 0.6), Palette.STATUS_RUN, 2.0)


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
