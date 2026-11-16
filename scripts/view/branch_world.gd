## Building blocks for the scenery around a branch (see BranchThemes):
## a height-field terrain, a cheap animated sea, limestone karst islands,
## trees and other repeated props drawn with MultiMesh instancing, boats and
## vehicles that move, and the branch compound itself.
##
## Performance (the same budget as the first factory, phones included):
## - everything static is merged by MeshBatch into a few meshes, and
##   repeated props (trees, islands, cacti, containers) are one MultiMesh
##   per kind, so a whole branch costs a few dozen draw calls;
## - the terrain and sea are single grid meshes; lighting and ambient
##   occlusion are baked into vertex colours (darker at the foot of slopes,
##   wet rock at the waterline), so nothing is computed per frame;
## - the sea is one opaque shader with a few sine waves, no textures, no
##   reflections, no transparency;
## - only scenery near the factory casts shadows; small details (people,
##   parked bikes, deck chairs) are hidden when the camera is zoomed far out,
##   where they would be a pixel or two anyway; on phones and in the browser
##   there are fewer trees and islands and a coarser terrain grid.
class_name BranchWorld
extends Node3D

const EXTENT := 170.0
const SEA := -0.55

var location_id := ""
var sim: Simulation
## Shared night-lit materials from the main scenery (see DayNight).
var lamp_material: Material
var window_material: Material

var low := Palette.low_end()
var has_sea := false
## Theme colours for the terrain.
var grass := Color("6b9a4c")
var grass2 := Color("82a656")
var sand := Color("d9c89a")
var rock := Color("8d8a80")
var soil := Color("8a6f4d")
var seabed := Color("6f8a74")
## Sea colours: deep and shallow.
var sea_deep := Color("1d5a68")
var sea_shallow := Color("3f9a94")

var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _b := MeshBatch.new()  # near props, cast shadows
var _flat := MeshBatch.new()  # ground detail, no shadows
var _far := MeshBatch.new()  # distant, no shadows
var _detail := MeshBatch.new()  # small things hidden when zoomed out
var _instances := {}  # mesh key -> [mesh, Array[Transform3D], cast_shadow]
var _movers: Array[Dictionary] = []
var _rotors: Array[Node3D] = []
var _detail_root: Node3D
var _time := 0.0

var _paint: Material
var _steel: Material
var _ground: Material
var _paving: Material
var _rubber: Material
var _screen: Material


func _init() -> void:
	_paint = Palette.surface("paint")
	_steel = Palette.surface("steel")
	_ground = Palette.surface("ground")
	_paving = Palette.surface("paving")
	_rubber = Palette.surface("rubber")
	_screen = Palette.surface("screen")
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.02
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 3


## Draws the place; themes override it and end with finish().
func build() -> void:
	finish()


## Height of the theme's land at a point (sea floor is below SEA). Themes
## override this; the ground around the compound is always flat (see height).
func land(_x: float, _z: float) -> float:
	return 0.0


## Ground height with the factory lot and the road in front levelled.
func height(x: float, z: float) -> float:
	var dx := maxf(0.0, absf(x) - 30.0)
	var dz := maxf(0.0, maxf(z - 27.0, -z - 22.0))
	var flat := clampf(1.0 - sqrt(dx * dx + dz * dz) / 18.0, 0.0, 1.0)
	return lerpf(land(x, z), 0.0, smoothstep(0.0, 1.0, flat))


## Builds the merged meshes, the terrain, the sea and the instanced props.
## Themes add their props first, then call this.
func finish() -> void:
	_build_terrain()
	if has_sea:
		_build_sea()
	_b.build(self)
	_flat.build(self, false)
	_far.build(self, false)
	_detail_root = Node3D.new()
	add_child(_detail_root)
	_detail.build(_detail_root)
	for key in _instances:
		var entry: Array = _instances[key]
		var xforms: Array = entry[1]
		if xforms.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = entry[0]
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if not entry[2]:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	_instances.clear()


func _process(delta: float) -> void:
	var speed := 0.4 if TimeManager.speed == 0 else minf(2.0, float(TimeManager.speed))
	_time += delta * speed
	for m in _movers:
		var n: Node3D = m.node
		match m.kind:
			"loop":
				# Around an ellipse: centre, radii, speed (rad/s), phase.
				var a: float = m.phase + _time * float(m.speed)
				var c: Vector3 = m.center
				var r: Vector2 = m.radius
				n.position = c + Vector3(cos(a) * r.x, 0, sin(a) * r.y)
				n.rotation.y = -a + (0.0 if float(m.speed) > 0.0 else PI)
				if m.has("bob"):
					n.position.y = c.y + sin(_time * 1.3 + float(m.phase) * 3.0) * float(m.bob)
					n.rotation.z = sin(_time * 1.1 + float(m.phase)) * 0.04
			"bob":
				n.position.y = float(m.y) + sin(_time * 1.2 + float(m.phase)) * float(m.amount)
				n.rotation.z = sin(_time * 0.9 + float(m.phase)) * 0.05
				n.rotation.x = sin(_time * 0.7 + float(m.phase) * 2.0) * 0.03
			"lane":
				# Back and forth along X on a road: from, to, speed (m/s).
				var span: float = float(m.to) - float(m.from)
				var x := wrapf(float(m.phase) + _time * float(m.speed), 0.0, absf(span))
				n.position.x = float(m.from) + x * signf(span)
			"smoke":
				var t := fmod(_time * 0.25 + float(m.phase), 1.0)
				n.position = Vector3(m.origin) + Vector3(t * 6.0, t * 14.0, t * 2.0)
				n.scale = Vector3.ONE * (0.6 + t * 1.8)
	for r in _rotors:
		r.rotate_object_local(Vector3.FORWARD, delta * 1.1)
	if _detail_root:
		var cam := get_viewport().get_camera_3d()
		if cam:
			_detail_root.visible = cam.size < 85.0


