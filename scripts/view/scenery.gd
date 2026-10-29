## Everything outside the factory fence: pavements, street lamps, a power
## line, the silos and plant behind the hall, the neighbourhood across the
## road, a pond, a farm with fields, hills, wind turbines, woods, grass,
## drifting clouds and traffic. Purely decorative; lamp materials and lights
## are handed to the day/night cycle.
##
## Static pieces are merged into three meshes (see MeshBatch): props that
## cast shadows, ground-level detail and far scenery that do not.
extends Node3D

const BuildingsView := preload("res://scripts/view/buildings_view.gd")
const TRUNK := Color("6b4a2e")
const LEAVES := [Color("4f8a3c"), Color("3f7a34"), Color("5f9c44"), Color("6b8e23"), Color("45803a")]
const PINE := [Color("2f5d33"), Color("35683a"), Color("2a5330")]
const CAR_COLORS := [Color("c62828"), Color("f9a825"), Color("eceff1"), Color("1565c0"), Color("2e7d32"), Color("212121"), Color("78909c")]
const HOUSE_WALLS := [Color("f3e0cf"), Color("f5ecc8"), Color("d9e6d0"), Color("d6e2ee"), Color("efd6dc")]
const HOUSE_ROOFS := [Color("a63c2c"), Color("7d4a2e"), Color("9a3d48"), Color("5d4037"), Color("8f4434")]

## Emissive lamp heads and OmniLights the day/night cycle switches on at dusk.
var lamp_material: StandardMaterial3D
var window_material: StandardMaterial3D
var night_lights: Array[OmniLight3D] = []

var _cars: Array[Node3D] = []
var _clouds: Array[Node3D] = []
var _rotors: Array[Node3D] = []
var _flag: Node3D
var _time := 0.0
var _rng := RandomNumberGenerator.new()

var _b := MeshBatch.new()  # props that cast shadows
var _flat := MeshBatch.new()  # ground-level detail, no shadows
var _far := MeshBatch.new()  # distant scenery, no shadows
var _leaf_segments := 7 if Palette.low_end() else 9
var _paint: Material
var _steel: Material
var _ground: Material
var _paving: Material


func _ready() -> void:
	_rng.seed = 11
	lamp_material = StandardMaterial3D.new()
	lamp_material.albedo_color = Color("fff3c4")
	lamp_material.emission_enabled = true
	lamp_material.emission = Color("ffd27a")
	lamp_material.emission_energy_multiplier = 0.0
	window_material = StandardMaterial3D.new()
	window_material.albedo_color = Color("8fb6d6")
	window_material.roughness = 0.15
	window_material.metallic = 0.4
	window_material.emission_enabled = true
	window_material.emission = Color("ffcf70")
	window_material.emission_energy_multiplier = 0.0
	_paint = Palette.surface("paint")
	_steel = Palette.surface("steel")
	_ground = Palette.surface("ground")
	_paving = Palette.surface("paving")
	_build_pavements_and_lamps()
	_build_power_line()
	_build_gate()
	_build_plant_yard()
	_build_neighbourhood()
	_build_pond()
	_build_farm()
	_build_hills_and_turbines()
	_build_trees()
	_build_rocks()
	_build_flowers()
	_b.build(self)
	_flat.build(self, false)
	_far.build(self, false)
	_build_grass()
	_build_clouds()
	_build_traffic()
	_build_site_lights()


func _process(delta: float) -> void:
	_time += delta
	var speed := maxf(1.0, TimeManager.speed) if TimeManager.speed > 0 else 0.4
	for car in _cars:
		var v: float = car.get_meta("speed")
		car.position.x += v * delta * speed
		if car.position.x > 120.0:
			car.position.x = -120.0 - _rng.randf_range(0, 30)
	for c in _clouds:
		c.position.x += delta * 1.2
		if c.position.x > 130.0:
			c.position.x = -130.0
	for r in _rotors:
		r.rotate_object_local(Vector3.FORWARD, delta * 1.2)
	if _flag:
		_flag.rotation.y = sin(_time * 2.0) * 0.18


## True where decorations may go: not on the lot, road, pond, fields,
## farm or houses.
func _free_spot(p: Vector3, margin := 0.0) -> bool:
	if p.x > -27 - margin and p.x < 27 + margin and p.z > -19 - margin and p.z < 16 + margin:
		return false  # factory lot
	if p.x > 39 - margin and p.x < 117 + margin and p.z > -14 - margin and p.z < 15 + margin:
		return false  # plots for more factories
	if absf(p.z - FactoryLayout.ROAD_Z) < 6.5 + margin:
		return false  # road and pavements
	if p.z > 22 and p.z < 46 and p.x > -38 and p.x < 58:
		return false  # neighbourhood
	if Vector2(p.x + 42, (p.z + 4) * 1.5).length() < 12 + margin:
		return false  # pond
	if p.z < -21 and p.z > -46 and p.x > -27 - margin and p.x < 40 + margin:
		return false  # fields and farm
	return true


# --- Road side -----------------------------------------------------------------

func _build_pavements_and_lamps() -> void:
	var z := FactoryLayout.ROAD_Z
	var slab := Color("bcb8ae")
	# North pavement stops at the two driveways, south pavement runs through
	for span in [Vector2(-210, -1.2), Vector2(3.2, 12.8), Vector2(19.2, 210)]:
		var length: float = span.y - span.x
		_flat.box(Vector3(length, 0.1, 1.6), Vector3((span.x + span.y) / 2.0, 0.05, z - 3.85), slab, _paving)
	_flat.box(Vector3(420, 0.1, 1.6), Vector3(0, 0.05, z + 3.85), slab, _paving)
	for i in range(-105, 106):
		var x := i * 2.0
		_flat.box(Vector3(0.04, 0.104, 1.6), Vector3(x, 0.05, z + 3.85), slab.darkened(0.12))
		if (x < -1.2 or x > 3.2) and (x < 12.8 or x > 19.2):
			_flat.box(Vector3(0.04, 0.104, 1.6), Vector3(x, 0.05, z - 3.85), slab.darkened(0.12))
	# Zebra crossing and a bus stop
	for k in 7:
		_flat.box(Vector3(0.5, 0.012, 4.6), Vector3(-30.0 + k * 0.9, 0.064, z), Color("f2f2ee"))
	_bus_stop(Vector3(-36, 0, z + 4.2))
	for x in range(-84, 85, 14):
		if absf(x - 16) < 4:
			continue
		_lamp(Vector3(x, 0, z - 3.9), 0.0)
		_lamp(Vector3(x + 7, 0, z + 3.9), PI)


