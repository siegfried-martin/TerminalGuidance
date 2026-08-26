class_name ViewController
extends Node
## The camera/control mode state machine.
##
##     SHIP_VIEW → (fire) → MISSILE_VIEW → (impact | fuse expiry) → SHIP_VIEW
##
## TURRET_VIEW is POC step 6 and is deliberately absent rather than stubbed. When
## it arrives it is a peer of SHIP_VIEW, not a sub-state of it.
##
## Transitions are instant by design. `camera/missile_view_mode` is carried in
## tuning so the Descent-style picture-in-picture alternative can be felt back to
## back against the hard cut, but only "cut" is implemented — PiP is step 9.

signal view_changed(view: int)

enum View { SHIP, MISSILE }

var _view: View = View.SHIP
var _ship: Mothership
var _ship_camera: ChaseCamera
var _missile_camera: ChaseCamera
var _piloted_missile: Missile


func _ready() -> void:
	# The tuning panel takes the pointer while it is open; hand it back after.
	DebugPanel.toggled.connect(func(open: bool) -> void:
		if not open:
			_apply_mouse_mode())


## The pointer is captured whenever it is steering something: a ridden missile
## always, and the ship only while the player has it off autopilot (ADR 0040).
## Under autopilot there is nothing for the mouse to fly, so it stays free for the
## tuning panel.
func _apply_mouse_mode() -> void:
	if DebugPanel.is_open():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _steering() \
		else Input.MOUSE_MODE_VISIBLE


## Is the player flying something right now?
func _steering() -> bool:
	if _view == View.MISSILE:
		return true
	return _ship != null and not _ship.autopilot


## Re-read the mouse mode. Called when the ship changes hands, which is the one
## thing that can change the answer without a view change.
func refresh_mouse_mode() -> void:
	_apply_mouse_mode()


func setup(ship: Mothership, ship_camera: ChaseCamera, missile_camera: ChaseCamera) -> void:
	_ship = ship
	_ship_camera = ship_camera
	_missile_camera = missile_camera
	_ship_camera.subject = ship
	_ship_camera.tuning_prefix = "camera/ship"
	_missile_camera.tuning_prefix = "camera/missile"
	_enter_ship_view()


func enter_missile_view(missile: Missile) -> void:
	# The ship stops reading input the moment the player leaves it. Under autopilot
	# this changes nothing; under manual flight it is what stops W and A from
	# flying the ship and the missile at the same time.
	if _ship != null:
		_ship.piloted = false
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


func _on_missile_detonated(_missile: Missile, _reason: int, _hit: bool) -> void:
	_piloted_missile = null
	var delay := Tuning.num("camera/return_delay_sec")
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	# A second missile may have been fired during the delay; do not steal its view.
	if _piloted_missile == null:
		_enter_ship_view()


func _enter_ship_view() -> void:
	if _ship != null:
		_ship.piloted = true
	_ship_camera.snap()
	_ship_camera.current = true
	_view = View.SHIP
	_apply_mouse_mode()
	view_changed.emit(_view)


## Mouse motion goes to whatever is being flown. Routing it here keeps each
## vehicle the only thing that decides how input becomes turn, and means neither
## one has to know whether it is the one on screen.
func _unhandled_input(event: InputEvent) -> void:
	if DebugPanel.is_open() or not (event is InputEventMouseMotion):
		return
	var relative := (event as InputEventMouseMotion).relative
	if _view == View.MISSILE:
		if _piloted_missile != null and is_instance_valid(_piloted_missile):
			_piloted_missile.add_mouse_steer(relative)
	elif _ship != null and not _ship.autopilot:
		_ship.add_mouse_steer(relative)


func view() -> View:
	return _view


func view_name() -> String:
	return "MISSILE" if _view == View.MISSILE else "SHIP"


func piloted_missile() -> Missile:
	return _piloted_missile
