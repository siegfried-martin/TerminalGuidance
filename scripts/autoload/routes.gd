extends Node
## Loads `data/routes.json` and hot-reloads it whenever the file changes on disk.
##
## The road is data now (ADR 0095). A route is a polyline of lattice cells, and
## saving this file relays the map out under the player — which matters more than it
## looks. The feel-parameter law exists because a slider dragged while watching is a
## different instrument from a number typed in another window, and retiring the weave
## sliders costs that loop unless the route data reloads live too.
##
## Modelled on `Tuning`: a throwaway parse first, so a half-written file mid-save
## cannot wipe the map out from under a running session, and a loud error rather than
## a plausible default.
##
## It also carries the JUNCTION TILE CATALOGUE, which is read from the sidecars beside
## the `.obj` files in `assets/models/`. A tile is an asset and does not hot-reload
## the way the routes do, but it is re-scanned on every reload so `make assets`
## followed by F5 is enough.

signal reloaded

const PATH := "res://data/routes.json"
const TILE_DIR := "res://assets/models"
const TILE_PREFIX := "road_junction_"
## Infrastructure constant, not a feel value: how often the file is stat'd.
const POLL_INTERVAL_SEC := 0.25

## The tuning keys the road's geometry is bounded by, read in one place so the gate
## and the builder cannot disagree about which they are.
const LIMIT_KEYS: PackedStringArray = [
	"cruise_speed", "cruise_turn_rate_deg_per_sec", "lane_width", "lane_height",
	"deck_separation", "road_pitch_max_deg", "road_fillet_radius",
]

var _anchors: Dictionary = {}
var _routes: Dictionary = {}
var _order: PackedStringArray = PackedStringArray()
var _tiles: Dictionary = {}
var _errors: PackedStringArray = PackedStringArray()
var _load_error: String = ""
var _last_mtime: int = 0
var _poll_accum: float = 0.0
var _reload_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The bounds every route is checked against are tuned, so a tuning change
	# revalidates the map without the file on disk having moved.
	Tuning.reloaded.connect(_revalidate)
	reload()


func _process(delta: float) -> void:
	_poll_accum += delta
	if _poll_accum < POLL_INTERVAL_SEC:
		return
	_poll_accum = 0.0
	var mtime := FileAccess.get_modified_time(PATH)
	# 0 means "unknown" (exported build, packed res://): never reload on that.
	if mtime != 0 and mtime != _last_mtime:
		reload()


func reload() -> void:
	var mtime := FileAccess.get_modified_time(PATH)
	var text := FileAccess.get_file_as_string(PATH)
	if text.is_empty():
		_fail("cannot read %s" % PATH)
		_last_mtime = mtime
		return
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("%s must be a JSON object" % PATH)
		_last_mtime = mtime
		return

	# Parse into throwaways first: a half-written file mid-save must not empty the
	# map out from under a running session.
	var anchors := _parse_anchors(parsed as Dictionary)
	var routes := {}
	var order := PackedStringArray()
	var listed: Variant = (parsed as Dictionary).get("routes", null)
	if typeof(listed) != TYPE_DICTIONARY:
		_fail("%s needs a \"routes\" object" % PATH)
		_last_mtime = mtime
		return
	for route_name: String in (listed as Dictionary):
		var entry: Variant = (listed as Dictionary)[route_name]
		if typeof(entry) != TYPE_DICTIONARY:
			_fail("%s: route \"%s\" must be an object" % [PATH, route_name])
			continue
		routes[route_name] = RouteSpec.parse(route_name, entry as Dictionary, anchors)
		order.append(route_name)

	_anchors = anchors
	_routes = routes
	_order = order
	_tiles = _load_tiles()
	_last_mtime = mtime
	_load_error = ""
	_reload_count += 1
	_revalidate()


func _parse_anchors(data: Dictionary) -> Dictionary:
	var out := {}
	var listed: Variant = data.get("anchors", {})
	if typeof(listed) != TYPE_DICTIONARY:
		_fail("%s: \"anchors\" must be an object" % PATH)
		return out
	for anchor: String in (listed as Dictionary):
		var entry: Variant = (listed as Dictionary)[anchor]
		if typeof(entry) != TYPE_DICTIONARY:
			_fail("%s: anchor \"%s\" must be an object" % [PATH, anchor])
			continue
		var cell: Variant = (entry as Dictionary).get("cell", null)
		if typeof(cell) != TYPE_ARRAY or (cell as Array).size() != 2:
			_fail("%s: anchor \"%s\" needs a \"cell\" of [q, r]" % [PATH, anchor])
			continue
		var placed := {"cell": Vector2i(int((cell as Array)[0]), int((cell as Array)[1]))}
		if (entry as Dictionary).has("level"):
			placed["level"] = int((entry as Dictionary)["level"])
		out[anchor] = placed
	return out


