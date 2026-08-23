# Combat POC — Implementation Doc

*Version 3. Supersedes v2. Scope and success criteria are unchanged. What changed: the coordinate guidance, which v2 got wrong in a way that would have hardened into an obstacle; new architectural invariants from the exploration design; and additions to the ADR seed list.*

## Purpose

Prove or kill the core bet: **the alternation between riding a fuse-limited missile and working a turret is fun enough to carry an entire combat system.**

v1 scoped this to the missile alone. That was testing the half that was never in doubt — Descent and Battlefield already established that flying a munition on a chase cam is delightful in isolation. The open question is whether it sustains as a *loop*: what the player does between missiles, and whether missile #300 differs from missile #5. A missile-only POC returns a verdict on a minigame, not on a game.

### Success criteria

All three must pass. The first is the original criterion, retained because it's still necessary:

1. **The 8 seconds.** The developer grins during missile flight, in gray-box, with no art, no sound polish, no progression.
2. **The loop.** After 30 minutes of continuous play, the developer is still *choosing* to fire, and never feels stuck waiting with nothing to do. Turret time reads as its own activity, not as a pause.
3. **The ceiling.** There is a felt difference between an early missile and a late one — the flight has enough depth that skill visibly accumulates. This is the hour-thirty boredom test run early and cheap.

If 1 passes and 2 or 3 fail, the problem is fixable and the next step is tuning, not stopping. If 1 fails after honest tuning effort, stop and rethink before building anything else.

### What this POC does not test

Manual ship flight, exploration and cruise feel, progression cadence, the overworld, and whether hired crew is satisfying. Absence of these from the POC is a **scope deferral, not a design decision** — see Scope Notes below.

## Scope

### In scope (and nothing else)

1. A gray-box arena: player mothership, one dumb enemy target ship, empty space, minimal reference geometry (a few asteroids/grid so speed is legible).
2. Mothership autopilot with ONE behavior: fly a slow arc relative to a commanded target (close / hold standoff).
3. Fire missile: launches along the ship's current heading. Camera cuts to close-behind third-person missile cam.
4. Missile flight: mouse/stick steering (direct screen-space mapping, NOT vector thrust), boost/afterburner on a button, fuse timer that detonates the missile at expiry.
5. Early-detonate button with an explosion radius; splash does partial damage, steeply worse than direct hit.
6. **Turret mode:** switch to a fixed turret station. Aim-and-track, fire at the enemy ship and at incoming objects. No ladder, no ship interior, no walking — the switch is instant and diegetically unexplained for now.
7. **Missile cooldown**, spent in turret mode. This is the alternation under test.
8. Enemy releases 3–6 slow-moving blocker/shrapnel objects toward incoming missiles; collision destroys the missile. Turret can shoot blockers down.
9. **Enemy fires at the player ship**, and the turret can intercept. Ship has an HP number. This exists to make turret time *matter*, not to create ambient dread — see the interrupt rules in `DESIGN.md`.
10. **The interrupt:** a loud, telegraphed incoming-missile warning while the player is riding, resolvable by returning to the turret. Frequency is a tuning parameter starting at zero and raised deliberately.
11. Hit feedback: target takes damage, dies after N hits, respawns. Camera returns to ship view after detonation/miss.
12. Ammo capacity, defaulting to effectively unlimited, present so it can be tested independently of cooldown.
13. Hot-reloadable tuning file driving every feel parameter.
14. Debug HUD: missile speed, fuse remaining, distance to target, cooldown remaining, ammo, ship HP.

### Explicitly out of scope

Manual ship flight, cruise mode, fuel, planets, landing, system boundaries, the disc volume, inter-system travel, upgrades, factions, economy, crew/NPCs, ship builder, ship interior or walkability, multiple enemies, enemy AI beyond "drift slowly + emit blockers + shoot + occasionally launch", menus, save/load, sound design, any art beyond primitive meshes, multiplayer, the overworld.

### Scope Note — manual ship flight

**Manual flight exists in the design, and is now more central than it was.** The player flies the mothership in first or close third person for exploration, for positioning before a fight, and for the entirety of travel — there is no travel mode, so manual flight is the exploration verb. Autopilot is a delegation the player elects; at the travel scale it is a heading hold and nothing more.

It is absent from this POC only because the POC tests the combat alternation and manual flight is not part of that alternation.

This note exists because v1 of this document said "no manual ship flight controls" without qualification, which reads as a design commitment. It is not one. Do not write an ADR asserting that the ship is autopilot-only, and do not let this omission harden into a decision.