func _lamp(pos: Vector3, yaw: float) -> void:
	var keep := _b.origin
	_b.origin = Transform3D(Basis(Vector3.UP, yaw), pos)
	var pole := Color("56616b")
	_b.cylinder(0.14, 0.4, Vector3(0, 0.2, 0), pole, _steel, 0.1, Vector3.ZERO, 10)
	_b.cylinder(0.08, 4.4, Vector3(0, 2.4, 0), pole, _steel, 0.06, Vector3.ZERO, 8)
	_b.bar(Vector3(0, 4.5, 0), Vector3(0, 4.6, 1.1), 0.08, pole, _steel, true)
	_b.box(Vector3(0.36, 0.12, 0.65), Vector3(0, 4.58, 1.15), Color("3a3f44"), _steel)
	_b.box(Vector3(0.3, 0.04, 0.55), Vector3(0, 4.5, 1.15), Color("fff3c4"), lamp_material)
	_b.origin = keep


func _bus_stop(p: Vector3) -> void:
	var glass := Palette.surface("glass")
	for x in [-1.4, 1.4]:
		_b.box(Vector3(0.08, 2.4, 0.08), p + Vector3(x, 1.2, 0.7), Color("3a3f44"), _steel)
	_b.box(Vector3(3.2, 0.1, 1.6), p + Vector3(0, 2.45, 0.2), Color("2f6db5"), _paint)
	_b.box(Vector3(2.8, 1.8, 0.03), p + Vector3(0, 1.3, 0.7), Color.WHITE, glass)
	_b.box(Vector3(2.0, 0.08, 0.4), p + Vector3(0, 0.5, 0.45), Color("8d6e63"))
	_b.cylinder(0.04, 2.6, p + Vector3(2.0, 1.3, -0.4), Color("6d747a"), _steel, -1.0, Vector3.ZERO, 6)
	_b.box(Vector3(0.5, 0.5, 0.04), p + Vector3(2.0, 2.5, -0.4), Color("1565c0"), _paint)


## Wooden poles on the far side of the road carrying three sagging wires.
func _build_power_line() -> void:
	var z := FactoryLayout.ROAD_Z + 5.4
	var prev := []
	for i in range(-5, 6):
		var x := i * 22.0 + 3.0
		var p := Vector3(x, 0, z)
		_b.cylinder(0.15, 9.0, p + Vector3(0, 4.5, 0), Color("6d5442"), null, 0.11, Vector3.ZERO, 8)
		_b.box(Vector3(2.6, 0.14, 0.14), p + Vector3(0, 8.4, 0), Color("5d4037"))
		var tops := []
		for k in 3:
			var t := p + Vector3(-1.1 + k * 1.1, 8.55, 0)
			_b.cylinder(0.05, 0.18, t, Color("8fb3c4"), _paint, 0.035, Vector3.ZERO, 6)
			tops.append(t + Vector3(0, 0.1, 0))
		if not prev.is_empty():
			for k in 3:
				_wire(prev[k], tops[k], 0.6)
		prev = tops
	# Transformer on one pole
	_b.cylinder(0.35, 0.9, Vector3(3.0 + 22.0, 6.6, z + 0.45), Color("8d969d"), _steel)


func _wire(a: Vector3, b: Vector3, sag: float) -> void:
	var segs := 5
	var prev := a
	for i in range(1, segs + 1):
		var t := float(i) / segs
		var p := a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		_flat.bar(prev, p, 0.03, Color("1d2125"), null, false)
		prev = p


func _build_gate() -> void:
	# Sign over the truck driveway, guard booth with a boom barrier and a
	# flagpole beside it.
	for x in [12.6, 19.4]:
		_b.box(Vector3(0.35, 4.2, 0.35), Vector3(x, 2.1, 14.2), Color("37474f"), _paint)
		_b.box(Vector3(0.55, 0.2, 0.55), Vector3(x, 0.1, 14.2), Color("9a9893"), _paving)
	_b.box(Vector3(7.2, 0.9, 0.25), Vector3(16, 4.4, 14.2), Color("1565c0"), _paint)
	_b.box(Vector3(7.3, 0.08, 0.3), Vector3(16, 4.86, 14.2), Color("cfd8dc"), _steel)
	var sign := Palette.label3d(self, "NHÀ MÁY NHỰA", Vector3(16, 4.4, 14.4), 44, Color.WHITE)
	sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sign.no_depth_test = false
	sign.outline_size = 0
	var booth := Vector3(9.6, 0, 12.9)
	_b.box(Vector3(1.6, 0.25, 1.6), booth + Vector3(0, 0.125, 0), Color("9a9893"), _paving)
	_b.box(Vector3(1.4, 2.2, 1.4), booth + Vector3(0, 1.35, 0), Color("eceff1"), _paint)
	_b.box(Vector3(1.42, 0.7, 1.2), booth + Vector3(0, 1.75, 0), Color("4d6378"), _paint)
	_b.box(Vector3(1.8, 0.12, 1.8), booth + Vector3(0, 2.5, 0), Color("37474f"), _paint)
	_b.box(Vector3(0.3, 0.9, 0.3), Vector3(12.4, 0.45, 15.2), Color("eceff1"), _paint)
	for k in 6:
		_b.box(Vector3(0.6, 0.1, 0.1), Vector3(12.85 + k * 0.6 + 0.3, 0.85, 15.2), Color("d32f2f") if k % 2 == 0 else Color("f5f5f5"), _paint)
	_b.cylinder(0.07, 7.0, Vector3(7.6, 3.5, 13.0), Color("cfd8dc"), _steel, 0.05, Vector3.ZERO, 8)
	_b.sphere(0.1, Vector3(7.6, 7.05, 13.0), Color("ffd54f"), _steel)
	_flag = Node3D.new()
	_flag.position = Vector3(7.6, 6.3, 13.0)
	add_child(_flag)
	var fb := MeshBatch.new()
	fb.box(Vector3(1.6, 1.0, 0.03), Vector3(0.82, 0, 0), Color("d32f2f"))
	fb.box(Vector3(0.36, 0.36, 0.04), Vector3(0.82, 0, 0), Color("ffd54f"), null, Vector3(0, 0, PI / 4))
	fb.build(_flag)


