# Highway Tiles — Plan of Record

*Written 2026-09-06, after five play sessions in which the highway consumed the large
majority of the project's time and kept producing the same shape of bug. Supersedes the
construction half of `HIGHWAY_STRUCTURE_PLAN.md`; the section, the glass, the docking
and the exit rules from that plan all stand.*

**This document is the reasoning as much as the plan.** It is written to be argued with.
Section 12 lists what is deliberately *not* decided yet, and section 13 lists the things
most likely to be wrong.

---

## 1. The problem, stated precisely

The current road derives **geometry from a path**. `RoadNetwork` lays a continuous
`RoadPath` (a weaving polyline) and `RoadStructure` steps rigid box modules along it.
Everything about the built structure is therefore *computed*: where an opening goes, how
long it is, which face it cuts, where a ramp's shell starts and stops.

Two consequences, and between them they account for nearly every highway bug in
ADRs 0087–0094:

**(a) A rigid box cannot follow a curve.** A module is a straight box placed at the
middle of its stretch with the tangent *there*, so on a bend its ends fall short of the
path by the sagitta — `length × turn / 8` at each end. At the tuned 400 m module on a
~3 km radius that is ~7 m a side, ~13 m of misalignment at every joint, the length of
the road. ADR 0094 hides it with a bleed and states the limit honestly: **one affine
transform has parallel end faces, and two consecutive joints on a curve are not
parallel, so no placement of a rigid box makes both ends meet exactly.** The error falls
as `length²`; it never reaches zero.

**(b) Junctions are measured, not authored.** `crossing`, `overlap`, `_facing`,
`_opposite`, `_clear_of`, span-piercing, per-face trimming — every one of those is a
measurement standing in for a decision an artist should have made. Each has been wrong
at least once: the aperture that was a point when it needed to be a stretch (0091), the
face asked of the spine instead of the carriageway (0093), the trough that was right for
an entry and wrong for an exit (0092), the wall opened for a kilometre (0093).

Neither is a bug to fix. Both are properties of the approach.

## 2. The decision

**Invert the dependency. Tiles are placed; the path is what they produce.**

A tile is an authored mesh with sockets. Roads are chains of tiles. `RoadPath` becomes an
*output* of the chain rather than the input to construction. Then:

- Geometry is watertight by construction, because tiles are authored to butt.
- A junction is a tile with a hole already in it. Nothing is measured.
- The tile is the unit of art, which is what makes "dress up the highway" possible at
  all. It is the ADR 0030 promise finally true for the road.

**And the tiles snap to a hexagonal lattice.** That is what makes loops close exactly and
what lets the world be authored road-first *or* system-first, interchangeably.

## 3. Why a lattice, and why hexagonal

Without a lattice, a chain of tiles lands wherever it lands. Every **independent loop** in
the road graph then needs a closure constraint — `edges − nodes + 1` of them — absorbed
by a fitted tile, a solver, or a nudged anchor. That is manageable but it is machinery,
it needs a residual threshold to tune, and it fails in a way the designer has to hunt.

With a lattice, every loop closes because every tile's displacement is an exact lattice
vector. All of that machinery is deleted rather than managed.

**Hexagonal rather than square**, for one reason: on a triangular lattice all six
neighbours are equidistant, so every step is the same length and integer combinations
compose exactly. A square grid's diagonal is `√2` — irrational — so 45° roads never tile
with the orthogonals without a hack.

### 3.1 Which bearings exist

Lattice directions are the vectors `a·e₁ + b·e₂` where `e₁ = (1,0)` and
`e₂ = (½, √3⁄2)`, at bearing `atan(b√3 / (2a+b))` and length `s·√(a²+ab+b²)`.

| Footprint (a,b) | Bearing | Length (cells) |
|---|---|---|
| (1,0) | 0° | 1.000 |
| (4,1) | 10.9° | 4.583 |
| (3,1) | 13.9° | 3.606 |
| (2,1) | 19.1° | 2.646 |
| (3,2) | 23.4° | 4.359 |
| (1,1) | 30° | 1.732 |
| (2,3) | 36.6° | 4.359 |
| (1,2) | 40.9° | 2.646 |
| (1,3) | 46.1° | 3.606 |
| (0,1) | 60° | 1.000 |

**15° is not on the lattice at any tile size.** Solving `tan 15° = b√3/(2a+b)` gives
`a/b = √3 + 1`, irrational. This is a property of the lattice's directions, not of its
resolution, so subdividing cells does not produce it. 13.9° is the nearest available and
is assumed to be close enough for any design purpose; if it is not, that is a reason to
revisit the lattice, not to fudge a tile.

### 3.2 The two quantisations are independent

