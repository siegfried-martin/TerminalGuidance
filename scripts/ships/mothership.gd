class_name Mothership
extends Node3D
## The player's ship. Two modes, and the player chooses which one is running.
##
## **Autopilot** is the POC's original single behaviour: fly a slow arc around the
## commanded target, holding standoff, nose along the direction of travel. ADR 0013
## bounds it hard — a heading hold plus station-keeping, which does not path, avoid,
## arrive, or make decisions. Do not grow it.
##
## **Manual flight** (ADR 0040) is the human lifting a scope deferral, not a design
## reversal: COMBAT_POC_IMPLEMENTATION.md always said manual flight exists and was
## merely absent from the alternation under test. The throttle is a held state that
## climbs to full and falls to zero — a ship, not a missile — while steering reuses
## the missile's own reticle instrument so the two vehicles differ in their numbers
## rather than in their model.
##
## The speed hierarchy in CLAUDE.md (lasers > missiles > ships) is enforced here by
## construction, not by a comment: the manual top speed is clamped against
## missile/base_speed, so no edit to the ship's own numbers can outrun a missile.

## True while the autopilot has the ship. Flip it with `set_autopilot`.
var autopilot: bool = true
## True while the ship is the thing the player is flying. False while they are
## riding a missile: the ship keeps its velocity and coasts, but stops reading
## input, so W and A do not fly two vehicles at once. The autopilot ignores this
## entirely — delegating is the whole point of it, and it keeps arcing while the
## player is away.
var piloted: bool = true
var target: Node3D

var _velocity: Vector3 = Vector3.ZERO
var _orbit_sign: float = 1.0
var _hull: MeshInstance3D
var _last_standoff: float = -1.0
## 0 to 1. Held, not impulsive: this is the difference the human asked for between
## the ship's W and the missile's.
var _throttle: float = 0.0
var _reticle := ReticleSteering.new()
## Seconds until the launch tube can put another missile out. The tube belongs to
## the ship, not to the arena that happens to be wiring it up.
var _missile_cooldown: float = 0.0
## Hit points, and whether they mean anything. `ship/invulnerable` is true for this
## build at the human's direction: the pacing test asks "does being pulled to the
## turret disrupt the rhythm?", and that is answerable without a consequence for
## failing. Adding damage now would mix a pacing signal with a difficulty one and
## neither could be read cleanly. Hits still REGISTER — they are counted and they
## flash — because otherwise a failed intercept is indistinguishable from one that
## never arrived, and there would be nothing to pace against.
var _hp: float = -1.0
var _hits_taken: int = 0
## Seconds left on the impact flash. Feedback without consequence.
var _hit_flash: float = 0.0


func _ready() -> void:
	_hull = MeshInstance3D.new()
	_hull.name = "Hull"
	# A capital-scale gunboat, not a fighter (ADR 0044). Authored at 1 unit = 1 m
	# and 48 m long, so `ship/hull_scale` sits at 1.0 and every distance in the
	# tuning file is in the same units as the mesh.
	_hull.mesh = load("res://assets/models/carrier.obj")
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/textures/hull_panels.png")
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_hull.material_override = mat
	add_child(_hull)

	autopilot = Tuning.flag("ship/autopilot_on_start")
	_reticle.reset(basis)
	_apply_tuning()
	Tuning.reloaded.connect(_on_tuning_reloaded)


func _on_tuning_reloaded() -> void:
	_apply_tuning()
	# Hot reload has to *show* the value that was typed. Left to the controller,
	# a standoff edit takes tens of seconds to converge and reads as "the reload
	# didn't work" — so a changed standoff repositions the ship immediately. Only
	# under autopilot: doing it to a ship the player is flying is a teleport.
	if not autopilot:
		return
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
	if delta <= 0.0:
		return
	# The tube reloads regardless of who is flying, or whether anyone is: the
	# cooldown is the rhythm of the whole loop and it must not depend on which
	# station the player happens to be standing at.
	_missile_cooldown = maxf(_missile_cooldown - delta, 0.0)
	_hit_flash = maxf(_hit_flash - delta, 0.0)
	if autopilot:
		_fly_autopilot(delta)
	elif piloted:
		_fly_manual(delta)
	else:
		# Coasting: no input, no steering, no drag. Newtonian only in the sense that
		# nothing is acting on it — there is no flight model here, and there is not
		# meant to be one (ADR 0003).
		position += _velocity * delta


# --- autopilot ---------------------------------------------------------------

