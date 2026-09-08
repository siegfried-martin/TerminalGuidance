class_name RoadCollider
extends RefCounted
## The road's collision, for one hull. Pure — no scene tree, no disk. Tuning is read
## for the restitution only.
##
## **The hull is always in exactly one `Tube` or in open space.** Inside a tube its
## centre is kept within the section shrunk by the hull's own extents; a side is
## passable only where the point straight through the wall lies inside a NEIGHBOUR
## tube, which is exactly where `RoadMesh` left the wall out. Outside every tube the
## hull bounces off the road's exterior, and an open end is a mouth it may fly in by.
##
## **It bounces** (ADR 0090). Speed into a face comes back out of it scaled by
## `structure_bounce_restitution`; speed along the face is untouched, so a glancing
## hit deflects and a hull flying beside a wall is never slowed by it. What a hit costs
## the throttle is the ship's business — `hold()` reports how square the hit was.
##
## One object per hull, kept across frames, because "which tube am I in" is a fact
## about the hull that geometry updates rather than re-derives: a hull that has just
## crossed an open wall is in the tube on the far side of it and nowhere else.

## "Strictly inside" tolerance for the open-wall rule, in metres. `RoadMesh` clips
## with the same number, so the rule has exactly one definition.
const OPEN_EPS := 0.25

var tubes: Array[Tube] = []
var roads: Array[Road] = []
## The tube the hull is in, or null in open space.
var tube: Tube = null
## What the last step did, for the HUD and for tests.
var last_contact: Dictionary = {"wall": "-", "squareness": 0.0, "age": INF}
var log_lines: PackedStringArray = []


func setup(all_tubes: Array[Tube], all_roads: Array[Road]) -> void:
	tubes = all_tubes
	roads = all_roads
	tube = null


## Which tube contains a world point, checking `candidates` in order, or null.
static func tube_containing(point: Vector3, candidates: Array) -> Tube:
	for t: Tube in candidates:
		if t.contains(point):
			return t
	return null


## Put the hull where it is allowed to be after moving from `prev` to `next`.
##
## `basis` and `half` are the hull's orientation and half-extents (width, height,
## length), so the SIDE of the hull meets the wall rather than its centre (ADR 0068).
## Returns `{pos, vel, kick, hit, into_wall, squareness, wall}`: the held position,
## the velocity with the component through each struck face removed, the rebound
## (that component scaled by the restitution, coming back out), and what the surface
## absorbed. `tube` is updated to wherever the hull now is.
func hold(prev: Vector3, next: Vector3, velocity: Vector3, basis: Basis,
		half: Vector3, delta: float) -> Dictionary:
	last_contact["age"] = float(last_contact["age"]) + delta
	var result := {"pos": next, "vel": velocity, "kick": Vector3.ZERO, "hit": false,
		"into_wall": 0.0, "squareness": 0.0, "wall": "-"}
	if tube != null:
		_collide_inside(next, basis, half, result)
	else:
		_collide_outside(prev, next, basis, half, result)
	return result


## Half-size of the oriented hull box along a direction.
static func extent(basis: Basis, half: Vector3, dir: Vector3) -> float:
	return half.x * absf(dir.dot(basis.x)) + half.y * absf(dir.dot(basis.y)) \
		+ half.z * absf(dir.dot(basis.z))


func _hit(result: Dictionary, n: Vector3, wall: String) -> void:
	var vel: Vector3 = result["vel"]
	var vn := vel.dot(n)
	if vn >= 0.0:
		return
	var speed := vel.length()
	var squareness := -vn / speed if speed > 1e-3 else 1.0
	var restitution := clampf(Tuning.num("exploration/structure_bounce_restitution"), 0.0, 1.0)
	# The component THROUGH the face is removed from the velocity; what comes back
	# out of it is the kick, handed back on its own so the caller can carry it.
	result["vel"] = vel - vn * n
	result["kick"] = (result["kick"] as Vector3) - restitution * vn * n
	result["into_wall"] = float(result["into_wall"]) - vn
	result["squareness"] = maxf(float(result["squareness"]), squareness)
	if not result["hit"]:
		result["wall"] = wall
	result["hit"] = true
	last_contact = {"wall": wall, "squareness": squareness, "age": 0.0}
	_log("hit %s, squareness %.2f" % [wall, squareness])


## Name a side of the tube from the pilot's seat. `side` is in the PATH frame.
func _wall_name(side: String) -> String:
	if side == "+v":
		return "roof"
	if side == "-v":
		return "floor"
	var travel_right := (side == "+u") == (tube.direction == 1)
	if travel_right:
		return "right wall"
	return "median" if tube.road.get("tubes").size() == 2 else "left wall"


## Is the wall open here — is the point just through it inside a neighbouring tube?
## Remembers which tube opened it, because that tube is where a hull going through
## the opening is, whatever else the far point happens to lie in.
var _opener: Tube = null

func _open_at(p: Vector3) -> bool:
	for n in tube.neighbours:
		if tube.sealed.has(n):
			continue
		if n.contains(p, OPEN_EPS):
			_opener = n
			return true
	return false


