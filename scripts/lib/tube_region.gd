class_name TubeRegion
extends BoundaryRegion
## The bounded space around a centre-line: a corridor between two systems, with the
## funnel through each rim at its ends — and, the same shape, the same code, the
## playable space a road carries with it.
##
## A corridor flares at both ends: wide where it meets a rim, tapering to the corridor
## over `flare_length`, so leaving a system is aimed rather than threaded and arriving
## at one opens out (ADR 0062). Off-road travel between systems happens inside this,
## which is what keeps open space a real choice rather than a void with no edges.
##
## It has **no end caps**. A cap would be a wall reported where the tube merely meets
## a disc, and it would put a red glow across the middle of a legal route. Instead
## the tube declares itself inapplicable outside its own span and the disc at that
## end takes over — see `BoundaryRegion`.

## The centre-line, in the map's frame.
var path: RoadPath = null
## Half-width where it meets a rim…
var mouth_radius: float = 0.0
## …tapering over this many metres at each end…
var flare_length: float = 0.0
## …to this, the corridor proper.
var radius: float = 0.0

var name_of: String = "corridor"

## One-entry memo for `closest`. A single frame asks several questions about the same
## point, and a closest-point query walks every piece of the path.
var _memo_at: Vector3 = Vector3(INF, INF, INF)
var _memo: Dictionary = {}


func _closest(point: Vector3) -> Dictionary:
	if point != _memo_at:
		_memo_at = point
		_memo = path.closest(point)
	return _memo


func label() -> String:
	return name_of


## Lay the tube along a centre-line.
func follow(line: RoadPath) -> void:
	path = line
	_memo_at = Vector3(INF, INF, INF)


func span_between(a: Vector3, b: Vector3) -> void:
	follow(RoadPath.straight(a, b))


func from() -> Vector3:
	return path.start()


func to() -> Vector3:
	return path.finish()


func length() -> float:
	return 0.0 if path == null else path.length


## The direction the tube runs at its start.
func axis() -> Vector3:
	return path.tangent_at(0.0)


## How far along the tube this point is, measured ALONG the centre-line.
func along(point: Vector3) -> float:
	return _closest(point)["t"]


## The tube exists between its mouths and nowhere else. Behind the start, or past
## the finish, the disc at that end is the thing with something to say.
func applies_to(point: Vector3) -> bool:
	if path == null or path.is_empty():
		return false
	if path.closed:
		return true
	var span := length()
	var t: float = _closest(point)["t"]
	if t <= 0.001:
		return (point - path.start()).dot(path.tangent_at(0.0)) >= 0.0
	if t >= span - 0.001:
		return (point - path.finish()).dot(path.tangent_at(span)) <= 0.0
	return true


func constraints(point: Vector3) -> Array[BoundaryConstraint]:
	var found := _closest(point)
	var t: float = found["t"]
	var centre: Vector3 = found["pos"]
	var off := point - centre
	var list: Array[BoundaryConstraint] = []
	list.append(BoundaryConstraint.new(off.length() - profile(t), unit_or_zero(off)))
	return list


## The tube's half-width this far along it: the mouth at each end, the corridor in
## the middle, a taper between.
func profile(t: float) -> float:
	if flare_length <= 0.0 or path.closed:
		return radius
	var span := length()
	var from_end := minf(t, span - t)
	if from_end >= flare_length:
		return radius
	return lerpf(mouth_radius, radius, clampf(from_end / flare_length, 0.0, 1.0))
