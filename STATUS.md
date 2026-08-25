# STATUS

*Updated 2026-08-25.*

## Where the build is

POC build order **steps 3 and 4 are in, and step 5 is all but done**: the arena, the mothership under its one
autopilot behaviour, one dumb target, and the missile — launch, chase cam,
steering, fuse. Early detonate, boost, side thrusters and rock obstacles have since
landed on top. This is the **first feel checkpoint** and it is still waiting on a
human verdict (success criterion 1: the 8 seconds) — now with more verbs to judge.

Toolchain from the bootstrap session is unchanged and still the way everything is
driven; no Godot editor GUI has been used at any point.

### What works

| Thing | State |
|---|---|
| Godot 4.7.2 project, runs windowed and headless | working |
| `tuning.cfg` hot reload (save the file, the running game changes) | working |
| Tuning file is a `ConfigFile` with inline `;` comments on every value (ADR 0033) | working |
| **F2 tuning panel**: live sliders for all 73 ranged values, tooltips, filter, save | working |
| Comment-preserving save — five edits changed exactly five lines | working |
| `Tuning` autoload with typed getters and loud missing-key errors | working |
| Input bindings from `data/input_map.json` (no editor Input Map tab) | working |
| Debug HUD with pluggable readout rows + tuning status line | working |
| Gray-box arena: 7³ marker lattice via one MultiMesh, rebuilt on reload | working |
| Debug fly-cam (RMB look, WASD/QE, Shift boost) | working |
| Asset pipeline: `.obj` model + `.png` texture, generated → imported → rendered | working |
| `make check`: 275 headless assertions, exit code gated | working |
| Godot-3 API linter over all scripts, data-driven denylist | working |
| `make shot`: render frames to PNG from the CLI for visual verification | working |
| `make apiref`: this exact build's 771-class reference for API grounding | working |
| `DESIGN.md` — distilled thesis, Target Experience verbatim | written |
| `decisions/` — 38 ADRs, indexed, each with a *What this forbids* section | written |
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
| **Boost**: held on Space, from a reserve that does not refill in flight | working |
| **Side thrusters**: WASD lateral slide, no momentum past the key (ADR 0037) | working |
| **Rocks kill missiles**: 260 obstacles inside the fight, swept-sphere (ADR 0038) | working |
| Detonate moved to LMB/X so a rider never shares a button with boost | working |

### Deliberately not built yet

In build order, each with its own feel checkpoint — do not pull any of them
forward, because adding one early destroys the reading on the one before it:

- **Step 5** — only **splash damage** is left. Early detonate, boost and side
  thrusters are all in (pulled forward by request). Splash needs the target to have
  hit points, which is really step 7's job, so it may land there instead.
- **Step 6** — turret mode and the missile cooldown. *This is the alternation the
  whole POC exists to test* (success criterion 2).
- **Step 7** — blockers, enemy fire, ship HP.
- **Step 8** — the interrupt, starting at zero and raised carefully.
- **Step 9** — damage, death, respawn, the PiP camera toggle, verdict session.

## Next

**A human feel session, before any more code.** Step 4 is the first checkpoint and
the answer gates everything after it. Fly it, turn the knobs with F2 while it runs,
and answer success criterion 1: *does the developer grin during missile flight, in
gray-box, with no art and no progression?*

The session now has four new things to judge, and they interact — read them
together, not one at a time:

1. **Boost** — is 1.9x for 1.8 s a spend worth making, or is the reserve so small
   it is never worth the thumb?
2. **Thrusters** — does the slide read as a dodge, or as the missile being loose?
   `strafe_ramp_seconds` / `strafe_release_seconds` are the two ends of that.
3. **Rocks as obstacles** — 260 of them from 60 m out. This is the first thing in
   the POC that can kill a missile that was otherwise on target.
4. **Whether the far-field speed reference is missed** now the rocks came inside.
   If it is, the fix is a second sparse non-colliding layer (ADR 0038), not moving
   these back out.

Then step 6 (turret mode and cooldown), which is the alternation the POC exists
to test.

Every change lands on a feature branch via a PR to `main`. See `CLAUDE.md`
§Git flow.

## Open feel questions

Every value below is a starting position picked to be flyable, not a proposal.
They are the knobs most likely to be wrong.

- **`missile/boost_multiplier` 1.9 for `boost_seconds` 1.8, no regen.** A single
  tank per missile, so boost is a route decision rather than a held button. If it
  is always right to burn it immediately, the reserve is too small or the
  multiplier too shy.
- **`missile/strafe_speed` 18 m/s, ramp 0.08 s, release 0.12 s.** Snappy-on,
  slower-off. Both ends may go to zero for an instant lane-snap. This is the pair
  that decides whether thrusters read as Arwing or as slop.
- **`arena/rock_inner_radius` 60 m with `rock_count` 260 and sizes 8–46 m.** Note
  the scale: a 46 m rock 60 m from arena centre is enormous next to a 200 m
  standoff, so the near rocks are large. `rock_hit_radius_scale` 0.55 forgives the
  box corners; raise toward 1.0 to make them bite at their drawn silhouette.
- **`missile/base_speed` 70 m/s and `missile/turn_rate_deg_per_sec` 80.** The
  speed/turn-rate ratio is the whole handling model. Too much turn rate and the
  fuse stops mattering; too little and the shot is decided at launch.
- **`missile/fuse_seconds` 6.0** against a 200 m standoff — about 420 m of travel
  un-boosted, so roughly 220 m of margin for manoeuvring. That margin *is* the
  difficulty (ADR 0002). Boost buys reach at the cost of the reserve.
- **`camera/missile_follow_distance` 14 / `_height` 2.8 / `_look_ahead` 26.** Set
  so the missile sits low-centre with the target above it. Lag is 14.
- **`camera/return_delay_sec` 0.7** — how long the flash is watched before the cut
  back. Long enough to read the outcome, short enough not to be a cutscene.
- **`ship/arc_speed` 14 at `standoff_distance` 200** — how much the launch geometry
  varies shot to shot, which is where the procedural variety comes from.
- **`controls/mouse_sensitivity` 0.28 deg/px** versus the stick. Both are capped by
  the same turn rate so neither device can out-ask the other.

### Decided this session

- **Side thrusters do not supersede ADR 0003** (ADR 0037). The slide is bounded and
  decays to zero on release, so no momentum outlives the input — which is what 0003
  actually objects to. True thrusters with damping remain available as a later
  supersede.
- **Rocks became obstacles** (ADR 0038), superseding only ADR 0032's *placement*
  clause. The swept-segment mechanism is untouched and there is still no physics
  body anywhere in the arena. `arena/rock_collision = false` restores the old arena.

### Fixed this session

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

### How to tune now

Press **F2** in game. Sliders and number boxes for every value, grouped by
section, with a filter box and mouse-wheel scrolling. Hover any row for the long
description. *Save to tuning.cfg* writes your session back to the file without
disturbing a single comment; *Revert* throws it away. Editing the file in a text
editor still hot-reloads, and disk wins over unsaved panel edits.

### Engagement envelope — record this

`docs/COMBAT_POC_IMPLEMENTATION.md` asks for `ship.max_engagement_envelope` to be
observed rather than guessed, because it is the first link in the exploration
numbers chain (envelope → disc height → cruise speeds → system diameter).

Current geometry, as built: standoff 200 m, missile reach ~420 m un-boosted, target
patrol ±120 m, obstacle field from 60 m out. **Nothing is confirmed until a tuning session settles the numbers** — write
the observed value here when it does.

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
