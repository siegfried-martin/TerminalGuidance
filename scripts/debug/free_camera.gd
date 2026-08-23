class_name FreeCamera
extends Camera3D
## Debug fly-cam for inspecting the sandbox. Hold right mouse to look, WASD to
## move, Q/E down/up, Shift to boost.
##
## This is a debug tool, not the game's camera and not a flight model. The
## mothership and missile cameras in the POC are separate and will not inherit
## from this. Its speeds still come from tuning.json, because anything the
## developer will want to nudge while looking at the screen belongs there.

var _yaw: float = 0.0
var _pitch: float = 0.0
var _velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	# Adopt whatever orientation the caller framed us with, so the debug cam
	# does not snap on the first frame.
	_yaw = rotation.y
	_pitch = rotation.x
	fov = Tuning.num("camera/fov_base")
	Tuning.reloaded.connect(func() -> void: fov = Tuning.num("camera/fov_base"))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cam_look"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_released("cam_look"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := (event as InputEventMouseMotion).relative
		var sens := Tuning.num("camera/free_look_sensitivity")
		_yaw -= deg_to_rad(motion.x * sens)
		_pitch = clampf(_pitch - deg_to_rad(motion.y * sens), -PI * 0.49, PI * 0.49)


func _process(delta: float) -> void:
	rotation = Vector3(_pitch, _yaw, 0.0)

	var wish := Vector3(
		Input.get_axis("cam_left", "cam_right"),
		Input.get_axis("cam_down", "cam_up"),
		Input.get_axis("cam_forward", "cam_back"),
	)
	if wish.length_squared() > 1.0:
		wish = wish.normalized()

	var speed := Tuning.num("camera/free_move_speed")
	if Input.is_action_pressed("cam_boost"):
		speed *= Tuning.num("camera/free_boost_multiplier")

	var target := (global_transform.basis * wish) * speed
	var smoothing := Tuning.num("camera/free_move_smoothing")
	_velocity = _velocity.lerp(target, clampf(smoothing * delta, 0.0, 1.0))
	global_position += _velocity * delta


func speed_mps() -> float:
	return _velocity.length()
