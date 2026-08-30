class_name Mothership
extends Node3D
## The player's ship. Two modes, and the player chooses which one is running.
##
## Which of the two is running is not a mode the player toggles: it follows from
## whether they are the **pilot** or the **gunner** (ADR 0056). A ship nobody is
## flying has to fly itself.
##
## **Autopilot** is the POC's original single behaviour: a slow arc around the
## commanded target at standoff, nose along the direction of travel, now held on a
## plane `ship/arc_depth` metres *below* it so the turret — which is mounted on the
## spine — has a clear line over its own hull (ADR 0056). ADR 0013 bounds it hard:
## a heading hold plus station-keeping, which does not path, avoid, arrive, or make
## decisions. Flying under the target is a fixed geometric station, not a choice it
## makes. Do not grow it.
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

## Which hull this is. Everything about how the ship flies resolves from here.
##
## Assign through `set_hull_class` rather than directly: the silhouette is a class
## property too, and a bare assignment leaves the hull at the previous class's size
## until something else happens to trigger a hot reload.
var hull_class: HullClass.Kind = HullClass.DEFAULT
## Scaled below 1 while the ship leans on a system boundary (ADR 0011, SystemDisc).
##
## The clamp is on the SPEED LIMIT, never on the velocity vector. That is what makes
## "magnitude only, never direction" structural: there is no code path anywhere that
## can turn the player's ship, because nothing on this side ever receives a heading.
## The stick does exactly what was asked and the ship simply strains.
##
## It also shows: the HUD's speed row reads "of N", and N comes down.
##
## Several things constrain it — the disc's faces, the approach envelope — so the
## scene composes them and assigns the tightest, rather than each writing this field
## and the last one to run winning. Zero is reachable, and means docked: the
## boundary never uses it, because ADR 0011's faces must never be a hard stop.
var speed_ceiling_scale: float = 1.0

## The road, sampled where the ship is, or null when the cruise drive is not
## running. Set by the map each frame; the ship never looks the road up.
##
## Cruise is a PLACE the ship is in rather than a mode it switches to (ADR 0057):
## the throttle is still the player's, the stick still steers, and the only
## differences are a much higher ceiling and a cone around the road's axis. Nothing
## here fades, loads, or plays.
var cruise: CruiseLane = null

## 0 to 1: how far the cruise drive has wound up. The ceiling is blended across it,
## so joining the road accelerates and leaving it decelerates instead of the speed
## snapping between hull and cruise in one frame.
##
## This is NOT entry ceremony and must not become it (ADR 0057). The player is
## already through the aperture, already steering, already holding their own
## throttle; what takes time is an engine winding up, which is the ship doing
## something rather than something being done to the ship.
var _cruise_spool: float = 0.0
## The road's top speed, remembered across the spool-down so leaving the road has
## something to decelerate FROM after `cruise` has already gone null.
var _cruise_ceiling: float = 0.0

var _velocity: Vector3 = Vector3.ZERO
var _orbit_sign: float = 1.0
var _hull: MeshInstance3D
var _last_standoff: float = -1.0
var _last_depth: float = -1.0
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

	# The view controller sets this from the crew roster on the first frame; this is
	# only so a Mothership built on its own (the headless gate does that) starts
	# somewhere defined rather than on whatever the member's default happened to be.
	autopilot = Tuning.text("ship/start_role").strip_edges().to_lower() == "gunner"
	adopt_tuned_hull_class()
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
	var depth := Tuning.num("ship/arc_depth")
	if not is_equal_approx(standoff, _last_standoff) or not is_equal_approx(depth, _last_depth):
		snap_to_standoff()


