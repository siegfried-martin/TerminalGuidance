class_name Turret
extends Node3D
## The gun station — POC build step 6, the second half of the combat bet.
##
## A peer of flying the ship, never a sub-state of it. The player is either at the
## helm or at the guns, which is the sequential-attention rule in CLAUDE.md made
## structural rather than asked for politely: while the station is manned the ship
## stops reading input, exactly as it does while a missile is being ridden.
##
## Two things make this a turret and not a second cockpit:
##
## 1. **The aim lives in the arena frame, not the ship's.** The hull rotates under
##    the station without dragging the gun with it, and the bearing survives being
##    left and come back to. Everything is parent-relative, so a floating-origin
##    recentre leaves it valid (ADR 0020).
## 2. **The mouse aims 1:1, with no reticle and no lag.** ADR 0035's two-stage
##    steering exists to give a *vehicle* weight; a gun has no mass to express, and
##    one of the four weapons is hitscan — an aim that lags behind a hitscan weapon
##    is a control that lies about where the shot went.
##
## Roll can never accumulate (ADR 0045) because there is nowhere for it to hide:
## the aim is two scalars, an azimuth and an elevation, and the basis is derived
## from them every frame.
##
## Two of the four weapons are live: the autocannon, which throws a `Projectile`
## on a fire-rate cooldown, and the pulse beam, which is hitscan on purpose (the
## human's spec calls that a requirement, so lead and travel time never have to be
## reasoned about) and is limited by heat rather than by ammo. The unguided missile
## and the blockers are stages 3 and 4 of docs/TURRET_MODE_IMPLEMENTATION.md and
## are deliberately absent rather than stubbed; a loadout slot holding one simply
## does nothing yet.
##
## Every shot — travelling or hitscan — resolves through `Shot`, so a rock between
## the gun and the target stops it and a component mounted proud of the hull is
## reached before the hull (ADR 0043). No physics bodies (ADR 0032).

## The four weapons of the specification, plus an explicit empty slot so a loadout
## can be turned off from tuning without a code change — the "every layer is
## independently disableable" requirement of the build.
enum Weapon { NONE, AUTOCANNON, UNGUIDED, PULSE, BLOCKER }

const LOADOUT_COUNT := 2

## True while the player is at the station. The aim only moves when it is manned;
## an unmanned turret holds its bearing rather than drifting or re-centring.
var active: bool = false
## The hull the station is bolted to. The mount point rides the ship; the aim does not.
var ship: Mothership

## Aim, in the parent frame. Azimuth 0 points along -Z, positive turns right;
## elevation 0 is the shared horizon of ADR 0045, positive is up.
var _azimuth: float = 0.0
var _elevation: float = 0.0
var _pending_mouse: Vector2 = Vector2.ZERO
var _loadout: int = 1

## What the guns can reach, and where their effects are parented. Set by the arena
## through `setup`; held rather than looked up, so a shot fired into a torn-down
## arena cannot resurrect it.
var _world: Node3D
var _target: TargetShip
var _rocks: ReferenceField
var _beam: BeamFlash

## Seconds until the autocannon may fire again. Ticks down whether or not the
## button is held, so tapping cannot bank shots.
var _autocannon_cooldown: float = 0.0
## 0 to 1. At 1 the beam locks out for `turret/pulse_overheat_lockout_seconds`.
var _heat: float = 0.0
var _overheat_left: float = 0.0
var _rounds_fired: int = 0


func _ready() -> void:
	reset_to_hull()


## Hand the station what it can shoot at and where to put its effects. Called by
## the arena after the node is in the tree, because the beam is parented into
## arena space rather than to the gun — it is drawn in the frame its endpoints are
## measured in (ADR 0020).
func setup(world: Node3D, target: TargetShip, rocks: ReferenceField) -> void:
	_world = world
	_target = target
	_rocks = rocks
	if _beam == null and world != null:
		_beam = BeamFlash.new()
		_beam.name = "PulseBeam"
		world.add_child(_beam)


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	if active:
		_aim(delta)
	else:
		# Motion between frames still arrives while the panel or another view has
		# the pointer; drop it rather than applying it all at once on re-entry.
		_pending_mouse = Vector2.ZERO
	_ride_the_hull()
	basis = FlightGeometry.basis_from_forward(aim_local())
	_run_weapons(delta)


