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

## How finely a weaving leg is tessellated. Infrastructure, not feel: fine enough
## that the polyline reads as a curve and that `max_turn_deg_per_metre` measures the
## curve rather than the tessellation.
const WEAVE_SEGMENT_METRES := 250.0

## How finely a fillet's arc is tessellated, and the deflection below which a vertex
## is left alone. Both infrastructure: the first trades polyline length against how
## well `max_turn_deg_per_metre` reads the arc rather than the tessellation, and a
## 30-degree fillet at 900 m wants about six points at this setting.
const FILLET_SEGMENT_METRES := 80.0
## The window `heading_at` averages the direction over. Wide enough that a filleted
## bend reads as a turn rather than as a stack of steps, narrow enough that a straight
## approaching a bend is still straight. Infrastructure, not feel: it smooths the
## POLYLINE, and how sharply the road may turn is `road_fillet_radius`.
const TANGENT_BLEND_METRES := 90.0
const FILLET_MIN_ANGLE_RAD := 0.0005

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


## The direction the road runs at a point, **smoothed across the polyline's own
## vertices**.
##
## `tangent_at` is the segment's raw direction and is piecewise CONSTANT, which is the
## right answer for placing a module and the wrong one for anything that steers: a
## filleted bend is half a dozen segments, so a ship or a berth pointed straight at
## `tangent_at` snaps through the turn in that many discrete jumps. The berth showed it
## first, because a berth is carried exactly along this and has no slew of its own to
## hide it.
##
## A centred difference over `TANGENT_BLEND_METRES` rather than a special case at each
## vertex: on a straight the two samples are on the same segment and the answer is
## exact, at a vertex it blends over a fixed window, and at either end `point_at`
## clamps so the direction is still right. Nothing has to know where the vertices are.
func heading_at(along: float) -> Vector3:
	if is_empty():
		return Vector3.FORWARD
	var half := TANGENT_BLEND_METRES * 0.5
	var behind := point_at(along - half)
	var ahead := point_at(along + half)
	var run := ahead - behind
	return tangent_at(along) if run.length_squared() < 0.000001 else run.normalized()


## The raw direction of the segment at `along`. Piecewise constant — see `heading_at`
## for the one that steers.
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


## The stretch of this path between two distances along it, as its own polyline.
##
## Used to stop a ramp's BUILDING where it enters the building of the road it serves
## (ADR 0088). The lane is never cut — a deck has to run the whole way for the union to
## hand over — so this cuts the shell and nothing else.
##
## The cut points are real vertices at the ends, so the trimmed line starts and ends
## exactly where it was asked to rather than at the nearest tessellation step.
func section(from: float, to: float) -> PackedVector3Array:
	var span := length()
	var head := clampf(minf(from, to), 0.0, span)
	var tail := clampf(maxf(from, to), 0.0, span)
	if is_empty() or tail - head <= 0.001:
		return PackedVector3Array()
	var line := PackedVector3Array([point_at(head)])
	for i in points.size():
		if _milestones[i] > head and _milestones[i] < tail:
			line.append(points[i])
	line.append(point_at(tail))
	return line


## A straight run between two points.
static func straight(from: Vector3, to: Vector3) -> PackedVector3Array:
	return PackedVector3Array([from, to])


