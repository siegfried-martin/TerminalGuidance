# The Highway — how the road is built, authored and verified

*Written 2026-09-07 with ADR 0096, replacing `HIGHWAY_STRUCTURE_PLAN.md` and
`HIGHWAY_LATTICE_PLAN.md`. This is the document a session reads before touching the
road. The design intent is in `EXPLORATION_DESIGN.md`; the decision is ADR 0096; this
is the mechanism.*

## In one paragraph

A road is a centre-line of straight legs joined by circular arcs, with one or two
rectangular tubes swept along it. A highway is two carriageways side by side under one
roof with a glass median, traffic on the right; a ramp is one carriageway. The tube is
the only collision primitive: the ship is always in exactly one tube or in open space,
and a wall is passable only where the point straight through it is inside another
road's tube — which is exactly where the mesh leaves the wall out. Ramps are built by
one rule from where the data says they start and end. The mesh streams in around the
ship; the collision is analytic and holds everywhere. The road is verified by flying
it, in the gate, against its own rendered triangles.

## The files

| File | What it is |
|---|---|
| `data/routes.json` | The map: systems, highways as waypoints, which ramps exist. Hot-reloaded. |
| `scripts/autoload/routes.gd` | Loads it, polls it, emits `reloaded`. |
| `scripts/lib/road_path.gd` | The centre-line: straights and arcs, analytic `closest`, `frame`, `at`. |
| `scripts/lib/tube.gd` | One carriageway's volume: `contains`, `local`, `world`, `sample` (the `CruiseLane`). |
| `scripts/lib/road.gd` | One road: its path, its tubes, its ribs. |
| `scripts/lib/road_collider.gd` | The collision for one hull. `hold()` keeps it inside its tube or bounces it off the outside. |
| `scripts/lib/road_probe.gd` | A scripted pilot for the gate, flying through the same collider. |
| `scripts/world/road_network.gd` | Builds the roads and ramps from the data, validates, streams the mesh, owns portals and gates. |
| `scripts/world/road_mesh.gd` | The visible structure, in chunks, with the one clip rule. |
| `scripts/world/road_berth.gd` | The dock on the roadway (ADR 0082), on tubes. |
| `scripts/world/system_map.gd` | Places the systems and corridors, hands the ship its tube each frame. |
| `tools/tests/road_suite.gd` | The flying half of the gate. |
| `tools/tests/road_report.gd` | `make roads`: build the map headless and list every problem. |

## The section

