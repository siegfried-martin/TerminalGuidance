# The Highway on a Lattice — Plan of Record

*Written 2026-09-06, after five play sessions in which the highway consumed most of the
project's time and kept producing the same shape of bug. This is the second plan of the
day: the first (the "tile plan", same file, earlier in `git log`) proposed a catalogue of
curved tiles, and its review found that no curved tile can serve both heading families
of a hex lattice, that a 30° turn cannot fit the footprint it was given, and that the
catalogue would double for real art. The human's own proposal, a straight road made of
lattice steps, turned out to be the simpler and more stable design, and this document is
that proposal worked through.*

*It supersedes the construction half of `HIGHWAY_STRUCTURE_PLAN.md`. The section, the
glass, the docking and the exit-face rules from that plan all stand. ADR 0095 records the
decision; this file is the reasoning and the build order.*

**Stated priority, from the human: it must work correctly above anything else.** Every
choice below was made against that. Where a more expressive option existed, it lost.

---

## 1. The problem, stated precisely

The current road derives geometry from a curve. `RoadNetwork` lays a weaving polyline and
`RoadStructure` steps rigid box modules along it; ramps are fitted cubics that cross the
mainline's building wherever the fit puts them, and the opening is measured after the
fact. Nearly every highway bug in ADRs 0087 to 0094 is one of two things:

- **A rigid box on a curve does not meet its neighbour.** ADR 0094 states the limit: two
  consecutive joints on a curve are not parallel, so no placement of a straight box makes
  both ends meet. The bleed hides it; nothing removes it.
- **Junctions are measured, not authored.** `crossing`, `overlap`, `_facing`,
  `_opposite`, `_clear_of`, span piercing, per-face trimming. Each is a measurement
  standing in for a decision, and each has been wrong at least once.

Both are properties of the approach, and the approach is *curves plus measurement*.

## 2. The decision

**A route is a polyline whose vertices are lattice cells. Every edge is a straight road.
Every direction change is an angle at a vertex. Junctions are authored tiles that occupy
an edge.**

Three things follow, and they are the whole argument:

- **A straight edge is exact.** The existing unit-box modules stepped along a straight
  are watertight with no bleed, because a straight box on a straight segment is the case
  ADR 0078's module system was always correct for. The module code survives, restricted
  to what it was right about.
- **Every direction change is exact.** Two straight edges share a vertex by definition.
  The only computed joint on the whole road is the vertex, and it has one input, the
  angle, and one bounded rule (§5).
- **Closure is free.** An interchange ramp between two lattice roads starts at a cell and
  ends at a cell, and the sum of lattice vectors is a lattice vector. The fitted cubic
  that solved that by hand is deleted rather than replaced.

**The road does not curve.** The building is straight and hard-cornered. The *lane*
inside it is filleted at each vertex so the axis the camera and the nose follow turns
smoothly. The human said the visual of a curved highway is not needed; what is needed
is that a direction change be flyable, and the fillet is what makes it so, bounded by
the gate that already exists (ADR 0070).

## 3. The lattice

### 3.1 Basis

A triangular lattice in the horizontal plane, axial coordinates `(q, r)`, step `s`
(`lattice_cell_metres`). In Godot's frame (`-Z` forward, `+Y` up, `+X` east):

| | World vector | Bearing (`SystemDisc.bearing_to_direction`, 0 = -Z, clockwise) |
|---|---|---|
| `e₁` | `(s, 0, 0)` | 90° (due east) |
| `e₂` | `(s/2, 0, -s·√3/2)` | 30° |

`cell (q, r)` is at `q·e₁ + r·e₂`. **Levels** are the vertical axis: a vertex at level
`n` sits at `y = n · lattice_level_metres`. Level 0 is the combat plane.

### 3.2 Which directions exist

Every vector between two cells is a lattice vector, so **every edge direction is a
lattice direction, and a long edge has a bearing as fine as anyone wants.** The short
ones, which are the ones a route reaches for:

