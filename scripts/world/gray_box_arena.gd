class_name GrayBoxArena
extends Node3D
## A lattice of small marker cubes, so motion and speed are legible in empty space.
##
## Built entirely in code from tuning values, and rebuilt on hot reload. One
## MultiMesh, one draw call — the marker count is expected to grow a lot once
## the arena is sized against a real engagement envelope.
##
## Floating origin: markers are placed relative to this node, never in absolute
## world space, so recentring the world is a move of this node and nothing else.

var _multi: MultiMeshInstance3D


func _ready() -> void:
	_multi = MultiMeshInstance3D.new()
	_multi.name = "MarkerLattice"
	# Markers are reference geometry, not scenery: they must not eat missiles
	# or be picked up by a raycast.
	_multi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_multi)
	rebuild()
	Tuning.reloaded.connect(rebuild)


func rebuild() -> void:
	var per_axis := Tuning.integer("arena/marker_count_per_axis")
	var spacing := Tuning.num("arena/marker_spacing")
	var size := Tuning.num("arena/marker_size")
	if per_axis <= 0 or spacing <= 0.0:
		_multi.multimesh = null
		return

	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * size

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Tuning.color("arena/marker_color")
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 1.4
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cube.material = mat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cube
	mm.instance_count = per_axis * per_axis * per_axis

	var offset := (per_axis - 1) * 0.5
	var i := 0
	for x in per_axis:
		for y in per_axis:
			for z in per_axis:
				var pos := Vector3(x - offset, y - offset, z - offset) * spacing
				mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos))
				i += 1
	_multi.multimesh = mm


## Half-extent of the lattice, for camera framing and headless assertions.
func extent() -> float:
	var per_axis := Tuning.integer("arena/marker_count_per_axis")
	return max(0, per_axis - 1) * 0.5 * Tuning.num("arena/marker_spacing")


func marker_count() -> int:
	return 0 if _multi.multimesh == null else _multi.multimesh.instance_count
