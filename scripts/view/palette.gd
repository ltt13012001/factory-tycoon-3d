## Shared flat-colour materials and mesh helpers for the placeholder art.
class_name Palette
extends RefCounted

const GRASS := Color("679a4b")
const ROAD := Color("474b51")
const CONCRETE := Color("8f969e")
const HALL_FLOOR := Color("aab0ae")
const WAREHOUSE_RAW := Color("a0b3c6")
const WAREHOUSE_FINISHED := Color("a6c09e")
const DOCK := Color("c4b48a")
const OFFICE := Color("b58c63")
const WALL := Color("d9dad5")
const WALL_TRIM := Color("6f7780")
const MACHINE_BODY := Color("3d7cc9")
const MACHINE_DARK := Color("2b3440")
const PELLET_BAG := Color("efe6c8")
const BOX := Color("4fb3e8")
const PALLET := Color("a87a4f")
const SCRAP := Color("d9534f")
const OPERATOR := Color("f0a030")
const WAREHOUSE := Color("4caf6a")
const OWNER := Color("8e5bd6")
const TECHNICIAN := Color("2f80ed")
const MANAGER := Color("eceff1")
const SKIN := Color("f1c9a5")
const HELMET := Color("ffd23f")
const TRUCK_SUPPLIER := Color("e8833a")
const TRUCK_CUSTOMER := Color("3fa7a0")
const STATUS_RUN := Color("34c759")
const STATUS_WARN := Color("ffcc00")
const STATUS_STOP := Color("ff3b30")
const SELECT := Color("ffffff")

static var _cache := {}
static var _surfaces := {}
static var _grain: ImageTexture


## True on phones, tablets and in the browser: fewer decorative extras.
static func low_end() -> bool:
	return OS.has_feature("web") or OS.has_feature("mobile")


## Shared vertex-coloured materials for MeshBatch geometry:
## matte, paint (machines, cars), steel, rubber, ground (grass, soil),
## paving (asphalt, concrete), floor (polished hall floors), glass, water,
## mesh (see-through fence netting) and screen (self-lit displays).
static func surface(kind: String) -> Material:
	if _surfaces.has(kind):
		return _surfaces[kind]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.85
	match kind:
		"paint":
			m.roughness = 0.38
			m.metallic = 0.15
			m.metallic_specular = 0.6
		"steel":
			m.roughness = 0.32
			m.metallic = 0.75
		"rubber":
			m.roughness = 0.95
			m.metallic_specular = 0.2
		"ground":
			m.roughness = 0.97
			m.metallic_specular = 0.25
			_add_grain(m, 0.045)
		"paving":
			m.roughness = 0.9
			m.metallic_specular = 0.35
			_add_grain(m, 0.22)
		"floor":
			m.roughness = 0.45
			m.metallic_specular = 0.5
			_add_grain(m, 0.12)
		"glass":
			m.vertex_color_use_as_albedo = false
			m.albedo_color = Color(0.62, 0.78, 0.9, 0.42)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.05
			m.metallic = 0.3
		"mesh":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.roughness = 0.5
			m.metallic = 0.5
		"solar":
			m.roughness = 0.18
			m.metallic = 0.6
			m.metallic_specular = 0.9
		"screen":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		"water":
			m.roughness = 0.06
			m.metallic = 0.35
			m.metallic_specular = 0.8
			_add_grain(m, 0.08)
	_surfaces[kind] = m
	return m


## Soft world-space noise multiplied into the vertex colour, so large flat
## areas (grass, asphalt, concrete) show natural variation instead of one
## flat colour. Sampled triplanar so no UVs are needed.
static func _add_grain(m: StandardMaterial3D, scale: float) -> void:
	m.albedo_texture = grain_texture()
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3(scale, scale, scale)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


static func grain_texture() -> ImageTexture:
	if _grain:
		return _grain
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = 7
	noise.frequency = 0.012
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 5
	noise.fractal_gain = 0.55
	var size := 256
	var src := noise.get_seamless_image(size, size)
	src.convert(Image.FORMAT_L8)
	var data := src.get_data()
	# Map the noise to sRGB 226..255 (about 0.78..1.0 linear) so it only tints.
	var out := PackedByteArray()
	out.resize(size * size * 3)
	for i in size * size:
		var v := 226 + data[i] * 29 / 255
		out[i * 3] = v
		out[i * 3 + 1] = v
		out[i * 3 + 2] = v
	var img := Image.create_from_data(size, size, false, Image.FORMAT_RGB8, out)
	img.generate_mipmaps()
	_grain = ImageTexture.create_from_image(img)
	return _grain


static func mat(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var key := "%s_%s" % [color.to_html(), emission]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	_cache[key] = m
	return m


## A wooden pallet (three runners and five deck boards) added to a batch.
static func pallet(b: MeshBatch, pos: Vector3, size := Vector2(1.0, 1.0), color := PALLET) -> void:
	for k in 3:
		b.box(Vector3(size.x, 0.08, 0.12), pos + Vector3(0, 0.04, (k - 1) * (size.y / 2.0 - 0.06)), color.darkened(0.12))
	for k in 5:
		b.box(Vector3(size.x * 0.16, 0.035, size.y), pos + Vector3((k - 2) * size.x * 0.21, 0.1, 0), color)


static func box(parent: Node, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat(color)
	parent.add_child(mi)
	return mi


static func cylinder(parent: Node, radius: float, height: float, pos: Vector3, color: Color, top_radius: float = -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = 16
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat(color)
	parent.add_child(mi)
	return mi


static func sphere(parent: Node, radius: float, pos: Vector3, color: Color, emission: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat(color, emission)
	parent.add_child(mi)
	return mi


## Adds a pickable collision box carrying selection metadata.
static func pick_body(parent: Node, size: Vector3, pos: Vector3, kind: String, id: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.set_meta("select_kind", kind)
	body.set_meta("select_id", id)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	parent.add_child(body)
	return body


static func label3d(parent: Node, text: String, pos: Vector3, size: int = 48, color: Color = Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = roundi(size * 1.5)
	l.pixel_size = 0.016
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = color
	l.outline_size = 20
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.font = UiTheme.font()
	parent.add_child(l)
	return l
