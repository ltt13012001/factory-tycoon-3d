## Shared flat-colour materials and mesh helpers for the placeholder art.
class_name Palette
extends RefCounted

const GRASS := Color("5d8f48")
const ROAD := Color("3f444b")
const CONCRETE := Color("8f969e")
const HALL_FLOOR := Color("b3aea4")
const WAREHOUSE_RAW := Color("8fa8c8")
const WAREHOUSE_FINISHED := Color("94bd8c")
const DOCK := Color("d1a93c")
const OFFICE := Color("c9a983")
const WALL := Color("e4ddd0")
const WALL_TRIM := Color("8a8f98")
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
const SKIN := Color("f1c9a5")
const HELMET := Color("ffd23f")
const TRUCK_SUPPLIER := Color("e8833a")
const TRUCK_CUSTOMER := Color("3fa7a0")
const STATUS_RUN := Color("34c759")
const STATUS_WARN := Color("ffcc00")
const STATUS_STOP := Color("ff3b30")
const SELECT := Color("ffffff")

static var _cache := {}


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