func _fly_autopilot(delta: float) -> void:
	if target == null:
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

	# Clamped to the ship's own top speed. The autopilot may not fly the ship in a
	# way the player could not: without this, `range_hold_max_speed` of 45 against a
	# manual ceiling of 34 means handing control back produces a lurch the player
	# has no way to produce themselves (ADR 0043).
	_velocity = (tangent * Tuning.num("ship/arc_speed") + radial * radial_speed) \
		.limit_length(manual_max_speed())
	position += _velocity * delta

	# The nose follows the direction of travel, not the target. Firing along the
	# ship's heading then launches the missile across the target rather than at
	# it, so every shot needs a real turn (ADR 0034).
	#
	# Turned at a bounded rate rather than snapped with `look_at`. A snap is
	# invisible while the autopilot has been flying all along, but the frame the
	# player hands the ship back is a frame where the nose is wherever *they* left
	# it, and an instant re-point reads as the ship being yanked out of their hands.
	if _velocity.length_squared() > 0.0001:
		var turn := deg_to_rad(
			Tuning.num("ship/autopilot_turn_rate_deg_per_sec")) * delta
		basis = FlightGeometry.basis_from_forward(
			FlightGeometry.turn_towards(-basis.z, _velocity.normalized(), turn))


# --- manual flight -----------------------------------------------------------

## The top speed the ship may reach, whatever the ship's own numbers say.
##
## This is the speed hierarchy made structural (CLAUDE.md): a ship that can match
## a missile makes the missile pointless, and the failure would show up as "the
## POC stopped being fun" rather than as a bug. Clamping here means a tuning
## session cannot produce that state by accident, and the fraction is itself
## tunable so the margin is a decision rather than a magic number.
func manual_max_speed() -> float:
	var ceiling := Tuning.num("missile/base_speed") \
		* clampf(Tuning.num("ship/manual_speed_ceiling_fraction"), 0.0, 0.95)
	return minf(Tuning.num("ship/manual_max_speed"), ceiling)


func _fly_manual(delta: float) -> void:
	# Throttle is a held state that climbs and falls, not a burst. The seconds are
	# the whole travel of the lever, so "3 s to full" means what it says.
	var accel_seconds := maxf(Tuning.num("ship/manual_accel_seconds"), 0.01)
	var brake_seconds := maxf(Tuning.num("ship/manual_brake_seconds"), 0.01)
	if Input.is_action_pressed("throttle_up"):
		_throttle = minf(_throttle + delta / accel_seconds, 1.0)
	if Input.is_action_pressed("throttle_down"):
		_throttle = maxf(_throttle - delta / brake_seconds, 0.0)

	var stick := ReticleSteering.apply_deadzone(Vector2(
		Input.get_axis("aim_left", "aim_right"),
		Input.get_axis("aim_up", "aim_down"),
	), Tuning.num("controls/deadzone"))

	basis = _reticle.update(basis, stick, delta,
		Tuning.num("controls/stick_reticle_speed_deg_per_sec"),
		Tuning.num("controls/mouse_sensitivity"),
		Tuning.num("ship/manual_turn_rate_deg_per_sec"),
		Tuning.num("ship/manual_reticle_max_angle_deg"))

	# Lateral thrusters are held here, unlike the missile's one-press dodge. ADR
	# 0039 rejected a held slide for the *missile*, where it flattened every
	# approach into a lane change; a ship is not flying a terminal approach and
	# has no such geometry to flatten.
	var strafe := Input.get_axis("strafe_left", "strafe_right") \
		* Tuning.num("ship/manual_strafe_speed")

	# The clamp is on the WHOLE velocity, not on the throttle alone. Thrusting
	# sideways at full throttle otherwise sums to more than the top speed — 34 m/s
	# forward plus 12 m/s across is 36 — and the speed hierarchy would be broken by
	# holding two keys rather than by editing a number.
	_velocity = (-basis.z * (_throttle * manual_max_speed()) + basis.x * strafe) \
		.limit_length(manual_max_speed())
	position += _velocity * delta


# --- taking hits -------------------------------------------------------------

## Register an incoming missile's warhead. Returns true if it actually cost HP.
##
## Turning damage on later is a single flip of `ship/invulnerable`, not a build:
## the counting, the flash and the readouts are all here already and are exercised
## by the pacing test itself.
func take_hit(damage: float) -> bool:
	_hits_taken += 1
	_hit_flash = Tuning.num("hud/hit_flash_seconds")
	if Tuning.flag("ship/invulnerable"):
		return false
	if _hp < 0.0:
		_hp = Tuning.num("ship/hp")
	_hp = maxf(_hp - damage, 0.0)
	return true


func hits_taken() -> int:
	return _hits_taken


## Hit points remaining. Full while invulnerable, because nothing has been spent.
func hp() -> float:
	if _hp < 0.0:
		return Tuning.num("ship/hp")
	return _hp


func hp_fraction() -> float:
	var pool := maxf(Tuning.num("ship/hp"), 0.001)
	return clampf(hp() / pool, 0.0, 1.0)


func is_invulnerable() -> bool:
	return Tuning.flag("ship/invulnerable")


## 0 to 1, fading. What the overlay tints the screen edge with on an impact.
func hit_flash() -> float:
	var total := maxf(Tuning.num("hud/hit_flash_seconds"), 0.001)
	return clampf(_hit_flash / total, 0.0, 1.0)