# --- Terrain and sea -------------------------------------------------------------

func _build_terrain() -> void:
	var step := 5.0 if low else 3.4
	var n := int(EXTENT * 2.0 / step) + 1
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for j in n:
		for i in n:
			heights[j * n + i] = height(-EXTENT + i * step, -EXTENT + j * step)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(n * n)
	normals.resize(n * n)
	colors.resize(n * n)
	for j in n:
		for i in n:
			var x := -EXTENT + i * step
			var z := -EXTENT + j * step
			var h := heights[j * n + i]
			var hl := heights[j * n + maxi(i - 1, 0)]
			var hr := heights[j * n + mini(i + 1, n - 1)]
			var hd := heights[maxi(j - 1, 0) * n + i]
			var hu := heights[mini(j + 1, n - 1) * n + i]
			var nor := Vector3(hl - hr, 2.0 * step, hd - hu).normalized()
			verts[j * n + i] = Vector3(x, h, z)
			normals[j * n + i] = nor
			# Baked occlusion: hollows a little darker than ridges.
			var cavity := clampf((hl + hr + hd + hu) / 4.0 - h, -1.5, 1.5)
			colors[j * n + i] = ground_color(x, z, h, nor.y).darkened(clampf(cavity * 0.12, 0.0, 0.18))
	var idx := PackedInt32Array()
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			idx.append_array([a, a + 1, a + n, a + 1, a + n + 1, a + n])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _ground)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position.y = -0.04
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Terrain colour: beach by the water, rock on steep slopes, grass
## elsewhere in two shades. Themes may override for fields or desert.
func ground_color(x: float, z: float, h: float, up: float) -> Color:
	if has_sea and h < SEA - 0.4:
		return seabed
	if has_sea and h < SEA + 0.75:
		return sand
	var n := _noise.get_noise_2d(x * 1.7, z * 1.7) * 0.5 + 0.5
	var c := grass.lerp(grass2, n)
	if up < 0.82:
		c = c.lerp(rock, clampf((0.82 - up) * 4.0, 0.0, 1.0))
	return c


func _build_sea() -> void:
	var step := 8.0 if low else 5.0
	var ext := EXTENT + 60.0
	var n := int(ext * 2.0 / step) + 1
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var keep := PackedByteArray()
	verts.resize(n * n)
	colors.resize(n * n)
	keep.resize(n * n)
	for j in n:
		for i in n:
			var x := -ext + i * step
			var z := -ext + j * step
			var h := height(x, z) if absf(x) <= EXTENT and absf(z) <= EXTENT else -8.0
			verts[j * n + i] = Vector3(x, SEA, z)
			var depth := clampf((SEA - h) / 6.0, 0.0, 1.0)
			colors[j * n + i] = Color(depth, 0, 0)
			keep[j * n + i] = 1 if h < SEA + 0.6 else 0
	var idx := PackedInt32Array()
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			if keep[a] + keep[a + 1] + keep[a + n] + keep[a + n + 1] == 0:
				continue
			idx.append_array([a, a + 1, a + n, a + 1, a + n + 1, a + n])
	var normals := PackedVector3Array()
	normals.resize(n * n)
	normals.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, sea_material())
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


const SEA_SHADER := """
shader_type spatial;
render_mode cull_back, specular_schlick_ggx;
uniform vec4 deep : source_color;
uniform vec4 shallow : source_color;
uniform vec4 foam : source_color = vec4(0.93, 0.96, 0.96, 1.0);
varying vec3 wpos;
varying float depth;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	depth = COLOR.r;
}

void fragment() {
	vec2 p = wpos.xz;
	float t = TIME;
	// Four travelling sine waves: their slopes tilt the normal.
	vec2 d1 = vec2(0.31, 0.12);
	vec2 d2 = vec2(-0.14, 0.37);
	vec2 d3 = vec2(0.83, -0.55);
	vec2 d4 = vec2(-1.4, -1.1);
	vec2 g = d1 * cos(dot(d1, p) + t * 0.8) * 0.06
		+ d2 * cos(dot(d2, p) - t * 0.65) * 0.05
		+ d3 * cos(dot(d3, p) + t * 1.7) * 0.022
		+ d4 * cos(dot(d4, p) - t * 2.3) * 0.011;
	vec3 n = normalize(vec3(-g.x, 1.0, -g.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float shore = 1.0 - smoothstep(0.0, 0.07, depth);
	float wave = 0.5 + 0.5 * sin(depth * 60.0 - t * 1.6 + p.x * 0.05);
	vec3 col = mix(shallow.rgb, deep.rgb, smoothstep(0.0, 0.85, depth));
	col = mix(col, foam.rgb, shore * (0.45 + 0.4 * wave));
	ALBEDO = col;
	ROUGHNESS = 0.2;
	METALLIC = 0.0;
	SPECULAR = 0.4;
}
"""


