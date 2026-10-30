## Everything outside the factory fence, set in a Vietnamese industrial
## suburb: pavements with street trees, street lamps, concrete power poles,
## the silos and plant behind the hall, a row of narrow tube houses with
## shops across the road, a pond with coconut palms, rice paddies with a
## farmhouse, haystacks and bamboo, hills, wind turbines, woods, grass,
## drifting clouds, and cars and motorbikes keeping to their lanes. Purely
## decorative; lamp materials and lights are handed to the day/night cycle.
##
## Static pieces are merged into three meshes (see MeshBatch): props that
## cast shadows, ground-level detail and far scenery that do not.
extends Node3D

const BuildingsView := preload("res://scripts/view/buildings_view.gd")
const TRUNK := Color("6b4a2e")
const LEAVES := [Color("4f8a3c"), Color("3f7a34"), Color("5f9c44"), Color("6b8e23"), Color("45803a")]
const PINE := [Color("2f5d33"), Color("35683a"), Color("2a5330")]
const CAR_COLORS := [Color("c62828"), Color("f9a825"), Color("eceff1"), Color("1565c0"), Color("2e7d32"), Color("212121"), Color("78909c")]
const HOUSE_WALLS := [Color("f4e3a1"), Color("cfe8d8"), Color("cfe0f0"), Color("f3d0cc"), Color("f6ead2"), Color("e3d6ef"), Color("ffd9b0"), Color("e4e4dc")]
const SIGN_COLORS := [Color("c62828"), Color("1565c0"), Color("f9a825"), Color("2e7d32"), Color("6a1b9a"), Color("ef6c00")]
const AWNINGS := [Color("1e88e5"), Color("43a047"), Color("e53935"), Color("fb8c00")]
const SHIRTS := [Color("eceff1"), Color("1565c0"), Color("c62828"), Color("2e7d32"), Color("f9a825"), Color("6d4c41"), Color("90a4ae")]
## Traffic lanes (right-hand traffic): eastbound cars, eastbound motorbikes
## by the kerb, westbound motorbikes, and the lane they swerve into to pass a
## truck stopped at the factory gate. Every vehicle in a lane keeps the same
## speed so nothing drives through anything.
const LANE_CARS := 20.4
const LANE_BIKES_EAST := 21.6
const LANE_BIKES_WEST := 16.6
const LANE_PASSING := 19.3
## Trees on the far pavement (x, at z = ROAD_Z + 4).
const FAR_STREET_TREES := [-46.0, -14.0, 0.0, 14.0, 28.0, 42.0, 56.0]

## Emissive lamp heads and OmniLights the day/night cycle switches on at dusk.
var lamp_material: StandardMaterial3D
var window_material: StandardMaterial3D
var night_lights: Array[OmniLight3D] = []

var _cars: Array[Node3D] = []  # cars and motorbikes
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
	var trucks := get_tree().get_nodes_in_group("road_trucks")
	for car in _cars:
		var v: float = car.get_meta("speed")
		car.position.x = wrapf(car.position.x + v * delta * speed, -120.0, 120.0)
		if v < 0.0:
			# Westbound bikes share the gate lane with the trucks: pull out
			# around a truck ahead, then back in.
			var lane := LANE_BIKES_WEST
			for t in trucks:
				var dx: float = car.position.x - t.position.x
				if absf(t.position.z - LANE_BIKES_WEST) < 2.0 and dx > -5.0 and dx < 12.0:
					lane = LANE_PASSING
			car.position.z = move_toward(car.position.z, lane, delta * speed * 1.6)
	# Clouds float between the camera and the ground: hide them when zoomed
	# in close, where one would cover the whole view.
	var cam := get_viewport().get_camera_3d()
	var clouds_on := cam == null or cam.size > 34.0
	for c in _clouds:
		c.visible = clouds_on
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
	if p.z > 22 and p.z < 42 and p.x > -38 and p.x < 66:
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
	for x in FactoryLayout.STREET_TREES:
		_street_tree(Vector3(x, 0, z - 4.0), posmod(int(x), 3))
	for x in FAR_STREET_TREES:
		_street_tree(Vector3(x, 0, z + 4.0), posmod(int(x / 14.0), 3))
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


