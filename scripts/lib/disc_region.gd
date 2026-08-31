class_name DiscRegion
extends BoundaryRegion
## A system: a disc with hard flat faces and a rim that opens only where a road
## attaches (ADR 0011, as amended by ADR 0062).
##
## The height is asymmetric and decomposes rather than coming from a ratio
## (ADR 0061): a combat band around the centre plane, `ceiling` of clearance above
## it *so the ceiling never enters a fight*, and `floor_depth` below, deep enough to
## hold the planet with the hard floor under it.
##
## The funnel out of an aperture is **not** here — it is a `TubeRegion`, the same
## shape as the corridor it becomes. All this region knows is where its rim has
## holes in it.

## Where the disc's centre sits, in the map's frame. Regions carry their own
## placement so a map of several systems is a list rather than a special case.
var center: Vector3 = Vector3.ZERO
var ceiling: float = 0.0
var floor_depth: float = 0.0
var radius: float = 0.0

## Outward bearings where the rim opens, as horizontal unit vectors. Empty means a
## closed rim.
var apertures: Array[Vector3] = []
## Half-width of an opening, measured across the throat rather than along the rim —
## so a 2200 m mouth in a 3500 m disc opens about a fifth of the rim, not two
## thirds. Constant here: the taper belongs to the tube.
var aperture_radius: float = 0.0

var name_of: String = "system"


func label() -> String:
	return name_of


func constraints(point: Vector3) -> Array[BoundaryConstraint]:
	var local := point - center
	var list: Array[BoundaryConstraint] = []
	list.append(BoundaryConstraint.new(local.y - ceiling, Vector3.UP))
	list.append(BoundaryConstraint.new(-floor_depth - local.y, Vector3.DOWN))
	if not rim_is_open(point):
		var flat := Vector3(local.x, 0.0, local.z)
		list.append(BoundaryConstraint.new(flat.length() - radius,
			unit_or_zero(flat)))
	return list


## Does the rim have a hole where this point would cross it?
##
## The rim mesh is built from this too, so the hole in the picture is the hole in
## the boundary. A wall you can fly through, or a gap you cannot, teaches the player
## to distrust what they are looking at.
func rim_is_open(point: Vector3) -> bool:
	return aperture_at(point) >= 0


## Which aperture's opening this point is lined up with, or -1 for none.
##
## **The hole is a hole in the wall, not a tunnel through space.** Two things follow,
## and getting either wrong makes a disc claim territory it does not own:
##
## - Outside the rim there is no hole to be in. Past `radius` the wall is simply
##   behind you and the disc is bounded by it again; what is out there belongs to
##   the corridor. Without this the disc reports itself unbounded along its own
##   aperture bearing, and being a kilometre past it reads as "still in SYSTEM A".
## - The opening is ANGULAR, measured where it cuts the wall. A point's own distance
##   from the axis is not the test — that would widen the hole for anything deep
##   inside the disc, which is where it matters least and is wrong most.
##
## Being lined up is not the same as being through. What is through the rim is the
## corridor's business.
func aperture_at(point: Vector3) -> int:
	var local := point - center
	var flat := Vector3(local.x, 0.0, local.z)
	var out := flat.length()
	# A hair of slack so a point placed exactly on the rim — which is how the rim
	# mesh asks this question — counts as being in the wall rather than past it.
	if out > radius + 0.001 or out <= 0.001:
		return -1
	var dir := flat / out
	for i in apertures.size():
		var axis: Vector3 = apertures[i]
		var toward := dir.dot(axis)
		if toward <= 0.0:
			continue
		# Where this bearing crosses the wall, how far off the aperture's centre is
		# it? radius * sin of the angle between them.
		if (dir - axis * toward).length() * radius <= aperture_radius:
			return i
	return -1


## Where an aperture's mouth sits, in the map's frame — the point a corridor
## attaches to.
func aperture_mouth(index: int) -> Vector3:
	if index < 0 or index >= apertures.size():
		return center
	return center + apertures[index] * radius
