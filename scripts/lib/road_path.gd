class_name RoadPath
extends RefCounted
## A road's centre-line: straight legs joined by circular arcs. Pure — no scene tree,
## no tuning, no disk.
##
## Built from waypoints and a corner radius per waypoint. The tangent is continuous
## everywhere, so nothing steering by it ever snaps, and every query is analytic: no
## baking, no sampled polyline, no approximation. The mesh, the collision and the lane
## all read this one curve, which is what lets them agree to the millimetre (ADR 0096).
##
## Coordinates are the map's frame, Y up. A path may be CLOSED (a loop) or open; an
## open path's ends are mouths.

const STRAIGHT := 0
const ARC := 1
const UP := Vector3.UP

## Each piece: `{kind, t0, len, a (start position), dir (start tangent)}`, and for an
## arc also `{centre, axis, radius, angle}`.
var pieces: Array[Dictionary] = []
## A bounding sphere per piece, `{centre, radius}`, so a closest-point query can skip
## pieces that cannot beat the best distance found so far.
var _spheres: Array[Dictionary] = []
var length: float = 0.0
var closed: bool = false
var waypoints: Array[Vector3] = []
## Every rounded corner, as `{pos, radius, angle_deg, t}` with `t` where its arc begins.
var corners: Array[Dictionary] = []


static func build(points: Array, radii: Array, is_closed: bool) -> RoadPath:
	var path := RoadPath.new()
	path._build(points, radii, is_closed)
	return path


## A two-point straight, for corridors and anything else with no bend in it.
static func straight(from: Vector3, to: Vector3) -> RoadPath:
	return build([from, to], [0.0, 0.0], false)


func _build(points: Array, radii: Array, is_closed: bool) -> void:
	closed = is_closed
	waypoints.clear()
	for q in points:
		waypoints.append(q as Vector3)
	var n := waypoints.size()
	assert(n >= 2, "a path needs two waypoints")
	# Corner data: for each waypoint that is a corner, where its arc enters and leaves.
	var arcs := {}
	var first_c := 1 if not closed else 0
	var last_c := n - 2 if not closed else n - 1
	for i in range(first_c, last_c + 1):
		var prev: Vector3 = waypoints[(i - 1 + n) % n]
		var cur: Vector3 = waypoints[i]
		var next: Vector3 = waypoints[(i + 1) % n]
		var a := (cur - prev).normalized()
		var b := (next - cur).normalized()
		var ang := a.angle_to(b)
		if ang < deg_to_rad(0.05):
			continue
		var r := float(radii[i]) if i < radii.size() else 0.0
		assert(r > 0.0, "corner %d needs a radius" % i)
		var d := r * tan(ang * 0.5)
		var axis := a.cross(b).normalized()
		var start := cur - a * d
		var centre := start + axis.cross(a) * r
		arcs[i] = {"start": start, "end": cur + b * d, "centre": centre, "axis": axis,
			"radius": r, "angle": ang, "dir": a, "d": d}
	# Walk the waypoints emitting straight and arc pieces.
	pieces.clear()
	corners.clear()
	var t := 0.0
	var cursor: Vector3 = waypoints[0]
	if closed and arcs.has(0):
		cursor = arcs[0]["end"]
	var seq_end := n - 1 if not closed else n
	for k in range(1, seq_end + 1):
		var i := k % n
		var target: Vector3 = waypoints[i]
		if arcs.has(i):
			var arc: Dictionary = arcs[i]
			t = _add_straight(t, cursor, arc["start"])
			corners.append({"pos": waypoints[i], "radius": arc["radius"],
				"angle_deg": rad_to_deg(arc["angle"]), "t": t})
			t = _add_arc(t, arc)
			cursor = arc["end"]
		else:
			t = _add_straight(t, cursor, target)
			cursor = target
	length = t
	_spheres.clear()
	for p in pieces:
		var a: Vector3 = p["a"]
		var b: Vector3 = a + (p["dir"] as Vector3) * float(p["len"])
		if p["kind"] == ARC:
			var c: Vector3 = p["centre"]
			b = c + (a - c).rotated(p["axis"], p["angle"])
			var mid: Vector3 = c + (a - c).rotated(p["axis"], float(p["angle"]) * 0.5)
			var centre := (a + b + mid) / 3.0
			_spheres.append({"centre": centre, "radius": maxf(maxf(centre.distance_to(a),
				centre.distance_to(b)), centre.distance_to(mid)) + 1.0})
		else:
			_spheres.append({"centre": (a + b) * 0.5, "radius": a.distance_to(b) * 0.5 + 1.0})


