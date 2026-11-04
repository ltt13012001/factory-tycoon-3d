## The surroundings of each branch, modelled on the real place:
## - Hạ Long: on the bay, limestone islands, tourist junks, a floating
##   fishing village, Bãi Cháy hotels and the cable-stayed bridge;
## - Hải Phòng: next to the container port, gantry cranes, a ship at the quay;
## - Đà Nẵng: on the beach, coconut palms, basket boats, Sơn Trà mountain;
## - Bắc Ninh: in an industrial park among rice paddies, a village pagoda;
## - Bình Dương: in an industrial park, rubber plantations on red soil;
## - Thailand: on a river with long-tail boats and a temple;
## - Indonesia: rice terraces under a smoking volcano;
## - India: a dusty plain with banyan trees, stone pavilions, tuk-tuks;
## - Mexico: desert with mesas, saguaro cacti and agave fields;
## - Germany: rolling hills, pine forest, half-timbered village, church;
## - USA: plains with cornfields, a grain farm, water tower, skyline.
## Each place is drawn when the player visits it (see BranchView) and freed
## when they leave, so only one is ever in memory.
extends BranchWorld

const HOUSE_WALLS := [Color("f4e3a1"), Color("cfe8d8"), Color("cfe0f0"), Color("f3d0cc"), Color("f6ead2"), Color("ffd9b0"), Color("e4e4dc")]
const CONTAINER_COLORS := [Color("c62828"), Color("1565c0"), Color("f9a825"), Color("2e7d32"), Color("6d4c41"), Color("eceff1"), Color("ef6c00")]


func build() -> void:
	_rng.seed = hash(location_id)
	_noise.seed = hash(location_id) % 1000
	match location_id:
		"quang_ninh":
			_ha_long()
		"hai_phong":
			_hai_phong()
		"da_nang":
			_da_nang()
		"bac_ninh":
			_bac_ninh()
		"binh_duong":
			_binh_duong()
		"thailand":
			_thailand()
		"indonesia":
			_indonesia()
		"india":
			_india()
		"mexico":
			_mexico()
		"germany":
			_germany()
		"usa":
			_usa()
		_:
			road()
			scatter("tree", 80, Vector2(-160, -160), Vector2(160, 160))
	finish()


func land(x: float, z: float) -> float:
	var n := _noise.get_noise_2d(x, z)
	match location_id:
		"quang_ninh":
			var coast := minf(z + 25.0 + n * 6.0, x + 42.0 + n * 6.0)
			if coast < 0.0:
				return SEA - 1.0 - clampf(-coast * 0.3, 0.0, 7.0)
			return minf(coast * 0.2, 0.6) + smoothstep(36.0, 110.0, z) * (16.0 + n * 14.0) + smoothstep(60.0, 150.0, x) * maxf(0.0, z + 20.0) * 0.1
		"hai_phong":
			var coast := z + 32.0 + (n * 3.0 if x < 25.0 else 0.0)
			if x > 25.0 and z < -2.0:
				coast = z + 34.0  # straight quay
			if coast < 0.0:
				return SEA - 2.0 - clampf(-coast * 0.4, 0.0, 6.0)
			return minf(coast * 0.2, 0.5) + smoothstep(60.0, 160.0, z) * 3.0 * (n + 1.0)
		"da_nang":
			var mountain := 1.0 - Vector2(x - 110.0, (z + 130.0) * 0.8).length() / 90.0
			var coast := z + 24.0 + n * 2.0
			if mountain > 0.0:
				return maxf(SEA - 6.0 + mountain * 80.0 * (0.85 + n * 0.3), coast * 0.08 if coast > 0.0 else SEA - 6.0)
			if coast < 0.0:
				return SEA - 0.4 - clampf(-coast * 0.12, 0.0, 6.0)
			return minf(coast * 0.06, 0.5) + smoothstep(50.0, 160.0, z) * 6.0 * (n + 1.0)
		"thailand":
			var river := absf(z + 62.0 + n * 8.0)
			if river < 24.0:
				return SEA - 0.5 - (24.0 - river) * 0.25
			return minf((river - 24.0) * 0.15, 0.5) + 0.1 + absf(n) * 0.4
		"indonesia":
			var volcano := 1.0 - Vector2(x + 50.0, z + 165.0).length() / 120.0
			var hill := smoothstep(30.0, 120.0, maxf(-z, x)) * (10.0 + n * 8.0)
			var h := maxf(hill, volcano * 85.0 if volcano > 0.0 else 0.0)
			if volcano > 0.84:
				h -= (volcano - 0.84) * 220.0  # crater
			# Terraces: the lower slopes step down in level rice fields.
			if h > 0.8 and h < 18.0 and volcano < 0.7:
				h = floorf(h / 1.4) * 1.4 + 0.2
			return h
		"india":
			return 0.1 + n * 0.4 + smoothstep(90.0, 170.0, -z) * 14.0 * (n + 0.8)
		"mexico":
			var mesa := _noise.get_noise_2d(x * 0.6 + 300.0, z * 0.6)
			var far := smoothstep(40.0, 90.0, Vector2(x, z - 10.0).length())
			var h := 0.2 + n * 0.8
			if mesa > 0.12:
				h += 26.0 * smoothstep(0.12, 0.2, mesa) * far
			return h
		"germany":
			return 0.3 + (n + 0.5) * 9.0 * smoothstep(30.0, 90.0, Vector2(x, z).length())
		"usa":
			return 0.1 + n * 0.3
		"bac_ninh":
			return 0.1 + smoothstep(90.0, 160.0, z) * 12.0 * (n + 1.0)
		"binh_duong":
			return 0.2 + (n + 0.6) * 3.0 * smoothstep(30.0, 80.0, Vector2(x, z).length())
	return 0.0


# --- Vietnam -------------------------------------------------------------------

