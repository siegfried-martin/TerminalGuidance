class_name HexLattice
extends RefCounted
## The triangular lattice the road is authored on. Pure — no scene tree, no tuning,
## no disk. Construct one from `lattice_cell_metres` and `lattice_level_metres`.
##
## Every road is a polyline whose vertices are lattice cells, and **every vector
## between two cells is a lattice vector**, so every edge direction is legal and a
## long edge points as finely as anyone wants (ADR 0095). That is the whole reason
## this file exists: it makes "a direction change" an exact integer fact rather than
## a fitted curve, and the joint at a vertex the only computed geometry on the road.
##
## Axial coordinates `(q, r)` as a `Vector2i`, so a cell is exact and stays exact
## under re-authoring. In Godot's frame (-Z forward, +Y up, +X east):
##
##     e1 = (s, 0, 0)              bearing 90 deg, due east
##     e2 = (s/2, 0, -s*sqrt3/2)   bearing 30 deg
##
## and `cell (q, r)` sits at `q*e1 + r*e2`. LEVELS are the vertical axis and do not
## rotate: level `n` is `y = n * level_metres`, level 0 being the combat plane.

## Half the height of an equilateral triangle of side 1 — the `-Z` reach of `e2`.
const ROOT3_OVER_2 := 0.8660254037844386

## The six unit steps, in order, each 60 degrees clockwise from the last starting at
## `e1`. `(1, -1)` is a unit vector too: its length is sqrt(1 - 1 + 1).
const STEPS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1),
]

## How far a world point may sit from a cell centre and still be called that cell,
## for `is_lattice_vector`. Infrastructure, not feel: it exists to absorb float
## error in a value that ought to be exact, not to let a near-miss pass.
const SNAP_TOLERANCE_METRES := 0.05

var cell_metres: float = 600.0
var level_metres: float = 120.0


func _init(cell_size: float, level_size: float) -> void:
	cell_metres = cell_size
	level_metres = level_size


## The world position of a cell at a level.
func to_world(cell: Vector2i, level: int) -> Vector3:
	return Vector3(
		cell_metres * (float(cell.x) + float(cell.y) * 0.5),
		level_metres * float(level),
		-cell_metres * float(cell.y) * ROOT3_OVER_2)


## The world OFFSET of a lattice vector — the same arithmetic, named for the case
## where the argument is a difference of two cells rather than a place.
func offset_of(cell: Vector2i) -> Vector3:
	return to_world(cell, 0)


## The nearest cell to a world point, ignoring its height.
##
## CUBE ROUNDING, not `round()` on each axis. The axial basis is not orthogonal, so
## rounding q and r independently picks the wrong cell near a boundary — the classic
## hex bug. Round all three cube coordinates, then correct whichever one moved
## furthest, which restores `x + y + z = 0` by giving up the least accurate axis.
func from_world(point: Vector3) -> Vector2i:
	var r := -point.z / (cell_metres * ROOT3_OVER_2)
	var q := point.x / cell_metres - r * 0.5
	var cube_x := q
	var cube_z := r
	var cube_y := -cube_x - cube_z
	var rx := roundf(cube_x)
	var ry := roundf(cube_y)
	var rz := roundf(cube_z)
	var dx := absf(rx - cube_x)
	var dy := absf(ry - cube_y)
	var dz := absf(rz - cube_z)
	if dx > dy and dx > dz:
		rx = -ry - rz
	elif dy > dz:
		ry = -rx - rz
	else:
		rz = -rx - ry
	return Vector2i(int(rx), int(rz))


## The nearest level to a world point.
func level_from_world(point: Vector3) -> int:
	return int(roundf(point.y / level_metres))


## Whether a world offset is a lattice vector — that is, whether it joins two cells.
## The height is ignored; a level is checked separately because it is a different
## axis with a different step.
func is_lattice_vector(offset: Vector3) -> bool:
	var cell := from_world(offset)
	var flat := Vector3(offset.x, 0.0, offset.z)
	return flat.distance_to(offset_of(cell)) <= SNAP_TOLERANCE_METRES


## The length of a lattice vector, in metres. Exact: `s * sqrt(a^2 + ab + b^2)`.
func length_of(cell: Vector2i) -> float:
	return cell_metres * sqrt(cells_of(cell))


## The squared length of a lattice vector in CELLS, which is always an integer.
static func cells_of(cell: Vector2i) -> int:
	return cell.x * cell.x + cell.x * cell.y + cell.y * cell.y


## The compass bearing of a lattice vector: 0 is -Z, counting clockwise, matching
## `SystemDisc.bearing_to_direction` so a bearing means one thing across the project.
func bearing_of(cell: Vector2i) -> float:
	var world := offset_of(cell)
	return fposmod(rad_to_deg(atan2(world.x, -world.z)), 360.0)


## The six cells one step away.
func neighbours(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for step in STEPS:
		out.append(cell + step)
	return out


## A lattice vector turned by `steps * 60` degrees about the vertical.
##
## `(q, r) -> (-r, q + r)` is +60 degrees and it is EXACT — a rotation of the lattice
## onto itself, with no float in it. That is what lets a junction tile's socket, which
## is authored as a cell offset for an east-pointing edge, be placed on an edge
## running at 60 or 120 degrees and still land on a cell (ADR 0095, plan section 6.2).
static func rotate60(cell: Vector2i, steps: int) -> Vector2i:
	var turned := cell
	for _i in posmod(steps, 6):
		turned = Vector2i(-turned.y, turned.x + turned.y)
	return turned


## Which multiple of 60 degrees takes `from` onto `to`, or -1 if none does.
##
## This is how a junction is matched to the edge it sits on: a tile authored for a
## `(n, 0)` edge may be placed on any edge that is a 60-degree rotation of its
## footprint, and on no other.
static func rotation_between(from: Vector2i, to: Vector2i) -> int:
	for steps in 6:
		if rotate60(from, steps) == to:
			return steps
	return -1


## Whether a lattice vector points along one of the six `(n, 0)` directions — the
## family junction tiles are generated for. `(n, 0)` and its five rotations.
static func is_axial_family(cell: Vector2i) -> bool:
	return cell.x == 0 or cell.y == 0 or cell.x + cell.y == 0