| Vector `(a, b)` | Off `e₁` | Length (cells) | Metres at `s = 600` |
|---|---|---|---|
| (1, 0) | 0° | 1.000 | 600 |
| (4, 1) | 10.9° | 4.583 | 2750 |
| (3, 1) | 13.9° | 3.606 | 2163 |
| (2, 1) | 19.1° | 2.646 | 1587 |
| (3, 2) | 23.4° | 4.359 | 2615 |
| (1, 1) | 30° | 1.732 | 1039 |
| (8, 3) | 15.3° | 9.849 | 5909 |
| (11, 4) | 14.9° | 13.454 | 8072 |

With mirrors and 60° rotations, the four-cell-or-shorter vectors alone give twelve
distinct lines through 180°. **15° exactly is on no lattice**: its tangent is irrational
in both the hex and the square basis, so it cannot be fudged in by any tile size. 13.9°
is the short answer and 15.3° the long one, and neither is distinguishable from 15° in a
frame. The human's "three hexes in a line and a fourth offset" is `(3, 1)`, and it was
right.

### 3.3 Why hexagonal

It barely matters in this design, which is itself a finding: the plan this replaces
needed the hex lattice's equal step lengths for its tile footprints, and a straight edge
of any length needs nothing of the kind. Hex is kept for the 60° crossing (§7) and for
continuity with the arithmetic above. A square lattice with integer `x, y` authoring
would be an equally valid choice and is not worth the churn now.

## 4. Routes: the authoring surface

Routes live in **`data/routes.json`**, beside `data/input_map.json`, loaded by a `Routes`
autoload that polls the file's mtime the way `Tuning` does and emits `reloaded`. Saving
the file relays out the map under the player. This matters more than it looks: the
feel-parameter law exists because a slider dragged while watching is a different
instrument from a number typed in another window, and retiring the weave sliders costs
that loop unless the route data reloads live.

### 4.1 Shape

Sketch, and the schema is step B's to pin down with the gate. What is load-bearing is
that **a route is vertices, a vertex is a cell and a level, and a junction is an
annotation on the edge leaving a vertex**.

```json
{
  "anchors": {
    "SYSTEM A": { "cell": [0, 0] },
    "SYSTEM B": { "cell": [17, 3] },
    "SYSTEM C": { "cell": [49, 3] },
    "SYSTEM D": { "cell": [8, 18] },
    "SYSTEM E": { "cell": [24, -9] }
  },
  "routes": {
    "A-377B": {
      "profile": "pair", "level": 3,
      "vertices": [
        { "cell": [-4, 0] },
        { "at": "SYSTEM A" },
        { "cell": [6, 0] },
        { "cell": [14, 3], "junction": "diverge_right" },
        { "at": "SYSTEM B" },
        { "cell": [20, 3], "junction": "merge_below" },
        { "cell": [36, 3] },
        { "cell": [44, 6] },
        { "at": "SYSTEM C" },
        { "cell": [53, 3] }
      ]
    },
    "A-377B/off-B-forward": {
      "profile": "lane",
      "from": { "route": "A-377B", "vertex": 3, "carriageway": "forward" },
      "vertices": [ { "cell": [17, 1], "level": 2 }, { "cell": [18, 0], "level": 1 } ],
      "to": { "portal": "SYSTEM B" }
    }
  }
}
```

- `at` names an anchor; a vertex may be a bare cell or an anchor. Anchors carry the
  story content later (faction, name, market). None of that is on the road.
- `level` on a route is the default; a vertex may override it. An edge between two
  levels is a pitched straight.
- `junction` on a vertex means *the edge leaving this vertex is that tile*, for that
  carriageway. The edge must be exactly the tile's footprint (§6) and the gate says so.
  A junction for the reverse carriageway is the same tile placed backwards.
- A `lane` route's `from` is a junction's ramp socket; its first vertex is the cell after
  that socket. Its `to` is a portal (a mouth, as now: flare and ring) or another
  junction (an interchange). Nothing is measured to find where either end is.
- The map above was **illustrative and does not validate**: `merge_below`'s footprint
  is not the edge it annotates, the ramp's first hop pitches 11.3° against a limit of 7,
  and the vertex at `(44,6)` deflects 52°. **Step A authors the real cells**, against
  today's leg lengths and the 60° crossing, and the gate checks every bound in §5 on
  them. Legs stay unequal on purpose (ADR 0085); step D revises the cells only if
  flying says so.

### 4.2 Systems sit on the lattice

