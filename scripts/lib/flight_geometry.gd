class_name FlightGeometry
extends RefCounted
## Pure geometry helpers. Static, no scene tree, no engine state — so they are
## directly testable headlessly and cheap to reason about.

## Does the swept segment a→b pass within `radius` of `center`?
##
## A missile moving 55 m/s at 60 fps covers ~0.9 m per frame, and a boosted one
## considerably more; a per-frame distance check would tunnel straight through a
## small target. Testing the whole segment is both correct and closer to what a
## proximity fuse physically does.
##
## Positions must be expressed in a common frame. Use parent-relative coordinates
## (see the floating-origin invariant in CLAUDE.md) — a world recentre moves the
## shared parent, so relative positions stay valid across the shift.
static func segment_hits_sphere(a: Vector3, b: Vector3, center: Vector3, radius: float) -> bool:
	return segment_distance_to_point(a, b, center) <= radius


## Does the swept segment a→b enter the ellipsoid at `center`, oriented by the
## orthonormal `orientation` and with semi-axes `radii`?
##
## Solved by mapping into the ellipsoid's own frame and dividing out the radii,
## which turns it into the unit-sphere test above. That map is affine, so it
## preserves whether the segment and the surface intersect — the answer is exact,
## not an approximation, even though distances inside the mapped frame are not
## real metres.
##
## `orientation` must be orthonormal; its inverse is taken as its transpose.
static func segment_hits_ellipsoid(a: Vector3, b: Vector3, center: Vector3,
		orientation: Basis, radii: Vector3) -> bool:
	if radii.x <= 0.0 or radii.y <= 0.0 or radii.z <= 0.0:
		return false
	var to_local := orientation.transposed()
	var local_a := (to_local * (a - center)) / radii
	var local_b := (to_local * (b - center)) / radii
	return segment_distance_to_point(local_a, local_b, Vector3.ZERO) <= 1.0


## Where along the swept segment a→b does it first enter the ellipsoid? Returns
## the parameter t in 0..1, or -1 for a clean miss.
##
## Same affine trick as `segment_hits_ellipsoid`, and the parameter survives it:
## the map into the ellipsoid's frame is linear in t, so a point at t in the mapped
## frame is the point at t in the real one. The distances in there are not metres;
## the parameter is exact.
static func segment_ellipsoid_entry(a: Vector3, b: Vector3, center: Vector3,
		orientation: Basis, radii: Vector3) -> float:
	if radii.x <= 0.0 or radii.y <= 0.0 or radii.z <= 0.0:
		return -1.0
	var to_local := orientation.transposed()
	var local_a := (to_local * (a - center)) / radii
	var local_b := (to_local * (b - center)) / radii
	return segment_sphere_entry(local_a, local_b, Vector3.ZERO, 1.0)


## Where along the swept segment a→b does it first enter the sphere? Returns the
## parameter t in 0..1, or -1 for a clean miss. t = 0 means it started inside.
##
## `segment_hits_sphere` answers *whether*; this answers *where*, which is what a
## target made of several hittable parts needs — the part the segment reaches
## first is the one that was aimed at, and "first" is not a question a boolean can
## answer (ADR 0043).
static func segment_sphere_entry(a: Vector3, b: Vector3, center: Vector3, radius: float) -> float:
	var direction := b - a
	var offset := a - center
	var length_sq := direction.length_squared()
	if length_sq < 0.000001:
		return 0.0 if offset.length() <= radius else -1.0
	var outside := offset.length_squared() - radius * radius
	if outside <= 0.0:
		return 0.0
	var half_b := offset.dot(direction)
	var discriminant := half_b * half_b - length_sq * outside
	if discriminant < 0.0:
		return -1.0
	var t := (-half_b - sqrt(discriminant)) / length_sq
	return t if t >= 0.0 and t <= 1.0 else -1.0