### Scope Note — exploration

Exploration is a separate bet with its own prototype (see `PROJECT_OVERVIEW.md`, Sequencing). Cruise feel, the travel gauntlet, and whether an off-route contact is worth diverting for are feel questions this POC cannot answer and should not attempt.

What exploration *does* impose on this POC is two architectural invariants, below. Those are not optional and not deferrable, because retrofitting either is expensive.

## Architecture

- **Engine:** Godot 4.x (pin exact minor version in `CLAUDE.md`), GDScript.
- **Everything constructed in code from data.** The editor is a viewer, not an authoring tool. Scenes are minimal shells; entities are spawned programmatically. `.tscn` files stay small, text-diffable, and model-authorable.
- **Tuning file:** a single `tuning.json` (or `.tres` text resource) at repo root, watched at runtime, hot-reloaded on change. Every feel parameter reads from it every frame or on reload — no feel constants in code, ever.
- **State machine for camera/control mode:** `SHIP_VIEW ↔ TURRET_VIEW`, and `→ MISSILE_VIEW → (detonate | fuse-expire | blocker-hit | abandon) → previous view`. Keep transitions instant first; add transition polish only if the core is fun.
- **Camera transition — test both.** Hard cut is the default. Also implement Descent's option: missile view as a picture-in-picture inset with the ship view retained. The hard cut costs situational awareness on every round trip ("where is the enemy now?"), and PiP may be the answer. Make it a tuning toggle so both can be felt back to back.
- **Projectile speed regime:** ships never approach missile speeds by construction (speed hierarchy: lasers > missiles > ships). Velocity-inheritance fraction for missile launch is a tuning parameter (start at 0.0, arcade-style).

### Coordinates — corrected from v2

v2 said the arena is origin-local, single-precision is fine, and *"do not build anything here that assumes a to-scale coordinate space."* The first two are still true for the POC. The third was aimed at the right hazard and stated in a way that is now misleading, because the exploration design does put the ship in a large to-scale space.

The current position:

- **A system is a disc-shaped arena and combat is origin-local within it.** Nothing in the POC needs large coordinates, and single-precision Godot is fine at this scale.
- **The world uses a floating origin.** Travel is continuous across systems, so real play involves large coordinates, and single-precision floats degrade visibly in the tens-of-kilometers range — jitter in physics, camera, and particles. It will surface first as missile flight feeling subtly wrong far from origin, which is the hardest possible place to diagnose it. The world recenters on the player periodically and everything else shifts.
- **Therefore: no system may assume a fixed world origin, or cache a world position across frames without accounting for recentering.** The POC does not have to *implement* the shift, but nothing built here may make it harder to add. This is the practical content of the old warning.

### Distant-object LOD and collision

Planets and stations render as background-layer objects that scale with distance and swap to real meshes on approach.

- The swap must occur where apparent size change is sub-pixel — a second camera at compressed scale, with the real mesh spawning at a distance where the two agree.
- **Only the real object has collision.** The background layer is visual only: no physics body, no missile interaction, nothing queryable.

This is out of scope to build for the POC and in scope to not violate. Raycasting against something that is currently a billboard produces bugs that look like physics problems, and it is a natural mistake for a fresh session to make.

## Tuning File — Initial Parameter Set

```json
{
  "missile": {
    "base_speed": 0, "boost_multiplier": 0, "boost_duration": 0,
    "turn_rate_deg_per_sec": 0, "fuse_seconds": 0,
    "velocity_inheritance": 0.0,
    "detonate_radius": 0, "splash_damage_fraction": 0.25,
    "direct_hit_damage": 0,
    "cooldown_seconds": 20, "ammo_capacity": 999
  },
  "turret": {
    "traverse_deg_per_sec": 0, "projectile_speed": 0,
    "damage": 0, "fire_rate": 0, "blocker_deploy_count": 0
  },
  "camera": {
    "follow_distance": 0, "follow_lag": 0, "fov_base": 0,
    "fov_boost_kick": 0, "shake_on_detonate": 0,
    "missile_view_mode": "cut"
  },
  "ship": { "arc_speed": 0, "standoff_distance": 0, "hp": 0 },
  "enemy": {
    "drift_speed": 0, "blocker_count": 0, "blocker_speed": 0, "hp": 0,
    "fire_rate": 0, "damage": 0,
    "interrupt_interval_seconds": 0, "interrupt_warning_lead_seconds": 0,
    "interrupt_missile_speed": 0
  },
  "controls": { "stick_sensitivity": 0, "mouse_sensitivity": 0, "deadzone": 0 }
}
```

