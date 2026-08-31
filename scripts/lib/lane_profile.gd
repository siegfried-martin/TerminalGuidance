class_name LaneProfile
## How wide a road is at a point along it. Pure — no scene tree, no tuning, no disk.
##
## Full through the middle, narrowing to the portal's own opening at whichever end
## carries one: a freeway on-ramp is narrower than the road it feeds, and the flare
## is what makes entry a piloting act rather than a formality. An end with no portal
## does not narrow — the mainline is full width where a ramp merges into it.
##
## Extracted from `RoadDeck` when the structure was split out of the deck (ADR 0078).
## The lane and the building around it are two objects now and they must agree about
## where the road narrows, so the arithmetic lives in one place rather than being
## written twice and drifting.


## The half-extents at `along`, given the road's own `length`.
##
## `flare` is the distance over which the mouth opens out to the full section. Zero
## or less means no flare at all, and the road is full width to its very end.
static func extents(along: float, length: float, full: Vector2, mouth: Vector2,
		flare: float, narrows_at_start: bool, narrows_at_end: bool) -> Vector2:
	if flare <= 0.0:
		return full
	var from_end := INF
	if narrows_at_start:
		from_end = minf(from_end, along)
	if narrows_at_end:
		from_end = minf(from_end, length - along)
	if from_end >= flare:
		return full
	return mouth.lerp(full, clampf(from_end / flare, 0.0, 1.0))
