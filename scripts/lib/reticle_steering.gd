class_name ReticleSteering
extends RefCounted
## Two-stage steering: input moves a reticle, the nose turns towards it at a
## bounded rate. Extracted from Missile so the mothership's manual flight uses the
## same instrument rather than a second, subtly different one (ADR 0040).
##
## The two stages are the whole point (ADR 0035). Input is never rate-limited —
## the reticle goes where it is pushed, instantly, so the control never feels
## laggy. The *vehicle* is rate-limited, so it has weight. Collapsing them into
## one turn rate is the thing this design rejects.
##
## Pure of tuning and of the scene tree: every rate is an argument, so a caller
## can be stepped by hand in a headless test and both vehicles can carry their own
## numbers. It holds mouse deltas because those arrive as events between frames
## and have to accumulate somewhere.

## The intended direction, in the caller's parent frame — never world space, so a
## floating-origin recentre leaves it valid (ADR 0020).
var aim_basis: Basis = Basis.IDENTITY

var _pending_mouse: Vector2 = Vector2.ZERO


## Park the reticle on the nose. Call this whenever the vehicle's heading changes
## for a reason that was not steering — a launch, or autopilot handing control
## back — so the first frame of control is not a snap to a stale reticle.
func reset(nose: Basis) -> void:
	aim_basis = nose.orthonormalized()
	_pending_mouse = Vector2.ZERO


## Mouse motion arrives as events, not as a polled axis, so it accumulates here
## and is consumed by the next `update`.
func add_mouse(relative: Vector2) -> void:
	_pending_mouse += relative


## Advance one frame. Returns the vehicle's new nose basis; `aim_basis` is updated
## in place. All rates are per-caller so a missile and a ship can differ.
func update(nose: Basis, stick: Vector2, delta: float, reticle_speed_deg_per_sec: float,
		mouse_degrees_per_pixel: float, turn_rate_deg_per_sec: float,
		max_angle_deg: float) -> Basis:
	# Stage 1: input moves the reticle. Not rate-limited — only the vehicle is.
	var stick_step := deg_to_rad(reticle_speed_deg_per_sec) * delta
	var yaw := -stick.x * stick_step - deg_to_rad(_pending_mouse.x * mouse_degrees_per_pixel)
	var pitch := -stick.y * stick_step - deg_to_rad(_pending_mouse.y * mouse_degrees_per_pixel)
	_pending_mouse = Vector2.ZERO
	aim_basis = FlightGeometry.steer_basis(aim_basis, yaw, pitch)

	# Stage 2: hold the reticle inside a cone around the nose, so it can never be
	# parked somewhere the vehicle has no chance of reaching — a control that lies.
	var forward := -nose.z
	var aim := FlightGeometry.clamp_to_cone(
		-aim_basis.z, forward, deg_to_rad(max_angle_deg))
	aim_basis = FlightGeometry.basis_from_forward(aim)

	# Stage 3: the vehicle turns towards the reticle at its own bounded rate. This
	# is the entire difference between "responsive" and "has mass".
	var max_step := deg_to_rad(turn_rate_deg_per_sec) * delta
	return FlightGeometry.basis_from_forward(
		FlightGeometry.turn_towards(forward, aim, max_step))


## Angle in degrees between a nose and the reticle — the lag the player feels.
func offset_degrees(nose: Basis) -> float:
	return rad_to_deg((-nose.z).angle_to(-aim_basis.z))


## Stick input with a dead zone applied, rescaled past the edge so the first live
## input is a nudge rather than a step change.
static func apply_deadzone(stick: Vector2, deadzone: float) -> Vector2:
	var magnitude := stick.length()
	if magnitude < deadzone:
		return Vector2.ZERO
	if deadzone >= 1.0:
		return stick
	return stick.normalized() * ((magnitude - deadzone) / (1.0 - deadzone))