func sea_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = SEA_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("deep", sea_deep)
	m.set_shader_parameter("shallow", sea_shallow)
	return m


# --- Instancing -----------------------------------------------------------------

## Adds one copy of a shared mesh (built once per kind) at a transform.
func instance(key: String, mesh_maker: Callable, xform: Transform3D, cast := true) -> void:
	if not _instances.has(key):
		_instances[key] = [mesh_maker.call(), [], cast]
	var entry: Array = _instances[key]
	entry[1].append(xform)


func place(x: float, z: float, yaw := 0.0, s := 1.0, sy := -1.0) -> Transform3D:
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3(s, s if sy < 0.0 else sy, s))
	return Transform3D(basis, Vector3(x, height(x, z), z))


## A limestone karst tower 1 m wide and 1 m tall (scaled per copy): steep
## sides with dark rain streaks, a notch worn in at the waterline and a cap
## of jungle on top. Colours carry the shading, so it needs no texture.
func karst_mesh(variant: int) -> ArrayMesh:
	var segs := 14 if low else 18
	var rings := 12
	var noise := FastNoiseLite.new()
	noise.seed = 100 + variant * 17
	noise.frequency = 0.9
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var radius := func(a: float, t: float) -> float:
		var notch := 0.86 if t < 0.05 else 1.0
		var profile := 1.0 - pow(t, 3.0) * 0.5
		var bumps := 1.0 + noise.get_noise_2d(cos(a) * 2.0 + variant, sin(a) * 2.0 + t * 2.5) * 0.35
		return 0.5 * notch * profile * bumps
	var top_y := func(a: float, r: float) -> float:
		return 1.0 + (0.5 - r) * 0.25 + noise.get_noise_2d(cos(a) * r * 6.0, sin(a) * r * 6.0) * 0.06
	var ring_pts := []
	for k in rings + 1:
		var t := float(k) / rings
		var pts := []
		for s in segs:
			var a := s * TAU / segs
			var r: float = radius.call(a, minf(t, 0.92))
			if t > 0.92:
				r *= 1.0 - (t - 0.92) / 0.08 * 0.35
			pts.append(Vector3(cos(a) * r, t * 0.95, sin(a) * r))
		ring_pts.append(pts)
	var rock_col := func(p: Vector3, t: float) -> Color:
		var streak := noise.get_noise_2d(atan2(p.z, p.x) * 6.0, 0.0) * 0.5 + 0.5
		var c := Color("8f8b80").lerp(Color("5f5d57"), streak * 0.6)
		c = c.lerp(Color("a68a62"), clampf(noise.get_noise_2d(p.x * 9.0, t * 4.0) * 1.5, 0.0, 0.35))
		# Jungle clings to the upper slopes and to ledges; sheer faces stay bare.
		var ledge := noise.get_noise_2d(p.x * 4.0 + p.z * 3.0, t * 7.0)
		var green := maxf(smoothstep(0.5, 0.72, t + noise.get_noise_2d(p.x * 5.0, p.z * 5.0) * 0.3), smoothstep(0.15, 0.35, ledge) * smoothstep(0.08, 0.25, t))
		c = c.lerp(Color("3d6a2f").lerp(Color("4c7a36"), streak), green * 0.92)
		if t < 0.04:
			c = c.darkened(0.25)
		return c
	for k in rings:
		var t0 := float(k) / rings
		var t1 := float(k + 1) / rings
		var r0: Array = ring_pts[k]
		var r1: Array = ring_pts[k + 1]
		for s in segs:
			var s2 := (s + 1) % segs
			var a: Vector3 = r0[s]
			var b: Vector3 = r0[s2]
			var c: Vector3 = r1[s]
			var d: Vector3 = r1[s2]
			verts.append_array([a, b, c, b, d, c])
			colors.append_array([rock_col.call(a, t0), rock_col.call(b, t0), rock_col.call(c, t1), rock_col.call(b, t0), rock_col.call(d, t1), rock_col.call(c, t1)])
	# Domed, forested top
	var top: Array = ring_pts[rings]
	var apex := Vector3(0, 1.0, 0)
	for s in segs:
		var a: Vector3 = top[s]
		var b: Vector3 = top[(s + 1) % segs]
		var mid_a := a.lerp(apex, 0.5) + Vector3(0, 0.03, 0)
		var mid_b := b.lerp(apex, 0.5) + Vector3(0, 0.03, 0)
		var g1 := Color("3d6a2f")
		var g2 := Color("4a7a36")
		verts.append_array([a, b, mid_a, b, mid_b, mid_a, mid_a, mid_b, apex])
		colors.append_array([g1, g1, g2, g1, g2, g2, g2, g2, g2.lightened(0.05)])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in verts.size():
		st.set_color(colors[i])
		st.add_vertex(verts[i])
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, Palette.surface("ground"))
	return mesh


## Places a karst island standing in the sea.
func karst(x: float, z: float, w: float, h: float) -> void:
	var v := _rng.randi() % 3
	var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(w * _rng.randf_range(0.8, 1.2), h, w * _rng.randf_range(0.8, 1.2)))
	instance("karst%d" % v, karst_mesh.bind(v), Transform3D(basis, Vector3(x, SEA - 0.03 * h - 0.5, z)), false)


