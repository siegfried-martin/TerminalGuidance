class_name EnemyMissile
extends Node3D
## The interrupt (POC step 8): a guided missile the target ship sends at the player,
## on a long timer, with deliberately imperfect aim.
##
## This is the single most dangerous thing in the build for the target experience,
## and `CLAUDE.md` is explicit about why: *"Stress is a spike, never ambient."* Two
## rules from `PROJECT_OVERVIEW.md` Pillar 2 govern everything here:
##
## 1. **The warning is loud, telegraphed and unambiguous.** The launch is announced
##    `enemy/interrupt_warning_lead_seconds` before it happens, not as it happens.
##    An interrupt you can miss is not a spike, it is ambient dread — which is the
##    exact failure the target-experience guard exists to prevent.
## 2. **It must be possible to win both.** A player who is quick can detonate on
##    target *and* make the turret in time. The lead therefore has to exceed a
##    typical remaining ride, and the missile is shootable by every turret weapon.
##
## The aim error is sampled once at launch and never corrected, so the missile
## flies at a point *near* the ship rather than at it. That is what "random
## imperfect accuracy" means here: the miss is decided at launch and is the same
## miss all the way in, which is something the player can read off the missile's
## line rather than a die roll at the end.
##
## Guided, but it does not path, avoid, or make decisions in flight (ADR 0013's
## bound, applied to the other side): it turns towards one point at one rate.
##
## Swept-segment throughout (ADR 0032), parent-relative throughout (ADR 0020).

signal ended(missile: EnemyMissile, reason: int, point: Vector3)

## Appended to, never reordered.
enum EndReason { FUSE_EXPIRED, HIT_SHIP, SHOT_DOWN, FLARE_INTERCEPT }

const GROUP := "enemy_missile"

## Drawn and hit at the same radius, so a shot that looks like it should have
## clipped it did (ADR 0041, 0043, 0050).
var hit_radius: float = 0.0

var _target: Mothership
var _aim_point: Vector3 = Vector3.ZERO
var _aim_error: Vector3 = Vector3.ZERO
var _speed: float = 0.0
var _fuse_left: float = 0.0
var _health: float = 1.0
var _previous_position: Vector3
var _spent: bool = false
var _body: MeshInstance3D


func _ready() -> void:
	add_to_group(GROUP)


## `error_seed` is passed in rather than drawn here so the gate can ask for a
## missile that will certainly hit, or certainly miss, without reaching inside.
func launch(from: Vector3, ship: Mothership, error: Vector3) -> void:
	_target = ship
	_aim_error = error
	hit_radius = Tuning.num("enemy/missile_radius")
	_speed = resolved_speed()
	_fuse_left = Tuning.num("enemy/missile_fuse_seconds")
	_health = maxf(Tuning.num("enemy/missile_hit_points"), 0.001)
	position = from
	_previous_position = from
	_refresh_aim()
	basis = FlightGeometry.basis_from_forward(
		(_aim_point - position).normalized())
	_build_body()


## A random aim error inside a sphere of `enemy/missile_aim_error` metres. Drawn
## here so there is one definition of what "imperfect accuracy" means.
static func random_error() -> Vector3:
	var spread := Tuning.num("enemy/missile_aim_error")
	if spread <= 0.0:
		return Vector3.ZERO
	# Cubed root of a uniform draw gives a uniform density inside the sphere rather
	# than a pile-up at the centre, so "usually nearly on target" is a tuning
	# decision rather than an accident of the sampling.
	var direction := Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5)
	if direction.length_squared() < 0.000001:
		return Vector3.ZERO
	return direction.normalized() * spread * pow(randf(), 1.0 / 3.0)


## The speed hierarchy applies to both sides (CLAUDE.md). An enemy missile is a
## missile: it may not outrun the player's own at full boost, or the turret's
## rounds would be slower than the thing they are meant to intercept and the
## interrupt would be unanswerable by construction.
static func resolved_speed() -> float:
	var missile_top := Tuning.num("missile/base_speed") \
		* maxf(Tuning.num("missile/boost_multiplier"), 1.0)
	return minf(Tuning.num("enemy/missile_speed"), missile_top)


