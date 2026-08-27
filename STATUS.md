# STATUS

*Updated 2026-08-27.*

## Where the build is

### ✅ Success criterion 1 has PASSED — 2026-08-27

> "I have play tested enough of the POC to determine this is a winner. The brakes +
> acceleration give a much higher skill ceiling that feels believable."

The 8 seconds work. The named cause is **brake and boost**, which is worth holding
onto: the verdict is not "flying a missile is fun" (that was never in doubt and the
POC doc says so) but that the *speed-versus-agility trade* is what gives it a
ceiling. That is the thing to protect in every later change.

Also endorsed, and now written down:

- **The shared horizon.** "All ships are kept on the same plane" — nothing rolls
  (ADR 0045). This had been an accident of ADR 0003's roll-free bases; it is a rule
  now.
- **Ship movement and the autopilot.** Good enough. Better trajectory-locking
  mechanics are wanted eventually; the heading hold is not blocking anything.

### ⛔ Criteria 2 and 3 are still untested, and cannot be tested yet

**Turret mode does not exist.** Criterion 2 is the loop — "after 30 minutes the
developer is still choosing to fire, and never feels stuck waiting" — and criterion
3 is the ceiling. Both are questions about *what happens between missiles*, and
there is currently no between. `PROJECT_OVERVIEW.md` §Sequencing is blunt about it:
"the loop under test is missile *and* turret, not missile alone."

So the POC is half-verdicted. The half that passed is the half the doc predicted
would pass.

### What works

| Thing | State |
|---|---|
| Godot 4.7.2 project, runs windowed and headless | working |
| `tuning.cfg` hot reload (save the file, the running game changes) | working |
| Tuning file is a `ConfigFile` with inline `;` comments on every value (ADR 0033) | working |
| **F2 tuning panel**: live sliders, tooltips, filter, save — now in collapsible sections | working |
| Comment-preserving save — five edits changed exactly five lines | working |
| `Tuning` autoload with typed getters and loud missing-key errors | working |
| Input bindings from `data/input_map.json` (no editor Input Map tab) | working |
| Debug HUD with pluggable readout rows + tuning status line | working |
| Gray-box arena: 7³ marker lattice via one MultiMesh, rebuilt on reload | working |
| Debug fly-cam (RMB look, WASD/QE, Shift boost) | working |
| Asset pipeline: `.obj` model + `.png` texture, generated → imported → rendered | working |
| `make check`: 403 headless assertions, exit code gated | working |
| Godot-3 API linter over all scripts, data-driven denylist | working |
| `make shot`: render frames to PNG from the CLI for visual verification | working |
| `make apiref`: this exact build's 771-class reference for API grounding | working |
| `DESIGN.md` — distilled thesis, Target Experience verbatim | written |
| `decisions/` — 44 ADRs, indexed, each with a *What this forbids* section | written |
| **Combat arena** (`scenes/arena.tscn`, now the main scene) | working |
| Mothership autopilot: slow arc at standoff, nose on target | working |
| Dumb target ship: drifts, turns at its patrol bounds | working |
| Missile: launch along ship heading, constant speed, fuse | working |
| Reticle steering: input moves an intent marker, the missile turns toward it | working |
| Autopilot faces its direction of travel; missiles launch across the target | working |
| Flight overlay: reticle, nose-to-reticle lag line, screen-edge target arrow | working |
| Early detonate on the fire button while riding, camera returns to the ship | working |
| SHIP ↔ MISSILE camera state machine, hard cut, timed return | working |
| Swept-segment hit test — no physics bodies anywhere (ADR 0032) | working |
| Detonation flash, hit/miss readout, shot and hit counters | working |
| `make shot SCENE=res://tools/shots/missile_view_shot.tscn` — captures the ride | working |
| **Boost**: held on W, from a reserve that does not refill in flight | working |
| **Brake**: held on S, trades speed for turn rate, overrides boost (ADR 0039) | working |
| **Dodge**: A/D, one press, one displacement, then a cooldown (ADR 0039) | working |
| **Rocks kill missiles**: 260 obstacles inside the fight (ADR 0038) | working |
| **Rocks are ellipsoid clusters** — the drawn shape *is* the hit shape (ADR 0041) | working |
| **Manual ship flight**: T toggles, W/S throttle, A/D thrusters, mouse steers (ADR 0040) | working |
| Ship top speed clamped against `missile/base_speed` in code, not by comment | working |
| **Target is a ship shape** — fuselage, nose, wings, fin, built from primitives | working |
| **Destructible components**: 4 cylinders, darken then explode, respawn (ADR 0042) | working |
| Target hit as the boxes it is drawn from; nearest part along the shot wins (ADR 0043) | working |
| **Player ship is a 50 m gunboat** — crescent-winged capital hull (ADR 0044) | working |
| Autopilot eases its nose instead of snapping, and cannot outrun manual flight | working |
| F2 panel folds into one collapsible section per `[section]`, with counts | working |
| `make shot SCENE=res://tools/shots/target_shot.tscn` — captures the target close up | working |