# --- Plants ---------------------------------------------------------------------

func _leaf_mesh(kind: String) -> ArrayMesh:
	var m := MeshBatch.new()
	var trunk := Color("6b4a2e")
	match kind:
		"tree":
			m.cylinder(0.24, 2.0, Vector3(0, 1.0, 0), trunk, null, 0.15, Vector3.ZERO, 6)
			for c in [[Vector3(0, 2.7, 0), 1.35, 0.0], [Vector3(0.75, 2.5, 0.35), 0.95, 0.06], [Vector3(-0.65, 2.45, -0.3), 0.9, 0.06], [Vector3(0.1, 3.35, -0.2), 0.95, -0.05]]:
				m.sphere(c[1], c[0], Color("4f8a3c").darkened(c[2]), null, Vector3(1, 0.85, 1), 8, 5)
		"pine":
			m.cylinder(0.18, 1.4, Vector3(0, 0.7, 0), trunk, null, 0.12, Vector3.ZERO, 6)
			for k in 4:
				m.cylinder(1.5 - k * 0.3, 1.7, Vector3(0, 1.6 + k * 0.95, 0), Color("2f5d33").lightened(k * 0.04), null, 0.0, Vector3(0, k * 0.4, 0), 8)
		"palm":
			var prev := Vector3.ZERO
			for i in range(1, 6):
				var t := i / 5.0
				var q := Vector3(t * t * 1.4, 7.5 * t, 0)
				m.bar(prev, q, 0.32 - t * 0.08, Color("8d7b62").darkened(0.06 * (i % 2)), null, true)
				prev = q
			for f in 8:
				var a := f * TAU / 8.0
				var dir := Vector3(cos(a), 0, sin(a))
				var mid := prev + dir * 1.3 + Vector3(0, 0.35, 0)
				var tip := prev + dir * 2.6 + Vector3(0, -0.6, 0)
				m.bar(prev, mid, 0.12, Color("4f8a3c"))
				m.bar(mid, tip, 0.1, Color("5f9c44"))
				m.box(Vector3(0.7, 0.03, 1.5), prev.lerp(tip, 0.55) + Vector3(0, 0.05, 0), Color("5a9a3e"), null, Vector3(0, -a + PI / 2.0, 0.25))
			for n in 3:
				m.sphere(0.18, prev + Vector3(cos(n * 2.1) * 0.25, -0.3, sin(n * 2.1) * 0.25), Color("6b8e23"), null, Vector3.ONE, 6, 4)
		"rubber":
			# Plantation rubber tree: slim straight trunk, high narrow crown.
			m.cylinder(0.16, 4.0, Vector3(0, 2.0, 0), Color("8a8170"), null, 0.12, Vector3.ZERO, 6)
			m.sphere(1.2, Vector3(0, 4.9, 0), Color("3f7330"), null, Vector3(1, 1.3, 1), 8, 5)
			m.sphere(0.9, Vector3(0.4, 5.9, 0.2), Color("4b8236"), null, Vector3(1, 1.1, 1), 7, 4)
		"bamboo":
			for k in 7:
				var a := k * TAU / 7.0
				var base := Vector3(cos(a) * 0.3, 0, sin(a) * 0.3)
				var lean := Vector3(cos(a), 0, sin(a)) * 1.8
				m.bar(base, base + Vector3(0, 6.5, 0) + lean, 0.07, Color("8bb24a"), null, true)
				m.sphere(0.6, base + Vector3(0, 5.6, 0) + lean * 0.85, Color("6f9f3a"), null, Vector3(1.4, 0.5, 0.9), 7, 4)
		"cactus":
			# Saguaro: a ribbed column with two raised arms.
			var g := Color("4f7d45")
			m.cylinder(0.32, 5.0, Vector3(0, 2.5, 0), g, null, 0.3, Vector3.ZERO, 10)
			m.sphere(0.3, Vector3(0, 5.0, 0), g, null, Vector3.ONE, 8, 5)
			for sx in [-1.0, 1.0]:
				var y := 2.0 + (0.6 if sx > 0 else 0.0)
				m.bar(Vector3(0, y, 0), Vector3(sx * 0.9, y + 0.2, 0), 0.4, g, null, true)
				m.cylinder(0.2, 1.6, Vector3(sx * 0.9, y + 1.0, 0), g, null, 0.19, Vector3.ZERO, 8)
				m.sphere(0.19, Vector3(sx * 0.9, y + 1.8, 0), g, null, Vector3.ONE, 6, 4)
		"agave":
			for k in 9:
				var a := k * TAU / 9.0
				m.box(Vector3(0.16, 1.1, 0.05), Vector3(cos(a) * 0.3, 0.45, sin(a) * 0.3), Color("6f9b9a"), null, Vector3(sin(a) * 0.6, 0, -cos(a) * 0.6))
		"banyan":
			m.cylinder(0.7, 3.0, Vector3(0, 1.5, 0), Color("6d5a45"), null, 0.5, Vector3.ZERO, 8)
			for k in 5:
				var a := k * TAU / 5.0
				m.bar(Vector3(cos(a) * 3.0, 0, sin(a) * 3.0), Vector3(cos(a) * 3.0, 3.6, sin(a) * 3.0), 0.12, Color("6d5a45"))
			m.sphere(4.2, Vector3(0, 4.6, 0), Color("4c7a38"), null, Vector3(1.2, 0.55, 1.2), 10, 6)
			m.sphere(3.0, Vector3(0.8, 5.6, -0.5), Color("5b8a43"), null, Vector3(1.1, 0.6, 1.1), 9, 5)
		"bush":
			for k in 3:
				m.sphere(0.6 - k * 0.1, Vector3((k - 1) * 0.45, 0.35, (k % 2) * 0.3), Color("3f7a34").darkened(0.05 * k), null, Vector3(1, 0.75, 1), 7, 4)
	return m.build_mesh()