This is the load-bearing insight and it is easy to conflate the two halves:

- **Position** must land on the lattice. This is what makes loops close.
- **Heading at a socket** must come from the catalogue's angle set. This is what makes
  adjacent tiles match.

A tile's footprint and its interior are *separate choices*. A `(3,1)` footprint can be a
straight run at 13.9°, or an S that enters and leaves at 0° while stepping sideways, or a
gentle bend from 0° to 30°, or any of those while changing level. Same footprint, same
closure guarantee, different mesh.

The rule that falls out, and it governs the catalogue:

> **Be generous with footprints. Be stingy with headings.**

A new footprint at an existing heading is one mesh and no new transitions. A new heading
needs turn tiles into and out of it, and those multiply against every heading already in
the set.

## 4. The socket contract

A tile is:

| | |
|---|---|
| **mesh** | one authored `.obj`, in the tile's own local frame |
| **entry socket** | at the origin, facing `−Z`, with a declared **profile** |
| **exit socket** | a `Transform3D` relative to entry, with a declared profile |
| **extra sockets** | zero or more, for junctions — each a transform and a profile |
| **lane runs** | one polyline per carriageway through the tile, in local space |
| **footprint** | the lattice cells the tile occupies, for overlap checking |

Two tiles connect when the exit socket of one matches the entry socket of the other in
**position, heading and profile**. Profiles are named cross-sections — `pair` (both
carriageways), `lane` (one), `mouth` (a portal's narrow section). A profile mismatch is a
build error, not a silent taper.

The tile's *displacement* — the translation part of the exit socket — must be an exact
lattice vector. The gate asserts it, per tile, at build time.

**Godot convention, unchanged from `gen_road_modules.py`:** `−Z` forward, `+Y` up,
`+X` starboard.

## 5. The catalogue

Twelve headings to start: 0° and 30° and their rotations. One 30° turn plus its mirror.

| Family | Tiles | Footprint | Notes |
|---|---|---|---|
| Straight | plain, **station** | (1,0) | station is the same sockets, different mesh |
| Turn | left, right | (1,1) | 30° of heading change |
| Shift | S-left, S-right | (2,1) / (3,1) | enters and leaves at the same heading, steps sideways. **This is how the weave is expressed** |
| Grade | climb-in, climb-hold, climb-out, and mirrors | (2,1) | one level per climb tile |
| Junction | merge-from-below, diverge-left, diverge-right | (3,1) | carries the hole *and* the ramp's first stretch, ending at a `lane` socket |
| Mouth | portal | (1,0) at `mouth` profile | carries the `Portal` and its hoop |

Ramps are chains from the same catalogue at the `lane` profile, ending in a mouth tile.

**One axis per tile.** Never "curve left while climbing". The road alternates instead.
The expressiveness cost is small; the catalogue saving is not — every combination is a
mesh maintained forever.

### 5.1 Reserved, not built

The `√7` family — 19.1° and 40.9°, footprints (2,1) and (1,2) — raises the set to 30
headings. **Adding it later is a catalogue addition, not an architecture change**: same
lattice, same closure, three more turn tiles. The arithmetic is recorded in §3.1 so a
future session does not re-derive it. Do not build it until twelve headings have been
found limiting in a real layout.

## 6. Sizing

Four constraints pull against each other. Resolved here against the map that exists.

**The cell must be at least the road's width.** The mainline building is
`deck_separation + lane_width = 480 m` across. A hexagon of step `s` is `s` flat to flat.
Below `s = 480` a road claims more than one cell and neighbouring roads overlap, which
needs corridor occupancy — machinery worth avoiding.

**A leg wants ten or more tiles**, or there is no shape in it. The shortest leg on the
map is `cross_outbound_leg_length = 6600 m`.

**A turn may not out-turn the ship** (ADR 0070). At `cruise_speed = 250` and
`cruise_turn_rate_deg_per_sec = 34`, the road may bend at most `34/250 = 0.136 deg/m`, so
a 30° turn needs **at least 220 m of arc**.

**Grade:** the two roads are `crossing_road_height − road_height = 240 m` apart, and
`road_rise_deg = 7` is the steepest pitch the current road uses.

### Proposed: `s = 600 m`, level step `= 120 m`

| | |
|---|---|
| Straight tile | 600 m |
| 30° turn (1,1) | 1039 m of footprint — ~4.7× the 220 m minimum arc. Comfortable |
| S-shift (3,1) | 2163 m |
| Climb tile (2,1) | 1587 m for 120 m of rise → **4.3°**, inside the current 7° |
| Two levels | 240 m — exactly the gap between the two road heights |
| Shortest leg (6600) | 11 straight cells |
| Local leg (8000) | 13.3 |
| Cross inbound (9600) | 16 |
| Trunk (18000) | 30 |
| Road width vs cell | 480 in 600 — one cell per road, 120 m of margin |

Leg lengths become **derived** rather than tuned: a leg is however long its tile chain
is. `local_leg_length` and its three siblings retire.

The current weave — `road_curve_deg = 20` over `road_curve_period = 6000` — becomes
roughly one S-shift pair per 6 km, which at these sizes is one or two S-shifts per leg.
That is the same road, authored instead of sampled.

## 7. What does not change

This bounds the size of the job, and it is the strongest argument that the refactor is
contained.

**Everything downstream reads a `RoadPath` polyline.** A tile chain emits one per
carriageway. Unchanged, and not to be touched:

- `RoadDeck.sample` / `CruiseLane` — the lane, its push, its speed penalty
- `RoadBerth` / `BerthHold` — the rail
- `TubeRegion` — the road's own playable space (ADR 0091)
- `RoadNetwork.governing` — the lane union
- `Portal`, `RampGate` — placed by the mouth and junction tiles rather than computed
- `HullBarrier` — see below

**The shell barrier stays derived from the path and the section, never from the mesh.**
This is a deliberate invariant and it should be stated in the ADR: it means a tile can be
dressed up as far as anyone likes — girders, hangars, signage, greebles — and it can
never change where the player may fly. Art and collision stay independent, so enhancing
the highway never requires re-testing the game.

**Floating origin, LOD/collision, the target-experience rule** — untouched. Tiles are
placed in the map's frame with the node at identity, exactly as `RoadStructure` is now.

**Rendering cost stays where ADR 0078 put it.** One `MultiMeshInstance3D` per *tile
type*, instanced at every placement. A route is a handful of draw calls, as now.

## 8. What is deleted

From `RoadNetwork`: `crossing`, `overlap`, `section_of`, `_facing`, `_opposite`,
`_open_for`, `_clear_of`, `_laid_on`, `_at`, `_mouth`, `_side_of`, `_across_at`, and the
cubic ramp fitting in `_build_ramps` / `_build_interchange`.

From `RoadStructure`: `pierce`, `_openings_in`, `_fill`, `_inside_an_opening`, `_module`,
`_span`, `_end_ring`, `apertures`, and the whole module-stepping `rebuild`.

From `RoadPath`: `weave`, `ramp`, `sweep` — the fitted-curve constructors. `closest`,
`point_at`, `tangent_at`, `section` and `max_turn_deg_per_metre` all stay; they are how
the rest of the game reads the road.

From `tuning.cfg`: `road_curve_deg`, `road_curve_period`, `road_rise_deg`,
`road_rise_period`, `structure_module_length`, `structure_rib_thickness`,
`structure_station_spacing`, `structure_station_length`, `junction_wall_opening_metres`,
`ramp_run_length`, `interchange_run_length`, `ramp_exit_side_offset`, `ramp_exit_depth`,
`ramp_entry_side_offset`, `ramp_entry_depth`, `ramp_curve_tightness`,
`interchange_curve_tightness`, `interchange_side_offset`, `portal_flare_length`, and the
four `*_leg_length` values. **Twenty-three keys**, every one of them a number that only
existed to steer a computation.

## 9. Where the road is authored

Routes move to **`data/routes.json`**, alongside `data/input_map.json`, and hot-reload on
save the way `tuning.cfg` does.

This matters more than it looks. The feel-parameter law exists because *"a slider you can
drag while watching the missile is a different instrument from a number you type in
another window"*. Retiring the four weave sliders costs exactly that loop unless the
route data reloads live. With reload, the loop is preserved in a better form: edit the
chain, save, watch the road change under you.

Sketch, not final:

```json
{
  "A-377B": {
    "anchor": { "system": "SYSTEM A", "heading": 0, "level": 2 },
    "legs": [
      { "to": "SYSTEM B",
        "tiles": ["straight", "s_left", "straight x3", "s_right",
                  "straight x2", "junction_diverge_right", "straight x3"] }
    ]
  }
}
```

## 10. Anchors, systems and closure

An **anchor** is a named lattice cell with a heading and a level. Systems, interchanges
and stations are anchors. Story content — faction, name, market, what the place *is* —
lives on the anchor, never on the road.

Because positions are lattice cells, the road-first / system-first fork disappears: route
to a system's cell, or drop a system on a cell the road already passes. Both are exact.

**Closure is free.** A ring road through twelve systems needs no fitted tile, no residual
threshold and no solver, because every tile's displacement is a lattice vector and the
sum of lattice vectors is a lattice vector. The gate asserts that a route declared as a
loop returns to its origin cell, and the failure — *"route K-112 closes at cell (14,−3),
started at (12,−3)"* — is exact and actionable.

**Systems must sit on the lattice.** A system disc is 3.5 km across against a 600 m cell,
so "on the lattice" costs at most 300 m of position, which is invisible. This replaces
the "name everything, never place by coordinate" discipline the free-chain design would
have needed: integer cell coordinates are stable under re-authoring.

## 11. Build order

One PR per step, each with its ADR, each leaving the game playable.

**A — the lattice and the contract.** `HexLattice` (pure: axial coordinates, the ten
footprints, cell↔world), `RoadTile` (the socket contract), and a `tools/gen_road_tiles.py`
that emits placeholder meshes to it. No road built yet. Gate: every catalogue tile's
displacement is an exact lattice vector; every mesh fits its declared profile; entry and
exit sockets are where the tile says.

**B — the mainline from tiles.** `RoadNetwork` builds a route by chaining tiles from
`data/routes.json`. `RoadDeck` takes its polyline from the chain. `RoadStructure` becomes
tile placement. Ramps stay on the old cubic fitting for this step so the map still works.
Gate: the existing road suite passes unchanged except for numbers; no seam anywhere,
checked by asserting that consecutive tiles' sockets coincide to within a millimetre.

**C — junction tiles.** The three junction types. Delete the measurement machinery. Ramps
become tile chains ending in a mouth tile. Gate: the exit-face rules and the containment
check from ADRs 0087–0093 all still hold, now as properties of authored tiles rather than
of measurements.

**D — retire the computed road.** Delete `weave`, `ramp`, `sweep`, the twenty-four tuning
keys, and the leg lengths. Author the five-system map as data. Gate: loop closure, anchor
alignment, and `max_turn_deg_per_metre × cruise_speed ≤ cruise_turn_rate_deg_per_sec`
across every tile in the catalogue.

**E — real art.** Replace placeholder `.obj`s in place. No code change, which is the
whole point.

## 12. Deliberately not decided here

- **The exact mesh of any tile.** That is art, and it is the human's.
- **Whether the `√7` family is needed.** Reserved (§5.1), not built.
- **Ring roads.** Legal and free under this design; nothing on the map needs one yet.
- **Whether a leg's tile list is hand-written or generated from a shorthand.** Start
  hand-written; a shorthand can be added without touching the runtime.
- **Junction tiles for the interchange between two *routes*.** Step C builds the three
  planet-ramp junctions; a route-to-route interchange is a fourth type and may want its
  own step.

## 13. Where this is most likely to be wrong

Listed so a reviewer can attack the weak points rather than hunt for them.

1. **`s = 600 m` may be too coarse.** A 6600 m leg is 11 straights, and an S-shift eats
   3.6 of them. If legs need more shape than that, either the cell shrinks (and roads
   start claiming corridors of cells, which is real machinery) or legs get longer. The
   sizing in §6 is the number most likely to move.
2. **Twelve headings may read as a hex map from far out.** Mitigated by cells being
   kilometre-scale and by S-shifts doing the fine work, but it is a judgement that can
   only be made from a frame.
3. **One axis per tile may be too austere.** If a climb through a turn is needed often
   enough, the catalogue grows combinatorially. Watch for it; do not pre-empt it.
4. **Grade as an integer level assumes roads only ever want to be at level heights.** A
   road that wants to sit 60 m above another cannot. Levels can be subdivided, at the
   cost of more grade tiles.
5. **The junction tile owning the ramp's first stretch fixes the divergence geometry.**
   Today `ramp_exit_side_offset` and friends are sliders. After, the shape of a divergence
   is baked into a mesh. That is the intent, but it means changing how a ramp leaves is an
   art change rather than a slider.
6. **`data/routes.json` is a new authoring surface with no editor.** Editing a chain by
   hand and looking at the result is the loop. It may want a tool sooner than expected.
7. **Two routes crossing at a non-lattice angle is impossible.** `crossing_bearing_deg`
   is currently 55°; the nearest lattice bearings are 30° and 60°. The crossing angle
   becomes an authored choice from the set, not a slider. 60° is the obvious replacement
   and is a better interchange angle anyway, but it is a change to the map's shape.

## 14. Cost, plainly

Two working sessions at least, probably three with the art pass. The gate needs real
rewriting — a substantial part of `_test_the_road` and `_test_exploration_builds` asserts
properties of measured geometry that will no longer exist, and the replacements assert socket matching
and lattice alignment instead.

Against that: nearly every bug of the last five sessions was one of the two problems in
§1, and neither is fixable within the current approach.