func _ha_long() -> void:
	has_sea = true
	sea_deep = Color("1f6a72")
	sea_shallow = Color("4aa79a")
	sand = Color("cdbf98")
	road()
	# Promenade with a sea wall, lamps, palms and benches along the bay.
	_flat.box(Vector3(220.0, 0.12, 5.0), Vector3(55.0, 0.06, -21.5), Color("c9c2b4"), _paving)
	_flat.box(Vector3(5.0, 0.12, 44.0), Vector3(-36.0, 0.06, 0.0), Color("c9c2b4"), _paving)
	_b.box(Vector3(220.0, 2.2, 0.6), Vector3(55.0, -0.8, -24.2), Color("9e9a90"), _paving)
	_b.box(Vector3(0.6, 2.2, 46.0), Vector3(-38.6, -0.8, -1.0), Color("9e9a90"), _paving)
	_b.box(Vector3(220.0, 0.15, 0.25), Vector3(55.0, 0.9, -23.9), Color("eceff1"), _paint)
	for i in 14:
		var x := -30.0 + i * 13.0
		lamp_post(Vector3(x, 0, -20.0))
		plant("palm", x + 6.0, -20.5, 0.9)
		_detail.box(Vector3(1.8, 0.1, 0.5), Vector3(x + 3.0, 0.5, -22.6), Color("8d6e63"))
	for z in [-14.0, -2.0, 10.0]:
		plant("palm", -35.5, z, 0.9)
	for i in 6:
		person(Vector3(-20.0 + i * 17.0, 0.1, -21.0 + (i % 2)), HOUSE_WALLS[i], PI if i % 2 else 0.0)
	# Limestone karst islands across the bay: a few close to the shore, in
	# view while playing, and many more further out, bigger and hazier.
	for k in [[-52.0, -48.0, 15.0, 30.0], [-22.0, -72.0, 20.0, 40.0], [12.0, -56.0, 11.0, 22.0], [-88.0, -22.0, 13.0, 26.0],
			[42.0, -80.0, 22.0, 44.0], [-72.0, -96.0, 26.0, 52.0], [78.0, -52.0, 12.0, 24.0], [-40.0, -118.0, 18.0, 36.0]]:
		karst(k[0], k[1], k[2], k[3])
	var islands := 22 if low else 38
	var placed := 0
	var tries := 0
	while placed < islands and tries < 600:
		tries += 1
		var x := _rng.randf_range(-260, 230)
		var z := _rng.randf_range(-260, -10)
		if land(x, z) > SEA - 3.0 or Vector2(x, z).length() < 110.0:
			continue
		var d := Vector2(x, z).length()
		var w := _rng.randf_range(8.0, 16.0) + d * 0.04
		karst(x, z, w, _rng.randf_range(14.0, 26.0) + d * 0.1)
		placed += 1
	# Tourist junks cruising between the islands, fishing boats at anchor.
	for i in 5:
		boat("junk", {"kind": "loop", "center": Vector3(-70.0 + i * 38.0, SEA + 0.2, -75.0 - (i % 3) * 22.0), "radius": Vector2(26.0 + i * 3.0, 14.0), "speed": 0.05 * (1 if i % 2 else -1), "phase": i * 1.7, "bob": 0.1})
	for i in 4:
		var n := boat("fishing", {"kind": "bob", "y": SEA + 0.1, "amount": 0.08, "phase": i * 1.3})
		n.position = Vector3(-60.0 + i * 9.0, SEA + 0.1, -36.0 - (i % 2) * 6.0)
		n.rotation.y = i * 0.7
	# Floating fishing village between two islands.
	for k in 6:
		raft_house(Vector3(-105.0 + (k % 3) * 13.0, SEA, -55.0 - (k / 3) * 12.0), HOUSE_WALLS[k])
	karst(-128.0, -48.0, 22.0, 40.0)
	karst(-80.0, -88.0, 18.0, 34.0)
	# Bãi Cháy: hotels along the shore to the east and on the hills behind.
	for i in 9:
		var h := _rng.randf_range(12.0, 34.0)
		block(Vector3(42.0 + i * 14.0, height(42.0 + i * 14.0, -8.0), -8.0 + (i % 2) * 4.0), Vector3(10.0, h, 8.0), HOUSE_WALLS[i % HOUSE_WALLS.size()].lightened(0.2), Color("37474f"), _far if i > 4 else _b)
	for i in 10:
		var x := -40.0 + i * 16.0
		house(Vector3(x, height(x, 34.0), 34.0), 6.0, 8.0, HOUSE_WALLS[i % HOUSE_WALLS.size()], Color("b5562e"), 0.0)
	scatter("tree", 200, Vector2(-170, 40), Vector2(170, 170), 1.3)
	scatter("bush", 60, Vector2(-170, 30), Vector2(170, 170))
	# The cable-stayed bridge over the strait to the west.
	_bridge(Vector3(-205.0, 0, -95.0), Vector3(-120.0, 0, -205.0), 13.0)
	traffic(["bike", "car", "bike", "truck", "bike", "car"], 8)


func _bridge(a: Vector3, b: Vector3, deck: float) -> void:
	var dir := (b - a).normalized()
	var side := Vector3(-dir.z, 0, dir.x)
	var length := a.distance_to(b)
	var yaw := atan2(dir.x, dir.z)
	var mid := (a + b) / 2.0
	_far.box(Vector3(14.0, 1.2, length), mid + Vector3(0, deck, 0), Color("cfd2d4"), _paving, Vector3(0, yaw, 0))
	for k in [-1.0, 1.0]:
		var p: Vector3 = mid + dir * k * length * 0.2
		var top: Vector3 = p + Vector3(0, deck + 48.0, 0)
		_far.bar(p + side * 6.0 + Vector3(0, SEA, 0), top, 2.2, Color("e6e6e2"), _paint)
		_far.bar(p - side * 6.0 + Vector3(0, SEA, 0), top, 2.2, Color("e6e6e2"), _paint)
		for c in 9:
			for s in [-1.0, 1.0]:
				var anchor: Vector3 = p + dir * s * (8.0 + c * 6.0) + Vector3(0, deck + 0.6, 0)
				_far.bar(top - Vector3(0, 4.0 + c * 1.6, 0), anchor, 0.25, Color("f5f5f5"), _steel)
	for k in range(1, 8):
		var p := a.lerp(b, k / 8.0)
		if absf(k / 8.0 - 0.3) < 0.08 or absf(k / 8.0 - 0.7) < 0.08:
			continue
		_far.box(Vector3(5.0, deck, 3.0), p + Vector3(0, deck / 2.0 + SEA, 0), Color("b0b0aa"), _paving, Vector3(0, yaw, 0))


