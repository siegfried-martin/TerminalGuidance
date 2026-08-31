class_name BoundaryField
extends RefCounted
## The edge of the playable volume: a **union of regions**, each a list of
## constraints. Pure — no scene tree, no tuning, no disk.
##
## Each constraint reports two things at a point: how far past it you are, and which
## way is out. Everything below reads those two numbers and never knows what shape
## produced them, which is what lets one system, two systems joined by a corridor,
## and the whole-map boundary that comes later be *different region lists rather
## than different code* (ADR 0062).
##
##     within a region   constraints INTERSECT — you are inside only if inside all
##     between regions   regions UNITE — you are outside only if outside all
##
## Corners then fall out of the arithmetic instead of being written. Past both the
## ceiling and the rim, the combined outward normal is the diagonal, so
## down-and-inward is cheapest and up-and-out is stopped, with no case for it. And
## a corridor is continuous with the systems at its ends rather than having a seam:
## crossing a rim through its mouth, the disc's faces hand over to the tube wall
## without either ever being breached.

## The playable space, as pieces. Order does not matter; the shallowest wins.
var regions: Array[BoundaryRegion] = []

## Metres INSIDE the edge over which the volume reddens. Telegraph only — nothing
## mechanical happens in the warning band.
var warning_band: float = 0.0
## Metres OUTSIDE the edge over which the outbound speed limit ramps to zero. The
## red zone is genuinely outside the good zone, and can be entered.
var stop_distance: float = 1.0


## Which region governs this point: the one it is least outside of. -1 if the field
## is empty or nothing applies here.
func governing(point: Vector3) -> int:
	var best := -1
	var best_depth := INF
	for i in regions.size():
		var region: BoundaryRegion = regions[i]
		if not region.applies_to(point):
			continue
		var depth := region.depth(point)
		if depth < best_depth:
			best_depth = depth
			best = i
	return best


## Every constraint acting at this point — the governing region's.
func constraints(point: Vector3) -> Array[BoundaryConstraint]:
	var index := governing(point)
	return [] if index < 0 else regions[index].constraints(point)


## What the player would call where they are. "outside" when nothing applies, which
## can only happen off the end of the map.
func label(point: Vector3) -> String:
	var index := governing(point)
	return "outside" if index < 0 else regions[index].label()


# --- what the regions add up to ----------------------------------------------

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
	for constraint: BoundaryConstraint in constraints(point):
		if constraint.depth > 0.0:
			sum += constraint.outward * constraint.depth
	return BoundaryRegion.unit_or_zero(sum)


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
	var index := governing(point)
	return INF if index < 0 else regions[index].depth(point)
