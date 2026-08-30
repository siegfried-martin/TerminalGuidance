class_name SystemDisc
extends Node3D
## The drawn body of a system: hard flat faces, and a rim that opens only where a
## road attaches (ADR 0011, as amended by ADR 0062).
##
## The height is asymmetric and decomposes rather than coming from a ratio
## (ADR 0061): a combat band around y = 0, `system_ceiling_height` of clearance
## above it *so the ceiling never enters a fight*, and `system_floor_depth` below,
## deep enough to hold the planet with the hard floor under it.
##
## **The boundary itself lives in `DiscRegion`, and the map owns it.** This node
## draws that region and nothing else decides anything: the hole in the rim mesh is
## built from the same `rim_is_open` the boundary is enforced with, so the picture
## and the rule cannot drift apart. The funnel through the hole is not drawn here
## either — it belongs to the corridor, which is the same shape (`SystemLink`).
##
## Everything is parent-relative and rebuilt on hot reload (ADR 0020).

## How finely the rim is tessellated. Infrastructure, not feel: enough segments
## that the aperture's edge is not visibly faceted at the disc's scale.
const RIM_SEGMENTS := 128
## The fewest lines the grid will draw around a circle, however coarse the spacing
## is tuned. Infrastructure, not feel: below this a "grid" is a couple of lines and
## reads as debris rather than as a ruled surface.
const GRID_MIN_SPOKES := 8

## Where the road leaves, in degrees. Assigned by the map before the node enters the
## tree — the bearings come from the layout, not from a preference, because a leg
## and the aperture it uses cannot disagree.
var bearings: Array[float] = []
## What the HUD calls this place.
var system_name: String = "SYSTEM"

## Ceiling and floor, drawn as flat slabs that redden as the player nears them.
var _ceiling: MeshInstance3D
var _floor: MeshInstance3D
## The rim wall, built as an ArrayMesh so the apertures can be holes in it rather
## than decals over it.
var _rim: MeshInstance3D
## A ruled grid over all three surfaces. The translucent faces alone are one flat
## colour filling the view, and a ship flying at one has nothing in the frame that
## moves; the grid is the texture that slides past. Drawn from the same radius and
## the same `rim_is_open` as the surfaces, so it cannot disagree with them.
var _grid: MeshInstance3D
## Reference markers filling the volume, so motion is legible in empty space. The
## combat arena's `GrayBoxArena` fills a cube; a disc is a different shape and gets
## its own placement rather than a shape flag on that one.
var _markers: MultiMeshInstance3D
## The boundary this node draws. Positioned in the map's frame, which is why the
## region carries a centre rather than relying on where the node happens to hang.
var _region: DiscRegion = DiscRegion.new()


func _ready() -> void:
	_ceiling = _make_surface("Ceiling")
	_floor = _make_surface("Floor")
	_rim = _make_surface("Rim")
	_grid = _make_surface("Grid")
	_markers = MultiMeshInstance3D.new()
	_markers.name = "SystemMarkers"
	_markers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_markers)
	rebuild()
	# NOT connected to `Tuning.reloaded` here. The map owns the layout, and this
	# node's geometry depends on it: reloading in signal order would rebuild against
	# the old positions and then have to be rebuilt again. The map drives it.


