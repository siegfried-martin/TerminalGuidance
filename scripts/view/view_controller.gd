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
var _ship_camera: ChaseCamera
var _missile_camera: ChaseCamera
var _piloted_missile: Missile


func _ready() -> void:
	# The tuning panel takes the pointer while it is open; hand it back after.
	DebugPanel.toggled.connect(func(open: bool) -> void:
		if not open:
			_apply_mouse_mode())


func _apply_mouse_mode() -> void:
	if DebugPanel.is_open():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _view == View.MISSILE \
		else Input.MOUSE_MODE_VISIBLE


func setup(ship: Node3D, ship_camera: ChaseCamera, missile_camera: ChaseCamera) -> void:
	_ship_camera = ship_camera
	_missile_camera = missile_camera
	_ship_camera.subject = ship
	_ship_camera.tuning_prefix = "camera/ship"
	_missile_camera.tuning_prefix = "camera/missile"
	_enter_ship_view()


func enter_missile_view(missile: Missile) -> void:
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
	_ship_camera.snap()
	_ship_camera.current = true
	_view = View.SHIP
	_apply_mouse_mode()
	view_changed.emit(_view)


func _unhandled_input(event: InputEvent) -> void:
	if _view == View.MISSILE and not DebugPanel.is_open() and event is InputEventMouseMotion \
			and _piloted_missile != null and is_instance_valid(_piloted_missile):
		_piloted_missile.add_mouse_steer((event as InputEventMouseMotion).relative)


func view() -> View:
	return _view


func view_name() -> String:
	return "MISSILE" if _view == View.MISSILE else "SHIP"


func piloted_missile() -> Missile:
	return _piloted_missile
