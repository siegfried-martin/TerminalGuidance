class_name SystemLink
extends Node3D
## The bounded space between two systems: a corridor from one rim to the other,
## flared at both ends so leaving is aimed rather than threaded (ADR 0062).
##
## **No road in it yet.** POC step 5 is the control condition — fly A to B by hand,
## at each hull's speed, with nothing but the corridor. That is the baseline the
## highway has to beat in step 6 and what success criterion 2 is measured against,
## so it has to be flown before the road exists rather than remembered afterwards.
##
## The boundary lives in `TubeRegion` and the map owns it; this node draws it, from
## the same `profile()` the boundary is enforced with.
##
## The geometry is built in the MAP'S frame with the node left at identity, rather
## than in a local frame with a transform to place it. There is no rotation to get
## backwards that way, and the floating origin still works because everything moves
## with the map (ADR 0020).

## How finely the tube is tessellated around, and how many rings each part gets.
## Infrastructure, not feel.
const RING_SEGMENTS := 40
const RINGS_PER_FLARE := 8
const RINGS_ALONG := 20

var link_name: String = "corridor"
## The leg's own bearing, in degrees. Used to DECLARE which deck is which under the
## convention (see `RoadDeck.rides_upper`) — assigned by the map, which is the
## authoring layer, rather than worked out per frame from a heading.
var leg_bearing_deg: float = 0.0
## What each end leads to, for the portals' labels.
var from_name: String = ""
var to_name: String = ""

var _wall: MeshInstance3D
## Reference markers down the length of it. Four kilometres of empty tube reads as a
## still image at 15 m/s, and the leg being *long* is the thing under test.
var _markers: MultiMeshInstance3D
var _region: TubeRegion = TubeRegion.new()
## The road inside the corridor: one deck per direction, stacked (POC step 6).
var _decks: Array[RoadDeck] = []


func _ready() -> void:
	_wall = MeshInstance3D.new()
	_wall.name = "Wall"
	_wall.material_override = BoundaryPaint.make_material()
	_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_wall)
	_markers = MultiMeshInstance3D.new()
	_markers.name = "LinkMarkers"
	_markers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_markers)
	for deck_name in ["DeckOut", "DeckBack"]:
		var deck := RoadDeck.new()
		deck.name = deck_name
		add_child(deck)
		_decks.append(deck)
	rebuild()
	# NOT connected to `Tuning.reloaded` here. The map owns the layout, and this
	# node's geometry depends on it: reloading in signal order would rebuild against
	# the old positions and then have to be rebuilt again. The map drives it.


## Both mouths, in the map's frame. Set by the map before the node enters the tree,
## and again on reload — the system diameter is a slider and the mouths move with it.
func span(from: Vector3, to: Vector3) -> void:
	_region.from = from
	_region.to = to
	if _wall != null:
		rebuild()


func rebuild() -> void:
	_region.mouth_radius = Tuning.num("exploration/aperture_mouth_diameter") * 0.5
	_region.radius = Tuning.num("exploration/corridor_diameter") * 0.5
	_region.flare_length = Tuning.num("exploration/aperture_funnel_length")
	_region.name_of = link_name
	_rebuild_wall()
	_rebuild_markers()
	_rebuild_decks()
	paint(0.0)


## A frame perpendicular to the tube, for placing things around its axis.
func _cross_frame() -> Array[Vector3]:
	var axis := _region.axis()
	var up := Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.99 else Vector3.BACK
	var u := axis.cross(up).normalized()
	return [u, axis.cross(u).normalized()]


