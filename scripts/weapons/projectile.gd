class_name Projectile
extends Node3D
## A turret round that travels: the autocannon's shot, and later the unguided
## missile. Nobody rides it and nobody steers it — it goes where it was pointed,
## at a constant speed, until it reaches something or runs out of range.
##
## One class for both because the difference between them is a tuning prefix and a
## blast radius, not a behaviour. `launch()` takes the prefix and every number is
## read from it, the same way `ChaseCamera` serves three views.
##
## Hit testing is a swept segment against the metre it crossed this frame, resolved
## by `Shot` so that a rock between the gun and the target stops it (ADR 0032,
## ADR 0043). At 320 m/s a round covers over 5 m per frame, so a per-frame distance
## check would tunnel through the target most of the time — the segment is not an
## optimisation, it is the only version that works.
##
## Parent-relative throughout (ADR 0020).

## `kind` is a `Shot.Kind`. Emitted whatever was reached, including a clean expiry
## at maximum range, where `kind` is NOTHING.
signal spent(projectile: Projectile, kind: int, point: Vector3)

var _prefix: String = "turret/autocannon"
var _speed: float = 0.0
var _damage: float = 0.0
var _range_left: float = 0.0
var _direction: Vector3 = Vector3.FORWARD
var _previous_position: Vector3
var _finished: bool = false
var _target: TargetShip
var _rocks: ReferenceField
var _body: MeshInstance3D


## `prefix` names the tuning group the round reads: "turret/autocannon" reads
## `turret/autocannon_speed`, `_damage`, `_range` and the body's look.
func launch(from: Vector3, direction: Vector3, prefix: String,
		target: TargetShip, rocks: ReferenceField) -> void:
	_prefix = prefix
	_target = target
	_rocks = rocks
	_direction = direction.normalized()
	if _direction.length_squared() < 0.5:
		_direction = Vector3.FORWARD
	_speed = resolved_speed(prefix)
	_damage = Tuning.num(prefix + "_damage")
	_range_left = Tuning.num(prefix + "_range")
	position = from
	_previous_position = from
	basis = FlightGeometry.basis_from_forward(_direction)


## The speed a round actually flies at, whatever its own tuning says.
##
## The speed hierarchy in CLAUDE.md is *structural*: lasers > missiles > ships. A
## turret round is not a laser, but it must still arrive faster than the thing the
## player rides — a missile that outruns the guns covering it inverts the shape of
## the whole engagement, and the failure would present as "the POC stopped being
## fun" rather than as a bug. So this is a floor, not a ceiling, and it is measured
## against the missile's *boosted* top speed rather than its cruise: a boosting
## missile is still a missile.
##
## `Mothership.manual_max_speed()` is the same guarantee from the other side.
static func resolved_speed(prefix: String) -> float:
	var missile_top := Tuning.num("missile/base_speed") \
		* maxf(Tuning.num("missile/boost_multiplier"), 1.0)
	var floor_speed := missile_top \
		* maxf(Tuning.num("turret/projectile_speed_floor_fraction"), 1.0)
	return maxf(Tuning.num(prefix + "_speed"), floor_speed)


func _ready() -> void:
	_build_body()


## Gray-box tracer: a thin bar drawn along the flight path so the round is legible
## at speed. Placeholder art, generated rather than authored (ADR 0030).
func _build_body() -> void:
	var mesh := BoxMesh.new()
	var width := Tuning.num(_prefix + "_round_width")
	mesh.size = Vector3(width, width, Tuning.num(_prefix + "_round_length"))
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Tuning.color(_prefix + "_round_color")
	_body = MeshInstance3D.new()
	_body.name = "Round"
	_body.mesh = mesh
	_body.material_override = material
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_body)


func _process(delta: float) -> void:
	if _finished or delta <= 0.0:
		return
	var step := _speed * delta
	if step >= _range_left:
		# Walk out the last of the range, test it, then expire wherever that left it.
		step = _range_left
	_previous_position = position
	position += _direction * step
	_range_left -= step

	var result := Shot.resolve(_previous_position, position, _target, _rocks)
	if Shot.stops_a_shot(result):
		_land(result)
		return
	if _range_left <= 0.0:
		_expire()


func _land(result: Dictionary) -> void:
	var component := int(result["component"])
	if component >= 0 and _target != null and is_instance_valid(_target):
		_target.damage_component(component, _damage)
	_finish(int(result["kind"]), result["point"])


func _expire() -> void:
	_finish(Shot.Kind.NOTHING, position)


func _finish(kind: int, point: Vector3) -> void:
	if _finished:
		return
	_finished = true
	position = point
	spent.emit(self, kind, point)
	queue_free()


func damage() -> float:
	return _damage


func speed() -> float:
	return _speed


func range_remaining() -> float:
	return _range_left