func _hai_phong() -> void:
	has_sea = true
	sea_deep = Color("2d5a63")
	sea_shallow = Color("5a8a80")
	sand = Color("a59a80")
	road()
	# Container terminal: concrete apron, quay edge with fenders, rail track.
	_flat.box(Vector3(140.0, 0.2, 36.0), Vector3(98.0, 0.1, -16.0), Color("b4b4ae"), _paving)
	_b.box(Vector3(140.0, 2.6, 1.2), Vector3(98.0, -0.9, -34.2), Color("8d8d88"), _paving)
	for i in 28:
		_b.box(Vector3(0.8, 1.4, 0.5), Vector3(30.0 + i * 5.0, -0.4, -34.9), Color("212121"), _rubber)
	for z in [-30.0, -18.0]:
		_flat.box(Vector3(140.0, 0.05, 0.2), Vector3(98.0, 0.22, z), Color("6d6d6d"), _steel)
	# Ship-to-shore gantry cranes on the quay.
	for i in 4:
		_sts_crane(Vector3(45.0 + i * 30.0, 0, -24.0), Color("c62828") if i % 2 == 0 else Color("eceff1"))
	# Container stacks in the yard
	var stacks := 0
	for row in 4:
		for col in 12:
			var x := 36.0 + col * 10.0
			var z := -12.0 + row * 3.2
			var tiers := 1 + (row * 7 + col * 3) % 4
			for t in tiers:
				_container(x, z, t, (col + row * 5 + t * 3) % CONTAINER_COLORS.size())
				stacks += 1
	# Rubber-tyred yard crane over the stacks
	for x in [70.0, 120.0]:
		for z in [-14.5, 0.8]:
			_b.box(Vector3(0.8, 14.0, 0.8), Vector3(x, 7.0, z), Color("f9a825"), _paint)
		_b.box(Vector3(1.0, 1.0, 16.6), Vector3(x, 14.0, -6.8), Color("f9a825"), _paint)
	# A container ship at the quay, others leaving the port.
	var ship := boat("cargo", {"kind": "bob", "y": SEA + 0.2, "amount": 0.05, "phase": 0.0})
	ship.position = Vector3(90.0, SEA + 0.2, -44.0)
	ship.rotation.y = PI / 2
	for i in 2:
		boat("cargo", {"kind": "loop", "center": Vector3(10.0 + i * 60.0, SEA + 0.2, -150.0 - i * 30.0), "radius": Vector2(120.0, 30.0), "speed": 0.012 * (1 if i % 2 else -1), "phase": i * 2.0, "bob": 0.05})
	for i in 3:
		boat("fishing", {"kind": "loop", "center": Vector3(-40.0 + i * 25.0, SEA + 0.1, -70.0), "radius": Vector2(20.0, 10.0), "speed": 0.08, "phase": i * 2.1, "bob": 0.1})
	# Cát Bà islands on the horizon.
	for i in (8 if low else 14):
		karst(_rng.randf_range(-220, 180), _rng.randf_range(-260, -170), _rng.randf_range(18, 30), _rng.randf_range(20, 36))
	# City side: shophouses, warehouses, trees.
	for i in 12:
		var x := -150.0 + i * 10.0
		block(Vector3(x, 0, -12.0 + (i % 3) * 8.0), Vector3(8.0, 6.0 + (i % 4) * 3.0, 7.0), HOUSE_WALLS[i % HOUSE_WALLS.size()], Color("455a64"))
	for i in 8:
		var x := -120.0 + i * 30.0
		block(Vector3(x, height(x, 40.0), 40.0 + (i % 2) * 12.0), Vector3(16.0, 8.0, 12.0), Color("cfd6dc"), Color("607d8b"))
	scatter("tree", 120, Vector2(-170, 30), Vector2(170, 170))
	_bridge(Vector3(-210.0, 0, -40.0), Vector3(-90.0, 0, -200.0), 12.0)
	traffic(["truck", "bike", "truck", "car", "bike", "truck"], 8)


func _sts_crane(p: Vector3, color: Color) -> void:
	for x in [-5.0, 5.0]:
		for z in [-6.0, 6.0]:
			_b.box(Vector3(1.0, 26.0, 1.0), p + Vector3(x, 13.0, z), color, _paint)
		_b.box(Vector3(1.2, 1.2, 13.0), p + Vector3(x, 26.0, 0), color, _paint)
	_b.box(Vector3(11.0, 1.2, 1.2), p + Vector3(0, 18.0, -6.0), color, _paint)
	_b.box(Vector3(11.0, 1.2, 1.2), p + Vector3(0, 18.0, 6.0), color, _paint)
	# Boom reaching out over the water and the back reach over the yard
	_b.box(Vector3(3.0, 1.6, 64.0), p + Vector3(0, 28.0, -14.0), color, _paint)
	_b.box(Vector3(4.0, 3.0, 5.0), p + Vector3(0, 30.0, -4.0), Color("eceff1"), _paint)
	_b.box(Vector3(2.6, 1.4, 2.6), p + Vector3(0, 26.4, -26.0), Color("37474f"), _steel)
	_b.bar(p + Vector3(0, 32.0, 2.0), p + Vector3(0, 28.8, -44.0), 0.3, Color("37474f"), _steel)
	_b.bar(p + Vector3(0, 26.0, -26.0), p + Vector3(0, 9.0, -26.0), 0.08, Color("212121"))
	_b.box(Vector3(2.6, 2.6, 6.1), p + Vector3(0, 7.8, -26.0), CONTAINER_COLORS[int(p.x) % CONTAINER_COLORS.size()], _paint)


func _container(x: float, z: float, tier: int, color: int) -> void:
	instance("container%d" % color, _container_mesh.bind(CONTAINER_COLORS[color]), Transform3D(Basis.IDENTITY, Vector3(x, height(x, z) + 0.2 + tier * 2.6, z)))


func _container_mesh(c: Color) -> ArrayMesh:
	var m := MeshBatch.new()
	m.box(Vector3(6.0, 2.55, 2.4), Vector3(0, 1.28, 0), c, _paint)
	for k in 9:
		m.box(Vector3(0.06, 2.3, 2.45), Vector3(-2.6 + k * 0.65, 1.28, 0), c.darkened(0.15))
	return m.build_mesh()