Fill values during tuning sessions with controller in hand. The AI's job is to make changing any of these take zero seconds to test. Feel verdicts are human-only.

**`interrupt_interval_seconds` starts at 0 (disabled).** Turn it on only at step 8, and expect the good value to be much larger than intuition suggests. This parameter is the single easiest way to turn a relaxed game into a stressful one; it is a spike, not a background condition.

**`cooldown_seconds` and `ammo_capacity` are independent levers.** Cooldown governs the moment-to-moment rhythm. Ammo governs endurance across a long expedition and defaults to effectively unlimited here so cooldown can be evaluated alone. Test cooldown-only, ammo-only, and both.

**One note for later:** the eventual `ship.max_engagement_envelope` — the largest distance a fight sprawls across — is the first link in the exploration numbers chain (envelope → disc height → cruise speeds → system diameter). Record what the envelope actually turns out to be during tuning sessions. It is free to observe now and expensive to guess at later.

## Build Order

1. **Repo scaffold + AI guidance files** (below) before any game code.
2. Tuning-file loader with hot reload + debug HUD. *This comes before gameplay* — it is the instrument everything else is played through.
3. Arena, mothership autopilot arc, static target.
4. Missile launch + missile cam + steering + fuse. **First feel checkpoint** (success criterion 1).
5. Boost, early detonate, splash.
6. **Turret mode + missile cooldown.** The alternation is now testable. **Second feel checkpoint** (success criterion 2) — is turret time an activity or a wait?
7. Blockers, enemy fire, ship HP. Turret work now has stakes. **Third feel checkpoint** — does turret time feel consequential without feeling like a chore?
8. The interrupt, starting disabled and raised carefully.
9. Hit/death/respawn loop, camera returns, PiP toggle. **Verdict session:** 30+ minutes of continuous play against all three success criteria.

Expected scale: still weekend-class with Claude Code doing the lifting, though turret mode adds meaningfully to step 6.

## AI Guidance Files (create at repo root before coding)

### `CLAUDE.md` (or `AGENTS.md`) — static, rarely changes

Must contain:

- **Version pins:** "Godot 4.x.y, GDScript. Never emit Godot 3.x APIs. When unsure whether an API is 3.x or 4.x, check the pinned class reference before writing code." (Models trained on years of Godot 3 tutorials will confidently emit deprecated calls — this is the known failure mode.) Back this with a headless smoke test that fails loudly on deprecated API usage, so it is caught by the machine rather than by a human reading diffs.
- **Feel-parameter law:** "No gameplay-feel constant may appear in code. All feel values load from `tuning.json`. If you need a new feel parameter, add it to the tuning file and the debug HUD in the same change."
- **Code-first scene policy:** "Construct entities programmatically. Do not add authoritative state through editor-only manipulation. `.tscn` diffs must remain human-reviewable."
- **Scope guard:** "The POC scope is defined in COMBAT_POC_IMPLEMENTATION.md. Do not implement out-of-scope features even if they seem adjacent or easy. Flag scope questions instead of resolving them. Note that some omissions are scope deferrals rather than design decisions and are marked as such — do not convert them into ADRs."
- **Target-experience guard:** "This game targets relaxed mastery, not tension. The rule is that pressure must be a decision the player made, not a condition imposed on them: it must be chosen, visible before commitment, and reversible. Do not introduce ambient dread, unattended degradation, or mechanics demanding attention on two things at once, even where they appear to be good design in isolation. Flag any proposal that adds background threat. Note that resource costs the player plans around (fuel, cargo mass, ammo) are *not* covered by this prohibition — they pass the rule."
- **Floating-origin invariant:** "The world recenters on the player. No system may assume a fixed world origin or cache a world-space position across frames without accounting for the shift. Prefer relative positions. This applies even inside the origin-local combat arena, where the shift is not yet implemented."
- **LOD/collision invariant:** "Distant planets and stations are background-layer visuals with no physics body and nothing queryable. Only the swapped-in real mesh has collision. Never raycast, overlap-test, or query a distant object."
- **No-interdiction invariant:** "Cruise is dropped by player input alone. Never by an NPC's decision, and never by taking damage. Damage degrades top cruise speed instead. If a proposal would stop the player's ship because of something an NPC did, flag it — this is the genre default and it is deliberately rejected here."
- **Autopilot definition:** "Autopilot is a heading hold. It points the nose at a designated object; the player owns the throttle. It does not path, avoid, arrive, or make decisions. Do not grow it."
- **Testing convention:** headless-runnable logic where possible (`godot --headless`); physics/feel verified by the human, systems verified by tests.
- **Project conventions:** file layout, naming, one-class-per-file, where autoloads live.

