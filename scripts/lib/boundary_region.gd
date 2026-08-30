class_name BoundaryRegion
extends RefCounted
## One piece of playable space: a disc, a corridor, later whatever else. Pure — no
## scene tree, no tuning, no disk.
##
## A region's constraints **intersect**: you are inside it only if you are inside
## all of them, so its depth is the deepest one. Regions then **unite** inside a
## `BoundaryField`: you are outside only if you are outside all of them. That pair
## of rules is the entire composition model, and it is what makes a corridor
## continuous with the systems at each end rather than two volumes with a seam.
##
## A region may also declare itself **inapplicable** somewhere, which is different
## from saying you are outside it. A corridor does not exist behind its own mouth,
## and a region that answered there would judge a ship by a tube it has not reached.
## Inapplicable regions are skipped rather than breached — the alternative is an end
## cap, and an end cap is a wall reported where two regions merely meet, which puts
## a red glow in the middle of a legal route.

## Every constraint acting at this point. Override this.
func constraints(_point: Vector3) -> Array[BoundaryConstraint]:
	return []


## Does this region have anything to say about this point at all? Override where
## the region has a limited extent.
func applies_to(_point: Vector3) -> bool:
	return true


## How far outside this region the point is. Negative inside, and an intersection —
## the worst constraint wins.
func depth(point: Vector3) -> float:
	var worst := -INF
	for constraint: BoundaryConstraint in constraints(point):
		worst = maxf(worst, constraint.depth)
	return 0.0 if worst == -INF else worst


## A short name for the HUD and for test failure messages. Override it.
func label() -> String:
	return "region"


static func unit_or_zero(vector: Vector3) -> Vector3:
	return Vector3.ZERO if vector.length_squared() <= 0.000001 \
		else vector.normalized()
