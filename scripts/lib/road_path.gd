class_name RoadPath
extends RefCounted
## A road's centre-line, as a polyline. Pure — no scene tree, no tuning, no disk.
##
## A polyline rather than two endpoints, because a road is not a straight line: a
## ramp curves away from the mainline it leaves, and the trunk leg has to curve or
## success criterion 1 cannot be tested at all (*"a generous clamp on a straight road
## still feels like nothing"*). Both are the same shape with different points in it.
##
## Distances are measured ALONG the path, not through it. A ship a third of the way
## round a curve is a third of the way along the road, which is the only reading that
## makes "how much further" mean anything.

var points: PackedVector3Array = PackedVector3Array()
## Cumulative distance to each point, so `length` and `point_at` are lookups rather
## than walks. Rebuilt whenever the points change.
var _milestones: PackedFloat32Array = PackedFloat32Array()


func set_points(line: PackedVector3Array) -> void:
	points = line
	_milestones = PackedFloat32Array()
	var run := 0.0
	_milestones.append(0.0)
	for i in range(1, points.size()):
		run += points[i - 1].distance_to(points[i])
		_milestones.append(run)


func length() -> float:
	return 0.0 if _milestones.is_empty() else _milestones[_milestones.size() - 1]


func is_empty() -> bool:
	return points.size() < 2


## The closest point on the path, as `[along, centre, tangent]`.
##
## Every segment is tested rather than the nearest vertex found first: a long
## straight next to a tight curve makes "nearest vertex" pick the wrong segment, and
## the ship is then told it is off a road it is flying down the middle of.
func closest(query: Vector3) -> Array:
	if is_empty():
		return [0.0, query, Vector3.FORWARD]
	var best_distance := INF
	var best_along := 0.0
	var best_centre := points[0]
	var best_tangent := Vector3.FORWARD
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		var run := b - a
		var span := run.length()
		if span <= 0.0001:
			continue
		var direction := run / span
		var travelled := clampf((query - a).dot(direction), 0.0, span)
		var on_line := a + direction * travelled
		var distance := query.distance_squared_to(on_line)
		if distance < best_distance:
			best_distance = distance
			best_along = _milestones[i - 1] + travelled
			best_centre = on_line
			best_tangent = direction
	return [best_along, best_centre, best_tangent]


func point_at(along: float) -> Vector3:
	if is_empty():
		return Vector3.ZERO
	var wanted := clampf(along, 0.0, length())
	for i in range(1, points.size()):
		if wanted <= _milestones[i]:
			var span := _milestones[i] - _milestones[i - 1]
			if span <= 0.0001:
				return points[i]
			return points[i - 1].lerp(points[i],
				(wanted - _milestones[i - 1]) / span)
	return points[points.size() - 1]


func tangent_at(along: float) -> Vector3:
	if is_empty():
		return Vector3.FORWARD
	var wanted := clampf(along, 0.0, length())
	for i in range(1, points.size()):
		if wanted <= _milestones[i]:
			return (points[i] - points[i - 1]).normalized()
	return (points[points.size() - 1] - points[points.size() - 2]).normalized()


func start() -> Vector3:
	return Vector3.ZERO if points.is_empty() else points[0]


func finish() -> Vector3:
	return Vector3.ZERO if points.is_empty() else points[points.size() - 1]


## A straight run between two points.
static func straight(from: Vector3, to: Vector3) -> PackedVector3Array:
	return PackedVector3Array([from, to])


## A curve that leaves `from` along `from_tangent` and arrives at `to`.
##
## A quadratic Bezier, which is enough for a ramp and is the cheapest curve that
## meets the one requirement that matters: it leaves the mainline TANGENTIALLY, so a
## ship steering onto it is not asked for a corner the steering cone cannot turn.
static func ramp(from: Vector3, from_tangent: Vector3, to: Vector3,
		segments: int) -> PackedVector3Array:
	var reach := from.distance_to(to) * 0.55
	var control := from + from_tangent.normalized() * reach
	var line := PackedVector3Array()
	for i in segments + 1:
		var t := float(i) / float(segments)
		var inverse := 1.0 - t
		line.append(from * (inverse * inverse)
			+ control * (2.0 * inverse * t)
			+ to * (t * t))
	return line