func plant(kind: String, x: float, z: float, s := 1.0, cast := true) -> void:
	instance(kind, _leaf_mesh.bind(kind), place(x, z, _rng.randf() * TAU, s * _rng.randf_range(0.85, 1.15)), cast)


## Scatters a kind of plant at random in a rectangle, avoiding the compound,
## the road and the sea. Fewer on phones.
func scatter(kind: String, count: int, from: Vector2, to: Vector2, s := 1.0, min_h := -INF, max_h := INF) -> void:
	var n := count / 2 if low else count
	var tries := 0
	var placed := 0
	while placed < n and tries < n * 12:
		tries += 1
		var x := _rng.randf_range(from.x, to.x)
		var z := _rng.randf_range(from.y, to.y)
		if not free_spot(x, z):
			continue
		var h := height(x, z)
		if h < min_h or h > max_h or (has_sea and h < SEA + 1.0):
			continue
		plant(kind, x, z, s, absf(x) < 70.0 and absf(z) < 60.0)
		placed += 1


## Rows of trees (plantations, orchards) in a rectangle.
func rows(kind: String, from: Vector2, to: Vector2, gap: Vector2, s := 1.0) -> void:
	var g := gap * (1.4 if low else 1.0)
	var x := from.x
	while x <= to.x:
		var z := from.y
		while z <= to.y:
			if free_spot(x, z):
				instance(kind, _leaf_mesh.bind(kind), place(x + _rng.randf_range(-0.2, 0.2), z, _rng.randf() * TAU, s * _rng.randf_range(0.9, 1.1)), absf(x) < 60.0)
			z += g.y
		x += g.x


## Not on the compound or the road in front of it.
func free_spot(x: float, z: float) -> bool:
	if x > -27 and x < 27 and z > -21 and z < 18:
		return false
	return absf(z - 22.0) > 5.0


# --- Props ----------------------------------------------------------------------

func lamp_post(p: Vector3, yaw := 0.0) -> void:
	_b.cylinder(0.08, 5.0, p + Vector3(0, 2.5, 0), Color("5b6670"), _steel, 0.06, Vector3.ZERO, 8)
	var arm := Vector3(sin(yaw), 0, cos(yaw))
	_b.bar(p + Vector3(0, 4.9, 0), p + Vector3(0, 5.1, 0) + arm * 1.0, 0.07, Color("5b6670"), _steel)
	_b.box(Vector3(0.5, 0.12, 0.25), p + Vector3(0, 5.05, 0) + arm * 1.1, Color("fff3c4"), lamp_material, Vector3(0, yaw, 0))


## A simple person standing (or sitting), part of the small details.
func person(p: Vector3, shirt: Color, yaw := 0.0, hat := Color(0, 0, 0, 0)) -> void:
	var o := _detail.origin
	_detail.origin = Transform3D(Basis(Vector3.UP, yaw), p)
	for sx in [-0.11, 0.11]:
		_detail.box(Vector3(0.14, 0.75, 0.16), Vector3(sx, 0.38, 0), Color("37474f"))
	_detail.box(Vector3(0.42, 0.55, 0.26), Vector3(0, 1.03, 0), shirt)
	_detail.sphere(0.17, Vector3(0, 1.48, 0), Color("e3b08a"), null, Vector3.ONE, 8, 5)
	if hat.a > 0.0:
		_detail.cylinder(0.32, 0.18, Vector3(0, 1.62, 0), hat, null, 0.0, Vector3.ZERO, 10)
	else:
		_detail.sphere(0.18, Vector3(0, 1.55, -0.02), Color("2b2420"), null, Vector3(1, 0.7, 1), 8, 4)
	_detail.origin = o


## A building with rows of windows that light up at night.
func block(c: Vector3, size: Vector3, wall: Color, roof := Color("5d6066"), batch: MeshBatch = null) -> void:
	var b := batch if batch else _b
	b.box(size, c + Vector3(0, size.y / 2.0, 0), wall, _paint)
	b.box(Vector3(size.x + 0.3, 0.3, size.z + 0.3), c + Vector3(0, size.y + 0.15, 0), roof, _paint)
	var floors := int(size.y / 3.2)
	for f in floors:
		var y := 1.7 + f * 3.2
		for side in [-1.0, 1.0]:
			var cols := int(size.x / 2.6)
			for k in cols:
				var x := -size.x / 2.0 + (k + 0.5) * size.x / cols
				b.box(Vector3(1.3, 1.4, 0.06), c + Vector3(x, y, side * (size.z / 2.0 + 0.02)), Color("8fb6d6"), window_material)


