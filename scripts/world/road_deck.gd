class_name RoadDeck
extends Node3D
## One direction of one road: a lane you fly down, with a portal at each end.
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
## Geometry is built in the MAP'S frame with the node left at identity, as with
## `SystemLink`: there is no rotation to get backwards that way.

## How finely a rib is drawn, and how many samples a rail follows the flare with.
## Infrastructure, not feel.
const RIB_SEGMENTS := 28

var deck_name: String = "deck"
## What the portal at the far end leads to.
var destination: String = ""
## Upper or lower, per the deck convention. **Declared, not derived** — a road
## segment carries its deck, and a test asserts the declaration matches the
## orientation. The convention's value is as a mistake-catcher ("I'm heading east,
## why am I on the lower deck?"), and one exception makes it worse than no rule.
var is_upper: bool = true

var _from: Vector3 = Vector3.ZERO
var _to: Vector3 = Vector3.ZERO
var _structure: MeshInstance3D
var _start: Portal
var _end: Portal


func _ready() -> void:
	_structure = MeshInstance3D.new()
	_structure.name = "Structure"
	_structure.material_override = _make_material()
	_structure.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_structure)
	_start = Portal.new()
	_start.name = "StartPortal"
	add_child(_start)
	_end = Portal.new()
	_end.name = "EndPortal"
	add_child(_end)
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


## Lay this deck between two points, both in the map's frame and already offset to
## the deck's own height.
func span(start: Vector3, finish: Vector3, leads_to: String, back_to: String) -> void:
	_from = start
	_to = finish
	destination = leads_to
	if _structure == null:
		return
	# Both portals at a site connect to the same neighbour — one is the way there and
	# one is the way back — so the label has to say WHICH, not just where. The deck
	# convention answers it too, but a player reading the sign should not have to
	# derive their answer from a mnemonic about compass arcs.
	_start.destination = "TO %s" % leads_to
	_end.destination = "FROM %s" % back_to
	rebuild()


func rebuild() -> void:
	if length() <= 0.001:
		_structure.mesh = null
		return
	_start.place(_from, axis())
	_end.place(_to, axis())
	_rebuild_structure()
	repaint()


func axis() -> Vector3:
	var run := _to - _from
	return Vector3.FORWARD if run.length_squared() <= 0.000001 else run.normalized()


func length() -> float:
	return _from.distance_to(_to)


## The lane's half-extents this far along it. Full in the middle, narrowing to the
## portal's own opening at each end over `portal_flare_length` — a freeway on-ramp
## is narrower than the road it feeds, and the flare is what makes entry a piloting
## act rather than a formality.
func profile(along: float) -> Vector2:
	var full := Vector2(Tuning.num("exploration/lane_width"),
		Tuning.num("exploration/lane_height")) * 0.5
	var mouth := Vector2(Tuning.num("exploration/portal_width"),
		Tuning.num("exploration/portal_height")) * 0.5
	var flare := Tuning.num("exploration/portal_flare_length")
	if flare <= 0.0:
		return full
	var from_end := minf(along, length() - along)
	if from_end >= flare:
		return full
	return mouth.lerp(full, clampf(from_end / flare, 0.0, 1.0))


## Where the road is, at this point. Everything the ship needs from the lane in one
## object, so the ship never has to look the road up (`CruiseLane`).
func sample(point: Vector3) -> CruiseLane:
	var lane := CruiseLane.new()
	var direction := axis()
	var frame := CruiseLane.frame_for(direction)
	var along := clampf((point - _from).dot(direction), 0.0, length())
	var offset := point - (_from + direction * along)
	var extents := profile(along)
	lane.axis = direction
	lane.right = frame[0]
	lane.up = frame[1]
	lane.lateral = offset.dot(frame[0])
	lane.vertical = offset.dot(frame[1])
	lane.half_width = extents.x
	lane.half_height = extents.y
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


## Ribs across the lane and rails along it. Lines rather than a surface, because the
## lane has to be visually open — the system outside is the thing the road is not
## allowed to hide, and a rib you can see the war through is still unmistakably a
## road.
func _rebuild_structure() -> void:
	var direction := axis()
	var frame := CruiseLane.frame_for(direction)
	var spacing := maxf(Tuning.num("exploration/lane_rib_spacing"), 1.0)
	var span := length()
	var count := maxi(int(span / spacing), 1)
	var verts := PackedVector3Array()
	var rails: Array[PackedVector3Array] = [PackedVector3Array(),
		PackedVector3Array(), PackedVector3Array(), PackedVector3Array()]
	for i in count + 1:
		var along := span * float(i) / float(count)
		var centre := _from + direction * along
		var extents := profile(along)
		var ring := PackedVector3Array()
		for s in RIB_SEGMENTS:
			var angle := TAU * float(s) / float(RIB_SEGMENTS)
			ring.append(centre + _lozenge(frame, extents, angle))
		for s in RIB_SEGMENTS:
			verts.append(ring[s])
			verts.append(ring[(s + 1) % RIB_SEGMENTS])
		# The four extremes, followed along so the rails taper with the flare.
		for r in 4:
			rails[r].append(centre + _lozenge(frame, extents, TAU * float(r) / 4.0))
	for rail in rails:
		for i in rail.size() - 1:
			verts.append(rail[i])
			verts.append(rail[i + 1])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	_structure.mesh = mesh


## A point on the lane's cross-section. The superellipse `CruiseLane.edge_distance`
## measures against, so the drawn lane and the felt lane are the same shape.
func _lozenge(frame: Array[Vector3], extents: Vector2, angle: float) -> Vector3:
	var exponent := 2.0 / maxf(Tuning.num("exploration/lane_corner_roundness"), 1.0)
	var across := cos(angle)
	var upward := sin(angle)
	return frame[0] * signf(across) * pow(absf(across), exponent) * extents.x \
		+ frame[1] * signf(upward) * pow(absf(upward), exponent) * extents.y


func repaint() -> void:
	var color := Tuning.color("exploration/lane_color")
	color.a = Tuning.num("exploration/lane_line_alpha")
	(_structure.material_override as StandardMaterial3D).albedo_color = color


## Blue or red on both this deck's portals, decided against the hull the player is
## flying right now (ADR 0060).
func set_permitted(allowed: bool) -> void:
	if _start != null:
		_start.permitted = allowed
	if _end != null:
		_end.permitted = allowed


func start_portal() -> Portal:
	return _start


func end_portal() -> Portal:
	return _end
