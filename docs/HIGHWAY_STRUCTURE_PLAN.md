# Highway Structure — Rebuild Plan

*Written 2026-08-31, from concept art the human generated after the translucent road
failed to land. Plan of record for steps A–E. Supersedes parts of
`EXPLORATION_DESIGN.md`'s locked decisions; those changes are listed below and each
one lands with its ADR.*

**Reference image:** `docs/reference/highway_concept.jpeg` — an industrial structure in
space: a segmented spine of metal ribs, glazed bays between them, a solid roadway
floor, traffic running along it, ships flying free outside. Committed rather than left
in `temp/` because a plan that references a gitignored file rots.

---

## Why the road is being rebuilt

Four sessions of tuning the translucent road did not make it read as a place. The
human flew it, tuned it, and gave up; the concept art was generated to find out what
was missing. The answer is not colour, opacity, or line count.

**The structure is modular, and the current one is extruded.** `RoadDeck` sweeps a
single continuous `ArrayMesh` along a `RoadPath`. That is why it reads as an abstract
volume rather than a built thing, and it is why no generated or authored asset can
ever drop into it.

If the structure is instead **modules placed along the path** — one rib, one glass
bay, one floor plate, repeated — then three things follow at once:

- swapping placeholder geometry for real art is replacing one mesh, with no code
  change. That is the ADR 0030 promise, finally true for the road.
- the road bends *between* segments rather than within one, which is why the art reads
  as built rather than extruded.
- vertex count collapses. A mainline shell is currently tens of thousands of verts; a
  `MultiMeshInstance3D` is one mesh and a transform list.

That is the load-bearing change. Side-by-side lanes, glass, and steel rings are all
cheap once the structure is modules.

---

## Settled

Decided with the human on 2026-08-31. Do not re-litigate.

| | Decision |
|---|---|
| **Section** | Two directions **side by side**, right-hand traffic. Not stacked. |
| **Structure** | Metal ribs, glazed bays, solid floor, glass median. Built from modules. |
| **Glass** | Higher opacity than the current shell, deliberately — it is a diffuser. |
| **Docking** | The road is a **dock host**. Same verb as a planet, not a lookalike. |
| **Dock speed** | 75% of cruise. Automation is never the fast route. |
| **Dock exit** | `C` toggles. Input does **not** abort. |
| **Dock routing** | Mainline only, except when the player clicks an exit sign. |
| **Median** | Soft lane push keeps you off the glass. ADR 0064 unchanged. |
| **Interchange** | Build the exit-face mechanism **and** a second highway crossing at B. |
| **Ramp mouths** | A steel ring. Entry from below through the floor; exits never go down. |

### The exit-face rules

From the human, and they are **authored properties of a ramp**, never computed:

- Onto a highway going **right**: exit right.
- Onto a highway going **left**: exit **above** if that highway is above, or **right**
  if it is below.
- **Never exit downward.** Down is the floor road, and an exit competing with it for
  the meaning of "down" is clutter.
- **Entry comes from below**, up through a hole in the floor plate, because merging
  upward into the only lane there is is unambiguous. The floor road bridges the gap.

---

## What this retires

| Retired | Where it lives now |
|---|---|
| "The two decks are stacked vertically" | `EXPLORATION_DESIGN.md`, Structure |
| The upper/lower deck convention | `RoadDeck.rides_upper`, 6 gate assertions |
| **Enforced Invariant 1** — the NW–SE divider and the "physical twist" | `EXPLORATION_DESIGN.md` |
| ADR 0075's outer→divider colour gradient | superseded by materials |

**Right-hand traffic is self-orienting, so the convention is deleted rather than
replaced.** Two anti-parallel lanes side by side: from either driver's seat the other
lane is on their left, in any frame, at any bearing. No mnemonic, no bearing rule, no
twist, and long ring roads become legal — X4's signature ring road was illegal here
and now is not.

In code the whole of it is one expression, evaluated per point along the spine:

```gdscript
var side := travel.cross(Vector3.UP)   # travel already carries the deck's sense
```

`RoadNetwork._at` and `_mouth` already compute exactly that vector for ramp placement.

**One real cost.** `_lifted` chose a *vertical* offset specifically so both decks stay
the same length on a bend. A lateral offset makes the inner deck shorter than the
outer one. That is correct for a divided highway and is fine, but it retires an
equal-length assumption and needs a new gate check: **minimum curve radius must exceed
the deck separation**, or the inner lane folds through itself on a tight weave.

---

## Conflicts, and how each is resolved

These are the places this plan runs into an accepted decision. Each needs its ADR in
the PR that creates the conflict.

### Glass vs ADR 0074 and ADR 0057

0074 forbids raising alpha toward opacity; 0057 requires that the surrounding space
stay rendered. A metal-and-glass tunnel is more opaque than what is there now.