func _da_nang() -> void:
	has_sea = true
	sea_deep = Color("1b6f9a")
	sea_shallow = Color("47b3bf")
	sand = Color("efe0b9")
	road()
	# Wide beach behind the plant: palms, sunshades, deck chairs, basket boats.
	for i in 22:
		var x := -150.0 + i * 13.5 + _rng.randf_range(-3, 3)
		if absf(x) < 28.0:
			continue
		plant("palm", x, -18.0 + _rng.randf_range(-3, 3), 1.0)
	var shades := [Color("e53935"), Color("1e88e5"), Color("fdd835"), Color("43a047"), Color("fb8c00")]
	for i in 16:
		var x := -120.0 + i * 15.0 + _rng.randf_range(-2, 2)
		var z := -27.0 + _rng.randf_range(-1.5, 1.5)
		var hb := height(x, z)
		if hb < SEA + 0.3:
			continue
		_detail.cylinder(0.04, 2.4, Vector3(x, hb + 1.2, z), Color("eceff1"))
		_detail.cylinder(1.6, 0.6, Vector3(x, hb + 2.4, z), shades[i % shades.size()], _paint, 0.05, Vector3.ZERO, 10)
		for k in 2:
			_detail.box(Vector3(0.7, 0.12, 1.8), Vector3(x - 0.6 + k * 1.2, hb + 0.3, z + 1.6), Color("fafafa"), _paint, Vector3(-0.2, 0, 0))
		if i % 3 == 0:
			person(Vector3(x + 1.5, hb, z - 2.0), HOUSE_WALLS[i % HOUSE_WALLS.size()], 0.0)
	for i in 10:
		var n := boat("basket", {"kind": "bob", "y": SEA + 0.05, "amount": 0.07, "phase": i * 0.9})
		n.position = Vector3(-90.0 + i * 8.5 + _rng.randf_range(-2, 2), SEA + 0.05, -36.0 - _rng.randf_range(0, 14))
	for i in 5:
		var x := 30.0 + i * 3.0
		var z := -24.0
		var m := MeshBatch.new()
		m.cylinder(0.95, 0.5, Vector3(0, 0.25, 0), Color("4a3a28"), null, 1.05, Vector3.ZERO, 14)
		var n := Node3D.new()
		add_child(n)
		m.build(n)
		n.position = Vector3(x, height(x, z), z)
		n.rotation.x = 0.2
	for i in 4:
		boat("fishing", {"kind": "loop", "center": Vector3(-60.0 + i * 40.0, SEA + 0.1, -110.0), "radius": Vector2(30.0, 12.0), "speed": 0.05 * (1 if i % 2 else -1), "phase": i * 1.5, "bob": 0.15})
	# Beachfront hotels to the west.
	for i in 8:
		var h := _rng.randf_range(24.0, 60.0)
		block(Vector3(-50.0 - i * 15.0, 0, 6.0 - (i % 2) * 8.0), Vector3(11.0, h, 10.0), Color("f5f5f2").lerp(HOUSE_WALLS[i % HOUSE_WALLS.size()], 0.3), Color("37474f"), _far if i > 2 else _b)
	# Sơn Trà mountain: jungle on the peninsula, a white statue at the tip.
	scatter("tree", 260, Vector2(20, -170), Vector2(170, -40), 1.6, 4.0)
	_far.cylinder(1.6, 3.0, Vector3(48.0, height(48.0, -96.0) + 1.5, -96.0), Color("f5f5f5"), _paint, 1.2)
	_far.cylinder(0.9, 12.0, Vector3(48.0, height(48.0, -96.0) + 9.0, -96.0), Color("fafafa"), _paint, 0.6)
	# Marble Mountains: limestone outcrops inland.
	for p in [Vector2(110, 70), Vector2(125, 95), Vector2(95, 100)]:
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(16, 26, 14))
		instance("karst0", karst_mesh.bind(0), Transform3D(basis, Vector3(p.x, height(p.x, p.y) - 1.0, p.y)), false)
	scatter("tree", 90, Vector2(-170, 34), Vector2(170, 170))
	traffic(["bike", "car", "bike", "bike", "car", "truck"], 8)


func _bac_ninh() -> void:
	grass = Color("6f9e4e")
	road()
	# Rice paddies north of the park: flooded seedlings, green and ripe.
	var water := Palette.surface("water")
	var crops := [Color("8fbf5a"), Color("6fa84a"), Color("d6b54a"), Color("5f8f9a")]
	for i in range(-8, 9):
		for j in range(3, 11):
			var x := i * 20.0
			var z := -j * 15.0
			if x < -80.0 and z < -60.0:
				continue  # village
			var c: Color = crops[(i * 3 + j * 5 + 20) % crops.size()]
			var hz := height(x, z)
			_flat.box(Vector3(19.0, 0.06, 14.0), Vector3(x, hz + 0.1, z), c, water if c == crops[3] else _ground)
			_flat.box(Vector3(20.0, 0.25, 0.8), Vector3(x, hz + 0.05, z + 7.2), Color("8a7a4f"), _ground)
			_flat.box(Vector3(0.8, 0.25, 15.0), Vector3(x + 9.8, hz + 0.05, z), Color("8a7a4f"), _ground)
	for i in 6:
		person(Vector3(-40.0 + i * 25.0, 0.1, -50.0 - (i % 3) * 20.0), Color("8d6e63"), 0.0, Color("e8d9a8"))
	# Village with a pagoda, a lotus pond and bamboo.
	var v := Vector3(-120.0, 0, -110.0)
	_pagoda(v)
	_flat.box(Vector3(24.0, 0.08, 14.0), v + Vector3(0, 0.08, 26.0), Color("3f6f7a"), water)
	for k in 20:
		_detail.cylinder(0.35, 0.02, v + Vector3(_rng.randf_range(-11, 11), 0.15, 26.0 + _rng.randf_range(-6, 6)), Color("4f8a3c"), null, -1.0, Vector3.ZERO, 8)
		if k % 3 == 0:
			_detail.sphere(0.16, v + Vector3(_rng.randf_range(-10, 10), 0.3, 26.0 + _rng.randf_range(-5, 5)), Color("f48fb1"))
	for k in 14:
		var a := k * TAU / 14.0
		house(v + Vector3(cos(a) * 40.0, 0, sin(a) * 34.0), 6.0, 7.0, HOUSE_WALLS[k % HOUSE_WALLS.size()], Color("b5562e"), -a + PI / 2)
		plant("bamboo", v.x + cos(a + 0.2) * 46.0, v.z + sin(a + 0.2) * 40.0, 1.0)
	# Electronics plants of the industrial park to the east and west.
	for i in 5:
		for side in [-1.0, 1.0]:
			var c := Vector3(side * (55.0 + i * 26.0), 0, -2.0 + (i % 2) * 6.0)
			_modern_factory(c, Color("eceff1"), Color("1565c0") if (i + int(side)) % 2 == 0 else Color("00897b"))
	scatter("tree", 100, Vector2(-170, 32), Vector2(170, 170))
	for x in [-150.0, -100.0, -50.0, 0.0, 50.0, 100.0, 150.0]:
		_pylon(Vector3(x, 0, -38.0))
	traffic(["bike", "bike", "car", "truck", "bike", "car"], 9)


