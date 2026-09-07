# The lattice rebuild — findings, for review

*Written 2026-09-06 by the implementing agent, at the human's request, before step C
is finished. The human's words: "for us to see so many recurring issues makes me
nervous about the approach so I want to review before going further."*

**This document is written for a reviewer who did not build it.** It is meant to be
adversarial-friendly: the case against the approach is made as strongly as the case
for it, and the numbers are given so they can be checked rather than believed.

---

## 1. What exists

| Branch | PR | State |
|---|---|---|
| `feat/lattice-a` | #17 | open — the lattice, the fillet, route data, two junction tiles |
| `feat/lattice-b` | #18 | open, stacked on A — the mainline built from routes; `make lattice` |
| `feat/lattice-c` | none | not opened; step C is unfinished |

`make check` on `feat/lattice-c`: **1495 checks, 0 failed.** `make fly` (the old road)
is untouched and passes its whole suite unchanged; `make lattice` is the new one.

New code, in lines:

```
scripts/lib/hex_lattice.gd        153    scripts/lib/map_layout.gd          59
scripts/lib/route_spec.gd         344    scripts/autoload/routes.gd        338
scripts/lib/road_tile.gd          245    scripts/world/legacy_layout.gd    107
scripts/lib/road_limits.gd         88    tools/gen_road_junctions.py       634
scripts/lib/road_rehearsal.gd      76    data/routes.json                  180
scripts/lib/lattice_layout.gd     107
```

Plus edits to `road_network.gd`, `road_structure.gd`, `system_map.gd`,
`road_path.gd`, `road_deck.gd`, `road_berth.gd` and the gate.

## 2. Every fault found, and by whom

The column that matters is **who found it**. A fault the gate found is the process
working; a fault the human found in the first seconds of a drive is the process
failing.

| # | Fault | Found by | Cause |
|---|---|---|---|
| 1 | Fillet-then-offset leaves the inner carriageway at `R − sep/2`, demanding 47.6 deg/s of a 34 deg/s ship | me, reviewing the plan | plan error (§10.B contradicted §5.3) |
| 2 | A building answers the barrier for points past its own end; the HUD named a shell 35 km behind the ship | gate, once there were 12 buildings | latent in the old road; `RoadPath.closest` clamps |
| 3 | Splicing a lane's arc onto the tile's curve: 496 deg/s | gate | my design error; fixed by a declared straight at the socket |
| 4 | No way to engage the drive on the lattice road | **human, seconds** | incomplete, and known — but I shipped it to be tested anyway |
| 5 | Collar rhythm per building: 450/400/427/458 m on consecutive edges | **human, seconds** | regression I introduced; one road became twelve buildings |
| 6 | `tangent_at` is piecewise constant → discrete heading steps, worst in a berth | **human, seconds** | latent in the old road; the lattice's filleted lanes exposed it |
| 7 | Stations break the collar beat (400,400,400,335,465) | **human**, still open | pre-existing (ADR 0078); not a lattice fault |
| 8 | A tile lost its entire wall/roadway: one aperture removed one segment, and a run was two points | **human, seconds** | my generator error; silently undid ADR 0093 |
| 9 | Exit distance measured to the ramp's centre-line start, not the opening: 257 m vs 1.6 km | **human, seconds** | inherited old-road behaviour, wrong once a ramp starts inside a tile |
| 10 | The road consuming 100% of the ship's turn authority → nose, velocity, camera and control all disagree | **human, seconds**; then the gate, once instrumented | **the plan's central bound was too weak** |

Six of ten were found by the human within seconds of starting to fly. That is the
number this review exists to explain.

## 3. Why the gate missed them — one cause

**The gate had no model of the ship following the road.**

It checked two things thoroughly and one thing not at all:

- **The data** — every bound in the plan's §5, on every vertex, plus each tile's
  sidecar against its own contract. This worked. No fault above is a data fault.
- **The collision shell** — the barrier, derived from the path and the section. This
  worked, and found #2 itself.
- **What the player is handed, frame by frame** — nothing. Faults 5, 6, 8, 9 and 10
  all live here.

Two structural blind spots follow from that:

**(a) The mesh was never checked against its own sidecar, and by design nothing else
could catch it.** The plan's `§8` promise is that the shell comes from the path and
the section and *never* from the mesh, so art and collision stay independent. That is
a good rule and it is why a tile could lose an entire wall while every collision check
passed. The decoupling is right; it means the mesh needs a check of its own, and that
check does not exist yet. **This is the largest remaining hole.**

**(b) The curvature bound was the wrong bound.** The plan (§5, ADR 0070) says the road
may not out-turn the ship:

```
max_turn_deg_per_metre × cruise_speed ≤ cruise_turn_rate_deg_per_sec
```

That is "the road never demands more than the ship's **whole** turn rate". But the
ship's nose is not glued to the road: `_road_axis` slews after the lane's axis at that
*same* rate. So at the bound, the slew exactly keeps up and never gets ahead — the
nose lags the road through the entire bend, the velocity points somewhere else again,
and the camera, hung off the nose, swings with no input. The check passes and the road
is unflyable.

`scripts/lib/road_rehearsal.gd` is the instrument that was missing: it walks a path at
cruise speed, slews a heading after it at the ship's own rate, and reports the worst
**lag** and the **share** of turn rate taken. Added to the gate, it named the off-ramp
at **81%** on its first run. `road_turn_share` (0.5) is the bound that should have been
in the plan; it moves the fillet floor from 421 m to 842.

