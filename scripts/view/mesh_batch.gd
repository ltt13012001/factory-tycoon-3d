## Collects many primitive shapes and merges them into one mesh with one
## surface per material, coloured per vertex. A detailed static scene then
## costs a handful of draw calls instead of thousands, which keeps the web
## and tablet builds smooth.
##   var b := MeshBatch.new()
##   b.box(Vector3(1, 2, 1), Vector3(0, 1, 0), Color.RED)
##   b.build(self)
class_name MeshBatch
extends RefCounted

## Shape key -> [vertices, normals], already expanded from the index buffer.
static var _shapes := {}

## Optional transform applied to every shape added afterwards.
var origin := Transform3D.IDENTITY

## Material -> [Array of PackedVector3Array, normals likewise, Array of
## PackedColorArray]. Kept as chunks and joined once in build(), because
## appending to a packed array stored in a Dictionary copies it every time.
var _parts := {}


func box(size: Vector3, pos: Vector3, color: Color, mat: Material = null, rot := Vector3.ZERO) -> void:
	var key := "b%s" % size
	if not _shapes.has(key):
		var m := BoxMesh.new()
		m.size = size
		_shapes[key] = _expand(m)
	_add(_shapes[key], Transform3D(Basis.from_euler(rot), pos), color, mat)


## Cylinder or cone along Y (top_radius < 0 means same as radius).
func cylinder(radius: float, height: float, pos: Vector3, color: Color, mat: Material = null, top_radius := -1.0, rot := Vector3.ZERO, segments := 12, scale := Vector3.ONE) -> void:
	var top := radius if top_radius < 0.0 else top_radius
	var key := "c%s_%s_%s_%d" % [radius, top, height, segments]
	if not _shapes.has(key):
		var m := CylinderMesh.new()
		m.bottom_radius = radius
		m.top_radius = top
		m.height = height
		m.radial_segments = segments
		m.rings = 1
		m.cap_top = top > 0.0
		_shapes[key] = _expand(m)
	_add(_shapes[key], Transform3D(Basis.from_euler(rot) * Basis.from_scale(scale), pos), color, mat)


## Sphere, optionally squashed or stretched per axis.
func sphere(radius: float, pos: Vector3, color: Color, mat: Material = null, scale := Vector3.ONE, segments := 10, rings := 6) -> void:
	var key := "s%s_%d_%d" % [radius, segments, rings]
	if not _shapes.has(key):
		var m := SphereMesh.new()
		m.radius = radius
		m.height = radius * 2.0
		m.radial_segments = segments
		m.rings = rings
		_shapes[key] = _expand(m)
	_add(_shapes[key], Transform3D(Basis.from_scale(scale), pos), color, mat)


## Triangular prism (pitched roofs); left_to_right 0.5 puts the ridge centred.
func prism(size: Vector3, pos: Vector3, color: Color, mat: Material = null, left_to_right := 0.5, rot := Vector3.ZERO) -> void:
	var key := "p%s_%s" % [size, left_to_right]
	if not _shapes.has(key):
		var m := PrismMesh.new()
		m.size = size
		m.left_to_right = left_to_right
		_shapes[key] = _expand(m)
	_add(_shapes[key], Transform3D(Basis.from_euler(rot), pos), color, mat)


## A straight bar between two points (pipes, beams, rails, cables).
func bar(a: Vector3, b: Vector3, thickness: float, color: Color, mat: Material = null, rounded := false) -> void:
	var d := b - a
	var length := d.length()
	if length < 0.001:
		return
	var up := d / length
	var side := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := side.cross(up).normalized()
	var z := x.cross(up).normalized()
	var basis := Basis(x, up, z)
	var shape: Array
	if rounded:
		var key := "c%s_%s_%s_%d" % [thickness / 2.0, thickness / 2.0, length, 8]
		if not _shapes.has(key):
			var m := CylinderMesh.new()
			m.bottom_radius = thickness / 2.0
			m.top_radius = thickness / 2.0
			m.height = length
			m.radial_segments = 8
			m.rings = 1
			_shapes[key] = _expand(m)
		shape = _shapes[key]
	else:
		var key := "b%s" % Vector3(thickness, length, thickness)
		if not _shapes.has(key):
			var m := BoxMesh.new()
			m.size = Vector3(thickness, length, thickness)
			_shapes[key] = _expand(m)
		shape = _shapes[key]
	_add(shape, Transform3D(basis, (a + b) / 2.0), color, mat)


func is_empty() -> bool:
	return _parts.is_empty()


## Builds the merged mesh as a child of parent and clears the batch.
func build(parent: Node, cast_shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = build_mesh()
	if not cast_shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Returns the merged mesh (to share between several instances) and clears
## the batch.
func build_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for m in _parts:
		var verts := PackedVector3Array()
		var normals := PackedVector3Array()
		var colors := PackedColorArray()
		for chunk in _parts[m][0]:
			verts.append_array(chunk)
		for chunk in _parts[m][1]:
			normals.append_array(chunk)
		for chunk in _parts[m][2]:
			colors.append_array(chunk)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, m)
	_parts.clear()
	return mesh


func _add(shape: Array, xform: Transform3D, color: Color, mat: Material) -> void:
	var m: Material = mat if mat != null else Palette.surface("matte")
	if not _parts.has(m):
		_parts[m] = [[], [], []]
	var t := origin * xform
	var src_v: PackedVector3Array = shape[0]
	var src_n: PackedVector3Array = shape[1]
	var vs: PackedVector3Array = t * src_v
	var ns: PackedVector3Array = Transform3D(t.basis.inverse().transposed(), Vector3.ZERO) * src_n
	var cs := PackedColorArray()
	cs.resize(vs.size())
	cs.fill(color)
	var part: Array = _parts[m]
	part[0].append(vs)
	part[1].append(ns)
	part[2].append(cs)


static func _expand(mesh: PrimitiveMesh) -> Array:
	var arrays := mesh.get_mesh_arrays()
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	if idx.is_empty():
		return [v, n]
	out_v.resize(idx.size())
	out_n.resize(idx.size())
	for i in idx.size():
		out_v[i] = v[idx[i]]
		out_n[i] = n[idx[i]]
	return [out_v, out_n]