## A pavement tree in a square grate: shade trees, purple crape myrtle
## (bằng lăng) and red flame trees (phượng).
func _street_tree(p: Vector3, kind: int) -> void:
	var curb := Color("9a978f")
	_flat.box(Vector3(1.1, 0.03, 1.1), p + Vector3(0, 0.1, 0), Color("4e3424"), _ground)
	for k in 4:
		var a := k * PI / 2.0
		_flat.box(Vector3(1.2, 0.14, 0.1), p + Vector3(cos(a) * 0.55, 0.07, sin(a) * 0.55), curb, _paving, Vector3(0, a + PI / 2.0, 0))
	var h := 3.4
	_b.cylinder(0.17, h, p + Vector3(0, h / 2.0, 0), TRUNK.darkened(0.1), null, 0.12, Vector3.ZERO, 7)
	_b.bar(p + Vector3(0, h * 0.75, 0), p + Vector3(0.9, h + 0.4, 0.3), 0.1, TRUNK)
	_b.bar(p + Vector3(0, h * 0.7, 0), p + Vector3(-0.8, h + 0.3, -0.4), 0.1, TRUNK)
	var leaf: Color = [Color("4c8a3a"), Color("9a6fc4"), Color("e0502a")][kind]
	var under := Color("3f7a34")
	var clumps := [[Vector3(0, 0.6, 0), 1.5], [Vector3(1.0, 0.4, 0.4), 1.05], [Vector3(-0.9, 0.35, -0.4), 1.05], [Vector3(0.2, 1.1, -0.3), 1.0], [Vector3(-0.3, 0.3, 0.9), 0.9]]
	for k in clumps.size():
		var c: Array = clumps[k]
		# Flowering trees show green leaves under the blossom.
		var col := under if kind > 0 and k == 0 else leaf.lightened(0.05 * (k % 2))
		_b.sphere(c[1], p + Vector3(0, h, 0) + c[0], col, null, Vector3(1.15, 0.6, 1.15), _leaf_segments, _leaf_segments - 4)


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
		_b.box(Vector3(0.3, 9.0, 0.3), p + Vector3(0, 4.5, 0), Color("a8a49c"), _paving)  # concrete pole
		_b.box(Vector3(2.6, 0.14, 0.14), p + Vector3(0, 8.4, 0), Color("6d747a"), _steel)
		_b.box(Vector3(1.6, 0.1, 0.1), p + Vector3(0, 7.2, 0), Color("6d747a"), _steel)
		# Telecom cables bundled lower down, the way they hang in town
		for k in 2:
			_b.box(Vector3(0.22, 0.35, 0.16), p + Vector3(0.0, 5.6 + k * 0.5, -0.24), Color("37474f"), _paint)
		var tops := []
		for k in 3:
			var t := p + Vector3(-1.1 + k * 1.1, 8.55, 0)
			_b.cylinder(0.05, 0.18, t, Color("8fb3c4"), _paint, 0.035, Vector3.ZERO, 6)
			tops.append(t + Vector3(0, 0.1, 0))
		var low := [p + Vector3(-0.7, 7.25, 0), p + Vector3(0.7, 7.25, 0), p + Vector3(0, 5.9, -0.2), p + Vector3(0.1, 5.75, -0.2)]
		if not prev.is_empty():
			for k in 3:
				_wire(prev[k], tops[k], 0.6)
			for k in low.size():
				_wire(prev[3 + k], low[k], 0.9 + k * 0.25)
		prev = tops + low
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
	# A street front of narrow tube houses (nhà ống), shops below and
	# homes above, with an alley halfway along. One or two storeys, so they
	# never hide the factory from the usual camera angle.
	var x := -8.0
	var count := 12 if Palette.low_end() else 16
	for i in count:
		var w: float = [4.2, 4.6, 5.0, 4.0, 3.8, 4.4][i % 6]
		_tube_house(Vector3(x + w / 2.0, 0, z0), w, [2, 1, 2, 2, 1, 2, 2, 1][i % 8], i)
		x += w
		if i == 6:
			_flat.box(Vector3(2.4, 0.04, 12.0), Vector3(x + 1.2, 0.02, z0 + 6.0), Color("9a978f"), _paving)
			x += 2.4
	Palette.label3d(self, "Tạp hoá", Vector3(-8.0 + 4.2 + 4.6 + 2.5, 4.4, z0 - 0.5), 30)


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


