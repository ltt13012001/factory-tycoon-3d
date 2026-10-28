## Delivery truck: cab with windows, lights and mirrors, chassis, a flatbed
## with stake sides, spinning wheels and visible cargo. Faces +Z.
extends Node3D

var color := Palette.TRUCK_SUPPLIER
var _cargo: Node3D
var _wheels: Array[Node3D] = []


func _ready() -> void:
	var b := MeshBatch.new()
	var paint := Palette.surface("paint")
	var steel := Palette.surface("steel")
	var rubber := Palette.surface("rubber")
	var glass := Palette.surface("glass")
	var dark := Color("2a2e33")
	# Chassis, bumper, fuel tank and mudguards
	b.box(Vector3(1.5, 0.25, 5.6), Vector3(0, 0.6, 0.3), dark, steel)
	b.box(Vector3(2.2, 0.28, 0.2), Vector3(0, 0.55, 3.55), Color("3a3f44"), steel)
	b.cylinder(0.25, 0.9, Vector3(1.0, 0.65, 1.0), Color("c9ced3"), steel, -1.0, Vector3(PI / 2, 0, 0), 12)
	for z in [-1.4, 2.4]:
		for x in [-1.05, 1.05]:
			b.box(Vector3(0.4, 0.06, 1.1), Vector3(x, 1.0, z), dark, rubber)
	# Cab: body, roof fairing, windscreen, side windows, grille, lights
	b.box(Vector3(2.1, 1.55, 1.9), Vector3(0, 1.55, 2.55), color, paint)
	b.box(Vector3(2.0, 0.35, 1.4), Vector3(0, 2.5, 2.35), color.darkened(0.12), paint, Vector3(-0.15, 0, 0))
	b.box(Vector3(1.9, 0.75, 0.04), Vector3(0, 1.85, 3.5), Color.WHITE, glass, Vector3(-0.08, 0, 0))
	for x in [-1.06, 1.06]:
		b.box(Vector3(0.04, 0.6, 0.8), Vector3(x, 1.9, 2.9), Color.WHITE, glass)
		b.box(Vector3(0.05, 0.35, 0.12), Vector3(x * 1.12, 1.85, 3.35), dark)
	b.box(Vector3(1.3, 0.5, 0.04), Vector3(0, 1.0, 3.51), Color("1d2125"), steel)
	for i in 4:
		b.box(Vector3(1.25, 0.03, 0.02), Vector3(0, 0.82 + i * 0.12, 3.535), Color("8d969d"), steel)
	for x in [-0.85, 0.85]:
		b.box(Vector3(0.3, 0.16, 0.04), Vector3(x, 0.98, 3.52), Color("fff6d6"), Palette.surface("screen"))
		b.box(Vector3(0.2, 0.12, 0.04), Vector3(x, 0.6, -2.42), Color("d32f2f"), Palette.surface("screen"))
	b.box(Vector3(0.6, 0.06, 0.06), Vector3(0, 2.36, 3.3), Color("f2a516"), Palette.surface("screen"))
	# Flatbed with stake sides and a headboard
	b.box(Vector3(2.2, 0.12, 3.9), Vector3(0, 0.8, -0.45), Color("8d969d"), steel)
	b.box(Vector3(2.2, 1.0, 0.08), Vector3(0, 1.35, 1.5), Color("3a3f44"), steel)
	for x in [-1.08, 1.08]:
		b.box(Vector3(0.05, 0.35, 3.9), Vector3(x, 1.03, -0.45), color.darkened(0.2), paint)
		for k in 5:
			b.box(Vector3(0.07, 0.6, 0.07), Vector3(x, 1.15, -2.3 + k * 0.92), Color("3a3f44"), steel)
	b.box(Vector3(2.2, 0.3, 0.05), Vector3(0, 1.0, -2.4), color.darkened(0.2), paint)
	b.build(self)
	for x in [-1.0, 1.0]:
		for z in [-1.4, 2.4]:
			var w := Node3D.new()
			w.position = Vector3(x * 1.02, 0.45, z)
			w.rotation.z = PI / 2
			add_child(w)
			var wb := MeshBatch.new()
			wb.cylinder(0.45, 0.34, Vector3.ZERO, Color("1c1d1f"), rubber, -1.0, Vector3.ZERO, 16)
			wb.cylinder(0.26, 0.36, Vector3.ZERO, Color("b9c0c6"), steel, -1.0, Vector3.ZERO, 8)
			wb.box(Vector3(0.1, 0.37, 0.3), Vector3.ZERO, Color("6d747a"), steel)
			wb.build(w)
			_wheels.append(w)
	_cargo = Node3D.new()
	add_child(_cargo)
	var cb := MeshBatch.new()
	var supplier := color == Palette.TRUCK_SUPPLIER
	for i in 6:
		var p := Vector3(-0.5 + (i % 2) * 1.0, 0.86, -1.75 + (i / 2) * 0.98)
		Palette.pallet(cb, p, Vector2(0.92, 0.92))
		if supplier:
			cb.box(Vector3(0.82, 0.55, 0.82), p + Vector3(0, 0.4, 0), Palette.PELLET_BAG)
			cb.box(Vector3(0.28, 0.18, 0.01), p + Vector3(0, 0.42, 0.415), Color("4a7fb5"))
		else:
			cb.box(Vector3(0.84, 0.6, 0.84), p + Vector3(0, 0.42, 0), Palette.BOX)
			cb.box(Vector3(0.86, 0.04, 0.86), p + Vector3(0, 0.5, 0), Palette.BOX.darkened(0.2))
	cb.build(_cargo)


func set_cargo_visible(v: bool) -> void:
	_cargo.visible = v


func spin_wheels(amount: float) -> void:
	for w in _wheels:
		w.rotate_object_local(Vector3.UP, amount)
