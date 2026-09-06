# ADR 0078 — The road is built from modules, and a deck is the lane rather than the building

*Status: accepted · 2026-08-31 · from four sessions of tuning a road that would not read as a place*

## Decision

**The highway is modules placed along a path, not one swept mesh.** `RoadStructure`
steps four `MultiMeshInstance3D` layers along the road — metal collars, glazed bays,
a roadway, and a median pane — where `RoadDeck` used to sweep a single continuous
`ArrayMesh`.

**A deck is the lane you fly in; the structure is the building around it.** Those were
one object. `RoadDeck` now owns the path, the `CruiseLane` sample, the portals at its
ends, and the markings painted on its own carriageway. Everything you could stand on
belongs to `RoadStructure`.

**One structure per pair of decks.** The mainline pair share a single building
straddling the spine, a carriageway either side of the median. A ramp is the same
building with one lane in it and no median.

**The unit section is the contract.** Every module is authored inside `x, y, z` in
`[-0.5, 0.5]` by `tools/gen_road_modules.py`, and each instance is scaled by (full
width, full height, that module's length). **The box is the clear interior** —
modules sit on or outside its faces, so the space a ship flies through is exactly the
box and the lane's half-extents are the structure's inside face.

## Why

Four sessions of tuning colour, alpha, rib spacing and line count did not make the
road read as a place, and the human gave up on it. The concept art generated to find
out what was missing answered a question nobody had asked: **the structure is modular
and ours was extruded.** A swept mesh repeats nothing, so nothing about it looks
manufactured — it is an abstract volume with a tint, and no amount of tint fixes that.

Three things follow from modules at once, and only the first was the goal:

- **The road bends between segments rather than within one**, which is what makes a
  built thing look built.
- **Real art becomes a mesh swap.** That is ADR 0030's promise, and it was not true of
  the road: no generated or authored asset could ever have dropped into a procedural
  sweep. It is true now, and the unit-section contract is what makes it true.
- **Vertex count collapses.** A mainline shell was tens of thousands of vertices; the
  whole highway is four meshes and a transform list.

**The split had to happen for the pair to share a building.** A deck cannot own a
structure that also belongs to the deck coming the other way, and after ADR 0077 put
the two carriageways side by side there is exactly one building over both of them.
That is the honest object graph and it was worth the churn: it is also what step D's
roadway dock and step C's ramp rings attach to.

The two halves have to agree about where the road narrows, so the flare arithmetic
moved to `LaneProfile` — pure, shared, and written once rather than twice.

## What this forbids

- Do not build road geometry by sweeping a mesh along a path again. If a piece of the
  road cannot be expressed as a module repeated, it is scenery and belongs somewhere
  else.
- Do not give `RoadDeck` geometry that is part of the building. The test is whether
  the oncoming carriageway shares it: if it does, it is the structure's.
- Do not author a module outside the unit section, and **do not let one reach inward
  past its faces**. A module that eats the interior eats the lane, and the lane is
  what the hull clearance is measured against (ADR 0068).
- Do not scale a module by anything but (width, height, length) at its station. A
  module that knows where it is on the road is a module real art cannot replace.
- Do not rebuild geometry when the ridden deck changes. Becoming active is a repaint,
  and it happens at the moment the player is merging.
- Do not compute the flare twice. `LaneProfile` answers for the lane and the building
  both, or they drift.