func _pagoda(c: Vector3) -> void:
	# Temple hall: red pillars, tiled double roof with upturned eaves,
	# a three-arch gate and a three-tier tower.
	_b.box(Vector3(16.0, 0.8, 10.0), c + Vector3(0, 0.4, 0), Color("9e9a90"), _paving)
	_b.box(Vector3(13.0, 3.6, 7.0), c + Vector3(0, 2.6, 0), Color("c9a27a"), _paint)
	for x in range(-6, 7, 2):
		_b.cylinder(0.22, 3.6, c + Vector3(x, 2.6, 3.8), Color("a1342b"), _paint)
	for tier in 2:
		var y := 4.6 + tier * 1.6
		var s := 1.0 - tier * 0.3
		_b.prism(Vector3(16.0 * s, 1.8, 10.5 * s), c + Vector3(0, y + 0.9, 0), Color("7b3b2a"), _paint, 0.5, Vector3(0, PI / 2, 0))
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_b.box(Vector3(0.3, 0.3, 1.4), c + Vector3(sx * 8.0 * s, y + 0.3, sz * 5.2 * s), Color("7b3b2a"), _paint, Vector3(0.6 * sz, 0.6 * sx * sz, 0))
	_b.box(Vector3(14.0, 0.25, 0.3), c + Vector3(0, 7.9, 0), Color("c8a04a"), _paint)
	var tower := c + Vector3(14.0, 0, 6.0)
	for t in 3:
		var w := 4.0 - t * 1.0
		var y := t * 3.2
		_b.box(Vector3(w, 2.4, w), tower + Vector3(0, y + 1.2, 0), Color("e6d6b8"), _paint)
		_b.cylinder(w * 0.95, 0.9, tower + Vector3(0, y + 2.85, 0), Color("7b3b2a"), _paint, w * 0.3, Vector3(0, PI / 4, 0), 4)
	_b.cylinder(0.12, 1.6, tower + Vector3(0, 10.4, 0), Color("c8a04a"), _paint)
	var gate := c + Vector3(0, 0, 16.0)
	for x in [-4.0, 0.0, 4.0]:
		_b.box(Vector3(2.4, 3.2 if x == 0.0 else 2.6, 1.0), gate + Vector3(x, 1.6 if x == 0.0 else 1.3, 0), Color("d8c8a8"), _paint)
		_b.prism(Vector3(3.0, 0.9, 1.6), gate + Vector3(x, (3.6 if x == 0.0 else 3.0), 0), Color("7b3b2a"), _paint, 0.5, Vector3(0, PI / 2, 0))
	plant("tree", c.x - 10.0, c.z + 8.0, 1.6)
	plant("tree", c.x + 9.0, c.z - 7.0, 1.5)


func _modern_factory(c: Vector3, wall: Color, stripe: Color) -> void:
	var batch := _b if absf(c.x) < 90.0 else _far
	var size := Vector3(22.0, 9.0, 18.0)
	batch.box(size, c + Vector3(0, size.y / 2.0, 0), wall, _paint)
	batch.box(Vector3(size.x + 0.1, 1.2, size.z + 0.1), c + Vector3(0, size.y - 1.4, 0), stripe, _paint)
	batch.box(Vector3(8.0, 6.0, 0.08), c + Vector3(-5.0, 3.6, size.z / 2.0 + 0.05), Color("8fb6d6"), window_material)
	batch.box(Vector3(5.0, 4.5, 0.08), c + Vector3(6.0, 2.25, size.z / 2.0 + 0.05), Color("78909c"), _steel)
	batch.box(Vector3(size.x - 4.0, 0.8, size.z - 4.0), c + Vector3(0, size.y + 0.4, 0), Color("90a4ae"), _steel)


func _pylon(p: Vector3) -> void:
	var hp := p + Vector3(0, height(p.x, p.z), 0)
	for sx in [-1.5, 1.5]:
		for sz in [-1.5, 1.5]:
			_far.bar(hp + Vector3(sx, 0, sz), hp + Vector3(sx * 0.3, 22.0, sz * 0.3), 0.18, Color("9aa5ad"), _steel)
	for y in [14.0, 18.0, 21.0]:
		_far.box(Vector3(9.0 - y * 0.2, 0.2, 0.2), hp + Vector3(0, y, 0), Color("9aa5ad"), _steel)


func _binh_duong() -> void:
	grass = Color("6a9a48")
	grass2 = Color("7fa452")
	soil = Color("a0522d")
	road()
	# Boulevard median with trees and flags
	_flat.box(Vector3(EXTENT * 2.0, 0.25, 1.4), Vector3(0, 0.12, 22.0), Color("6a8f4a"), _ground)
	# Industrial park: factories either side, worker housing behind.
	for i in 5:
		for side in [-1.0, 1.0]:
			_modern_factory(Vector3(side * (52.0 + i * 25.0), 0, -4.0 + (i % 2) * 5.0), Color("f2f2ee"), [Color("c62828"), Color("1565c0"), Color("2e7d32")][(i + 3) % 3])
	for i in 6:
		var x := -100.0 + i * 40.0
		block(Vector3(x, height(x, 52.0), 52.0), Vector3(24.0, 15.0, 10.0), HOUSE_WALLS[i % HOUSE_WALLS.size()], Color("455a64"))
	# Becamex-style tower downtown
	_far.box(Vector3(14.0, 80.0, 14.0), Vector3(-130.0, 40.0, 140.0), Color("8fb6d6"), window_material)
	_far.box(Vector3(10.0, 12.0, 10.0), Vector3(-130.0, 86.0, 140.0), Color("cfd8dc"), _steel)
	# Rubber plantations on the red earth to the north.
	rows("rubber", Vector2(-160, -165), Vector2(160, -35), Vector2(5.0, 4.5), 1.0)
	scatter("tree", 70, Vector2(-170, 70), Vector2(170, 170))
	traffic(["truck", "bike", "car", "truck", "bike", "car", "bike"], 9)


