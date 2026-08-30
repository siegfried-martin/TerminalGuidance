class_name BoundaryField
extends RefCounted
## The edge of the playable volume, as a **list of constraints** rather than as a
## set of special cases. Pure — no scene tree, no tuning, no disk.
##
## Each constraint reports two things at a point: how far past it you are, and
## which way is out. Everything else — the red, the strain, the damage timer —
## reads those two numbers and never knows what shape produced them. A system disc
## is one constraint set; the whole-map boundary that comes later is a *different
## set, not different code*. Only `constraints()` knows about geometry.
##
## Corners then fall out of the arithmetic instead of being written. Past both the
## ceiling and the rim, the combined outward normal is the diagonal, so
## down-and-inward is free and up-and-out is stopped, with no case for it.
##
## **The rim is a boundary** (ADR 0062, superseding ADR 0011's open rim). It opens
## only where a road attaches, and that opening is a funnel: wide at the rim,
## narrowing to the corridor, so leaving is aimed rather than threaded.
##
## Replaces `DiscBounds`, which knew only about the two flat faces and whose
## outbound test was a boolean.


## One boundary surface, as felt at one point.
class Constraint:
	## Metres past this surface. Negative inside, zero on it, positive outside.
	var depth: float = 0.0
	## Unit vector pointing out of the good zone, here.
	var outward: Vector3 = Vector3.ZERO

	func _init(past: float, out_dir: Vector3) -> void:
		depth = past
		outward = out_dir


# --- the shape, set by whoever knows it --------------------------------------

## Metres from the combat plane up to the ceiling, and down to the floor. Two
## numbers rather than one half-height: the disc is asymmetric because the planet
## lives under the lower one (ADR 0061).
var ceiling: float = 0.0
var floor_depth: float = 0.0
var radius: float = 0.0

## Metres INSIDE the edge over which the volume reddens. Telegraph only — nothing
## mechanical happens in the warning band.
var warning_band: float = 0.0
## Metres OUTSIDE the edge over which the outbound speed limit ramps to zero. The
## red zone is genuinely outside the good zone, and can be entered.
var stop_distance: float = 1.0

## Outward bearings where the rim opens, as horizontal unit vectors. Empty means a
## closed rim.
var apertures: Array[Vector3] = []
## The funnel's wide end, at the rim.
var aperture_radius: float = 0.0
## …tapering over this many metres outward…
var funnel_length: float = 0.0
## …to this, the corridor the road runs down.
var corridor_radius: float = 0.0


# --- the shape's one shape-aware method --------------------------------------

## Every constraint acting at this point.
##
## The playable volume is a UNION — the disc, plus a funnel out of each aperture —
## so a point is only outside if it is outside all of them, and the one it is least
## outside of is the one that governs. That is what makes the throat continuous with
## the disc instead of two volumes with a seam: crossing the rim through the mouth,
## the disc's faces hand over to the funnel wall without either ever being breached.
##
## Within a region the constraints intersect (deepest wins); between regions they
## unite (shallowest wins). Ceiling, floor and rim are not special cases of each
## other and a corner is not a special case of anything.
func constraints(point: Vector3) -> Array[Constraint]:
	var best := _disc_constraints(point)
	var best_depth := _max_depth(best)
	for i in apertures.size():
		if point.dot(apertures[i]) < radius:
			# The funnel starts at the rim plane. Offering it further back would let
			# a ship above the ceiling near the mouth be judged by a throat it has
			# not reached yet.
			continue
		var alt := _funnel_constraints(point, i)
		var depth := _max_depth(alt)
		if depth < best_depth:
			best = alt
			best_depth = depth
	return best


## The disc itself: two flat faces, and a rim with holes in it.
func _disc_constraints(point: Vector3) -> Array[Constraint]:
	var list: Array[Constraint] = []
	list.append(Constraint.new(point.y - ceiling, Vector3.UP))
	list.append(Constraint.new(-floor_depth - point.y, Vector3.DOWN))
	if not rim_is_open(point):
		var flat := Vector3(point.x, 0.0, point.z)
		list.append(Constraint.new(flat.length() - radius, _unit_or_zero(flat)))
	return list


## One funnel, past the rim plane: a single wall, tapering outward.
func _funnel_constraints(point: Vector3, index: int) -> Array[Constraint]:
	var axis: Vector3 = apertures[index]
	var off := point - axis * point.dot(axis)
	var list: Array[Constraint] = []
	list.append(Constraint.new(off.length() - funnel_radius(point.dot(axis)),
		_unit_or_zero(off)))
	return list


## Does the rim have a hole where this point would cross it?
##
## The mesh is built from this too, so the hole in the picture is the hole in the
## boundary. A wall you can fly through, or a gap you cannot, teaches the player to
## distrust what they are looking at.
func rim_is_open(point: Vector3) -> bool:
	return aperture_at(point) >= 0


## Which aperture's throat this point has actually entered — past the rim plane and
## inside the walls — or -1 for none.
##
## Distinct from `aperture_at`, which only asks whether the point is LINED UP with an
## opening. A ship in the middle of the disc can be lined up with an aperture a
## kilometre away; it is not in the throat, and telling the player it is makes the
## readout useless exactly where it is supposed to help.
func throat_at(point: Vector3) -> int:
	var lined_up := aperture_at(point)
	if lined_up < 0 or point.dot(apertures[lined_up]) < radius:
		return -1
	return lined_up


