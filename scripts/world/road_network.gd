class_name RoadNetwork
extends Node3D
## The highway network: every road on the map, the tubes inside them, the ramps
## between them, and the structure drawn around them (ADR 0096).
##
## **A road is a `RoadPath` with one or two `Tube`s in it.** A highway carries two
## carriageways under one roof with a glass median; a ramp carries one. A ramp LEAVES
## a carriageway by running level inside it for a lead, then diverging through the
## wall; it ARRIVES by approaching from below and climbing through the floor
## (ADR 0096: exits never through the floor, entries always up through it — a rule applied by `_ramp` rather than a shape measured after the
## fact). The wall and floor are open wherever the ramp's tube is, and nowhere else,
## and the collider and the mesh read the same rule.
##
## **Routes are data**, in `data/routes.json` (the `Routes` autoload), hot-reloaded
## like `tuning.cfg`: systems, highways as waypoints with corner radii, planet ramps
## declared by system and side and shaped by the ramp rule, interchange ramps
## authored as waypoints. Everything here is built from that in `build()` and rebuilt
## on reload.
##
## **The mesh streams.** Building a whole map of clipped junctions up front was the
## POC's load time, so each road is chunks (`RoadMesh.plan`) built around the ship
## within `road_detail_radius` on worker threads, and a coarse unclipped far version
## stands in beyond it. Collision is analytic and always available everywhere; only
## the visuals stream.
##
## Geometry is built in the MAP's frame with this node at identity, so the floating
## origin is a move of the map and nothing here has to know (ADR 0020).

## Chunks started per frame at most, and worker tasks in flight at most. Infrastructure.
const BUILDS_PER_FRAME := 2
const WORKERS := 2
## Ramps are a little smaller than the carriageway they leave, so their tube nests
## inside it for the lead. Infrastructure, not feel: 2 m nobody can see.
const RAMP_INSET := 2.0

var roads: Array[Road] = []
var tubes: Array[Tube] = []
## `{road, from_tube, from_t, to_tube, to_t, mouth_of, exit_portal, entry_portal, gate}`.
var ramps: Array[Dictionary] = []
## Teleport spots for the debug drop: `{label, tube, t}`.
var spots: Array[Dictionary] = []
## Validation messages. Reported, never silently fixed.
var problems: PackedStringArray = []

var _mesh_root: Node3D
## The pool of live track lights that follows the ship (`RoadLamps`).
var lamps: RoadLamps
var _far: Dictionary = {}
var _markings: Dictionary = {}
var _chunks: Array[Dictionary] = []
var _loaded: Dictionary = {}
var _pending: Dictionary = {}
var _portals: Array[Portal] = []
var _gates: Array[RampGate] = []
var _active: Tube = null
var _floor_thickness: float = 10.0
var _beam: float = 8.0


func _ready() -> void:
	_mesh_root = Node3D.new()
	_mesh_root.name = "Structure"
	add_child(_mesh_root)
	lamps = RoadLamps.new()
	add_child(lamps)


## Tear down and build from the route data (`Routes.data()`), with the systems'
## positions in the map's frame.
func build(data: Dictionary, system_positions: Dictionary) -> void:
	_cancel_pending()
	if _mesh_root == null:
		_ready()
	for child in _mesh_root.get_children():
		child.queue_free()
	for portal in _portals:
		portal.queue_free()
	for gate in _gates:
		gate.queue_free()
	_portals.clear()
	_gates.clear()
	_far.clear()
	_markings.clear()
	_loaded.clear()
	_chunks.clear()
	_release()
	ramps.clear()
	spots.clear()
	problems.clear()
	_active = null
	_floor_thickness = Tuning.num("exploration/structure_floor_thickness")
	_beam = Tuning.num("exploration/structure_beam_size")

	var by_name := {}
	for h: Dictionary in data.get("highways", []):
		var points: Array = []
		for p: Array in h["points"]:
			points.append(Vector3(p[0], p[1], p[2]))
		var radii: Array = h.get("radii", [])
		var path := RoadPath.build(points, radii, bool(h.get("closed", false)))
		var road := Road.make(String(h["name"]), "highway", path, 2, 0.0)
		road.set_meta("systems", h.get("systems", []))
		if h.has("mouth_height"):
			road.set_meta("mouth_height", float(h["mouth_height"]))
		if h.has("mouth_along"):
			road.set_meta("mouth_along", float(h["mouth_along"]))
		_add_road(road)
		if not path.closed:
			road.mouths.append({"t": 0.0, "label": road.name + " start"})
			road.mouths.append({"t": path.length, "label": road.name + " end"})
		by_name[road.name] = road
		for c in path.problems():
			problems.append("%s: %s" % [road.name, c])

	for r: Dictionary in data.get("planet_ramps", []):
		var road: Road = by_name.get(String(r["highway"]))
		if road == null:
			problems.append("planet ramp names unknown highway %s" % r["highway"])
			continue
		var system := String(r["system"])
		if not system_positions.has(system):
			problems.append("planet ramp names unknown system %s" % system)
			continue
		for side: String in r.get("sides", ["R", "L"]):
			for kind: String in r.get("kinds", ["exit", "entry"]):
				_planet_ramp(_side_of(road, side), system, system_positions[system], kind)
	var authored: Array = data.get("ramps", [])
	for r: Dictionary in authored:
		if not r.has("mirror_of"):
			_authored_ramp(r, by_name, system_positions)
	for r: Dictionary in authored:
		if r.has("mirror_of"):
			_mirrored_ramp(r, authored, by_name, system_positions)

	_finish()
	_plan_chunks()
	for road in roads:
		for tube in road.tubes:
			var lines := RoadMesh.markings(tube)
			_mesh_root.add_child(lines)
			_markings[tube.name] = lines
	repaint()