## The sphere an incoming missile is tested against.
##
## Derived from the hull mesh's own bounds rather than tuned, for the reason
## `TargetShip._recompute_bound` gives: a hand-set number a few metres short makes
## part of the ship silently unhittable and there is no error anywhere to find.
##
## **This is the one hit shape in the game that is still a sphere around a mesh**,
## which is exactly the shape ADR 0043 was written about. It is acceptable only
## because the player is invulnerable in this build and the error is generous in
## the direction of *being* hit. When ship damage arrives (step 9) this has to
## become the hull's own volumes, the way the target's did.
func hit_radius() -> float:
	var scale := maxf(Tuning.num("ship/hit_radius_scale"), 0.01)
	if _hull == null or _hull.mesh == null:
		return Tuning.num("ship/hull_scale") * scale
	var extents: Vector3 = _hull.mesh.get_aabb().size * 0.5
	return extents.length() * Tuning.num("ship/hull_scale") * scale


# --- the launch tube ---------------------------------------------------------

## Can another missile be launched?
##
## This is POC step 6's other half and the reason success criterion 2 is
## answerable at all: "after 30 minutes the developer is still choosing to fire,
## and never feels stuck waiting". Without a cooldown there is no between-missiles
## to have an opinion about, and the turret has nothing to be an answer to.
func missile_ready() -> bool:
	return _missile_cooldown <= 0.0


func missile_cooldown_remaining() -> float:
	return _missile_cooldown


## 0 to 1, how far through the reload the tube is. What the overlay draws.
func missile_charge() -> float:
	var total := Tuning.num("ship/missile_cooldown_seconds")
	if total <= 0.0:
		return 1.0
	return clampf(1.0 - _missile_cooldown / total, 0.0, 1.0)


## Start the clock. Called at LAUNCH, not at detonation, and that is a design
## choice rather than an implementation convenience: it means a second spent in the
## missile is a second off the gun, which is the trade `PROJECT_OVERVIEW.md` names
## as the loop's opportunity cost. Ending a ride early buys turret time; riding the
## fuse out spends it. Starting the clock at detonation would invert that and make
## a long ride free.
func note_missile_launched() -> void:
	_missile_cooldown = maxf(Tuning.num("ship/missile_cooldown_seconds"), 0.0)


## Hand the ship between the autopilot and the player. Returns the mode now in
## force, so a caller can report it without re-reading.
func set_autopilot(on: bool) -> bool:
	if on == autopilot:
		return autopilot
	autopilot = on
	if autopilot:
		# Adopt the current tuned standoff without acting on it. `_last_standoff` has
		# been frozen since the player took over, so a standoff edit made during
		# manual flight would otherwise fire `snap_to_standoff` — a teleport — at the
		# next unrelated hot reload.
		_last_standoff = Tuning.num("ship/standoff_distance")
	else:
		# Take over from where the autopilot left off rather than from a stop: the
		# reticle starts on the nose, and the throttle starts at whatever speed the
		# ship already had, so the handover is not a lurch.
		_reticle.reset(basis)
		var ceiling := manual_max_speed()
		_throttle = 0.0 if ceiling <= 0.0 else clampf(_velocity.length() / ceiling, 0.0, 1.0)
	return autopilot


## Mouse motion arrives as events, not as a polled axis; the view controller feeds
## it here so the ship stays the only thing that decides how input becomes turn.
func add_mouse_steer(relative: Vector2) -> void:
	if not autopilot:
		_reticle.add_mouse(relative)


# --- shared ------------------------------------------------------------------

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
	_reticle.reset(basis)


## Current distance to the commanded target, for the HUD and for tests.
func range_to_target() -> float:
	return 0.0 if target == null else position.distance_to(target.position)


## Where a missile leaves the ship, in the parent's frame.
func muzzle_position() -> Vector3:
	return position + (-basis.z) * Tuning.num("ship/muzzle_offset")


func velocity() -> Vector3:
	return _velocity


func speed() -> float:
	return _velocity.length()


## 0 to 1. Meaningless under autopilot, which sets its own speed.
func throttle() -> float:
	return _throttle


func mode_name() -> String:
	return "AUTOPILOT" if autopilot else "MANUAL"


## Where the ship's reticle points, in world space — the flight overlay draws it
## while the player is flying. Parent-relative internally, converted here, which is
## the floating-origin rule (ADR 0020).
func aim_direction() -> Vector3:
	var parent := get_parent_node_3d()
	var local_aim := -_reticle.aim_basis.z
	if parent == null:
		return local_aim.normalized()
	return (parent.global_transform.basis * local_aim).normalized()


## Angle in degrees between the nose and the reticle — the lag the player feels.
func aim_offset_degrees() -> float:
	return _reticle.offset_degrees(basis)


## Flip the arc direction. Present so a tuning session can see both sides of the
## target without a manual-flight system; not an AI behaviour.
func reverse_arc() -> void:
	_orbit_sign = -_orbit_sign