# --- aiming ------------------------------------------------------------------

func _aim(delta: float) -> void:
	var sensitivity := deg_to_rad(Tuning.num("controls/turret_mouse_sensitivity"))
	var stick := ReticleSteering.apply_deadzone(Vector2(
		Input.get_axis("aim_left", "aim_right"),
		Input.get_axis("aim_up", "aim_down"),
	), Tuning.num("controls/deadzone"))
	var sweep := deg_to_rad(Tuning.num("turret/traverse_deg_per_sec")) * delta

	# Screen convention for both devices: right turns right, down aims down.
	_azimuth += _pending_mouse.x * sensitivity + stick.x * sweep
	_elevation -= _pending_mouse.y * sensitivity + stick.y * sweep
	_pending_mouse = Vector2.ZERO

	_azimuth = wrapf(_azimuth, -PI, PI)
	var limit := deg_to_rad(Tuning.num("turret/elevation_limit_deg"))
	_elevation = clampf(_elevation, -limit, limit)


## Mouse motion arrives as events between frames, so the view controller feeds it
## here and it accumulates until the next `_process` consumes it.
func add_mouse_aim(relative: Vector2) -> void:
	if active:
		_pending_mouse += relative


## Point the gun down the hull's nose. Called once at construction so the first
## entry is not a station aimed at the stern; never called on later entries,
## because holding its bearing while the ship manoeuvres under it is the whole
## behaviour that distinguishes a turret from a nose gun.
func reset_to_hull() -> void:
	var forward := Vector3.FORWARD if ship == null else -ship.basis.z
	set_aim_direction(forward)


## Aim at a direction given in the parent frame. Elevation is clamped, so a caller
## cannot place the gun somewhere it could not have been driven to by hand.
func set_aim_direction(direction: Vector3) -> void:
	var d := direction.normalized()
	if d.length_squared() < 0.5:
		return
	var limit := deg_to_rad(Tuning.num("turret/elevation_limit_deg"))
	_elevation = clampf(asin(clampf(d.y, -1.0, 1.0)), -limit, limit)
	var flat := Vector2(d.x, -d.z)
	# Straight up or straight down leaves no bearing to read; keep the current one.
	if flat.length_squared() > 0.000001:
		_azimuth = atan2(flat.x, flat.y)


## The aim in the parent frame — arena space, which is what every hit test wants.
func aim_local() -> Vector3:
	var horizontal := Vector3(sin(_azimuth), 0.0, -cos(_azimuth))
	return horizontal * cos(_elevation) + Vector3.UP * sin(_elevation)


## The same direction in world space, for the screen-space overlay.
func aim_direction() -> Vector3:
	var parent := get_parent_node_3d()
	if parent == null:
		return aim_local()
	return (parent.global_transform.basis * aim_local()).normalized()


func azimuth_degrees() -> float:
	return rad_to_deg(_azimuth)


func elevation_degrees() -> float:
	return rad_to_deg(_elevation)


## Where a turret round leaves the ship, in the parent frame.
##
## The muzzle sits **off** the sight line, not on it — `turret/muzzle_mount_offset`
## drops it below the station in the station's own frame. Fired from the sight line
## itself, every tracer and every beam travels straight down the camera's view axis
## and projects to a single dot at the crosshair: the player cannot see their own
## fire at all. That was true of the first version and it is not a cosmetic
## complaint — a gun whose shots are invisible gives no feedback between firing and
## the impact flash.
func muzzle_position() -> Vector3:
	return position + aim_local() * Tuning.num("turret/muzzle_offset") \
		+ basis * Tuning.vec3("turret/muzzle_mount_offset")


