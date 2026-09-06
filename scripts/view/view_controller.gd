class_name ViewController
extends Node
## The camera/control state machine, which is really a **crew roster** (ADR 0056).
##
## The player holds one job at a time:
##
##     PILOT  ←T/G→  GUNNER          the two stations
##       └── Q ──→ riding a missile ──→ back to whichever job they left
##
## `T` and `G` **pick a job**; they are not toggles and there is no third state.
## Everything else follows from which job is held:
##
## - **Pilot** — the helm. The autopilot hands over; the player flies.
## - **Gunner** — the guns. The autopilot takes the ship back, because a ship
##   nobody is flying has to fly itself.
##
## The autopilot is therefore a *consequence of not being the pilot*, never a mode
## of its own. That is the whole of ADR 0056 and it replaces ADR 0040's independent
## toggle: one press used to mean "hand the ship over", and now it means "go to the
## helm", which is the same act described from the player's side instead of the
## ship's.
##
## Riding a missile is an excursion, not a job: the ship keeps whatever its roster
## implies while the player is away — a gunner's ship keeps arcing, a pilot's ship
## coasts on the velocity they left it with — and the ride ends back at the station
## they fired from.
##
## Transitions are instant by design. `camera/missile_view_mode` is carried in
## tuning so the Descent-style picture-in-picture alternative can be felt back to
## back against the hard cut, but only "cut" is implemented — PiP is step 9.

signal view_changed(view: int)

## The jobs. Appended to, never reordered — there may be more of them later
## (`docs/PROJECT_OVERVIEW.md` Pillar 6 has a crew in it).
enum Role { PILOT, GUNNER }
enum View { SHIP, MISSILE, TURRET }

var _role: Role = Role.PILOT
var _view: View = View.SHIP
var _ship: Mothership
var _turret: Turret
var _ship_camera: ChaseCamera
var _missile_camera: ChaseCamera
var _turret_camera: ChaseCamera
var _piloted_missile: Missile


func _ready() -> void:
	# The tuning panel takes the pointer while it is open; hand it back after.
	DebugPanel.toggled.connect(func(open: bool) -> void:
		if not open:
			_apply_mouse_mode())


## The pointer is captured whenever it is steering something, which under the
## roster is always: a pilot flies the ship, a gunner aims the guns, and a rider
## flies the missile. It is released only for the tuning panel.
func _apply_mouse_mode() -> void:
	if DebugPanel.is_open():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _steering() \
		else Input.MOUSE_MODE_VISIBLE


## Is the player flying or aiming something right now?
func _steering() -> bool:
	if _view == View.MISSILE or _view == View.TURRET:
		return true
	return _ship != null and not _ship.autopilot


## Re-read the mouse mode. Kept because the debug panel closing has to restore it,
## and because a caller that changes the roster out of band should be able to say so.
func refresh_mouse_mode() -> void:
	_apply_mouse_mode()


func setup(ship: Mothership, ship_camera: ChaseCamera, missile_camera: ChaseCamera,
		turret: Turret, turret_camera: ChaseCamera) -> void:
	_ship = ship
	_ship_camera = ship_camera
	_missile_camera = missile_camera
	_turret = turret
	_turret_camera = turret_camera
	_ship_camera.subject = ship
	_ship_camera.tuning_prefix = "camera/ship"
	_missile_camera.tuning_prefix = "camera/missile"
	_turret_camera.subject = turret
	_turret_camera.tuning_prefix = "camera/turret"
	# The gun elevates far enough that a rigid boom would swing back through the
	# hull it is mounted on; see ChaseCamera.pitch_share_key. At the first-person
	# distance the boom is too short for that to matter, but the mechanism stays so
	# pulling the camera back does not reintroduce the problem.
	_turret_camera.pitch_share_key = "camera/turret_boom_pitch_share"
	# The gun gets its own, narrower field of view. Aiming and flying want different
	# ones: a helm wants to see what is around it, a gun wants magnification.
	_turret_camera.set_fov_key("camera/turret_fov")
	set_role(role_from_name(Tuning.text("ship/start_role")))


# --- the roster --------------------------------------------------------------

