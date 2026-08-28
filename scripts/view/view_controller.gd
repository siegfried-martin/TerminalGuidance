class_name ViewController
extends Node
## The camera/control mode state machine.
##
##     SHIP ←→ TURRET
##      ↓ (fire)
##     MISSILE → (impact | fuse | rock) → SHIP
##
## TURRET is a peer of SHIP, not a sub-state of it: the player is at the helm or
## at the guns, never both. That is the sequential-attention rule in CLAUDE.md,
## and it is why entering either one takes the ship's controls away rather than
## sharing them.
##
## A missile is fired from the helm, so the only edge out of TURRET is back to
## SHIP. There is no direct TURRET → MISSILE launch, and adding one would put the
## player on two things at once for the frame it takes to leave.
##
## Transitions are instant by design. `camera/missile_view_mode` is carried in
## tuning so the Descent-style picture-in-picture alternative can be felt back to
## back against the hard cut, but only "cut" is implemented — PiP is step 9.

signal view_changed(view: int)

enum View { SHIP, MISSILE, TURRET }

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


## The pointer is captured whenever it is steering something: a ridden missile
## always, the turret always, and the ship only while the player has it off
## autopilot (ADR 0040). Under autopilot there is nothing for the mouse to fly, so
## it stays free for the tuning panel.
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


## Re-read the mouse mode. Called when the ship changes hands, which is the one
## thing that can change the answer without a view change.
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
	# hull it is mounted on; see ChaseCamera.pitch_share_key.
	_turret_camera.pitch_share_key = "camera/turret_boom_pitch_share"
	_enter_ship_view()


func enter_missile_view(missile: Missile) -> void:
	# The ship stops reading input the moment the player leaves it. Under autopilot
	# this changes nothing; under manual flight it is what stops W and A from
	# flying the ship and the missile at the same time.
	_release_ship()
	_piloted_missile = missile
	missile.piloted = true
	missile.detonated.connect(_on_missile_detonated)

	_missile_camera.subject = missile
	_missile_camera.snap()
	_missile_camera.current = true
	_view = View.MISSILE
	# The mouse is the missile's stick while riding; release it when we return.
	_apply_mouse_mode()
	view_changed.emit(_view)


## Man the guns. Refused while riding a missile — that transition is what the
## sequential-attention rule forbids, and the player already has a way back to the
## ship (the missile ends).
func enter_turret_view() -> bool:
	if _view == View.MISSILE or _turret == null:
		return false
	_release_ship()
	_turret.active = true
	_turret_camera.snap()
	_turret_camera.current = true
	_view = View.TURRET
	_apply_mouse_mode()
	view_changed.emit(_view)
	return true


## `G` in either direction: to the guns from the helm, back to the helm from the
## guns. A no-op while riding a missile.
func toggle_turret() -> bool:
	if _view == View.TURRET:
		_enter_ship_view()
		return true
	return enter_turret_view()


func _on_missile_detonated(_missile: Missile, _reason: int, _hit: bool) -> void:
	_piloted_missile = null
	var delay := Tuning.num("camera/return_delay_sec")
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	# A second missile may have been fired during the delay; do not steal its view.
	if _piloted_missile == null:
		_enter_ship_view()


func _enter_ship_view() -> void:
	if _turret != null:
		# The station keeps its bearing while unmanned — it just stops taking input.
		_turret.active = false
	if _ship != null:
		_ship.piloted = true
	_ship_camera.snap()
	_ship_camera.current = true
	_view = View.SHIP
	_apply_mouse_mode()
	view_changed.emit(_view)


## Take the helm out of the player's hands without touching the autopilot. An
## autopiloted ship keeps arcing; a manually flown one coasts on its velocity.
func _release_ship() -> void:
	if _ship != null:
		_ship.piloted = false


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
