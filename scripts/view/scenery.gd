## Everything outside the factory fence: pavements, street lamps, the
## neighbourhood across the road, a pond, fields, hills, wind turbines,
## drifting clouds and traffic. Purely decorative; lamp materials and lights
## are handed to the day/night cycle.
extends Node3D

const BuildingsView := preload("res://scripts/view/buildings_view.gd")
const TRUNK := Color("7a5432")
const LEAVES := [Color("4f8a3c"), Color("3f7a34"), Color("5f9c44"), Color("6b8e23")]
const CAR_COLORS := [Color("e53935"), Color("fdd835"), Color("eceff1"), Color("1e88e5"), Color("43a047"), Color("212121")]

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


func _ready() -> void:
	_rng.seed = 11
	lamp_material = StandardMaterial3D.new()
	lamp_material.albedo_color = Color("fff3c4")
	lamp_material.emission_enabled = true
	lamp_material.emission = Color("ffd27a")
	lamp_material.emission_energy_multiplier = 0.0
	window_material = StandardMaterial3D.new()
	window_material.albedo_color = Color("8fb6d6")
	window_material.emission_enabled = true
	window_material.emission = Color("ffcf70")
	window_material.emission_energy_multiplier = 0.0
	_build_pavements_and_lamps()
	_build_gate()
	_build_neighbourhood()
	_build_pond()
	_build_fields_and_hills()
	_build_trees()
	_build_flowers()
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
		if c.position.x > 110.0:
			c.position.x = -110.0
	for r in _rotors:
		r.rotate_object_local(Vector3.FORWARD, delta * 1.2)
	if _flag:
		_flag.rotation.y = sin(_time * 2.0) * 0.18


# --- Road side -----------------------------------------------------------------

func _build_pavements_and_lamps() -> void:
	var z := FactoryLayout.ROAD_Z
	Palette.box(self, Vector3(260, 0.08, 1.6), Vector3(0, 0.04, z - 3.8), Color("b9b4aa"))
	Palette.box(self, Vector3(260, 0.08, 1.6), Vector3(0, 0.04, z + 3.8), Color("b9b4aa"))
	for x in range(-84, 85, 14):
		if absf(x - 16) < 4:
			continue
		_lamp(Vector3(x, 0, z - 3.9), 0.0)
		_lamp(Vector3(x + 7, 0, z + 3.9), PI)