## The lane through a chain of vertices, with a **circular arc of `radius` at each
## interior vertex** and a straight between them. The first and last vertex are left
## exactly where they were.
##
## This is the whole of the lattice road's curvature (ADR 0095). The BUILDING is
## straight and hard-cornered — a straight box on a straight segment is watertight,
## which is the case ADR 0094 says a curve can never be — and the lane inside it is
## filleted so the axis the camera and the nose follow turns smoothly. A direction
## change is therefore flyable without the road curving.
##
## The radius is a feel value (`road_fillet_radius`): longer is gentler. It has a
## floor, and the floor is derived rather than tuned — a fillet's turn rate is
## `cruise_speed / radius`, so a radius under `cruise_speed / turn_rate` builds a
## road that out-turns the ship (ADR 0070). The gate asserts it and `RoadNetwork`
## clamps to it, because the human slides this one while flying.
##
## FILLET EACH CARRIAGEWAY'S OWN LINE, never the spine. Filleting the spine at R and
## then offsetting by half the deck separation leaves the inner carriageway at
## R - separation/2, which is a tighter turn than the one the floor was computed for.
## Both lanes get the same R here and both clear the floor.
##
## Where the tangent points would pass an edge's midpoint the radius is reduced for
## that vertex, so two adjacent fillets can never overlap. That is a backstop: the
## gate rejects a route that needs it, with the vertex named.
static func fillet(vertices: PackedVector3Array, radius: float,
		segment_metres: float) -> PackedVector3Array:
	if vertices.size() < 3 or radius <= 0.0:
		return vertices
	var out := PackedVector3Array([vertices[0]])
	for i in range(1, vertices.size() - 1):
		var here := vertices[i]
		var back := here - vertices[i - 1]
		var ahead := vertices[i + 1] - here
		var back_length := back.length()
		var ahead_length := ahead.length()
		if back_length <= 0.001 or ahead_length <= 0.001:
			out.append(here)
			continue
		var leaving := back / back_length
		var arriving := ahead / ahead_length
		# The DEFLECTION, not the interior angle: 0 is straight on.
		var theta := leaving.angle_to(arriving)
		# Straight on needs no arc, and doubling back has no finite one. A route
		# that doubles back is rejected by `RouteSpec.validate` long before here.
		if theta <= FILLET_MIN_ANGLE_RAD or theta >= PI - FILLET_MIN_ANGLE_RAD:
			out.append(here)
			continue
		var half := theta * 0.5
		var tangent := minf(radius * tan(half),
			minf(back_length, ahead_length) * 0.5)
		var effective := tangent / tan(half)
		var entry := here - leaving * tangent
		var exit := here + arriving * tangent
		# The centre is on the interior bisector, at `R / cos(theta/2)` from the
		# vertex. `arriving - leaving` IS that bisector: it is (-leaving) + arriving.
		var centre := here + (arriving - leaving).normalized() * (effective / cos(half))
		var spoke := entry - centre
		var axis := spoke.cross(exit - centre)
		if axis.length_squared() <= 0.000001:
			out.append(here)
			continue
		axis = axis.normalized()
		if out[out.size() - 1].distance_to(entry) > 0.001:
			out.append(entry)
		var steps := maxi(int(ceil(effective * theta / maxf(segment_metres, 1.0))), 2)
		for k in range(1, steps + 1):
			out.append(centre + spoke.rotated(axis, theta * float(k) / float(steps)))
	out.append(vertices[vertices.size() - 1])
	return out


## A ramp: leaves `from` along `from_tangent` and **arrives at `to` along
## `to_tangent`**.
##
## A cubic rather than the quadratic this started as, and the second tangent is the
## whole reason. A quadratic can only be told where to *leave* from; where it
## arrives is whatever falls out, and what fell out was a mouth pointing almost
## square across the mainline — a ramp that dives sideways and down, which is the
## "too steep" the human flew into. A cubic controls both ends, so a ramp leaves the
## road along it, swings out and down, and **arrives at its portal pointing along the
## road again**: the S-curve a freeway ramp actually is.
##
## `tightness` is how much of the along-road run each end spends committed to its own
## tangent. Small holds the road's line longer and then turns harder in the middle;
## large eases out sooner and bends harder at the ends. It is a feel value and lives
## in `tuning.cfg`.
static func ramp(from: Vector3, from_tangent: Vector3, to: Vector3,
		to_tangent: Vector3, tightness: float, segments: int) -> PackedVector3Array:
	var leave := from_tangent.normalized()
	var land := to_tangent.normalized()
	# Measured ALONG the road rather than straight-line, so a ramp that is mostly
	# sideways does not get a control arm long enough to loop back on itself.
	var run := absf((to - from).dot(leave))
	var reach := maxf(run * clampf(tightness, 0.05, 0.95), 0.001)
	var c1 := from + leave * reach
	var c2 := to - land * reach
	var line := PackedVector3Array()
	for i in maxi(segments, 1) + 1:
		var t := float(i) / float(maxi(segments, 1))
		var u := 1.0 - t
		line.append(from * (u * u * u)
			+ c1 * (3.0 * u * u * t)
			+ c2 * (3.0 * u * t * t)
			+ to * (t * t * t))
	return line