A system disc is 3.5 km across against a 600 m cell, so snapping a system to a cell
moves it by at most 300 m, which is invisible. Integer cell coordinates are stable under
re-authoring, which is what retires the "place nothing by coordinate" discipline the
free-chain alternative would have needed. Route to a system's cell, or drop a system on
a cell a route already passes through: both are exact.

## 5. The vertex rule, exactly

This is the only computed joint on the road, so it is written out in full. Everything
in it has one input, the angle `θ` between the two edges at the vertex (in the plane
of the two edges, so a change of pitch is the same rule turned on its side).

Let `h` be the building's half-width across (`deck_separation/2 + lane_width/2` for a
pair; `lane_width/2` for a lane), and `e = h · tan(θ/2)`.

1. **Each edge's building is extended past an interior vertex by `e`.** The extension
   reaches exactly the mitre's outer corner, so the outside of the bend is closed. The
   two boxes overlap on the inside of the bend and that overlap is hidden by the collar.
   An edge's modules are stepped along the extended length, exactly as now, with no
   bleed: the segment is straight.
2. **A collar stands on the bisector at the vertex**, the existing rib module, with its
   length along the bisector `2e + structure_rib_thickness`, so both boxes' ends are
   inside it. A vertex with `θ = 0` is a plain rib. Where the human has asked for a
   station, the station module takes the collar's place, as now.
3. **The lane through the vertex is a circular fillet** of radius `road_fillet_radius`,
   tangent to both edges' lane lines. `RoadPath.fillet` is a pure function: vertices in,
   polyline out, and it leaves the first and last vertex where they were.
4. **The barrier at a vertex is the union of the two boxes.** This costs no code:
   there is one `RoadStructure` per edge, and `RoadNetwork.barrier` already picks the
   building the hull is deepest inside of, inside beating outside (ADR 0087). A hull in
   the overlap is inside both; a hull at the outer corner is inside the box whose
   extension reaches it.

**Bounds, and the gate checks every one on every vertex of every route:**

| Bound | Why |
|---|---|
| `road_fillet_radius ≥ cruise_speed / turn_rate` (radians) | ADR 0070: a fillet's turn rate is `1/R`, and the road may not out-turn the ship. At 250 m/s and 34 deg/s that is 421 m. **The bound is on each carriageway's own lane line, so each is filleted on its own line at that radius — fillet the spine and offset afterwards and the inner carriageway comes out at `R − deck_separation/2`, which is 301 m and demands 47.6 deg/s of a ship that turns at 34.** `RoadLimits` holds the tuned value up to this floor at the point of use, so a slider dragged under it cannot break the road silently |
| `road_fillet_radius ≥ deck_separation` | ADR 0077: the inner carriageway folds through itself below this |
| `R · tan(θ/2) ≤` half the shorter adjacent edge | the fillet's tangent points must not pass the edge's midpoint, or two fillets overlap |
| every point of the filleted lane is inside the union of the two boxes | the lane is what the hull is measured against; a lane outside its own building is the bug ADR 0087 fixed |
| pitch of every edge `≤ road_pitch_max_deg` | comfort, the human's number, migrated from `road_rise_deg` |
| `θ ≤ 30°` is a guideline, not a gate | a 60° turn is two 30° vertices with a straight between. The gate bounds the fillet, which bounds `θ` through the row above |

The fillet radius is a **feel value**: longer is gentler, and the human slides it while
flying a vertex. The gate keeps it from ever being too tight. That, and not a curved
building, is what answers *"direction changes will be hard to manoeuvre in a relatively
small highway"*.

## 6. Junction tiles

The one place geometry is authored rather than stepped. A junction is a mesh occupying
one edge, with a declared ramp socket at a cell.

### 6.1 The contract

A tile is an `.obj` pair (metal, glass, so the existing per-layer material split holds)
plus a sidecar `.json` next to it, both emitted by `tools/gen_road_junctions.py`:

| Field | Meaning |
|---|---|
| `footprint` | the edge's lattice vector, e.g. `[3, 0]`. The tile occupies exactly this edge |
| `profile` | `pair` |
| `sockets.ramp` | cell offset from the edge's start, level offset, heading (always along the edge: ADR 0070's tangential rule, authored rather than fitted) |
| `lane_runs` | one polyline per carriageway and one for the ramp, local frame, from socket to socket |
| `apertures` | per building (mainline, ramp): `[from, to, face]` along that building's own run, the ADR 0091 stretch and the ADR 0093 face, declared |
| `gate` | where the `RampGate` sheen sits and which way it faces |
| `section` | the `lane_width`, `lane_height`, `deck_separation`, `lattice_cell_metres` it was generated against, for the gate |

The mainline's building on a junction edge is a `RoadStructure` whose mesh is the tile
rather than modules, with `_pierced_*` filled from `apertures` instead of from
`pierce`. The barrier code does not change. The ramp deck's polyline is the tile's ramp
run followed by the lane route's filleted polyline.

### 6.2 The catalogue

| Tile | Footprint | Ramp socket (start-relative) | Notes |
|---|---|---|---|
| `diverge_right` | (3, 0) | cell (3, -1), level 0, heading along the edge | 1500 m along, 520 m to the right of the spine: 400 m off the carriageway, an S of ~30° at ~1.5 km radius. Leaves at lane height (ADR 0092: an exit is cut, not troughed) |
| `merge_below` | (5, 0) → **(6, 0) as built** | cell (1, -1), level -2 | arrives 240 m below and climbs through the roadway over 2.4 km at 5.7°. Trough rising into a slot (ADR 0091) |
| `diverge_above` | (3, 0) | cell (3, 0), level +2 | the over-the-top left turn onto a road above (ADR 0080). **Not built until the interchange needs it**; listed so it is a catalogue addition and not an architecture change |

Footprints and socket cells are starting values. The generator solves the ramp's curve
between the carriageway and the socket, and the gate checks the result against the same
bounds as §5 by walking the tile's declared runs. If a footprint has to grow to pass,
it grows; the tile is the unit that absorbs it. **`merge_below` grew to (6, 0)** on the
first run, for the reason §12.4 expected.

**A ramp's lateral move is a two-arc S; its climb is a constant slope with a rounded
end.** They are solved separately and that is not a detail. An S of 240 m over 2.7 km
peaks at 11° — the S puts its steepest point in the middle, at twice the average — and
buying that back by lengthening the tile costs nearly two more kilometres of junction.
A constant 5.7° with a 3 km vertical fillet at each end is both shorter and gentler, and
its curvature is bounded by the same check.

**The exit's divergence point is derived from the radius, not picked.** A ramp that
peels away at the tile's seam is flush with the mainline's wall for its whole length,
and that is the highway losing a side (ADR 0093). Solving for a 900 m turn instead puts
the divergence 369 m in and opens 620 m of wall — near the 500 m that ADR was tuned to,
without a number to maintain.

**A socket offset is written for an east-pointing edge and rotated with the edge.** A
tile's sidecar gives its socket as a cell offset from the edge's start, in the frame
where the edge runs along `e₁`. Placing the tile on a `(n, 0)`-family edge that runs at
60° or 120° rotates that offset by the same multiple of 60°, which is an exact lattice
rotation: axial `(q, r)` rotated by +60° is `(-r, q + r)`. Levels do not rotate. The
world position of the socket is therefore always a cell, and the gate asserts it.

**Backward placement is part of the contract.** A pair-profile tile is symmetric under a
half-turn about the vertical, because both carriageways exist whichever way the route
is read. A `diverge_right` for the reverse carriageway is the same mesh placed on the
same edge rotated 180°, and its sockets go with it. One mesh per junction type.

**Junctions sit on `(n, 0)`-family edges only, to start.** A socket must be a lattice
cell relative to its edge's direction, so each direction family needs its own generated
variant. Straights and mouths work in every direction for free; a junction does not.
Route through a system on an east-west (or 60°, or 120°) edge and take any angle before
or after. Relaxing this later is more generator output, not a design change.

### 6.3 What a junction is not

- It is not measured. `crossing`, `overlap` and the face and stretch logic are deleted.
  The ADR 0091 to 0093 rules (an aperture is a stretch; a roadway opens for the whole
  merge; a wall opens a bounded length; an exit is cut and an entry troughs; no hoop on
  a junction) become properties of the mesh and its sidecar, and the gate reads the
  sidecar to assert them.