## The wall, ring by ring, following the same profile the boundary uses.
##
## Rings are packed into the flares and spread thinly down the straight middle: the
## taper is the part with a shape worth drawing, and four kilometres of cylinder
## reads fine from twenty rings.
func _rebuild_wall() -> void:
	var span_m := _region.length()
	if span_m <= 0.001:
		_wall.mesh = null
		return
	var frame := _cross_frame()
	var axis := _region.axis()
	var stops := _wall_stops(span_m)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in stops.size() - 1:
		var t0: float = stops[i]
		var t1: float = stops[i + 1]
		var r0 := _region.profile(t0)
		var r1 := _region.profile(t1)
		for s in RING_SEGMENTS:
			var a0 := TAU * float(s) / float(RING_SEGMENTS)
			var a1 := TAU * float(s + 1) / float(RING_SEGMENTS)
			var d0: Vector3 = frame[0] * cos(a0) + frame[1] * sin(a0)
			var d1: Vector3 = frame[0] * cos(a1) + frame[1] * sin(a1)
			var near0 := _region.from + axis * t0 + d0 * r0
			var near1 := _region.from + axis * t0 + d1 * r0
			var far0 := _region.from + axis * t1 + d0 * r1
			var far1 := _region.from + axis * t1 + d1 * r1
			for corner: Array in [
					[near0, d0], [near1, d1], [far1, d1],
					[near0, d0], [far1, d1], [far0, d0]]:
				verts.append(corner[0])
				normals.append(corner[1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_wall.mesh = mesh


## Where to put a ring: dense through each flare, sparse down the straight.
func _wall_stops(span_m: float) -> PackedFloat32Array:
	var flare := minf(_region.flare_length, span_m * 0.5)
	var stops := PackedFloat32Array()
	for i in RINGS_PER_FLARE + 1:
		stops.append(flare * float(i) / float(RINGS_PER_FLARE))
	for i in range(1, RINGS_ALONG):
		var t := flare + (span_m - flare * 2.0) * float(i) / float(RINGS_ALONG)
		if t > flare and t < span_m - flare:
			stops.append(t)
	for i in RINGS_PER_FLARE + 1:
		stops.append(span_m - flare + flare * float(i) / float(RINGS_PER_FLARE))
	return stops


func _rebuild_markers() -> void:
	var spacing := Tuning.num("exploration/marker_spacing")
	var span_m := _region.length()
	if spacing <= 0.0 or span_m <= 0.001:
		return
	var frame := _cross_frame()
	var axis := _region.axis()
	var places: Array[Vector3] = []
	var across := int(_region.radius / spacing)
	var steps := int(span_m / spacing)
	for iz in range(1, steps):
		var t := float(iz) * spacing
		var allowed := _region.profile(t)
		for ix in range(-across, across + 1):
			for iy in range(-across, across + 1):
				var offset := Vector2(float(ix) * spacing, float(iy) * spacing)
				if offset.length() > allowed:
					continue
				places.append(_region.from + axis * t
					+ frame[0] * offset.x + frame[1] * offset.y)
	_markers.multimesh = BoundaryPaint.make_markers(places)
	_markers.material_override = BoundaryPaint.make_marker_material()


func paint(warning_level: float) -> void:
	BoundaryPaint.tint([_wall], warning_level,
		Tuning.num("exploration/bounds_rim_alpha_scale"))


## The two decks, outbound first. Stacked vertically and visible to each other, one
## per direction, so there is never oncoming traffic in the player's lane — which is
## structural here rather than a rule about where NPCs may spawn.
##
## Which is upper follows the deck convention: headings in the arc clockwise from
## northwest through north and east to southeast ride the upper deck. The convention
## earns its keep as a mistake-catcher — *"I am heading east, why am I on the lower
## deck?"* — and one exception makes it worse than no rule at all.
func _rebuild_decks() -> void:
	if _decks.size() < 2:
		return
	var half := Tuning.num("exploration/deck_separation") * 0.5
	var out_is_upper := RoadDeck.rides_upper(leg_bearing_deg)
	var back_is_upper := RoadDeck.rides_upper(leg_bearing_deg + 180.0)
	_decks[0].deck_name = "%s bound" % to_name
	_decks[0].is_upper = out_is_upper
	_decks[0].span(_region.from + Vector3.UP * (half if out_is_upper else -half),
		_region.to + Vector3.UP * (half if out_is_upper else -half),
		to_name, from_name)
	_decks[1].deck_name = "%s bound" % from_name
	_decks[1].is_upper = back_is_upper
	_decks[1].span(_region.to + Vector3.UP * (half if back_is_upper else -half),
		_region.from + Vector3.UP * (half if back_is_upper else -half),
		from_name, to_name)


func decks() -> Array[RoadDeck]:
	return _decks


func region() -> TubeRegion:
	return _region


func length() -> float:
	return _region.length()


func marker_count() -> int:
	return 0 if _markers.multimesh == null else _markers.multimesh.instance_count
