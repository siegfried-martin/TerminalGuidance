# Turret Mode — Implementation Doc

*Version 1 · 2026-08-27 · covers POC build-order steps 6, 7 and 8, specified together by the human after the criterion-1 verdict.*

This is the second half of the combat bet. `COMBAT_POC_IMPLEMENTATION.md` remains
the scope authority; this document is the detail for the part of it that is being
built now, plus the things that were decided in the specifying conversation and
would otherwise be lost.

## Why this exists now

Success criterion 1 (the 8 seconds) passed on 2026-08-27. Criteria 2 (the loop)
and 3 (the ceiling) are questions about **what happens between missiles**, and
there is currently no between. `PROJECT_OVERVIEW.md` §Sequencing: *"the loop under
test is missile and turret, not missile alone."*

---

## The specification

Verbatim intent from the human, restated precisely.

### Entering the station

- **`G` enters turret / gun mode**, exactly as `T` toggles manual pilot now.
- Turret view is a **peer of ship view**, not a sub-state of it — `view_controller.gd`
  already says so in its header. The state machine becomes:

      SHIP ←→ TURRET
       ↓ (fire)
      MISSILE → (impact | fuse | rock | flare) → SHIP

- No ladder, no walking, no interior. The switch is instant and diegetically
  unexplained (POC scope item 6).

### The four weapons

| # | Weapon | Fire | Range | Ammo / limiter | Projectile? |
|---|---|---|---|---|---|
| 1 | **Autocannon** | 2 shots/sec | medium | unlimited | yes, travels |
| 2 | **Unguided missile** | click to fire, **click again to detonate** | — | 10 per magazine | yes, travels |
| 3 | **Pulse beam** | continuous | short | **heat buildup** | **no — hitscan** |
| 4 | **Blockers** | one press | — | 5 s cooldown | flares, travel slowly |

- The **unguided missile** detonates in a **large radius — twice the ridden
  missile's** — and is explicitly meant to be useful for two things: killing
  incoming enemy missiles, and damaging several components on the enemy ship at
  once.
- The **pulse beam is hitscan on purpose**, so that lead and travel time do not
  have to be factored in. That is a design requirement, not an optimisation.
- **Blockers** spit out multiple flares in a **star pattern**; an enemy missile
  that touches one dies.

### Loadouts

- Four weapons, **two loadouts**, each mapping **left click** and **right click**.
- **`1` and `2`** switch loadout.

### Enemy behaviour

- When a player missile is approaching, the enemy **fires a blocker with 50%
  probability**.
- The enemy **fires a guided missile at the player once per minute**, with random
  imperfect accuracy. **A small alert is shown to the player** when this happens.

### Player rhythm

- **The player's ridden missile has a 10-second cooldown.**

---

## Flags — read these before building

These are recorded because the repo's own rules require them to be raised, not
because the direction is being questioned. The human's call stands on all of them.

### 1. The interrupt frequency is the one to watch

The once-per-minute enemy missile **is the interrupt** — POC scope item 10, build
step 8. The scope doc is emphatic about it:

> `interrupt_interval_seconds` **starts at 0 (disabled).** Turn it on only at step
> 8, and **expect the good value to be much larger than intuition suggests.** This
> parameter is the single easiest way to turn a relaxed game into a stressful one;
> it is a spike, not a background condition.

With a 10 s missile cooldown and a ~6 s ride, once per minute puts an interrupt on
roughly every sixth action. That may be exactly right for a *test* — an interrupt
you never see cannot be evaluated — but it is far denser than the design predicts
will survive. **Build it at 60 s, expect to raise it.**

Two hard rules from `PROJECT_OVERVIEW.md` Pillar 2 that the implementation must
honour whatever the interval says:

1. The warning is **loud, telegraphed, unambiguous.** The spec says "a small
   alert". If it is small enough to miss, the interrupt stops being a punctual
   spike and becomes ambient dread — which is the precise failure the
   target-experience guard in `CLAUDE.md` exists to prevent. Build the alert
   prominent and let the human tune it *down*; the tuning file carries its size,
   colour and lead time.
2. **It must be possible to win both.** A player close enough and fast enough
   detonates on target *and* makes the turret in time. The interrupt is an
   opportunity to show off, not a tax for being in the missile. This constrains
   `interrupt_warning_lead_seconds` against missile flight time — the lead must
   exceed a typical remaining ride.