func ground_color(x: float, z: float, h: float, up: float) -> Color:
	match location_id:
		"binh_duong":
			if z < -32.0:
				return soil.lerp(Color("8b4a2b"), _noise.get_noise_2d(x * 3.0, z * 3.0) * 0.5 + 0.5)
		"india":
			return Color("c8aa78").lerp(Color("a99263"), _noise.get_noise_2d(x * 2.0, z * 2.0) * 0.5 + 0.5).lerp(Color("8a9a5a"), 0.15)
		"mexico":
			var c := Color("d8a874").lerp(Color("c48a5a"), _noise.get_noise_2d(x * 2.0, z * 2.0) * 0.5 + 0.5)
			if h > 4.0:
				c = Color("b9643c").lerp(Color("d08850"), fmod(h, 3.0) / 3.0)
			return c
		"usa":
			if absf(z) > 40.0 or absf(x) > 50.0:
				var field := absi(int(floor(x / 30.0) + floor(z / 30.0) * 3) % 3)
				var fields: Array[Color] = [Color("8faa4a"), Color("c8b45a"), Color("7a9a40")]
				return fields[field]
		"germany":
			var patch := _noise.get_noise_2d(x * 0.5 + 77.0, z * 0.5)
			if patch > 0.3 and up > 0.9:
				return Color("e8d33f")  # rapeseed in flower
		"indonesia":
			if up > 0.97 and h > 0.8 and h < 18.0:
				return Color("7fb84a").lerp(Color("5a9a8a"), fmod(h, 2.8) / 2.8)
			if h > 40.0:
				return Color("6a5f55").lerp(Color("4a433d"), smoothstep(40.0, 70.0, h))
	return super.ground_color(x, z, h, up)


# --- Abroad --------------------------------------------------------------------

func _thailand() -> void:
	has_sea = true
	sea_deep = Color("5b5a3a")
	sea_shallow = Color("8a7f55")
	sand = Color("a89a72")
	road()
	for i in 6:
		boat("longtail", {"kind": "loop", "center": Vector3(-40.0 + i * 30.0, SEA + 0.1, -62.0), "radius": Vector2(60.0, 7.0), "speed": 0.06 * (1 if i % 2 else -1), "phase": i * 1.1, "bob": 0.08})
	boat("barge", {"kind": "loop", "center": Vector3(0, SEA + 0.2, -62.0), "radius": Vector2(150.0, 5.0), "speed": 0.01, "phase": 0.0, "bob": 0.03})
	# Temple on the far bank: white stupa with a gold spire, a hall with
	# stacked red roofs and golden finials.
	var t := Vector3(-30.0, 0, -125.0)
	t.y = height(t.x, t.z)
	_far.box(Vector3(26.0, 1.0, 26.0), t + Vector3(0, 0.5, 0), Color("eceae4"), _paving)
	for k in 4:
		_far.cylinder(9.0 - k * 1.8, 2.2, t + Vector3(0, 1.0 + k * 2.2 + 1.1, 0), Color("f2efe8"), _paint, 8.0 - k * 1.8, Vector3.ZERO, 16)
	_far.sphere(4.6, t + Vector3(0, 11.0, 0), Color("f5f2ea"), _paint, Vector3(1, 1.15, 1), 14, 8)
	_far.cylinder(1.6, 16.0, t + Vector3(0, 21.0, 0), Color("d4a933"), _paint, 0.05, Vector3.ZERO, 12)
	var hall := t + Vector3(32.0, 0, 6.0)
	_far.box(Vector3(14.0, 5.0, 24.0), hall + Vector3(0, 3.0, 0), Color("f5f2ea"), _paint)
	for tier in 3:
		var s := 1.0 - tier * 0.18
		_far.prism(Vector3(16.0 * s, 4.0, 26.0 * s), hall + Vector3(0, 7.5 + tier * 2.2, 0), Color("b3261e") if tier % 2 == 0 else Color("1b5e20"), _paint)
	_far.box(Vector3(0.4, 0.4, 24.0), hall + Vector3(0, 13.4, 0), Color("d4a933"), _paint)
	for sz in [-1.0, 1.0]:
		_far.cylinder(0.25, 3.0, hall + Vector3(0, 14.5, sz * 12.0), Color("d4a933"), _paint, 0.02)
	for side in [-1.0, 1.0]:
		for i in 12:
			plant("palm", -150.0 + i * 26.0 + _rng.randf_range(-4, 4), -62.0 + side * 28.0 + _rng.randf_range(-3, 3), 1.0)
	for i in 6:
		var x := 50.0 + i * 20.0
		house(Vector3(x, height(x, -36.0), -36.0), 7.0, 6.0, Color("8d6e63"), Color("b3261e"), PI)
	for i in 4:
		_modern_factory(Vector3(60.0 + i * 26.0, 0, 6.0), Color("f2f2ee"), Color("1565c0"))
	scatter("palm", 50, Vector2(-170, 34), Vector2(170, 170))
	scatter("tree", 90, Vector2(-170, 34), Vector2(170, 170))
	traffic(["bike", "car", "tuktuk", "truck", "bike", "car"], 8)


func _indonesia() -> void:
	grass = Color("5f9a45")
	grass2 = Color("78ab4e")
	rock = Color("6a5f55")
	road()
	# Smoke rising from the crater.
	var smoke := StandardMaterial3D.new()
	smoke.albedo_color = Color(0.92, 0.92, 0.9, 0.55)
	smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var crater := Vector3(-50.0, land(-50.0, -165.0) + 4.0, -165.0)
	for k in (3 if low else 5):
		var m := MeshBatch.new()
		m.sphere(5.0, Vector3.ZERO, Color.WHITE, smoke, Vector3(1.4, 0.8, 1.0), 10, 6)
		mover(m, {"kind": "smoke", "origin": crater, "phase": k / 5.0})
	# Village: steep tiled roofs, a mosque with a dome.
	for i in 12:
		var x := 40.0 + (i % 6) * 15.0
		var z := 40.0 + (i / 6) * 16.0
		house(Vector3(x, height(x, z), z), 7.0, 7.0, HOUSE_WALLS[i % HOUSE_WALLS.size()], Color("a0472b"), 0.0)
	var mq := Vector3(-60.0, 0, 50.0)
	mq.y = height(mq.x, mq.z)
	_b.box(Vector3(14.0, 6.0, 14.0), mq + Vector3(0, 3.0, 0), Color("f2efe8"), _paint)
	_b.sphere(5.0, mq + Vector3(0, 6.0, 0), Color("2e7d32"), _paint, Vector3(1, 0.9, 1), 14, 8)
	_b.cylinder(0.8, 18.0, mq + Vector3(9.0, 9.0, 0), Color("f2efe8"), _paint, 0.6)
	_b.cylinder(0.9, 2.0, mq + Vector3(9.0, 19.0, 0), Color("2e7d32"), _paint, 0.0)
	scatter("palm", 120, Vector2(-170, -120), Vector2(170, 170), 1.0, 0.0, 16.0)
	scatter("banyan", 10, Vector2(-170, 30), Vector2(170, 170), 0.8)
	for i in 6:
		person(Vector3(-80.0 + i * 30.0, height(-80.0 + i * 30.0, -60.0), -60.0), Color("8d6e63"), 0.0, Color("e8d9a8"))
	for i in 3:
		_modern_factory(Vector3(-60.0 - i * 26.0, 0, 0.0), Color("f2f2ee"), Color("c62828"))
	traffic(["bike", "bike", "car", "truck", "bike"], 8)