## 4. Is the lattice the problem? The case both ways

### The case that it is not

- **Every geometric claim the plan makes has held and is asserted.** Straight boxes
  meet exactly; closure is exact to the millimetre; the mitre reaches its corner;
  the collar covers both ends; the rhythm is uniform (measured: 102 of 106 gaps on the
  trunk are exactly 400.0 m, the four exceptions being its two real bends). None of
  the ten faults is a failure of the lattice's own arithmetic.
- **Four of the ten are not lattice faults at all.** #2 and #6 were latent in the old
  road; #7 is ADR 0078 behaviour predating this work; #9 is inherited old-road
  behaviour that only became wrong in a new context.
- **The lattice *revealed* two of them.** One long building per route hid #2
  completely; twelve short ones surfaced it in one frame. That is the design doing
  what it is for — making the wrong thing visible.
- The old road's own history says the same: ADRs 0087–0094 are seven consecutive
  sessions of highway bugs on the curve-and-measure approach, which is why ADR 0095
  exists.

### The case that it is, or that the plan was

- **The rebuild multiplied seams.** One building became twelve per route; one deck
  became many; geometry moved into data *and* generated tiles *and* a splice between
  them. **Every fault I introduced (#3, #5, #8) is at a seam** — building-to-building,
  tile-to-lane, mesh-to-sidecar. The lattice's exactness is real but it is exactness
  *within* pieces; the joins are where the work now is.
- **The plan specified the gate for the data and not for the artefacts.** §10's gate
  lists are thorough about routes and sidecars and silent about the mesh and about
  flying. Faults 8 and 10 are directly attributable to that.
- **Ramps are where the lattice is least comfortable.** A 600 m cell is coarse for a
  ramp: a 60° turn needs 1040 m edges at the mainline's fillet, which forced a
  per-route fillet override (anticipated by §12.2), and then forced the generator to
  grow a tile's *socket* as well as its footprint. `diverge_right` has grown 3→4 cells
  and `merge_below` 5→7 in the course of getting one ramp to pass. **The junction
  catalogue is absorbing more than the plan expected**, and there are nine more planet
  ramps and an interchange still to author.
- **Junction cost is unresolved and is a map-scale question.** A junction has one
  socket, so SYSTEM B's planet ramp and its interchange ramp need separate junction
  edges: about 6 km of junction per road at B, against a 21.5 km B→C leg. All four
  carriageways at every system would be ~12 km of junction around each — more than the
  entire A→B leg. Nobody has decided whether that is acceptable.

### My own reading, stated plainly

The **defect rate is not evidence against the lattice's geometry**; it is evidence
against the gate that was specified for it, and against how much I built between
tests. I wrote steps A, B and C's machinery with the human testing only between
whole steps. The faults found in seconds cluster exactly where I had no instrument,
and every one of them would have been caught by a "fly the road and assert what the
player gets" test — which I built only after being told twice.

The thing I would genuinely reconsider is **not the lattice but the junction tiles**.
The straight-edges-and-vertices half is exact, cheap and verified. The authored-tile
half has produced three of the four faults I introduced, has grown twice under its own
constraints, and still has its largest verification hole open. A reviewer should push
hardest there.

## 5. What a reviewer should check

1. **Is `road_turn_share` the right shape of fix?** It bounds the road so the nose has
   authority spare. The alternative nobody has costed is making a ramp *slower* than
   the mainline (a real off-ramp has an advisory speed), which would let ramps stay
   tight. `lane.base_speed` is currently `cruise_speed` everywhere.
2. **Verify the rehearsal is measuring the right thing.** `road_rehearsal.gd` is 76
   lines. If its model of the nose is wrong, the new bound is wrong.
3. **The mesh-vs-sidecar hole.** Is asserting emitted geometry against the sidecar the
   right answer, or should the tile mesh be derived from the sidecar at load time so
   they cannot disagree?
4. **Junction cost.** Is 6 km of junction at an interchange acceptable on a 21.5 km
   leg? If not, the tile catalogue's footprints are the thing to attack.
5. **Is the tile needed at all?** The straights are exact without it. A junction could
   in principle be more straight edges plus declared apertures, with no authored mesh
   and no splice. That would delete the generator, the sidecar, the splice and the
   socket-straight — and with them faults 3, 8 and the open verification hole. It
   would cost the ability to author a junction's shape as art. **This is the question
   I would most want a second opinion on.**
6. **Was ADR 0095 right?** It supersedes ADR 0070, 0085 and 0094. If the answer to (5)
   is "drop the tiles", ADR 0095 still stands and only §6 changes.

## 6. What is unfinished

- Step C: nine planet ramps and the interchange are unauthored. Only SYSTEM A's
  off-ramp exists.
- The reverse carriageway has no ramps on the lattice at all.
- No mesh-vs-sidecar check.
- **Nothing in steps B or C has been signed off from the seat.** The station beat
  (#7) is diagnosed, deliberately unfixed, and is a feel call.
- `make fly` still runs the old road. Step D (the swap and the deletion) has not
  started, so nothing is irreversible: abandoning the lattice today costs the three
  branches and nothing else.

## 7. The one thing worth keeping regardless

`RoadRehearsal`, and the rule behind it: **a road is not verified by bounding its
geometry, it is verified by flying it and asserting what the player gets.** That is
true of the old road too, and it would have caught faults on it.
