class_name BoundaryPaint
extends RefCounted
## The one place the boundary's look is decided, shared by every surface that is
## part of it — a system's faces and rim, a corridor's wall.
##
## Split out because the alternative is each node growing its own copy of the same
## material setup and the same lerp, and then two of them disagreeing about what
## "approaching the edge" looks like. The boundary is one thing to the player and
## should be one thing in the code.

## Both sides, always. A ceiling is seen from below and a floor from above, a
## corridor wall from inside, and a player who has gone past one has to still see
## the thing they went past.
static func make_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


## Colour a set of surfaces for how close the player is to leaving.
##
## `rest` and `alarm` are passed in rather than read here, because the wall and the
## grid ruled on it no longer share them: the solid faces are tuned to nothing at rest
## — the deep field is what gives the volume a size now, and a translucent sheet in
## front of it was reported as an ugly blue barrier — while the grid stays faintly
## drawn so the edge is still findable before it is a warning.
static func tint(nodes: Array, warning: float, rest: float, alarm: float) -> void:
	var color := Tuning.color("exploration/bounds_face_color").lerp(
		Tuning.color("exploration/bounds_color"), warning)
	color.a = clampf(lerpf(rest, alarm, warning), 0.0, 1.0)
	for node: MeshInstance3D in nodes:
		if node != null and node.material_override != null:
			(node.material_override as StandardMaterial3D).albedo_color = color


## A line mesh from a list of polylines, for ruling a boundary surface.
##
## The translucent faces alone are one flat colour that fills the view, and a ship
## flying at one has nothing in the frame that moves — which is the "impossible to
## tell that I am moving" report. A ruled grid on the same surface fixes that without
## making the boundary opaque, which it must never be: the space past the edge stays
## visible through it.
static func make_grid(lines: Array[PackedVector3Array]) -> ArrayMesh:
	var verts := PackedVector3Array()
	for line: PackedVector3Array in lines:
		for i in line.size() - 1:
			verts.append(line[i])
			verts.append(line[i + 1])
	if verts.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return mesh


## Reference geometry, not scenery: nothing here is queryable and nothing eats a
## missile. It exists so motion is legible in space that is otherwise empty — which
## matters most in a corridor, where there is nothing else at all to move past.
static func make_markers(places: Array[Vector3]) -> MultiMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * Tuning.num("exploration/marker_size")
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = places.size()
	for i in places.size():
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, places[i]))
	return multi


static func make_marker_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Tuning.color("exploration/marker_color")
	return mat