### `DESIGN.md` — living

The distilled design thesis (source: `PROJECT_OVERVIEW.md`) so any session has the "why" without re-litigating it. **Must include the Target Experience section verbatim** — that section is the one most likely to erode silently across sessions, because pressure mechanics look like good design when evaluated one at a time.

Include the pass/fail examples under the pressure rule. The rule is not usable as an abstraction alone; what makes it operable is the contrast between fuel (chosen, visible, reversible → passes) and interdiction (imposed, unavoidable, resolved on someone else's terms → fails).

### `decisions/` (ADRs) — append-only

One short ADR per irreversible or surprising decision, with reasoning and date. Seed with:

**Combat**
- Taxi/missile split — with the correction that manual flight exists and autopilot is elective
- Fuse-as-range, and its role as the player-facing difficulty dial
- Direct screen-space steering over vector thrust
- Splash steeply worse than direct hits
- Velocity-inheritance as a tunable
- Cooldown governs rhythm, ammo governs endurance; tuned independently
- NPC competence ceiling: crew can gun, crew cannot ride missiles
- Pressure is sequential, never parallel

**World and travel** *(new in v3)*
- **No hyperspace or jump mode; one continuous space at three throttle scales** — the organizing decision of the exploration layer
- **Continuous engine speed contested by mass, rather than tiered drive tech** — a mass/speed tradeoff generates a decision every trip; a tech gate generates one decision ever. Distance gates regions softly (time, fuel, zero standing on arrival) rather than by unlock
- **Systems are discs: hard flat faces, open rim** — the rim is departure, not a wall; bounds are player-only, with ramping damage and an outbound velocity clamp that scales magnitude only
- **Approach envelope with abortable landing sequence, never auto-steer** — the ship's heading is never taken from the player
- **Autopilot is a heading hold; delegation forfeits discovery, never safety**
- **No interdiction — and cruise does not drop on damage either** — damage degrades top cruise speed; "drops on damage" is interdiction with an extra step
- **Proximity inhibition is admissible where interdiction is not** — the drive won't spool near a hostile. Consider these two together: they look identical from outside and were separated deliberately. The distinction is a law of the world versus an agent's decision
- **Threat sits on value, not on coordinates** — enemies occupy what the war is about, which produces the danger gradient and makes invasions witnessed by default
- **Fuel is a route budget traded against cargo space; stranding is recoverable, never a softlock**
- **Difficulty banded by faction, not coordinates** — the bands move with the war

**Framing corrections** *(new in v3)*
- **Overworld lineage is Escape Velocity, not Mount & Blade** — the starmap is a planning UI; M&B's map model exists to make army logistics a decision and does not transfer to a 2–5 ship game. Recorded because the wrong framing was in v1–v2 of the overview and actively misdirected design work
- **Target Experience pressure rule narrowed** — "no resource anxiety" was too broad and forbade good systems; replaced with chosen/visible/reversible
- **Combat arenas are origin-local; the world uses a floating origin** — supersedes the v2 phrasing about to-scale coordinate spaces
- **Travel carries the campaign clock** — the war advances in real time while the player flies, which is why there is no abstracted jump duration

**Engine and process**
- Godot over Unity (text-legibility rationale)
- Target audience is sim/sandbox, not action; default tuning biases toward power fantasy
- Difficulty is player-selected through mechanics, never a menu; the cautious path stays viable

### `STATUS.md` — living

Current build state, what works, what's next, open feel questions. Updated at the end of every working session so parallel chat sessions (exploration, overworld design) and future Claude Code sessions resume without context reconstruction.

## Division of Labor

| AI (Claude Code) | Human |
|---|---|
| All systems code, state machines, autopilot math | Every feel verdict |
| Tuning infrastructure, hot reload, debug HUD | Turning the knobs, controller in hand |
| Headless test harnesses | The grin test and the loop test |
| Keeping STATUS.md/ADRs current from session notes | Scope discipline, kill/continue decision |
| Surfacing failure modes others have hit, and why | Creative direction |

When directing feel work, give the AI *reference anchors*, not adjectives: "turn response like Star Fox's Arwing, not a Newtonian thruster" outperforms "make it snappier."