func _india() -> void:
	road(Color("55524c"), Color("c2b49a"))
	grass = Color("a8a070")
	# Stone pavilions (chhatris) on a terrace and a step well.
	var c := Vector3(-70.0, 0, -80.0)
	_far.box(Vector3(40.0, 2.0, 24.0), c + Vector3(0, 1.0, 0), Color("c9905a"), _paving)
	for k in 3:
		var p := c + Vector3(-12.0 + k * 12.0, 2.0, 0)
		var s := 1.4 if k == 1 else 1.0
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_far.box(Vector3(0.6, 4.0 * s, 0.6), p + Vector3(sx * 2.4 * s, 2.0 * s, sz * 2.4 * s), Color("d29b62"), _paint)
		_far.box(Vector3(6.0 * s, 0.6, 6.0 * s), p + Vector3(0, 4.2 * s, 0), Color("c58a50"), _paint)
		_far.sphere(2.6 * s, p + Vector3(0, 4.5 * s, 0), Color("dba873"), _paint, Vector3(1, 1.1, 1), 12, 6)
		_far.cylinder(0.15, 1.6, p + Vector3(0, 7.6 * s, 0), Color("c8a04a"), _paint, 0.02)
	# Water tower and flat-roofed houses in bright colours.
	var wt := Vector3(60.0, 0, -50.0)
	for sx in [-2.0, 2.0]:
		for sz in [-2.0, 2.0]:
			_b.box(Vector3(0.6, 16.0, 0.6), wt + Vector3(sx, 8.0, sz), Color("a0a0a0"), _paving)
	_b.cylinder(4.0, 4.0, wt + Vector3(0, 18.0, 0), Color("b0b0aa"), _paving, -1.0, Vector3.ZERO, 16)
	var cols := [Color("f48fb1"), Color("81d4fa"), Color("ffcc80"), Color("c5e1a5"), Color("fff59d"), Color("ce93d8")]
	for i in 18:
		var x := -150.0 + (i % 9) * 34.0 + _rng.randf_range(-4, 4)
		var z := 40.0 + (i / 9) * 22.0 + _rng.randf_range(-3, 3)
		var h := 3.2 * (1 + i % 3)
		_b.box(Vector3(8.0, h, 7.0), Vector3(x, h / 2.0, z), cols[i % cols.size()], _paint)
		_b.box(Vector3(8.4, 0.5, 7.4), Vector3(x, h + 0.25, z), Color("eceff1"), _paint)
		_b.box(Vector3(1.4, 1.2, 0.05), Vector3(x - 1.5, h - 1.6, z + 3.52), Color("8fb6d6"), window_material)
	# Brick kiln chimney on the plain
	_far.cylinder(2.0, 24.0, Vector3(110.0, 12.0, -120.0), Color("9a4a32"), _paint, 1.2)
	scatter("banyan", 18, Vector2(-170, -170), Vector2(170, 170), 1.0)
	scatter("tree", 60, Vector2(-170, -170), Vector2(170, 170), 0.9)
	for i in 8:
		person(Vector3(-60.0 + i * 15.0, 0.1, 30.0), cols[i % cols.size()], PI)
	traffic(["tuktuk", "truck", "bike", "tuktuk", "car", "bike", "tuktuk"], 9)


func _mexico() -> void:
	road(Color("4e4a45"), Color("c9b896"), false)
	grass = Color("c9a46e")
	grass2 = Color("b98f5c")
	# Agave fields in rows, saguaro cacti scattered on the desert.
	rows("agave", Vector2(-160, -70), Vector2(-40, -32), Vector2(2.6, 2.6), 1.2)
	rows("agave", Vector2(40, -70), Vector2(160, -32), Vector2(2.6, 2.6), 1.2)
	scatter("cactus", 90, Vector2(-170, -170), Vector2(170, 170), 1.0, -INF, 3.0)
	scatter("bush", 50, Vector2(-170, -170), Vector2(170, 170), 0.7, -INF, 3.0)
	# Adobe houses with flat roofs and wooden beams.
	var adobe := [Color("d9a066"), Color("e8c39e"), Color("c97b4a"), Color("f2d7b6")]
	for i in 10:
		var x := -40.0 + i * 12.0
		var z := 38.0 + (i % 2) * 10.0
		_b.box(Vector3(8.0, 3.4, 7.0), Vector3(x, 1.7, z), adobe[i % adobe.size()], _paint)
		for k in 4:
			_b.box(Vector3(0.18, 0.18, 0.8), Vector3(x - 3.0 + k * 2.0, 3.0, z + 3.7), Color("6d4c41"))
		_b.box(Vector3(1.0, 1.0, 0.05), Vector3(x + 1.6, 1.7, z + 3.52), Color("8fb6d6"), window_material)
	# Step pyramid in the distance
	var p := Vector3(90.0, 0, -140.0)
	for k in 6:
		var w := 40.0 - k * 6.0
		_far.box(Vector3(w, 4.0, w), p + Vector3(0, 2.0 + k * 4.0, 0), Color("b8a58a").darkened(k * 0.03), _paving)
	_far.box(Vector3(6.0, 24.0, 8.0), p + Vector3(0, 12.0, 18.0), Color("a8957a"), _paving, Vector3(-0.85, 0, 0))
	_far.box(Vector3(8.0, 5.0, 8.0), p + Vector3(0, 26.5, 0), Color("a8957a"), _paving)
	traffic(["pickup", "truck", "car", "pickup", "truck"], 7)