## The junction catalogue: every `road_junction_*.json` sidecar in `assets/models`.
## Scanned rather than listed, so a tile the generator has just emitted needs no
## code change to be usable.
func _load_tiles() -> Dictionary:
	var out := {}
	var dir := DirAccess.open(TILE_DIR)
	if dir == null:
		_fail("cannot open %s" % TILE_DIR)
		return out
	for file in dir.get_files():
		if not file.begins_with(TILE_PREFIX) or not file.ends_with(".json"):
			continue
		var tile_name := file.substr(TILE_PREFIX.length(),
			file.length() - TILE_PREFIX.length() - ".json".length())
		var text := FileAccess.get_file_as_string("%s/%s" % [TILE_DIR, file])
		var parsed: Variant = JSON.parse_string(text)
		if typeof(parsed) != TYPE_DICTIONARY:
			_fail("%s/%s is not a JSON object" % [TILE_DIR, file])
			continue
		out[tile_name] = RoadTile.parse(tile_name, parsed as Dictionary)
	return out


# --- Validation --------------------------------------------------------------

## Every reason the map on disk could not be built, by name. Runs on load and again
## whenever tuning moves, because the bounds are tuned.
func _revalidate() -> void:
	var limits := RoadLimits.new(tuned_limits())
	var lattice := make_lattice()
	_errors = PackedStringArray()
	for tile_name: String in _tiles:
		var tile := _tiles[tile_name] as RoadTile
		_errors.append_array(tile.parse_errors)
		_errors.append_array(tile.section_matches(tuned_section()))
		_errors.append_array(_check_tile(tile, lattice, limits))
	for route_name in _order:
		var spec := _routes[route_name] as RouteSpec
		_errors.append_array(spec.validate(lattice, limits.fillet_radius(),
			limits.half_width(spec.profile), limits.half_height(),
			limits.pitch_max_deg, _tiles))
		_errors.append_array(_check_links(spec))
	reloaded.emit()


## A tile's own contract (plan section 6.1): its footprint is a lattice vector in the
## family tiles are generated for, its socket lands on a cell, its runs start and end
## where it says they do, its apertures lie inside their run, and nothing it declares
## turns tighter than the ship can fly.
func _check_tile(tile: RoadTile, lattice: HexLattice,
		limits: RoadLimits) -> PackedStringArray:
	var errors := PackedStringArray()
	if tile.footprint == Vector2i.ZERO:
		errors.append("%s: footprint has no length" % tile.name)
		return errors
	if not HexLattice.is_axial_family(tile.footprint):
		errors.append("%s: footprint (%d,%d) is not in the (n, 0) family tiles are generated for"
			% [tile.name, tile.footprint.x, tile.footprint.y])
	var socket := lattice.to_world(tile.socket_cell, tile.socket_level)
	if not lattice.is_lattice_vector(socket):
		errors.append("%s: ramp socket (%d,%d) is not a lattice cell"
			% [tile.name, tile.socket_cell.x, tile.socket_cell.y])
	var ramp := tile.run("ramp")
	if ramp.size() < 2:
		errors.append("%s: the ramp run needs at least two points" % tile.name)
		return errors
	var landing := ramp[ramp.size() - 1]
	# Closure, to the millimetre. The whole reason the fitted cubic went away.
	var miss := minf(landing.distance_to(socket), ramp[0].distance_to(socket))
	if miss > 0.001:
		errors.append("%s: the ramp run misses its own socket by %.3f m" % [tile.name, miss])
	for run_name: String in tile.lane_runs:
		var path := RoadPath.new()
		path.set_points(tile.run(run_name))
		var demanded := limits.demanded_turn_rate(path.max_turn_deg_per_metre())
		if demanded > limits.turn_rate_deg_per_sec + 0.001:
			errors.append("%s run \"%s\": demands %.1f deg/s at cruise, and the ship turns at %.1f"
				% [tile.name, run_name, demanded, limits.turn_rate_deg_per_sec])
		var pitch := _steepest_pitch(tile.run(run_name))
		if pitch > limits.pitch_max_deg + 0.001:
			errors.append("%s run \"%s\": pitches %.2f deg, past road_pitch_max_deg %.1f"
				% [tile.name, run_name, pitch, limits.pitch_max_deg])
	for aperture in tile.apertures:
		var path := RoadPath.new()
		path.set_points(tile.run(String(aperture["run"])))
		var span := path.length()
		var from := float(aperture["from"])
		var to := float(aperture["to"])
		if from < -0.001 or to > span + 0.001 or to <= from:
			errors.append("%s: aperture %.0f..%.0f m lies outside its %.0f m \"%s\" run"
				% [tile.name, from, to, span, aperture["run"]])
	return errors


