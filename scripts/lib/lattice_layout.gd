class_name LatticeLayout
extends RefCounted
## The map, laid out from `data/routes.json`. Pure — no scene tree, no tuning, no
## disk; the caller reads `Routes` and `Tuning` and hands the pieces in.
##
## A route is a polyline of lattice cells and every edge is a straight road (ADR
## 0095), so laying the map out is arithmetic on integers rather than a walk down a
## list of tuned leg lengths with a weave fitted to each. **Leg lengths are derived**:
## a leg is the sum of its edges, which is what retires the four `*_leg_length` keys.
##
## A SYSTEM SITS ON A CELL. Snapping a 3.5 km disc to a 600 m cell moves it by at most
## 300 m, which is invisible, and integer coordinates are stable under re-authoring —
## so "place nothing by coordinate" stops being a discipline anyone has to keep.
##
## What comes out is a `MapLayout`, the same shape the legacy layout produces, so
## nothing downstream of `SystemMap` knows which one built it.


## `names` is the system roster in index order; an anchor in the route file is matched
## to it by name. `radius` is a system's own half-diameter, used to hold the corridors
## off the discs the way the legacy layout's mouth-to-mouth legs did.
static func build(specs: Array[RouteSpec], anchors: Dictionary,
		lattice: HexLattice, limits: RoadLimits, names: PackedStringArray,
		radius: float) -> MapLayout:
	var layout := MapLayout.new()
	layout.on_lattice = true
	for i in names.size():
		layout.positions.append(Vector3.ZERO)
		layout.bearings.append([] as Array[float])

	# The systems, from the anchors. On the combat plane: the level a route rides at
	# lifts the ROAD, not the place it passes through.
	for i in names.size():
		var anchor := String(names[i])
		if anchors.has(anchor):
			layout.positions[i] = lattice.to_world(
				(anchors[anchor] as Dictionary)["cell"] as Vector2i, 0)

	for spec in specs:
		if spec.is_lane():
			continue
		var world := spec.world_vertices(lattice)
		if world.size() < 2:
			continue
		layout.route_names.append(spec.name)
		layout.route_specs.append(spec)
		layout.route_heights.append(0.0)
		# The line the road is laid on is the FILLETED spine. The buildings are built
		# per edge from the vertices and never see this; what reads it is the deep
		# field, the map's own "where does this road go", and the gate.
		layout.route_lines.append(RoadPath.fillet(world, limits.fillet_radius(),
			RoadPath.FILLET_SEGMENT_METRES))

		# Which systems this route serves, in the order it meets them. A vertex that
		# names an anchor is a system on the road; every other vertex is a bend.
		var on_route := PackedInt32Array()
		var at_vertex := PackedInt32Array()
		for i in spec.vertex_count():
			var index := names.find(spec.anchor_names[i])
			if index >= 0:
				on_route.append(index)
				at_vertex.append(i)
		layout.route_systems.append(on_route)

		# The apertures. A system's rim opens the way each road leaves it and the way
		# it came in — asked of the route's own EDGES rather than of a bearing, which
		# is the same reading the legacy layout took of its legs and the only one that
		# still means anything when a route bends between two systems.
		for i in on_route.size():
			var vertex := at_vertex[i]
			var facings := layout.bearings[on_route[i]] as Array[float]
			if vertex < spec.vertex_count() - 1:
				facings.append(lattice.bearing_of(spec.edge(vertex)))
			if vertex > 0:
				facings.append(lattice.bearing_of(-spec.edge(vertex - 1)))

		# One corridor per leg, mouth to mouth on the combat plane, in the order
		# `SystemMap` created its links.
		for i in at_vertex.size() - 1:
			layout.corridors.append(_corridor(spec, lattice, at_vertex[i],
				at_vertex[i + 1], radius))

	if not layout.route_lines.is_empty():
		layout.spine = layout.line_of(0)
	return layout


## The bounded space between two systems: the route's own vertices between them, flat
## on the combat plane, trimmed by a system radius at each end.
##
## FLAT, and that is deliberate. A corridor is what off-road travel is bounded by, and
## off-road travel happens on the plane the systems are on. The road is 360 m above it
## and carries its own space (ADR 0091), so nothing here has to reach up to cover it.
static func _corridor(spec: RouteSpec, lattice: HexLattice, from_vertex: int,
		to_vertex: int, radius: float) -> PackedVector3Array:
	var flat := PackedVector3Array()
	for i in range(from_vertex, to_vertex + 1):
		var at := lattice.to_world(spec.cells[i], 0)
		flat.append(Vector3(at.x, 0.0, at.z))
	if flat.size() < 2:
		return flat
	var path := RoadPath.new()
	path.set_points(flat)
	var span := path.length()
	if span <= radius * 2.0 + 1.0:
		return flat
	return path.section(radius, span - radius)
