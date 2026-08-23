# STATUS

*Updated 2026-08-23.*

## Where the build is

POC build order **steps 3 and 4 are in**: the arena, the mothership under its one
autopilot behaviour, one dumb target, and the missile — launch, chase cam,
steering, fuse. This is the **first feel checkpoint** and it is waiting on a human
verdict (success criterion 1: the 8 seconds).

Toolchain from the bootstrap session is unchanged and still the way everything is
driven; no Godot editor GUI has been used at any point.

### What works

| Thing | State |
|---|---|
| Godot 4.7.2 project, runs windowed and headless | working |
| `tuning.cfg` hot reload (save the file, the running game changes) | working |
| Tuning file is a `ConfigFile` with inline `;` comments on every value (ADR 0033) | working |
| `Tuning` autoload with typed getters and loud missing-key errors | working |
| Input bindings from `data/input_map.json` (no editor Input Map tab) | working |
| Debug HUD with pluggable readout rows + tuning status line | working |
| Gray-box arena: 7³ marker lattice via one MultiMesh, rebuilt on reload | working |
| Debug fly-cam (RMB look, WASD/QE, Shift boost) | working |
| Asset pipeline: `.obj` model + `.png` texture, generated → imported → rendered | working |
| `make check`: 71 headless assertions, exit code gated | working |
| Godot-3 API linter over all scripts, data-driven denylist | working |
| `make shot`: render frames to PNG from the CLI for visual verification | working |
| `make apiref`: this exact build's 771-class reference for API grounding | working |
| `DESIGN.md` — distilled thesis, Target Experience verbatim | written |
| `decisions/` — 35 ADRs, indexed, each with a *What this forbids* section | written |
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

### Deliberately not built yet

In build order, each with its own feel checkpoint — do not pull any of them
forward, because adding one early destroys the reading on the one before it:

- **Step 5** — boost/afterburner and splash damage. *Early detonate is already in*
  (pulled forward by request); what remains of step 5 is boost and splash.
- **Step 6** — turret mode and the missile cooldown. *This is the alternation the
  whole POC exists to test* (success criterion 2).
- **Step 7** — blockers, enemy fire, ship HP.
- **Step 8** — the interrupt, starting at zero and raised carefully.
- **Step 9** — damage, death, respawn, the PiP camera toggle, verdict session.

## Next

**A human feel session, before any more code.** Step 4 is the first checkpoint and
the answer gates everything after it. Fly it, turn the knobs in `tuning.cfg` while
it runs, and answer success criterion 1: *does the developer grin during missile
flight, in gray-box, with no art and no progression?*

Then step 5 (boost, early detonate, splash), then step 6 (turret mode and
cooldown), which is the alternation the POC actually exists to test.

Every change lands on a feature branch via a PR to `main`. See `CLAUDE.md`
§Git flow.

## Open feel questions

Every value below is a starting position picked to be flyable, not a proposal.
They are the knobs most likely to be wrong.

- **`missile/base_speed` 90 m/s and `missile/turn_rate_deg_per_sec` 100.** The
  speed/turn-rate ratio is the whole handling model. Too much turn rate and the
  fuse stops mattering; too little and the shot is decided at launch.
- **`missile/fuse_seconds` 5.0** against a 240 m standoff — about 450 m of travel,
  so roughly 210 m of margin for manoeuvring. That margin *is* the difficulty
  (ADR 0002). It is currently generous.
- **`camera/missile_follow_distance` 14 / `_height` 2.8 / `_look_ahead` 26.** Set
  so the missile sits low-centre with the target above it. Lag is 14.
- **`camera/return_delay_sec` 0.7** — how long the flash is watched before the cut
  back. Long enough to read the outcome, short enough not to be a cutscene.
- **`ship/arc_speed` 14 at `standoff_distance` 240** — how much the launch geometry
  varies shot to shot, which is where the procedural variety comes from.
- **`controls/mouse_sensitivity` 0.28 deg/px** versus the stick. Both are capped by
  the same turn rate so neither device can out-ask the other.

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

### Engagement envelope — record this

`docs/COMBAT_POC_IMPLEMENTATION.md` asks for `ship.max_engagement_envelope` to be
observed rather than guessed, because it is the first link in the exploration
numbers chain (envelope → disc height → cruise speeds → system diameter).

Current geometry, as built: standoff 240 m, missile reach ~450 m, target patrol
±120 m. **Nothing is confirmed until a tuning session settles the numbers** — write
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
