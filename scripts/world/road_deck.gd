class_name RoadDeck
extends Node3D
## One stretch of road in one direction: a mainline, or a ramp on or off one.
##
## Lanes are **one-way**, and each direction is a physically separate deck stacked
## above or below the other, visible to each other. There is no oncoming traffic in
## the player's lane, ever, and that is structural rather than a spawn rule.
##
## The lane is **visually open** (ADR 0057): ribs and rails define it, and the system
## and the space around it stay rendered and visible from inside. An opaque tunnel
## would convert the living overworld from witnessed to reported, which is the thing
## the road is not allowed to cost.
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

## How finely a rib is drawn. Infrastructure, not feel.
const RIB_SEGMENTS := 28
## Rails around the cross-section: the four extremes, always drawn on every deck.
const RAIL_COUNT := 4
## How often the translucent shell puts a ring of geometry down. Close enough that a
## weaving lane reads as a tube rather than as a chain of prisms. Infrastructure.
const SHELL_STATION_METRES := 120.0

var deck_name: String = "deck"
## Upper or lower, per the deck convention. **Declared, not derived** — a road
## segment carries its deck, and a test asserts the declaration matches the
## orientation. The convention's value is as a mistake-catcher ("I'm heading east,
## why am I on the lower deck?"), and one exception makes it worse than no rule.
var is_upper: bool = true
## Which ends carry a way on or off. A mainline has neither: it is joined and left
## through the ramps, which is what makes the highway continuous through a system
## rather than something that stops at each one (ADR 0065).
var has_start_portal: bool = false
var has_end_portal: bool = false

var _path: RoadPath = RoadPath.new()
## Rails run the length of the deck and are always drawn: they are what says a road
## goes that way, from anywhere.
var _rails: MeshInstance3D
## The lane as a TRANSLUCENT SURFACE, on the deck being ridden. Wireframe alone did
## not read as a road — the human flew it and the tube did not exist — so the lane you
## are in is a solid you can see straight through, and the ribs below become a speed
## cue rather than the whole of the structure.
##
## ADR 0057's requirement is that the surrounding space stays RENDERED, not that the
## lane is drawn as lines. A shell at a tenth of an alpha keeps the system, the war and
## the deep field visible through it, which is the thing that must never be lost; a
## test asserts the alpha rather than the primitive.
var _shell: MeshInstance3D
## Ribs are the cross-sections, and they are drawn ONLY on the deck the player is
## riding. Four decks meet at an interchange and every one of them was drawing a rib
## every 120 m; the result was reported as small rounded squares everywhere, with no
## way to tell which of them was the road being flown. Widely spaced now, because the
## shell carries the shape and these only have to carry speed.
var _ribs: MeshInstance3D
## Whether this is the deck the ship is on. Set by the network from the map.
var _active: bool = false
var _start: Portal
var _end: Portal


func _ready() -> void:
	_rails = MeshInstance3D.new()
	_rails.name = "Rails"
	_rails.material_override = _make_material()
	_rails.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rails)
	_shell = MeshInstance3D.new()
	_shell.name = "Shell"
	_shell.material_override = _make_material()
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shell.visible = false
	add_child(_shell)
	_ribs = MeshInstance3D.new()
	_ribs.name = "Ribs"
	_ribs.material_override = _make_material()
	_ribs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ribs.visible = false
	add_child(_ribs)
	rebuild()


func _make_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


## The deck convention: headings in the arc running clockwise from northwest through
## north and east to southeast ride the UPPER deck; everything else rides the lower.
## Bearings are 0 at -Z, counting clockwise, so that arc is 315 deg round to 135.
static func rides_upper(bearing_deg: float) -> bool:
	var bearing := fposmod(bearing_deg, 360.0)
	return bearing <= 135.0 or bearing >= 315.0


## Lay this deck along a path, in the map's frame.
func follow(line: PackedVector3Array, leads_to: String, back_to: String) -> void:
	_path.set_points(line)
	if _rails == null:
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
		_rails.mesh = null
		_ribs.mesh = null
		_shell.mesh = null
		return
	if _start != null:
		_start.place(_path.start(), _path.tangent_at(0.0))
	if _end != null:
		_end.place(_path.finish(), _path.tangent_at(_path.length()))
	_rebuild_structure()
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
func profile(along: float) -> Vector2:
	var full := Vector2(Tuning.num("exploration/lane_width"),
		Tuning.num("exploration/lane_height")) * 0.5
	var mouth := Vector2(Tuning.num("exploration/portal_width"),
		Tuning.num("exploration/portal_height")) * 0.5
	var flare := Tuning.num("exploration/portal_flare_length")
	if flare <= 0.0:
		return full
	var from_end := INF
	if has_start_portal:
		from_end = minf(from_end, along)
	if has_end_portal:
		from_end = minf(from_end, length() - along)
	if from_end >= flare:
		return full
	return mouth.lerp(full, clampf(from_end / flare, 0.0, 1.0))


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


