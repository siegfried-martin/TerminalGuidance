# ADR 0095 — The road is straight edges on a lattice, and a direction change is an angle at a vertex

*Status: accepted · 2026-09-06 · from the human, after five sessions of highway bugs:
"I need something that works correctly above anything else"*

## Decision

**A route is a polyline whose vertices are lattice cells.** A triangular lattice in the
horizontal plane, step `lattice_cell_metres`, with integer levels of
`lattice_level_metres` for height. Systems, mouths and junction sockets are cells.

**Every edge is a straight road**, built by stepping the existing unit-box modules along
it (ADR 0078), which on a straight is exact. An edge between two levels is a pitched
straight.

**Every direction change is an angle at a vertex.** The building does not curve. Each
edge's building is extended past the vertex by `h·tan(θ/2)` so the outer corner is
closed, a collar on the bisector hides the overlap, and the lane through the vertex is
a circular fillet of `road_fillet_radius`. The fillet is a feel value, bounded below by
the gate so the road can never out-turn the ship (ADR 0070) or fold the inner carriageway
(ADR 0077).

**A junction is an authored tile occupying one edge**, with its ramp socket at a declared
cell and its apertures declared in a sidecar. Nothing about a junction is measured.

**Routes are data**, in `data/routes.json`, hot-reloaded like `tuning.cfg`. Leg lengths,
bearings, heights and ramp shapes stop being tuning keys, because they are what the
route *is*.

**The shell barrier stays derived from the path and the section, never from the mesh.**
Art and collision are independent, so dressing the road never re-tests the game.

## Why

Nearly every highway bug since ADR 0087 is one of two things, and both are properties
of deriving geometry from a curve. A rigid box on a curve cannot meet its neighbour
(ADR 0094 states the limit honestly and hides it with a bleed). A ramp fitted as a cubic
crosses a building wherever the fit puts it, and the opening then has to be measured,
and every measurement in `RoadNetwork` has been wrong at least once.

Two alternatives were worked through and lost:

- **A catalogue of curved tiles** (the earlier plan of the same day). It was found on
  review that a hex lattice has 60° symmetry and not 30°, so no curved tile can serve
  both heading families; that a 30° turn cannot fit the (1,1) footprint it was given
  without a kink; and that the catalogue would double for real art. More machinery, not
  less.
- **Keep the curves and fix the measurements.** Five sessions say no.

Straight edges make the whole thing exact with nothing new: the module system is kept,
restricted to the case it was always right for, and the only computed joint left is the
vertex, which has one input and a bounded rule. The lattice is what makes loops and
interchange ramps close for free. And the human does not need the visual of a curved
highway; what is needed is that a direction change be flyable, and the filleted lane is
that, with the gate keeping it honest.

The finer directions are free too. Every vector between two cells is an edge direction,
so a road can point at 13.9° with a four-cell edge or at 15.3° with a longer one. **15°
exactly is on no lattice** (its tangent is irrational in both hex and square bases), and
no tile size fudges it in. Nobody can read the difference from a frame.

## What this supersedes

- **ADR 0070**, the weave and the cubic ramp: curvature is no longer expressed as an
  angle over a period, and a ramp is no longer a fitted cubic. *The rule that no road
  out-turns the ship stands unchanged* and is now checked on filleted lanes and on every
  junction tile's declared runs.
- **ADR 0085**, the two-sweep interchange and the measured crossing: an interchange is
  two junction tiles and a lane route between them, closing exactly. The five-system map
  and "a route is the unit" stand.
- **ADR 0094**, entirely: there is no curved stretch for a box to fall short of.
- **ADRs 0088, 0091, 0093, the measuring half only.** An aperture is still a stretch, a
  roadway still opens for the whole merge, a wall still opens a bounded length, an exit
  is still cut and an entry still troughs. Those are now declared by the junction tile
  and asserted by the gate from its sidecar, rather than measured off a cubic.
- **ADR 0078 is narrowed, not superseded.** Modules are stepped along straight edges
  only. The unit-section contract and the mesh-swap promise stand.

## What this forbids

- **Do not add a curved road.** Not a curved edge, not a curved tile, not a spline
  between cells. If a road needs to bend, it takes an angle at a vertex, and if the
  angle is too sharp it takes two.
- **Do not place a vertex off the lattice**, and do not nudge a cell by a coordinate to
  make something line up. If two things do not meet, one of them is on the wrong cell.
- **Do not measure where a ramp meets a road.** A ramp starts at a junction's socket cell
  and ends at a mouth or at another socket cell. If a ramp does not reach, the route is
  wrong, and the gate says which vertex.
- **Do not put a road's shape in `tuning.cfg`.** Lengths, bearings, heights, offsets
  and depths are route data. What stays in tuning is the section, the modules, and the
  fillet radius, because those are how every road is built and are nudged while
  looking.
- **Do not let the mesh decide the barrier.** The barrier is the path and the section,
  as ADR 0087 built it. A junction's open faces come from its sidecar, not its geometry.
- **Do not bring back the bleed.** A box on a straight edge reaches its neighbour; if it
  does not, the edge is not straight and that is the bug.
- **Do not add a junction variant by hand-editing a mesh.** The generator emits it with
  its sidecar, or real art replaces the generator's output in place with the sidecar
  unchanged.
- Do not relax a §5 bound to make a route validate. Change the route.
