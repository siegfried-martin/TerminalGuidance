class_name RoadSuite
extends RefCounted
## The road's suite of the gate (ADR 0096): a road is not verified by bounding its
## geometry, it is verified by FLYING it and asserting what the player is handed.
##
## A `RoadProbe` — the same collider and the same lane sample the mothership uses —
## flies every carriageway end to end, every ramp from its host to its destination,
## dives at every wall around every junction and every bend, and flies drunk on every
## tube. The checks are against the RENDERED triangles, not the road data: a ray from
## the probe's last position to its new one must never cross a visible surface, the
## probe must never be stopped, and while inside a tube there must be structure on
## all four sides. That is what makes "what you see is what you hit" a checked
## property rather than a promise.

const DT := 1.0 / 60.0

var _runner: Node
var _holder: Node3D
var _network: RoadNetwork
var _space: PhysicsDirectSpaceState3D
var _probe: RoadProbe
var _steps: int = 0
var _warnings: PackedStringArray = []


func _init(runner: Node) -> void:
	_runner = runner


func _expect(condition: bool, what: String, detail: String) -> void:
	_runner._expect(condition, what, detail)


## Build the network, its whole mesh, and a collision body of every rendered
## triangle. Then run the suites.
func run() -> void:
	var t0 := Time.get_ticks_msec()
	_holder = Node3D.new()
	_holder.name = "RoadSuite"
	_runner.add_child(_holder)
	_network = RoadNetwork.new()
	_holder.add_child(_network)
	_network.build(Routes.data(), Routes.system_positions())
	_expect(_network.problems.is_empty(),
		"data/routes.json builds with no problems: bends flyable, ramps clear, highways apart",
		"\n      ".join(_network.problems))
	var faces := _network.build_all_now()
	var body := StaticBody3D.new()
	_holder.add_child(body)
	var tris := 0
	for road_name: String in faces:
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces[road_name])
		shape.backface_collision = true
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		tris += (faces[road_name] as PackedVector3Array).size() / 3
	_expect(tris > 1000, "the whole road's mesh is built for the gate", "%d triangles" % tris)
	print("  road suite: %d roads, %d triangles, built in %d ms" % [
		_network.roads.size(), tris, Time.get_ticks_msec() - t0])
	await _runner.get_tree().physics_frame
	await _runner.get_tree().physics_frame
	_space = _holder.get_world_3d().direct_space_state
	_probe = RoadProbe.new()
	_probe.setup(_network.tubes, _network.roads)
	# The taxi, at whatever scale the hull is drawn at.
	var hull := load("res://assets/models/carrier.obj") as Mesh
	_probe.half = hull.get_aabb().size * Tuning.num("ship/hull_scale") * 0.5

	_winding()
	_containment()
	_laps()
	_ramps()
	_exits_steered()
	_dives()
	_drunk()
	for w in _warnings:
		print("  road suite WARN " + w)
	print("  road suite: %d probe steps" % _steps)
	_probe.collider.setup([], [])
	_holder.queue_free()


## Every triangle's FRONT face is the side its normal points to. Godot's front face
## is wound clockwise from outside, so the right-hand cross product of a triangle's
## edges points the OTHER way from its normal. Get this wrong and, with culling off,
## every face is lit as though it faced the other way — the roadway seen from above
## was being lit by the star underneath it.
func _winding() -> void:
	var road := _network.roads[0]
	var chunk: Dictionary = RoadMesh.plan(road)[0]
	var foreign: Array[Tube] = []
	var built := RoadMesh.build_chunk(road, foreign, chunk, 4.0, 3.0, false)
	var wrong := 0
	var total := 0
	for m in 3:
		var vs: PackedVector3Array = (built["verts"] as Array)[m]
		var ns: PackedVector3Array = (built["norms"] as Array)[m]
		var i := 0
		while i + 2 < vs.size():
			var geometric := (vs[i + 1] - vs[i]).cross(vs[i + 2] - vs[i])
			if geometric.length_squared() > 1e-9 and geometric.dot(ns[i]) > 0.0:
				wrong += 1
			total += 1
			i += 3
	_expect(total > 0 and wrong == 0,
		"every triangle is wound clockwise from the side its normal faces (Godot's front)",
		"%d of %d triangles face the wrong way" % [wrong, total])