**Resolution:** 0057 protects *the world stays witnessed*. Window bays and a glass
median deliver that; what would break it is an enclosed metal tube. So the gate check
changes from "one alpha is below a threshold" to **"the outward-facing area is
transparent, and the glass stays below opaque"** — an area ratio, which is a stricter
and more meaningful check than the number it replaces.

The thicker glass also earns its keep rather than being a look: **the glass is a
diffuser, so a low-detail proxy behind it reads as a plausible ship.** That makes it
load-bearing for LOD, not decoration, and it composes with the existing LOD/collision
invariant — rough renders beyond glass have no body and are not queryable.

### Road docking vs ADR 0057's "no non-interactive transit"

0057 says the player holds their own throttle. A dock that carries you at 75% cruise
is a conveyor.

**Resolution, in the human's words:** *"dock is correct in both cases. The ship is
stationary attached to a meaningful larger entity. You can't access a planet directly
from the highway."* This is the same verb, not a lookalike — you stop piloting and
attach to infrastructure, exactly as at a planet. 0057's clause was written to stop
the tube *itself* being a loading screen; an opt-in berth inside it, that skips no
time and no distance, is a different object.

Three properties keep it honest, and they are what a review should check:

1. **Chosen** — offered on proximity, declined by doing nothing.
2. **Reversible** — `C` again, at any moment.
3. **Never optimal** — 75% of cruise. This is ADR 0058's rule (automation is worse
   than an engaged player) applied to travel, so the dock is a comfort you pay for
   rather than a route optimisation.

**The two hosts share the offer and differ in the exit.** The planet envelope aborts
on mouse motion (`approach_abort_mouse_speed`) because it is a countdown to a
commitment. A road berth is a place you sit inside and want to look around from, read
comms in, and click things in — aborting on look would make it useless for the one
thing it is for. The rule: **a threshold aborts on any input; a berth is left
deliberately.** That divergence is also what frees the mouse for the exit signs.

**Consequence to build later, not now:** if docking a planet opens a services screen,
docking the road opens the chatter channel. Same screen slot. That is where "chatter
with other vessels" belongs.

### The exit sign vs ADR 0013 and ADR 0067

While docked, the player clicks a physical exit sign and the dock takes that ramp.
That looks like routing, which ADR 0013 (autopilot is a heading hold) and ADR 0067
(no junction logic) both forbid.

**Resolution:** a sign is not a map. It is an object in the world, visible before
commitment, chosen at the moment it can be seen — the player makes the decision and
the road changes which rail it is on. The bound to hold, stated exactly: **the dock
follows the centre-line of the deck it is bound to, and a sign click rebinds it to
that ramp.** No merge computed, no arrival, no re-planning, no avoidance.

It is smooth by construction rather than by tuning: **ADR 0070 already requires every
ramp to be tangential to the mainline at the merge**, so a rebind at that point has no
angle to absorb. That ADR was written about ship handling and turns out to be what
makes this safe.

**A decision with a real cost, on purpose:** at 250 m/s against a 2600 m ramp run,
there is a point past which the sign is behind you. Reading it early enough is a
piloting act, and missing it costs one hop off and back on — which is the miss cost
`EXPLORATION_DESIGN.md` already specifies. Sign lead distance is a feel value.

Signs are a small extension rather than new machinery: `Portal` already carries a
world-space destination label (`portal_label_metres`, "TO C" / "FROM A"). An exit sign
is that text mounted on the structure ahead of the mouth, with a click target.
Clickable **only while docked** — a click while flying would be autopilot growth.

### The median vs ADR 0064

0064: the lane boundary is soft, and if the player can be stopped by it, it is wrong.
Glass you fly through looks broken; glass you cannot looks like a wall.

**Resolution:** the soft boundary sits *inside* the glass with a margin, so the push
turns you back before contact. 0064 stands unchanged and nothing gains collision.
**Watch this one** — at cruise 250 in a capital the margin may not be enough, and if
it is not, the honest fix is narrowing ADR 0064 to "the lane is soft, the structure is
not", not widening the push.

---

## The steps

One PR each, in this order, because each sits on the one before.

### A — The section flips ✅ built 2026-08-31 (ADR 0077)

Side by side, right-hand traffic. No new art; the same shell, moved.

*Landed as planned. Two things worth carrying into B: `shade()` lost its deck argument
entirely, because the median is on the left of both carriageways — one function
answers for both and the seam matches by construction. And `deck_separation` moved
150 → 240 to stay flush against `lane_width` rather than `lane_height`, which is the
first of the number shifts below.*

- `RoadDeck.is_upper` → `runs_forward`. `rides_upper()` deleted.
- `RoadNetwork.rebuild` / `_lifted`: lateral offset per point from `travel.cross(UP)`,
  replacing the vertical lift. `deck_separation` becomes an across-measurement.
