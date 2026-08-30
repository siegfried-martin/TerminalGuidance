# CLAUDE.md — working agreement for this repo

Working title: **Missile Rider**. This file is the part that must survive every
session; the rules below are not suggestions.

**Where to look:**

| For | Read |
|---|---|
| The design, distilled — thesis, pillars, what this game is *not* | `DESIGN.md` |
| Decisions already made, and what each one forbids | `decisions/` |
| What is built, what is next, open feel questions | `STATUS.md` |
| What is being built first, and its scope boundary | `docs/COMBAT_POC_IMPLEMENTATION.md` |
| What is being built *right now*, in detail | `docs/EXPLORATION_POC_IMPLEMENTATION.md` |
| The travel layer's locked decisions — roads, portals, the speed ladder, crew | `docs/EXPLORATION_DESIGN.md` |
| The combat bet, now built | `docs/TURRET_MODE_IMPLEMENTATION.md` |
| What comes after the combat bet, and in what order | `docs/ROADMAP.md` |
| The full design of record | `docs/PROJECT_OVERVIEW.md` |

Before proposing anything that changes how the game behaves, check `decisions/` —
each ADR has a **What this forbids** section, and most of the genre defaults you
would reach for by reflex are forbidden there deliberately.

## Engine and version

- **Godot 4.7.2.stable** (`ed1daf0bf`), GDScript, native Linux. Pinned — check
  `godot --version` before assuming.
- **Never emit Godot 3.x APIs.** This is the known failure mode for LLM-written
  Godot code: years of Godot 3 tutorials in the training data, emitted with total
  confidence. `Spatial`, `yield()`, `export var`, `.instance()`,
  `connect("sig", self, "method")`, `File.new()`, `deg2rad()`, `PoolVector3Array`
  are all wrong here.
- **When unsure whether an API is 3.x or 4.x, look it up in this build's own class
  reference** rather than recalling it: `make apiref` dumps 771 class XML files to
  `.apiref/doc/classes/` from the exact binary on this machine. `grep -n
  "method name=" .apiref/doc/classes/Node3D.xml`. That is ground truth; memory is not.
- `make check` fails the build on a denylist of Godot-3-isms
  (`tools/tests/godot3_denylist.json`). Add a rule the first time anything new
  gets past review. Escape hatch for a false positive: `# godot4-lint: ignore`
  on the line.

## The feel-parameter law

**No gameplay-feel constant may appear in code.** Every feel value — turn rates,
fuse times, camera lag, boost curves, easing, cooldowns, interrupt frequency,
cruise speeds, spool times, light angles, FOV — lives in `tuning.cfg` and is read
through the `Tuning` autoload at the point of use.

- Adding a feel parameter means: add it to `tuning.cfg`, read it via
  `Tuning.num()` / `vec3()` / `color()` / `flag()`, add it to
  `REQUIRED_TUNING_KEYS` in `tools/tests/test_runner.gd`, and surface it in the
  debug HUD if it is something the human will want to watch. Same change, not a
  follow-up.
- `Tuning` getters take **no default argument**, on purpose. A default is a feel
  constant hiding in code, and it makes a typo'd key behave plausibly. A missing
  key errors, turns the HUD's tuning line red, and fails `make check`.
- Saving `tuning.cfg` hot-reloads it into the running game. Systems that cache a
  derived value must rebuild on the `Tuning.reloaded` signal (see
  `GrayBoxArena.rebuild()`).
- `tuning.cfg` is a Godot `ConfigFile` (ADR 0033). Comments start with `;` and may
  sit at the end of a value line; **`#` is not a comment character** and silently
  corrupts the next key. Values are Godot literals — `Vector3(x, y, z)` is real,
  colours are hex strings.
- **Values are edited in-game with the F2 panel** (ADR 0036), and Save writes back
  to `tuning.cfg` preserving every comment. The comments are the panel's labels,
  tooltips and slider ranges:

  ```ini
  ;; Long-form description, shown as the tooltip. As many lines as it needs.
  base_speed = 70.0        ; [20..400] m/s. Short label, shown on the row
  ```

  So **every new value needs a comment**, and a `[min..max]` marker if it should
  get a slider. Adding the value and documenting it are one action, not two.