### Deliberately not built yet

In build order, each with its own feel checkpoint — do not pull any of them
forward, because adding one early destroys the reading on the one before it:

- **Step 5** — only **splash damage** is left. Early detonate, boost, brake and
  dodge are all in (pulled forward by request). Splash needs the target to have hit
  points, which is really step 7's job, so it may land there instead.
- **Step 6** — turret mode and the missile cooldown. *This is the alternation the
  whole POC exists to test* (success criterion 2).
- **Step 7** — blockers, enemy fire, ship HP.
- **Step 8** — the interrupt, starting at zero and raised carefully.
- **Step 9** — damage, death, respawn, the PiP camera toggle, verdict session.

## Next

**Turret mode — steps 6, 7 and 8 together.** Specified in full by the human on
2026-08-27 and written up in `docs/TURRET_MODE_IMPLEMENTATION.md`: four weapons
across two loadouts, blockers on both sides, a 10 s missile cooldown, and the
interrupt. Read that doc's *Flags* section before building — three build-order
checkpoints are landing at once, and the interrupt is arriving at an interval the
scope doc predicts is far too dense. Every layer is required to be independently
disableable from tuning so clean readings are still obtainable.

The reason it is next, unchanged: It is the last thing that could
invalidate the design, and it is small — the view state machine already treats
TURRET as a peer of SHIP (`view_controller.gd` says so in its header), the reticle
instrument is shared and tested, and the swept-segment hit testing already works
against ship parts. No ladder, no walking, no interior: an instant switch to a
fixed station, aim-and-track, and a cooldown timer.

**And take the engagement-envelope measurement** — see below. It is an observation,
not a design act, and the entire exploration numbers chain is blocked on it.

Everything else the design is waiting on — cruise, economy, missions, interactions,
art — is downstream of one or the other of those two. See *Where to start* below.

Still open from the first feel session, and worth judging while playing step 6:

1. **Boost and brake numbers.** 1.9x for 1.8 s of reserve; 0.55x speed for 1.8x
   turn. The verdict says the *shape* is right, which makes the values worth a
   second pass rather than a first one.
2. **Dodge** — 22 m over 0.28 s on a 1.1 s cooldown. Not named in the verdict
   either way. Worth asking whether it is earning its button (ADR 0047 leaves its
   tier open for that reason).
3. **The ship's new scale.** 50 m of hull at a 203 m standoff, camera 62 m back.
   Every camera and speed value was retuned around it and none has been felt.
4. **Target practice.** Components against a single hit sphere.
   `enemy/component_count = 0` restores the old target for an A/B.
5. **Whether the far-field speed reference is missed** now the rocks came inside.
   If it is, the fix is a second sparse non-colliding layer (ADR 0038), not moving
   these back out.

## Where to start — the dependency chain

*Full version, with what each stage is blocked on: `docs/ROADMAP.md`.
The current build's detailed spec: `docs/TURRET_MODE_IMPLEMENTATION.md`.*

The design has a lot of open fronts (cruise, between-system activity, economy,
missions, interactions, art) and they look parallel. They are not; they are a
chain, and most of it is already written down in `PROJECT_OVERVIEW.md`
§Sequencing and §Open Questions. In order:

1. **Finish the combat bet** — step 6, then 7-9. Cheapest remaining question,
   and the only one that can still say "rethink".
2. **Measure `ship.max_engagement_envelope`.** Root of the numbers chain.
3. **Exploration prototype** — the second bet, and blocked on 2. Cruise feel, the
   gauntlet, whether a gray blip is worth diverting for.
4. **Overworld design in parallel** — chat-only, validated by a headless faction
   sim at 1000x before anything visual exists.
5. **Economy, missions, interactions** — these price off travel time, which comes
   out of 3. Travel carries the campaign clock (ADR 0022), the clock sets mission
   cadence, cadence sets economy tuning. Designing them before cruise feel is
   settled means re-tuning all of it afterwards.
6. **Art, last.** Placeholders are generated by scripts and replaced in place
   (ADR 0030); nothing in code knows the difference, so nothing is waiting on it.

Every change lands on a feature branch via a PR to `main`. See `CLAUDE.md`
§Git flow.