## The sight line's own origin: on the aim, clear of the mount. The hitscan beam
## resolves from here rather than from the muzzle, so it is exact at every range —
## "hitscan, so travel time and lead never have to be factored in" is a
## specification requirement, and a beam that lands low at close range would be
## factoring geometry back in through the side door. It is *drawn* from the muzzle
## to wherever it landed, which is what a converging tracer looks like anyway.
func sight_origin() -> Vector3:
	return position + aim_local() * Tuning.num("turret/muzzle_offset")


## The direction a travelling round leaves the muzzle: towards the point the
## crosshair marks, not parallel to the aim.
##
## The two are different because the muzzle is offset from the sight line, and
## firing parallel from there would put every shot a muzzle-offset below the
## crosshair at every range — a sight that lies. Converging means the guns are
## exactly right at `turret/convergence_distance` and progressively off either side
## of it, which is how a real sighted gun behaves and is why that value is tuned
## against `ship/standoff_distance`.
func firing_direction() -> Vector3:
	var convergence := position + aim_local() * Tuning.num("turret/convergence_distance")
	var offset := convergence - muzzle_position()
	if offset.length_squared() < 0.000001:
		return aim_local()
	return offset.normalized()


# --- firing ------------------------------------------------------------------

## One frame of every weapon that is currently held.
##
## Cooldowns and cooling run whether or not the station is manned, so leaving for a
## missile and coming back does not find the gun in the state it was abandoned in.
## Firing itself needs the station manned, which is the sequential-attention rule
## again — an unmanned turret is not a second player.
func _run_weapons(delta: float) -> void:
	_autocannon_cooldown = maxf(_autocannon_cooldown - delta, 0.0)
	_overheat_left = maxf(_overheat_left - delta, 0.0)

	var held := held_weapons()
	if held.has(Weapon.AUTOCANNON):
		_fire_autocannon()

	# The beam is the only weapon whose *not* firing is a state change, because
	# that is when it cools. Everything else simply does nothing.
	if held.has(Weapon.PULSE) and _overheat_left <= 0.0:
		_fire_pulse(delta)
	else:
		_heat = maxf(_heat - Tuning.num("turret/pulse_cool_per_second") * delta, 0.0)


## Which weapons the player is asking for this frame, deduped — two loadout slots
## may legitimately hold the same weapon, and it must not then run twice and build
## heat at double rate.
func held_weapons() -> Array:
	var held: Array = []
	if not active:
		return held
	if Input.is_action_pressed("fire_primary"):
		held.append(primary())
	if Input.is_action_pressed("fire_secondary") and not held.has(secondary()):
		held.append(secondary())
	held.erase(Weapon.NONE)
	return held


func _fire_autocannon() -> void:
	if _autocannon_cooldown > 0.0 or _world == null:
		return
	var rate := maxf(Tuning.num("turret/autocannon_rounds_per_second"), 0.01)
	_autocannon_cooldown = 1.0 / rate
	_rounds_fired += 1

	var round_shot := Projectile.new()
	round_shot.name = "Round"
	_world.add_child(round_shot)
	round_shot.launch(muzzle_position(), firing_direction(),
		"turret/autocannon", _target, _rocks)
	round_shot.spent.connect(_on_round_spent)


## Hitscan, on purpose: the whole range is resolved in one segment this frame, so
## there is no lead to work out and no travel time to feel. That is a design
## requirement from the specification, not a shortcut — and it is the reason the
## aim has no reticle (ADR 0048).
##
## Damage is per *second*, applied as `rate x delta`, so the component darkens
## continuously while the beam is on it rather than in steps. That is the visible
## difference between a beam and a gun.
func _fire_pulse(delta: float) -> void:
	var from := sight_origin()
	var to := from + aim_local() * Tuning.num("turret/pulse_range")
	var result := Shot.resolve(from, to, _target, _rocks)
	var end_point: Vector3 = result["point"]

	var component := int(result["component"])
	if component >= 0 and _target != null and is_instance_valid(_target):
		_target.damage_component(
			component, Tuning.num("turret/pulse_damage_per_second") * delta)

	_heat = minf(_heat + Tuning.num("turret/pulse_heat_per_second") * delta, 1.0)
	if _heat >= 1.0:
		_overheat_left = Tuning.num("turret/pulse_overheat_lockout_seconds")

	if _beam != null and is_instance_valid(_beam):
		_beam.strike(muzzle_position(), end_point, Tuning.num("turret/pulse_beam_width"),
			Tuning.color("turret/pulse_beam_color"),
			Tuning.num("turret/pulse_beam_fade_seconds"))


