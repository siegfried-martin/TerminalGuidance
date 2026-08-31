class_name RoadDeck
extends Node3D
## One stretch of road in one direction: a mainline, or a ramp on or off one.
##
## Lanes are **one-way**, and each direction is a physically separate deck laid
## BESIDE the other, visible to each other. There is no oncoming traffic in the
## player's lane, ever, and that is structural rather than a spawn rule.
##
## **Traffic runs on the right** (ADR 0077). Every deck sits to the right of the
## spine as its own traffic travels, so the oncoming deck is on its left from either
## driver's seat, at any bearing, in any frame. That is what retired the upper/lower
## deck convention: the section says which side you are on without a rule to remember.
##
## **A deck is the lane; the building around it is a `RoadStructure`** (ADR 0078).
## What lives here is where the road IS and how it is flown — the path, the sample
## the ship is handed, the portals at its ends, and the markings on its own
## carriageway. Collars, glazing and roadway are the structure's, and one structure
## carries both carriageways of a mainline.
##
## The lane is **visually open** (ADR 0057): the walls and roof around it are glazed
## and only the roadway is solid, so the system and the space around it stay rendered
## and visible from inside. An opaque tunnel would convert the living overworld from
## witnessed to reported, which is the thing the road is not allowed to cost.
##
## The lane boundary is **soft**: outside it the cruise drive is slower and the road
## nudges you back toward the centre-line. It is an incentive, not a wall — if the
## player can be stopped by it, it is wrong (ADR 0064).
##
## **A deck follows a path, not a line** (`RoadPath`). That is what lets a ramp curve
## away from the mainline tangentially, and what will let the trunk leg curve in step
## 8. Portals are optional per end: a mainline has none — you join it from a ramp —
## and a ramp carries one at whichever end sits by the planet.
##
## Geometry is built in the MAP'S frame with the node left at identity, as with
## `SystemLink`: there is no rotation to get backwards that way.

## Lines painted the length of the carriageway. Longitudinal lines converging to a
## vanishing point are the strongest speed and direction cue there is; the structure
## now carries the tunnel, so these are road markings rather than a wireframe.
const MARKING_COUNT := 5
## How much of the lane's half-width the outermost markings sit inside. Painted lines
## stop short of the kerb on a real road, and flush against the wall they read as an
## edge of the structure rather than as paint.
const MARKING_INSET := 0.82
## How far above the roadway a marking floats, as a fraction of the lane's
## half-height. Enough to clear the plate's own surface without reading as hovering.
const MARKING_LIFT := 0.02
## How often a marking puts a vertex down. Close enough that a weaving lane reads as
## a curve rather than as a chain of chords. Infrastructure.
const STATION_METRES := 120.0

var deck_name: String = "deck"
## Which way along the spine this deck's traffic runs. It is a grouping key and
## nothing else: the union may only ever consider decks that agree on it, so
## "no oncoming traffic in your lane" stays structural (ADR 0067).
##
## It is NOT a deck convention and carries no side information — right-hand traffic
## already puts each deck on its own right, so nothing has to be declared or checked
## against a heading (ADR 0077).
var runs_forward: bool = true
## Which ends carry a way on or off. A mainline has neither: it is joined and left
## through the ramps, which is what makes the highway continuous through a system
## rather than something that stops at each one (ADR 0065).
var has_start_portal: bool = false
var has_end_portal: bool = false

var _path: RoadPath = RoadPath.new()
## Markings run the length of the carriageway and are ALWAYS drawn, brighter on the
## one being ridden (ADR 0075). Every lane is drawn because a road you can only see
## once you are committed to it is not a road you can choose; the one you are on is
## brighter because four carriageways meet at an interchange and the player has to be
## able to see which is theirs.
var _lines: MeshInstance3D
## Whether this is the deck the ship is on. Set by the network from the map.
var _active: bool = false
var _start: Portal
var _end: Portal


func _ready() -> void:
	_lines = MeshInstance3D.new()
	_lines.name = "Lines"
	var mat := StandardMaterial3D.new()
	# Paint, unshaded on purpose. The structure around the lane is lit and takes its
	# form from that; a marking is a light source in its own right, and one that dims
	# with the system's key light is one the player stops steering by.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_lines.material_override = mat
	_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_lines)
	rebuild()


## Lay this deck along a path, in the map's frame.
func follow(line: PackedVector3Array, leads_to: String, back_to: String) -> void:
	_path.set_points(line)
	if _lines == null:
		return
	_name_portals(leads_to, back_to)
	rebuild()


func _name_portals(leads_to: String, back_to: String) -> void:
	# Both portals at a site connect to the same neighbour — one is the way there and
	# one is the way back — so the label has to say WHICH, not just where.
	if has_start_portal:
		if _start == null:
			_start = Portal.new()
			_start.name = "StartPortal"
			add_child(_start)
		_start.destination = "TO %s" % leads_to
	if has_end_portal:
		if _end == null:
			_end = Portal.new()
			_end.name = "EndPortal"
			add_child(_end)
		_end.destination = "FROM %s" % back_to


func rebuild() -> void:
	if _path.is_empty():
		_lines.mesh = null
		return
	if _start != null:
		_start.place(_path.start(), _path.tangent_at(0.0))
	if _end != null:
		_end.place(_path.finish(), _path.tangent_at(_path.length()))
	_rebuild_markings()
	repaint()


func path() -> RoadPath:
	return _path


func length() -> float:
	return _path.length()