## A pitched-roof house.
func house(c: Vector3, w: float, d: float, wall: Color, roof: Color, yaw := 0.0, batch: MeshBatch = null) -> void:
	var b := batch if batch else _b
	var o := b.origin
	b.origin = Transform3D(Basis(Vector3.UP, yaw), c)
	b.box(Vector3(w, 3.0, d), Vector3(0, 1.5, 0), wall, _paint)
	b.prism(Vector3(w + 0.5, 1.8, d + 0.4), Vector3(0, 3.9, 0), roof, _paint, 0.5, Vector3(0, PI / 2.0, 0))
	for x in [-w / 4.0, w / 4.0]:
		b.box(Vector3(0.8, 0.9, 0.05), Vector3(x, 1.8, d / 2.0 + 0.02), Color("8fb6d6"), window_material)
	b.box(Vector3(0.9, 1.9, 0.05), Vector3(0, 0.95, d / 2.0 + 0.03), Color("6d4c41"))
	b.origin = o


## A moving node (boat, car) built from a batch and animated in _process.
func mover(batch: MeshBatch, data: Dictionary) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	batch.build(n)
	data.node = n
	_movers.append(data)
	return n


func boat(kind: String, data: Dictionary) -> Node3D:
	var m := MeshBatch.new()
	match kind:
		"junk":
			# Tourist junk: dark wooden hull, white cabin decks, rust sails.
			m.box(Vector3(3.2, 1.0, 13.0), Vector3(0, 0.3, 0), Color("5b3a24"), _paint)
			m.prism(Vector3(3.2, 1.0, 2.5), Vector3(0, 0.3, 7.5), Color("5b3a24"), _paint, 0.5, Vector3(PI / 2, 0, 0))
			m.box(Vector3(2.8, 1.4, 8.0), Vector3(0, 1.5, -1.0), Color("f2efe6"), _paint)
			m.box(Vector3(2.4, 1.1, 5.0), Vector3(0, 2.7, -1.5), Color("f2efe6"), _paint)
			for z in [-3.0, -1.0, 1.0]:
				m.box(Vector3(2.85, 0.6, 1.2), Vector3(0, 1.6, z), Color("3d5566"), window_material)
			m.box(Vector3(2.6, 0.12, 8.4), Vector3(0, 2.25, -1.0), Color("6d4c41"))
			for s in [[-0.5, 6.0, 4.5], [3.0, 7.5, 5.5]]:
				var z: float = s[0]
				var mast: float = s[1]
				m.cylinder(0.08, mast, Vector3(0, 2.0 + mast / 2.0, z), Color("4e342e"), null, -1.0, Vector3.ZERO, 6)
				var w: float = s[2]
				m.box(Vector3(0.05, mast * 0.7, w), Vector3(0.1, 2.6 + mast * 0.45, z - w * 0.35), Color("b5562e"), null, Vector3(0, 0, 0))
				for k in 5:
					m.box(Vector3(0.08, 0.06, w + 0.2), Vector3(0.12, 2.6 + mast * 0.1 + k * mast * 0.14, z - w * 0.35), Color("4e342e"))
		"fishing":
			m.box(Vector3(1.8, 0.7, 6.0), Vector3(0, 0.2, 0), Color("1e6fa8"), _paint)
			m.prism(Vector3(1.8, 0.7, 1.4), Vector3(0, 0.2, 3.7), Color("1e6fa8"), _paint, 0.5, Vector3(PI / 2, 0, 0))
			m.box(Vector3(1.85, 0.12, 6.0), Vector3(0, 0.58, 0), Color("c62828"))
			m.box(Vector3(1.3, 1.1, 1.6), Vector3(0, 1.1, -1.6), Color("eceff1"), _paint)
			m.cylinder(0.05, 3.0, Vector3(0, 1.8, 1.0), Color("6d4c41"), null, -1.0, Vector3.ZERO, 6)
		"basket":
			# Round woven basket boat of the central coast.
			m.cylinder(0.95, 0.5, Vector3(0, 0.1, 0), Color("4a3a28"), null, 1.05, Vector3.ZERO, 14)
			m.cylinder(1.08, 0.08, Vector3(0, 0.38, 0), Color("2f5d8a"), _paint, -1.0, Vector3.ZERO, 14)
		"cargo":
			m.box(Vector3(9.0, 3.4, 42.0), Vector3(0, 0.9, 0), Color("27323d"), _paint)
			m.box(Vector3(9.05, 1.2, 42.0), Vector3(0, -0.3, 0), Color("a33a2a"), _paint)
			m.prism(Vector3(9.0, 3.4, 5.0), Vector3(0, 0.9, 23.5), Color("27323d"), _paint, 0.5, Vector3(PI / 2, 0, 0))
			m.box(Vector3(8.0, 6.0, 5.0), Vector3(0, 5.6, -17.0), Color("eceff1"), _paint)
			m.box(Vector3(8.1, 0.8, 5.1), Vector3(0, 7.6, -17.0), Color("37474f"), window_material)
			m.cylinder(0.8, 2.5, Vector3(0, 9.6, -18.5), Color("c62828"), _paint, -1.0, Vector3.ZERO, 10)
			var cc := [Color("c62828"), Color("1565c0"), Color("f9a825"), Color("2e7d32"), Color("6d4c41"), Color("eceff1")]
			for z in range(-12, 21, 3):
				for x in [-2.6, 0.0, 2.6]:
					for y in 2:
						m.box(Vector3(2.4, 2.4, 2.9), Vector3(x, 3.8 + y * 2.45, z), cc[(z * 7 + int(x * 3) + y * 5 + 40) % cc.size()], _paint)
		"longtail":
			m.box(Vector3(1.2, 0.5, 8.0), Vector3(0, 0.1, 0), Color("7a4f2a"), _paint)
			m.prism(Vector3(1.2, 0.8, 2.0), Vector3(0, 0.3, 4.8), Color("7a4f2a"), _paint, 0.5, Vector3(PI / 2, 0, 0))
			m.box(Vector3(1.1, 0.06, 4.0), Vector3(0, 1.3, -0.5), Color("1565c0"), _paint)
			for z in [-2.4, 1.4]:
				for x in [-0.5, 0.5]:
					m.cylinder(0.03, 1.0, Vector3(x, 0.8, z), Color("5d4037"), null, -1.0, Vector3.ZERO, 5)
			m.bar(Vector3(0, 0.6, -4.0), Vector3(0, 0.0, -6.0), 0.08, Color("37474f"), _steel)
		"barge":
			m.box(Vector3(6.0, 1.6, 30.0), Vector3(0, 0.3, 0), Color("263238"), _paint)
			m.box(Vector3(5.0, 0.8, 22.0), Vector3(0, 1.3, 2.0), Color("5d4037"))
			m.box(Vector3(5.0, 3.0, 4.0), Vector3(0, 2.6, -12.0), Color("eceff1"), _paint)
			m.box(Vector3(5.05, 0.6, 4.05), Vector3(0, 3.6, -12.0), Color("37474f"), window_material)
	return mover(m, data)