func _collide_inside(next: Vector3, basis: Basis, half: Vector3, result: Dictionary,
		depth: int = 0) -> void:
	_opener = null
	var l := tube.local(next)
	var f: Dictionary = l["frame"]
	var right: Vector3 = f["right"]
	var up: Vector3 = f["up"]
	var t: float = l["t"]
	var u: float = l["u"]
	var v: float = l["v"]
	var umax := tube.hw - extent(basis, half, right)
	var vmax := tube.hh - extent(basis, half, up)
	if u > umax and not _open_at(tube.world(t, tube.hw, v)):
		u = umax
		_hit(result, -right, _wall_name("+u"))
	elif u < -umax and not _open_at(tube.world(t, -tube.hw, v)):
		u = -umax
		_hit(result, right, _wall_name("-u"))
	if v > vmax and not _open_at(tube.world(t, u, tube.hh)):
		v = vmax
		_hit(result, -up, _wall_name("+v"))
	elif v < -vmax and not _open_at(tube.world(t, u, -tube.hh)):
		v = -vmax
		_hit(result, up, _wall_name("-v"))
	# w is the overshoot past an open end: a mouth, and the hull keeps it.
	var out: Vector3 = tube.world(t, u, v) + (f["fwd"] as Vector3) * float(l["w"])
	result["pos"] = out
	var l2 := {"t": t, "u": u, "v": v, "w": l["w"]}
	if not tube.contains_local(l2):
		# Through an open wall, the hull is in the tube that OPENED it — and if one
		# step carried it clean across that tube (a thin ramp at speed), that tube's
		# own walls hold it, once. Only a hull leaving through an open END takes
		# whichever tube contains it, or open space.
		var next_tube: Tube = null
		if _opener != null:
			next_tube = _opener
			if not _opener.contains(out) and depth == 0:
				_log("entered %s" % next_tube.name)
				tube = next_tube
				_collide_inside(out, basis, half, result, depth + 1)
				return
		if next_tube == null:
			next_tube = tube_containing(out, tube.neighbours)
		if next_tube == null:
			next_tube = tube_containing(out, tubes)
		if next_tube != null:
			_log("entered %s" % next_tube.name)
			tube = next_tube
		else:
			_log("left %s into open space" % tube.name)
			tube = null


func _collide_outside(prev: Vector3, next: Vector3, basis: Basis, half: Vector3,
		result: Dictionary) -> void:
	for road in roads:
		var reach := road.half_width + road.half_height + road.rib_protrusion \
			+ half.length() + 20.0
		if not road.bounds.grow(reach).has_point(next):
			continue
		var c := road.path.closest(next)
		var t: float = c["t"]
		# Beyond an open end the closest point clamps and `w` carries the overshoot;
		# a hull out there is not beside this road at all.
		if not road.path.closed and absf(float(c["w"])) > 0.05:
			continue
		var f: Dictionary = c["frame"]
		var right: Vector3 = f["right"]
		var up: Vector3 = f["up"]
		var floor_thickness := Tuning.num("exploration/structure_floor_thickness")
		var margin := road.rib_margin_at(t)
		var mu := extent(basis, half, right) + margin
		var mv := extent(basis, half, up) + margin
		var w := road.half_width
		var h := road.half_height
		var u: float = c["u"]
		var v: float = c["v"]
		var inside_expanded := absf(u) < w + mu and v < h + mv and v > -h - floor_thickness - mv
		if not inside_expanded:
			continue
		var before := road.path.closest(prev)
		var pu: float = before["u"]
		var pv: float = before["v"]
		var was_inside := absf(pu) < w + mu and pv < h + mv and pv > -h - floor_thickness - mv
		if (not road.path.closed and absf(float(before["w"])) > 0.05) or was_inside:
			# Arrived through an open end — a mouth — or was already inside without a
			# tube (a teleport, a reload). Whichever tube holds us has us.
			var entered := tube_containing(next, road.tubes)
			if entered != null:
				tube = entered
				_log("entered %s through its mouth" % entered.name)
				return
			if was_inside:
				continue
			continue
		# Came at the outside of a wall: bounce off the exterior.
		var d_right := pu - (w + mu)
		var d_left := -(w + mu) - pu
		var d_top := pv - (h + mv)
		var d_bottom := (-h - floor_thickness - mv) - pv
		var best := maxf(maxf(d_right, d_left), maxf(d_top, d_bottom))
		if best == d_right:
			u = w + mu
			_hit(result, right, "outside of " + road.name)
		elif best == d_left:
			u = -(w + mu)
			_hit(result, -right, "outside of " + road.name)
		elif best == d_top:
			v = h + mv
			_hit(result, up, "outside of " + road.name)
		else:
			v = -h - floor_thickness - mv
			_hit(result, -up, "outside of " + road.name)
		result["pos"] = road.path.at(t, u, v)
		return


func _log(line: String) -> void:
	log_lines.append(line)
	if log_lines.size() > 8:
		log_lines.remove_at(0)