func _add_straight(t: float, from: Vector3, to: Vector3) -> float:
	var len := from.distance_to(to)
	if len < 1e-3:
		return t
	pieces.append({"kind": STRAIGHT, "t0": t, "len": len, "a": from,
		"dir": (to - from) / len})
	return t + len


func _add_arc(t: float, arc: Dictionary) -> float:
	var len: float = arc["radius"] * arc["angle"]
	pieces.append({"kind": ARC, "t0": t, "len": len, "a": arc["start"], "dir": arc["dir"],
		"centre": arc["centre"], "axis": arc["axis"], "radius": arc["radius"],
		"angle": arc["angle"]})
	return t + len


func is_empty() -> bool:
	return pieces.is_empty()


## Wrap or clamp a distance along the path into range.
func wrap_t(t: float) -> float:
	if closed:
		return fposmod(t, length)
	return clampf(t, 0.0, length)


## Signed distance from `t_from` forward to `t_to` along the path, in `direction`
## (+1 along increasing t, -1 against it). Closed paths wrap.
func ahead(t_from: float, t_to: float, direction: int) -> float:
	var d := (t_to - t_from) * direction
	if closed:
		d = fposmod(d, length)
	return d


func _piece_at(t: float) -> Dictionary:
	var last: Dictionary = pieces[pieces.size() - 1]
	for p in pieces:
		if t < p["t0"] + p["len"]:
			return p
	return last


## Position and unit tangent at distance `t`.
func sample(t: float) -> Dictionary:
	t = wrap_t(t)
	var p := _piece_at(t)
	var s: float = t - p["t0"]
	if p["kind"] == STRAIGHT:
		return {"pos": p["a"] + p["dir"] * s, "tan": p["dir"]}
	var phi: float = s / p["radius"]
	var centre: Vector3 = p["centre"]
	var axis: Vector3 = p["axis"]
	return {"pos": centre + (p["a"] - centre).rotated(axis, phi),
		"tan": (p["dir"] as Vector3).rotated(axis, phi)}


func point_at(t: float) -> Vector3:
	return sample(t)["pos"]


func tangent_at(t: float) -> Vector3:
	return sample(t)["tan"]


func start() -> Vector3:
	return point_at(0.0)


func finish() -> Vector3:
	return point_at(length)


## A right-handed road frame for a tangent: forward, up (world up made perpendicular)
## and right. Level, because nothing rolls (ADR 0045).
static func frame_from_tangent(tangent: Vector3) -> Dictionary:
	var up := UP - tangent * UP.dot(tangent)
	if up.length_squared() < 1e-6:
		up = Vector3.FORWARD
	up = up.normalized()
	return {"fwd": tangent, "up": up, "right": tangent.cross(up)}


func frame(t: float) -> Dictionary:
	var s := sample(t)
	var f := frame_from_tangent(s["tan"])
	f["pos"] = s["pos"]
	f["t"] = wrap_t(t)
	return f


## World position at (t, lateral u to the right, vertical v up).
func at(t: float, u: float, v: float) -> Vector3:
	var f := frame(t)
	return f["pos"] + f["right"] * u + f["up"] * v