## A glazed window or door in a frame.
func _house_front_glass(c: Vector3, size: Vector2, frame: Color) -> void:
	_b.box(Vector3(size.x + 0.12, size.y + 0.12, 0.05), c + Vector3(0, 0, 0.01), frame)
	_b.box(Vector3(size.x, size.y, 0.06), c, Color("8fb6d6"), window_material)


## A tube house: narrow and deep, its ground floor an open shop (or a home
## behind a folding gate) under an awning and a signboard, balconies with
## railings and plants above, bare grey side walls, and a roof terrace
## with a stainless water tank and a small tiled roof, a tin roof or a
## washing line. The camera mostly sees the back: windows, air
## conditioners and a back door.
func _tube_house(p: Vector3, w: float, floors: int, i: int) -> void:
	var wall: Color = HOUSE_WALLS[(i * 3) % HOUSE_WALLS.size()]
	var trim := wall.darkened(0.14)
	var d := 9.0 + (i % 3)
	var h0 := 3.6
	var hf := 3.1
	var top := h0 + (floors - 1) * hf
	var zf := p.z
	var zb := zf + d
	var cx := p.x
	# Tiled forecourt where motorbikes park, and the house body
	_flat.box(Vector3(w, 0.06, 1.4), Vector3(cx, 0.03, zf - 0.7), Color("c9a98a") if i % 2 == 0 else Color("b8ad9e"), _paving)
	_b.box(Vector3(w - 0.06, top, d), Vector3(cx, top / 2.0, zf + d / 2.0), wall)
	for sx in [-1.0, 1.0]:
		_b.box(Vector3(0.03, top - 0.05, d - 0.1), Vector3(cx + sx * (w / 2.0 - 0.02), top / 2.0, zf + d / 2.0), Color("bdb7ab"))
	# Ground floor: a shop, a café or a home behind a folding gate
	var kind := i % 4
	_b.box(Vector3(w - 0.6, 2.7, 0.06), Vector3(cx, 1.35, zf - 0.02), Color("3b332d"))
	match kind:
		0:
			for r in 3:
				for k in int(w / 0.5):
					_b.box(Vector3(0.38, 0.32, 0.2), Vector3(cx - w / 2.0 + 0.55 + k * 0.5, 0.45 + r * 0.7, zf + 0.05), SIGN_COLORS[(k + r + i) % SIGN_COLORS.size()].lightened(0.25))
		1:
			for k in 2:
				var t := Vector3(cx - 0.8 + k * 1.6, 0, zf - 1.0)
				_b.cylinder(0.35, 0.04, t + Vector3(0, 0.45, 0), Color("eceff1"), _paint, -1.0, Vector3.ZERO, 10)
				_b.cylinder(0.04, 0.44, t + Vector3(0, 0.22, 0), Color("6d747a"), _steel, -1.0, Vector3.ZERO, 6)
				for sx in [-1.0, 1.0]:
					_b.box(Vector3(0.3, 0.25, 0.3), t + Vector3(sx * 0.55, 0.13, 0), Color("1e88e5") if k == 0 else Color("e53935"), _paint)
		2:
			for k in int((w - 0.6) / 0.22):
				_b.box(Vector3(0.04, 2.5, 0.05), Vector3(cx - w / 2.0 + 0.4 + k * 0.22, 1.3, zf - 0.08), Color("4f7f88"), _steel)
		3:
			_b.cylinder(0.32, 0.12, Vector3(cx + w / 2.0 - 0.7, 0.35, zf - 0.7), Color("1d2125"), Palette.surface("rubber"), -1.0, Vector3(PI / 2, 0, 0), 12)
			_b.box(Vector3(0.6, 0.5, 0.4), Vector3(cx - w / 2.0 + 0.8, 0.25, zf - 0.5), Color("c62828"), _paint)
	_b.box(Vector3(w - 0.4, 0.28, 0.32), Vector3(cx, 2.86, zf - 0.12), Color("8d969d"), _steel)  # rolled-up shutter
	_b.box(Vector3(w - 0.15, 0.05, 1.5), Vector3(cx, 2.72, zf - 0.75), AWNINGS[i % AWNINGS.size()], _paint, Vector3(-0.22, 0, 0))
	_b.box(Vector3(w - 0.3, 0.8, 0.08), Vector3(cx, 3.3, zf - 0.08), SIGN_COLORS[i % SIGN_COLORS.size()], _paint)
	_b.box(Vector3(w - 1.0, 0.14, 0.09), Vector3(cx, 3.36, zf - 0.09), Color("fff8e1"), _paint)
	_b.box(Vector3(w - 1.8, 0.1, 0.09), Vector3(cx, 3.12, zf - 0.09), Color("fff8e1"), _paint)
	# A parked motorbike on most forecourts
	if i % 3 != 2:
		_parked_bike(Vector3(cx + (0.6 if i % 2 == 0 else -0.6), 0, zf - 0.8), SIGN_COLORS[(i + 2) % SIGN_COLORS.size()])
	# Upper floors: balcony with railing, French door, window; at the back
	# windows, an air conditioner and drain pipe
	for f in range(1, floors):
		var y := h0 + (f - 1) * hf
		_b.box(Vector3(w, 0.2, 0.3), Vector3(cx, y, zf - 0.12), trim)
		_b.box(Vector3(w - 0.3, 0.12, 0.9), Vector3(cx, y + 0.06, zf - 0.45), Color("d8d3c8"))
		_b.box(Vector3(w - 0.3, 0.06, 0.08), Vector3(cx, y + 1.05, zf - 0.88), Color("37474f"), _steel)
		_flat.box(Vector3(w - 0.32, 0.95, 0.02), Vector3(cx, y + 0.6, zf - 0.88), Color(0.2, 0.25, 0.28, 0.55), Palette.surface("mesh"))
		_house_front_glass(Vector3(cx - w * 0.18, y + 1.25, zf - 0.03), Vector2(1.2, 2.2), Color("6d4c41"))
		_house_front_glass(Vector3(cx + w * 0.27, y + 1.55, zf - 0.03), Vector2(0.9, 1.1), Color("eceff1"))
		if (i + f) % 2 == 0:
			_b.cylinder(0.14, 0.25, Vector3(cx + w * 0.3, y + 0.25, zf - 0.6), Color("b07a54"), null, 0.18, Vector3.ZERO, 8)
			_b.sphere(0.3, Vector3(cx + w * 0.3, y + 0.55, zf - 0.6), Color("4f8a3c"), null, Vector3(1, 1.2, 1), 7, 4)
		_b.box(Vector3(w, 0.14, 0.1), Vector3(cx, y, zb + 0.05), trim)
		_house_front_glass(Vector3(cx - w * 0.12, y + 1.5, zb + 0.03), Vector2(1.0, 1.1), Color("eceff1"))
		if (i + f) % 3 == 0:
			_b.box(Vector3(0.8, 0.55, 0.3), Vector3(cx + w * 0.28, y + 0.7, zb + 0.16), Color("eceff1"), _paint)
			_b.box(Vector3(0.5, 0.5, 0.02), Vector3(cx + w * 0.28, y + 0.7, zb + 0.32), Color("90a4ae"), _steel)
	_house_front_glass(Vector3(cx + w * 0.2, 1.6, zb + 0.03), Vector2(0.9, 1.0), Color("eceff1"))
	_b.box(Vector3(0.9, 2.1, 0.06), Vector3(cx - w * 0.2, 1.05, zb + 0.03), Color("6d4c41"))
	_b.cylinder(0.05, top, Vector3(cx + w / 2.0 - 0.2, top / 2.0, zb + 0.08), Color("eceff1"), _paint, -1.0, Vector3.ZERO, 6)
	# Roof terrace: parapet, water tank on a stand, and one of three tops
	var paint := _paint
	_b.box(Vector3(w, 0.9, 0.16), Vector3(cx, top + 0.45, zf + 0.08), trim)
	_b.box(Vector3(w, 0.9, 0.16), Vector3(cx, top + 0.45, zb - 0.08), trim)
	for sx in [-1.0, 1.0]:
		_b.box(Vector3(0.16, 0.9, d), Vector3(cx + sx * (w / 2.0 - 0.08), top + 0.45, zf + d / 2.0), trim)
	_flat.box(Vector3(w - 0.3, 0.04, d - 0.3), Vector3(cx, top + 0.02, zf + d / 2.0), Color("9e9a92"), _paving)
	var tank := Vector3(cx + w * 0.18, top, zb - 1.4)
	_b.box(Vector3(1.0, 0.5, 0.8), tank + Vector3(0, 0.25, 0), Color("6d747a"), _steel)
	_b.cylinder(0.48, 1.3, tank + Vector3(0, 0.98, 0), Color("dfe4e8"), _steel, -1.0, Vector3(0, 0, PI / 2), 14)
	match i % 3:
		0:
			# Small tiled roof over the front (mái thái)
			_b.prism(Vector3(3.6, 1.2, w - 0.1), Vector3(cx, top + 0.95 + 0.6, zf + 2.0), Color("b5452f"), null, 0.5, Vector3(0, PI / 2, 0))
			_b.box(Vector3(w - 0.2, 0.2, 3.4), Vector3(cx, top + 0.95, zf + 2.0), trim)
		1:
			# Tin roof over the back half
			_b.box(Vector3(w - 0.1, 0.06, d * 0.45), Vector3(cx, top + 2.0, zf + d * 0.62), Color("5c8fb8") if i % 2 == 0 else Color("8a9aa5"), _steel, Vector3(-0.12, 0, 0))
			for sx in [-1.0, 1.0]:
				_b.box(Vector3(0.08, 1.9, 0.08), Vector3(cx + sx * (w / 2.0 - 0.3), top + 1.0, zf + d * 0.42), Color("6d747a"), _steel)
		2:
			# Washing on a line and potted plants
			_b.bar(Vector3(cx - w / 2.0 + 0.3, top + 1.5, zf + 3.0), Vector3(cx + w / 2.0 - 0.3, top + 1.5, zf + 3.0), 0.02, Color("37474f"))
			for k in 4:
				_b.box(Vector3(0.45, 0.6, 0.03), Vector3(cx - w / 2.0 + 0.8 + k * (w - 1.4) / 3.0, top + 1.2, zf + 3.0), SHIRTS[(k + i) % SHIRTS.size()])
			for k in 3:
				_b.cylinder(0.2, 0.35, Vector3(cx - w / 2.0 + 0.5 + k * 0.6, top + 0.18, zf + 0.6), Color("b07a54"), null, 0.25, Vector3.ZERO, 8)
				_b.sphere(0.32, Vector3(cx - w / 2.0 + 0.5 + k * 0.6, top + 0.6, zf + 0.6), Color("4f8a3c").lightened(k * 0.05), null, Vector3(1, 1.1, 1), 7, 4)
	if i % 4 == 1:
		# Solar water heater
		_b.box(Vector3(1.6, 0.06, 1.2), Vector3(cx - w * 0.15, top + 0.7, zb - 1.6), Color("1d2a3a"), paint, Vector3(0.6, 0, 0))
		_b.cylinder(0.2, 1.6, Vector3(cx - w * 0.15, top + 1.15, zb - 2.0), Color("dfe4e8"), _steel, -1.0, Vector3(0, 0, PI / 2), 10)