- It is not the mouth. A ramp's portal end stays what it is now: `LaneProfile`'s flare
  over `portal_flare_length` and `_end_ring`, both on a straight, both exact.

## 7. Sizing

Resolved against the map that exists. `s = 600 m`, `level = 120 m`.

| | |
|---|---|
| Road width vs cell | 480 in 600; a hex of step `s` is `s` flat to flat, and the corner-to-corner 693 covers a road crossing a cell obliquely |
| Mainline level | 3 (360 m). Was `road_height = 320` |
| Crossing level | 5 (600 m). Roof at 675 against a 900 m ceiling: 225 m of head room, over the 120 m warning band. Was 560 |
| Two levels | 240 m, the two roads' separation today |
| One level over a (2, 0) edge | 5.7°; over (3, 0), 3.8°. Both inside `road_pitch_max_deg = 7` |
| Crossing angle | **60°**. `crossing_bearing_deg = 55` is not a lattice angle; 60° is, and it is a better interchange angle anyway. This is a change to the map's shape, deliberately |
| Shortest leg today (6600 m) | eleven cells, or one (8, 3) and a (3, 0) |
| Ramp mouth | one cell from the system centre; `portal_site_offset = 600` retires into the route |

Leg lengths become **derived**: a leg is the sum of its edges. The four `*_leg_length`
keys retire.

## 8. What does not change

Everything downstream reads a `RoadPath` polyline plus a section, and none of it is
touched: `RoadDeck.sample` / `CruiseLane`, `RoadBerth` / `BerthHold`, `TubeRegion`,
`RoadNetwork.governing`, `Portal`, `RampGate`, `HullBarrier`, the bottom strip.

**The shell barrier stays derived from the path and the section, never from the mesh.**
A tile can be dressed as far as anyone likes and it can never change where the player
may fly. Art and collision stay independent, so enhancing the highway never requires
re-testing the game.

**The module system stays** (ADR 0078): unit-box modules scaled by (width, height,
length), so `lane_width`, `lane_height` and `deck_separation` stay live sliders on every
straight edge. Only the junction tiles are authored against a section, and the gate
fails if the tiles on disk were generated against a different one than `tuning.cfg`
carries, which is the honest way to say "run `make assets`".

**Floating origin, LOD/collision, the target-experience rule**: untouched. Everything is
built in the map's frame with nodes at identity, as now.

**Rendering cost** stays where ADR 0078 put it: the module layers are per-network
`MultiMeshInstance3D`s as now, and each junction type is one more.

## 9. What is deleted, what is added

**From `RoadNetwork`:** `crossing`, `overlap`, `section_of`, `_facing`, `_opposite`,
`_open_for`, `_clear_of`, `_laid_on`, `_at`, `_mouth`, `_across_at`, `_link`,
`link_routes`, `_build_ramps`, `_build_interchange`. Replaced by `add_route(RouteSpec)`
and `add_ramp(RouteSpec)`.

**From `RoadStructure`:** `pierce`, `_openings_in`, `_fill`, `_inside_an_opening`, the
curvature bleed in `_module`, the `bay_open_*` layers. `rebuild` becomes a straight
step. `apertures()` stays, fed by data.

**From `RoadPath`:** `weave`, `ramp`, `sweep`. Added: `fillet`. `closest`, `point_at`,
`tangent_at`, `section`, `max_turn_deg_per_metre` stay; they are how the game reads the
road.

**From `SystemMap`:** `LEG_KEYS`, `ROUTE_SYSTEMS`, `ROUTE_LEGS`, `ROUTE_ANCHORS`,
`ROUTE_BEARING_KEYS`, `ROUTE_HEIGHT_KEYS`, and the leg-walking half of `relayout`.
Replaced by `LatticeLayout`, pure, from `Routes`.

**From the gate:** `_test_module_bleed`, and every assertion in
`_test_exploration_builds` that measures a crossing, an overlap, a bleed or a weave.
Roughly eighty of its 187 checks. Also the read of `crossing_road_length`, a key that
no longer exists in `tuning.cfg`.