## Every tube contains its own centre-line and points near it, everywhere. This is
## the ground truth the mesh clip, the collision and the tube switching all rely on.
func _containment() -> void:
	for tube in _network.tubes:
		var bad := 0
		var t := 0.0
		while t < tube.path.length:
			# Offsets as shares of the section, so the test means the same at any scale.
			var w := tube.hw * 0.42
			var h := tube.hh * 0.4
			for off: Vector3 in [Vector3.ZERO, Vector3(w, h, 3.3), Vector3(-w, -h, -3.3), Vector3(-w * 0.7, 0, 7.7)]:
				var ta: float = t + off.z * tube.direction
				if not tube.path.closed and (ta < 0.0 or ta > tube.path.length):
					continue
				var p: Vector3 = tube.world(t, off.x, off.y) + (tube.travel_frame(t)["fwd"] as Vector3) * off.z
				if not tube.contains(p):
					bad += 1
			t += 25.0
		_expect(bad == 0, "%s contains its own centre-line" % tube.name, "%d points outside" % bad)


## Every carriageway of every highway, mouth to mouth.
func _laps() -> void:
	for tube in _network.tubes:
		if tube.is_ramp():
			continue
		var start_t := tube.start_t() + 150.0 * tube.direction
		var seconds := tube.path.length / _probe.cruise_speed + 20.0
		_fly("lap of %s" % tube.name, [tube], tube, start_t, seconds, not tube.path.closed)


## Every ramp: host, ramp, then the road it merges into or the mouth it ends at.
func _ramps() -> void:
	for ramp in _network.ramps:
		var road: Road = ramp["road"]
		var rt: Tube = road.tubes[0]
		var route: Array = []
		var start_tube: Tube
		var start_t: float
		if ramp["from_tube"] != null:
			var ft: Tube = ramp["from_tube"]
			route.append(ft)
			start_tube = ft
			start_t = ft.path.wrap_t(float(ramp["from_t"]) - 2000.0 * ft.direction)
		else:
			start_tube = rt
			start_t = 100.0
		route.append(rt)
		var to_mouth: bool = ramp["to_tube"] == null
		if not to_mouth:
			route.append(ramp["to_tube"])
		var seconds := (2000.0 + road.path.length + 3000.0) / _probe.cruise_speed + 20.0
		_fly("ramp %s" % road.name, route, start_tube, start_t, seconds, to_mouth)


## Every exit, taken the way a player takes one: steering into it sharper than it
## diverges, from short of the junction. The probe rides the ramp's outer wall for
## the diverging leg, and it must arrive in the ramp without being slowed — which is
## the "caught on something" the human reported from the seat.
func _exits_steered() -> void:
	for ramp in _network.ramps:
		if ramp["from_tube"] == null:
			continue
		var host: Tube = ramp["from_tube"]
		var rt: Tube = (ramp["road"] as Road).tubes[0]
		var start := host.path.wrap_t(float(ramp["from_t"]) - 600.0 * host.direction)
		_probe.place(host, start)
		_probe.throttle = 1.0
		_probe.velocity = _probe.forward() * _probe.cruise_speed
		var f := host.travel_frame(start)
		_probe.aim = (f["fwd"] as Vector3).rotated(f["up"], -deg_to_rad(15.0))
		var slowest := INF
		var label := "steering 15 deg into exit %s" % rt.name
		var ok := true
		for i in int(9.0 / DT):
			# Once in the ramp, fly it: what is under test is what ENTERING sharply
			# costs, not holding a fixed heading into the ramp's own bends.
			if _probe.tube() == rt:
				var lc := rt.local(_probe.position)
				_probe.aim = (rt.centre(float(lc["t"]) + 400.0) - _probe.position).normalized()
			if not _step_checked(label, i):
				ok = false
				break
			if i * DT > 1.0:
				slowest = minf(slowest, _probe.speed())
		_expect(ok and _probe.tube() == rt, label + " ends in the ramp",
			"in %s" % _name(_probe.tube()))
		_expect(slowest > _probe.cruise_speed * 0.7,
			label + " is never slowed below 70%% of cruise on the way",
			"%.0f m/s at slowest" % slowest)