## Behind the hall: two pellet silos feeding the plant, a chiller and a
## transformer.
func _build_plant_yard() -> void:
	var z := -14.3
	for x in [9.0, 12.4]:
		var p := Vector3(x, 0, z)
		for k in 4:
			var a := PI / 4 + k * PI / 2
			_b.box(Vector3(0.14, 2.6, 0.14), p + Vector3(cos(a) * 0.8, 1.3, sin(a) * 0.8), Color("8d969d"), _steel)
		_b.cylinder(0.15, 1.3, p + Vector3(0, 2.75, 0), Color("cfd4d8"), _steel, 1.25, Vector3.ZERO, 16)
		_b.cylinder(1.25, 5.0, p + Vector3(0, 5.9, 0), Color("dfe3e6"), _steel, -1.0, Vector3.ZERO, 16)
		for k in 4:
			_b.cylinder(1.27, 0.06, p + Vector3(0, 4.1 + k * 1.2, 0), Color("b9c0c6"), _steel, -1.0, Vector3.ZERO, 16)
		_b.cylinder(1.3, 0.7, p + Vector3(0, 8.75, 0), Color("cfd4d8"), _steel, 0.2, Vector3.ZERO, 16)
		_b.box(Vector3(0.5, 7.5, 0.06), p + Vector3(0, 4.4, 1.3), Color("6d747a"), _steel)
		_b.bar(p + Vector3(0, 8.9, 0), Vector3(x - 1.5, 5.7, -12.3), 0.16, Color("b9c0c6"), _steel, true)
		_b.box(Vector3(1.6, 0.7, 0.03), p + Vector3(0, 6.2, 1.27), Color("1565c0"), _paint)
	# Chiller units with fans
	for i in 2:
		var c := Vector3(-8.0 + i * 3.4, 0, -14.4)
		_b.box(Vector3(3.0, 1.5, 1.6), c + Vector3(0, 0.85, 0), Color("dfe3e6"), _paint)
		_b.box(Vector3(3.1, 0.1, 1.7), c + Vector3(0, 0.05, 0), Color("6d747a"), _steel)
		for k in 2:
			_b.cylinder(0.55, 0.12, c + Vector3(-0.72 + k * 1.44, 1.66, 0), Color("3a3f44"), _steel, -1.0, Vector3.ZERO, 16)
			_b.box(Vector3(0.9, 0.03, 0.05), c + Vector3(-0.72 + k * 1.44, 1.73, 0), Color("8d969d"), _steel, Vector3(0, 0.6 + k, 0))
		for k in 6:
			_b.box(Vector3(2.8, 0.04, 0.02), c + Vector3(0, 0.35 + k * 0.18, 0.81), Color("8d969d"), _steel)
	_b.bar(Vector3(-8, 1.2, -13.6), Vector3(-8, 1.2, -12.2), 0.18, Color("2f6db5"), _paint, true)
	_b.bar(Vector3(-4.6, 1.2, -13.6), Vector3(-4.6, 1.2, -12.2), 0.18, Color("2f6db5"), _paint, true)
	# Transformer in a fenced pen
	var t := Vector3(-20.5, 0, -14.6)
	_b.box(Vector3(1.6, 1.6, 1.2), t + Vector3(0, 0.9, 0), Color("6f8f6a"), _paint)
	for k in 7:
		_b.box(Vector3(0.05, 1.3, 1.25), t + Vector3(-0.75 + k * 0.25, 0.85, 0), Color("5f7d5a"), _paint)
	for k in 3:
		_b.cylinder(0.07, 0.5, t + Vector3(-0.5 + k * 0.5, 1.95, 0), Color("8a6d4f"), _paint, 0.05, Vector3.ZERO, 8)
	_b.box(Vector3(2.0, 0.15, 1.6), t + Vector3(0, 0.075, 0), Color("9a9893"), _paving)


# --- Neighbourhood across the road ----------------------------------------------

func _build_neighbourhood() -> void:
	var z0 := FactoryLayout.ROAD_Z + 6.0
	_build_neighbour_factory(Vector3(-22, 0, z0 + 9))
	for i in 5:
		_house(Vector3(4 + i * 9.0, 0, z0 + 5 + (i % 2) * 2.0), i)
	_build_shop(Vector3(50, 0, z0 + 5))