## Take a job. Idempotent on purpose: `T` while already the pilot does nothing,
## which is what makes these selections rather than toggles — a player who has lost
## track of which station they are at can press the one they want and be right,
## instead of pressing it and ending up somewhere else.
##
## Refused while actually riding a missile: the player is not at either station,
## and a job change that took effect when they landed would be a control acting
## several seconds after it was pressed.
##
## The test is on the missile, not on the view, because the view stays MISSILE for
## `camera/return_delay_sec` after a detonation while the flash is watched. During
## that window there is nothing being flown, so a job press takes effect at once and
## the pending return stands down.
func set_role(role: Role) -> bool:
	if _piloted_missile != null and is_instance_valid(_piloted_missile):
		return false
	_role = role
	_apply_role()
	if role == Role.GUNNER:
		_enter_turret_view()
	else:
		_enter_ship_view()
	return true


## Hand the ship to the autopilot or to the player, from the roster and nothing
## else. A ship nobody is flying has to fly itself; a ship the player is at the
## helm of must not be flown out from under them (ADR 0056).
func _apply_role() -> void:
	if _ship == null:
		return
	_ship.set_autopilot(_role == Role.GUNNER)
	# The station only takes input while it is manned. It keeps its bearing either
	# way — an unmanned turret holds where it was left (ADR 0048).
	if _turret != null:
		_turret.active = _role == Role.GUNNER


func role() -> Role:
	return _role


func role_name() -> String:
	return "GUNNER" if _role == Role.GUNNER else "PILOT"


## Tuning names the starting job in words rather than by index, so a typo reads as
## something rather than as whichever job happens to share that number — the same
## reasoning as the turret's weapon slots (ADR 0048).
static func role_from_name(name_text: String) -> Role:
	return Role.GUNNER if name_text.strip_edges().to_lower() == "gunner" else Role.PILOT


# --- views -------------------------------------------------------------------

func enter_missile_view(missile: Missile) -> void:
	# The player leaves their station the moment they are in the missile. Under
	# the autopilot this changes nothing; at the helm it is what stops W and A from
	# flying the ship and the missile at the same time.
	if _ship != null:
		_ship.piloted = false
	if _turret != null:
		_turret.active = false
	_piloted_missile = missile
	missile.piloted = true
	missile.detonated.connect(_on_missile_detonated)

	_missile_camera.subject = missile
	_missile_camera.snap()
	_missile_camera.current = true
	_view = View.MISSILE
	# The mouse is the missile's stick while riding; it returns to the station after.
	_apply_mouse_mode()
	view_changed.emit(_view)


func _on_missile_detonated(_missile: Missile, _reason: int, _hit: bool) -> void:
	_piloted_missile = null
	var delay := Tuning.num("camera/return_delay_sec")
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	# A second missile may have been fired during the delay; do not steal its view.
	# Nor if the player has already picked a station during it — a job press is a
	# live instruction and outranks a timer that was started before it.
	if _piloted_missile != null or _view != View.MISSILE:
		return
	# Back to the job they left, not to a default. The roster is what the player
	# set; a ride is an excursion from it.
	_apply_role()
	if _role == Role.GUNNER:
		_enter_turret_view()
	else:
		_enter_ship_view()


func _enter_ship_view() -> void:
	if _ship != null:
		_ship.piloted = true
	_ship_camera.snap()
	_ship_camera.current = true
	_view = View.SHIP
	_apply_mouse_mode()
	view_changed.emit(_view)


func _enter_turret_view() -> void:
	if _ship != null:
		# Nobody is at the helm. The autopilot has it, and `piloted` is what stops
		# the ship reading the keys the gunner is pressing.
		_ship.piloted = false
	_turret_camera.snap()
	_turret_camera.current = true
	_view = View.TURRET
	_apply_mouse_mode()
	view_changed.emit(_view)


## Mouse motion goes to whatever is being flown or aimed. Routing it here keeps
## each station the only thing that decides how input becomes movement, and means
## none of them has to know whether it is the one on screen.
func _unhandled_input(event: InputEvent) -> void:
	if DebugPanel.is_open() or not (event is InputEventMouseMotion):
		return
	var relative := (event as InputEventMouseMotion).relative
	match _view:
		View.MISSILE:
			if _piloted_missile != null and is_instance_valid(_piloted_missile):
				_piloted_missile.add_mouse_steer(relative)
		View.TURRET:
			if _turret != null:
				_turret.add_mouse_aim(relative)
		View.SHIP:
			if _ship != null and not _ship.autopilot:
				_ship.add_mouse_steer(relative)


func view() -> View:
	return _view


func view_name() -> String:
	match _view:
		View.MISSILE:
			return "MISSILE"
		View.TURRET:
			return "TURRET"
	return "SHIP"


func piloted_missile() -> Missile:
	return _piloted_missile


func turret() -> Turret:
	return _turret