## Open feel questions

Every value below is a starting position picked to be flyable, not a proposal.
They are the knobs most likely to be wrong.

- **`missile/boost_multiplier` 1.9 for `boost_seconds` 1.8, no regen.** A single
  tank per missile, so boost is a route decision rather than a held button. If it
  is always right to burn it immediately, the reserve is too small or the
  multiplier too shy.
- **`missile/dodge_distance` 22 m over `dodge_seconds` 0.28, cooldown 1.1 s.** The
  displacement eases out, so most of it lands in the first few frames. Cooldown
  under `dodge_seconds` degenerates back into a held strafe — the thing ADR 0039
  removed.
- **`missile/brake_speed_multiplier` 0.55 and `brake_turn_multiplier` 1.8.** How
  sharp the speed/agility trade is. Brake pays in range and nothing else.
- **`arena/rock_inner_radius` 69.8 with `rock_count` 260 and sizes 8–46 m.** Note
  the scale: a 46 m rock 70 m from arena centre is enormous next to a 203 m
  standoff, so the near rocks are large. These counts and sizes were chosen against
  the *old* forgiving hit shape — the field is meaningfully more solid now that
  `rock_hit_radius_scale` is 1.0 and the ellipsoids bite at their own silhouette.
  Expect to want fewer or smaller.
- **`missile/base_speed` 58 m/s and `missile/turn_rate_deg_per_sec` 41.85.** The
  speed/turn-rate ratio is the whole handling model. Too much turn rate and the
  fuse stops mattering; too little and the shot is decided at launch.
- **`missile/fuse_seconds` 6.0** against a 203 m standoff — about 350 m of travel
  un-boosted, so roughly 150 m of margin for manoeuvring. That margin *is* the
  difficulty (ADR 0002). Boost buys reach at the cost of the reserve.
- **`camera/missile_follow_distance` 7.85 / `_height` 2.0 / `_look_ahead` 25.5.**
  Set so the missile sits low-centre with the target above it. Lag is 14.
- **`camera/return_delay_sec` 0.7** — how long the flash is watched before the cut
  back. Long enough to read the outcome, short enough not to be a cutscene.
- **`ship/arc_speed` 13.8 at `standoff_distance` 203** — how much the launch
  geometry varies shot to shot, which is where the procedural variety comes from.
- **`controls/mouse_sensitivity` 0.20 deg/px** versus the stick. Both are capped by
  the same turn rate so neither device can out-ask the other.
- **`ship/manual_max_speed` 34 against a 0.6 ceiling fraction.** 0.6 x 58 is 34.8,
  so the ship's own number is what currently binds — but only just. Raise
  `manual_max_speed` and the clamp takes over silently and correctly; the HUD's
  *flight* row shows both figures so it is visible when that happens.
- **`ship/manual_accel_seconds` 3.2 and `manual_brake_seconds` 2.4.** How heavy the
  ship feels to get moving and to stop. Longer is more ship-like and more annoying;
  the crossover is the thing to find.
- **`ship/manual_turn_rate_deg_per_sec` 26** against the missile's 41.85. The gap
  between those two numbers is how different the two vehicles feel to fly, and it
  is the main dial for that.
- **`enemy/component_count` 4 at `component_hit_radius` 2.2**, inside a hull sphere
  of 9. If components are too easy to hit the experiment says nothing; if they are
  too hard, every shot lands on the hull and it also says nothing.
- **`enemy/component_respawn_seconds` 8.0.** A harness value, not a design claim —
  it exists so the loop can be felt more than once per session.

### Decided 2026-08-27 (from the POC verdict)

- **Every vehicle shares one horizon; nothing rolls** (ADR 0045). Promoted from an
  accident of ADR 0003 to a rule, because the next session to add a vehicle will
  otherwise reach for a roll axis and the reason not to was nowhere in the code.
  Ships and missiles still pitch and climb freely — this is not a 2D plane.
- **Two supported playstyles, one economic gradient** (ADR 0046). Gunboat with
  missiles and turret, or a fast fighter with ship-facing pilot-controlled guns.
  Merchant hulls are large and hauling is the reliable money, so the earning curve
  points at the gunboat. **The tension to watch:** the fighter must earn *less*,
  never *not enough* — ADR 0025's "the cautious path stays viable" applies, and a
  playstyle that cannot pay its own upkeep is a trap dressed as a choice.
- **Brake and boost are missile-tier equipment** (ADR 0047), not baseline verbs.
  The starting missile is reticle steering, a fuse and early detonate. This is
  Pillar 1's "the upgrade tree is itself a difficulty dial" applied to the two
  verbs that turned out to carry the ceiling — and it protects the fuse, which is
  fuzzier to read when boost is available (ADR 0002).