func _add_road(road: Road) -> void:
	roads.append(road)
	for t in road.tubes:
		tubes.append(t)


func _side_of(road: Road, side: String) -> Tube:
	return road.tubes[1] if side == "L" and road.tubes.size() == 2 else road.tubes[0]


## The planet ramp rule: an S-BEND. The highway runs along the bottom of the system
## and the mouths sit low beside the planet, a little above the road and a little to
## its right, so a ramp is two bends of `ramp_bend_radius` through `ramp_bend_deg`
## with one straight between them. An EXIT leaves the carriageway level, bends up
## and right, runs straight, and bends back level into its mouth; an ENTRY leaves its
## mouth level, bends down and left, runs straight, and bends back level onto the
## merge lead inside the carriageway — in from above, never up through the floor.
## The mouth's offset from the carriageway sets the ramp's length: it is the offset
## over the tangent of the bend angle, plus a bend's tangent length at each end. Both
## mouths sit beside the system's centre, outside the planet's approach envelope (the
## gate checks).
func _planet_ramp(tube: Tube, system: String, centre: Vector3, kind: String) -> void:
	var t_s: float = tube.local(centre)["t"]
	# A highway may also push its mouths further along (`mouth_along` in routes.json),
	# so a road crossing another can put its mouths clear of the other's building.
	var along: float = float(tube.road.get_meta("mouth_along",
		Tuning.num("exploration/ramp_mouth_along_offset")))
	var side := Tuning.num("exploration/ramp_mouth_side_offset")
	# A highway may lift or lower its mouths (`mouth_height` in routes.json) so that
	# where two highways cross, their ramps to the same planet pass clear of each
	# other.
	var mouth_y: float = centre.y + float(tube.road.get_meta("mouth_height",
		Tuning.num("exploration/ramp_mouth_height")))
	var theta := deg_to_rad(clampf(Tuning.num("exploration/ramp_bend_deg"), 5.0, 75.0))
	var r := Tuning.num("exploration/ramp_bend_radius")
	# A bend's tangent length: how far before and after its corner the arc reaches.
	# Each straight has to be two of these, or the arcs would overlap.
	var d := r * tan(theta * 0.5) + 1.0
	# The mouth's offset to the driver's right of THIS carriageway's centre-line: the
	# side offset is from the system's centre, which the road's own centre-line passes
	# through, and the carriageway sits u0 to one side of that.
	var lateral := side - tube.u0 * tube.direction
	var name := "%s %s %s" % [tube.name, system, "out" if kind == "exit" else "in"]
	if kind == "exit":
		# An exit is taken by steering RIGHT, so it leaves through the wall the way
		# every ramp's head does — the level peel at the exit angle — and only then
		# bends up to its mouth: the S-bend carries the climb and whatever of the
		# side offset the peel did not.
		var angle := deg_to_rad(Tuning.num("exploration/ramp_exit_angle_deg"))
		var lead := Tuning.num("exploration/ramp_exit_lead")
		var length := Tuning.num("exploration/ramp_exit_length")
		var t_mouth := tube.path.wrap_t(t_s - tube.direction * along)
		var f := tube.travel_frame(t_mouth)
		var c: Vector3 = f["pos"]
		var mouth: Vector3 = c + (f["right"] as Vector3) * lateral + (f["up"] as Vector3) * (mouth_y - c.y)
		var across := lateral - length * sin(angle)
		var off: Vector3 = (f["right"] as Vector3) * across + (f["up"] as Vector3) * (mouth_y - c.y)
		var run := off.length() / tan(theta)
		var t0 := tube.path.wrap_t(t_mouth - tube.direction * (lead + length * cos(angle) + run + 2.0 * d))
		var f0 := tube.travel_frame(t0)
		var p0: Vector3 = f0["pos"]
		var p1: Vector3 = p0 + (f0["fwd"] as Vector3) * lead
		var p2: Vector3 = p1 + (f0["fwd"] as Vector3).rotated(f0["up"], -angle) * length
		var m2: Vector3 = mouth - (f["fwd"] as Vector3) * 2.0 * d
		_ramp_build(name, tube, t0, null, 0.0, [p0, p1, p2, m2, mouth],
			[0.0, minf(Tuning.num("exploration/ramp_exit_radius"), (lead * 0.5 - 1.0) / maxf(tan(angle * 0.5), 0.001)), r, r, 0.0], system)
	else:
		var t_mouth := tube.path.wrap_t(t_s + tube.direction * along)
		var f := tube.travel_frame(t_mouth)
		var c: Vector3 = f["pos"]
		var mouth: Vector3 = c + (f["right"] as Vector3) * lateral + (f["up"] as Vector3) * (mouth_y - c.y)
		var off := mouth - c
		var run := off.length() / tan(theta)
		var merge_lead := maxf(Tuning.num("exploration/ramp_merge_lead"), 2.0 * d)
		var t_m := tube.path.wrap_t(t_mouth + tube.direction * (2.0 * d + run + merge_lead))
		var fm := tube.travel_frame(t_m)
		var e0: Vector3 = fm["pos"]
		var e1: Vector3 = e0 - (fm["fwd"] as Vector3) * merge_lead
		var m1: Vector3 = mouth + (f["fwd"] as Vector3) * 2.0 * d
		_ramp_build(name, null, 0.0, tube, t_m, [mouth, m1, e1, e0], [0.0, r, r, 0.0], system)