func _build_neighbour_factory(o: Vector3) -> void:
	var w := 22.0
	var d := 14.0
	var wall := Color("aab4bb")
	_b.box(Vector3(w, 0.6, d), o + Vector3(0, 0.3, 0), Color("8f8c86"), _paving)
	_b.box(Vector3(w, 4.6, d), o + Vector3(0, 2.9, 0), wall)
	for i in int(w / 0.7):
		_b.box(Vector3(0.08, 4.4, 0.05), o + Vector3(-w / 2.0 + 0.35 + i * 0.7, 2.9, -d / 2.0 - 0.02), wall.darkened(0.1))
	# Sawtooth roof with glazed north lights
	for i in 5:
		var x := -8.8 + i * 4.4
		_b.prism(Vector3(4.4, 1.6, d), o + Vector3(x, 6.0, 0), Color("6b7b86"), _steel, 1.0)
		_b.box(Vector3(0.05, 1.5, d - 0.4), o + Vector3(x + 2.17, 6.0, 0), Color("8fb6d6"), window_material)
	_b.box(Vector3(w + 0.3, 0.2, d + 0.3), o + Vector3(0, 5.25, 0), Color("56616b"), _steel)
	for i in 6:
		if i == 2 or i == 4:
			continue  # roller doors there
		var win := o + Vector3(-8.5 + i * 3.4, 2.8, -d / 2.0 - 0.04)
		_b.box(Vector3(2.2, 1.4, 0.04), win - Vector3(0, 0, 0.005), Color("3a3f44"), _steel)
		_b.box(Vector3(2.0, 1.2, 0.05), win, Color("8fb6d6"), window_material)
	# Roller doors with a canopy
	for k in 2:
		var door := o + Vector3(-1.7 + k * 6.8, 0, -d / 2.0 - 0.05)
		_b.box(Vector3(4.0, 3.4, 0.06), door + Vector3(0, 2.0, 0), Color("6d747a"), _steel)
		for r in 10:
			_b.box(Vector3(4.0, 0.03, 0.08), door + Vector3(0, 0.5 + r * 0.32, 0), Color("56616b"), _steel)
		_b.box(Vector3(4.6, 0.12, 1.4), door + Vector3(0, 4.0, -0.65), Color("37474f"), _paint)
	# Chimney with red and white bands, a tank and a pipe bridge
	var ch := o + Vector3(9, 0, 4)
	_b.cylinder(0.9, 12.0, ch + Vector3(0, 6.0, 0), Color("8d6e63"), null, 0.65, Vector3.ZERO, 14)
	for k in 3:
		_b.cylinder(0.72 - k * 0.03, 0.8, ch + Vector3(0, 9.0 + k * 1.2, 0), Color("c62828") if k % 2 == 0 else Color("f5f5f5"), _paint, 0.7 - k * 0.03, Vector3.ZERO, 14)
	_b.cylinder(1.6, 4.0, o + Vector3(-13.5, 2.0, 3), Color("dfe3e6"), _steel, -1.0, Vector3.ZERO, 16)
	_b.sphere(1.6, o + Vector3(-13.5, 4.0, 3), Color("dfe3e6"), _steel, Vector3(1, 0.35, 1), 16, 6)
	_b.bar(o + Vector3(-13.5, 3.6, 3), o + Vector3(-11, 4.2, 3), 0.2, Color("b9c0c6"), _steel, true)
	var smoke := CPUParticles3D.new()
	smoke.position = ch + Vector3(0, 12.2, 0)
	smoke.amount = 14
	smoke.lifetime = 6.0
	smoke.direction = Vector3(0.3, 1, 0)
	smoke.spread = 12.0
	smoke.initial_velocity_min = 0.8
	smoke.initial_velocity_max = 1.4
	smoke.gravity = Vector3(0.25, 0.05, 0)
	smoke.scale_amount_min = 1.2
	smoke.scale_amount_max = 2.4
	var sm := SphereMesh.new()
	sm.radius = 0.6
	sm.height = 1.2
	sm.radial_segments = 8
	sm.rings = 4
	smoke.mesh = sm
	smoke.material_override = Palette.mat(Color(0.85, 0.85, 0.85, 0.5))
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(smoke)
	_flat.box(Vector3(w + 4, 0.04, 3.0), o + Vector3(0, 0.02, -d / 2.0 - 1.5), Color("8a8d90"), _paving)
	Palette.label3d(self, "Xưởng cơ khí bên cạnh", o + Vector3(0, 8.5, 0), 30, Color("eceff1"))


