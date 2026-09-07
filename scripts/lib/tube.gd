class_name Tube
extends RefCounted
## One carriageway's flyable volume: a rectangular section swept along a `RoadPath`,
## offset sideways and vertically from the path's centre-line. Pure — no scene tree,
## no disk; tuning is read by the `Road` that makes it.
##
## **This is the only collision primitive on the road** (ADR 0096). The ship is always
## either inside exactly one tube or in open space. A side of a tube is passable only
## where the point straight through the wall lies inside a NEIGHBOUR tube — which is
## exactly where `RoadMesh` leaves the wall out — so what is drawn and what holds the
## ship cannot disagree.
##
## A tube is also the lane the cruise drive flies: `sample()` hands the ship the same
## `CruiseLane` the old deck did, measured in the tube's travel frame.

var name: String = ""
## The `Road` that owns this tube. Untyped to avoid a reference cycle in the parser.
var road: RefCounted = null
var path: RoadPath
## Lateral and vertical offset of the tube's centre from the path (right positive).
var u0: float = 0.0
var v0: float = 0.0
## Half width and half height of the flyable section.
var hw: float = 120.0
var hh: float = 75.0
## +1 travels along increasing t, -1 against it. The two carriageways of a highway
## are the same path in opposite directions, each on its own right (ADR 0077).
var direction: int = 1
## Where ramps leave and arrive: `{t, kind ("exit" | "entry" | "from" | "merge"),
## label, ramp: Tube}`.
var junctions: Array[Dictionary] = []
## Tubes of OTHER roads whose volume overlaps this one — the ones a wall may open on to.
var neighbours: Array[Tube] = []
var bounds: AABB
## Whether this road may be taken at all. False is a red gate at its mouth: the tube
## stops being listed as an exit and the strip greys it (ADR 0084). It REFUSES rather
## than blocks — a road that could stop the ship would be interdiction (ADR 0014).
var passable: bool = true
## The highway this carriageway belongs to, for the strip ("stay on highway A-377B").
var route_name: String = ""


## Local coordinates of a world point: t along the path, u/v relative to the TUBE
## centre in the path frame (u right, v up), plus the frame at t.
func local(point: Vector3) -> Dictionary:
	var c := path.closest(point)
	c["u"] -= u0
	c["v"] -= v0
	return c


## World position from tube-local (t, u, v).
func world(t: float, u: float, v: float) -> Vector3:
	return path.at(t, u + u0, v + v0)


func t_in_range(t: float, margin := 0.0) -> bool:
	if path.closed:
		return true
	return t >= -margin and t <= path.length + margin


## True when the point is strictly inside the tube, shrunk by `shrink` on every side.
## A negative `shrink` grows it.
func contains(point: Vector3, shrink := 0.0) -> bool:
	if not bounds.has_point(point):
		return false
	var q := path.closest_tuvw(point)
	if not t_in_range(q.x, -shrink):
		return false
	if absf(q.w) > maxf(0.0, -shrink) + 0.05:
		return false
	return absf(q.y - u0) < hw - shrink and absf(q.z - v0) < hh - shrink


func contains_local(l: Dictionary, shrink := 0.0) -> bool:
	if not t_in_range(l["t"], -shrink):
		return false
	# Beyond an open end the closest point clamps, and w is the overshoot.
	if absf(l["w"]) > maxf(0.0, -shrink) + 0.05:
		return false
	return absf(l["u"]) < hw - shrink and absf(l["v"]) < hh - shrink


## The frame traffic flies in at t: `fwd` is the direction this tube's traffic flows,
## `right` is the driver's right.
func travel_frame(t: float) -> Dictionary:
	var f := path.frame(t)
	var fwd: Vector3 = f["fwd"] * direction
	var up: Vector3 = f["up"]
	return {"pos": f["pos"] + f["right"] * u0 + up * v0, "fwd": fwd, "up": up,
		"right": fwd.cross(up), "t": f["t"]}


func centre(t: float) -> Vector3:
	return world(t, 0.0, 0.0)


func is_ramp() -> bool:
	return road != null and road.get("kind") == "ramp"


## Metres of this tube still ahead of `t` in the travel direction. Infinite on a loop.
func remaining(t: float) -> float:
	if path.closed:
		return INF
	return path.length - t if direction == 1 else t


func travelled(t: float) -> float:
	if path.closed:
		return t
	return t if direction == 1 else path.length - t


## The t at this tube's start (in travel terms) and its end.
func start_t() -> float:
	return 0.0 if direction == 1 else path.length


func end_t() -> float:
	return path.length if direction == 1 else 0.0


## Distance along the travel direction from t to the next junction of `kind` (or any
## kind when empty), and the junction itself.
func next_junction(t: float, kind: String = "") -> Dictionary:
	var best := INF
	var found: Dictionary = {}
	for j in junctions:
		if not kind.is_empty() and j["kind"] != kind:
			continue
		var d: float = path.ahead(t, j["t"], direction)
		if d > 1.0 and d < best:
			best = d
			found = j
	return {"distance": best, "junction": found}


func compute_bounds() -> void:
	bounds = path.aabb(sqrt(hw * hw + hh * hh) + absf(u0) + absf(v0) + 5.0)


## The road, sampled where the ship is — everything the ship needs from the lane in one
## object, so the ship never looks the road up (`CruiseLane`).
##
## `clearance` is half the asking ship's own section: the lane is measured against the
## hull rather than against a point (ADR 0068).
func sample(point: Vector3, clearance: Vector2 = Vector2.ZERO) -> CruiseLane:
	var l := local(point)
	var f := travel_frame(l["t"])
	var lane := CruiseLane.new()
	lane.axis = f["fwd"]
	lane.right = f["right"]
	lane.up = f["up"]
	# u is measured to the PATH's right; the driver's right flips with the direction.
	lane.lateral = float(l["u"]) * direction
	lane.vertical = float(l["v"])
	lane.half_width = hw
	lane.half_height = hh
	lane.clearance = clearance
	lane.clearance_cap = Tuning.num("exploration/lane_hull_clearance_cap")
	lane.roundness = Tuning.num("exploration/lane_corner_roundness")
	lane.edge_softness = Tuning.num("exploration/lane_edge_softness")
	lane.base_speed = Tuning.num("exploration/cruise_speed")
	lane.edge_speed_penalty = Tuning.num("exploration/lane_edge_speed_penalty")
	lane.push_accel = Tuning.num("exploration/lane_edge_push_accel")
	lane.clamp_deg = Tuning.num("exploration/cruise_turn_clamp_deg")
	lane.turn_rate_deg = Tuning.num("exploration/cruise_turn_rate_deg_per_sec")
	lane.deck_name = name
	lane.metres_travelled = travelled(l["t"])
	lane.metres_remaining = remaining(l["t"])
	return lane