func _apply_tuning() -> void:
	_hull.scale = Vector3.ONE * hull_scale()
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
	_spool(delta)
	if autopilot:
		_fly_autopilot(delta)
	elif piloted and cruise != null:
		_fly_cruise(delta)
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
	var standoff := Tuning.num("ship/standoff_distance")
	_last_standoff = standoff
	_last_depth = Tuning.num("ship/arc_depth")
	var hold_seconds := maxf(Tuning.num("ship/range_hold_seconds"), 0.01)
	var hold_max := Tuning.num("ship/range_hold_max_speed")

	# The station is a horizontal circle, `arc_depth` below the target's plane.
	# Keeping the ship UNDER the enemy is what gives the turret its shot: the gun
	# sits on top of the spine, so from level or above it is looking across its own
	# hull (ADR 0056). Standoff still means slant range to the target — the depth
	# only decides where on that sphere the ship sits — so the missile-reach
	# arithmetic against `standoff_distance` is unchanged.
	var depth := clampf(Tuning.num("ship/arc_depth"), 0.0, standoff * 0.95)
	var arc_radius := sqrt(maxf(standoff * standoff - depth * depth, 1.0))

	var to_target := target.position - position
	var flat := Vector3(to_target.x, 0.0, to_target.z)
	var flat_range := flat.length()
	# Directly under the target there is no bearing to arc on. Pick one rather than
	# dividing by zero; a frame later there is a real one to use.
	var radial := Vector3.RIGHT if flat_range < 0.001 else flat / flat_range

	# The arc is horizontal by construction, which is the shared horizon of ADR 0045
	# arriving in the autopilot. It also removes the old degenerate case: there used
	# to be a fallback reference axis for near-vertical geometry, and there is no
	# such geometry any more.
	var tangent := radial.cross(Vector3.UP) * _orbit_sign

	# Range and altitude corrections as explicit speeds, not as shares of one
	# normalised heading. The earlier version blended tangent and radial and
	# normalised the result, which meant the range authority collapsed towards zero
	# exactly at the setpoint — a target drifting at a few m/s outran it and the
	# held range wandered indefinitely.
	var radial_speed := clampf((flat_range - arc_radius) / hold_seconds, -hold_max, hold_max)
	var altitude_error := (target.position.y - depth) - position.y
	var climb_speed := clampf(altitude_error / hold_seconds, -hold_max, hold_max)

	# Clamped to the ship's own top speed. The autopilot may not fly the ship in a
	# way the player could not: without this, `range_hold_max_speed` of 45 against a
	# manual ceiling of 34 means handing control back produces a lurch the player
	# has no way to produce themselves (ADR 0043).
	# A fraction of this hull's own top speed, never an absolute: at the corrected
	# taxi speed the old absolute 13.8 would put the autopilot at 89% of manual and
	# make flying yourself decoration (EXPLORATION_DESIGN.md invariant 3).
	var arc_speed := manual_max_speed() \
		* clampf(Tuning.num("ship/arc_speed_fraction"), 0.0, 0.95)
	_velocity = (tangent * arc_speed
		+ radial * radial_speed
		+ Vector3.UP * climb_speed).limit_length(manual_max_speed())
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
## This is the speed hierarchy made structural (CLAUDE.md), and it now resolves
## through the hull class: a taxi at 0.27 of missile speed and a fighter at 0.67
## cannot share one global fraction, so each class declares its own headroom and
## `HullClass` applies the clamp. What the invariant protects widens from "missiles
## outrun ships" to "a missile outruns its intended targets".
func manual_max_speed() -> float:
	# On the road the ceiling is the cruise drive's, not the hull's — that is the
	# whole of what the road buys, and it is why there is no personal cruise drive
	# for open space (ADR 0057). The lane's own penalty is already folded into
	# `top_speed`, so drifting wide shows up here and on the HUD's "of N".
	#
	# Blended across the spool rather than switched, in BOTH directions: joining the
	# road is an acceleration and leaving it is a deceleration, and the blend is on
	# the ceiling rather than on the velocity so the throttle keeps meaning what it
	# meant. A ship that arrives in a system still doing 140 has not left the road,
	# it has been teleported off it.
	var hull := HullClass.max_speed(hull_class)
	var road := cruise.top_speed() if cruise != null else _cruise_ceiling
	return lerpf(hull, maxf(road, hull), _cruise_spool) \
		* clampf(speed_ceiling_scale, 0.0, 1.0)