func _make_surface(surface_name: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = surface_name
	node.material_override = BoundaryPaint.make_material()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func rebuild() -> void:
	_rebuild_region()
	for node: MeshInstance3D in [_ceiling, _floor]:
		if node.mesh == null:
			node.mesh = CylinderMesh.new()
		var mesh := node.mesh as CylinderMesh
		mesh.top_radius = _region.radius
		mesh.bottom_radius = _region.radius
		# A slab rather than a plane: seen edge-on from inside, a zero-height disc
		# vanishes exactly when the player most needs to see where it is.
		mesh.height = Tuning.num("exploration/bounds_face_thickness")
		mesh.radial_segments = 64
		mesh.rings = 1
	_ceiling.position = Vector3(0.0, ceiling_height(), 0.0)
	_floor.position = Vector3(0.0, -floor_depth(), 0.0)
	_rebuild_rim()
	_rebuild_grid()
	paint(0.0)
	_rebuild_markers()


## The boundary, from tuning and from the layout the map handed down. Built once per
## reload rather than per frame, and it is the same object the meshes come from.
func _rebuild_region() -> void:
	_region.center = position
	_region.radius = Tuning.num("exploration/system_diameter") * 0.5
	_region.ceiling = ceiling_height()
	_region.floor_depth = floor_depth()
	_region.aperture_radius = Tuning.num("exploration/aperture_mouth_diameter") * 0.5
	_region.name_of = system_name
	var directions: Array[Vector3] = []
	for degrees: float in bearings:
		directions.append(bearing_to_direction(degrees))
	_region.apertures = directions


## A compass bearing as a horizontal unit vector. 0 is -Z, counting clockwise, so
## the number in `tuning.cfg` reads the way a bearing reads.
static func bearing_to_direction(degrees: float) -> Vector3:
	var radians := deg_to_rad(degrees)
	return Vector3(sin(radians), 0.0, -cos(radians))


## The rim wall, with the apertures as actual holes.
##
## An ArrayMesh rather than a cylinder with something drawn over it: a hole you can
## fly through has to be a hole in the thing being drawn, or the picture and the
## boundary disagree and the player learns to distrust the picture.
func _rebuild_rim() -> void:
	var top := ceiling_height()
	var bottom := -floor_depth()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in RIM_SEGMENTS:
		var a0 := TAU * float(i) / float(RIM_SEGMENTS)
		var a1 := TAU * float(i + 1) / float(RIM_SEGMENTS)
		var d0 := Vector3(sin(a0), 0.0, -cos(a0))
		var d1 := Vector3(sin(a1), 0.0, -cos(a1))
		var mid := Vector3(sin((a0 + a1) * 0.5), 0.0, -cos((a0 + a1) * 0.5))
		if _region.rim_is_open(_region.center + mid * _region.radius):
			continue
		var p0 := d0 * _region.radius
		var p1 := d1 * _region.radius
		for corner: Array in [
				[p0, bottom, d0], [p1, bottom, d1], [p1, top, d1],
				[p0, bottom, d0], [p1, top, d1], [p0, top, d0]]:
			var base: Vector3 = corner[0]
			verts.append(Vector3(base.x, corner[1], base.z))
			normals.append(corner[2])

	if verts.is_empty():
		_rim.mesh = null
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_rim.mesh = mesh


## Circles and spokes on the ceiling and floor, uprights and level rings on the rim.
##
## The grid is what makes the disc read as a room with a size rather than as a wash of
## colour: at 160 m/s a ruled line passing the canopy is the only thing on a bare
## boundary that says how fast you are going. The rim skips its apertures for the same
## reason the wall does — a line across the opening is a wall drawn where the hole is.
func _rebuild_grid() -> void:
	var spacing := maxf(Tuning.num("exploration/bounds_grid_spacing"), 1.0)
	var top := ceiling_height()
	var bottom := -floor_depth()
	var lines: Array[PackedVector3Array] = []
	# Spokes are spaced by the SAME metres as the rings, measured around the rim, so
	# the grid is square where it matters rather than being a fan of lines that are
	# metres apart at the middle and hundreds apart at the wall.
	var spokes := maxi(int(TAU * _region.radius / spacing), GRID_MIN_SPOKES)
	for height: float in [top, bottom]:
		var rings := maxi(int(_region.radius / spacing), 1)
		for i in range(1, rings + 1):
			var r := minf(float(i) * spacing, _region.radius)
			var ring := PackedVector3Array()
			for s in RIM_SEGMENTS + 1:
				var a := TAU * float(s) / float(RIM_SEGMENTS)
				ring.append(Vector3(sin(a) * r, height, -cos(a) * r))
			lines.append(ring)
		for s in spokes:
			var a := TAU * float(s) / float(spokes)
			var d := Vector3(sin(a), 0.0, -cos(a))
			lines.append(PackedVector3Array([Vector3(0.0, height, 0.0),
				d * _region.radius + Vector3(0.0, height, 0.0)]))

	# The rim: uprights where the wall is solid, and level rings drawn as arcs that
	# break at each opening.
	for s in spokes:
		var a := TAU * float(s) / float(spokes)
		var d := Vector3(sin(a), 0.0, -cos(a))
		if _region.rim_is_open(_region.center + d * _region.radius):
			continue
		lines.append(PackedVector3Array([d * _region.radius + Vector3(0.0, bottom, 0.0),
			d * _region.radius + Vector3(0.0, top, 0.0)]))
	var levels := maxi(int((top - bottom) / spacing), 1)
	for i in levels + 1:
		var y := bottom + minf(float(i) * spacing, top - bottom)
		var arc := PackedVector3Array()
		for s in RIM_SEGMENTS + 1:
			var a := TAU * float(s) / float(RIM_SEGMENTS)
			var d := Vector3(sin(a), 0.0, -cos(a))
			if _region.rim_is_open(_region.center + d * _region.radius):
				if arc.size() > 1:
					lines.append(arc)
				arc = PackedVector3Array()
				continue
			arc.append(d * _region.radius + Vector3(0.0, y, 0.0))
		if arc.size() > 1:
			lines.append(arc)
	_grid.mesh = BoundaryPaint.make_grid(lines)


## Markers filling the disc, on a lattice clipped to the cylinder. Reference
## geometry, not scenery: nothing here is queryable and nothing eats a missile.
func _rebuild_markers() -> void:
	var spacing := Tuning.num("exploration/marker_spacing")
	if spacing <= 0.0:
		return
	var radius_m := _region.radius
	var places: Array[Vector3] = []
	var across := int(radius_m / spacing)
	var up := int(ceiling_height() / spacing)
	var down := int(floor_depth() / spacing)
	for ix in range(-across, across + 1):
		for iz in range(-across, across + 1):
			var x := float(ix) * spacing
			var z := float(iz) * spacing
			if Vector2(x, z).length() > radius_m:
				continue
			for iy in range(-down, up + 1):
				places.append(Vector3(x, float(iy) * spacing, z))
	_markers.multimesh = BoundaryPaint.make_markers(places)
	_markers.material_override = BoundaryPaint.make_marker_material()


## The faces are always faintly visible so the volume has a shape, and go red as the
## player nears one. All of them light together: which one you are approaching is
## obvious from looking at it, and lighting only the near one makes the disc read as
## a plane rather than as a room.
func paint(warning_level: float) -> void:
	BoundaryPaint.tint([_ceiling, _floor], warning_level, 1.0)
	# The rim is a single-thickness wall seen face-on, where the slabs are seen
	# edge-on and stack their own depth. Same colour, more of it.
	BoundaryPaint.tint([_rim], warning_level,
		Tuning.num("exploration/bounds_rim_alpha_scale"))
	BoundaryPaint.tint([_grid], warning_level,
		Tuning.num("exploration/bounds_grid_alpha_scale"))


func ceiling_height() -> float:
	return Tuning.num("exploration/system_ceiling_height")


func floor_depth() -> float:
	return Tuning.num("exploration/system_floor_depth")


## Floor to ceiling. Derived, never tuned: the two halves are set separately because
## the planet lives under one of them (ADR 0061), and a single height key would make
## that relationship impossible to express.
func height() -> float:
	return ceiling_height() + floor_depth()


func radius() -> float:
	return Tuning.num("exploration/system_diameter") * 0.5


## The boundary this node draws. The map composes these into the field.
func region() -> DiscRegion:
	return _region


## Where the rim opens, in the map's frame — the point a corridor attaches to.
func aperture_mouth(index: int) -> Vector3:
	return _region.aperture_mouth(index)


func aperture_count() -> int:
	return _region.apertures.size()


func marker_count() -> int:
	return 0 if _markers.multimesh == null else _markers.multimesh.instance_count