### 2. Three build-order steps are landing at once

Step 6 (turret + cooldown) carries the **criterion-2 feel checkpoint**; step 7
(blockers, enemy fire, ship HP) carries the **criterion-3 checkpoint**; step 8 is
the interrupt. The scope doc says not to pull them forward because "adding one
early destroys the reading on the one before it."

**Mitigation, and it is a requirement of this build:** every layer must be
independently disableable from `tuning.cfg`, so a clean reading is still
obtainable without a code change.

- `enemy/interrupt_interval_seconds = 0` → no incoming missiles at all
- `enemy/blocker_chance = 0` → no enemy countermeasures
- `turret/loadout_*` → a loadout can be set to `"none"`
- `ship/invulnerable = true` → hits register and are counted, but never hurt

That gives back step 6 in isolation (turret + cooldown only), then step 7, then
step 8, by editing three values while the game runs.

### 3. The player is invincible for this build — deliberately

Human direction, 2026-08-27:

> "For the first version of testing I'm not worried about my ship getting hurt by
> missiles, I just need to test the pacing, so it makes more sense to be invincible
> while I test. Yes eventually they will deal damage."

This is the right call and it sharpens the reading. The question step 8 asks is
*"does being pulled to the turret disrupt the rhythm?"* — and that is answerable
without a consequence for failing. Adding damage now would mix a **pacing** signal
with a **difficulty** signal and neither could be read cleanly.

**But a hit must still be legible**, or a failed intercept is indistinguishable
from one that never arrived and there is nothing to pace against. So:

- `ship/invulnerable = true` — the default for this build. HP never drops.
- The ship still **has** an HP number and still **registers** hits: the HUD counts
  hits taken, and an impact produces a flash. Feedback without consequence.
- Turning damage on later is then a single tuning flip, not a build. The plumbing
  is proven by the pacing test itself.

There is still **no death and no respawn** — that is step 9 regardless.

### 4. Ambiguities resolved, flagged for correction

| Spec | Reading taken | Change cost |
|---|---|---|
| "10 ammo before reset" | A magazine of 10 that refills over `turret/unguided_reload_seconds`. `0` = never refills in a session. | tuning |
| Which weapon on which button | L1 = autocannon (LMB) + pulse beam (RMB); L2 = unguided missile (LMB) + blockers (RMB) | tuning |
| "twice current missile radius" | Twice `missile/flash_end_radius`, given as its own tuned key rather than a derived one | tuning |
| Turret aim feel | Mouse aims **1:1, no lag** — a hitscan weapon whose aim lags is a control that lies. Gamepad stick sweeps at `turret/traverse_deg_per_sec`. | tuning |

### 5. Two invariants this build must not break

- **Speed hierarchy is structural** (`CLAUDE.md`): *lasers > missiles > ships*.
  The pulse beam is hitscan, so it satisfies "lasers" trivially. But **autocannon
  rounds and unguided missiles are projectiles and must be clamped faster than
  `missile/base_speed`**, in code, the same way `Mothership.manual_max_speed()`
  is clamped. A tuning value that inverts the hierarchy must do nothing.
- **Splash is steeply worse than a direct hit** (ADR 0004). The unguided missile's
  blast is the first splash mechanic in the game — it is also the last outstanding
  piece of POC step 5. Build the damage falloff once and let both use it.

### 6. Target-experience check on the enemy blockers

Enemy countermeasures at 50% *pass* the pressure rule. The player chose to fire,
the counter is a visible response to their own action, the missile is expendable,
and nothing is imposed on them while they are doing something else. This is
recorded so a later session does not mistake it for the thing the guard forbids.

---

## Architecture

### Damage model — the one existing thing that changes

Components currently take a count of *hits* (`enemy/component_hits_to_destroy`).
Four weapons with different damage make that untenable. Convert to a **damage
pool**: each component has hit points, each weapon has a damage number, and the
existing darken-then-destroy feedback keys off the fraction remaining. ADR 0042's
behaviour is preserved; only the currency changes.

### What can be shot

Turret weapons resolve against, nearest-first along the swept segment:

- the target ship's parts and components (`TargetShip.hit_test`, already exists)
- enemy missiles in flight
- flares, of either side
- rocks (`ReferenceField.hit_test`, already exists)