## A floating fish farm house: a raft of plastic drums, a timber deck, a
## small house with a tin roof and a few net pens around it.
func raft_house(p: Vector3, wall: Color) -> void:
	var m := MeshBatch.new()
	m.box(Vector3(9.0, 0.25, 7.0), Vector3(0, 0.35, 0), Color("8d6e63"))
	for x in range(-4, 5, 2):
		for z in [-3.0, 3.0]:
			m.cylinder(0.4, 0.8, Vector3(x, 0.1, z), Color("1e88e5"), _paint, -1.0, Vector3(PI / 2, 0, 0), 8)
	m.box(Vector3(5.0, 2.6, 4.0), Vector3(-1.0, 1.75, 0), wall, _paint)
	m.prism(Vector3(5.6, 1.2, 4.6), Vector3(-1.0, 3.6, 0), Color("4f6d7a"), _steel, 0.5, Vector3(0, PI / 2, 0))
	m.box(Vector3(0.9, 0.9, 0.05), Vector3(-2.0, 2.0, 2.03), Color("8fb6d6"), window_material)
	for k in 3:
		var c := Vector3(6.5 + k * 4.5, 0.2, -1.0 + (k % 2) * 2.5)
		for s in 4:
			var a := s * PI / 2
			m.box(Vector3(4.0, 0.15, 0.15), c + Vector3(cos(a) * 2.0, 0, sin(a) * 2.0), Color("6d4c41"), null, Vector3(0, a + PI / 2, 0))
	var n := Node3D.new()
	n.position = p
	add_child(n)
	m.build(n, false)
	_movers.append({"node": n, "kind": "bob", "y": p.y, "amount": 0.06, "phase": p.x * 0.1})


func wind_turbine(p: Vector3, h := 22.0) -> void:
	_far.cylinder(0.45, h, p + Vector3(0, h / 2.0, 0), Color("f2f4f5"), _paint, 0.22, Vector3.ZERO, 10)
	_far.box(Vector3(0.8, 0.8, 1.8), p + Vector3(0, h + 0.2, 0.2), Color("eef0f1"), _paint)
	var hub := Node3D.new()
	hub.position = p + Vector3(0, h + 0.2, 1.25)
	add_child(hub)
	var hb := MeshBatch.new()
	hb.sphere(0.45, Vector3.ZERO, Color("eeeeee"), _paint, Vector3(1, 1, 1.4))
	for k in 3:
		var a := k * TAU / 3.0
		var dir := Vector3(sin(a), cos(a), 0)
		hb.bar(dir * 0.3, dir * 9.0, 0.34, Color("fafafa"), _paint)
	hb.build(hub, false)
	hub.rotation.z = _rng.randf() * TAU
	_rotors.append(hub)


## Vehicles driving along the road in front of the compound.
func traffic(kinds: Array, count: int) -> void:
	var colors := [Color("c62828"), Color("f9a825"), Color("eceff1"), Color("1565c0"), Color("2e7d32"), Color("212121"), Color("78909c")]
	var n := maxi(2, count * 2 / 3) if low else count
	for i in n:
		var east := i % 2 == 0
		var kind: String = kinds[i % kinds.size()]
		var lane := 23.5 if east else 20.5
		var node: Node3D
		match kind:
			"car":
				node = BuildingsView._car(self, Vector3(0, 0, lane), PI / 2 if east else -PI / 2, colors[i % colors.size()], lamp_material)
			_:
				var m := MeshBatch.new()
				_vehicle(m, kind, colors[(i * 3) % colors.size()])
				node = Node3D.new()
				add_child(node)
				m.build(node)
				node.position = Vector3(0, 0, lane)
				node.rotation.y = PI / 2 if east else -PI / 2
		_movers.append({"node": node, "kind": "lane", "from": -160.0 if east else 160.0, "to": 160.0 if east else -160.0,
			"speed": (5.0 if kind == "bike" else 7.0) * _rng.randf_range(0.85, 1.15), "phase": i * 320.0 / n + _rng.randf() * 10.0})