**Tuning keys retired (24):** `road_curve_deg`, `road_curve_period`, `road_rise_deg`
(migrates to `road_pitch_max_deg`), `road_rise_period`, `structure_station_spacing` (a
station is placed by the route), `junction_wall_opening_metres`, `ramp_run_length`,
`interchange_run_length`, `ramp_exit_side_offset`, `ramp_exit_depth`,
`ramp_entry_side_offset`, `ramp_entry_depth`, `ramp_curve_tightness`,
`interchange_curve_tightness`, `interchange_side_offset`, `local_leg_length`,
`trunk_leg_length`, `cross_inbound_leg_length`, `cross_outbound_leg_length`,
`crossing_bearing_deg`, `crossing_road_height`, `road_height`, `aperture_bearing_deg`,
`portal_site_offset`. The definitive list is step D's diff.

**Keys that stay, because a straight still needs them:** `structure_module_length`,
`structure_rib_thickness`, `structure_station_length`, `portal_flare_length`,
`ramp_ring_diameter`, `ramp_ring_depth`, and the whole section and glass group.

**Tuning keys added (4),** under a `;;; The lattice` group, each with a comment, a range
and a `REQUIRED_TUNING_KEYS` entry: `lattice_cell_metres`, `lattice_level_metres`,
`road_fillet_radius`, `road_pitch_max_deg`.

**Keys that become generator inputs as well:** `lane_width`, `lane_height`,
`deck_separation`, `structure_rib_thickness`. Still live on straights; a junction tile
needs `make assets` after they move, and the gate says so.

## 10. Build order and implementation plan

> **Start here.** A fresh session begins step A on a branch `feat/lattice-a` from `main`.
> Read §3 (the basis), §5 (the vertex rule) and §6.1 (the tile contract) before writing
> anything; they are the three things the gate in step A asserts. Nothing in the old road
> is touched in A, so `make fly` is unaffected until D.

One PR per step, on a `feat/` branch, `make check` green before each is called done,
each leaving `make fly` playable. Steps B and C build the new road in a **second scene**
(`scenes/lattice.tscn`, `make lattice`) beside the existing one, so the old map keeps
working until the new one is complete and D swaps them. That is the price of "works
correctly above anything else": the human can fly both and say when the new one is
ready.

### A. The lattice, the fillet, the data, the tiles ✅

Pure code and tools. No visible change. **Built 2026-09-06**; `make check` is 1409 checks.

| New | What |
|---|---|
| `scripts/lib/hex_lattice.gd` | `to_world(cell, level)`, `from_world`, `is_lattice_vector(v)`, `bearing_of(cell)`, `length_of(cell)`, `neighbours`. No scene tree, no disk |
| `scripts/lib/road_path.gd` | `static fillet(vertices, radius, segment_metres) -> PackedVector3Array` |
| `scripts/lib/road_limits.gd` | the §5 bounds in one place, so the gate and the builder cannot disagree: the derived fillet floor and its clamp, the half-section per profile, the mitre extension, the turn rate a curvature demands |
| `scripts/lib/route_spec.gd` | the parsed shape of one route: profile, vertices (cell, level, anchor, junction), `from`, `to`; and `validate() -> PackedStringArray` of exact, actionable errors ("K-112 closes at (14,-3), started at (12,-3)") |
| `scripts/autoload/routes.gd` | loads `data/routes.json`, polls mtime, `reloaded` signal, `route(name)`, `anchors()`. Registered in `project.godot` |
| `scripts/lib/road_tile.gd` | the sidecar, parsed: footprint, sockets, lane runs, apertures, gate, section |
| `tools/gen_road_junctions.py` | emits `assets/models/road_junction_<name>_{metal,glass}.obj` and `road_junction_<name>.json` for `diverge_right` and `merge_below`, reading the section and the cell from `tuning.cfg` |
| `data/routes.json` | the current five-system map, transcribed onto the lattice (§4.1's sketch, corrected until it validates) |
| `tuning.cfg` | the four new keys, in their group, with comments |

Gate: lattice round-trips (cube rounding, so a point off a cell centre snaps to the
*nearest* cell) and the §3.2 table; `fillet` is tangent at both ends, has curvature
`1/R`, leaves the endpoints alone, and reduces its radius rather than folding when an
edge is too short; `RouteSpec.validate` rejects each of a list of bad routes with the
right message; every tile's footprint is a lattice vector, its ramp socket is a lattice
cell, its runs start and end at its sockets to a millimetre, its apertures lie inside
it, its exit opens a wall and its entry a floor (ADR 0080 as a property of the
catalogue), and its section matches `tuning.cfg`; **every §5 bound on every vertex of
`data/routes.json`**, because the data lands here and step B should not be where a map
that cannot be flown is discovered; the derived fillet floor and its clamp;
`REQUIRED_TUNING_KEYS` carries the new keys.

**ADR 0095** lands here (it is written; this step makes it true).

### B. The mainline from routes ✅

**Built 2026-09-06**; `make check` is 1489 checks. `make lattice` plays it.

`scenes/lattice.tscn` and `make lattice`: the same scene script as exploration with a
`LatticeLayout` instead of the leg-walking layout.

| Changed | What |
|---|---|
| `scripts/lib/lattice_layout.gd` (new, pure) | routes and anchors in, and out: disc positions, each disc's aperture bearings (the direction of the route's edge at the anchor), the spine polyline per pair route, the corridor polyline per leg |
| `SystemMap` | takes a layout object; the legacy layout is extracted unchanged into `legacy_layout.gd` so the exploration scene does not move. `relayout` runs on `Tuning.reloaded` **and** `Routes.reloaded` |
| `RoadNetwork.add_route(spec)` | one `RoadStructure` per edge, extended by `e` at interior vertices; one collar per vertex on the bisector; two `RoadDeck`s per route, each offset from the spine and then filleted **on its own line** (§5). `_laid_on`'s bisector offset survives as the offset step |
| `RoadStructure` | loses the bleed. `rebuild` is a straight step. `pierce` stays for one more step so the old scene still works |

