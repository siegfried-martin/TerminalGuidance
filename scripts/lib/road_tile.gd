class_name RoadTile
extends RefCounted
## One junction tile's sidecar, parsed. Pure — no scene tree, no tuning, no disk;
## `Routes` reads the files and hands the dictionaries here.
##
## A junction is the one place on the lattice road where geometry is **authored
## rather than stepped** (ADR 0095). Everything the old code measured about a
## junction — `crossing`, `overlap`, `_facing`, `_opposite`, span piercing,
## per-face trimming — is declared here instead, and each of those measurements had
## been wrong at least once. The tile occupies exactly one edge, its ramp socket is
## exactly one cell, and the ADR 0091 to 0093 rules (an aperture is a stretch; a
## roadway opens for the whole merge; an exit is cut and an entry troughs) become
## properties of the mesh rather than something a function works out per frame.
##
## THE LOCAL FRAME: the tile's origin is the start of the edge it occupies, the edge
## runs along `+X` (that is `e1`, due east), `+Y` is up. Traffic runs on the right
## (ADR 0077), so the forward carriageway is at `+Z` and the reverse at `-Z`. Placing
## the tile on an edge that runs at 60 or 120 degrees rotates the whole frame, and
## the socket offset with it — an exact lattice rotation, so the socket is still a
## cell (`HexLattice.rotate60`).

## The keys of `section`, which is what makes "run `make assets`" an assertion rather
## than a piece of folklore: a tile baked against one section on a road tuned to
## another is a gap, and the gate names it.
const SECTION_KEYS: PackedStringArray = [
	"lane_width", "lane_height", "deck_separation", "structure_rib_thickness",
	"lattice_cell_metres", "lattice_level_metres",
]

const FACE_NAMES: PackedStringArray = ["RIGHT", "LEFT", "ABOVE", "BELOW"]

var name: String = ""
## The lattice vector of the edge this tile occupies, written for an east-pointing
## edge. The route's edge must be exactly this, up to a 60-degree rotation.
var footprint: Vector2i = Vector2i.ZERO
## The profile of the road the tile carries, and of the ramp inside it.
var profile: String = "pair"
var ramp_profile: String = "lane"

## The ramp socket: a cell offset from the edge's start, a level offset, and a
## heading. The heading is ALWAYS along the edge (ADR 0070's tangential rule),
## authored rather than fitted.
var socket_cell: Vector2i = Vector2i.ZERO
var socket_level: int = 0
var socket_heading: Vector2i = Vector2i.ZERO

## One polyline per carriageway and one for the ramp, in the local frame, socket to
## socket. `RoadDeck` gets these; the ramp's is followed by the lane route's own
## filleted polyline.
var lane_runs: Dictionary = {}

## The buildings on the tile and the stretch of a run each covers.
## `[{ name, run, from, to, profile }]`. A mainline building covers its whole edge; a
## ramp's begins where the sidecar says, which is what makes an exit CUT rather than
## troughed (ADR 0092) a property of the tile rather than a runtime measurement.
var buildings: Array[Dictionary] = []

## Per building: the stretch of that building's own run that is open, and which face
## of it. `[{ building, run, from, to, face }]`, `face` an index into `Face`.
var apertures: Array[Dictionary] = []

## Where the `RampGate` sheen sits, and which way it faces. Only a tile you can
## leave the road through has one.
var has_gate: bool = false
var gate_at: Vector3 = Vector3.ZERO
var gate_facing: Vector3 = Vector3.FORWARD

## The section this tile was generated against.
var section: Dictionary = {}

var parse_errors: PackedStringArray = PackedStringArray()