## A scooter on its stand, facing the road.
func _parked_bike(p: Vector3, color: Color) -> void:
	var rubber := Palette.surface("rubber")
	for z in [-0.55, 0.55]:
		_b.cylinder(0.27, 0.1, p + Vector3(0, 0.27, z), Color("17181a"), rubber, -1.0, Vector3(0, 0, PI / 2), 10)
	_b.box(Vector3(0.32, 0.35, 0.95), p + Vector3(0, 0.5, 0), color, _paint)
	_b.box(Vector3(0.3, 0.1, 0.6), p + Vector3(0, 0.72, 0.15), Color("1d2125"))
	_b.box(Vector3(0.26, 0.55, 0.16), p + Vector3(0, 0.75, -0.48), color, _paint, Vector3(0.3, 0, 0))
	_b.bar(p + Vector3(-0.3, 1.05, -0.5), p + Vector3(0.3, 1.05, -0.5), 0.04, Color("3a3f44"), _steel)


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
	# Coconut palms and banana plants on the shore
	for k in 4:
		var a := 0.6 + k * 1.3
		_palm(c + Vector3(cos(a) * 11.5, 0, sin(a) * 8.0), k)
	for k in 3:
		_banana(c + Vector3(-11.5 + k * 1.4, 0, 5.5 + (k % 2) * 1.2))
	# Ducks
	for i in 3:
		var d := Vector3(c.x - 3 + i * 1.4, 0.2, c.z + 1 - i * 0.6)
		_b.sphere(0.25, d, Color.WHITE if i > 0 else Color("8d6e63"), null, Vector3(1.3, 0.8, 1.0), 8, 5)
		_b.sphere(0.12, d + Vector3(0.26, 0.2, 0), Color("2e7d32"), null, Vector3.ONE, 6, 4)
		_b.box(Vector3(0.12, 0.04, 0.06), d + Vector3(0.4, 0.18, 0), Color("f9a825"))