## A house with a pitched roof, chimney, windows, porch, picket fence,
## a front path and a garden tree.
func _house(p: Vector3, i: int) -> void:
	var wall: Color = HOUSE_WALLS[i % HOUSE_WALLS.size()]
	var roof: Color = HOUSE_ROOFS[i % HOUSE_ROOFS.size()]
	var front := p.z - 2.5
	_b.box(Vector3(6.2, 0.4, 5.2), p + Vector3(0, 0.2, 0), Color("9a9893"), _paving)
	_b.box(Vector3(6, 3.0, 5), p + Vector3(0, 1.9, 0), wall)
	_b.box(Vector3(6.05, 0.15, 5.05), p + Vector3(0, 3.38, 0), wall.darkened(0.15))
	_b.prism(Vector3(6.8, 2.0, 5.8), p + Vector3(0, 4.45, 0), roof)
	_b.box(Vector3(0.7, 1.6, 0.7), p + Vector3(1.8, 4.9, 1.0), Color("8d6e63"))
	_b.box(Vector3(0.8, 0.1, 0.8), p + Vector3(1.8, 5.73, 1.0), Color("5d4037"))
	# Door with a porch roof, windows with frames and shutters
	_b.box(Vector3(1.0, 1.9, 0.08), Vector3(p.x, 1.35, front - 0.02), Color("6d4c41"))
	_b.box(Vector3(0.08, 0.08, 0.06), Vector3(p.x + 0.35, 1.3, front - 0.08), Color("d4af37"), _steel)
	_b.box(Vector3(1.8, 0.1, 1.0), Vector3(p.x, 2.45, front - 0.5), roof.darkened(0.1), null, Vector3(-0.2, 0, 0))
	for x in [-0.8, 0.8]:
		_b.box(Vector3(0.1, 2.0, 0.1), Vector3(p.x + x, 1.4, front - 0.9), Color("eceff1"))
	for x in [-1.9, 1.9]:
		var c := Vector3(p.x + x, 1.95, front - 0.03)
		_b.box(Vector3(1.24, 1.04, 0.06), c, Color("f5f5f5"))
		_b.box(Vector3(1.1, 0.9, 0.07), c - Vector3(0, 0, 0.01), Color("8fb6d6"), window_material)
		_b.box(Vector3(1.1, 0.05, 0.08), c - Vector3(0, 0, 0.015), Color("f5f5f5"))
		for s in [-1, 1]:
			_b.box(Vector3(0.35, 1.0, 0.05), c + Vector3(s * 0.82, 0, 0), roof.darkened(0.2))
		_b.box(Vector3(1.0, 0.25, 0.3), c + Vector3(0, -0.65, -0.15), Color("6d4c41"))
		for k in 3:
			_b.sphere(0.12, c + Vector3(-0.3 + k * 0.3, -0.45, -0.15), [Color("ec407a"), Color("ffee58"), Color("ff7043")][k], null, Vector3.ONE, 6, 4)
	# Front path, picket fence with a gate gap, hedge and a garden tree
	var fz := p.z - 6.2 if i % 2 == 0 else p.z - 8.2
	_flat.box(Vector3(1.0, 0.03, front - fz), Vector3(p.x, 0.015, (front + fz) / 2.0), Color("b9b0a2"), _paving)
	for side in [-1, 1]:
		var x0: float = p.x + side * 0.7
		var x1: float = p.x + side * 3.9
		_b.box(Vector3(absf(x1 - x0), 0.06, 0.04), Vector3((x0 + x1) / 2.0, 0.65, fz), Color("f5f5f5"))
		_b.box(Vector3(absf(x1 - x0), 0.06, 0.04), Vector3((x0 + x1) / 2.0, 0.35, fz), Color("f5f5f5"))
		for k in 9:
			_b.box(Vector3(0.08, 0.85, 0.03), Vector3(x0 + (x1 - x0) * k / 8.0, 0.43, fz + 0.03), Color("f5f5f5"))
	_b.box(Vector3(0.3, 1.0, 0.3), Vector3(p.x + 3.4, 0.5, fz + 0.4), Color("37474f"), _paint)
	_b.box(Vector3(0.4, 0.3, 0.5), Vector3(p.x + 3.4, 1.1, fz + 0.4), Color("c62828"), _paint)
	_tree(Vector3(p.x - 4.3, 0, p.z - 0.5), 0.75, false)
	for k in 4:
		_b.sphere(0.5, Vector3(p.x + 3.2, 0.4, p.z - 3.4 + k * 0.9), Color("3f6e2e"), null, Vector3(1, 0.8, 1), 8, 5)


func _build_shop(o: Vector3) -> void:
	_b.box(Vector3(7.2, 0.3, 6.2), o + Vector3(0, 0.15, 0), Color("9a9893"), _paving)
	_b.box(Vector3(7, 3.4, 6), o + Vector3(0, 2.0, 0), Color("eceff1"))
	_b.box(Vector3(7.2, 0.5, 6.2), o + Vector3(0, 3.95, 0), Color("c62828"), _paint)
	for i in 7:
		var c := Color("c62828") if i % 2 == 0 else Color.WHITE
		_b.box(Vector3(1.0, 0.06, 1.6), o + Vector3(-3.0 + i * 1.0, 3.0, -3.65), c, _paint, Vector3(0.35, 0, 0))
	_b.box(Vector3(5.2, 1.8, 0.06), o + Vector3(-0.5, 1.6, -3.02), Color("3a3f44"), _steel)
	_b.box(Vector3(5.0, 1.6, 0.07), o + Vector3(-0.5, 1.6, -3.03), Color("8fb6d6"), window_material)
	_b.box(Vector3(1.1, 2.2, 0.08), o + Vector3(2.7, 1.4, -3.03), Color("455a64"), _steel)
	_b.box(Vector3(0.6, 0.9, 0.5), o + Vector3(3.8, 0.6, -3.4), Color("1565c0"), _paint)
	for k in 3:
		_b.box(Vector3(0.6, 0.12, 0.5), o + Vector3(-3.0 + k * 1.3, 0.4, -4.4), Color("8d6e63"))
	Palette.label3d(self, "Tạp hoá", o + Vector3(0, 4.6, -3), 30)


# --- Nature ------------------------------------------------------------------------