func _authored_ramp(r: Dictionary, by_name: Dictionary, systems: Dictionary) -> Road:
	var from_tube: Tube = null
	var from_t := 0.0
	var to_tube: Tube = null
	var to_t := 0.0
	var mouth_of := ""
	var from: Dictionary = r.get("from", {})
	var to: Dictionary = r.get("to", {})
	if from.has("highway"):
		var road: Road = by_name.get(String(from["highway"]))
		if road == null:
			problems.append("ramp %s leaves unknown highway %s" % [r["name"], from["highway"]])
			return null
		from_tube = _side_of(road, String(from.get("side", "R")))
		from_t = _t_of(from_tube, from, systems)
	elif from.has("mouth"):
		mouth_of = String(from["mouth"])
	if to.has("highway"):
		var road: Road = by_name.get(String(to["highway"]))
		if road == null:
			problems.append("ramp %s joins unknown highway %s" % [r["name"], to["highway"]])
			return null
		to_tube = _side_of(road, String(to.get("side", "R")))
		to_t = _t_of(to_tube, to, systems)
	elif to.has("mouth"):
		mouth_of = String(to["mouth"])
	var mids: Array = []
	for p: Array in r.get("points", []):
		mids.append(Vector3(p[0], p[1], p[2]))
	return _ramp(String(r["name"]), from_tube, from_t, to_tube, to_t, mids,
		r.get("radii", []), mouth_of)


## A ramp that is another ramp turned half a turn about a system's centre. The two
## carriageways of a highway are each other's half-turn image, so a ramp between the
## forward carriageways of two roads mirrors onto one between the reverse ones.
func _mirrored_ramp(r: Dictionary, authored: Array, by_name: Dictionary, systems: Dictionary) -> void:
	var source: Dictionary = {}
	for other: Dictionary in authored:
		if String(other.get("name", "")) == String(r["mirror_of"]):
			source = other
	if source.is_empty():
		problems.append("ramp %s mirrors unknown ramp %s" % [r["name"], r["mirror_of"]])
		return
	var about: Vector3 = systems.get(String(r["about"]), Vector3.ZERO)
	var turned: Dictionary = source.duplicate(true)
	turned["name"] = r["name"]
	for end in ["from", "to"]:
		if turned.has(end) and (turned[end] as Dictionary).has("highway"):
			var e: Dictionary = turned[end]
			e["side"] = "L" if String(e.get("side", "R")) == "R" else "R"
			if e.has("near"):
				var p: Array = e["near"]
				var q := _half_turn(Vector3(p[0], p[1], p[2]), about)
				e["near"] = [q.x, q.y, q.z]
	var points: Array = []
	for p: Array in turned.get("points", []):
		var q := _half_turn(Vector3(p[0], p[1], p[2]), about)
		points.append([q.x, q.y, q.z])
	turned["points"] = points
	_authored_ramp(turned, by_name, systems)


static func _half_turn(p: Vector3, about: Vector3) -> Vector3:
	return Vector3(2.0 * about.x - p.x, p.y, 2.0 * about.z - p.z)


