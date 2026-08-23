class_name Missile
extends Node3D
## A player-flown missile. Constant forward speed, direct screen-space steering,
## and a fuse that ends the flight whether or not the player got there.
##
## ADR 0002 (fuse-as-range), ADR 0003 (screen-space steering) and ADR 0035
## (reticle steering) govern this file. The fuse is the range limit and the
## difficulty dial. Input moves a *reticle* — an intended direction — and the
## missile turns towards it at a bounded rate, so it has weight without becoming
## a flight model the player has to model in their head.
##
## Floating origin (ADR 0020): all flight and hit-testing is done in the parent's
## frame via `position`, never in world space. The one value carried across frames
## — `_previous_position` — is parent-relative for exactly that reason, so a world
## recentre that moves the parent leaves it valid.

signal detonated(missile: Missile, reason: int, hit: bool)

enum EndReason { FUSE_EXPIRED, IMPACT, EARLY_DETONATE }

var piloted: bool = false

var _speed: float = 0.0
var _fuse_left: float = 0.0
var _previous_position: Vector3
var _aim_basis: Basis = Basis.IDENTITY
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
	_aim_basis = basis
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

	# Step 1: input moves the reticle. The reticle is where the player wants the
	# missile pointed, and it is not rate-limited — only the missile is.
	var stick_step := deg_to_rad(Tuning.num("controls/stick_reticle_speed_deg_per_sec")) * delta
	var yaw := -stick.x * stick_step - deg_to_rad(_pending_steer.x * Tuning.num("controls/mouse_sensitivity"))
	var pitch := -stick.y * stick_step - deg_to_rad(_pending_steer.y * Tuning.num("controls/mouse_sensitivity"))
	_pending_steer = Vector2.ZERO
	_aim_basis = FlightGeometry.steer_basis(_aim_basis, yaw, pitch)

	# Step 2: hold the reticle inside a cone around the nose, so it can never be
	# parked somewhere the missile has no chance of reaching.
	var forward := -basis.z
	var aim := FlightGeometry.clamp_to_cone(
		-_aim_basis.z, forward, deg_to_rad(Tuning.num("missile/reticle_max_angle_deg")))
	_aim_basis = FlightGeometry.basis_from_forward(aim)

	# Step 3: the missile turns towards the reticle at its own bounded rate. This
	# is the whole difference between "responsive" and "has mass".
	var max_step := deg_to_rad(Tuning.num("missile/turn_rate_deg_per_sec")) * delta
	basis = FlightGeometry.basis_from_forward(
		FlightGeometry.turn_towards(forward, aim, max_step))


## Mouse motion arrives as events, not as a polled axis; the view controller feeds
## it here so the missile stays the only thing that decides how input becomes turn.
func add_mouse_steer(relative: Vector2) -> void:
	_pending_steer += relative


## Player-triggered detonation. POC step 5 also brings splash damage; this is the
## abort half of it, so a bad shot can be ended instead of watched.
func detonate_early() -> void:
	_finish(EndReason.EARLY_DETONATE, false)


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


## Where the reticle is pointing, in world space.
##
## `_aim_basis` is parent-relative, like `basis` and `position` — that is the
## floating-origin rule (ADR 0020). Converting here rather than storing a world
## direction keeps it valid across a recentre.
func aim_direction() -> Vector3:
	var parent := get_parent_node_3d()
	var local_aim := -_aim_basis.z
	if parent == null:
		return local_aim.normalized()
	return (parent.global_transform.basis * local_aim).normalized()


## Angle in degrees between the nose and the reticle — the lag the player feels.
func aim_offset_degrees() -> float:
	return rad_to_deg((-basis.z).angle_to(-_aim_basis.z))