func _build_pond() -> void:
	var c := Vector3(-42, 0, -4)
	var sx := Vector3(1.0, 1.0, 0.65)
	_flat.cylinder(10.4, 0.05, c + Vector3(0, 0.02, 0), Color("a89a72"), _ground, -1.0, Vector3.ZERO, 32, Vector3(1, 1, 0.68))
	_flat.cylinder(9.6, 0.06, c + Vector3(0, 0.03, 0), Color("5b5a3f"), _ground, -1.0, Vector3.ZERO, 32, Vector3(1, 1, 0.66))
	_flat.cylinder(9.0, 0.06, c + Vector3(0, 0.06, 0), Color("3f7aa6"), Palette.surface("water"), -1.0, Vector3.ZERO, 32, sx)
	_flat.cylinder(5.5, 0.061, c + Vector3(0.5, 0.062, -0.3), Color("2f6690"), Palette.surface("water"), -1.0, Vector3.ZERO, 24, sx)
	# Reeds in clumps, lily pads and stones on the shore
	for i in 10:
		var a := _rng.randf() * TAU
		var p := c + Vector3(cos(a) * 9.1, 0, sin(a) * 6.0)
		for k in 6:
			var o := Vector3(_rng.randf_range(-0.5, 0.5), 0, _rng.randf_range(-0.5, 0.5))
			var h := _rng.randf_range(0.8, 1.5)
			_b.cylinder(0.03, h, p + o + Vector3(0, h / 2.0, 0), Color("7a9a3a"), null, 0.0, Vector3(_rng.randf_range(-0.15, 0.15), 0, _rng.randf_range(-0.15, 0.15)), 4)
			if k == 0:
				_b.cylinder(0.05, 0.25, p + o + Vector3(0, h - 0.1, 0), Color("6b4a2e"), null, -1.0, Vector3.ZERO, 6)
	for i in 12:
		var p := c + Vector3(_rng.randf_range(-6, 6), 0.1, _rng.randf_range(-3.5, 3.5))
		_flat.cylinder(0.35, 0.02, p, Color("4f8a3c"), null, -1.0, Vector3.ZERO, 8)
		if i % 4 == 0:
			_flat.sphere(0.1, p + Vector3(0.1, 0.06, 0), Color("f8bbd0"), null, Vector3(1, 0.6, 1), 6, 4)
	for i in 14:
		var a := _rng.randf() * TAU
		_b.sphere(_rng.randf_range(0.25, 0.55), c + Vector3(cos(a) * 9.7, 0.05, sin(a) * 6.4), Color("8a8a84").darkened(_rng.randf() * 0.2), null, Vector3(1.2, 0.6, 1.0), 7, 4)
	# Bench, and a jetty on posts
	_b.box(Vector3(2.0, 0.08, 0.5), c + Vector3(0, 0.48, 7.4), Color("8d6e63"))
	_b.box(Vector3(2.0, 0.45, 0.06), c + Vector3(0, 0.8, 7.68), Color("8d6e63"), null, Vector3(-0.15, 0, 0))
	for x in [-0.85, 0.85]:
		_b.box(Vector3(0.08, 0.48, 0.5), c + Vector3(x, 0.24, 7.45), Color("3a3f44"), _steel)
	_b.box(Vector3(1.4, 0.1, 4.0), c + Vector3(6, 0.3, 3.5), Color("a1887f"))
	for k in 8:
		_b.box(Vector3(1.4, 0.02, 0.04), c + Vector3(6, 0.36, 1.7 + k * 0.5), Color("7b5e4f"))
	for x in [5.4, 6.6]:
		for z in [1.8, 3.5, 5.2]:
			_b.cylinder(0.07, 0.8, c + Vector3(x, 0.1, z), Color("6d4c41"), null, -1.0, Vector3.ZERO, 6)
	# Ducks
	for i in 3:
		var d := Vector3(c.x - 3 + i * 1.4, 0.2, c.z + 1 - i * 0.6)
		_b.sphere(0.25, d, Color.WHITE if i > 0 else Color("8d6e63"), null, Vector3(1.3, 0.8, 1.0), 8, 5)
		_b.sphere(0.12, d + Vector3(0.26, 0.2, 0), Color("2e7d32"), null, Vector3.ONE, 6, 4)
		_b.box(Vector3(0.12, 0.04, 0.06), d + Vector3(0.4, 0.18, 0), Color("f9a825"))


## Fields with crop rows, a barn, a silo, hay bales, a tractor and a fence.
func _build_farm() -> void:
	var soil := Color("7a5a3c")
	var colors := [Color("9ccc65"), Color("c0ca33"), Color("8bc34a"), Color("d4c25a")]
	for f in 3:
		var x0 := -24.0 + f * 14.0
		var col: Color = colors[f % colors.size()]
		_flat.box(Vector3(13.0, 0.08, 20.0), Vector3(x0 + 6.5, 0.04, -33.0), soil, _ground)
		for i in 16:
			_flat.box(Vector3(12.4, 0.28, 0.55), Vector3(x0 + 6.5, 0.14, -42.0 + i * 1.2), col.darkened(0.05 * (i % 2)), _ground)
	# Wheat field ready for harvest
	_flat.box(Vector3(13.0, 0.5, 20.0), Vector3(26.5, 0.25, -33.0), Color("d8b75a"), _ground)
	# Barn, silo and hay bales
	var barn := Vector3(31, 0, -16.5)
	_b.box(Vector3(8, 4.0, 6), barn + Vector3(0, 2.0, 0), Color("a83a2a"))
	_b.prism(Vector3(8.6, 2.4, 6.6), barn + Vector3(0, 5.2, 0), Color("4a4f54"), _steel, 0.5, Vector3(0, PI / 2, 0))
	_b.box(Vector3(3.0, 3.0, 0.08), barn + Vector3(0, 1.5, -3.02), Color("e8e4dc"))
	_b.box(Vector3(2.8, 2.8, 0.1), barn + Vector3(0, 1.5, -3.04), Color("8d2f22"))
	_b.bar(barn + Vector3(-1.4, 0.1, -3.1), barn + Vector3(1.4, 2.9, -3.1), 0.12, Color("e8e4dc"))
	_b.bar(barn + Vector3(1.4, 0.1, -3.1), barn + Vector3(-1.4, 2.9, -3.1), 0.12, Color("e8e4dc"))
	_b.cylinder(1.4, 8.0, barn + Vector3(5.8, 4.0, 1.0), Color("b0bec5"), _steel, -1.0, Vector3.ZERO, 16)
	_b.sphere(1.4, barn + Vector3(5.8, 8.0, 1.0), Color("90a4ae"), _steel, Vector3(1, 0.6, 1), 16, 6)
	for k in 5:
		_b.cylinder(0.65, 1.1, barn + Vector3(-5.5 + (k % 3) * 1.4, 0.65 + (k / 3) * 1.25, -4.5 - (k % 2) * 0.3), Color("d9b85c"), null, -1.0, Vector3(0, 0, PI / 2), 12)
	_tractor(barn + Vector3(-1.0, 0, -6.8))
	# Farm fence along the road side of the fields
	for i in 33:
		var x := -26.0 + i * 2.0
		_b.box(Vector3(0.12, 1.1, 0.12), Vector3(x, 0.55, -22.0), Color("8d6e63"))
	_b.box(Vector3(64.0, 0.08, 0.06), Vector3(6.0, 0.9, -22.0), Color("8d6e63"))
	_b.box(Vector3(64.0, 0.08, 0.06), Vector3(6.0, 0.5, -22.0), Color("8d6e63"))
	_flat.box(Vector3(3.0, 0.04, 30.0), Vector3(36.5, 0.02, -8.0), Color("9c8a6a"), _ground)


