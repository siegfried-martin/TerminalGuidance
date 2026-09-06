class_name MapLayout
extends RefCounted
## Where the systems are and what shape each road is — the answer, not the method.
## Pure: a plain result object, no scene tree, no disk.
##
## `SystemMap` used to work this out inline by walking a list of leg lengths. There
## are two ways to lay a map now — the legacy legs and the lattice (ADR 0095) — and
## they have to coexist until step D swaps them, so the map takes a layout rather than
## being one. Everything downstream of here is identical for both.

## One system per entry, in `SystemMap.NAMES` order. Positions are on the COMBAT
## PLANE: a road rides above it, and how far above is the road's business.
var positions: Array[Vector3] = []
## Per system, the compass bearings its rim opens on — one per road leaving it, both
## ways along each. A system on two roads has four.
var bearings: Array = []

## Per route: its name, the systems on it in order, the line it is laid on, and the
## height that line still has to be lifted by.
var route_names: PackedStringArray = PackedStringArray()
var route_systems: Array = []
var route_lines: Array = []
## Zero on the lattice, where a vertex's level already puts the line at its height.
var route_heights: PackedFloat32Array = PackedFloat32Array()
## The parsed route, on the lattice only. `RoadNetwork` builds per EDGE from this, and
## an edge is a thing a polyline has forgotten about.
var route_specs: Array = []

## One corridor per leg, in the order `SystemMap` created its links: the bounded space
## between two systems, on the combat plane, for the trip you take by declining the
## road.
var corridors: Array = []

## The line the deep field is scattered around and the map reports as "the" spine.
var spine: PackedVector3Array = PackedVector3Array()

## Whether the roads here are lattice routes. `SystemMap` and `RoadNetwork` branch on
## it in exactly one place each, and both branches go in step D.
var on_lattice: bool = false


func route_count() -> int:
	return route_names.size()


func systems_on(route: int) -> PackedInt32Array:
	return route_systems[route] as PackedInt32Array


func line_of(route: int) -> PackedVector3Array:
	return route_lines[route] as PackedVector3Array


func spec_of(route: int) -> RouteSpec:
	return route_specs[route] as RouteSpec if route < route_specs.size() else null


func corridor(index: int) -> PackedVector3Array:
	return corridors[index] as PackedVector3Array