## Wind the drive up or down. Runs every frame whatever is flying, because the
## spool-down has to keep going after `cruise` is already null.
func _spool(delta: float) -> void:
	if cruise != null:
		_cruise_ceiling = cruise.top_speed()
		var up := maxf(Tuning.num("exploration/cruise_spool_seconds"), 0.001)
		_cruise_spool = minf(_cruise_spool + delta / up, 1.0)
		return
	if _cruise_spool <= 0.0:
		return
	var down := maxf(Tuning.num("exploration/cruise_spool_down_seconds"), 0.001)
	_cruise_spool = maxf(_cruise_spool - delta / down, 0.0)


## How far the cruise drive has wound up, 0 to 1. For the HUD, which has to show the
## wind-up as it happens or it reads as sluggishness rather than as an engine.
func cruise_spool() -> float:
	return _cruise_spool


## Is the cruise drive running right now?
func is_cruising() -> bool:
	return cruise != null


## Read the class back out of tuning. Called at build and on every hot reload, so
## editing `ship/hull_class` changes the ship in place, and so the debug roster
## (POC step 4) can put it back.
func adopt_tuned_hull_class() -> void:
	set_hull_class(HullClass.from_name(Tuning.text("ship/hull_class")))


## Change class, and rebuild everything that follows from it. Instant by design —
## the roster exists so the classes can be felt back to back, and a transition would
## put the thing being compared behind an animation.
func set_hull_class(kind: HullClass.Kind) -> void:
	hull_class = kind
	if _hull != null:
		_apply_tuning()


## Can this hull use a portal at all? The fighter cannot, and that is the single
## property `<class>_has_cruise_drive` rather than a rule about portals.
func has_cruise_drive() -> bool:
	return HullClass.has_cruise_drive(hull_class)


## How hard this hull turns. Read publicly because the roster's whole purpose is
## comparing classes, and a difference the player has to infer from feel alone is
## a difference they will mis-attribute.
func turn_rate_deg_per_sec() -> float:
	return HullClass.num(hull_class, "turn_rate_deg_per_sec",
		"ship/manual_turn_rate_deg_per_sec")


func strafe_speed() -> float:
	return HullClass.num(hull_class, "strafe_speed", "ship/manual_strafe_speed")


## Seconds of throttle travel, end to end. The pair is what "ponderous" actually
## means for a capital — its top speed is only half the story.
func accel_seconds() -> float:
	return HullClass.num(hull_class, "accel_seconds", "ship/manual_accel_seconds")


func brake_seconds() -> float:
	return HullClass.num(hull_class, "brake_seconds", "ship/manual_brake_seconds")


## The hull's size multiplier for this class. A roster whose three ships look
## identical fails at the one thing it is for: you must be able to see which one
## you are in without reading the HUD.
func hull_scale() -> float:
	return HullClass.num(hull_class, "hull_scale", "ship/hull_scale")


## Every number here resolves through the hull class (ADR 0059), with the
## `ship/manual_*` values as the shared fallback. A class that overrides nothing
## flies exactly as this ship always has — which is why the taxi, the class the
## combat arena uses, has no entries of its own and is untouched by the roster.
##
## Top speed alone does not make a class legible. A fighter that is a fast taxi
## teaches nothing about what a fighter *is*, so turn rate, throttle travel and
## thruster authority are all per class too. That is the difference between
## "the number is different" and "it flies differently".
func _fly_manual(delta: float) -> void:
	# Throttle is a held state that climbs and falls, not a burst. The seconds are
	# the whole travel of the lever, so "3 s to full" means what it says.
	var accel_seconds := maxf(
		HullClass.num(hull_class, "accel_seconds", "ship/manual_accel_seconds"), 0.01)
	var brake_seconds := maxf(
		HullClass.num(hull_class, "brake_seconds", "ship/manual_brake_seconds"), 0.01)
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
		turn_rate_deg_per_sec(),
		HullClass.num(hull_class, "reticle_max_angle_deg",
			"ship/manual_reticle_max_angle_deg"))

	# Lateral thrusters are held here, unlike the missile's one-press dodge. ADR
	# 0039 rejected a held slide for the *missile*, where it flattened every
	# approach into a lane change; a ship is not flying a terminal approach and
	# has no such geometry to flatten.
	var strafe := Input.get_axis("strafe_left", "strafe_right") * strafe_speed()

	# The clamp is on the WHOLE velocity, not on the throttle alone. Thrusting
	# sideways at full throttle otherwise sums to more than the top speed — 34 m/s
	# forward plus 12 m/s across is 36 — and the speed hierarchy would be broken by
	# holding two keys rather than by editing a number.
	_velocity = (-basis.z * (_throttle * manual_max_speed()) + basis.x * strafe) \
		.limit_length(manual_max_speed())
	position += _velocity * delta