func _lamp(pos: Vector3, yaw: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	add_child(n)
	Palette.cylinder(n, 0.08, 4.4, Vector3(0, 2.2, 0), Color("546e7a"))
	Palette.box(n, Vector3(0.1, 0.1, 1.2), Vector3(0, 4.35, 0.55), Color("546e7a"))
	var head := Palette.box(n, Vector3(0.45, 0.14, 0.6), Vector3(0, 4.25, 1.1), Color("fff3c4"))
	head.material_override = lamp_material
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_gate() -> void:
	# Sign over the truck driveway and a flagpole beside it.
	for x in [12.6, 19.4]:
		Palette.box(self, Vector3(0.35, 4.2, 0.35), Vector3(x, 2.1, 14.2), Color("37474f"))
	Palette.box(self, Vector3(7.2, 0.9, 0.25), Vector3(16, 4.4, 14.2), Color("1565c0"))
	var sign := Palette.label3d(self, "NHÀ MÁY NHỰA", Vector3(16, 4.4, 14.4), 44, Color.WHITE)
	sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sign.no_depth_test = false
	Palette.cylinder(self, 0.07, 7.0, Vector3(9.5, 3.5, 13.0), Color("cfd8dc"))
	_flag = Node3D.new()
	_flag.position = Vector3(9.5, 6.3, 13.0)
	add_child(_flag)
	Palette.box(_flag, Vector3(1.6, 1.0, 0.04), Vector3(0.82, 0, 0), Color("1e88e5"))
	Palette.box(_flag, Vector3(0.5, 0.5, 0.06), Vector3(0.82, 0, 0), Color("ffca28"))


# --- Neighbourhood across the road ----------------------------------------------

func _build_neighbourhood() -> void:
	var z0 := FactoryLayout.ROAD_Z + 6.0
	# Neighbour factory with a sawtooth roof and a smoking chimney
	var f := Node3D.new()
	f.position = Vector3(-22, 0, z0 + 9)
	add_child(f)
	Palette.box(f, Vector3(22, 5, 14), Vector3(0, 2.5, 0), Color("90a4ae"))
	for i in 5:
		var roof := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.left_to_right = 1.0
		pm.size = Vector3(4.4, 1.6, 14)
		roof.mesh = pm
		roof.position = Vector3(-8.8 + i * 4.4, 5.8, 0)
		roof.material_override = Palette.mat(Color("607d8b"))
		f.add_child(roof)
	for i in 6:
		var w := Palette.box(f, Vector3(2.0, 1.2, 0.05), Vector3(-8.5 + i * 3.4, 2.6, -7.03), Color("8fb6d6"))
		w.material_override = window_material
	Palette.cylinder(f, 0.9, 12, Vector3(9, 6, 4), Color("8d6e63"), 0.7)
	Palette.box(f, Vector3(4, 3, 0.1), Vector3(-3, 1.5, -7.05), Color("455a64"))
	var smoke := CPUParticles3D.new()
	smoke.position = Vector3(9, 12.2, 4)
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
	smoke.material_override = Palette.mat(Color(0.85, 0.85, 0.85, 0.55))
	f.add_child(smoke)
	Palette.label3d(f, "Xưởng cơ khí bên cạnh", Vector3(0, 8.5, 0), 30, Color("eceff1"))
	# A row of houses with pitched roofs and gardens
	var house_colors := [Color("ffccbc"), Color("fff9c4"), Color("c8e6c9"), Color("bbdefb"), Color("f8bbd0")]
	var roof_colors := [Color("c0392b"), Color("8d4b2a"), Color("b23a48"), Color("6d4c41"), Color("a84432")]
	for i in 5:
		var h := Node3D.new()
		h.position = Vector3(4 + i * 9.0, 0, z0 + 5 + (i % 2) * 2.0)
		add_child(h)
		var hc: Color = house_colors[i]
		Palette.box(h, Vector3(6, 3.2, 5), Vector3(0, 1.6, 0), hc)
		var roof := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(6.6, 2.0, 5.6)
		roof.mesh = pm
		roof.position = Vector3(0, 4.2, 0)
		roof.material_override = Palette.mat(roof_colors[i])
		h.add_child(roof)
		Palette.box(h, Vector3(1.0, 1.9, 0.05), Vector3(0, 0.95, -2.53), Color("6d4c41"))
		for x in [-1.9, 1.9]:
			var w := Palette.box(h, Vector3(1.1, 0.9, 0.05), Vector3(x, 1.9, -2.53), Color("8fb6d6"))
			w.material_override = window_material
		# Garden hedge
		Palette.box(h, Vector3(7.5, 0.7, 0.6), Vector3(0, 0.35, -4.2), Color("33691e"))
	# Corner shop with an awning
	var shop := Node3D.new()
	shop.position = Vector3(50, 0, z0 + 5)
	add_child(shop)
	Palette.box(shop, Vector3(7, 3.4, 6), Vector3(0, 1.7, 0), Color("eceff1"))
	for i in 5:
		Palette.box(shop, Vector3(1.4, 0.15, 1.6), Vector3(-2.8 + i * 1.4, 3.0, -3.6), Color("e53935") if i % 2 == 0 else Color.WHITE).rotation.x = 0.3
	var win := Palette.box(shop, Vector3(5, 1.6, 0.05), Vector3(0, 1.5, -3.03), Color("8fb6d6"))
	win.material_override = window_material
	Palette.label3d(shop, "Tạp hoá", Vector3(0, 4.2, -3), 30)


# --- Nature ------------------------------------------------------------------------

func _build_pond() -> void:
	var c := Vector3(-42, 0, -4)
	var water := Palette.cylinder(self, 9.0, 0.06, c + Vector3(0, 0.05, 0), Color("4a90c2"))
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("4a90c2")
	m.metallic = 0.3
	m.roughness = 0.1
	water.material_override = m
	water.scale = Vector3(1.0, 1.0, 0.65)
	Palette.cylinder(self, 9.6, 0.04, c + Vector3(0, 0.03, 0), Color("c8b88a")).scale = Vector3(1.0, 1.0, 0.68)
	for i in 14:
		var a := _rng.randf() * TAU
		var p := c + Vector3(cos(a) * 9.0, 0, sin(a) * 5.9)
		Palette.cylinder(self, 0.05, 1.2, p + Vector3(0, 0.6, 0), Color("7cb342"))
	# Bench and a little jetty
	Palette.box(self, Vector3(2.0, 0.1, 0.6), c + Vector3(0, 0.5, 7.2), Color("8d6e63"))
	Palette.box(self, Vector3(2.0, 0.6, 0.1), c + Vector3(0, 0.8, 7.5), Color("8d6e63"))
	Palette.box(self, Vector3(1.4, 0.12, 4.0), c + Vector3(6, 0.25, 3.5), Color("a1887f"))
	# Ducks
	for i in 3:
		var d := Vector3(c.x - 3 + i * 1.4, 0.2, c.z + 1 - i * 0.6)
		Palette.sphere(self, 0.25, d, Color.WHITE)
		Palette.sphere(self, 0.13, d + Vector3(0.22, 0.2, 0), Color("2e7d32"))


func _build_fields_and_hills() -> void:
	# Crop rows north of the factory
	var colors := [Color("9ccc65"), Color("c0ca33"), Color("8bc34a")]
	for i in 10:
		Palette.box(self, Vector3(40, 0.25, 1.3), Vector3(-4, 0.12, -24 - i * 2.0), colors[i % 3])
	# Distant hills
	for h in [[Vector3(-70, 0, -60), 24.0], [Vector3(-25, 0, -72), 30.0], [Vector3(30, 0, -66), 26.0], [Vector3(75, 0, -50), 20.0], [Vector3(-85, 0, 10), 18.0], [Vector3(85, 0, 20), 16.0]]:
		var s := Palette.sphere(self, h[1], h[0], Color("6a9c50"))
		s.scale = Vector3(1.0, 0.35, 0.8)
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Wind turbines on the hills
	for p in [Vector3(-30, 0, -50), Vector3(-14, 0, -54), Vector3(4, 0, -50)]:
		Palette.cylinder(self, 0.35, 18, p + Vector3(0, 9, 0), Color("f5f5f5"), 0.2)
		var hub := Node3D.new()
		hub.position = p + Vector3(0, 18, 0.5)
		add_child(hub)
		Palette.sphere(hub, 0.5, Vector3.ZERO, Color("eeeeee"))
		for k in 3:
			var blade := Palette.box(hub, Vector3(0.35, 7.0, 0.08), Vector3(0, 3.5, 0), Color("fafafa"))
			var pivot := Node3D.new()
			hub.add_child(pivot)
			blade.reparent(pivot, false)
			pivot.rotation.z = k * TAU / 3.0
		hub.rotation.z = _rng.randf() * TAU
		_rotors.append(hub)


func _build_trees() -> void:
	var placed := 0
	var tries := 0
	while placed < 70 and tries < 600:
		tries += 1
		var p := Vector3(_rng.randf_range(-90, 90), 0, _rng.randf_range(-60, 60))
		if p.x > -27 and p.x < 27 and p.z > -19 and p.z < 16:
			continue  # factory lot
		if absf(p.z - FactoryLayout.ROAD_Z) < 6.5:
			continue  # road and pavements
		if p.z > 22 and p.z < 42 and p.x > -36 and p.x < 56:
			continue  # neighbourhood
		if Vector2(p.x + 42, (p.z + 4) * 1.5).length() < 11:
			continue  # pond
		if p.z < -21 and p.z > -45 and absf(p.x + 4) < 21:
			continue  # fields
		_tree(p, _rng.randf_range(0.8, 1.4), _rng.randi() % 3 == 0)
		placed += 1
	# A neat row of trees along the front fence
	for x in [-22, -16, -10, 6, 22]:
		_tree(Vector3(x, 0, 15.0), 0.7, false)


func _tree(p: Vector3, s: float, pine: bool) -> void:
	Palette.cylinder(self, 0.22 * s, 1.6 * s, p + Vector3(0, 0.8 * s, 0), TRUNK)
	var leaf: Color = LEAVES[_rng.randi() % LEAVES.size()]
	if pine:
		Palette.cylinder(self, 1.3 * s, 2.6 * s, p + Vector3(0, 2.6 * s, 0), leaf.darkened(0.15), 0.0)
		Palette.cylinder(self, 0.9 * s, 2.0 * s, p + Vector3(0, 3.8 * s, 0), leaf.darkened(0.15), 0.0)
	else:
		Palette.sphere(self, 1.4 * s, p + Vector3(0, 2.5 * s, 0), leaf)
		Palette.sphere(self, 0.9 * s, p + Vector3(0.7 * s, 3.2 * s, 0.3 * s), leaf.lightened(0.08))


func _build_flowers() -> void:
	var colors := [Color("ec407a"), Color("ffee58"), Color("ff7043"), Color("ab47bc"), Color.WHITE]
	for bed in [[Vector3(-17.5, 0, 13.6), 8.0], [Vector3(5, 0, 13.6), 7.0], [Vector3(-8.5, 0, 5.8), 2.0]]:
		var c: Vector3 = bed[0]
		var w: float = bed[1]
		Palette.box(self, Vector3(w, 0.15, 0.7), c + Vector3(w / 2.0, 0.07, 0), Color("6d4c41"))
		for i in int(w * 3):
			var p := c + Vector3(0.2 + i * 0.33, 0.25, _rng.randf_range(-0.2, 0.2))
			Palette.sphere(self, 0.13, p, colors[_rng.randi() % colors.size()])


func _build_clouds() -> void:
	for i in 9:
		var c := Node3D.new()
		c.position = Vector3(_rng.randf_range(-110, 110), _rng.randf_range(26, 34), _rng.randf_range(-60, 40))
		add_child(c)
		for k in 4:
			var s := Palette.sphere(c, _rng.randf_range(2.5, 4.0), Vector3(k * 3.0 - 4.5, _rng.randf_range(-0.5, 0.8), _rng.randf_range(-1.5, 1.5)), Color("fafafa"))
			s.scale = Vector3(1.2, 0.6, 1.0)
			s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_clouds.append(c)


func _build_traffic() -> void:
	for i in 5:
		var car := BuildingsView._car(self, Vector3(-120 + i * 50 + _rng.randf_range(0, 15), 0, FactoryLayout.ROAD_Z + 1.5), PI / 2, CAR_COLORS[i % CAR_COLORS.size()])
		car.set_meta("speed", _rng.randf_range(5.0, 8.0))
		for k in 2:
			var hl := Palette.box(car, Vector3(0.35, 0.18, 0.05), Vector3(-0.5 + k, 0.65, 1.72), Color("fff3c4"))
			hl.material_override = lamp_material
		_cars.append(car)


## Warm yard lights that come on at night.
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
