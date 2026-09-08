class_name Headlight
extends Node3D
## The ship's headlight: a spot on the nose, with a pair of lamp fixtures so the
## light has a visible source and reads as part of the hull rather than as a trick of
## the renderer. Between systems the road is dark on purpose (STATUS.md, the star);
## this is the first of the ways a ship buys its own light. What it costs and what
## better ones exist is a design decision that is flagged, not built: today every
## hull has this one and it is free.
##
## `L` toggles it from the seat. Its numbers are under `;;; Lights` in tuning.cfg.

var on: bool = true

var _spot: SpotLight3D
var _lamps: Array[MeshInstance3D] = []
var _material: StandardMaterial3D


func _ready() -> void:
	name = "Headlight"
	_spot = SpotLight3D.new()
	_spot.name = "Beam"
	_spot.shadow_enabled = false
	add_child(_spot)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.emission_enabled = true
	for side in 2:
		var lamp := MeshInstance3D.new()
		lamp.name = "Lamp %d" % side
		lamp.mesh = BoxMesh.new()
		lamp.material_override = _material
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(lamp)
		_lamps.append(lamp)
	on = Tuning.flag("exploration/headlight_enabled")
	retune()
	Tuning.reloaded.connect(_on_tuning_reloaded)


func _on_tuning_reloaded() -> void:
	# A saved file wins over the key, so the F2 panel's switch does what it says.
	on = Tuning.flag("exploration/headlight_enabled")
	retune()


func toggle() -> void:
	on = not on
	retune()


## Re-read the tuning and apply the switch.
func retune() -> void:
	var color := Tuning.color("exploration/headlight_color")
	_spot.light_color = color
	_spot.light_energy = Tuning.num("exploration/headlight_energy")
	_spot.spot_range = Tuning.num("exploration/headlight_range")
	_spot.spot_angle = Tuning.num("exploration/headlight_angle_deg")
	_spot.spot_attenuation = Tuning.num("exploration/headlight_attenuation")
	# Aimed down a little: the nose is half a tube above the roadway, and a beam held
	# level grazes the floor and lights the ribs ahead more than the road.
	_spot.rotation = Vector3(deg_to_rad(Tuning.num("exploration/headlight_pitch_deg")), 0.0, 0.0)
	_spot.visible = on
	_material.albedo_color = color
	_material.emission = color
	_material.emission_energy_multiplier = Tuning.num("exploration/headlight_lamp_glow") \
		if on else 0.0


## Sit on the nose. `nose` is the hull's foremost point in the ship's frame and
## `hull_scale` what the hull mesh is scaled by, so the fixtures follow the hull.
func fit(nose: Vector3, hull_scale: float) -> void:
	position = nose
	var size := Tuning.num("exploration/headlight_fixture_metres") * hull_scale
	var spread := Tuning.num("exploration/headlight_spread_metres") * hull_scale
	for side in 2:
		var lamp := _lamps[side]
		(lamp.mesh as BoxMesh).size = Vector3(size, size * 0.5, size * 0.5)
		lamp.position = Vector3((-1.0 if side == 0 else 1.0) * spread * 0.5, 0.0, 0.0)