## Into every wall at every junction edge and every bend.
func _dives() -> void:
	for ramp in _network.ramps:
		var road: Road = ramp["road"]
		var rt: Tube = road.tubes[0]
		if ramp["from_tube"] != null:
			var ft: Tube = ramp["from_tube"]
			for off: float in [-150.0, 400.0]:
				_dive_set("%s at exit %s (%+.0f m)" % [ft.name, road.name, off], ft,
					ft.path.wrap_t(float(ramp["from_t"]) + off * ft.direction))
		if ramp["to_tube"] != null:
			_dive_set("%s before its merge" % road.name, rt, maxf(road.path.length - 500.0, 50.0))
			var tt: Tube = ramp["to_tube"]
			_dive_set("%s at entry %s" % [tt.name, road.name], tt,
				tt.path.wrap_t(float(ramp["to_t"]) - 300.0 * tt.direction))
		else:
			# Well short of the mouth: four seconds of diving covers half a kilometre,
			# and out of the mouth is open space, legitimately.
			_dive_set("%s near its mouth" % road.name, rt,
				maxf(road.path.length - _probe.cruise_speed * 4.5, 50.0))
	for road in _network.roads:
		if road.kind != "highway":
			continue
		for c in road.path.corners:
			for tube in road.tubes:
				_dive_set("%s bend r=%.0f" % [tube.name, c["radius"]], tube,
					road.path.wrap_t(float(c["t"]) + 300.0 * tube.direction))


func _drunk() -> void:
	for tube in _network.tubes:
		var start_t := 300.0 if tube.direction == 1 else tube.path.length - 300.0
		if tube.is_ramp():
			start_t = 100.0
		_drunk_on("drunk on %s" % tube.name, tube, start_t, 30.0)


# --- flights -------------------------------------------------------------------

## Follow a route of tubes with a look-ahead pilot.
func _fly(label: String, route: Array, start_tube: Tube, start_t: float, seconds: float,
		ends_in_space: bool) -> void:
	_probe.place(start_tube, start_t)
	_probe.throttle = 1.0
	var idx := 0
	var visited: Array = [start_tube]
	var max_turn := 0.0
	# The pilot looks a fixed TIME ahead, whatever the speed.
	var lookahead := _probe.cruise_speed * 2.4
	var ok := true
	var steps := int(seconds / DT)
	var arrived := -1
	for i in steps:
		# On the last tube of the route, a few seconds more and done — the flight is
		# about reaching it, and flying on would take a merge near a road's end out
		# through its mouth.
		if idx == route.size() - 1 and not ends_in_space and _probe.tube() == route[idx]:
			if arrived < 0:
				arrived = i
			elif i - arrived > int(3.0 / DT):
				break
		if idx + 1 < route.size():
			var nxt: Tube = route[idx + 1]
			var l := nxt.local(_probe.position)
			if nxt.t_in_range(l["t"]) and Vector2(l["u"], l["v"]).length() < 90.0:
				idx += 1
		var cur: Tube = route[idx]
		var lc := cur.local(_probe.position)
		var ta: float = float(lc["t"]) + lookahead * cur.direction
		var target := cur.centre(ta)
		if not cur.path.closed and (ta > cur.path.length or ta < 0.0):
			var end_t := clampf(ta, 0.0, cur.path.length)
			target = cur.centre(end_t) + (cur.travel_frame(end_t)["fwd"] as Vector3) * absf(ta - end_t)
		_probe.aim = (target - _probe.position).normalized()
		var before := _probe.forward()
		_probe.throttle = 1.0
		if not _step_checked(label, i):
			ok = false
			break
		if i * DT > 5.0:
			max_turn = maxf(max_turn, before.angle_to(_probe.forward()) / DT)
		if _probe.tube() != null and not visited.has(_probe.tube()):
			visited.append(_probe.tube())
		if ends_in_space and _probe.tube() == null and i * DT > 5.0:
			break
	var share := rad_to_deg(max_turn) / _probe.turn_rate_deg
	if share > Tuning.num("exploration/road_turn_share") + 0.15:
		_warnings.append("%s: following the centre-line used %.0f%% of the turn rate" % [label, share * 100.0])
	for tube: Tube in route:
		if not visited.has(tube):
			ok = false
			_expect(false, "%s reaches %s" % [label, tube.name], "never entered it")
	if ends_in_space:
		_expect(_probe.tube() == null, "%s leaves through the mouth into open space" % label,
			"still in %s" % (_probe.tube().name if _probe.tube() else "?"))
	else:
		_expect(_probe.tube() != null, "%s ends on a road" % label, "ended in open space")
	_expect(ok, "%s: never through a surface, never stopped, structure all round" % label, "")


