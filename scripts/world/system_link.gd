class_name SystemLink
extends Node3D
## The bounded space between two systems: a corridor from one rim to the other,
## flared at both ends so leaving is aimed rather than threaded (ADR 0062).
##
## **The corridor is not the road.** The road runs through it and on through the
## systems at each end, and it belongs to `RoadNetwork`, which spans the whole map
## rather than one leg. What lives here is the bounded space you fly when you decline
## the road — the control condition success criterion 2 is measured against.
##
## **A leg weaves and undulates** (`RoadPath.weave`), because success criterion 1
## cannot be tested on a straight road. The corridor is the space around that leg, so
## it bends with it: this node is handed the leg's centre-line and walks it, rather
## than owning two endpoints and an axis.
##
## The boundary lives in `TubeRegion` and the map owns it; this node draws it, from
## the same `profile()` the boundary is enforced with.
##
## The geometry is built in the MAP'S frame with the node left at identity, rather
## than in a local frame with a transform to place it. There is no rotation to get
## backwards that way, and the floating origin still works because everything moves
## with the map (ADR 0020).

## How finely the tube is tessellated around, and how many rings each flare gets.
## Infrastructure, not feel.
const RING_SEGMENTS := 40
const RINGS_PER_FLARE := 8
## A ring this often down the straight middle. Close enough that a weaving corridor
## reads as a curve rather than as a chain of cylinders.
const WALL_RING_METRES := 300.0
## The fewest longitudinal lines the grid will draw, however coarse the spacing is
## tuned. Infrastructure, not feel.
const GRID_MIN_SPOKES := 6

var link_name: String = "corridor"
## What each end leads to. Kept for the HUD's naming of the corridor.
var from_name: String = ""
var to_name: String = ""

var _wall: MeshInstance3D
## A line grid over the wall. The translucent surface alone gives a moving ship
## nothing to measure itself against — it is one flat colour filling the view, which
## is exactly the "blue wall" report — so the wall carries a ruled grid that slides
## past as you fly.
var _grid: MeshInstance3D
## Reference markers down the length of it. Four kilometres of empty tube reads as a
## still image at 15 m/s, and the leg being *long* is the thing under test.
var _markers: MultiMeshInstance3D
var _region: TubeRegion = TubeRegion.new()


func _ready() -> void:
	_wall = MeshInstance3D.new()
	_wall.name = "Wall"
	_wall.material_override = BoundaryPaint.make_material()
	_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_wall)
	_grid = MeshInstance3D.new()
	_grid.name = "WallGrid"
	_grid.material_override = BoundaryPaint.make_material()
	_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_grid)
	_markers = MultiMeshInstance3D.new()
	_markers.name = "LinkMarkers"
	_markers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_markers)
	rebuild()
	# NOT connected to `Tuning.reloaded` here. The map owns the layout, and this
	# node's geometry depends on it: reloading in signal order would rebuild against
	# the old positions and then have to be rebuilt again. The map drives it.


## The leg's centre-line, in the map's frame, mouth to mouth. Set by the map before
## the node enters the tree, and again on reload — the system diameter is a slider
## and the mouths move with it, and so is the curvature.
func follow(line: PackedVector3Array) -> void:
	_region.follow(line)
	if _wall != null:
		rebuild()


func rebuild() -> void:
	_region.mouth_radius = Tuning.num("exploration/aperture_mouth_diameter") * 0.5
	_region.radius = Tuning.num("exploration/corridor_diameter") * 0.5
	_region.flare_length = Tuning.num("exploration/aperture_funnel_length")
	_region.name_of = link_name
	_rebuild_wall()
	_rebuild_markers()
	paint(0.0)


## A frame across the tube at this distance along it. Level, the same frame the lane
## uses, so nothing twists as the corridor bends.
func _cross_frame(along: float) -> Array[Vector3]:
	return CruiseLane.frame_for(_region.path.tangent_at(along))