## Rice paddies: flooded young rice in rows and ripe golden rice, earth
## dikes between the fields, a farmhouse with a tiled roof, haystacks, a
## tractor, and clumps of bamboo along the edge.
func _build_farm() -> void:
	var dike := Color("8a7a4f")
	var water := Palette.surface("water")
	var greens := [Color("8cc63f"), Color("a4d65e"), Color("7cb342")]
	for f in 3:
		var x0 := -24.0 + f * 14.0
		var col: Color = greens[f % greens.size()]
		_flat.box(Vector3(13.0, 0.1, 20.0), Vector3(x0 + 6.5, 0.05, -33.0), Color("5f7f6a"), water)
		for i in 26:
			_flat.box(Vector3(12.2, 0.22, 0.32), Vector3(x0 + 6.5, 0.12, -42.4 + i * 0.75), col.darkened(0.06 * (i % 2)), _ground)
		_dikes(Vector2(x0, -43.0), Vector2(x0 + 13.0, -23.0), dike)
	# Ripe rice ready for harvest
	_flat.box(Vector3(13.0, 0.55, 20.0), Vector3(26.5, 0.27, -33.0), Color("d9b44a"), _ground)
	for i in 20:
		_flat.box(Vector3(12.6, 0.06, 0.12), Vector3(26.5, 0.56, -42.5 + i * 1.0), Color("c9a03c"), _ground)
	_dikes(Vector2(20.0, -43.0), Vector2(33.0, -23.0), dike)
	# Farmhouse with a tiled roof, a porch and a water jar, and haystacks
	var house := Vector3(31, 0, -16.5)
	_b.box(Vector3(8.4, 0.35, 5.4), house + Vector3(0, 0.17, 0), Color("a8a49c"), _paving)
	_b.box(Vector3(8, 3.0, 5), house + Vector3(0, 1.85, 0), Color("f1e3c6"))
	_b.prism(Vector3(8.8, 2.2, 6.2), house + Vector3(0, 4.45, 0), Color("b5452f"), null, 0.5, Vector3(0, PI / 2, 0))
	for k in 3:
		_b.box(Vector3(1.1, 2.1, 0.06), house + Vector3(-2.6 + k * 2.6, 1.4, -2.52), Color("7b4a2e"))
	for k in 4:
		_b.box(Vector3(0.14, 2.4, 0.14), house + Vector3(-3.8 + k * 2.53, 1.55, -3.4), Color("8d6e63"))
	_b.box(Vector3(8.4, 0.1, 1.2), house + Vector3(0, 2.8, -3.0), Color("a0412c"), null, Vector3(-0.25, 0, 0))
	_b.sphere(0.45, house + Vector3(4.6, 0.45, -3.3), Color("6d4c41"), null, Vector3(1, 1.2, 1), 10, 6)
	for k in 3:
		var hay := house + Vector3(-6.0 + (k % 2) * 1.8, 0, -4.5 - k * 1.6)
		_b.cylinder(0.9, 1.4, hay + Vector3(0, 0.7, 0), Color("d9b85c"), null, 0.75, Vector3.ZERO, 12)
		_b.cylinder(0.75, 1.0, hay + Vector3(0, 1.9, 0), Color("cfae52"), null, 0.05, Vector3.ZERO, 12)
		_b.cylinder(0.04, 0.6, hay + Vector3(0, 2.5, 0), Color("6d4c41"), null, -1.0, Vector3.ZERO, 5)
	_tractor(house + Vector3(-1.0, 0, -6.8))
	# Bamboo clumps along the field edge
	var clumps := 4 if Palette.low_end() else 7
	for k in clumps:
		_bamboo(Vector3(-27.0 + k * 9.5, 0, -21.6 - (k % 2) * 0.8))
	_flat.box(Vector3(3.0, 0.04, 30.0), Vector3(36.5, 0.02, -8.0), Color("9c8a6a"), _ground)