## Which aperture's opening this point is lined up with, or -1 for none. This is the
## test that decides whether the rim is there — see `rim_is_open`.
func aperture_at(point: Vector3) -> int:
	for i in apertures.size():
		var axis: Vector3 = apertures[i]
		var along := point.dot(axis)
		if along <= 0.0:
			continue
		if (point - axis * along).length() <= funnel_radius(along):
			return i
	return -1


## The throat's half-width this far along an aperture's axis, measured from the
## disc's centre. Constant through the rim, then tapering to the corridor.
func funnel_radius(along: float) -> float:
	if along <= radius or funnel_length <= 0.0:
		return aperture_radius
	return lerpf(aperture_radius, corridor_radius,
		clampf((along - radius) / funnel_length, 0.0, 1.0))


# --- what the shape's constraints add up to ----------------------------------

## How far past the edge this point is, in metres. Zero anywhere inside.
func overshoot(point: Vector3) -> float:
	return maxf(_deepest(point), 0.0)


## Metres to the nearest edge. Negative once past one.
func distance_to_edge(point: Vector3) -> float:
	return -_deepest(point)


## How close to leaving, 0 to 1. Zero while comfortably inside, 1 at the edge and
## anywhere past it.
##
## This is the *telegraph*, and it reaches full BEFORE anything has happened to the
## player — which is the whole of the Bannerlord treatment and the reason it does
## not read as a punishment.
func warning(point: Vector3) -> float:
	var edge := distance_to_edge(point)
	if edge <= 0.0:
		return 1.0
	if warning_band <= 0.0:
		return 0.0
	return clampf(1.0 - edge / warning_band, 0.0, 1.0)


## Which way is out, here — every breached constraint's normal, weighted by how far
## past it the point is. Zero while inside.
##
## The weighting is what makes corners work: a metre past the ceiling and two
## hundred past the rim points almost straight out sideways, which is the honest
## answer about where the player actually is.
func outward(point: Vector3) -> Vector3:
	var sum := Vector3.ZERO
	for constraint: Constraint in constraints(point):
		if constraint.depth > 0.0:
			sum += constraint.outward * constraint.depth
	return _unit_or_zero(sum)


## What to multiply the ship's SPEED LIMIT by, given where it is and where it is
## going.
##
##     outbound = (1 + cos t) / 2        ; = cos²(t/2), t from the outward normal
##     reach    = clamp(metres past the edge / stop_distance, 0, 1)
##     scale    = 1 - reach * outbound
##
## `cos²(t/2)` is 1 straight out, **0.5 tangential**, 0 straight back in. So
## tangential travel in the red zone is slowed but not stopped, a ship that keeps
## pushing outward arrives at zero and must turn, and **the way home is never taxed
## at any depth**. The boundary stops you by making outward cost everything, never
## by taking the stick.
##
## Returning a scale rather than a modified vector is what makes ADR 0011's
## *"magnitude only, never direction"* structural instead of promised: there is no
## code path here that can turn the player's ship, because nothing here ever
## returns a heading.
func speed_ceiling_scale(point: Vector3, heading: Vector3) -> float:
	var past := overshoot(point)
	if past <= 0.0 or stop_distance <= 0.0:
		return 1.0
	var out := outward(point)
	if out == Vector3.ZERO:
		return 1.0
	var reach := clampf(past / stop_distance, 0.0, 1.0)
	return clampf(1.0 - reach * outbound_fraction(heading, out), 0.0, 1.0)


## How much of this heading is "out", 0 to 1. See `speed_ceiling_scale`.
static func outbound_fraction(heading: Vector3, outward_dir: Vector3) -> float:
	if heading.length_squared() <= 0.0 or outward_dir.length_squared() <= 0.0:
		return 0.0
	return clampf(
		(1.0 + heading.normalized().dot(outward_dir.normalized())) * 0.5, 0.0, 1.0)


## Damage per second at this point in an excursion, given how long the ship has
## been outside.
##
## Two stages, because a telegraph that hurts is not a telegraph: `grace` seconds
## pass with nothing but the red and the strain, and only then does damage begin
## and ramp over `ramp` more. A brief dip is a legitimate tactical option and costs
## nothing; camping out there does not work. That is the pressure rule holding —
## the player chose it, saw it coming, and can still turn round.
static func damage_per_second(seconds_outside: float, grace: float, ramp: float,
		full_rate: float) -> float:
	if seconds_outside <= grace:
		return 0.0
	if ramp <= 0.0:
		return full_rate
	return full_rate * clampf((seconds_outside - grace) / ramp, 0.0, 1.0)


func _deepest(point: Vector3) -> float:
	return _max_depth(constraints(point))


## How far outside a region is: its deepest breached constraint. An intersection,
## so the worst one wins — you are inside a region only if you are inside all of it.
func _max_depth(list: Array[Constraint]) -> float:
	var worst := -INF
	for constraint: Constraint in list:
		worst = maxf(worst, constraint.depth)
	return 0.0 if worst == -INF else worst


func _unit_or_zero(vector: Vector3) -> Vector3:
	return Vector3.ZERO if vector.length_squared() <= 0.000001 \
		else vector.normalized()