## The wall, ring by ring, following the same profile the boundary uses.
##
## Rings are packed into the flares and spread down the straight middle: the taper is
## the part with a shape worth drawing, and the middle needs enough rings to follow
## the weave rather than to draw a cylinder.
func _rebuild_wall() -> void:
	var span_m := _region.length()
	if span_m <= 0.001:
		_wall.mesh = null
		_grid.mesh = null
		return
	var stops := _wall_stops(span_m)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in stops.size() - 1:
		var t0: float = stops[i]
		var t1: float = stops[i + 1]
		var r0 := _region.profile(t0)
		var r1 := _region.profile(t1)
		var f0 := _cross_frame(t0)
		var f1 := _cross_frame(t1)
		var c0 := _region.path.point_at(t0)
		var c1 := _region.path.point_at(t1)
		for s in RING_SEGMENTS:
			var a0 := TAU * float(s) / float(RING_SEGMENTS)
			var a1 := TAU * float(s + 1) / float(RING_SEGMENTS)
			var d00: Vector3 = f0[0] * cos(a0) + f0[1] * sin(a0)
			var d01: Vector3 = f0[0] * cos(a1) + f0[1] * sin(a1)
			var d10: Vector3 = f1[0] * cos(a0) + f1[1] * sin(a0)
			var d11: Vector3 = f1[0] * cos(a1) + f1[1] * sin(a1)
			for corner: Array in [
					[c0 + d00 * r0, d00], [c0 + d01 * r0, d01], [c1 + d11 * r1, d11],
					[c0 + d00 * r0, d00], [c1 + d11 * r1, d11], [c1 + d10 * r1, d10]]:
				verts.append(corner[0])
				normals.append(corner[1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_wall.mesh = mesh
	_rebuild_grid(span_m)


## Where to put a ring: dense through each flare, regular down the straight.
func _wall_stops(span_m: float) -> PackedFloat32Array:
	var flare := minf(_region.flare_length, span_m * 0.5)
	var stops := PackedFloat32Array()
	for i in RINGS_PER_FLARE + 1:
		stops.append(flare * float(i) / float(RINGS_PER_FLARE))
	var middle := maxf(span_m - flare * 2.0, 0.0)
	var count := maxi(int(middle / WALL_RING_METRES), 1)
	for i in range(1, count):
		var t := flare + middle * float(i) / float(count)
		if t > flare and t < span_m - flare:
			stops.append(t)
	for i in RINGS_PER_FLARE + 1:
		stops.append(span_m - flare + flare * float(i) / float(RINGS_PER_FLARE))
	return stops


## Rings and longitudinal lines over the wall, so the corridor has a texture that
## moves. Drawn from the same profile as the wall, so the ruling sits ON the surface.
func _rebuild_grid(span_m: float) -> void:
	var spacing := maxf(Tuning.num("exploration/bounds_grid_spacing"), 1.0)
	var lines: Array[PackedVector3Array] = []
	var rings := maxi(int(span_m / spacing), 1)
	# Spaced by the same metres around the tube as along it, so the ruling is square.
	var spokes := maxi(int(TAU * _region.radius / spacing), GRID_MIN_SPOKES)
	for i in rings + 1:
		var t := minf(float(i) * spacing, span_m)
		var frame := _cross_frame(t)
		var centre := _region.path.point_at(t)
		var radius := _region.profile(t)
		var ring := PackedVector3Array()
		for s in RING_SEGMENTS + 1:
			var a := TAU * float(s) / float(RING_SEGMENTS)
			ring.append(centre + (frame[0] * cos(a) + frame[1] * sin(a)) * radius)
		lines.append(ring)
	for s in spokes:
		var a := TAU * float(s) / float(spokes)
		var run := PackedVector3Array()
		for i in rings + 1:
			var t := minf(float(i) * spacing, span_m)
			var frame := _cross_frame(t)
			run.append(_region.path.point_at(t)
				+ (frame[0] * cos(a) + frame[1] * sin(a)) * _region.profile(t))
		lines.append(run)
	_grid.mesh = BoundaryPaint.make_grid(lines)


func _rebuild_markers() -> void:
	var spacing := Tuning.num("exploration/marker_spacing")
	var span_m := _region.length()
	if spacing <= 0.0 or span_m <= 0.001:
		return
	var places: Array[Vector3] = []
	var across := int(_region.radius / spacing)
	var steps := int(span_m / spacing)
	for iz in range(1, steps):
		var t := float(iz) * spacing
		var allowed := _region.profile(t)
		var frame := _cross_frame(t)
		var centre := _region.path.point_at(t)
		for ix in range(-across, across + 1):
			for iy in range(-across, across + 1):
				var offset := Vector2(float(ix) * spacing, float(iy) * spacing)
				if offset.length() > allowed:
					continue
				places.append(centre + frame[0] * offset.x + frame[1] * offset.y)
	_markers.multimesh = BoundaryPaint.make_markers(places)
	_markers.material_override = BoundaryPaint.make_marker_material()


func paint(warning_level: float) -> void:
	BoundaryPaint.tint([_wall], warning_level,
		Tuning.num("exploration/bounds_rim_alpha_scale"))
	BoundaryPaint.tint([_grid], warning_level,
		Tuning.num("exploration/bounds_grid_alpha_scale"))


## The boundary this node draws: the bounded space between two systems. The map
## composes it into the field alongside the discs (ADR 0063).
func region() -> TubeRegion:
	return _region


## Mouth to mouth, ALONG the leg. Longer than the straight-line gap between the two
## systems now, because the leg weaves — which is the honest number for "how far is
## it if you decline the road".
func length() -> float:
	return _region.length()


func marker_count() -> int:
	return 0 if _markers.multimesh == null else _markers.multimesh.instance_count
