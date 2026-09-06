class_name RouteSpec
extends RefCounted
## One route from `data/routes.json`, parsed and checkable. Pure — no scene tree,
## no tuning, no disk. `Routes` reads the file; this is the shape it reads into.
##
## A route is **vertices**; a vertex is a **cell and a level**; a junction is an
## **annotation on the edge leaving a vertex** (ADR 0095). Nothing here is measured:
## every direction change is an angle between two exact lattice vectors, and every
## junction is a tile whose footprint is exactly the edge it occupies.
##
## `validate()` is the point of the class. The old road derived its geometry from a
## curve and then measured what came out, and nearly every highway bug from ADR 0087
## to 0094 was a measurement standing in for a decision. Here the decision is in the
## data and the gate rejects data that cannot be built, by name, before anything is
## laid out.

## A `pair` route is the mainline: two carriageways either side of a spine. A `lane`
## route is a ramp: one carriageway, from a junction socket to a portal or another
## junction.
const PROFILES: PackedStringArray = ["pair", "lane"]

var name: String = ""
var profile: String = "pair"
## The route's default level. A vertex may override it; an edge between two levels
## is a pitched straight.
var level: int = 0

## One entry per vertex, all the same length.
var cells: Array[Vector2i] = []
var levels: PackedInt32Array = PackedInt32Array()
## The anchor a vertex was named by, or "" for a bare cell. Anchors carry the story
## content later (faction, name, market); none of that is on the road.
var anchor_names: PackedStringArray = PackedStringArray()
## The junction tile occupying the edge LEAVING this vertex, or "" for a plain edge.
var junctions: PackedStringArray = PackedStringArray()

## A `lane` route's upstream end: the junction socket it starts at.
var from_route: String = ""
var from_vertex: int = -1
var from_carriageway: String = ""
## A `lane` route's downstream end: a portal (a mouth) or another junction.
var to_portal: String = ""
var to_route: String = ""
var to_vertex: int = -1

## Everything wrong with the JSON itself, found while parsing. `validate()` reports
## these first and then stops, because geometry checks on half-parsed data are noise.
var parse_errors: PackedStringArray = PackedStringArray()


func vertex_count() -> int:
	return cells.size()


func is_lane() -> bool:
	return profile == "lane"


## The route's vertices in world space. The polyline the building is stepped along
## and, once filleted, the lane.
func world_vertices(lattice: HexLattice) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in cells.size():
		out.append(lattice.to_world(cells[i], levels[i]))
	return out


## The lattice vector of the edge leaving vertex `i`.
func edge(i: int) -> Vector2i:
	return cells[i + 1] - cells[i]


# --- Parsing -----------------------------------------------------------------

## Read one route. `anchors` maps an anchor name to `{cell, level}`; a vertex may
## name one instead of giving a cell, and both are exact.
static func parse(route_name: String, data: Dictionary,
		anchors: Dictionary) -> RouteSpec:
	var spec := RouteSpec.new()
	spec.name = route_name
	if data.has("profile"):
		spec.profile = String(data["profile"])
	if data.has("level"):
		spec.level = int(data["level"])

	var listed: Variant = data.get("vertices", null)
	if typeof(listed) != TYPE_ARRAY:
		spec._note("%s: \"vertices\" must be an array" % route_name)
		return spec

	var index := 0
	for entry: Variant in (listed as Array):
		if typeof(entry) != TYPE_DICTIONARY:
			spec._note("%s vertex %d: must be an object" % [route_name, index])
			index += 1
			continue
		var vertex := entry as Dictionary
		var cell := Vector2i.ZERO
		var at_level := spec.level
		var anchor := ""
		if vertex.has("at"):
			anchor = String(vertex["at"])
			if not anchors.has(anchor):
				spec._note("%s vertex %d: no anchor named \"%s\"" % [
					route_name, index, anchor])
			else:
				var placed := anchors[anchor] as Dictionary
				cell = placed["cell"] as Vector2i
				if placed.has("level"):
					at_level = int(placed["level"])
		elif vertex.has("cell"):
			var pair: Variant = vertex["cell"]
			if typeof(pair) != TYPE_ARRAY or (pair as Array).size() != 2:
				spec._note("%s vertex %d: \"cell\" must be [q, r]" % [route_name, index])
			else:
				cell = Vector2i(int((pair as Array)[0]), int((pair as Array)[1]))
		else:
			spec._note("%s vertex %d: needs a \"cell\" or an \"at\"" % [route_name, index])
		if vertex.has("level"):
			at_level = int(vertex["level"])
		spec.cells.append(cell)
		spec.levels.append(at_level)
		spec.anchor_names.append(anchor)
		spec.junctions.append(String(vertex["junction"]) if vertex.has("junction") else "")
		index += 1

	if data.has("from"):
		var from: Variant = data["from"]
		if typeof(from) != TYPE_DICTIONARY:
			spec._note("%s: \"from\" must be an object" % route_name)
		else:
			spec.from_route = String((from as Dictionary).get("route", ""))
			spec.from_vertex = int((from as Dictionary).get("vertex", -1))
			spec.from_carriageway = String((from as Dictionary).get("carriageway", ""))
	if data.has("to"):
		var to: Variant = data["to"]
		if typeof(to) != TYPE_DICTIONARY:
			spec._note("%s: \"to\" must be an object" % route_name)
		else:
			spec.to_portal = String((to as Dictionary).get("portal", ""))
			spec.to_route = String((to as Dictionary).get("route", ""))
			spec.to_vertex = int((to as Dictionary).get("vertex", -1))
	return spec


