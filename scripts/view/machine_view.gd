## Placeholder injection molder: body, hopper, status light, progress bar,
## reason label and the pallet of finished boxes. Mirrors one machine in
## the simulation; replace the scene path in the MachineDef for real art.
extends Node3D

const STATUS_TEXT := {
	"running": "",
	"no_operator": "Thiếu công nhân",
	"no_material": "Thiếu nguyên liệu",
	"output_full": "Pallet đầy",
}

var machine_id := 0
var _body: Node3D
var _light: MeshInstance3D
var _bar_fill: MeshInstance3D
var _bar_root: Node3D
var _label: Label3D
var _boxes: Array[MeshInstance3D] = []
var _pallet_root: Node3D
var _time := 0.0
var _build_anim := 0.0


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	Palette.box(_body, Vector3(2.4, 0.25, 1.6), Vector3(0, 0.125, 0), Palette.MACHINE_DARK)
	Palette.box(_body, Vector3(2.2, 1.2, 1.3), Vector3(0, 0.85, 0), Palette.MACHINE_BODY)
	Palette.box(_body, Vector3(0.9, 0.5, 1.32), Vector3(-0.5, 0.95, 0), Palette.MACHINE_DARK)
	Palette.cylinder(_body, 0.12, 0.6, Vector3(0.6, 1.75, 0), Palette.MACHINE_DARK)
	Palette.cylinder(_body, 0.15, 0.7, Vector3(0.6, 2.3, 0), Palette.PELLET_BAG, 0.55)
	Palette.box(_body, Vector3(0.5, 0.3, 0.05), Vector3(-0.5, 0.95, 0.67), Color("9fe3ff"))
	_light = Palette.sphere(_body, 0.16, Vector3(-0.9, 1.6, 0.5), Palette.STATUS_RUN, 2.0)

	_bar_root = Node3D.new()
	_bar_root.position = Vector3(0, 3.0, 0)
	add_child(_bar_root)
	Palette.box(_bar_root, Vector3(1.6, 0.14, 0.14), Vector3.ZERO, Color(0, 0, 0, 0.6))
	_bar_fill = Palette.box(_bar_root, Vector3(1.6, 0.16, 0.16), Vector3.ZERO, Palette.STATUS_RUN)

	_label = Palette.label3d(self, "", Vector3(0, 3.5, 0), 40, Palette.STATUS_WARN)

	_pallet_root = Node3D.new()
	_pallet_root.position = Vector3(1.9, 0, 0)
	add_child(_pallet_root)
	Palette.box(_pallet_root, Vector3(1.2, 0.15, 1.2), Vector3(0, 0.075, 0), Palette.PALLET)
	for i in 20:
		var layer := i / 9
		var cell := i % 9
		var b := Palette.box(_pallet_root, Vector3(0.34, 0.3, 0.34),
			Vector3(-0.38 + (cell % 3) * 0.38, 0.32 + layer * 0.32, -0.38 + (cell / 3) * 0.38), Palette.BOX)
		b.visible = false
		_boxes.append(b)
	scale = Vector3(1, 0.01, 1)


func _process(delta: float) -> void:
	_time += delta
	if _build_anim < 1.0:
		_build_anim = minf(1.0, _build_anim + delta * 1.5)
		scale = Vector3(1, maxf(0.01, ease(_build_anim, 0.4)), 1)
	var sim: Simulation = GameManager.sim
	var m := sim.state.find_by_id(sim.state.machines, machine_id)
	if m.is_empty():
		return
	var d: MachineDef = sim.content.machines[m.def_id]
	var running: bool = m.status == "running"
	_body.position = Vector3(sin(_time * 40.0) * 0.015, absf(sin(_time * 25.0)) * 0.01, 0) if running and TimeManager.speed > 0 else Vector3.ZERO
	var color := Palette.STATUS_RUN
	if m.status == "no_operator" or m.status == "output_full":
		color = Palette.STATUS_WARN
	elif m.status == "no_material":
		color = Palette.STATUS_STOP
	_light.material_override = Palette.mat(color, 2.0)
	var progress := 0.0
	if m.in_cycle:
		progress = clampf((d.cycle_ticks - int(m.ticks_left) + (sim.tick_fraction() if running else 0.0)) / d.cycle_ticks, 0.0, 1.0)
	_bar_root.visible = m.in_cycle
	_bar_fill.scale = Vector3(maxf(progress, 0.01), 1, 1)
	_bar_fill.position.x = -0.8 + 0.8 * progress
	_label.text = STATUS_TEXT.get(m.status, "")
	_label.modulate = color
	var shown := mini(int(m.buffer), _boxes.size())
	for i in _boxes.size():
		_boxes[i].visible = i < shown