- `RoadNetwork.governing` keeps grouping by direction so the union can never hand over
  the oncoming lane (ADR 0067's safety property is unchanged, its field is renamed).
- `SystemMap._ride_the_road`, `ExplorationScene` HUD line (`exploration_scene.gd:187`
  prints "upper"/"lower").
- `EXPLORATION_DESIGN.md`: Structure bullets and Enforced Invariant 1.
- Gate: delete the 6 `rides_upper` assertions and the stacking checks; add **minimum
  curve radius > deck separation**.
- **ADR 0077** — traffic runs on the right; the deck convention is retired.

### B — The structure is modules

- Split `RoadStructure` out of `RoadDeck`. **A deck is the lane you fly in; the
  structure is the building around it.** These are currently conflated, and the split
  is what lets one structure carry two lanes.
- One structure per *pair* of decks: floor plate, metal ribs, outer glass bays, median
  glass — four `MultiMeshInstance3D`s stepping along the path.
- Placeholder module meshes generated by a `tools/` script (ADR 0030), so an asset
  review stays a diff review.
- Retire the vertex gradient and its keys.
- Gate: transparent-area ratio, and glass below opaque.
- **ADR 0078** — the road is built from modules.
- **ADR 0079** — glass is a diffuser, and "visually open" is measured as area.
  Supersede notes on 0074 and 0075.

### C — Rings, exit faces, and a second highway

- A steel ring at each ramp mouth: structure around the existing `Portal`, which keeps
  its blue/red per ADR 0060. No conflict — the ring is the building, the sheen is the
  permission.
- Exit face as an authored property of a ramp: right, or above. Entry from below,
  through a hole in the floor plate.
- A second highway crossing at system B, so all three exit cases are flyable. An exit
  rule you cannot fly is an exit rule you cannot judge.
- Gate: **the ring passes the largest hull.** The capital is 84 × 42 m, so a circular
  mouth needs roughly 120 m clear. This is the check ADR 0068 said the gate should be
  able to make and could not.

### D — The floor road and the dock

Depends on C for an interchange to exit at.

- `ApproachEnvelope` mounted on the road — same mechanism, second host.
- The hold: 75% of cruise along the bound deck's centre-line.
- `C` binds in `data/input_map.json` and toggles. No abort on look.
- Exit signs: clickable while docked, rebinding the dock to that ramp.
- HUD line.
- **ADR 0080** — the road is a dock host; a berth is left deliberately; a sign click
  is a rail rebind, not a route.

### E — Deferred to traffic (POC steps 9–10)

Not built here. **The ADR is written now anyway**, because it is precisely the thing a
future session would re-derive into a merge planner:

- Ships outside the glass are rough renders with no body and nothing queryable.
- Real hulls swap in only on the road or close to it.
- **There is no merge logic.** The only rule is an entry clearance check — "make sure
  when the player enters, there does not happen to be a ship there." Same for NPCs
  entering from on-ramps.
- **ADR 0081** — there is no merge logic, only an entry clearance check.

---

## Numbers that will shift

Stacked, the structure was 240 wide × 300 tall. Side by side it is roughly 520 × 150 —
a letterbox, where the concept art is about as tall as it is wide. So `lane_width`
probably wants to come down hard, which is convenient: **the lane at 240 was already
flagged as too wide to read as a tunnel.**

At `lane_width` 150 the section is about 340 × 150, and a capital still gets a 75 m
centre band under the 0.5 `lane_hull_clearance_cap`. Keys and ranges are mine to set
up; **the values are the human's** (feel verdicts are human-only).

New keys, all needing a comment, a `[min..max]`, a `;;;` group and a
`REQUIRED_TUNING_KEYS` entry in the same change:

- structure: rib spacing/thickness, glass alpha, module length, median width
- ramps: ring diameter, ring thickness, exit face
- dock: speed fraction, offer distance, sign lead distance, sign size

Removed: `lane_shell_outer_color`, `lane_shell_divider_color`,
`lane_shell_divider_bias`, and possibly `lane_shell_idle_alpha`.

---

## Also true

- **POC step 7** (cruise fuel, debug teleport) slips behind all of this. It is small,
  and the road not feeling right is the blocking problem.
- **`fighter_max_speed = 80` still wants an arena session** (ADR 0073). Unrelated to
  this plan, still open.
- **`approach_alpha_far = 0`** costs ADR 0012's "a visible place before a commitment"
  clause. Still open, and step D's dock offer is a second reason to revisit it.
- Success criterion 1 wants ten continuous minutes; the trunk leg is ~86 s at cruise
  250. Flagged on `trunk_leg_length`, unresolved.