## Closest point on the path, allocation free: `Vector4(t, u, v, w)` where u and v are
## the query point's lateral and vertical offsets in the road frame at t, and w is the
## overshoot along the tangent — non-zero only beyond an open end.
func closest_tuvw(point: Vector3) -> Vector4:
	var best_t := 0.0
	var best_d2 := INF
	var best_pos := Vector3.ZERO
	var best_tan := Vector3.FORWARD
	var best_d := INF
	for i in pieces.size():
		var sphere := _spheres[i]
		if point.distance_to(sphere["centre"]) - float(sphere["radius"]) > best_d:
			continue
		var p := pieces[i]
		var t_local: float
		var pos: Vector3
		var tng: Vector3
		if p["kind"] == STRAIGHT:
			var a: Vector3 = p["a"]
			var dir: Vector3 = p["dir"]
			t_local = clampf((point - a).dot(dir), 0.0, p["len"])
			pos = a + dir * t_local
			tng = dir
		else:
			var centre: Vector3 = p["centre"]
			var axis: Vector3 = p["axis"]
			var s0: Vector3 = p["a"] - centre
			var q: Vector3 = point - centre
			q -= axis * q.dot(axis)
			var phi := atan2(s0.cross(q).dot(axis), s0.dot(q))
			var ang: float = p["angle"]
			if phi < 0.0 or phi > ang:
				var mid := ang * 0.5 + PI
				phi = 0.0 if fposmod(phi, TAU) > mid else ang
			t_local = phi * p["radius"]
			pos = centre + s0.rotated(axis, phi)
			tng = (p["dir"] as Vector3).rotated(axis, phi)
		var d2 := (point - pos).length_squared()
		if d2 < best_d2:
			best_d2 = d2
			best_d = sqrt(d2)
			best_t = p["t0"] + t_local
			best_pos = pos
			best_tan = tng
	var up := UP - best_tan * best_tan.y
	if up.length_squared() < 1e-6:
		up = Vector3.FORWARD
	up = up.normalized()
	var right := best_tan.cross(up)
	var delta := point - best_pos
	# The tangential overshoot only means something past an open end. Elsewhere it is
	# float noise from equidistant neighbouring pieces, so it is zeroed.
	var w := 0.0
	if not closed and (best_t <= 0.001 or best_t >= length - 0.001):
		w = delta.dot(best_tan)
	return Vector4(best_t, delta.dot(right), delta.dot(up), w)


## Closest point with the full frame: `{t, u, v, w, dist, pos, frame}`.
func closest(point: Vector3) -> Dictionary:
	var q := closest_tuvw(point)
	var f := frame(q.x)
	var pos: Vector3 = f["pos"]
	return {"t": q.x, "u": q.y, "v": q.z, "w": q.w, "dist": point.distance_to(pos),
		"pos": pos, "frame": f}


## Axis-aligned bounds of the centre-line, grown by `margin`.
func aabb(margin: float) -> AABB:
	var box := AABB(sample(0.0)["pos"], Vector3.ZERO)
	var t := 0.0
	while t < length:
		box = box.expand(sample(t)["pos"])
		t += 50.0
	box = box.expand(sample(length)["pos"])
	return box.grow(margin)


func min_radius() -> float:
	var r := INF
	for p in pieces:
		if p["kind"] == ARC:
			r = minf(r, p["radius"])
	return r


## The centre-line sampled every `step` metres, for things that want a polyline (the
## deep field's scatter, a debug line). Never for collision or the mesh.
func points(step: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var t := 0.0
	while t < length:
		out.append(point_at(t))
		t += maxf(step, 1.0)
	out.append(point_at(length))
	return out


## Corners whose arc cannot fit: the tangent length `R·tan(θ/2)` must not pass the
## midpoint of either adjacent leg, or two arcs overlap and the path folds. One line
## per bad corner, naming it, so the author can act on it.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	var n := waypoints.size()
	var first_c := 1 if not closed else 0
	var last_c := n - 2 if not closed else n - 1
	for i in range(first_c, last_c + 1):
		var prev: Vector3 = waypoints[(i - 1 + n) % n]
		var cur: Vector3 = waypoints[i]
		var next: Vector3 = waypoints[(i + 1) % n]
		var a := (cur - prev).normalized()
		var b := (next - cur).normalized()
		var ang := a.angle_to(b)
		if ang < deg_to_rad(0.05):
			continue
		var r := 0.0
		for c in corners:
			if (c["pos"] as Vector3).is_equal_approx(cur):
				r = c["radius"]
		var d := r * tan(ang * 0.5)
		var room := minf(prev.distance_to(cur), cur.distance_to(next)) * 0.5
		if d > room + 0.01:
			out.append("corner %d at %s turns %.0f deg with r=%.0f: needs %.0f m of leg each side, has %.0f" % [
				i, cur, rad_to_deg(ang), r, d, room])
	return out


## The steepest pitch anywhere on the path, in degrees.
func max_pitch_deg() -> float:
	var worst := 0.0
	var t := 0.0
	while t <= length:
		var tng := tangent_at(t)
		worst = maxf(worst, rad_to_deg(asin(clampf(absf(tng.y), 0.0, 1.0))))
		t += 25.0
	return worst