## Raised earth banks around a paddy, with grass on top.
func _dikes(a: Vector2, b: Vector2, color: Color) -> void:
	var c := (a + b) / 2.0
	var s := b - a
	for z in [a.y, b.y, c.y]:
		_flat.box(Vector3(s.x + 0.6, 0.32, 0.6), Vector3(c.x, 0.16, z), color, _ground)
		_flat.box(Vector3(s.x + 0.6, 0.04, 0.5), Vector3(c.x, 0.33, z), Color("7a9a3a"), _ground)
	for x in [a.x, b.x]:
		_flat.box(Vector3(0.6, 0.32, s.y), Vector3(x, 0.16, c.y), color, _ground)
		_flat.box(Vector3(0.5, 0.04, s.y), Vector3(x, 0.33, c.y), Color("7a9a3a"), _ground)


## A clump of bamboo: tall jointed stems leaning out, feathery tops.
func _bamboo(p: Vector3) -> void:
	var stems := 11
	for k in stems:
		var a := k * TAU / stems + _rng.randf() * 0.4
		var r := _rng.randf_range(0.1, 0.5)
		var base := p + Vector3(cos(a) * r, 0, sin(a) * r)
		var h := _rng.randf_range(5.5, 8.0)
		var lean := Vector3(cos(a), 0, sin(a)) * h * 0.3
		var mid := base + Vector3(0, h * 0.6, 0) + lean * 0.3
		var tip := base + Vector3(0, h, 0) + lean
		var stem := Color("8bb24a") if k % 3 else Color("b5a642")
		_b.bar(base, mid, 0.08, stem, null, true)
		_b.bar(mid, tip, 0.06, stem, null, true)
		# Feathery leaves: thin drooping sprays along the top half
		for n in 3:
			var at := mid.lerp(tip, 0.2 + n * 0.35)
			_b.sphere(0.55 - n * 0.08, at + lean.normalized() * 0.3, Color("6f9f3a").darkened(0.05 * ((k + n) % 3)), null, Vector3(1.4, 0.45, 0.8), 7, 4)