`lane_width` × `lane_height` per carriageway, `deck_separation` between the two
carriageway centres, so a highway is `deck_separation + lane_width` across. The floor
is a slab of `structure_floor_thickness`; the walls, roof and median are glass; corner
beams of `structure_beam_size` and a collar every `structure_module_length` of
`structure_rib_thickness`, standing out by `structure_rib_protrusion`. All of it sits
*outside* the flyable box (ADR 0078's unit-section rule survives): the space the ship
flies is exactly `lane_width × lane_height`, less its own hull.

Markings — five lines on each carriageway's floor — are the lane paint. The ridden
carriageway's are brighter and a ramp's are darker.

Every quad is wound **clockwise from the side its normal faces**, which is Godot's
front face. The materials are double-sided, and Godot flips a back face's normal to
face the viewer, so a quad wound the other way is lit from the wrong side: the roadway
seen from above was being lit by the star underneath it. `RoadSuite` checks the
winding of a built chunk.

## The lights

Between systems it is dark on purpose (STATUS.md, the star), so the light out there
is carried. `RoadLamps` puts a lamp bar on every rib, above the glass roof of each
carriageway, as an instanced mesh in the chunk — the string of lights down the road —
and keeps a pool of real omni lights (at most `RoadLamps.MAX_LIGHTS`) that the map
re-places every frame onto the bars within `track_light_reach` of the ship, along the
tube it rides or the nearest one. The ship's `Headlight` is a spot on the nose with
two visible lamps, toggled with `L`. Everything you would nudge is under `;;; Lights`
in `tuning.cfg`, and the HUD's `lights` row says what is live.

## Authoring the map

`data/routes.json`, metres in the map's frame, Y up, the combat plane at y = 0:

```json
{
  "systems": { "SYSTEM A": [0, 0, 0], "SYSTEM B": [11500, 0, 0] },
  "highways": [
    { "name": "A-377B", "systems": ["SYSTEM A", "SYSTEM B", "SYSTEM C"],
      "points": [[-6000, 360, 0], [24000, 360, 0], [30000, 560, -2000]],
      "radii":  [0, 2500, 0],
      "mouth_height": 160, "mouth_along": 600 }
  ],
  "planet_ramps": [ { "highway": "A-377B", "system": "SYSTEM A" } ],
  "ramps": [
    { "name": "X1", "from": { "highway": "A-377B", "side": "R", "near": [4500, 360, 120] },
      "to": { "highway": "K-112", "side": "R", "at": "SYSTEM B", "offset": 5700 },
      "points": [[8000, 330, 1200], [11612, 320, 2435]], "radii": [1200, 1200] },
    { "name": "X3", "mirror_of": "X1", "about": "SYSTEM B" }
  ]
}
```

- A **highway** is waypoints with a corner radius each (0 at an open end). An open
  end is a mouth. `closed: true` makes a loop. The systems listed are what its
  corridors join and what its entry mouths are labelled toward.
- **`planet_ramps`** declares that a system on a highway gets ramps; by default an exit
  and an entry on both carriageways, shaped by the rule below. `mouth_height` and
  `mouth_along` on the highway move that highway's mouths, which is how K-112's ramps
  at B clear A-377B's.
- A **ramp** in `ramps` is an interchange: `from` and `to` name a highway, a side
  (`R` is the carriageway to the right of the path's direction, `L` the other), and
  where on it — `near` a point, or `at` a system plus an `offset` in travel metres.
  Either end may instead be `{"mouth": "SYSTEM X"}`. `points` are the waypoints
  BETWEEN the standard exit head and the standard merge tail, with a radius each.
- **`mirror_of` + `about`** turns a ramp half a turn about a system's centre, which
  maps a ramp between two forward carriageways onto one between the reverse ones.

Save the file and the map relays out under the ship. `make roads` builds it headless
and prints every problem: a bend tighter than `road_turn_share` of the ship's turn rate
allows, a highway pitched past `road_pitch_max_deg`, a ramp leg within 15 m of a tube
it is not meant to join, two highways touching, a corner whose arc does not fit its
legs. Fix the one it names and run it again; a map with problems still builds and
still flies, so the report is the loop and the gate is the stop.

## The ramp rule

Every ramp's two ends are built the same way, from the `exploration/ramp_*` keys:

- **Exit head**: from the carriageway's centre at `from`, level for `ramp_exit_lead`,
  then a bend of `ramp_exit_radius` onto a leg diverging right at `ramp_exit_angle_deg`
  for `ramp_exit_length`. The ramp's tube nests inside the carriageway for the lead
  (it is `RAMP_INSET` smaller) and leaves through the wall on the diverging leg.
- **Merge tail**: `ramp_merge_drop` below the carriageway's centre, climbing at
  `ramp_merge_pitch_deg` through the floor, then level inside it for
  `ramp_merge_lead`, ending at `to`. Bends of `ramp_merge_radius`.
- **Planet exits** add a swing (`ramp_swing_metres` further along, a little further
  right, part way down) and the mouth: `ramp_mouth_along_offset` short of the system's
  centre, `ramp_mouth_side_offset` to the right, `ramp_mouth_height` up. Entries are the
  same in reverse, past the centre. Mouths are beside a planet, never over it.

Exits go out through a wall or the roof, never the floor; entries come up through the
floor (ADR 0080). Where a ramp's tube overlaps its host's, the host's wall or floor is
open — and only there.

## Collision

`RoadCollider.hold(prev, next, velocity, basis, half)` once per frame, after the ship
has flown:

- **Inside a tube**: the hull's oriented extents shrink the section; each axis is
  clamped unless the point straight through that wall is inside a neighbour tube —
  and not a SEALED one: a ramp and its host's other carriageway (`Tube.sealed`) clip
  each other's structure but never open a surface between them, because the ramp's
  tail wall is the median. A
  clamped axis reflects the velocity component through it by
  `structure_bounce_restitution` and reports how square the hit was, which the ship
  charges to the throttle once per contact (never below
  `structure_bounce_throttle_floor`). If the held point is no longer inside the tube —
  through an open wall, or past an open end — the hull is in whichever tube contains
  it, or in open space.
- **Outside every tube**: the hull bounces off the exterior of any road it has run into,
  and enters through an open end if that is how it arrived.

The map reads `ship.road.tube` each frame: in a tube with a drive that can run, cruise
is on; crossed into another tube, that is the road now; out through a mouth, cruise
winds down. Nothing chooses a road; the geometry says where the hull is.

## Streaming

`RoadMesh.plan` cuts each road into chunks of `CHUNK_RINGS` rings. `RoadNetwork.stream`
builds the chunks within `road_detail_radius` of the ship on worker threads, nearest
first, and frees the ones beyond 1.5× that. A coarse unclipped version of the whole
road (`build_far`) is visible whenever none of that road's chunks is loaded. Building
a chunk is cheap on a straight and a second or so through a junction, because the
clip subdivides walls to `MIN_CLIP` metres where another tube passes through them.

## Verification

`make check` runs `RoadSuite`: the network builds with no problems; every tube
contains its own centre-line; a probe flies every carriageway mouth to mouth, every
ramp from host to destination, dives at every wall at every junction edge and bend,
and flies drunk on every tube — and a ray from each step's start to its end must never
cross a rendered triangle, the probe must never be stopped, and there must be structure
within 2.5 km on all four sides while inside a tube. The whole mesh is built for it
(about 1.5 million triangles, half a minute).

`make roads` is the fast loop while authoring. `make shot` with `ROAD_SHOT_SPOT=Exit`
(or `Merge`, `Bend 1`, `Mouth`, `Spawn`, `Planet`) renders a frame from the seat at
that spot, and `K` in the game drops the ship at the next spot. When the suite reports
a pass-through, `tools/tests/repro_drunk.tscn` flies that one tube in a minute and
names the road and triangle a step crossed (see its header).

## What is deliberately not here

- No physics bodies on the road. The collider is analytic because one rule serves the
  mesh and the collision; nothing forbids collision shapes if that property is kept
  (ADR 0096).
- No curved mesh art yet. The structure is generated from the section; real art
  replaces the generator's strips in place.
- No traffic. Steps 9 and 10 of `EXPLORATION_POC_IMPLEMENTATION.md`.
