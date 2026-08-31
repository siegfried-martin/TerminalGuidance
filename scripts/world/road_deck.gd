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
## Rails around the cross-section, on a deck you are not on: the four extremes, which
## is enough to say "a road goes that way" without adding to the thicket.
const RAIL_COUNT := 4
## And on the deck you ARE on. Longitudinal lines converging to a vanishing point are
## the strongest tunnel cue there is — it is what makes a real tunnel obvious from
## inside one — and four of them is a wireframe box, not a tunnel.
const LANE_LINE_COUNT := 16
## How often the translucent shell puts a ring of geometry down. Close enough that a
## weaving lane reads as a tube rather than as a chain of prisms. Infrastructure.
const SHELL_STATION_METRES := 120.0

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
## Rails run the length of the deck and are always drawn: they are what says a road
## goes that way, from anywhere.
var _rails: MeshInstance3D
## The same lines, many more of them, on the deck being ridden.
var _lines: MeshInstance3D
## The lane as a TRANSLUCENT SURFACE. Wireframe alone did not read as a road — the
## human flew it and the tube did not exist — so a lane is a solid you can see straight
## through, and the rings become a speed cue rather than the whole of the structure.
##
## **Drawn on EVERY deck**, brighter on the one being ridden. It used to be the active
## deck alone, and that produced a bug that reads as a rendering fault: taking a ramp
## handed the shell over to it, so the mainline's tube stopped being drawn straight
## ahead and the road appeared to vanish for a few seconds before the ramp swung into
## view beside you. A road you can only see once you are committed to it is not a road
## you can choose.
##
## ADR 0057's requirement is that the surrounding space stays RENDERED, not that the
## lane is drawn as lines. A shell at a twentieth of an alpha keeps the system, the war
## and the deep field visible through it, which is the thing that must never be lost;
## a test asserts the alpha rather than the primitive (ADR 0074).
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
	add_child(_shell)
	_lines = MeshInstance3D.new()
	_lines.name = "Lines"
	_lines.material_override = _make_material()
	_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lines.visible = false
	add_child(_lines)
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
	# The shell's floor, walls and roof are told apart by VERTEX colour rather than by
	# lighting: unshaded keeps the road looking the same wherever the system's key
	# light happens to be pointing, and a lane that changes character between systems
	# is a lane the player cannot learn.
	mat.vertex_color_use_as_albedo = true
	return mat


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
		_lines.mesh = null
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


## The lane's four pieces, all built ONCE and shown or hidden per deck.
##
## Built once and not on activation, deliberately: a mainline's shell is tens of
## thousands of vertices, and rebuilding it at the moment the ship merges would put a
## hitch exactly where the player is doing the one thing this road is for.
##
##     shell   a translucent tube             EVERY deck, brighter on yours
##     rails   four wires the length of it    a deck you are not on
##     lines   sixteen of them                the deck you are on
##     rings   cross-sections, widely spaced  the deck you are on
##
## The shell is what says *there is a lane there*; the lines are what make it read as
## a tunnel from inside, because converging longitudinals are the cue a real tunnel
## gives; the rings are what say *this is how fast you are going*.
func _rebuild_structure() -> void:
	var span := length()
	var rib_spacing := maxf(Tuning.num("exploration/lane_rib_spacing"), 1.0)
	_rails.mesh = _line_mesh(_runs_along(span, RAIL_COUNT))
	_lines.mesh = _line_mesh(_runs_along(span, LANE_LINE_COUNT))
	_ribs.mesh = _line_mesh(_rings_along(span, rib_spacing))
	_shell.mesh = _shell_along(span)


## Lines running the length of the lane, evenly around its section, followed along so
## they taper with the flare and lean with the curve.
func _runs_along(span: float, count_around: int) -> PackedVector3Array:
	var stations := maxi(int(span / SHELL_STATION_METRES), 1)
	var runs: Array[PackedVector3Array] = []
	for r in count_around:
		runs.append(PackedVector3Array())
	for i in stations + 1:
		var along := span * float(i) / float(stations)
		var frame := CruiseLane.frame_for(_path.tangent_at(along))
		var centre := _path.point_at(along)
		var extents := profile(along)
		for r in count_around:
			runs[r].append(centre + _lozenge(frame, extents,
				TAU * float(r) / float(count_around)))
	var verts := PackedVector3Array()
	for run in runs:
		for i in run.size() - 1:
			verts.append(run[i])
			verts.append(run[i + 1])
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