func _build_body() -> void:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.radius = hit_radius
	mesh.height = hit_radius * 2.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Tuning.color("enemy/missile_color")
	_body = MeshInstance3D.new()
	_body.name = "Body"
	_body.mesh = mesh
	_body.material_override = material
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_body)


func _process(delta: float) -> void:
	if _spent or delta <= 0.0:
		return

	_refresh_aim()
	var turn := deg_to_rad(Tuning.num("enemy/missile_turn_rate_deg_per_sec")) * delta
	var heading := FlightGeometry.turn_towards(
		-basis.z, (_aim_point - position).normalized(), turn)
	basis = FlightGeometry.basis_from_forward(heading)

	_previous_position = position
	position += heading * _speed * delta

	# Player flares first: a countermeasure that only worked when the missile was
	# not about to arrive would be no countermeasure at all.
	var flare := Flare.intercept(get_tree(), _previous_position, position, Flare.Side.ENEMY)
	if flare != null:
		flare.consume()
		_finish(EndReason.FLARE_INTERCEPT)
		return

	if _target != null and is_instance_valid(_target) \
			and FlightGeometry.segment_hits_sphere(
				_previous_position, position, _target.position, _target.hit_radius()):
		_target.take_hit(Tuning.num("enemy/missile_damage"))
		_finish(EndReason.HIT_SHIP)
		return

	_fuse_left -= delta
	if _fuse_left <= 0.0:
		_finish(EndReason.FUSE_EXPIRED)


## The point it is flying at: the ship's position plus the error sampled at launch.
## Re-read every frame because the ship moves — the missile is guided, and the
## error is a constant offset rather than a stale target position.
func _refresh_aim() -> void:
	if _target != null and is_instance_valid(_target):
		_aim_point = _target.position + _aim_error
	elif _aim_point.is_equal_approx(Vector3.ZERO):
		_aim_point = position - basis.z * 1000.0


## Spend `amount` of damage on it. Returns true if that destroyed it. Every turret
## weapon goes through here, in the same currency as everything else (ADR 0049).
func take_damage(amount: float) -> bool:
	if _spent or amount <= 0.0:
		return false
	_health -= amount
	if _health > 0.0:
		return false
	_finish(EndReason.SHOT_DOWN)
	return true


func _finish(reason: EndReason) -> void:
	if _spent:
		return
	_spent = true
	remove_from_group(GROUP)
	ended.emit(self, reason, position)
	queue_free()


func is_spent() -> bool:
	return _spent


func fuse_remaining() -> float:
	return maxf(_fuse_left, 0.0)


func health_fraction() -> float:
	var pool := maxf(Tuning.num("enemy/missile_hit_points"), 0.001)
	return clampf(_health / pool, 0.0, 1.0)


## How far it still has to come. The alert reads this, and so does the gate.
func distance_to_ship() -> float:
	if _target == null or not is_instance_valid(_target):
		return INF
	return position.distance_to(_target.position)


## Spend a blast's damage on every enemy missile within `radius` of `centre`.
## Returns how many it destroyed — the unguided missile's stated second job.
static func splash(tree: SceneTree, centre: Vector3, radius: float, peak: float,
		falloff_power: float) -> int:
	if tree == null or radius <= 0.0 or peak <= 0.0:
		return 0
	var killed := 0
	for node in tree.get_nodes_in_group(GROUP):
		var missile := node as EnemyMissile
		if missile == null or missile.is_spent():
			continue
		var distance := maxf(
			missile.position.distance_to(centre) - missile.hit_radius, 0.0)
		if missile.take_damage(Damage.splash(peak, distance, radius, falloff_power)):
			killed += 1
	return killed