## Where on a tube a ramp end is: `near` a world point, or `at` a system plus an
## `offset` along the carriageway in travel metres.
func _t_of(tube: Tube, end: Dictionary, systems: Dictionary) -> float:
	if end.has("near"):
		var p: Array = end["near"]
		return tube.local(Vector3(p[0], p[1], p[2]))["t"]
	var at: Vector3 = systems.get(String(end.get("at", "")), Vector3.ZERO)
	var t: float = tube.local(at)["t"]
	return tube.path.wrap_t(t + tube.direction * float(end.get("offset", 0.0)))


## A ramp. `from_tube` or `to_tube` may be null (a mouth at that end). `mids` are the
## waypoints between the standard exit head and the standard merge tail, each with a
## corner radius (0 at a mouth endpoint).
func _ramp(name: String, from_tube: Tube, from_t: float, to_tube: Tube, to_t: float,
		mids: Array, mid_radii: Array, mouth_of: String) -> Road:
	var pts: Array = []
	var radii: Array = []
	var lead := Tuning.num("exploration/ramp_exit_lead")
	var bend := Tuning.num("exploration/ramp_bend_radius")
	if from_tube != null:
		var f := from_tube.travel_frame(from_t)
		var p0: Vector3 = f["pos"]
		var p1: Vector3 = p0 + (f["fwd"] as Vector3) * lead
		var d: Vector3 = (f["fwd"] as Vector3).rotated(f["up"],
			-deg_to_rad(Tuning.num("exploration/ramp_exit_angle_deg")))
		var p2: Vector3 = p1 + d * Tuning.num("exploration/ramp_exit_length")
		# The bend into the diverging leg has to FIT the lead: an arc whose tangent
		# length passes the lead's midpoint starts inside the carriageway before the
		# ramp does, and folds. So the radius is the tuned one or the largest the lead
		# allows, whichever is smaller — a steeper exit angle buys a tighter bend.
		var half_angle := deg_to_rad(Tuning.num("exploration/ramp_exit_angle_deg")) * 0.5
		var fits := (lead * 0.5 - 1.0) / maxf(tan(half_angle), 0.001)
		pts += [p0, p1, p2]
		radii += [0.0, minf(Tuning.num("exploration/ramp_exit_radius"), fits),
			float(mid_radii[0]) if mid_radii.size() > 0 and float(mid_radii[0]) > 0.0 else bend]
	for i in mids.size():
		pts.append(mids[i])
		radii.append(float(mid_radii[i]) if i < mid_radii.size() else 0.0)
	if to_tube != null:
		var f := to_tube.travel_frame(to_t)
		var e0: Vector3 = f["pos"]
		var e1: Vector3 = e0 - (f["fwd"] as Vector3) * Tuning.num("exploration/ramp_merge_lead")
		var rm := Tuning.num("exploration/ramp_merge_radius")
		# An interchange ramp comes up from below: `drop` under the carriageway,
		# climbing at the merge pitch through the floor onto the lead.
		var drop := Tuning.num("exploration/ramp_merge_drop")
		var run := drop / tan(deg_to_rad(Tuning.num("exploration/ramp_merge_pitch_deg")))
		var e2: Vector3 = e1 - (f["fwd"] as Vector3) * run - (f["up"] as Vector3) * drop
		pts += [e2, e1, e0]
		radii += [rm, rm, 0.0]
	return _ramp_build(name, from_tube, from_t, to_tube, to_t, pts, radii, mouth_of)


