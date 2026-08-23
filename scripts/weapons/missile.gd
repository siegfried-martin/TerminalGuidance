class_name Missile
extends Node3D
## A player-flown missile. Constant forward speed, direct screen-space steering,
## and a fuse that ends the flight whether or not the player got there.
##
## ADR 0002 (fuse-as-range) and ADR 0003 (screen-space steering) govern this file.
## The fuse is the range limit and the difficulty dial; the steering is direct,
## not a flight model.
##
## Floating origin (ADR 0020): all flight and hit-testing is done in the parent's
## frame via `position`, never in world space. The one value carried across frames
## — `_previous_position` — is parent-relative for exactly that reason, so a world
## recentre that moves the parent leaves it valid.

signal detonated(missile: Missile, reason: int, hit: bool)

enum EndReason { FUSE_EXPIRED, IMPACT }

var piloted: bool = false

var _speed: float = 0.0
var _fuse_left: float = 0.0
var _previous_position: Vector3
var _target: Node3D
var _target_radius: float = 0.0
var _finished: bool = false
var _pending_steer: Vector2 = Vector2.ZERO
var _body: MeshInstance3D
var _exhaust: MeshInstance3D


func _ready() -> void:
	_build_body()


## Gray-box body. It exists so the chase camera has something to sit behind — an
## invisible missile makes the view read as a free-flying camera, which is a
## different feel entirely.
func _build_body() -> void:
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(
		Tuning.num("missile/body_width"),
		Tuning.num("missile/body_width"),
		Tuning.num("missile/body_length"))
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Tuning.color("missile/body_color")
	body_material.metallic = 0.3
	body_material.roughness = 0.4
	_body = MeshInstance3D.new()
	_body.name = "Body"
	_body.mesh = body_mesh
	_body.material_override = body_material
	add_child(_body)

	var exhaust_mesh := BoxMesh.new()
	exhaust_mesh.size = Vector3(
		Tuning.num("missile/body_width") * 0.6,
		Tuning.num("missile/body_width") * 0.6,
		Tuning.num("missile/exhaust_length"))
	var exhaust_material := StandardMaterial3D.new()
	exhaust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	exhaust_material.albedo_color = Tuning.color("missile/exhaust_color")
	exhaust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	exhaust_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_exhaust = MeshInstance3D.new()
	_exhaust.name = "Exhaust"
	_exhaust.mesh = exhaust_mesh
	_exhaust.material_override = exhaust_material
	_exhaust.position = Vector3(0.0, 0.0,
		(Tuning.num("missile/body_length") + Tuning.num("missile/exhaust_length")) * 0.5)
	add_child(_exhaust)


## `launch_basis` is the firing ship's orientation — the missile leaves along the
## ship's current heading (POC scope item 3), not along an aim point.
func launch(launch_position: Vector3, launch_basis: Basis, ship_velocity: Vector3,
		target: Node3D, target_radius: float) -> void:
	position = launch_position
	basis = launch_basis.orthonormalized()
	_previous_position = launch_position
	_target = target
	_target_radius = target_radius
	_fuse_left = Tuning.num("missile/fuse_seconds")

	# Velocity inheritance is a tunable that starts at zero (ADR 0005). Only the
	# component along the missile's own heading is meaningful for a missile that
	# flies at a constant forward speed.
	var forward := -basis.z
	_speed = Tuning.num("missile/base_speed") \
		+ Tuning.num("missile/velocity_inheritance") * ship_velocity.dot(forward)


func _process(delta: float) -> void:
	if _finished:
		return

	if piloted:
		_apply_steering(delta)

	_previous_position = position
	position += -basis.z * _speed * delta

	if _target != null and FlightGeometry.segment_hits_sphere(
			_previous_position, position, _target.position, _target_radius):
		_finish(EndReason.IMPACT, true)
		return

	_fuse_left -= delta
	if _fuse_left <= 0.0:
		_finish(EndReason.FUSE_EXPIRED, false)


func _apply_steering(delta: float) -> void:
	var stick := Vector2(
		Input.get_axis("missile_left", "missile_right"),
		Input.get_axis("missile_up", "missile_down"),
	)
	var deadzone := Tuning.num("controls/deadzone")
	if stick.length() < deadzone:
		stick = Vector2.ZERO
	elif deadzone < 1.0:
		# Rescale past the deadzone so the first live input is not a step change.
		stick = stick.normalized() * ((stick.length() - deadzone) / (1.0 - deadzone))

	var max_step := deg_to_rad(Tuning.num("missile/turn_rate_deg_per_sec")) * delta

	# Stick input is a rate; mouse input is a displacement. Both are capped by the
	# same turn rate, so the two devices cannot differ in what they can ask for.
	var step := Vector2(
		-stick.x * Tuning.num("controls/stick_sensitivity") * max_step,
		-stick.y * Tuning.num("controls/stick_sensitivity") * max_step,
	)
	step += Vector2(
		-_pending_steer.x * deg_to_rad(Tuning.num("controls/mouse_sensitivity")),
		-_pending_steer.y * deg_to_rad(Tuning.num("controls/mouse_sensitivity")),
	)
	_pending_steer = Vector2.ZERO

	if step.length() > max_step:
		step = step.normalized() * max_step
	basis = FlightGeometry.steer_basis(basis, step.x, step.y)


## Mouse motion arrives as events, not as a polled axis; the view controller feeds
## it here so the missile stays the only thing that decides how input becomes turn.
func add_mouse_steer(relative: Vector2) -> void:
	_pending_steer += relative


func _finish(reason: EndReason, hit: bool) -> void:
	if _finished:
		return
	_finished = true
	piloted = false
	detonated.emit(self, reason, hit)
	queue_free()


# --- readouts ----------------------------------------------------------------

func fuse_remaining() -> float:
	return maxf(_fuse_left, 0.0)


func speed() -> float:
	return _speed


func distance_to_target() -> float:
	return 0.0 if _target == null else position.distance_to(_target.position) - _target_radius