func _tractor(p: Vector3) -> void:
	var green := Color("2e7d32")
	var rubber := Palette.surface("rubber")
	_b.box(Vector3(1.3, 0.8, 2.2), p + Vector3(0, 1.0, 0.3), green, _paint)
	_b.box(Vector3(1.2, 1.1, 1.1), p + Vector3(0, 1.95, -0.3), Color("26323e"), _paint)
	_b.box(Vector3(1.35, 0.08, 1.25), p + Vector3(0, 2.55, -0.3), green, _paint)
	_b.cylinder(0.08, 0.8, p + Vector3(0.4, 1.8, 1.0), Color("3a3f44"), _steel, -1.0, Vector3.ZERO, 8)
	for x in [-0.85, 0.85]:
		_b.cylinder(0.75, 0.45, p + Vector3(x, 0.75, -0.5), Color("1c1d1f"), rubber, -1.0, Vector3(0, 0, PI / 2), 16)
		_b.cylinder(0.42, 0.47, p + Vector3(x, 0.75, -0.5), Color("f9a825"), _paint, -1.0, Vector3(0, 0, PI / 2), 10)
		_b.cylinder(0.42, 0.3, p + Vector3(x * 0.85, 0.42, 1.2), Color("1c1d1f"), rubber, -1.0, Vector3(0, 0, PI / 2), 12)


func _build_hills_and_turbines() -> void:
	var hills := [[Vector3(-70, 0, -62), 26.0], [Vector3(-25, 0, -76), 32.0], [Vector3(30, 0, -70), 28.0], [Vector3(76, 0, -52), 22.0], [Vector3(-92, 0, 10), 20.0], [Vector3(112, 0, 52), 18.0], [Vector3(-60, 0, 70), 22.0], [Vector3(40, 0, 78), 26.0]]
	var shades := [Color("5f9148"), Color("6a9c50"), Color("57873f"), Color("729f55")]
	for i in hills.size():
		var h: Array = hills[i]
		var r: float = h[1]
		_far.sphere(r, h[0], shades[i % shades.size()], _ground, Vector3(1.0, 0.32, 0.8), 20, 8)
		# A cap of woodland on each hill
		for k in 9:
			var a := _rng.randf() * TAU
			var d := _rng.randf_range(0.0, r * 0.55)
			var base: Vector3 = h[0] + Vector3(cos(a) * d, 0, sin(a) * d * 0.8)
			var top := r * 0.32 * sqrt(maxf(0.0, 1.0 - pow(d / r, 2.0)))
			var s := _rng.randf_range(1.2, 2.2)
			_far.cylinder(1.4 * s, 3.4 * s, base + Vector3(0, top + 1.2 * s, 0), PINE[k % PINE.size()], null, 0.0, Vector3.ZERO, 7)
	# Wind turbines on the far hills
	for p in [Vector3(-32, 0, -54), Vector3(-15, 0, -58), Vector3(3, 0, -54)]:
		_far.cylinder(0.45, 20, p + Vector3(0, 10, 0), Color("f2f4f5"), _paint, 0.22, Vector3.ZERO, 12)
		_far.box(Vector3(0.8, 0.8, 1.8), p + Vector3(0, 20.2, 0.2), Color("eef0f1"), _paint)
		var hub := Node3D.new()
		hub.position = p + Vector3(0, 20.2, 1.25)
		add_child(hub)
		var hb := MeshBatch.new()
		hb.sphere(0.45, Vector3.ZERO, Color("eeeeee"), _paint, Vector3(1, 1, 1.4))
		for k in 3:
			var a := k * TAU / 3.0
			var dir := Vector3(sin(a), cos(a), 0)
			hb.bar(dir * 0.3, dir * 8.0, 0.32, Color("fafafa"), _paint)
		hb.build(hub, false)
		hub.rotation.z = _rng.randf() * TAU
		_rotors.append(hub)


func _build_trees() -> void:
	var placed := 0
	var tries := 0
	var target := 80 if Palette.low_end() else 130
	while placed < target and tries < 1200:
		tries += 1
		var p := Vector3(_rng.randf_range(-110, 110), 0, _rng.randf_range(-70, 75))
		if not _free_spot(p):
			continue
		var r := _rng.randi() % 5
		_tree(p, _rng.randf_range(0.8, 1.5), r <= 1)
		placed += 1
		# Most trees grow in small groves
		if r == 2:
			_bush(p + Vector3(_rng.randf_range(-2, 2), 0, _rng.randf_range(-2, 2)), _rng.randf_range(0.7, 1.2))
	# A neat row of trees along the front fence
	for x in [-22, -16, -10, 6, 22]:
		_tree(Vector3(x, 0, 15.0), 0.7, false)


func _tree(p: Vector3, s: float, pine: bool) -> void:
	if pine:
		_b.cylinder(0.18 * s, 1.4 * s, p + Vector3(0, 0.7 * s, 0), TRUNK, null, 0.12 * s, Vector3.ZERO, 6)
		var col: Color = PINE[_rng.randi() % PINE.size()]
		for k in 4:
			var r := (1.5 - k * 0.3) * s
			_b.cylinder(r, 1.7 * s, p + Vector3(0, (1.6 + k * 0.95) * s, 0), col.lightened(k * 0.04), null, 0.0, Vector3(0, k * 0.4, 0), 8)
		return
	_b.cylinder(0.24 * s, 2.0 * s, p + Vector3(0, 1.0 * s, 0), TRUNK, null, 0.15 * s, Vector3.ZERO, 7)
	_b.bar(p + Vector3(0, 1.6 * s, 0), p + Vector3(0.6 * s, 2.4 * s, 0.2 * s), 0.12 * s, TRUNK)
	var leaf: Color = LEAVES[_rng.randi() % LEAVES.size()]
	var clumps := [[Vector3(0, 2.7, 0), 1.35], [Vector3(0.75, 2.5, 0.35), 0.95], [Vector3(-0.65, 2.45, -0.3), 0.9], [Vector3(0.1, 3.35, -0.2), 0.95], [Vector3(-0.2, 2.3, 0.7), 0.8]]
	for k in clumps.size():
		var c: Array = clumps[k]
		var shade := leaf.lightened(0.05) if k == 3 else leaf.darkened(0.04 * (k % 2))
		_b.sphere(c[1] * s, p + c[0] * s, shade, null, Vector3(1.0, 0.85, 1.0), _leaf_segments, _leaf_segments - 4)