## The lane's half-extents this far along it. Full through the middle, narrowing to
## the portal's own opening at whichever end carries one — a freeway on-ramp is
## narrower than the road it feeds, and the flare is what makes entry a piloting act
## rather than a formality. An end with no portal does not narrow: the mainline is
## full width where a ramp merges into it.
## The arithmetic is `LaneProfile`'s, shared with the structure around this lane, so
## the building and the lane inside it cannot disagree about where the road pinches.
func profile(along: float) -> Vector2:
	return LaneProfile.extents(along, length(),
		Vector2(Tuning.num("exploration/lane_width"),
			Tuning.num("exploration/lane_height")) * 0.5,
		Vector2(Tuning.num("exploration/portal_width"),
			Tuning.num("exploration/portal_height")) * 0.5,
		Tuning.num("exploration/portal_flare_length"),
		has_start_portal, has_end_portal)


## Where the road is, at this point. Everything the ship needs from the lane in one
## object, so the ship never has to look the road up (`CruiseLane`).
##
## `clearance` is half the asking ship's own section. The lane is measured against
## the hull rather than against a point, so a wide ship crosses the rail when its
## hull does; anything that does not have a hull worth the name passes zero and gets
## the point case back.
func sample(point: Vector3, clearance: Vector2 = Vector2.ZERO) -> CruiseLane:
	var lane := CruiseLane.new()
	var found := _path.closest(point)
	var along: float = found[0]
	var centre: Vector3 = found[1]
	var direction: Vector3 = found[2]
	var frame := CruiseLane.frame_for(direction)
	var offset := point - centre
	var extents := profile(along)
	lane.axis = direction
	lane.right = frame[0]
	lane.up = frame[1]
	lane.lateral = offset.dot(frame[0])
	lane.vertical = offset.dot(frame[1])
	lane.half_width = extents.x
	lane.half_height = extents.y
	lane.clearance = clearance
	lane.clearance_cap = Tuning.num("exploration/lane_hull_clearance_cap")
	lane.roundness = Tuning.num("exploration/lane_corner_roundness")
	lane.edge_softness = Tuning.num("exploration/lane_edge_softness")
	lane.base_speed = Tuning.num("exploration/cruise_speed")
	lane.edge_speed_penalty = Tuning.num("exploration/lane_edge_speed_penalty")
	lane.push_accel = Tuning.num("exploration/lane_edge_push_accel")
	lane.clamp_deg = Tuning.num("exploration/cruise_turn_clamp_deg")
	lane.turn_rate_deg = Tuning.num("exploration/cruise_turn_rate_deg_per_sec")
	lane.deck_name = deck_name
	lane.metres_travelled = along
	lane.metres_remaining = length() - along
	return lane


## The markings on this carriageway, built ONCE and repainted per deck.
##
## Built once and not on activation, deliberately: rebuilding geometry at the moment
## the ship merges would put a hitch exactly where the player is doing the one thing
## this road is for. Becoming the ridden deck changes a colour, nothing else.
##
## These used to be sixteen lines wrapped around the whole cross-section, because the
## lane had no walls and converging longitudinals were the only tunnel cue available.
## The structure carries the tunnel now (ADR 0078), so they are what they should
## always have been: paint on the road.
func _rebuild_markings() -> void:
	_lines.mesh = _line_mesh(_markings_along(length()))


## Lines painted the length of the carriageway, evenly across its roadway, followed
## along so they taper with the flare at a mouth and lean with the curve.
func _markings_along(span: float) -> PackedVector3Array:
	var stations := maxi(int(span / STATION_METRES), 1)
	var runs: Array[PackedVector3Array] = []
	for r in MARKING_COUNT:
		runs.append(PackedVector3Array())
	for i in stations + 1:
		var along := span * float(i) / float(stations)
		var frame := CruiseLane.frame_for(_path.tangent_at(along))
		var centre := _path.point_at(along)
		var extents := profile(along)
		# On the ROADWAY, which is the floor of the lane, lifted just clear of it.
		var floor_point := centre - frame[1] * extents.y * (1.0 - MARKING_LIFT)
		for r in MARKING_COUNT:
			var across := -1.0 + 2.0 * float(r) / float(MARKING_COUNT - 1)
			runs[r].append(floor_point
				+ frame[0] * across * extents.x * MARKING_INSET)
	var verts := PackedVector3Array()
	for run in runs:
		for i in run.size() - 1:
			verts.append(run[i])
			verts.append(run[i + 1])
	return verts


func _line_mesh(verts: PackedVector3Array) -> ArrayMesh:
	if verts.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return mesh


## Is this the deck the ship is riding? The geometry is already built, so this costs
## nothing and can happen mid-merge — it is a repaint.
func set_active(on: bool) -> void:
	if on == _active:
		return
	_active = on
	repaint()


func is_active() -> bool:
	return _active


## A ramp carries a portal at its planet end; a mainline carries none (ADR 0065). That
## is the whole difference, and it is enough to draw them apart: a ramp's STRUCTURE is
## built at `lane_ramp_shade` of the brightness, so "that one leaves the highway" is
## something the eye answers rather than a sign you have to read (ADR 0076).
func is_ramp() -> bool:
	return has_start_portal or has_end_portal


func repaint() -> void:
	var shade := Tuning.num("exploration/lane_ramp_shade") if is_ramp() else 1.0
	var color := Tuning.color("exploration/lane_active_color" if _active
		else "exploration/lane_color")
	color.a = Tuning.num("exploration/lane_active_alpha" if _active
		else "exploration/lane_line_alpha")
	color = color.darkened(1.0 - clampf(shade, 0.0, 1.0))
	(_lines.material_override as StandardMaterial3D).albedo_color = color


## Blue or red on this deck's portals, decided against the hull the player is flying
## right now (ADR 0060).
func set_permitted(allowed: bool) -> void:
	if _start != null:
		_start.permitted = allowed
	if _end != null:
		_end.permitted = allowed


func start_portal() -> Portal:
	return _start


func end_portal() -> Portal:
	return _end