## Build a ramp from its waypoints and corner radii: fit the arcs, make the road and
## its tube, record the junctions, place the portals, gate and spots.
func _ramp_build(name: String, from_tube: Tube, from_t: float, to_tube: Tube, to_t: float,
		pts: Array, radii: Array, mouth_of: String) -> Road:
	if pts.size() < 2:
		problems.append("ramp %s has no shape" % name)
		return null
	# Every corner's arc has to fit its legs: the tangent length may not pass either
	# leg's midpoint. A ramp's radii are shrunk to what fits; the validator still
	# floors them at what the ship can turn, so a leg too short for a flyable bend is
	# reported rather than folded.
	for i in range(1, pts.size() - 1):
		var r := float(radii[i])
		if r <= 0.0:
			continue
		var a: Vector3 = ((pts[i] as Vector3) - (pts[i - 1] as Vector3))
		var b: Vector3 = ((pts[i + 1] as Vector3) - (pts[i] as Vector3))
		var ang := a.normalized().angle_to(b.normalized())
		if ang < deg_to_rad(0.05):
			continue
		var room := minf(a.length(), b.length()) * 0.5 - 1.0
		radii[i] = minf(r, room / maxf(tan(ang * 0.5), 0.001))
	var path := RoadPath.build(pts, radii, false)
	for c in path.problems():
		problems.append("%s: %s" % [name, c])
	var road := Road.make(name, "ramp", path, 1, RAMP_INSET)
	var tube := road.tubes[0]
	tube.route_name = from_tube.route_name if from_tube != null \
		else (to_tube.route_name if to_tube != null else "")
	var spacing := road.rib_spacing
	var record := {"road": road, "from_tube": from_tube, "from_t": from_t,
		"to_tube": to_tube, "to_t": to_t, "mouth_of": mouth_of,
		"exit_portal": null, "entry_portal": null, "gate": null}
	if from_tube != null:
		road.rib_phase = fposmod(-from_t, spacing)
		# Where the host's wall actually OPENS: the first point along the ramp where its
		# tube reaches through the host's wall — the collider's own rule, walked once.
		# The strip counts down to this, and the gate stands where the ramp has cleared
		# the wall entirely; both used to be guessed from the lead and the exit length.
		var opens_t := from_t
		var clears_t := from_t
		var t := 0.0
		var found_open := false
		while t < path.length:
			var wall := from_tube.local(tube.centre(t))
			var out: float = absf(float(wall["u"])) - from_tube.hw
			if not found_open and out + tube.hw > RoadCollider.OPEN_EPS:
				opens_t = float(wall["t"])
				found_open = true
			if out - tube.hw >= 0.0:
				clears_t = t
				break
			t += 10.0
		from_tube.junctions.append({"t": from_t, "kind": "exit",
			"label": _exit_label(record), "ramp": tube, "opens_at": opens_t})
		tube.junctions.append({"t": 0.0, "kind": "from", "label": "from " + from_tube.name,
			"ramp": from_tube})
		spots.append({"label": "Exit %s" % name, "tube": from_tube,
			"t": from_tube.path.wrap_t(from_t - 1500.0 * from_tube.direction)})
		# THE GATE: the permission surface where the ramp has cleared the wall (ADR 0084).
		var gate := RampGate.new()
		gate.name = "Gate " + name
		gate.tube = tube
		add_child(gate)
		var gt := clears_t + 60.0
		gate.place(tube.centre(gt), tube.travel_frame(gt)["fwd"],
			Vector2(road.carriageway_w, road.carriageway_h))
		_gates.append(gate)
		record["gate"] = gate
	else:
		road.rib_phase = fposmod(path.length - to_t, spacing)
		road.mouths.append({"t": 0.0, "label": name + " mouth"})
		record["entry_portal"] = _portal(tube.centre(0.0), tube.travel_frame(0.0)["fwd"],
			"TO " + _next_system(to_tube))
		spots.append({"label": "Mouth %s (entry)" % name, "tube": tube, "t": 200.0})
	if to_tube != null:
		to_tube.junctions.append({"t": to_t, "kind": "entry", "label": "entry " + name,
			"ramp": tube})
		tube.junctions.append({"t": path.length, "kind": "merge",
			"label": "merge " + to_tube.name, "ramp": to_tube})
		spots.append({"label": "Merge %s" % name, "tube": tube,
			"t": maxf(0.0, path.length - 2200.0)})
	else:
		road.mouths.append({"t": path.length, "label": name + " mouth"})
		record["exit_portal"] = _portal(tube.centre(path.length),
			tube.travel_frame(path.length)["fwd"],
			mouth_of if not mouth_of.is_empty() else "EXIT")
	_add_road(road)
	ramps.append(record)
	return road


func _exit_label(record: Dictionary) -> String:
	var mouth: String = record["mouth_of"]
	if not mouth.is_empty():
		return mouth
	var to: Tube = record["to_tube"]
	return to.route_name if to != null and not to.route_name.is_empty() else "exit"


## The last system along a carriageway, for an entry mouth's label.
func _next_system(tube: Tube) -> String:
	if tube == null:
		return "the road"
	var systems: Array = tube.road.get_meta("systems", [])
	if systems.is_empty():
		return tube.route_name
	return String(systems[systems.size() - 1] if tube.direction == 1 else systems[0])


func _portal(at: Vector3, direction: Vector3, label: String) -> Portal:
	var portal := Portal.new()
	portal.name = "Portal " + label.validate_node_name()
	portal.destination = label
	add_child(portal)
	portal.place(at, direction)
	_portals.append(portal)
	return portal