func _bush(p: Vector3, s: float) -> void:
	var col: Color = LEAVES[_rng.randi() % LEAVES.size()]
	for k in 3:
		_b.sphere((0.6 - k * 0.1) * s, p + Vector3((k - 1) * 0.45 * s, 0.35 * s, (k % 2) * 0.3 * s), col.darkened(0.08), null, Vector3(1, 0.75, 1), 8, 5)


func _build_rocks() -> void:
	var n := 0
	while n < 24:
		var p := Vector3(_rng.randf_range(-100, 100), 0, _rng.randf_range(-65, 70))
		if not _free_spot(p, 1.0):
			continue
		var r := _rng.randf_range(0.3, 0.9)
		_b.sphere(r, p + Vector3(0, r * 0.2, 0), Color("8f8d86").darkened(_rng.randf() * 0.25), null, Vector3(1.3, 0.6, 1.0), 7, 4)
		if n % 2 == 0:
			_b.sphere(r * 0.5, p + Vector3(r * 0.9, r * 0.1, r * 0.4), Color("9a978f"), null, Vector3(1.2, 0.6, 1.0), 6, 4)
		n += 1


func _build_flowers() -> void:
	var colors := [Color("ec407a"), Color("ffee58"), Color("ff7043"), Color("ab47bc"), Color.WHITE]
	for bed in [[Vector3(-17.5, 0, 13.6), 8.0], [Vector3(5, 0, 13.6), 7.0], [Vector3(-8.5, 0, 5.8), 2.0]]:
		var c: Vector3 = bed[0]
		var w: float = bed[1]
		_b.box(Vector3(w + 0.2, 0.22, 0.78), c + Vector3(w / 2.0, 0.11, 0), Color("9a9893"), _paving)
		_flat.box(Vector3(w, 0.03, 0.7), c + Vector3(w / 2.0, 0.22, 0), Color("4e3424"), _ground)
		for i in int(w * 3):
			var p := c + Vector3(0.2 + i * 0.33, 0.3, _rng.randf_range(-0.2, 0.2))
			_b.sphere(0.09, p + Vector3(0, -0.04, 0), Color("3f7a34"), null, Vector3(1.4, 0.8, 1.4), 6, 4)
			_b.sphere(0.08, p + Vector3(0, 0.06, 0), colors[_rng.randi() % colors.size()], null, Vector3.ONE, 6, 4)


## Thousands of grass tufts drawn as one MultiMesh.
func _build_grass() -> void:
	var tuft := MeshBatch.new()
	for k in 3:
		var a := k * TAU / 3.0
		tuft.cylinder(0.05, 0.38, Vector3(cos(a) * 0.06, 0.17, sin(a) * 0.06), Color.WHITE, Palette.surface("ground"), 0.0, Vector3(cos(a) * 0.25, 0, sin(a) * 0.25), 3)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = tuft.build_mesh()
	var target := 1200 if Palette.low_end() else 3500
	var xforms: Array[Transform3D] = []
	var tries := 0
	while xforms.size() < target and tries < target * 4:
		tries += 1
		var p := Vector3(_rng.randf_range(-120, 120), 0, _rng.randf_range(-80, 85))
		if not _free_spot(p, -2.0):
			continue
		var s := _rng.randf_range(0.7, 1.6)
		xforms.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.8, 1.3), s)), p))
	mm.instance_count = xforms.size()
	var greens := [Color("6aa04c"), Color("5c9442"), Color("7cab52"), Color("8aa850"), Color("4f8a3c")]
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, greens[_rng.randi() % greens.size()])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _build_clouds() -> void:
	for i in 10:
		var c := Node3D.new()
		c.position = Vector3(_rng.randf_range(-130, 130), _rng.randf_range(28, 36), _rng.randf_range(-70, 50))
		add_child(c)
		var cb := MeshBatch.new()
		var puffs := _rng.randi_range(4, 7)
		for k in puffs:
			var r := _rng.randf_range(2.2, 4.2)
			cb.sphere(r, Vector3(k * 2.6 - puffs * 1.3, _rng.randf_range(0.0, 1.0) + (0.6 if k % 2 == 1 else 0.0), _rng.randf_range(-1.6, 1.6)), Color("fbfbfb"), null, Vector3(1.25, 0.62, 1.0), 10, 6)
		cb.sphere(puffs * 1.5, Vector3(0, -0.6, 0), Color("eef1f4"), null, Vector3(1.0, 0.18, 0.45), 12, 6)
		cb.build(c, false)
		_clouds.append(c)


func _build_traffic() -> void:
	for i in 6:
		var car := BuildingsView._car(self, Vector3(-120 + i * 42 + _rng.randf_range(0, 15), 0, FactoryLayout.ROAD_Z + 1.5), PI / 2, CAR_COLORS[i % CAR_COLORS.size()], lamp_material)
		car.set_meta("speed", _rng.randf_range(5.0, 8.0))
		_cars.append(car)


## Warm yard lights that come on at night.
func _build_site_lights() -> void:
	if OS.has_feature("web"):
		return  # each extra light redraws the scene again in a browser; the lamps still glow
	for p in [Vector3(16, 5, 9), Vector3(1, 5, 10), Vector3(-6, 5, 6.5), Vector3(-13, 5, 1), Vector3(13, 5, -4), Vector3(-6, 5, 22)]:
		var l := OmniLight3D.new()
		l.position = p
		l.omni_range = 16.0
		l.light_color = Color("ffd59a")
		l.light_energy = 0.0
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		night_lights.append(l)