## The translucent tube itself, vertex-coloured so the floor, the walls and the roof
## are told apart.
##
## Flat colour was the thing that stopped it reading as a tunnel: the human could not
## say which part of the sheen was left, right, above or below, because every part of
## it was the same. This gives the section a median and an outboard face, so it has a
## left and a right from anywhere inside it.
func _shell_along(span: float) -> ArrayMesh:
	var count := maxi(int(span / SHELL_STATION_METRES), 1)
	var shades := _section_shades()
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var normals := PackedVector3Array()
	var previous := _section_at(0.0)
	for i in range(1, count + 1):
		var here := _section_at(span * float(i) / float(count))
		for s in RIB_SEGMENTS:
			var t := (s + 1) % RIB_SEGMENTS
			# Wound one way only, and the material culls nothing: the player can be
			# inside the lane or outside it, and the tube has to exist from both.
			for corner: Array in [[previous[s], s], [previous[t], t], [here[t], t],
					[previous[s], s], [here[t], t], [here[s], s]]:
				verts.append(corner[0])
				colors.append(shades[corner[1]])
			var out: Vector3 = (previous[s] + here[s]) * 0.5
			for _n in 6:
				normals.append(out.normalized())
		previous = here
	if verts.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## The colour of each point around the section: a GRADIENT from the deck's outer face
## to the face it shares with the other deck.
##
## The two decks sit flush SIDE BY SIDE, and traffic runs on the right, so the shared
## face is each deck's own LEFT (ADR 0077). Running the gradient toward it on both
## means the seam between them is one colour from either side — a red stripe down the
## middle of the pair, which is the lane divider a divided highway actually has. From
## outside it marks where the two roads meet; from inside it is the median, and it is
## on your left because it always is.
##
## That is also the answer to why a flat tube did not read as a tunnel: with every part
## of the sheen identical there is no left, right, above or below to be told apart.
##
## The alpha carried here is RELATIVE — the material's own alpha decides how
## translucent the lane is overall and these multiply into it — so the one slider that
## could turn the road into a tunnel stays the one slider.
func _section_shades() -> PackedColorArray:
	var outer := Tuning.color("exploration/lane_shell_outer_color")
	var divider := Tuning.color("exploration/lane_shell_divider_color")
	var bias := clampf(Tuning.num("exploration/lane_shell_divider_bias"), 0.0, 1.0)
	var shades := PackedColorArray()
	for s in RIB_SEGMENTS:
		# `_lozenge` measures from +right, so this is 0 on the outboard face and 1 on
		# the median. No deck flag: the median is on the left of BOTH decks.
		var inward := (1.0 - cos(TAU * float(s) / float(RIB_SEGMENTS))) * 0.5
		shades.append(shade(inward, outer, divider, bias))
	return shades


## One point's colour, given how far ACROSS the section it sits toward the median: 0
## on the outboard face, 1 on the face shared with the oncoming deck. Pure and static,
## so the gate can check that the two decks actually meet in the same colour rather
## than inferring it from a rendered frame.
##
## There is no deck argument. Right-hand traffic puts the median on the left of both
## decks, so one function answers for both and the seam matches by construction rather
## than by two mirrored cases agreeing (ADR 0077).
static func shade(inward: float, outer: Color, divider: Color,
		bias: float) -> Color:
	var tint := outer.lerp(divider, inward)
	tint.a = lerpf(1.0 - bias, 1.0 + bias, inward)
	return tint


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


## Is this the deck the ship is riding? The geometry is already built, so this costs
## nothing and can happen mid-merge.
func set_active(on: bool) -> void:
	if on == _active:
		return
	_active = on
	_ribs.visible = _active
	_lines.visible = _active
	_rails.visible = not _active
	repaint()


func is_active() -> bool:
	return _active


## A ramp carries a portal at its planet end; a mainline carries none (ADR 0065). That
## is the whole difference, and it is enough to draw them apart: a ramp is the same
## road at `lane_ramp_shade` of the brightness, so "that one leaves the highway" is
## something the eye answers rather than a sign you have to read.
func is_ramp() -> bool:
	return has_start_portal or has_end_portal


## A point on the lane's cross-section. The superellipse `CruiseLane.edge_distance`
## measures against, so the drawn lane and the felt lane are the same shape.
func _lozenge(frame: Array[Vector3], extents: Vector2, angle: float) -> Vector3:
	var exponent := 2.0 / maxf(Tuning.num("exploration/lane_corner_roundness"), 1.0)
	var across := cos(angle)
	var upward := sin(angle)
	return frame[0] * signf(across) * pow(absf(across), exponent) * extents.x \
		+ frame[1] * signf(upward) * pow(absf(upward), exponent) * extents.y


func repaint() -> void:
	var shade := Tuning.num("exploration/lane_ramp_shade") if is_ramp() else 1.0
	var color := Tuning.color("exploration/lane_active_color" if _active
		else "exploration/lane_color")
	color.a = Tuning.num("exploration/lane_active_alpha" if _active
		else "exploration/lane_line_alpha")
	color = color.darkened(1.0 - clampf(shade, 0.0, 1.0))
	(_rails.material_override as StandardMaterial3D).albedo_color = color
	(_lines.material_override as StandardMaterial3D).albedo_color = color
	(_ribs.material_override as StandardMaterial3D).albedo_color = color
	# The SHELL'S own colour lives in its vertices — the floor and the roof are
	# different colours and a tinted albedo would flatten them back into one — so what
	# the material carries is the alpha and, on a ramp, the shade.
	(_shell.material_override as StandardMaterial3D).albedo_color = Color(
		shade, shade, shade, Tuning.num("exploration/lane_shell_alpha" if _active
			else "exploration/lane_shell_idle_alpha"))


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