- Infrastructure constants (poll intervals, buffer sizes, layer numbers) are not
  feel values and belong in code as `const`. If the human would ever want to nudge
  it while looking at the screen, it is a feel value.
- **Feel verdicts are human-only.** Build the instrument; do not turn the knobs and
  do not report on how something feels. When given feel direction, expect reference
  anchors ("Star Fox Arwing, not a Newtonian thruster"), not adjectives.

## Code-first scene policy

- **The editor is a viewer, not an authoring tool.** `.tscn` files are shells: a
  root node and a script, nothing else. Everything is constructed programmatically
  in `_ready()` from data. See `scenes/sandbox.tscn` (7 lines) and
  `scripts/sandbox/sandbox.gd`.
- Do not add authoritative state through the editor. A design decision must never
  be discoverable only by opening a scene in a GUI.
- Input bindings live in `data/input_map.json` and are applied by the `Bindings`
  autoload. Do not use the editor's Input Map tab — those land in `project.godot`
  and get clobbered.
- `project.godot` stays minimal. Anything expressible as code or data goes there
  instead.
- Placeholder art is generated by a script in `tools/` where practical
  (`gen_probe_obj.py`, `gen_textures.py`), so an asset review is a diff review.
  Real art will replace those files in place; no code knows the difference.

## Scope guard

- POC scope is defined in `docs/COMBAT_POC_IMPLEMENTATION.md`. Do not implement
  out-of-scope features even when adjacent or easy. **Flag scope questions instead
  of resolving them.**
- Some omissions are *scope deferrals, not design decisions*, and are marked as
  such in that doc (manual ship flight is the big one). Do not convert a deferral
  into an ADR or into a code assumption.

## Target-experience guard

This game targets **relaxed mastery, not tension**. The governing rule:

> **Pressure is a decision the player made, never a condition imposed on them.**
> It must be chosen, visible before commitment, and reversible.

- Passes: fuel spent on a route you plotted; cargo mass traded against speed; the
  opportunity cost of every second in the missile being a second off the gun.
- Fails: being pulled out of cruise by an NPC's decision; unattended systems
  degrading while you are busy; ambient dread; anything demanding attention on two
  things at once.
- Stress is a spike, never ambient. Pressure comes one job at a time — the player's
  attention is sequential, never parallel.
- Resource costs the player plans around (fuel, cargo, ammo) are **not** covered by
  the prohibition. They pass the rule.
- **Flag any proposal that adds background threat**, including ones that look like
  good design in isolation. This section is the one most likely to erode silently.

## Architectural invariants

These are cheap now and expensive to retrofit. They hold even where the thing they
protect is not implemented yet.

- **Floating origin.** The world recentres on the player. No system may assume a
  fixed world origin or cache a world-space position across frames without
  accounting for the shift. Prefer relative positions and parent-relative
  placement. This applies inside the origin-local combat arena too.
- **LOD / collision.** Distant planets and stations are background-layer visuals
  with no physics body and nothing queryable. Only the swapped-in real mesh has
  collision. Never raycast, overlap-test, or query a distant object — that bug
  looks like a physics bug and is not.
- **No interdiction.** Cruise is dropped by player input alone. Never by an NPC's
  decision, and never by taking damage — "drops on damage" is interdiction with an
  extra step. Damage degrades top cruise speed instead. Flag any proposal that
  stops the player's ship because of something an NPC did; it is the genre default
  and it is deliberately rejected here.
- **Autopilot is a heading hold.** It points the nose at a designated object; the
  player owns the throttle. It does not path, avoid, arrive, or make decisions.
  Do not grow it. `EXPLORATION_DESIGN.md`'s "autopilot is your own character flying"
  describes **what it already is** — every station is a person who keeps working,
  worse, while the player is elsewhere. A better hired pilot is a better *number*,
  never more authority, and is still worse than the player (ADR 0058). "Hiring a
  better pilot" is not a reason to add pathfinding, avoidance, or arrival.
