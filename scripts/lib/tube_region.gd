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
## It has **no end caps**. A cap would be a wall reported where the tube merely meets
## a disc, and it would put a red glow across the middle of a legal route. Instead
## the tube declares itself inapplicable outside its own span and the disc at that
## end takes over — see `BoundaryRegion`.

## Both in the map's frame. These are the aperture mouths, not the system centres.
var from: Vector3 = Vector3.ZERO
var to: Vector3 = Vector3.ZERO
## Half-width where it meets a rim…
var mouth_radius: float = 0.0
## …tapering over this many metres at each end…
var flare_length: float = 0.0
## …to this, the corridor proper.
var radius: float = 0.0

var name_of: String = "corridor"


func label() -> String:
	return name_of


func length() -> float:
	return from.distance_to(to)


func axis() -> Vector3:
	return unit_or_zero(to - from)


## How far along the tube this point is, from the `from` mouth. Negative behind it.
func along(point: Vector3) -> float:
	return (point - from).dot(axis())


## The tube exists between its mouths and nowhere else.
func applies_to(point: Vector3) -> bool:
	var t := along(point)
	return t >= 0.0 and t <= length()


func constraints(point: Vector3) -> Array[BoundaryConstraint]:
	var t := along(point)
	var off := point - from - axis() * t
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