## Neighbours, bend spots and validation.
func _finish() -> void:
	for a in tubes:
		for b in tubes:
			if a.road != b.road and a.bounds.intersects(b.bounds):
				a.neighbours.append(b)
	# A ramp's head and tail run inside its host's building, coincident with the host
	# carriageway, so the ramp's wall there IS the median. It must not open into the
	# host's other carriageway, nor that carriageway into it: the one wall-open rule
	# (a point through the wall is inside a neighbour) would see the other carriageway
	# a quarter-metre through the median and open a hole across the road. SEALED, not
	# un-neighboured: the ramp's rib collars poke into that carriageway and it has to
	# go on clipping them (`Tube.sealed`).
	for ramp in ramps:
		var road: Road = ramp["road"]
		for host: Tube in [ramp["from_tube"], ramp["to_tube"]]:
			if host == null:
				continue
			for other in host.road.tubes:
				if other == host:
					continue
				for t in road.tubes:
					if not t.sealed.has(other):
						t.sealed.append(other)
					if not other.sealed.has(t):
						other.sealed.append(t)
	for road in roads:
		if road.kind != "highway":
			continue
		var k := 0
		for c in road.path.corners:
			k += 1
			for tube in road.tubes:
				var t: float = road.path.wrap_t(float(c["t"]) - 1500.0 * tube.direction)
				if tube.direction == -1:
					t = road.path.wrap_t(float(c["t"])
						+ float(c["radius"]) * deg_to_rad(float(c["angle_deg"])) + 1500.0)
				spots.append({"label": "Bend %d %s (r=%dm)" % [k, tube.name, int(c["radius"])],
					"tube": tube, "t": t})
	_validate()


## The road may not ask for more than `road_turn_share` of the ship's turn rate
## (ADR 0096); a highway may not pitch past `road_pitch_max_deg`; no ramp leg may sit
## inside a tube it is not meant to join; two highways may not touch. Problems are
## reported, never silently fixed.
func _validate() -> void:
	var v := Tuning.num("exploration/cruise_speed")
	var w := deg_to_rad(Tuning.num("exploration/cruise_turn_rate_deg_per_sec"))
	var share := clampf(Tuning.num("exploration/road_turn_share"), 0.05, 1.0)
	var ramp_share := clampf(Tuning.num("exploration/ramp_turn_share"), 0.05, 1.0)
	var pitch_max := Tuning.num("exploration/road_pitch_max_deg")
	for road in roads:
		# A ramp may bend harder than a highway: it is short, it is taken on purpose,
		# and a ramp built to a highway's bends is a ramp no engineer would build.
		var s := ramp_share if road.kind == "ramp" else share
		var r_needed := v / (s * w)
		var r := road.path.min_radius()
		if r < r_needed:
			problems.append("%s: bend radius %.0f m under the %.0f m that %.0f%% of the turn rate allows" % [
				road.name, r, r_needed, s * 100.0])
		if road.kind == "highway" and road.path.max_pitch_deg() > pitch_max + 0.01:
			problems.append("%s: pitch %.1f deg over road_pitch_max_deg" % [
				road.name, road.path.max_pitch_deg()])
	# An exit's diverging leg must carry the ramp clear of the host's wall, and an
	# entry's drop must carry it under the host's floor, or the ramp never leaves.
	var hw := Tuning.num("exploration/lane_width") * 0.5
	var hh := Tuning.num("exploration/lane_height") * 0.5
	var reaches := Tuning.num("exploration/ramp_exit_length") \
		* sin(deg_to_rad(Tuning.num("exploration/ramp_exit_angle_deg")))
	if reaches < hw * 2.0 - RAMP_INSET + 20.0:
		problems.append("ramp_exit_length x sin(ramp_exit_angle_deg) is %.0f m: an exit must move %.0f m sideways to clear the wall" % [
			reaches, hw * 2.0 - RAMP_INSET + 20.0])
	if Tuning.num("exploration/ramp_merge_drop") < hh * 2.0 + _floor_thickness + 10.0:
		problems.append("ramp_merge_drop %.0f m does not put an entry under the host's floor (needs %.0f)" % [
			Tuning.num("exploration/ramp_merge_drop"), hh * 2.0 + _floor_thickness + 10.0])
	var head := Tuning.num("exploration/ramp_exit_lead") \
		+ Tuning.num("exploration/ramp_exit_length") + 600.0
	var tail := Tuning.num("exploration/ramp_merge_lead") \
		+ Tuning.num("exploration/ramp_merge_drop") \
			/ tan(deg_to_rad(Tuning.num("exploration/ramp_merge_pitch_deg"))) + 400.0
	for ramp in ramps:
		var road: Road = ramp["road"]
		var tube: Tube = road.tubes[0]
		var from_road: Road = (ramp["from_tube"] as Tube).road if ramp["from_tube"] != null else null
		var to_road: Road = (ramp["to_tube"] as Tube).road if ramp["to_tube"] != null else null
		var t := 0.0
		var reported := 0
		while t < road.path.length:
			var p := tube.centre(t)
			for other in tubes:
				if other.road == road:
					continue
				var in_head := from_road != null and t < head
				var in_tail := to_road != null and t > road.path.length - tail
				if (other.road == from_road and in_head) or (other.road == to_road and in_tail):
					continue
				# Inside its host, a ramp shares the building with the host's other ramps;
				# only one on the SAME carriageway can actually be in its way.
				if (in_head or in_tail) and other.is_ramp():
					var host: Tube = ramp["from_tube"] if in_head else ramp["to_tube"]
					var theirs := ramp_of(other)
					if not theirs.is_empty() and theirs["from_tube"] != host and theirs["to_tube"] != host:
						continue
				var l := other.local(p)
				if not other.t_in_range(l["t"]) or absf(float(l["w"])) > 1.0:
					continue
				var clear_u := absf(float(l["u"])) - other.hw - tube.hw
				var clear_v := absf(float(l["v"])) - other.hh - tube.hh - _floor_thickness
				if maxf(clear_u, clear_v) < 15.0 and reported < 3:
					problems.append("%s at t=%.0f has %.0f m clearance from %s (t=%.0f)" % [
						road.name, t, maxf(clear_u, clear_v), other.name, l["t"]])
					reported += 1
			t += 100.0
	for a in roads:
		for b in roads:
			if a.kind != "highway" or b.kind != "highway" or a.name >= b.name:
				continue
			var t := 0.0
			while t < a.path.length:
				var p := a.path.at(t, 0.0, 0.0)
				var hit := false
				for other in b.tubes:
					if other.contains(p, -(a.half_width + a.half_height + 60.0)):
						var l := other.local(p)
						if absf(float(l["v"])) < a.half_height + other.hh + 40.0:
							problems.append("%s and %s too close near %s" % [a.name, b.name, p])
							hit = true
				if hit:
					break
				t += 100.0