const BuildingsView := preload("res://scripts/view/buildings_view.gd")


func _vehicle(m: MeshBatch, kind: String, color: Color) -> void:
	match kind:
		"bike":
			for z in [-0.6, 0.6]:
				m.cylinder(0.28, 0.1, Vector3(0, 0.28, z), Color("17181a"), _rubber, -1.0, Vector3(0, 0, PI / 2), 10)
			m.box(Vector3(0.32, 0.32, 1.0), Vector3(0, 0.5, -0.05), color, _paint)
			m.box(Vector3(0.28, 0.6, 0.16), Vector3(0, 0.78, 0.5), color, _paint, Vector3(-0.3, 0, 0))
			m.box(Vector3(0.42, 0.55, 0.26), Vector3(0, 1.17, -0.15), Color("eceff1"))
			m.sphere(0.17, Vector3(0, 1.62, -0.12), Color("f9a825"), _paint, Vector3(1, 0.9, 1.05), 8, 5)
			m.box(Vector3(0.16, 0.1, 0.06), Vector3(0, 1.02, 0.66), Color("fff3c4"), lamp_material)
		"truck":
			m.box(Vector3(2.3, 2.2, 2.0), Vector3(0, 1.6, 3.0), color, _paint)
			m.box(Vector3(2.2, 0.8, 0.06), Vector3(0, 2.1, 4.02), Color("26323e"), _paint)
			m.box(Vector3(2.4, 2.8, 6.5), Vector3(0, 2.0, -1.4), Color("eceff1"), _paint)
			for z in [-3.4, -1.8, 3.0]:
				for x in [-1.05, 1.05]:
					m.cylinder(0.48, 0.35, Vector3(x, 0.48, z), Color("17181a"), _rubber, -1.0, Vector3(0, 0, PI / 2), 12)
			m.box(Vector3(0.4, 0.15, 0.05), Vector3(0.8, 1.0, 4.02), Color("fff3c4"), lamp_material)
			m.box(Vector3(0.4, 0.15, 0.05), Vector3(-0.8, 1.0, 4.02), Color("fff3c4"), lamp_material)
		"tuktuk":
			m.box(Vector3(1.3, 0.9, 2.2), Vector3(0, 0.75, 0), Color("2e7d32"), _paint)
			m.box(Vector3(1.35, 0.1, 2.3), Vector3(0, 1.85, -0.1), Color("f9a825"), _paint)
			for x in [-0.6, 0.6]:
				m.box(Vector3(0.06, 0.9, 0.06), Vector3(x, 1.35, 0.9), Color("212121"))
				m.cylinder(0.25, 0.15, Vector3(x, 0.25, -0.7), Color("17181a"), _rubber, -1.0, Vector3(0, 0, PI / 2), 10)
			m.cylinder(0.25, 0.15, Vector3(0, 0.25, 0.9), Color("17181a"), _rubber, -1.0, Vector3(0, 0, PI / 2), 10)
		"pickup":
			m.box(Vector3(2.0, 0.8, 5.4), Vector3(0, 0.8, 0), color, _paint)
			m.box(Vector3(1.9, 0.8, 2.0), Vector3(0, 1.6, 0.6), color, _paint)
			m.box(Vector3(1.85, 0.6, 0.06), Vector3(0, 1.65, 1.62), Color("26323e"), _paint)
			for z in [-1.7, 1.7]:
				for x in [-0.95, 0.95]:
					m.cylinder(0.42, 0.3, Vector3(x, 0.42, z), Color("17181a"), _rubber, -1.0, Vector3(0, 0, PI / 2), 12)
			m.box(Vector3(0.35, 0.15, 0.05), Vector3(0.7, 0.9, 2.72), Color("fff3c4"), lamp_material)
			m.box(Vector3(0.35, 0.15, 0.05), Vector3(-0.7, 0.9, 2.72), Color("fff3c4"), lamp_material)


## The road in front of the compound, with kerbs, lane lines and lamps.
func road(asphalt := Color("474b51"), pavement := Color("b9b5aa"), lamps := true) -> void:
	_flat.box(Vector3(EXTENT * 2.0, 0.08, 8.0), Vector3(0, 0.04, 22.0), asphalt, _paving)
	for i in range(-34, 35):
		_flat.box(Vector3(2.6, 0.012, 0.16), Vector3(i * 5.0, 0.086, 22.0), Color("eeeeea"))
	for z in [17.5, 26.5]:
		_flat.box(Vector3(EXTENT * 2.0, 0.14, 1.2), Vector3(0, 0.07, z), pavement, _paving)
	if lamps:
		for i in range(-6, 7):
			lamp_post(Vector3(i * 22.0 + 6.0, 0, 26.6), PI)