static func parse(tile_name: String, data: Dictionary) -> RoadTile:
	var tile := RoadTile.new()
	tile.name = tile_name
	tile.footprint = tile._cell(data, "footprint")
	tile.profile = String(data.get("profile", "pair"))
	tile.ramp_profile = String(data.get("ramp_profile", "lane"))

	var sockets: Variant = data.get("sockets", null)
	if typeof(sockets) != TYPE_DICTIONARY or not (sockets as Dictionary).has("ramp"):
		tile._note("%s: needs a \"sockets\" object with a \"ramp\"" % tile_name)
	else:
		var ramp := (sockets as Dictionary)["ramp"] as Dictionary
		tile.socket_cell = tile._cell(ramp, "cell")
		tile.socket_level = int(ramp.get("level", 0))
		tile.socket_heading = tile._cell(ramp, "heading")

	var runs: Variant = data.get("lane_runs", null)
	if typeof(runs) != TYPE_DICTIONARY:
		tile._note("%s: needs a \"lane_runs\" object" % tile_name)
	else:
		for run_name: String in (runs as Dictionary):
			tile.lane_runs[run_name] = tile._points(
				(runs as Dictionary)[run_name], "%s run \"%s\"" % [tile_name, run_name])

	var housed: Variant = data.get("buildings", [])
	if typeof(housed) != TYPE_ARRAY:
		tile._note("%s: \"buildings\" must be an array" % tile_name)
	else:
		for entry: Variant in (housed as Array):
			if typeof(entry) != TYPE_DICTIONARY:
				tile._note("%s: each building must be an object" % tile_name)
				continue
			var housing := entry as Dictionary
			tile.buildings.append({
				"name": String(housing.get("name", "")),
				"run": String(housing.get("run", "")),
				"from": float(housing.get("from", 0.0)),
				"to": float(housing.get("to", 0.0)),
				"profile": String(housing.get("profile", "pair")),
			})
	if tile.buildings.is_empty():
		tile._note("%s: needs at least one building" % tile_name)

	var listed: Variant = data.get("apertures", [])
	if typeof(listed) != TYPE_ARRAY:
		tile._note("%s: \"apertures\" must be an array" % tile_name)
	else:
		for entry: Variant in (listed as Array):
			if typeof(entry) != TYPE_DICTIONARY:
				tile._note("%s: each aperture must be an object" % tile_name)
				continue
			var aperture := entry as Dictionary
			var face := FACE_NAMES.find(String(aperture.get("face", "")))
			if face < 0:
				tile._note("%s: aperture face \"%s\" is not one of %s" % [
					tile_name, aperture.get("face", ""), ", ".join(FACE_NAMES)])
				continue
			tile.apertures.append({
				"building": String(aperture.get("building", "")),
				"run": String(aperture.get("run", "")),
				"from": float(aperture.get("from", 0.0)),
				"to": float(aperture.get("to", 0.0)),
				"face": face,
			})

	# A gate is where the `RampGate` sheen sits, so only a tile you can LEAVE the
	# road through carries one. A merge has none: you are joining, not choosing.
	if data.has("gate"):
		var gate: Variant = data["gate"]
		if typeof(gate) != TYPE_DICTIONARY:
			tile._note("%s: \"gate\" must be an object" % tile_name)
		else:
			tile.has_gate = true
			tile.gate_at = tile._vector((gate as Dictionary).get("at", null))
			tile.gate_facing = tile._vector((gate as Dictionary).get("facing", null))

	var carried: Variant = data.get("section", null)
	if typeof(carried) != TYPE_DICTIONARY:
		tile._note("%s: needs a \"section\" it was generated against" % tile_name)
	else:
		for key in SECTION_KEYS:
			if not (carried as Dictionary).has(key):
				tile._note("%s: \"section\" is missing \"%s\"" % [tile_name, key])
			else:
				tile.section[key] = float((carried as Dictionary)[key])
	return tile


## Whether the section this tile was baked against still matches the tuned one.
## A tile is authored geometry and the straights around it are stepped live, so the
## two disagree the moment `lane_width` moves and nobody regenerates.
func section_matches(tuned: Dictionary) -> PackedStringArray:
	var drifted := PackedStringArray()
	for key in SECTION_KEYS:
		if not section.has(key) or not tuned.has(key):
			continue
		var baked := float(section[key])
		var now := float(tuned[key])
		if absf(baked - now) > 0.001:
			drifted.append("%s: baked against %s = %.3f, tuning.cfg now says %.3f — run `make assets`"
				% [name, key, baked, now])
	return drifted


## The socket's cell in the route's frame, given how far the edge is rotated off
## east. Levels do not rotate.
func socket_in(turns: int) -> Vector2i:
	return HexLattice.rotate60(socket_cell, turns)


## The building of a given name, or an empty dictionary.
func building(building_name: String) -> Dictionary:
	for housed in buildings:
		if String(housed["name"]) == building_name:
			return housed
	return {}


func run(run_name: String) -> PackedVector3Array:
	var found: Variant = lane_runs.get(run_name, null)
	return found as PackedVector3Array if found != null else PackedVector3Array()


func _cell(data: Dictionary, key: String) -> Vector2i:
	var pair: Variant = data.get(key, null)
	if typeof(pair) != TYPE_ARRAY or (pair as Array).size() != 2:
		_note("%s: \"%s\" must be [q, r]" % [name, key])
		return Vector2i.ZERO
	return Vector2i(int((pair as Array)[0]), int((pair as Array)[1]))


func _vector(value: Variant) -> Vector3:
	if typeof(value) != TYPE_ARRAY or (value as Array).size() != 3:
		_note("%s: expected [x, y, z]" % name)
		return Vector3.ZERO
	var listed := value as Array
	return Vector3(float(listed[0]), float(listed[1]), float(listed[2]))


func _points(value: Variant, what: String) -> PackedVector3Array:
	var out := PackedVector3Array()
	if typeof(value) != TYPE_ARRAY:
		_note("%s: must be an array of [x, y, z]" % what)
		return out
	for entry: Variant in (value as Array):
		if typeof(entry) != TYPE_ARRAY or (entry as Array).size() != 3:
			_note("%s: each point must be [x, y, z]" % what)
			continue
		var listed := entry as Array
		out.append(Vector3(float(listed[0]), float(listed[1]), float(listed[2])))
	return out


func _note(message: String) -> void:
	parse_errors.append(message)
