class_name Star
extends Node3D
## A system's star: below and to one side of its planet, three planet diameters
## across, and the one real source of light in the system. Background-layer only —
## nothing here collides and nothing queries it (CLAUDE.md's LOD/collision rule); it
## sits under the disc's floor where nothing can reach it.
##
## The offset is random per system and fixed by the deep field's seed, so each system
## has its own light and the same one every run.

## The system's centre and the planet this star lights, in the map's frame.
var base: Vector3 = Vector3.ZERO
var planet_position: Vector3 = Vector3.ZERO
## Which system, for the seeded offset.
var index: int = 0

var _body: MeshInstance3D
var _light: OmniLight3D


func _ready() -> void:
	_body = MeshInstance3D.new()
	_body.name = "Body"
	_body.mesh = SphereMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	_body.material_override = mat
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_body)
	_light = OmniLight3D.new()
	_light.name = "Light"
	_light.shadow_enabled = false
	add_child(_light)
	rebuild()


func rebuild() -> void:
	if _body == null:
		return
	var radius := Tuning.num("exploration/planet_radius") \
		* Tuning.num("exploration/star_radius_planet_multiple")
	var mesh := _body.mesh as SphereMesh
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 48
	mesh.rings = 24
	var color := Tuning.color("exploration/star_color")
	var mat := _body.material_override as StandardMaterial3D
	mat.albedo_color = color
	mat.emission = color
	mat.emission_energy_multiplier = Tuning.num("exploration/star_emission")
	_light.light_color = color
	_light.light_energy = Tuning.num("exploration/star_light_energy")
	_light.omni_range = Tuning.num("exploration/star_light_range")
	_light.omni_attenuation = Tuning.num("exploration/star_light_attenuation")
	# Under the floor by a gap, so its rim is never in playable space, and off to one
	# side by a seeded random bearing.
	var rng := RandomNumberGenerator.new()
	rng.seed = Tuning.integer("exploration/deep_seed") + 977 * (index + 1)
	var bearing := rng.randf_range(0.0, TAU)
	var offset := Tuning.num("exploration/star_offset_metres")
	position = Vector3(planet_position.x + cos(bearing) * offset,
		base.y - Tuning.num("exploration/system_floor_depth")
			- Tuning.num("exploration/star_gap_below_floor") - radius,
		planet_position.z + sin(bearing) * offset)


func radius() -> float:
	return (_body.mesh as SphereMesh).radius if _body != null else 0.0


## The top of the star, which must be below the disc's floor.
func top() -> float:
	return position.y + radius()