Ramps: none on the lattice scene yet. The lattice scene is a highway with no way onto
it, so **a fresh run starts on the carriageway and the debug teleport walks the road's
own vertices** instead of its systems — the drop is derived from the route data, so
authoring a bend into `data/routes.json` adds a stop with no code change.

`tools/shots/vertex_shot.gd` renders a bend from the seat at any distance
(`VERTEX_SHOT_VERTEX`, `VERTEX_SHOT_APPROACH`). **The frame has to be taken from the
road**, and that is not a limitation of the harness: off the road there is nothing
playable — the corridor is on the combat plane and the highway rides 360 m above it,
carrying only its own tube (ADR 0091) — so a camera swung out to admire the mitre from
outside is 2 km past the boundary and the whole frame is the boundary's red.

The map's bends are 15.3°, not the 13.9° and 30° this asked for: an `(8, 3)` edge is
what the authored map wanted, and it is the closest thing on any lattice to the 15°
nobody can have.

Gate: every §5 bound on every vertex of every route in `data/routes.json` (step A);
the exploration suite unchanged; a new `_test_lattice_builds` asserting the node tree,
that consecutive edges' boxes both reach the mitre corner they share, that the collar
covers both box ends, that every deck's `max_turn_deg_per_metre × cruise_speed ≤ turn
rate` (the ADR 0070 check, now passing on a filleted lane rather than a weave), that
every metre of every lane is inside a building **and that the building which answers is
one the point is really inside**, that the two carriageways hold their separation
through a bend, and that a fresh run starts on the road.

**A `MultiMesh` cannot be read back headless** — the dummy renderer stores no instance
data, so `get_instance_transform` returns the identity for a row that was written
correctly. `RoadNetwork.collars()` returns the transforms as data, which is both
readable there and the more honest assertion: it tests the geometry rather than the
graphics server.

**One bug the lattice surfaced, fixed here.** `RoadPath.closest` clamps, so the offset
measured from a clamped end has no along-component left in it: a building thirty
kilometres behind the ship reported exactly the same two walls as the one the ship was
inside, and tied with it on `room()`. One long building per route hid that completely;
a dozen short edges in a line surfaced it at once, as the HUD naming the wrong shell. A
building now declines to answer past its own end face — measured as the **overshoot**,
because clamping makes "at the end" and "past the end" the same number, and a point
exactly on the end face is still that building's.

### C. Junctions and ramps

| Changed | What |
|---|---|
| `RoadStructure.follow_tile(tile, placement)` | a building whose mesh is one tile and whose `_pierced_*` come from the sidecar |
| `RoadNetwork.add_ramp(spec)` | the ramp deck: tile run, then filleted route, then the mouth; one `RoadStructure` per ramp edge, the ramp's own trough building inside the junction from the sidecar; the portal at the deck's end as now; the `RampGate` at the tile's declared gate; the exit sign (still behind `exit_signs_visible`) placed from the same point |
| `data/routes.json` | the planet ramps for all five systems and the four interchange ramps at B, on the lattice |
| Interchange | authored as `lane` routes from a `diverge_right` on one road to a `merge_below` on the other, dipping below the lower road where it has to. **No `diverge_above` yet**: the over-the-top left turn is the first thing this map does not have, exactly as today |

Gate: every ramp starts at its junction's socket cell and ends at its mouth or the next
junction's socket cell (closure, exact); every exit face declared by a tile is `RIGHT`
or `ABOVE`, never `BELOW`, and every entry is `BELOW` (ADR 0080, now a property of the
catalogue rather than a measurement); the ADR 0091 containment sample (a ship on a
merge is inside a building every frame); the drive-and-fuel and colour rules on every
portal, unchanged.

### D. The swap, and the deletion

`make fly` runs the lattice layout. `scenes/lattice.tscn`, `legacy_layout.gd`, the
measurement functions, `weave`, `ramp`, `sweep`, the bleed, the open-bay modules, the
twenty-seven keys and their `REQUIRED_TUNING_KEYS` entries, and the gate checks that
measured them all go in one PR, so the diff is the definitive list of what the old road
was. `STATUS.md` and `EXPLORATION_POC_IMPLEMENTATION.md` step 8 are updated to say the
road is data.

Gate: the exploration suite passes against the lattice map with its numbers updated;
`tuning.cfg` has no key the code does not read (the existing hygiene test); no file
under `scripts/` references a deleted symbol.

### E. Real art

Replace `road_*.obj` and `road_junction_*.obj` in place. No code change. Folds into the
traffic steps (POC 9 and 10) as the structure plan already said.

### Cost

| Step | Sessions |
|---|---|
| A | half to one |
| B | one |
| C | one |
| D | half |
| Total | three to three and a half, before art |

The gate is where the time goes, as the first plan said. What is cheaper than that plan:
no tile catalogue to author beyond two junctions, no heading families, no curved mesh
anywhere, and `RoadStructure`'s module stepping kept rather than rewritten.

## 11. Deliberately not decided here

- **The exact mesh of either junction.** Art, and the human's. The generator's version
  is a placeholder that satisfies the sidecar.
- **`diverge_above`.** Listed, not built. The over-the-top left turn waits for it.
- **Junctions off the `(n, 0)` family.** More generator output when a map needs one.
- **Whether `routes.json` wants a shorthand** ("east 6, then (8,3)"). Start with cells.
- **Ring roads.** Legal and free; nothing on the map needs one.
- **Hex versus square.** Hex, by default, for the reason in §3.3. Not worth reopening
  unless integer `x, y` authoring turns out to matter.

## 12. Where this is most likely to be wrong

1. **The vertex collar may read as a kink from the seat.** A hard 30° corner in a
   480 m wide building is a real mitre, and the concept art has none. If it is ugly, the
   fix is a generated elbow tile per angle (a mitred box, four angles and their
   mirrors), which is more generator output and no architecture change. It is not a
   curved tile.
2. **`road_fillet_radius` may want to be per vertex.** One radius for the whole map is
   the simplest thing; a sharp vertex and a shallow one may want different radii. Add a
   per-vertex override in the data if the human asks, keeping the global as the default.
3. **The lane's `closest` is a linear scan per deck per frame.** Filleted lanes carry
   more points than weaves did. `segment_metres` in `fillet` is an infrastructure
   constant and should stay coarse (a 30° fillet at 600 m needs about six points); if
   the frame time moves, `RoadPath` gets a bounding pass before the scan.
4. **`merge_below` at (5, 0) is long.** Three kilometres of junction is a lot of map at
   every through-system. The footprint is the tile's to shrink if the pitch allows.
5. **Junctions on one direction family may bite sooner than expected.** If every system
   wants to sit on an oblique edge, the generator gets its second family early.
6. **The 60° crossing changes the map's shape**, and the human has only flown 55°.