Use **Godot groups** (`enemy_missile`, `player_missile`, `flare`) for the
shootable sets rather than hand-maintained registries — nodes free themselves and
bookkeeping would rot.

**Everything stays swept-segment against analytic shapes.** ADR 0032's mechanism
rule is untouched: no physics body, no `Area3D`, no `CollisionShape3D`. The
hitscan beam is the same test with a very long segment.

### New files

| File | Responsibility |
|---|---|
| `scripts/view/turret.gd` | The station: aim basis, loadout state, per-weapon cooldown / heat / magazine, firing |
| `scripts/weapons/projectile.gd` | Autocannon rounds and unguided missiles — travels, swept hit test, optional manual detonate + blast |
| `scripts/weapons/flare.gd` | Blocker flares, both sides. Slow, short-lived, kills a missile on contact |
| `scripts/weapons/enemy_missile.gd` | Guided with tunable inaccuracy, shootable, damages ship HP |
| `scripts/effects/beam_flash.gd` | The pulse beam's tracer — a visual, no gameplay |
| `scripts/lib/damage.gd` | Splash falloff, shared by the ridden missile and the unguided one (ADR 0004) |

### Modified

| File | Change |
|---|---|
| `scripts/view/view_controller.gd` | `TURRET` as a third view, its camera, mouse capture |
| `scripts/arena/combat_arena.gd` | Wiring, missile cooldown, enemy behaviour timers, HUD rows, alert |
| `scripts/view/flight_overlay.gd` | Turret crosshair, incoming-missile alert, heat / ammo readouts |
| `scripts/ships/target_ship.gd` | Deploys blockers on missile approach; damage pool instead of hit count |
| `scripts/weapons/missile.gd` | Dies to flares |
| `data/input_map.json` | `turret_mode`, `fire_primary`, `fire_secondary`, `loadout_1`, `loadout_2` |
| `tuning.cfg` | New `[turret]` section; `[enemy]` gains blockers and the interrupt; `[ship]` gains `hp` and `invulnerable` |
| `tools/tests/test_runner.gd` | Required keys and actions, plus the behavioural tests below |

### Build stages — each ends with `make check` green

1. **Turret view.** `G`, the camera, aim, loadout switching, HUD rows. No weapons.
2. **Autocannon and pulse beam.** Projectile and hitscan paths, the damage pool,
   the speed-hierarchy clamp.
3. **Unguided missile and blast.** Manual detonate, splash falloff (ADR 0004),
   which also closes POC step 5.
4. **Flares.** Player blockers, enemy blockers at 50% on approach, missiles dying
   to them. Closes the blocker half of step 7.
5. **The missile cooldown.** 10 s. This is what makes step 6's checkpoint
   answerable at all.
6. **The interrupt.** Enemy guided missile, imperfect accuracy, the alert, the
   hit counter, turret intercept. Steps 7 and 8. Invulnerable by default.
7. **Docs.** ADRs, `STATUS.md`, `make shot` frames.

### Tests worth having

Behavioural, driven through real `Input` actions headlessly — the pattern
`_test_manual_flight` already uses:

- Loadout switching maps the right weapon to the right button.
- The autocannon respects its fire rate; the beam's heat builds and locks out.
- A projectile is clamped faster than `missile/base_speed`, even when its own
  tuning says otherwise.
- The unguided missile's blast damages **several** components at once, and splash
  is worse than a direct hit.
- A flare kills a missile that touches it, and does nothing to one that misses.
- The enemy's blocker chance is honoured over many trials.
- The interrupt fires on its interval, the alert raises, and the incoming missile
  is destroyable by every weapon that should be able to destroy it.
- With `interrupt_interval_seconds = 0`, no missile is ever launched at the player.
- With `ship/invulnerable = true`, a hit on the player is counted and signalled but
  costs no HP; with it false, HP drops. The pacing build ships with it true.

---

## What this build still does not include

In build order, and still deliberately absent:

- **Step 9** — target ship death and respawn, the picture-in-picture camera
  toggle, and the 30-minute verdict session against all three criteria.
- Ship destruction, and in this build ship *damage* at all — `ship/invulnerable`
  defaults true. Hits are counted and shown; they cost nothing.
- Crew, stations, ladders, interiors — Pillar 6 territory, not the POC.
- Anything from `ROADMAP.md` beyond the combat bet.