## A coconut palm: a curved ringed trunk and drooping fronds.
func _palm(p: Vector3, k: int) -> void:
	var lean := Vector3(cos(k * 2.1), 0, sin(k * 2.1)) * 0.9
	var prev := p
	var h := 7.0 + (k % 3)
	for i in range(1, 6):
		var t := i / 5.0
		var q := p + Vector3(0, h * t, 0) + lean * t * t * 2.0
		_b.bar(prev, q, 0.32 - t * 0.08, Color("8d7b62").darkened(0.06 * (i % 2)), null, true)
		prev = q
	for f in 8:
		var a := f * TAU / 8.0
		var dir := Vector3(cos(a), 0, sin(a))
		var mid := prev + dir * 1.3 + Vector3(0, 0.35, 0)
		var tip := prev + dir * 2.6 + Vector3(0, -0.6, 0)
		_b.bar(prev, mid, 0.12, Color("4f8a3c"))
		_b.bar(mid, tip, 0.1, Color("5f9c44"))
		_b.box(Vector3(0.7, 0.03, 1.5), prev.lerp(tip, 0.55) + Vector3(0, 0.05, 0), Color("5a9a3e"), null, Vector3(0, -a + PI / 2.0, 0.25))
	for n in 3:
		_b.sphere(0.18, prev + Vector3(cos(n * 2.1) * 0.25, -0.3, sin(n * 2.1) * 0.25), Color("6b8e23"), null, Vector3.ONE, 6, 4)