## Fire the probe at each wall from a spot.
func _dive_set(label: String, tube: Tube, t: float) -> void:
	var ok := true
	for side: String in ["right", "left", "up", "down"]:
		_probe.place(tube, t)
		_probe.throttle = 1.0
		_probe.velocity = _probe.forward() * _probe.cruise_speed * 0.8
		var f := tube.travel_frame(t)
		var fwd: Vector3 = f["fwd"]
		var dir: Vector3
		match side:
			"right": dir = fwd.rotated(f["up"], -deg_to_rad(50.0))
			"left": dir = fwd.rotated(f["up"], deg_to_rad(50.0))
			"up": dir = fwd.rotated(f["right"], deg_to_rad(50.0))
			_: dir = fwd.rotated(f["right"], -deg_to_rad(50.0))
		_probe.aim = dir
		var sub := "%s, diving %s" % [label, side]
		for i in int(4.0 / DT):
			if not _step_checked(sub, i):
				ok = false
				break
			if _probe.tube() == null:
				_expect(false, sub, "fell out of the structure into open space")
				ok = false
				break
	_expect(ok, "dives at " + label, "")


func _drunk_on(label: String, tube: Tube, t: float, seconds: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(label)
	_probe.place(tube, t)
	_probe.throttle = 1.0
	var ok := true
	var aim_local := Vector2.ZERO
	for i in int(seconds / DT):
		if i % 90 == 0:
			aim_local = Vector2(rng.randf_range(-40.0, 40.0), rng.randf_range(-15.0, 15.0))
		var fr: Dictionary = _probe.frame
		_probe.aim = (fr["fwd"] as Vector3).rotated(fr["up"], deg_to_rad(aim_local.x)) \
			.rotated(fr["right"], deg_to_rad(aim_local.y))
		_probe.throttle = 1.0
		if not _step_checked(label, i):
			ok = false
			break
		if _probe.tube() == null:
			var near_mouth := false
			for road in _network.roads:
				for m in road.mouths:
					if road.path.at(float(m["t"]), 0.0, 0.0).distance_to(_probe.position) < 3000.0:
						near_mouth = true
			if not near_mouth:
				_expect(false, label, "fell out into open space at %s" % _probe.position)
				ok = false
			break
	_expect(ok, label, "")


# --- the invariants, every step ------------------------------------------------

func _step_checked(label: String, i: int) -> bool:
	var before := _probe.position
	var tube_before := _probe.tube()
	_probe.step(DT)
	_steps += 1
	var after := _probe.position
	var hit := _ray(before, after)
	if not hit.is_empty():
		_expect(false, label, "passed through a surface at %s facing %s, moving %s -> %s (t=%.1fs, %s -> %s): %s" % [
			hit["position"], hit["normal"], before, after, i * DT, _name(tube_before),
			_name(_probe.tube()), " | ".join(_probe.collider.log_lines)])
		return false
	if i * DT > 6.0 and _probe.speed() < 15.0:
		_expect(false, label, "stopped (%.1f m/s at t=%.1fs in %s)" % [
			_probe.speed(), i * DT, _name(_probe.tube())])
		return false
	if _probe.tube() != null and i % 30 == 0:
		var fr: Dictionary = _probe.frame
		var fwd: Vector3 = fr["fwd"]
		var side: Vector3 = fr["right"]
		for d: Vector3 in [fr["right"], -fr["right"], fr["up"], -fr["up"]]:
			# A ray exactly along a seam between two of a clipped wall's triangles, or
			# through a shared edge, can slip through the physics test; three origins a
			# metre apart cannot all hit the same seam.
			if _ray(after, after + d * 2500.0).is_empty() \
					and _ray(after + fwd * 0.7, after + fwd * 0.7 + d * 2500.0).is_empty() \
					and _ray(after + side * 0.7 + fwd * 0.3, after + side * 0.7 + fwd * 0.3 + d * 2500.0).is_empty():
				_expect(false, label, "no structure within 2.5 km toward %s at %s (t=%.1fs in %s)" % [
					d, after, i * DT, _name(_probe.tube())])
				return false
	return true


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	if from.is_equal_approx(to):
		return {}
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.hit_back_faces = true
	q.hit_from_inside = false
	return _space.intersect_ray(q)


static func _name(t: Tube) -> String:
	return t.name if t else "space"