func _germany() -> void:
	grass = Color("5f9445")
	grass2 = Color("7aab52")
	road(Color("3e4146"), Color("b9b9b4"))
	# Pine forest on the hills, a river with a barge to the north.
	scatter("pine", 360, Vector2(-170, -170), Vector2(170, 170), 1.4, 2.0)
	scatter("tree", 80, Vector2(-170, -170), Vector2(170, 170), 1.1)
	for p in [Vector3(-120, 0, -110), Vector3(-80, 0, -140), Vector3(100, 0, -120), Vector3(140, 0, -60), Vector3(130, 0, 90)]:
		p.y = height(p.x, p.z)
		wind_turbine(p, 28.0)
	# Half-timbered village with a church.
	var v := Vector3(-90.0, 0, 50.0)
	for i in 12:
		var a := i * TAU / 12.0
		var hp := v + Vector3(cos(a) * 30.0, 0, sin(a) * 22.0)
		hp.y = height(hp.x, hp.z)
		_timber_house(hp, -a + PI / 2, HOUSE_WALLS[i % 3 + 4])
	var ch := v + Vector3(0, height(v.x, v.z), 0)
	_b.box(Vector3(10.0, 8.0, 18.0), ch + Vector3(0, 4.0, 0), Color("ece6da"), _paint)
	_b.prism(Vector3(11.0, 6.0, 19.0), ch + Vector3(0, 11.0, 0), Color("8a3b2b"), _paint, 0.5, Vector3(0, 0, 0))
	_b.box(Vector3(5.0, 18.0, 5.0), ch + Vector3(0, 9.0, 11.0), Color("ece6da"), _paint)
	_b.cylinder(3.6, 10.0, ch + Vector3(0, 23.0, 11.0), Color("3f5a4f"), _steel, 0.0, Vector3(0, PI / 4, 0), 4)
	_b.cylinder(0.8, 0.1, ch + Vector3(0, 15.0, 13.55), Color("fafafa"), _paint, -1.0, Vector3(PI / 2, 0, 0), 12)
	traffic(["car", "car", "truck", "car", "pickup", "car"], 8)


func _timber_house(p: Vector3, yaw: float, wall: Color) -> void:
	var o := _b.origin
	_b.origin = Transform3D(Basis(Vector3.UP, yaw), p)
	_b.box(Vector3(7.0, 5.6, 8.0), Vector3(0, 2.8, 0), wall.lightened(0.3), _paint)
	var beam := Color("4e342e")
	for x in [-3.5, -1.2, 1.2, 3.5]:
		_b.box(Vector3(0.22, 5.6, 0.06), Vector3(x, 2.8, 4.02), beam)
	for y in [0.2, 2.8, 5.5]:
		_b.box(Vector3(7.0, 0.22, 0.06), Vector3(0, y, 4.02), beam)
	_b.bar(Vector3(-3.5, 0.2, 4.03), Vector3(-1.2, 2.8, 4.03), 0.16, beam)
	_b.bar(Vector3(3.5, 0.2, 4.03), Vector3(1.2, 2.8, 4.03), 0.16, beam)
	for x in [-2.3, 2.3]:
		_b.box(Vector3(1.0, 1.1, 0.05), Vector3(x, 4.1, 4.04), Color("8fb6d6"), window_material)
	_b.prism(Vector3(7.8, 4.5, 8.6), Vector3(0, 7.85, 0), Color("a0412d"), _paint, 0.5, Vector3(0, PI / 2, 0))
	_b.origin = o


func _usa() -> void:
	road(Color("3e4146"), Color("bdbdb6"))
	grass = Color("8aa24c")
	grass2 = Color("a2a95a")
	# Freight train on the line behind the plant.
	_flat.box(Vector3(EXTENT * 2.0, 0.3, 4.0), Vector3(0, 0.15, -32.0), Color("8a8270"), _paving)
	for r in [-0.75, 0.75]:
		_flat.box(Vector3(EXTENT * 2.0, 0.12, 0.12), Vector3(0, 0.36, -32.0 + r), Color("6d6d6d"), _steel)
	var train := MeshBatch.new()
	train.box(Vector3(18.0, 4.2, 3.2), Vector3(0, 2.6, 0), Color("f9a825"), _paint)
	train.box(Vector3(5.0, 1.2, 3.25), Vector3(6.0, 4.4, 0), Color("263238"), window_material)
	var tc := [Color("8d3b2b"), Color("455a64"), Color("2e5d3a"), Color("6d4c41")]
	for k in 7:
		train.box(Vector3(17.0, 4.0, 3.1), Vector3(-19.0 - k * 18.5, 2.5, 0), tc[k % tc.size()], _paint)
	var tn := Node3D.new()
	add_child(tn)
	train.build(tn)
	tn.position = Vector3(0, 0.3, -32.0)
	_movers.append({"node": tn, "kind": "lane", "from": -330.0, "to": 330.0, "speed": 9.0, "phase": 0.0})
	# Farm: red barn, grain silos, and the town water tower.
	var farm := Vector3(-100.0, 0, -80.0)
	_b.box(Vector3(14.0, 7.0, 20.0), farm + Vector3(0, 3.5, 0), Color("a3322a"), _paint)
	_b.prism(Vector3(15.0, 5.0, 21.0), farm + Vector3(0, 9.5, 0), Color("5d4037"), _paint)
	_b.box(Vector3(4.0, 5.0, 0.1), farm + Vector3(0, 2.5, 10.05), Color("fafafa"), _paint)
	for k in 3:
		var s := farm + Vector3(14.0 + k * 7.0, 0, -4.0)
		_b.cylinder(3.0, 14.0, s + Vector3(0, 7.0, 0), Color("cfd4d8"), _steel, -1.0, Vector3.ZERO, 16)
		_b.cylinder(3.1, 2.5, s + Vector3(0, 15.2, 0), Color("b0b5b8"), _steel, 0.4, Vector3.ZERO, 16)
	var wt := Vector3(80.0, 0, 60.0)
	for k in 4:
		var a := k * PI / 2.0 + PI / 4.0
		_b.bar(wt + Vector3(cos(a) * 4.0, 0, sin(a) * 4.0), wt + Vector3(cos(a) * 2.5, 22.0, sin(a) * 2.5), 0.45, Color("90a4ae"), _steel)
	_b.sphere(5.5, wt + Vector3(0, 26.0, 0), Color("dfe5ea"), _steel, Vector3(1, 0.8, 1), 16, 8)
	# Distribution warehouses either side and a skyline far away.
	for i in 4:
		for side in [-1.0, 1.0]:
			_modern_factory(Vector3(side * (55.0 + i * 28.0), 0, -2.0), Color("eceff1"), Color("546e7a"))
	for i in 14:
		var h := _rng.randf_range(30.0, 110.0)
		_far.box(Vector3(10.0, h, 10.0), Vector3(-60.0 + i * 12.0, h / 2.0, -160.0 - (i % 3) * 8.0), Color("8fa3b5").lerp(Color("c9d3dc"), _rng.randf()), window_material)
	rows("tree", Vector2(-160, 40), Vector2(160, 46), Vector2(9.0, 6.0), 1.1)
	scatter("tree", 50, Vector2(-170, -170), Vector2(170, 170), 1.2)
	traffic(["pickup", "truck", "car", "truck", "pickup", "car"], 9)
