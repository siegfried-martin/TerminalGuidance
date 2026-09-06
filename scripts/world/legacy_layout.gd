class_name LegacyLayout
extends RefCounted
## The leg-walking layout: systems in a line per route, at tuned distances, joined by
## legs that weave and undulate.
##
## Extracted from `SystemMap.relayout` **unchanged**, so the lattice (ADR 0095) can
## take its place without moving the old road while both exist. `make fly` still runs
## this one; `make lattice` runs `LatticeLayout`. **This file goes in step D**, along
## with the twenty-four tuning keys it reads and the weave it fits.
##
## Legs are measured mouth to mouth, so centre to centre is the leg plus one system
## radius at each end — which is why the system diameter being a slider moves the
## systems apart as well as making them bigger.

## The legs, in order. One key per leg; systems are legs + 1, and the layout walks the
## list — so adding a system is adding a leg rather than editing a topology.
const LEG_KEYS: PackedStringArray = ["exploration/local_leg_length",
	"exploration/trunk_leg_length", "exploration/cross_inbound_leg_length",
	"exploration/cross_outbound_leg_length"]

## TWO HIGHWAYS, CROSSING AT SYSTEM B. A route is the systems on it in order, the legs
## between them, a bearing off the map's own, and the height its road rides at. A
## system on more than one route is where they meet (ADR 0085).
##
## Each route is anchored on one system whose position is already fixed: route 0
## anchors A at the origin and lays the rest out from it; route 1 anchors on B, which
## route 0 has already placed, so the two can never drift apart.
const ROUTE_SYSTEMS := [[0, 1, 2], [3, 1, 4]]
const ROUTE_LEGS := [[0, 1], [2, 3]]
const ROUTE_ANCHORS := [0, 1]
const ROUTE_BEARING_KEYS: PackedStringArray = ["", "exploration/crossing_bearing_deg"]
const ROUTE_HEIGHT_KEYS: PackedStringArray = ["exploration/road_height",
	"exploration/crossing_road_height"]


static func build(names: PackedStringArray,
		route_names: PackedStringArray) -> MapLayout:
	var layout := MapLayout.new()
	layout.route_names = route_names
	var radius := Tuning.num("exploration/system_diameter") * 0.5
	var bearing := Tuning.num("exploration/aperture_bearing_deg")
	for i in names.size():
		layout.positions.append(Vector3.ZERO)
		layout.bearings.append([] as Array[float])

	for route in ROUTE_SYSTEMS.size():
		var on_route: Array = ROUTE_SYSTEMS[route]
		var key: String = ROUTE_BEARING_KEYS[route]
		var route_bearing := bearing \
			+ (0.0 if key.is_empty() else Tuning.num(key))
		var step := SystemDisc.bearing_to_direction(route_bearing)
		var anchor: int = ROUTE_ANCHORS[route]

		# Walk BACK from the anchor and then forward from it, so a route hung on a
		# system another route already placed cannot move it.
		var here: Vector3 = layout.positions[on_route[anchor]]
		var lengths := PackedFloat32Array()
		for i in on_route.size() - 1:
			lengths.append(Tuning.num(LEG_KEYS[(ROUTE_LEGS[route] as Array)[i]]))
		var at := here
		for i in range(anchor - 1, -1, -1):
			at -= step * (lengths[i] + radius * 2.0)
			layout.positions[on_route[i]] = at
		at = here
		for i in range(anchor, on_route.size() - 1):
			at += step * (lengths[i] + radius * 2.0)
			layout.positions[on_route[i + 1]] = at

		# The legs, once every system on the route is placed.
		var legs: Array[PackedVector3Array] = []
		for i in on_route.size() - 1:
			var from_at: Vector3 = layout.positions[on_route[i]]
			legs.append(RoadPath.weave(from_at + step * radius, step, lengths[i],
				Tuning.num("exploration/road_curve_deg"),
				Tuning.num("exploration/road_curve_period"),
				Tuning.num("exploration/road_rise_deg"),
				Tuning.num("exploration/road_rise_period")))
			# The CORRIDOR is mouth to mouth: the bounded space between two systems,
			# handed the leg's own centre-line rather than two endpoints, so the
			# corridor and the highway inside it cannot drift apart.
			layout.corridors.append(legs[i])
			(layout.bearings[on_route[i]] as Array[float]).append(route_bearing)
			(layout.bearings[on_route[i + 1]] as Array[float]).append(
				route_bearing + 180.0)

		# The SPINE: behind the first system on the route, through every centre, along
		# every leg, and out past the last. The road is laid on this and the deep field
		# is scattered around it, so one polyline per route is the only place a route
		# is written down.
		var spine := PackedVector3Array()
		spine.append(layout.positions[on_route[0]] - step * radius)
		for i in on_route.size():
			spine.append(layout.positions[on_route[i]])
			if i < legs.size():
				for point: Vector3 in legs[i]:
					spine.append(point)
		spine.append(layout.positions[on_route[on_route.size() - 1]] + step * radius)

		var carried := PackedInt32Array()
		for index: int in on_route:
			carried.append(index)
		layout.route_systems.append(carried)
		layout.route_lines.append(spine)
		layout.route_heights.append(Tuning.num(ROUTE_HEIGHT_KEYS[route]))

	layout.spine = layout.line_of(0)
	return layout
