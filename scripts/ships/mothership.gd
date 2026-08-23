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
var _last_standoff: float = -1.0


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
	Tuning.reloaded.connect(_on_tuning_reloaded)


func _on_tuning_reloaded() -> void:
	_apply_tuning()
	# Hot reload has to *show* the value that was typed. Left to the controller,
	# a standoff edit takes tens of seconds to converge and reads as "the reload
	# didn't work" — so a changed standoff repositions the ship immediately.
	var standoff := Tuning.num("ship/standoff_distance")
	if not is_equal_approx(standoff, _last_standoff):
		snap_to_standoff()


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
	_last_standoff = standoff

	# Tangent of the arc. Near-vertical geometry would make this degenerate, so
	# fall back to a different reference axis rather than producing a zero vector.
	var reference := Vector3.UP if absf(radial.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var tangent := radial.cross(reference).normalized() * _orbit_sign

	# Radial correction as an explicit speed, not as a share of one normalised
	# heading. The earlier version blended tangent and radial and normalised the
	# result, which meant the range authority collapsed towards zero exactly at
	# the setpoint — a target drifting at a few m/s outran it and the held range
	# wandered indefinitely.
	var range_error := range_now - standoff
	var hold_seconds := maxf(Tuning.num("ship/range_hold_seconds"), 0.01)
	var hold_max := Tuning.num("ship/range_hold_max_speed")
	var radial_speed := clampf(range_error / hold_seconds, -hold_max, hold_max)

	_velocity = tangent * Tuning.num("ship/arc_speed") + radial * radial_speed
	position += _velocity * delta

	# The nose follows the direction of travel, not the target. Firing along the
	# ship's heading then launches the missile across the target rather than at
	# it, so every shot needs a real turn (ADR 0034).
	if _velocity.length_squared() > 0.0001:
		look_at(global_position + _velocity, Vector3.UP)


## Place the ship at exactly the tuned standoff along its current bearing.
## Used for initial placement and after a standoff edit.
func snap_to_standoff() -> void:
	if target == null:
		return
	var to_target := target.position - position
	if to_target.length() < 0.001:
		return
	var standoff := Tuning.num("ship/standoff_distance")
	position = target.position - to_target.normalized() * standoff
	_last_standoff = standoff

	# Face along the arc, so the first frame is not a snap from an arbitrary basis.
	var radial := (target.position - position).normalized()
	var reference := Vector3.UP if absf(radial.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var tangent := radial.cross(reference).normalized() * _orbit_sign
	look_at(global_position + tangent, Vector3.UP)


## Current distance to the commanded target, for the HUD and for tests.
func range_to_target() -> float:
	return 0.0 if target == null else position.distance_to(target.position)


## Where a missile leaves the ship, in the parent's frame.
func muzzle_position() -> Vector3:
	return position + (-basis.z) * Tuning.num("ship/muzzle_offset")


func velocity() -> Vector3:
	return _velocity


## Flip the arc direction. Present so a tuning session can see both sides of the
## target without a manual-flight system; not an AI behaviour.
func reverse_arc() -> void:
	_orbit_sign = -_orbit_sign
