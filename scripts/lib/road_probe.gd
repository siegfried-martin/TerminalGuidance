class_name RoadProbe
extends RefCounted
## A scripted pilot for the gate: a hull that flies the road through the SAME
## `RoadCollider` and the same `CruiseLane` the mothership uses, with none of the
## input, camera or HUD around it. Pure — no scene tree, no disk.
##
## It exists because a road is not verified by bounding its geometry; it is verified
## by flying it and asserting what the player is handed (ADR 0096). Every suite in the
## gate that says "the ship never passes through a wall" is this object being flown.

var collider: RoadCollider = RoadCollider.new()
var position: Vector3 = Vector3.ZERO
var basis: Basis = Basis.IDENTITY
var velocity: Vector3 = Vector3.ZERO
var throttle: float = 0.0
## World direction the nose turns toward.
var aim: Vector3 = Vector3.FORWARD
## Half extents: width, height, length.
var half: Vector3 = Vector3(7.0, 4.0, 24.0)
## The frame the pilot flies against: the road under the hull, or its own heading.
var frame: Dictionary = {}
var lane: CruiseLane = null
var time: float = 0.0
## Whether the hull was against a surface last step: the bounce cost is charged on
## the rising edge of contact, as the mothership charges it.
var _contact: bool = false
var turn_rate_deg: float = 34.0
var pitch_limit_deg: float = 7.0
var cruise_speed: float = 250.0
var open_space_speed: float = 80.0
var accel: float = 80.0


func setup(tubes: Array[Tube], roads: Array[Road]) -> void:
	collider.setup(tubes, roads)
	turn_rate_deg = Tuning.num("exploration/cruise_turn_rate_deg_per_sec")
	pitch_limit_deg = Tuning.num("exploration/road_pitch_max_deg")
	cruise_speed = Tuning.num("exploration/cruise_speed")
	open_space_speed = Tuning.num("exploration/taxi_max_speed")
	accel = cruise_speed / maxf(Tuning.num("exploration/cruise_spool_seconds"), 0.1)


func tube() -> Tube:
	return collider.tube


func forward() -> Vector3:
	return -basis.z


func speed() -> float:
	return velocity.length()


## Put the probe at rest on a tube's centre-line, nose along the traffic.
func place(t: Tube, at_t: float) -> void:
	collider.tube = t
	var f := t.travel_frame(at_t)
	position = f["pos"]
	basis = Basis.looking_at(f["fwd"], f["up"])
	aim = f["fwd"]
	velocity = Vector3.ZERO
	throttle = 0.0
	frame = f


func step(dt: float) -> void:
	time += dt
	var here := collider.tube
	if here != null:
		lane = here.sample(position, Vector2(half.x, half.y))
		frame = here.travel_frame(here.local(position)["t"])
		# Inside a junction the lane does not penalise (see `SystemMap`).
		for other in here.neighbours:
			if other.contains(position):
				lane.edge_speed_penalty = 1.0
				break
	else:
		lane = null
		frame = RoadPath.frame_from_tangent(forward())
		frame["pos"] = position
	var up: Vector3 = frame["up"]
	# The nose turns toward the aim at the turn rate.
	var fwd := forward()
	var angle := fwd.angle_to(aim)
	if angle > 1e-4:
		var stepa := minf(angle, deg_to_rad(turn_rate_deg) * dt)
		var axis := fwd.cross(aim)
		if axis.length_squared() < 1e-8:
			axis = up
		fwd = fwd.rotated(axis.normalized(), stepa).normalized()
	var limit := deg_to_rad(pitch_limit_deg if here != null else 60.0)
	var pitch := asin(clampf(fwd.dot(up), -1.0, 1.0))
	if absf(pitch) > limit:
		var horizontal := (fwd - up * fwd.dot(up)).normalized()
		fwd = horizontal * cos(limit) + up * sin(limit) * signf(pitch)
	basis = Basis.looking_at(fwd, up)
	# Speed chases the throttle; the lane's edge lowers the ceiling and pushes back.
	var top := cruise_speed if here != null else open_space_speed
	if lane != null:
		top = lane.top_speed()
	velocity = velocity.move_toward(fwd * throttle * top, accel * dt)
	# The lane's nudge is a velocity for THIS frame, exactly as the mothership adds
	# it, never accumulated into the probe's own.
	var moving := velocity + (lane.push() if lane != null else Vector3.ZERO)
	var next := position + moving * dt
	var held := collider.hold(position, next, moving, basis, half, dt)
	position = held["pos"]
	velocity = (held["vel"] as Vector3) + (held["kick"] as Vector3) \
		- (lane.push() if lane != null else Vector3.ZERO)
	var touching: bool = held["hit"]
	if touching and not _contact:
		var keep := lerpf(1.0, Tuning.num("exploration/structure_bounce_speed_keep"),
			float(held["squareness"]))
		throttle = maxf(Tuning.num("exploration/structure_bounce_throttle_floor"),
			throttle * keep)
	_contact = touching