### Decided 2026-08-26

- **Manual ship flight lands** (ADR 0040). `T` toggles; `W`/`S` are a *throttle*
  that stays where it is put, `A`/`D` are held thrusters, the mouse steers through
  the same reticle instrument the missile uses. The autopilot is untouched and
  still starts every run. This is the human lifting a deferral the scope doc always
  marked as one — not a design reversal, and `docs/COMBAT_POC_IMPLEMENTATION.md`
  now carries the amendment.
- **The speed hierarchy is enforced in code.** `ship/manual_max_speed` is clamped
  against `missile/base_speed`, on the whole velocity vector so a thruster held at
  full throttle cannot sum past it either. `CLAUDE.md` calls the hierarchy
  structural; a tuning comment is not a structure.
- **A rock is a cluster of ellipsoids, and the drawn shape is the hit shape**
  (ADR 0041). This answers both halves of the human's report at once — the missing
  corners *and* "they don't look like rocks" — because the thing that fixes the
  silhouette is the same thing that fixes the hit test. `rock_hit_radius_scale`
  is back to 1.0. ADR 0032's mechanism rule is untouched: still no physics body,
  still swept segments, now against `segment_hits_ellipsoid`.
- **The target carries destructible components** (ADR 0042). Two hits each:
  darken, then explode. They respawn, because otherwise a practice run is over in a
  handful of shots and the loop cannot be felt twice.
