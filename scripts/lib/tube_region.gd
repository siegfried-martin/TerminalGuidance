class_name TubeRegion
extends BoundaryRegion
## The bounded space around a road between two systems, and — the same shape, the
## same code — the funnel through each rim at its ends.
##
## A tube flares at both ends: wide where it meets a rim, tapering to the corridor
## over `flare_length`, so leaving a system is aimed rather than threaded and
## arriving at one opens out (ADR 0062). Off-road travel between systems happens
## inside this, which is what keeps open space a real choice rather than a void with
## no edges (`docs/EXPLORATION_POC_IMPLEMENTATION.md`, success criterion 2).
##
## **The tube follows a path, not an axis.** A leg weaves and undulates now — a
## straight road cannot answer success criterion 1 — and the corridor is the bounded
## space *around* that road, so it has to bend with it. The centre-line is the same
## `RoadPath` the road itself is laid on, which is what stops the two from ever
## disagreeing about where the leg goes.
##
## It has **no end caps**. A cap would be a wall reported where the tube merely meets
## a disc, and it would put a red glow across the middle of a legal route. Instead
## the tube declares itself inapplicable outside its own span and the disc at that
## end takes over — see `BoundaryRegion`.

## The centre-line, in the map's frame, from one aperture mouth to the other.
var path: RoadPath = RoadPath.new()
## Half-width where it meets a rim…
var mouth_radius: float = 0.0
## …tapering over this many metres at each end…
var flare_length: float = 0.0
## …to this, the corridor proper.
var radius: float = 0.0

var name_of: String = "corridor"

## One-entry memo for `closest`. Every question asked of a region is asked at a point,
## and callers ask several in a row about the same one: a single frame runs the
## warning, the outward normal, the speed clamp and the overshoot through here, and
## `applies_to` and `constraints` are always a pair. Walking an eighteen-kilometre
## polyline five times for one point is the difference between a hot reload that is
## instant and one that is not.
var _memo_at: Vector3 = Vector3(INF, INF, INF)
var _memo: Array = []


func _closest(point: Vector3) -> Array:
	if point != _memo_at:
		_memo_at = point
		_memo = path.closest(point)
	return _memo


func label() -> String:
	return name_of


## Lay the tube along a centre-line. The straight case is still a two-point path,
## so nothing has to special-case a leg with no curvature in it.
func follow(line: PackedVector3Array) -> void:
	path.set_points(line)
	_memo_at = Vector3(INF, INF, INF)


func span_between(a: Vector3, b: Vector3) -> void:
	follow(RoadPath.straight(a, b))


func from() -> Vector3:
	return path.start()


func to() -> Vector3:
	return path.finish()


func length() -> float:
	return path.length()


## The direction the tube runs at its start. Kept because callers that place things
## at a mouth want the way in, and a curved tube has no single axis any more.
func axis() -> Vector3:
	return path.tangent_at(0.0)


## How far along the tube this point is, measured ALONG the centre-line.
func along(point: Vector3) -> float:
	return _closest(point)[0]


## The tube exists between its mouths and nowhere else.
##
## `closest` clamps to the ends, so "along is inside the span" is not enough on its
## own: a point a kilometre behind the first mouth also reports zero. The end tests
## are therefore against the end tangents — behind the start, or past the finish, the
## disc at that end is the thing with something to say.
func applies_to(point: Vector3) -> bool:
	if path.is_empty():
		return false
	var span := length()
	var t: float = _closest(point)[0]
	if t <= 0.001:
		return (point - path.start()).dot(path.tangent_at(0.0)) >= 0.0
	if t >= span - 0.001:
		return (point - path.finish()).dot(path.tangent_at(span)) <= 0.0
	return true


func constraints(point: Vector3) -> Array[BoundaryConstraint]:
	var found := _closest(point)
	var t: float = found[0]
	var centre: Vector3 = found[1]
	var off := point - centre
	var list: Array[BoundaryConstraint] = []
	list.append(BoundaryConstraint.new(off.length() - profile(t),
		unit_or_zero(off)))
	return list


## The tube's half-width this far along it: the mouth at each end, the corridor in
## the middle, a taper between.
##
## A tube shorter than its own two flares still tapers rather than snapping — the
## flares meet somewhere above the corridor width and the narrowest point is the
## middle, which is the shape a short on-ramp actually has.
func profile(t: float) -> float:
	if flare_length <= 0.0:
		return radius
	var span := length()
	var from_end := minf(t, span - t)
	if from_end >= flare_length:
		return radius
	return lerpf(mouth_radius, radius,
		clampf(from_end / flare_length, 0.0, 1.0))