## Same question for an oriented box: the slab method, which is exact rather than
## an approximation, and gives the entry parameter for free.
##
## `orientation` must be orthonormal; its inverse is taken as its transpose.
static func segment_box_entry(a: Vector3, b: Vector3, center: Vector3,
		orientation: Basis, half_extents: Vector3) -> float:
	var to_local := orientation.transposed()
	var local_a := to_local * (a - center)
	var direction := to_local * (b - a)
	var t_min := 0.0
	var t_max := 1.0
	for axis in 3:
		var half: float = half_extents[axis]
		var origin: float = local_a[axis]
		var step: float = direction[axis]
		if absf(step) < 0.000001:
			# Parallel to this pair of faces: either between them for the whole
			# segment, or outside them for the whole segment.
			if origin < -half or origin > half:
				return -1.0
			continue
		var near := (-half - origin) / step
		var far := (half - origin) / step
		if near > far:
			var swap := near
			near = far
			far = swap
		t_min = maxf(t_min, near)
		t_max = minf(t_max, far)
		if t_min > t_max:
			return -1.0
	return t_min


## Shortest distance from `point` to the segment a→b.
static func segment_distance_to_point(a: Vector3, b: Vector3, point: Vector3) -> float:
	var ab := b - a
	var length_sq := ab.length_squared()
	if length_sq < 0.000001:
		return a.distance_to(point)
	var t := clampf((point - a).dot(ab) / length_sq, 0.0, 1.0)
	return (a + ab * t).distance_to(point)


## Rotate `basis` by yaw/pitch expressed in its own frame, keeping roll out of it.
##
## Screen-space steering (ADR 0003): the stick points, the missile goes there. Roll
## is deliberately never accumulated — a rolling missile makes "up" ambiguous and
## turns direct steering into a flight model, which is the thing that decision
## rejects.
static func steer_basis(basis: Basis, yaw_rad: float, pitch_rad: float) -> Basis:
	var rotated := basis.rotated(basis.y.normalized(), yaw_rad)
	rotated = rotated.rotated(rotated.x.normalized(), pitch_rad)
	return _level_roll(rotated.orthonormalized())


## A roll-free basis looking along `forward`. Same handedness rule as _level_roll:
## `forward × up` gives right, `right × forward` gives up. Reversing either
## produces a mirrored basis, which reads on screen as inverted steering.
static func basis_from_forward(forward: Vector3) -> Basis:
	var f := forward.normalized()
	if f.length_squared() < 0.5:
		return Basis.IDENTITY
	# Straight up or down leaves world up useless as a reference; pick another.
	var up_reference := Vector3.UP if absf(f.dot(Vector3.UP)) < 0.9995 else Vector3.FORWARD
	var right := f.cross(up_reference).normalized()
	var up := right.cross(f).normalized()
	return Basis(right, up, -f)


## Turn `from` towards `to` by at most `max_radians`.
static func turn_towards(from: Vector3, to: Vector3, max_radians: float) -> Vector3:
	var a := from.normalized()
	var b := to.normalized()
	var angle := a.angle_to(b)
	if angle <= max_radians or angle < 0.000001:
		return b
	return a.slerp(b, max_radians / angle)


## Clamp `direction` to lie within `max_radians` of `axis`.
static func clamp_to_cone(direction: Vector3, axis: Vector3, max_radians: float) -> Vector3:
	return turn_towards(axis, direction, max_radians)


## Re-derive right/up from forward and world up, so roll stays at zero.
static func _level_roll(basis: Basis) -> Basis:
	var forward := -basis.z.normalized()
	# Straight up or straight down: world up gives no usable reference, so keep the
	# basis we were handed rather than snapping the missile's horizon.
	if absf(forward.dot(Vector3.UP)) > 0.9995:
		return basis
	# Order matters: `forward × up` gives right, and `right × forward` gives up.
	# Reversing either cross product yields a mirrored, left-handed basis
	# (determinant -1), which reads on screen as inverted steering.
	var right := forward.cross(Vector3.UP).normalized()
	var up := right.cross(forward).normalized()
	return Basis(right, up, -forward)
