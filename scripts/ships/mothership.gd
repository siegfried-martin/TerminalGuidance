class_name Mothership
extends Node3D
## The player's ship under the POC's single autopilot behaviour: fly a slow arc
## around the commanded target, holding standoff distance, nose on the target.
##
## ADR 0013 bounds this hard. Autopilot is a heading hold plus a station-keeping
## arc; it does not path, avoid, arrive, or make decisions. Do not grow it.
##
## Manual flight is *not* absent because the ship is autopilot-only — it is absent
## because it is not part of the combat alternation under test (ADR 0001, and the
## scope note in COMBAT_POC_IMPLEMENTATION.md). Do not encode "autopilot-only"
## anywhere.

var target: Node3D

var _velocity: Vector3 = Vector3.ZERO
var _orbit_sign: float = 1.0
var _hull: MeshInstance3D


func _ready() -> void:
	_hull = MeshInstance3D.new()
	_hull.name = "Hull"
	_hull.mesh = load("res://assets/models/probe.obj")
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/textures/hull_panels.png")
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_hull.material_override = mat
	add_child(_hull)

	_apply_tuning()
	Tuning.reloaded.connect(_apply_tuning)


func _apply_tuning() -> void:
	_hull.scale = Vector3.ONE * Tuning.num("ship/hull_scale")
	var mat := _hull.material_override as StandardMaterial3D
	mat.albedo_color = Tuning.color("ship/hull_tint")
	mat.metallic = Tuning.num("ship/metallic")
	mat.roughness = Tuning.num("ship/roughness")


func _process(delta: float) -> void:
	if target == null or delta <= 0.0:
		return

	# Parent-relative throughout (ADR 0020): both ships share a parent, so a world
	# recentre moves them together and none of this arithmetic notices.
	var to_target := target.position - position
	var range_now := to_target.length()
	if range_now < 0.001:
		return
	var radial := to_target / range_now

	var standoff := Tuning.num("ship/standoff_distance")
	# Tangent of the arc. Near-vertical geometry would make this degenerate, so
	# fall back to a different reference axis rather than producing a zero vector.
	var reference := Vector3.UP if absf(radial.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var tangent := radial.cross(reference).normalized() * _orbit_sign

	# Close or back off proportionally to the standoff error, capped so the
	# correction never overwhelms the arc and turns this into a pursuit.
	var range_error := clampf((range_now - standoff) / maxf(standoff, 1.0), -1.0, 1.0)
	var heading := (tangent + radial * range_error).normalized()

	var previous := position
	position += heading * Tuning.num("ship/arc_speed") * delta
	_velocity = (position - previous) / delta

	# Heading hold: nose on the target, every frame, computed fresh.
	look_at(target.global_position, Vector3.UP)


## Where a missile leaves the ship, in the parent's frame.
func muzzle_position() -> Vector3:
	return position + (-basis.z) * Tuning.num("ship/muzzle_offset")


func velocity() -> Vector3:
	return _velocity


## Flip the arc direction. Present so a tuning session can see both sides of the
## target without a manual-flight system; not an AI behaviour.
func reverse_arc() -> void:
	_orbit_sign = -_orbit_sign