# --- streaming ---------------------------------------------------------------

func _plan_chunks() -> void:
	for road in roads:
		var foreign: Array[Tube] = []
		for tube in road.tubes:
			for n in tube.neighbours:
				if not foreign.has(n):
					foreign.append(n)
		# The far version leaves a ramp's head and tail out: unclipped, they would stand
		# inside the carriageway the ramp joins.
		var far_from := 0.0
		var far_to := road.path.length
		if road.kind == "ramp":
			var record := ramp_of(road.tubes[0])
			if not record.is_empty() and record["from_tube"] != null:
				far_from = Tuning.num("exploration/ramp_exit_lead") \
					+ Tuning.num("exploration/ramp_exit_length") + 400.0
			if not record.is_empty() and record["to_tube"] != null:
				far_to = road.path.length - Tuning.num("exploration/ramp_merge_lead") \
					- Tuning.num("exploration/ramp_merge_drop") \
						/ tan(deg_to_rad(Tuning.num("exploration/ramp_merge_pitch_deg"))) - 400.0
		for chunk in RoadMesh.plan(road):
			chunk["road"] = road
			chunk["foreign"] = foreign
			chunk["key"] = "%s/%d" % [road.name, chunk["index"]]
			_chunks.append(chunk)
			var far := RoadMesh.build_far(road, chunk, far_from, far_to, _floor_thickness, _beam)
			_mesh_root.add_child(far)
			_far[chunk["key"]] = far


## Light the road around `here`: the track lights follow the ship along the tube it
## rides, or the nearest one. Called every frame by the map, with the streaming.
func light(here: Vector3, riding: Tube) -> void:
	if lamps != null:
		lamps.follow(here, riding, tubes)


## Build the chunks near `here` and drop the ones far from it. Called every frame by
## the map. Worker threads build; this thread commits.
func stream(here: Vector3) -> void:
	var radius := Tuning.num("exploration/road_detail_radius")
	var done: Array = []
	for key: String in _pending:
		var job: Dictionary = _pending[key]
		if WorkerThreadPool.is_task_completed(job["task"]):
			WorkerThreadPool.wait_for_task_completion(job["task"])
			done.append(key)
	for key: String in done:
		var job: Dictionary = _pending[key]
		_pending.erase(key)
		_commit_chunk(job["chunk"], job["out"])
	var gone: Array = []
	for key: String in _loaded:
		var chunk := _chunk_named(key)
		if chunk.is_empty():
			continue
		if (chunk["centre"] as Vector3).distance_to(here) > radius * 1.5 + float(chunk["reach"]):
			gone.append(key)
	for key: String in gone:
		(_loaded[key] as Node3D).queue_free()
		_loaded.erase(key)
		var far: Node3D = _far.get(key)
		if far != null:
			far.visible = true
	var wanted: Array = []
	for chunk in _chunks:
		var key: String = chunk["key"]
		if _loaded.has(key) or _pending.has(key):
			continue
		var d := (chunk["centre"] as Vector3).distance_to(here) - float(chunk["reach"])
		if d <= radius:
			wanted.append([d, chunk])
	wanted.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as float) < (b[0] as float))
	var started := 0
	for pair: Array in wanted:
		if _pending.size() >= WORKERS or started >= BUILDS_PER_FRAME:
			break
		var chunk: Dictionary = pair[1]
		var out := {}
		var task := WorkerThreadPool.add_task(_build_job.bind(chunk, out))
		_pending[chunk["key"]] = {"chunk": chunk, "out": out, "task": task}
		started += 1