- **The target is hit as its parts, nearest-first** (ADR 0043, superseding ADR
  0042's hull clauses). See *Fixed this session* — this started as a bug and became
  a rule: **test order cannot substitute for geometry**, and a volume that encloses
  another makes it unreachable however the tests are ordered.
- **The autopilot may not fly the ship in a way the player could not** (ADR 0043).
  It is clamped to the ship's own top speed and turns its nose at a bounded rate.
  Both of those were free while the autopilot was the only thing flying; manual
  flight is what made them observable.
- **Ships are capital-scale gunboats; the engagement is naval, not a dogfight**
  (ADR 0044). The player's hull is 50 m stem to wingtip now — a thick faceted core
  with forward-swept crescent wings, the *StarCraft* reading of "carrier" rather
  than the flat-decked US Navy one. The old `probe.obj` was a 5 m dart, and a dart
  implies a dogfight, which is the wrong game to be reading feel verdicts against.
- **The F2 panel folds.** One collapsible section per `[section]`, collapsed by
  default, each header carrying its value count; `+`/`−` expand and collapse
  everything; the filter reaches into collapsed sections and restores the fold
  state when cleared. 200-odd rows in one scroll had become the bottleneck.
- **`ReticleSteering` is now shared** between the missile and manual flight. The
  two vehicles differ in their numbers, not in their model — a ship that taught a
  different mouse response from the missile would be teaching the wrong one, and
  the player spends far more time in the ship.

### Fixed this session

- **No component was ever hittable.** Reported as "I didn't see any enemy ship
  component ever get hit — my aim can't be that bad." The aim was fine. Every
  component sat inside the hull's 9 m sphere, so the sphere always resolved first,
  four metres before the nearest component — the "components are tested first" rule
  in ADR 0042 never came into play. Worse, that ADR's own gate asserted the
  *opposite* invariant ("components sit within the hull's hit sphere") and passed.
  The hull is now hit as the boxes it is drawn from, components are mounted proud
  of it, and the nearest shape along the shot wins (ADR 0043). The gate checks the
  geometric property — every component's outermost point outside every hull box —
  instead of the ordering, which was never the thing that mattered.
  **Expect hits to be harder now.** The old sphere was far more forgiving than the
  12 m hull it wrapped. If the target feels unfairly small, grow it with
  `enemy/hull_*` rather than re-inflating a sphere around it.
- **Handing the ship back to the autopilot yanked it.** The autopilot re-pointed
  its nose with `look_at`, which snapped through whatever angle the player had left
  it at, on the first frame; and it station-kept at up to 45 m/s against a manual
  ceiling of 34, so it could also move the ship faster than the player ever could.
  Both were invisible while the autopilot was the only thing flying. It now turns
  at `ship/autopilot_turn_rate_deg_per_sec` and is clamped to the ship's own top
  speed. A stale `_last_standoff` could also fire a `snap_to_standoff` teleport
  after a standoff edit made during manual flight; the handover now adopts the
  current value.
- **The strafe summed past the speed ceiling.** Caught in a screenshot reading
  `36 m/s of 34`: the lateral thruster was added on top of a full throttle. The
  clamp is on the whole velocity vector now, so the speed hierarchy cannot be
  broken by holding two keys.
- **The target's art was bigger than its hit sphere** — a 26 m hull inside a 9 m
  sphere, which is the same art-vs-hitbox gap that got the rocks rebuilt, freshly
  reintroduced in the same session. Moot now that the hull is hit as its parts, but
  it is why the hull proportions are what they are.
- **Autopilot could not hold its standoff.** The range correction was a normalised
  blend of tangent and radial, so its authority collapsed at the setpoint and a
  target drifting at 6 m/s outran it — the held range wandered indefinitely, and
  after a `standoff_distance` edit the ship crawled toward the new value ever more
  slowly. It read as "hot reload is broken"; hot reload was fine. Now the radial
  correction is an explicit speed (`range_hold_seconds`, `range_hold_max_speed`),
  and a standoff edit snaps the ship immediately so the typed value is visible at
  once. Guarded by a 30-second simulated regression test.
- **The flight overlay drew nothing.** A `Control` parented straight to a
  `CanvasLayer` has no parent Control to resolve anchors against, so
  `PRESET_FULL_RECT` left it at zero size and the edge-clamping maths degenerated.
  It now sizes itself from the viewport, with a test asserting non-zero size.
- **`glow_intensity` was a constant in arena code** — a feel value in code, which
  the feel-parameter law forbids. Moved to `[arena]`.

### Known inconsistency

The **enemy target is still a 12 m fighter silhouette** — fuselage, nose cone,
wings, fin — which predates ADR 0044 and now contradicts it. If the engagement is
naval, the thing being engaged should read as a gunboat too. Left alone
deliberately rather than changed in the same pass; it is a known inconsistency, not
a considered contrast. Changing it is cheap: the hull is built from tuning values
in `TargetShip._build_hull`, and the hit volumes are registered beside each drawn
part, so the shape and the hit test move together.

### How to tune now

Press **F2** in game. Every value in the file is here, folded into one collapsible
section per `[section]` — click a header to open it, or `+` / `−` to open and close
everything at once. Each header shows how many values are inside. The filter box
reaches into collapsed sections and puts the fold state back when you clear it.
Hover any row for the long description. *Save to tuning.cfg* writes your session
back to the file without disturbing a single comment; *Revert* throws it away.
Editing the file in a text editor still hot-reloads, and disk wins over unsaved
panel edits.

### Engagement envelope — STILL UNMEASURED, and now it is the blocker

`docs/COMBAT_POC_IMPLEMENTATION.md` asks for `ship.max_engagement_envelope` — the
largest distance a fight sprawls across — to be observed rather than guessed,
because it is the first link in the exploration numbers chain:

> envelope → disc height (5-10x the envelope) → cruise speeds → system diameter

`PROJECT_OVERVIEW.md` §Open Questions 1 adds that these are "sized in that order;
each mostly determines the next", and that the height:diameter ratio is an *output*.
So the exploration prototype cannot be scoped without this number, and guessing it
means re-deriving cruise speeds and system size afterwards.

It costs one playtest to observe and it has now been deferred twice.

Current geometry, as built: standoff 203 m, missile reach ~350 m un-boosted, target
patrol ±300 m, obstacle field from 70 m out, player hull 50 m. Manual flight makes
this properly observable for the first time — **the standoff you choose when you
own the throttle is the reading that matters**, not the one the autopilot holds.
Write the observed value here.

### Still open from the doc

- Whether the hard-cut camera transition or Descent-style PiP wins the round trip.
  `camera/missile_view_mode` carries the toggle; only `"cut"` is implemented (PiP
  is step 9).

## Notes for the next session

- `make check` before calling anything done. `make shot` to look at it yourself.
- Godot 4.7 segfaults if you `ResourceLoader.load()` a `class_name` script with
  `CACHE_MODE_IGNORE`; the test runner uses the default cache mode for that reason.
- `godot --check-only --script foo.gd` cannot see autoloads, so it reports
  "Identifier not found: Tuning" for most files. It is not a usable gate; the
  in-scene-tree test runner is.
- `tuning.cfg` uses `;` for comments. `#` is **not** a comment character — it gets
  parsed into the next key and corrupts the file without an obvious error.
- Adding a new `class_name` needs `make import` before anything can reference it,
  or the script fails to parse with "Could not find type". `make check` depends on
  `import` for that reason, and carries a `timeout` watchdog — when the runner
  script itself fails to parse, its scene root has no script, nothing calls
  `quit()`, and the engine idles forever instead of failing.