## A banana plant: a short stem and big arching leaves.
func _banana(p: Vector3) -> void:
	_b.cylinder(0.16, 2.0, p + Vector3(0, 1.0, 0), Color("7a8f4a"), null, 0.12, Vector3.ZERO, 7)
	for f in 6:
		var a := f * TAU / 6.0 + 0.3
		_b.box(Vector3(0.6, 0.03, 1.8), p + Vector3(cos(a) * 0.8, 2.2, sin(a) * 0.8), Color("6fae3f").darkened(0.05 * (f % 2)), null, Vector3(0, -a + PI / 2.0, 0.5))


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
	for bed in [[Vector3(-17.5, 0, 13.6), 8.0], [Vector3(5, 0, 13.6), 7.0], [Vector3(-3.4, 0, 5.8), 2.0]]:
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
	var low := Palette.low_end()
	var cars := 4 if low else 6
	for i in cars:
		var car := BuildingsView._car(self, Vector3(-120 + i * 240.0 / cars, 0, LANE_CARS), PI / 2, CAR_COLORS[i % CAR_COLORS.size()], lamp_material)
		car.set_meta("speed", 7.0)
		_cars.append(car)
	var bikes := 5 if low else 9
	for i in bikes:
		var east := i % 2 == 0
		var x := -120 + i * 240.0 / bikes + 11.0
		var bike := _motorbike(Vector3(x, 0, LANE_BIKES_EAST if east else LANE_BIKES_WEST), i)
		bike.rotation.y = PI / 2 if east else -PI / 2
		bike.set_meta("speed", 5.5 if east else -5.5)
		_cars.append(bike)


## A scooter with a rider in a helmet (and sometimes a passenger), faces +Z.
func _motorbike(pos: Vector3, i: int) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	var b := MeshBatch.new()
	var rubber := Palette.surface("rubber")
	var body: Color = SIGN_COLORS[(i * 5) % SIGN_COLORS.size()]
	var shirt: Color = SHIRTS[i % SHIRTS.size()]
	var skin := Color("e0ac83")
	for z in [-0.6, 0.6]:
		b.cylinder(0.28, 0.1, Vector3(0, 0.28, z), Color("17181a"), rubber, -1.0, Vector3(0, 0, PI / 2), 10)
	b.box(Vector3(0.32, 0.32, 1.0), Vector3(0, 0.5, -0.05), body, _paint)
	b.box(Vector3(0.3, 0.1, 0.7), Vector3(0, 0.72, -0.15), Color("1d2125"))
	b.box(Vector3(0.28, 0.6, 0.16), Vector3(0, 0.78, 0.5), body, _paint, Vector3(-0.3, 0, 0))
	b.bar(Vector3(-0.32, 1.1, 0.5), Vector3(0.32, 1.1, 0.5), 0.04, Color("3a3f44"), _steel)
	b.box(Vector3(0.16, 0.1, 0.06), Vector3(0, 1.02, 0.66), Color("fff3c4"), lamp_material)
	b.box(Vector3(0.14, 0.08, 0.04), Vector3(0, 0.66, -0.58), Color("c62828"), Palette.surface("screen"))
	# Rider: legs on the floorboard, torso, arms to the bars, helmet
	for sx in [-1.0, 1.0]:
		b.box(Vector3(0.13, 0.13, 0.5), Vector3(sx * 0.13, 0.82, 0.05), Color("37474f"))
		b.box(Vector3(0.12, 0.4, 0.13), Vector3(sx * 0.13, 0.6, 0.3), Color("37474f"))
		b.bar(Vector3(sx * 0.2, 1.38, -0.05), Vector3(sx * 0.28, 1.1, 0.45), 0.09, shirt)
	b.box(Vector3(0.42, 0.55, 0.26), Vector3(0, 1.17, -0.15), shirt, null, Vector3(0.15, 0, 0))
	b.sphere(0.12, Vector3(0, 1.55, -0.1), skin)
	b.sphere(0.17, Vector3(0, 1.62, -0.12), SIGN_COLORS[(i + 3) % SIGN_COLORS.size()].lightened(0.2), _paint, Vector3(1, 0.9, 1.05), 8, 5)
	if i % 3 == 1:
		b.box(Vector3(0.4, 0.5, 0.24), Vector3(0, 1.12, -0.5), SHIRTS[(i + 3) % SHIRTS.size()], null, Vector3(0.1, 0, 0))
		b.sphere(0.16, Vector3(0, 1.52, -0.52), Color("f5f5f5"), _paint, Vector3(1, 0.9, 1.05), 8, 5)
	b.build(n)
	return n


## Warm yard lights that come on at night (on the higher graphics levels,
## see Graphics.night_lights_on; the lamps glow either way).
func _build_site_lights() -> void:
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