## Flying the road.
##
## The same three inputs as manual flight — throttle, stick, thrusters — with two
## differences, and no third:
##
## - The ceiling is the cruise drive's, scaled by how far out of the lane you are.
## - The nose is held inside a cone around the ROAD's axis rather than free. The
##   reticle is clamped to the same cone, so it can never be parked somewhere the
##   ship is not allowed to go — a control that lies is worse than a bounded one.
##
## Everything ADR 0057 forbids is absent by construction: nothing fades, nothing
## loads, the stick and the throttle are live every frame, and the space outside the
## lane stays rendered because the lane is drawn as ribs rather than as a tunnel.
func _fly_cruise(delta: float) -> void:
	var accel_seconds := maxf(
		HullClass.num(hull_class, "accel_seconds", "ship/manual_accel_seconds"), 0.01)
	var brake_seconds := maxf(
		HullClass.num(hull_class, "brake_seconds", "ship/manual_brake_seconds"), 0.01)
	if Input.is_action_pressed("throttle_up"):
		_throttle = minf(_throttle + delta / accel_seconds, 1.0)
	if Input.is_action_pressed("throttle_down"):
		_throttle = maxf(_throttle - delta / brake_seconds, 0.0)

	var stick := ReticleSteering.apply_deadzone(Vector2(
		Input.get_axis("aim_left", "aim_right"),
		Input.get_axis("aim_up", "aim_down"),
	), Tuning.num("controls/deadzone"))

	# The reticle's own cone is opened right out here, because the road's cone below
	# replaces it. Two nested cones would compound into something neither value
	# describes, and the tuning comment on `cruise_turn_clamp_deg` promises that this
	# one number decides how much the player may steer.
	var turned := _reticle.update(basis, stick, delta,
		Tuning.num("controls/stick_reticle_speed_deg_per_sec"),
		Tuning.num("controls/mouse_sensitivity"),
		cruise.turn_rate_deg, 180.0)
	var cone := deg_to_rad(cruise.clamp_deg)
	basis = FlightGeometry.basis_from_forward(
		FlightGeometry.clamp_to_cone(-turned.z, cruise.axis, cone))
	_reticle.aim_basis = FlightGeometry.basis_from_forward(
		FlightGeometry.clamp_to_cone(-_reticle.aim_basis.z, cruise.axis, cone))

	var strafe := Input.get_axis("strafe_left", "strafe_right") * strafe_speed()
	var top := manual_max_speed()
	# The lane's nudge is added to the velocity rather than limited with it: it is
	# the road correcting a lane-keeping mistake, and clamping it away at full
	# throttle would make the correction vanish exactly when it is needed.
	_velocity = (-basis.z * (_throttle * top) + basis.x * strafe) \
		.limit_length(top) + cruise.push()
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
	# Against the CLASS's hull scale, not the shared one: a fighter drawn at a
	# quarter size with a gunboat's hit sphere would be hit from four hull-widths
	# away, and nothing would report it. Drawn shape is hit shape (ADR 0043).
	var scale := maxf(Tuning.num("ship/hit_radius_scale"), 0.01)
	if _hull == null or _hull.mesh == null:
		return hull_scale() * scale
	var extents: Vector3 = _hull.mesh.get_aabb().size * 0.5
	return extents.length() * hull_scale() * scale


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
		_last_depth = Tuning.num("ship/arc_depth")
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