func _note(message: String) -> void:
	parse_errors.append(message)


# --- Validation --------------------------------------------------------------

## Every bound in section 5 of `docs/HIGHWAY_LATTICE_PLAN.md`, on every vertex and
## every edge, as a list of exact, actionable errors. Empty means the route builds.
##
## `half_width` is the building's half-width across (`deck_separation/2 +
## lane_width/2` for a pair, `lane_width/2` for a lane) and `half_height` is
## `lane_height/2`. `tiles` maps a junction name to its `RoadTile`.
func validate(lattice: HexLattice, fillet_radius: float, half_width: float,
		half_height: float, pitch_max_deg: float,
		tiles: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray(parse_errors)
	if not errors.is_empty():
		return errors
	if not PROFILES.has(profile):
		errors.append("%s: profile \"%s\" is not one of %s" % [
			name, profile, ", ".join(PROFILES)])
		return errors
	if cells.size() < 2:
		errors.append("%s: a route needs at least two vertices, has %d" % [
			name, cells.size()])
		return errors

	_check_ends(errors)
	_check_edges(errors, lattice, pitch_max_deg)
	_check_junctions(errors, lattice, tiles)
	_check_vertices(errors, lattice, fillet_radius, half_width, half_height)
	return errors


## A `pair` route runs from nowhere to nowhere — it is the mainline, and its ends are
## stubs past the last system. A `lane` route is a ramp and both of its ends are
## named: it starts at a junction's socket and ends at a portal or another junction.
## That is what makes closure free rather than fitted.
func _check_ends(errors: PackedStringArray) -> void:
	if is_lane():
		if from_route.is_empty() or from_vertex < 0:
			errors.append("%s: a lane route needs a \"from\" naming a route and vertex"
				% name)
		if from_carriageway != "forward" and from_carriageway != "reverse":
			errors.append("%s: \"from.carriageway\" must be \"forward\" or \"reverse\", got \"%s\""
				% [name, from_carriageway])
		if to_portal.is_empty() and (to_route.is_empty() or to_vertex < 0):
			errors.append("%s: a lane route needs a \"to\" naming a portal or a junction"
				% name)
		return
	if not from_route.is_empty() or not to_portal.is_empty() or not to_route.is_empty():
		errors.append("%s: only a lane route carries \"from\" and \"to\"" % name)


func _check_edges(errors: PackedStringArray, lattice: HexLattice,
		pitch_max_deg: float) -> void:
	for i in cells.size() - 1:
		var step := edge(i)
		if step == Vector2i.ZERO:
			errors.append("%s vertex %d at %s: the edge to vertex %d has no length — %s"
				% [name, i, _cell_text(i), i + 1,
					"a vertical shaft is not a road"])
			continue
		var run := lattice.length_of(step)
		var rise := lattice.level_metres * float(levels[i + 1] - levels[i])
		var pitch := rad_to_deg(atan2(absf(rise), run))
		if pitch > pitch_max_deg + 0.001:
			errors.append("%s vertex %d at %s: the edge to %s pitches %.2f deg over %.0f m, past road_pitch_max_deg %.1f"
				% [name, i, _cell_text(i), _cell_text(i + 1), pitch, run, pitch_max_deg])


func _check_junctions(errors: PackedStringArray, lattice: HexLattice,
		tiles: Dictionary) -> void:
	for i in cells.size():
		var junction := junctions[i]
		if junction.is_empty():
			continue
		if i == cells.size() - 1:
			errors.append("%s vertex %d at %s: junction \"%s\" annotates the last vertex, which has no edge leaving it"
				% [name, i, _cell_text(i), junction])
			continue
		if not tiles.has(junction):
			errors.append("%s vertex %d at %s: no junction tile named \"%s\" — run `make assets`"
				% [name, i, _cell_text(i), junction])
			continue
		var tile := tiles[junction] as RoadTile
		var step := edge(i)
		var turns := HexLattice.rotation_between(tile.footprint, step)
		if turns < 0:
			errors.append("%s vertex %d at %s: junction \"%s\" has footprint %s, but the edge to %s is %s — the edge must be exactly the tile"
				% [name, i, _cell_text(i), junction, _vector_text(tile.footprint),
					_cell_text(i + 1), _vector_text(step)])
		if not HexLattice.is_axial_family(step):
			errors.append("%s vertex %d at %s: junction \"%s\" sits on the %s edge, and tiles are generated for the (n, 0) family only"
				% [name, i, _cell_text(i), junction, _vector_text(step)])
		if levels[i] != levels[i + 1]:
			errors.append("%s vertex %d at %s: junction \"%s\" spans a level change, and a tile is authored flat"
				% [name, i, _cell_text(i), junction])
		if tile.profile != profile:
			errors.append("%s vertex %d at %s: junction \"%s\" is a \"%s\" tile on a \"%s\" route"
				% [name, i, _cell_text(i), junction, tile.profile, profile])


func _check_vertices(errors: PackedStringArray, lattice: HexLattice,
		fillet_radius: float, half_width: float, half_height: float) -> void:
	var world := world_vertices(lattice)
	for i in range(1, world.size() - 1):
		var back := world[i] - world[i - 1]
		var ahead := world[i + 1] - world[i]
		if back.length() <= 0.001 or ahead.length() <= 0.001:
			continue
		var theta := back.normalized().angle_to(ahead.normalized())
		if theta <= RoadPath.FILLET_MIN_ANGLE_RAD:
			continue
		if theta >= PI - RoadPath.FILLET_MIN_ANGLE_RAD:
			errors.append("%s vertex %d at %s: the road doubles back on itself"
				% [name, i, _cell_text(i)])
			continue
		# The fillet's tangent points must not pass either edge's midpoint, or two
		# adjacent fillets overlap and the lane crosses itself.
		var tangent := fillet_radius * tan(theta * 0.5)
		var shortest := minf(back.length(), ahead.length())
		if tangent > shortest * 0.5 + 0.001:
			errors.append("%s vertex %d at %s: turning %.1f deg at a %.0f m fillet needs %.0f m of tangent, past half the %.0f m edge beside it"
				% [name, i, _cell_text(i), rad_to_deg(theta), fillet_radius,
					tangent, shortest])

	# The lane is what the hull is measured against, so a lane outside its own
	# building is the bug ADR 0087 fixed. Sampled rather than reasoned: the check is
	# conservative — 3D distance against the SMALLER half-extent — because a fillet
	# that needs the difference is a fillet nobody should be flying.
	var clearance := minf(half_width, half_height)
	var lane := RoadPath.fillet(world, fillet_radius, RoadPath.FILLET_SEGMENT_METRES)
	for point in lane:
		var nearest := INF
		for i in world.size() - 1:
			nearest = minf(nearest, _distance_to_segment(point, world[i], world[i + 1]))
		if nearest > clearance + 0.001:
			errors.append("%s: the filleted lane leaves its own building by %.0f m near %s, against %.0f m of clearance"
				% [name, nearest - clearance, _point_text(point), clearance])
			break


static func _distance_to_segment(point: Vector3, from: Vector3, to: Vector3) -> float:
	var run := to - from
	var span := run.length()
	if span <= 0.001:
		return point.distance_to(from)
	var along := clampf((point - from).dot(run / span), 0.0, span)
	return point.distance_to(from + (run / span) * along)


func _cell_text(i: int) -> String:
	var text := "(%d,%d)" % [cells[i].x, cells[i].y]
	return text if anchor_names[i].is_empty() else "%s %s" % [anchor_names[i], text]


static func _vector_text(cell: Vector2i) -> String:
	return "(%d,%d)" % [cell.x, cell.y]


static func _point_text(point: Vector3) -> String:
	return "(%.0f, %.0f, %.0f)" % [point.x, point.y, point.z]