## A lane route's ends. Checked here rather than in `RouteSpec` because it is the
## only place every route is known at once.
func _check_links(spec: RouteSpec) -> PackedStringArray:
	var errors := PackedStringArray()
	if not spec.is_lane():
		return errors
	errors.append_array(_check_socket(spec.name, "from", spec.from_route,
		spec.from_vertex))
	if not spec.to_route.is_empty():
		errors.append_array(_check_socket(spec.name, "to", spec.to_route,
			spec.to_vertex))
	return errors


func _check_socket(lane: String, end: String, route_name: String,
		vertex: int) -> PackedStringArray:
	var errors := PackedStringArray()
	if not _routes.has(route_name):
		errors.append("%s: \"%s\" names route \"%s\", which is not on the map"
			% [lane, end, route_name])
		return errors
	var host := _routes[route_name] as RouteSpec
	if vertex < 0 or vertex >= host.vertex_count():
		errors.append("%s: \"%s\" names vertex %d of \"%s\", which has %d"
			% [lane, end, vertex, route_name, host.vertex_count()])
		return errors
	if host.junctions[vertex].is_empty():
		errors.append("%s: \"%s\" names vertex %d of \"%s\", which carries no junction"
			% [lane, end, vertex, route_name])
	return errors


static func _steepest_pitch(points: PackedVector3Array) -> float:
	var worst := 0.0
	for i in range(1, points.size()):
		var step := points[i] - points[i - 1]
		var run := Vector2(step.x, step.z).length()
		if run <= 0.001:
			continue
		worst = maxf(worst, rad_to_deg(atan2(absf(step.y), run)))
	return worst


# --- Reading -----------------------------------------------------------------

func make_lattice() -> HexLattice:
	return HexLattice.new(Tuning.num("exploration/lattice_cell_metres"),
		Tuning.num("exploration/lattice_level_metres"))


func limits() -> RoadLimits:
	return RoadLimits.new(tuned_limits())


func tuned_limits() -> Dictionary:
	var out := {}
	for key in LIMIT_KEYS:
		out[key] = Tuning.num("exploration/" + key)
	return out


## The section a junction tile must have been generated against.
func tuned_section() -> Dictionary:
	var out := {}
	for key in RoadTile.SECTION_KEYS:
		out[key] = Tuning.num("exploration/" + key)
	return out


func route(route_name: String) -> RouteSpec:
	return _routes.get(route_name, null) as RouteSpec


func route_names() -> PackedStringArray:
	return _order


func all_routes() -> Array[RouteSpec]:
	var out: Array[RouteSpec] = []
	for route_name in _order:
		out.append(_routes[route_name] as RouteSpec)
	return out


func anchors() -> Dictionary:
	return _anchors


func anchor_cell(anchor: String) -> Vector2i:
	if not _anchors.has(anchor):
		return Vector2i.ZERO
	return (_anchors[anchor] as Dictionary)["cell"] as Vector2i


func tile(tile_name: String) -> RoadTile:
	return _tiles.get(tile_name, null) as RoadTile


func tiles() -> Dictionary:
	return _tiles


## Everything wrong with the map, as lines a human can act on. Empty means it builds.
func errors() -> PackedStringArray:
	return _errors


func load_error() -> String:
	return _load_error


func reload_count() -> int:
	return _reload_count


func _fail(message: String) -> void:
	_load_error = message
	push_error("Routes: " + message)