## Place the ship on its station: the tuned standoff along its current bearing, on
## the arc plane below the target. Used for initial placement and after a standoff
## or depth edit.
func snap_to_standoff() -> void:
	if target == null:
		return
	var standoff := Tuning.num("ship/standoff_distance")
	var depth := clampf(Tuning.num("ship/arc_depth"), 0.0, standoff * 0.95)
	var arc_radius := sqrt(maxf(standoff * standoff - depth * depth, 1.0))

	var to_target := target.position - position
	var flat := Vector3(to_target.x, 0.0, to_target.z)
	# No bearing to preserve — the ship is on the target's own vertical axis. Any
	# bearing is as good as any other, so take one instead of refusing to place.
	var radial := Vector3.RIGHT if flat.length() < 0.001 else flat.normalized()
	position = target.position - radial * arc_radius - Vector3.UP * depth
	_last_standoff = standoff
	_last_depth = Tuning.num("ship/arc_depth")

	# Face along the arc, so the first frame is not a snap from an arbitrary basis.
	look_at(global_position + radial.cross(Vector3.UP) * _orbit_sign, Vector3.UP)
	_reticle.reset(basis)


## The hull's actual size in metres, at this class's scale.
##
## Distinct from `hit_radius`, which is a bounding SPHERE and is generous on purpose.
## An aperture the ship has to fit through is an axis-by-axis question: the bounding
## sphere of a 44 x 24 x 48 m gunboat is 72 m across, and checking a 50 m portal
## against that would condemn an opening the ship flies through with 13 m to spare.
## Half the hull's section across and up, for the lane to measure itself against.
##
## The lane is measured against the SHIP rather than against a point (`CruiseLane`):
## a capital is 76 m across in a lane that is 240, and one that only noticed the
## centre would let most of the hull hang through the rails before anything reported
## it. Across and up only — the length does not decide whether you are in your lane.
func lane_clearance() -> Vector2:
	var size := hull_extents()
	return Vector2(size.x, size.y) * 0.5


func hull_extents() -> Vector3:
	if _hull == null or _hull.mesh == null:
		return Vector3.ONE * hull_scale()
	return _hull.mesh.get_aabb().size * hull_scale()


## Leave a dock, already moving.
##
## Departing must not put the ship back where it landed, at rest, pointing at the
## surface it just left: that is a hole to climb out of on every single visit, and
## the climb is not interesting the second time. It leaves on the REFLECTION of its
## arrival — same bearing, vertical flipped — so a descent becomes a climb and the
## planet is behind it on the first frame.
##
## The throttle is set to match the speed rather than left at zero, because a ship
## given velocity and no throttle bleeds it off over the next second and the takeoff
## reads as a shove instead of as flying away.
func launch_from_dock(fraction: float) -> void:
	var facing := -basis.z
	var away := Vector3(facing.x, -facing.y, facing.z)
	if away.length_squared() <= 0.000001:
		away = Vector3.UP
	basis = FlightGeometry.basis_from_forward(away.normalized())
	_throttle = clampf(fraction, 0.0, 1.0)
	_velocity = -basis.z * (_throttle * manual_max_speed())
	_reticle.reset(basis)


## Park the reticle on the nose. Called when the heading changes for a reason that
## was not steering — here, entering or leaving the road, where the cone the reticle
## lives in changes shape under it and a stale aim would read as a snap.
func reset_reticle() -> void:
	_reticle.reset(basis)


## Current distance to the commanded target, for the HUD and for tests.
func range_to_target() -> float:
	return 0.0 if target == null else position.distance_to(target.position)


## How far below the target the ship currently sits. Positive is below, which is
## where the autopilot holds it so the turret has a line over its own hull.
func depth_below_target() -> float:
	return 0.0 if target == null else target.position.y - position.y


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