## A ROAD-TO-ROAD TURN: leaves `from` along `from_tangent` and arrives at `to` along
## `to_tangent`, the same as `ramp`, but sized for a curve whose point is the change
## of heading rather than the change of place.
##
## The difference is one line and it matters. `ramp` measures its control arms along
## the LEAVING direction, because a ramp to a planet is mostly along the road and
## mostly sideways at the end, and measuring the straight-line chord there would give
## an arm long enough to loop back on itself. An interchange is the other shape: half
## of a fifty-five degree turn is across the leaving direction, so that projection
## under-measures the curve badly, the arms come out short, and the whole turn is
## crammed into the middle. Measured at 52 deg/s against a ship that turns at 34 —
## from a curve whose honest requirement is under 3.
##
## So this one measures the chord. The tightness is clamped harder for the same reason
## `ramp` avoids the chord: past a half the arms are long enough to overshoot.
static func sweep(from: Vector3, from_tangent: Vector3, to: Vector3,
		to_tangent: Vector3, tightness: float, segments: int) -> PackedVector3Array:
	var reach := maxf((to - from).length() * clampf(tightness, 0.05, 0.5), 0.001)
	var c1 := from + from_tangent.normalized() * reach
	var c2 := to - to_tangent.normalized() * reach
	var line := PackedVector3Array()
	for i in maxi(segments, 1) + 1:
		var t := float(i) / float(maxi(segments, 1))
		var u := 1.0 - t
		line.append(from * (u * u * u)
			+ c1 * (3.0 * u * u * t)
			+ c2 * (3.0 * u * t * t)
			+ to * (t * t * t))
	return line


## A leg of the highway: a run of `length` along `forward` that **weaves and
## undulates** instead of going straight.
##
## Success criterion 1 cannot be tested on a straight road — *"a generous clamp on a
## straight road still feels like nothing"* — so the leg is the thing that has to
## curve, not just the ramps. The shape is a sine weave across the bearing and a
## second, slower one in elevation.
##
## Both are wrapped in a `sin(PI u)` envelope, which is what makes this usable as a
## leg at all: value AND slope go to zero at both ends, so the leg leaves one
## aperture and arrives at the next exactly on the bearing, with no kink at either
## mouth. The systems therefore stay where a straight leg put them and the discs stay
## on the combat plane — only the road between them moves.
##
## The amplitudes are derived from ANGLES rather than tuned as distances: a 22 deg
## weave is 22 deg whether the leg is 2.6 km or 18 km, where a 400 m amplitude would
## be a gentle curve on one and a hairpin on the other.
static func weave(from: Vector3, forward: Vector3, length: float,
		curve_deg: float, curve_period: float,
		rise_deg: float, rise_period: float) -> PackedVector3Array:
	var ahead := forward.normalized()
	if length <= 0.001:
		return PackedVector3Array([from, from + ahead])
	var side := ahead.cross(Vector3.UP)
	# A leg running straight up has no "side", and nothing in this map does — but a
	# zero vector here would collapse the whole leg to a point rather than fail.
	side = Vector3.RIGHT if side.length_squared() < 0.000001 else side.normalized()
	var up := side.cross(ahead).normalized()

	var lat_cycles := maxf(round(length / maxf(curve_period, 1.0)), 1.0)
	var rise_cycles := maxf(round(length / maxf(rise_period, 1.0)), 1.0)
	var lat_amp := tan(deg_to_rad(clampf(curve_deg, 0.0, 70.0))) \
		* length / (TAU * lat_cycles)
	var rise_amp := tan(deg_to_rad(clampf(rise_deg, 0.0, 70.0))) \
		* length / (TAU * rise_cycles)

	var steps := maxi(int(ceil(length / WEAVE_SEGMENT_METRES)), 8)
	var line := PackedVector3Array()
	for i in steps + 1:
		var u := float(i) / float(steps)
		var envelope := sin(PI * u)
		line.append(from + ahead * (length * u)
			+ side * (lat_amp * sin(TAU * lat_cycles * u) * envelope)
			+ up * (rise_amp * sin(TAU * rise_cycles * u) * envelope))
	return line


## The tightest bend anywhere on this path, in degrees of heading change per metre.
##
## This is what "too steep" means in a number. Multiplied by the cruise speed it is
## degrees per second the road demands, and the ship's nose is hard-clamped into a
## cone around the road's axis — so a road that turns faster than
## `cruise_turn_rate_deg_per_sec` yanks the nose rather than being flown. The gate
## asserts against exactly that, which is why this lives here rather than in a test.
func max_turn_deg_per_metre() -> float:
	if points.size() < 3:
		return 0.0
	var worst := 0.0
	for i in range(1, points.size() - 1):
		var back := points[i] - points[i - 1]
		var ahead := points[i + 1] - points[i]
		var span := (back.length() + ahead.length()) * 0.5
		if span <= 0.001 or back.length_squared() <= 0.000001 \
				or ahead.length_squared() <= 0.000001:
			continue
		worst = maxf(worst,
			rad_to_deg(back.normalized().angle_to(ahead.normalized())) / span)
	return worst