## The lane's three pieces, all built ONCE and shown or hidden per deck.
##
## Built once and not on activation, deliberately: a mainline's shell is tens of
## thousands of vertices, and rebuilding it at the moment the ship merges would put a
## hitch exactly where the player is doing the one thing this road is for.
##
##     rails   four wires the length of it        every deck, always
##     shell   a translucent tube                 the deck you are on
##     ribs    rings at a wide spacing            the deck you are on
##
## The shell is what says *this is the lane*; the ribs are what say *this is how fast
## you are going*, which is the only job left for them once a surface exists.
func _rebuild_structure() -> void:
	var span := length()
	var rib_spacing := maxf(Tuning.num("exploration/lane_rib_spacing"), 1.0)
	_rails.mesh = _line_mesh(_rails_along(span))
	_ribs.mesh = _line_mesh(_rings_along(span, rib_spacing))
	_shell.mesh = _shell_along(span)


## The four extremes, followed along so they taper with the flare and lean with the
## curve.
func _rails_along(span: float) -> PackedVector3Array:
	var count := maxi(int(span / SHELL_STATION_METRES), 1)
	var rails: Array[PackedVector3Array] = []
	for r in RAIL_COUNT:
		rails.append(PackedVector3Array())
	for i in count + 1:
		var along := span * float(i) / float(count)
		var frame := CruiseLane.frame_for(_path.tangent_at(along))
		var centre := _path.point_at(along)
		var extents := profile(along)
		for r in RAIL_COUNT:
			rails[r].append(centre + _lozenge(frame, extents,
				TAU * float(r) / float(RAIL_COUNT)))
	var verts := PackedVector3Array()
	for rail in rails:
		for i in rail.size() - 1:
			verts.append(rail[i])
			verts.append(rail[i + 1])
	return verts


## Closed rings across the lane, at this spacing.
func _rings_along(span: float, spacing: float) -> PackedVector3Array:
	var count := maxi(int(span / spacing), 1)
	var verts := PackedVector3Array()
	for i in count + 1:
		var along := span * float(i) / float(count)
		var ring := _section_at(along)
		for s in RIB_SEGMENTS:
			verts.append(ring[s])
			verts.append(ring[(s + 1) % RIB_SEGMENTS])
	return verts


## The translucent tube itself.
func _shell_along(span: float) -> ArrayMesh:
	var count := maxi(int(span / SHELL_STATION_METRES), 1)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var previous := _section_at(0.0)
	for i in range(1, count + 1):
		var here := _section_at(span * float(i) / float(count))
		for s in RIB_SEGMENTS:
			var t := (s + 1) % RIB_SEGMENTS
			# Wound both ways is unnecessary — the material culls nothing, because the
			# player can be inside the lane or outside it and the tube has to exist
			# from both.
			for corner: Vector3 in [previous[s], previous[t], here[t],
					previous[s], here[t], here[s]]:
				verts.append(corner)
			var out: Vector3 = (previous[s] + here[s]) * 0.5
			for _n in 6:
				normals.append(out.normalized())
		previous = here
	if verts.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## One cross-section, as a closed ring of points.
func _section_at(along: float) -> PackedVector3Array:
	var frame := CruiseLane.frame_for(_path.tangent_at(along))
	var centre := _path.point_at(along)
	var extents := profile(along)
	var ring := PackedVector3Array()
	for s in RIB_SEGMENTS:
		ring.append(centre + _lozenge(frame, extents,
			TAU * float(s) / float(RIB_SEGMENTS)))
	return ring


func _line_mesh(verts: PackedVector3Array) -> ArrayMesh:
	if verts.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return mesh


## Is this the deck the ship is riding? Shows the shell and the ribs; the geometry is
## already built, so this costs nothing and can happen mid-merge.
func set_active(on: bool) -> void:
	if on == _active:
		return
	_active = on
	_shell.visible = _active
	_ribs.visible = _active
	repaint()


func is_active() -> bool:
	return _active


## A point on the lane's cross-section. The superellipse `CruiseLane.edge_distance`
## measures against, so the drawn lane and the felt lane are the same shape.
func _lozenge(frame: Array[Vector3], extents: Vector2, angle: float) -> Vector3:
	var exponent := 2.0 / maxf(Tuning.num("exploration/lane_corner_roundness"), 1.0)
	var across := cos(angle)
	var upward := sin(angle)
	return frame[0] * signf(across) * pow(absf(across), exponent) * extents.x \
		+ frame[1] * signf(upward) * pow(absf(upward), exponent) * extents.y


func repaint() -> void:
	var color := Tuning.color("exploration/lane_active_color" if _active
		else "exploration/lane_color")
	color.a = Tuning.num("exploration/lane_active_alpha" if _active
		else "exploration/lane_line_alpha")
	(_rails.material_override as StandardMaterial3D).albedo_color = color
	(_ribs.material_override as StandardMaterial3D).albedo_color = color
	var skin := Tuning.color("exploration/lane_shell_color")
	skin.a = Tuning.num("exploration/lane_shell_alpha")
	(_shell.material_override as StandardMaterial3D).albedo_color = skin


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
