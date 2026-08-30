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
## `alpha_scale` is for surfaces seen face-on rather than edge-on: a flat slab
## stacks its own thickness and needs less alpha than a wall does to read at the
## same strength.
static func tint(nodes: Array, warning: float, alpha_scale: float) -> void:
	var color := Tuning.color("exploration/bounds_face_color").lerp(
		Tuning.color("exploration/bounds_color"), warning)
	color.a = clampf(lerpf(Tuning.num("exploration/bounds_face_alpha"),
		Tuning.num("exploration/bounds_alarm_alpha"), warning) * alpha_scale,
		0.0, 1.0)
	for node: MeshInstance3D in nodes:
		if node != null and node.material_override != null:
			(node.material_override as StandardMaterial3D).albedo_color = color


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
