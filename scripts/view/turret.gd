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
## This file is the station only: where it points, which weapons are on which
## button, and what it costs to switch. The weapons themselves are step 2 of the
## build order in docs/TURRET_MODE_IMPLEMENTATION.md and are deliberately absent
## rather than stubbed.

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


func _ready() -> void:
	reset_to_hull()


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


## Where a turret round leaves the ship, in the parent frame. Used by step 2's
## weapons; here so the mount point has exactly one definition.
func muzzle_position() -> Vector3:
	return position + aim_local() * Tuning.num("turret/muzzle_offset")


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