- **Speed hierarchy** is structural: lasers > missiles > ships. It is now **keyed by
  hull class** — one global fraction cannot express a taxi at 0.27 of missile speed
  and a fighter at 0.67 — so what it guarantees is *"a missile outruns its intended
  targets"* (ADR 0059). Read ship numbers through `HullClass`, never straight out of
  `Tuning` at a site that knows the class, and never express a speed relationship
  between two ships as an absolute.
- **The highway is a place, not a mode** (ADR 0057, superseding 0009). The cruise
  drive works on the road and nowhere else, and there is no personal equivalent for
  open space. Inside the tube: no camera cut, no scene load, no non-interactive
  transit, the surrounding space stays rendered, and floating origin and
  LOD/collision rules apply exactly as everywhere else.

## Testing convention

- `make check` is the gate, and it must pass before anything is called done. It
  runs headless in a real scene tree (autoloads only exist there — a bare
  `godot --check-only --script foo.gd` reports "Identifier not found: Tuning" and
  is useless as a gate).
- It covers: every `.gd` compiles, the Godot-3 denylist, required tuning keys,
  required input actions, asset import, and that the sandbox scene actually builds
  its nodes. Extend it in the same change that adds a system.
- `make shot` renders frames to `.shots/` via the movie writer, so a visual change
  can be verified from the command line without opening a window or the editor.
  Use it; do not ask the human to look at something you have not looked at.
- Systems logic is verified by tests. Physics and feel are verified by the human.

## Project layout

```
project.godot          minimal; autoloads and window config only
tuning.cfg             every feel value in the game, with inline comments
data/input_map.json    input bindings
scenes/arena.tscn      main scene: the combat POC arena (shell only)
scenes/sandbox.tscn    asset/harness scene with the debug fly-cam (shell only)
scripts/autoload/      Tuning, Bindings
scripts/arena/         the combat arena builder
scripts/ships/         mothership, target ship
scripts/weapons/       missile, turret rounds, and the one shot resolver
scripts/view/          camera/control state machine, chase camera, the gun station
scripts/world/         marker lattice, reference field
scripts/effects/       detonation flash, pulse-beam tracer
scripts/lib/           pure helpers — no scene tree, no disk, unit tested:
                       FlightGeometry, ReticleSteering, Damage, HullClass,
                       BoundaryField, EnvelopeMeter, TuningSchema,
                       TuningWriter
scripts/sandbox/       the asset harness scene
scripts/debug/         HUD, debug fly-cam, the F2 tuning panel
assets/                models and textures (+ committed .import files)
tools/                 asset generators, test harness, screenshot harnesses
docs/                  design and POC docs (source of truth for intent)
.apiref/               generated, gitignored: this build's class reference
```

Conventions: one class per file, `snake_case.gd` matching the `class_name`,
typed GDScript throughout (`untyped_declaration` is a configured warning),
autoloads are nouns (`Tuning`, `Bindings`), `_private` members prefixed.

## Git flow

- `main` is protected by convention: **no direct commits.** Every change lands
  through a feature branch and a PR, so the work is trackable.
- Branch naming: `feat/<slug>`, `fix/<slug>`, `docs/<slug>`, `chore/<slug>`.
- One PR per coherent step. The POC build order in
  `docs/COMBAT_POC_IMPLEMENTATION.md` is a reasonable PR granularity — a step per
  branch, not the whole POC in one.
- `make check` must pass before a PR is opened. State it in the PR body.
- A PR that changes anything visual should include a `make shot` frame or say what
  was verified and how.
- A PR that makes a decision worth keeping adds its ADR in the same PR.

## Session hygiene

- Update `STATUS.md` at the end of a working session: what works, what is next,
  open feel questions. Parallel sessions and future ones resume from it.
- One short ADR in `decisions/` per irreversible or surprising decision, with the
  reasoning and the date. See `decisions/README.md` for the template and the
  supersede rule — accepted ADRs are never edited to change their decision.
- Record feel observations as they happen, especially
  **`ship.max_engagement_envelope`** (the largest distance a fight sprawls across).
  It is the first link in the exploration numbers chain, free to observe now and
  expensive to guess later.
