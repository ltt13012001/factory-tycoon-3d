## Placeholder truck: cab, cargo box, four wheels and visible cargo.
extends Node3D

var color := Palette.TRUCK_SUPPLIER
var _cargo: Node3D
var _wheels: Array[MeshInstance3D] = []


func _ready() -> void:
	Palette.box(self, Vector3(1.8, 1.5, 2.2), Vector3(0, 1.15, 2.4), color)
	Palette.box(self, Vector3(1.7, 0.6, 0.05), Vector3(0, 1.5, 3.52), Color("9fd8ff"))
	Palette.box(self, Vector3(2.2, 0.3, 5.6), Vector3(0, 0.55, 0.3), Palette.MACHINE_DARK)
	Palette.box(self, Vector3(2.1, 0.1, 3.6), Vector3(0, 0.75, -0.5), Color("d0d0d0"))
	for x in [-1.0, 1.0]:
		for z in [-1.4, 2.4]:
			var w := Palette.cylinder(self, 0.45, 0.35, Vector3(x * 1.05, 0.45, z), Color("222222"))
			w.rotation.z = PI / 2
			_wheels.append(w)
	_cargo = Node3D.new()
	add_child(_cargo)
	for i in 6:
		Palette.box(_cargo, Vector3(0.8, 0.6, 0.8), Vector3(-0.45 + (i % 2) * 0.9, 1.1, -1.7 + (i / 2) * 0.95), Palette.PELLET_BAG if color == Palette.TRUCK_SUPPLIER else Palette.BOX)


func set_cargo_visible(v: bool) -> void:
	_cargo.visible = v


func spin_wheels(amount: float) -> void:
	for w in _wheels:
		w.rotate_object_local(Vector3.UP, amount)
