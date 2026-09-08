class_name MarkerLights
extends Node3D
## A few tiny lamps on the hull, so the ship can be seen in the dark without lighting
## anything around it: these are glowing dots, not light sources. Port red, starboard
## green, white at the tail and on the tower — the convention every pilot already
## reads, which is what makes them look designed in. Their numbers are under
## `;;; Lights` in tuning.cfg.

var _lamps: Array[MeshInstance3D] = []
var _materials: Array[StandardMaterial3D] = []


func _ready() -> void:
	name = "MarkerLights"
	for i in 4:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		_materials.append(mat)
		var lamp := MeshInstance3D.new()
		lamp.name = ["Port", "Starboard", "Tail", "Tower"][i]
		lamp.mesh = SphereMesh.new()
		lamp.material_override = mat
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(lamp)
		_lamps.append(lamp)
	retune()
	Tuning.reloaded.connect(retune)


func retune() -> void:
	var glow := Tuning.num("exploration/ship_marker_glow")
	var colors: Array[Color] = [
		Tuning.color("exploration/ship_marker_port_color"),
		Tuning.color("exploration/ship_marker_starboard_color"),
		Tuning.color("exploration/ship_marker_white_color"),
		Tuning.color("exploration/ship_marker_white_color"),
	]
	for i in 4:
		_materials[i].albedo_color = colors[i]
		_materials[i].emission = colors[i]
		_materials[i].emission_energy_multiplier = glow


## Sit on the hull's extremities: the wingtips, the tail and the top of the tower,
## read off the hull mesh's bounds at the hull's scale.
func fit(aabb: AABB, hull_scale: float) -> void:
	var size := Tuning.num("exploration/ship_marker_metres") * hull_scale
	var lo := aabb.position * hull_scale
	var hi := aabb.end * hull_scale
	var spots: Array[Vector3] = [
		Vector3(lo.x, 0.0, 0.0),
		Vector3(hi.x, 0.0, 0.0),
		Vector3(0.0, 0.0, hi.z),
		Vector3(0.0, hi.y, 0.0),
	]
	for i in 4:
		var mesh := _lamps[i].mesh as SphereMesh
		mesh.radius = size * 0.5
		mesh.height = size
		_lamps[i].position = spots[i]