## A round reaching something gets the missile's own flash, scaled down. A real
## impact effect is art and this is gray-box (ADR 0030); what matters is that the
## player can see where the shot went, including when it went into a rock.
func _on_round_spent(_round_shot: Projectile, kind: int, point: Vector3) -> void:
	if kind == Shot.Kind.NOTHING or _world == null or not is_instance_valid(_world):
		return
	var flash := DetonationFlash.new()
	flash.name = "ImpactFlash"
	_world.add_child(flash)
	flash.position = point
	flash.setup(
		Tuning.num("turret/impact_flash_start_radius"),
		Tuning.num("turret/impact_flash_end_radius"),
		Tuning.num("turret/impact_flash_seconds"),
		Tuning.color("turret/impact_flash_color" if kind == Shot.Kind.COMPONENT
			else "turret/impact_flash_color_dud"))


# --- weapon state readouts ---------------------------------------------------

## 0 to 1. The beam locks out at 1 and cannot fire again until it has cooled for
## `turret/pulse_overheat_lockout_seconds`.
func heat() -> float:
	return _heat


func is_overheated() -> bool:
	return _overheat_left > 0.0


func overheat_remaining() -> float:
	return _overheat_left


func autocannon_ready() -> bool:
	return _autocannon_cooldown <= 0.0


func autocannon_cooldown_remaining() -> float:
	return _autocannon_cooldown


## Rounds the autocannon has put out this session. A readout for the gate and the
## HUD; the autocannon has unlimited ammo by specification.
func rounds_fired() -> int:
	return _rounds_fired


# --- loadouts ----------------------------------------------------------------

## Which loadout is live: 1 or 2, switched by the `1` and `2` keys. Four weapons
## across two buttons means a loadout switch is the cost of reaching the other
## two — that is the mechanic, not a UI convenience.
func loadout() -> int:
	return _loadout


func set_loadout(index: int) -> int:
	if index >= 1 and index <= LOADOUT_COUNT:
		_loadout = index
	return _loadout


func primary() -> Weapon:
	return _slot("primary")


func secondary() -> Weapon:
	return _slot("secondary")


func _slot(slot: String) -> Weapon:
	return weapon_from_name(Tuning.text("turret/loadout_%d_%s" % [_loadout, slot]))


## Tuning carries weapon slots as names rather than numbers so the file stays
## readable and so an unknown name fails loudly to NONE instead of landing on
## whichever weapon happens to share that index.
static func weapon_from_name(name_text: String) -> Weapon:
	match name_text.strip_edges().to_lower():
		"autocannon":
			return Weapon.AUTOCANNON
		"unguided":
			return Weapon.UNGUIDED
		"pulse":
			return Weapon.PULSE
		"blocker":
			return Weapon.BLOCKER
	return Weapon.NONE


static func weapon_label(weapon: Weapon) -> String:
	match weapon:
		Weapon.AUTOCANNON:
			return "autocannon"
		Weapon.UNGUIDED:
			return "unguided"
		Weapon.PULSE:
			return "pulse"
		Weapon.BLOCKER:
			return "blocker"
	return "—"


# --- mounting ----------------------------------------------------------------

## The station rides the hull: the mount point is fixed in the ship's frame and so
## swings as the ship turns, while the aim stays where it was left.
func _ride_the_hull() -> void:
	if ship == null or not is_instance_valid(ship):
		return
	position = ship.position + ship.basis * Tuning.vec3("turret/mount_offset")