func _build_job(chunk: Dictionary, out: Dictionary) -> void:
	var built := RoadMesh.build_chunk(chunk["road"], chunk["foreign"], chunk,
		_floor_thickness, _beam, false)
	out["verts"] = built["verts"]
	out["norms"] = built["norms"]


func _commit_chunk(chunk: Dictionary, built: Dictionary) -> void:
	var node := RoadMesh.commit(chunk["road"], chunk["index"], built)
	# The rib lamps come with the detailed chunk and go with it (`RoadLamps`).
	node.add_child(RoadLamps.fixtures(chunk["road"], chunk))
	_mesh_root.add_child(node)
	_loaded[chunk["key"]] = node
	# The far version of this stretch steps aside for the detailed one.
	var far: Node3D = _far.get(chunk["key"])
	if far != null:
		far.visible = false


func _chunk_named(key: String) -> Dictionary:
	for chunk in _chunks:
		if chunk["key"] == key:
			return chunk
	return {}


## Break the reference cycles between roads, their tubes and their neighbours, so a
## torn-down network is actually freed rather than leaked on every hot reload.
func _release() -> void:
	for t in tubes:
		t.road = null
		t.neighbours.clear()
		t.sealed.clear()
		t.junctions.clear()
	for r in roads:
		r.tubes.clear()
	for ramp in ramps:
		ramp.clear()
	roads.clear()
	tubes.clear()
	ramps.clear()
	spots.clear()


func _cancel_pending() -> void:
	for key: String in _pending:
		WorkerThreadPool.wait_for_task_completion((_pending[key] as Dictionary)["task"])
	_pending.clear()


func _exit_tree() -> void:
	_cancel_pending()
	_release()


## Build EVERY chunk now, on this thread, and return every road's triangles by road
## name. For the gate, which fires rays at the rendered surfaces; nothing in the game
## calls it.
func build_all_now() -> Dictionary:
	_cancel_pending()
	var faces := {}
	for chunk in _chunks:
		var built := RoadMesh.build_chunk(chunk["road"], chunk["foreign"], chunk,
			_floor_thickness, _beam, true)
		if not _loaded.has(chunk["key"]):
			_commit_chunk(chunk, built)
		var road: Road = chunk["road"]
		if not faces.has(road.name):
			faces[road.name] = PackedVector3Array()
		# A typed assignment shares the packed array; an `as` cast would copy it.
		var into: PackedVector3Array = faces[road.name]
		into.append_array(built["faces"])
	return faces


func loaded_chunk_count() -> int:
	return _loaded.size()


func chunk_count() -> int:
	return _chunks.size()


# --- what the map asks ---------------------------------------------------------

func portals() -> Array[Portal]:
	return _portals


func gates() -> Array[RampGate]:
	return _gates


## Blue or red on every mouth and gate, against the hull the player is flying now
## (ADR 0060), and whether any ramp may be taken (ADR 0084).
func set_permitted(allowed: bool) -> void:
	for tube in tubes:
		tube.passable = allowed
	for portal in _portals:
		portal.permitted = allowed


## Which tube the ship is riding, so its markings draw brighter (ADR 0096).
func set_active(riding: Tube) -> void:
	if riding == _active:
		return
	_active = riding
	_paint_markings()


func repaint() -> void:
	RoadMesh.refresh_materials()
	_paint_markings()
	for gate in _gates:
		gate.rebuild()
	for portal in _portals:
		portal.rebuild()


func _paint_markings() -> void:
	for tube in tubes:
		var lines: MeshInstance3D = _markings.get(tube.name)
		if lines != null:
			RoadMesh.paint_markings(lines, tube, tube == _active)


func tube_named(n: String) -> Tube:
	for t in tubes:
		if t.name == n:
			return t
	return null


func road_named(n: String) -> Road:
	for r in roads:
		if r.name == n:
			return r
	return null


## The ramp record whose tube this is, or empty.
func ramp_of(tube: Tube) -> Dictionary:
	for ramp in ramps:
		if (ramp["road"] as Road).tubes[0] == tube:
			return ramp
	return {}


## The first highway's centre-line as points, for the deep field to scatter around.
func spine() -> PackedVector3Array:
	for road in roads:
		if road.kind == "highway":
			return road.path.points(200.0)
	return PackedVector3Array()
