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
