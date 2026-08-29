# Exploration POC — Implementation Doc

*Version 1. Companion to `EXPLORATION_DESIGN.md` and `COMBAT_POC_IMPLEMENTATION.md`.*

*Read `EXPLORATION_DESIGN.md` first. This document assumes its locked decisions and does not restate their reasoning.*

---

## Amendments since v1

Settled with the human during planning on 2026-08-29, before implementation began.
Where this section and the body below disagree, this section wins.

- **The lane is a third the size v1 specified.** 150 x 100 m, not 900 x 420 — three
  hulls across, like a three-lane highway. Started deliberately small: scaling a
  road up when it feels crowded is easy, and a road that never feels like a road
  teaches nothing. `deck_separation` follows to 200 m.
- **The portal is the on-ramp mouth and is NARROWER than the road it feeds**, like a
  freeway ramp: 100 x 50 m, split from v1's single square `portal_size`. The lane
  flares from the aperture to full cross-section over `portal_flare_length`. The
  invariant that matters is the opposite of the one first proposed — not
  *portal > lane*, but *aperture clears the hull with margin*.
- **Portal access is decided by the player's hull class, not a debug flag.** A
  fighter has no cruise drive and therefore sees every portal red; a taxi sees blue
  (ADR 0060). The colour is the whole of the answer and is visible before
  commitment. Faction gating still out of scope, and lands on the same channel.
- **Ship switching moves ahead of docking**, to step 3. The human needs to feel taxi
  against fighter to judge whether 15.5 m/s is right, and that is the anchor for
  every number downstream — it should not wait behind a docking screen. A debug
  hull-cycle key (`H`) landed in the *combat* arena in step 1, so the question is
  answerable in the scene that already exists.
- **The space around the road outside a system is bounded**, at half a system
  diameter (`corridor_diameter`, 1750 m). The road runs down the middle of it, so
  off-road travel between systems has somewhere real to be and the lane still reads
  as open.
- **`open_traffic_per_100km3` rises from 1.5 to 20.** v1's figure was written
  against unbounded space; measured against the bounded volume within
  `traffic_despawn_distance` it yields 0.2 ships, i.e. empty, and success criterion
  2 would fail for an arithmetic reason. At 20 it is ~2 ships in a system against
  ~10 on the road within the same distance.
- **`system_height` added** (1200 m). ADR 0011's disc needs one and v1 had none.
  Flagged: `PROJECT_OVERVIEW`'s numbers chain sizes disc height at 5–10x the
  engagement envelope, and **the envelope is still unmeasured** — the diameter was
  handed down rather than derived, so the chain is resolved from the wrong end.
- **Leg lengths are portal to portal**, so centre-to-centre is the leg plus one
  system radius at each end.
- **ADR 0011's boundary treatment does not exist yet.** v1's step 2 says "existing
  boundary treatment"; there is none. The disc's hard faces, the red volume, the
  telegraphed timer and the magnitude-only outbound clamp are all new work in
  step 2.
- **`tuning.cfg` is the source of truth for every number below.** The block in
  §Starting Tuning Values is v1's proposal, kept for its reasoning; read the values
  from the file.

---

## Purpose

The combat POC returned a verdict on the combat bet. This one tests a different and less binary question: **do the pieces of the travel layer interact well enough to be worth building out?**

Specifically — does the highway feel like driving rather than waiting, does off-road travel survive as a real choice, does fuel produce planning rather than annoyance, and does the world read as populated without reading as busy?

This is not a fun-or-kill test the way the combat POC was. It is an interaction test. Several systems that were designed in isolation meet here for the first time, and the failure mode this catches is *they are individually fine and collectively wrong*.

### Success criteria

1. **The road is driving.** After ten continuous minutes on a trunk highway, the player's hands are still busy. Curvature, lane position, and traffic supply steering demand. If the road reads as a conveyor, either the turn clamp is too tight or the road geometry is too straight — tune before concluding.
2. **Off-road survives.** The player elects to fly at least one leg off-highway for a reason other than testing it, and does not regret the choice. If open space is only ever a punishment, the speed ratios or the fuel cost are wrong.
3. **Fuel is a plan.** The player checks the gauge before committing to a route. Running dry produces a story, not a reload.
4. **The tiers read.** A local hop and a trunk run feel like different activities without being told they are.

If 1 fails, the problem is road geometry or the camera clamp and is fixable. If 2 fails, the ratio between highway cruise and normal flight is wrong. If 3 fails, either fuel is too generous to notice or too tight to plan around. **None of these are kill conditions for the design** — they are calibration failures. The kill condition would be discovering that the road and the open space cannot coexist at any tuning, which is the specific thing this POC exists to rule out.

### What this POC does not test

Faction ownership of portals, reputation gating, the economy, missions, combat (which is already validated separately), the ship builder, crew hiring, persisted NPC identity, deep-space portals, or portals under construction. Their absence is **scope deferral, not design decision** — the same rule as `COMBAT_POC_IMPLEMENTATION.md`.

---

## Scope

### The test map

**Three systems in a line.** Not a network — a line is enough to test everything here and keeps authoring cheap.

```
   [ A ]────local────[ B ]────────────trunk────────────[ C ]
    4 km leg              40 km leg
```

- **A → B is a local leg**, ~4 km, ~41 s at cruise.
- **B → C is a trunk leg**, ~40 km, ~6.9 min at cruise.
- Each system is a disc **3–4 km in diameter** with the existing ceiling/floor treatment.
- Each system has **one planet** with a docking envelope.
- Each system has **portals at both ends** where a road connects, stacked upper/lower per the deck convention.
- Roads must **curve** — at minimum the trunk leg needs sustained curvature and at least one elevation change. A straight trunk road cannot test success criterion 1.
- The **northwest–southeast divider** is not exercised by a straight line. Author the trunk leg with enough curvature to make the deck convention visible, but do not cross the divider. The twist mechanic is out of scope for this POC.

### In scope

1. **System discs** — three, per above, with existing boundary treatment. Empty except for a planet and reference geometry.
2. **Planet docking** — approach envelope with an abortable landing sequence, no auto-steer, per the locked decision. Docking gives a screen with: refuel cruise tank, refill missile magazine, and depart. Nothing else.
3. **Highway tube** — rounded-lozenge cross-section, wide and flat. Soft lane boundary that slows and pushes back. Visually open — the system and surrounding space are visible from inside.
4. **Portals** — large square structures, unmissable, shimmering material carrying the destination system name. Two stacked per site, one per direction, visibly distinguishable. **Entry is instant on contact.** No alignment sequence, no docking animation, no confirmation prompt.
5. **Cruise drive** — engages automatically on portal entry, disengages on exit. Works nowhere else. Consumes cruise fuel.
6. **Cruise camera and control** — camera fixed to road heading, player steering clamped to a maximum angle off the road axis. Throttle is still the player's.
7. **Cruise fuel** — a tracked resource with a gauge. Empty means cruise cannot engage; normal flight is unaffected and free.
8. **Normal flight** — the existing manual flight model, usable everywhere including the full 40 km between B and C.
9. **NPC ship spawning** — two distinct sources:
   - **Road traffic**, same-direction, at varying speeds so overtaking happens. This is the primary source.
   - **Open-space traffic**, sparse but non-zero, so off-road is not empty.
   - All procedural for this POC. No persistence, no identity, no behaviour beyond flying a route.
10. **Player ship switching** — a debug roster of at least three hulls with different speeds and capabilities: a **taxi** (slow, has cruise drive), a **fighter** (fast, no cruise drive, cannot enter portals), and one **capital** (slowest, has cruise drive). Switch instantly from a debug menu. This is not the in-game ship-buying flow; it exists so the interaction of speed class with the road can be felt in one session.
11. **Weapons disabled inside the tube**, enabled everywhere else.
12. **Collisions glance off.** No damage, no destruction.
13. **Debug teleport to nearest system.** Explicitly requested. This exists so fuel limits can be tested without flying every leg. Bind it clearly, log every use, and make it obvious on the HUD that it was used — a silent teleport contaminates a travel-time verdict.
14. **Hot-reloadable tuning**, extending the existing file with an `[exploration]` section.
15. **Debug HUD additions** — current speed, cruise fuel, distance to next portal, ETA at current speed, current hull class, current deck.

### Explicitly out of scope

Faction ownership and access denial, reputation, economy, cargo, missions, comms chatter and distress calls, junctions of any kind, deep-space portals, portals under construction, the deck twist, ring roads, persisted NPCs, convoy behaviour, escorts, fuel vendors, tows, combat encounters, sound, art beyond primitives and the existing carrier mesh.

---

## Starting Tuning Values

New `[exploration]` section. **Every value is a starting position**, and all of them become equipment properties in the real game. Ranges matter more than the numbers.

```ini
[exploration]

;; The speed ladder, all derived from missile/base_speed. See EXPLORATION_DESIGN.md.
;; These are placed here as POC globals ONLY. In the real game each is a property
;; of a hull or of installed equipment. Build them as a table keyed by hull class
;; with a default, not as single values — the refactor later is expensive.
taxi_max_speed = 15.5              ; [5..60] m/s. The "ships are taxis" baseline
fighter_max_speed = 38.7           ; [10..120] m/s. ~missile/base_speed / 1.5
capital_max_speed = 11.0           ; [3..40] m/s. Slower than a taxi, deliberately
cruise_speed = 96.7                ; [30..400] m/s on the highway. ~fighter x 2.5

;; The camera locks to the road while cruising and the player steers within a cone
;; around it. This clamp is the single value that decides whether the highway is a
;; travel mode or a travel cutscene. Too tight and the player is a passenger; too
;; loose and the tube stops reading as a bounded space.
;; Tune this WITH road curvature, never alone — a generous clamp on a straight road
;; still feels like nothing.
cruise_turn_clamp_deg = 18.0       ; [3..60] deg off the road axis the player may steer
cruise_turn_rate_deg_per_sec = 22.0 ; [5..90] deg/s toward the requested heading

;; The lane. Wide and flat, matching monitor aspect and the locked-roll controls.
;; The boundary is soft: crossing it slows you and pushes you back. It is an
;; incentive, never a wall. If the player can be stopped by it, it is wrong.
lane_width = 900.0                 ; [100..4000] m across
lane_height = 420.0                ; [50..2000] m top to bottom. Keep well under width
lane_edge_softness = 60.0          ; [5..400] m of gradient before the push is at full
lane_edge_speed_penalty = 0.45     ; [0.1..0.95] multiplies cruise_speed fully outside
lane_edge_push_accel = 8.0         ; [0..60] m/s^2 back toward the lane centre
deck_separation = 700.0            ; [100..3000] m between the two decks' centres

;; Portals. Entry is on contact and instant, by decision. At a 41-second local leg,
;; ten seconds of entry ceremony is a quarter of the trip. If any sequence creeps in
;; here, the local network becomes a chain of loading screens.
portal_size = 600.0                ; [100..2000] m across the square opening
portal_entry_seconds = 0.0         ; [0..3] KEEP AT ZERO unless testing the cost of delay

;; Cruise fuel. Consumption is per METRE, not per second, so speed upgrades do not
;; secretly change range. Capacity is generous for this POC — the question is whether
;; the gauge gets checked at all, which needs it to be plausibly reachable.
;; With these values a full tank runs ~120 km, which is three trunk legs.
cruise_fuel_capacity = 100.0       ; [10..1000] units
cruise_fuel_per_km = 0.83          ; [0.05..20] units burned per km of highway
cruise_fuel_start_fraction = 1.0   ; [0..1] tank level on spawn

;; NPC traffic. Density is the main dial for "populated but not busy". Road traffic
;; is the primary source; open-space traffic exists so off-road is not empty, and
;; should be sparse enough that the contrast is felt.
;; Speed spread is what produces overtaking, which is the road's core social event.
road_traffic_per_km = 0.6          ; [0..8] ships per km of road, same direction
road_traffic_speed_spread = 0.35   ; [0..0.8] +/- fraction of cruise_speed across traffic
open_traffic_per_100km3 = 1.5      ; [0..30] ships per 100 cubic km of open space
traffic_despawn_distance = 8000.0  ; [500..40000] m before a spawned ship is recycled

;; The test map.
system_diameter = 3500.0           ; [500..20000] m
local_leg_length = 4000.0          ; [500..30000] m, A to B
trunk_leg_length = 40000.0         ; [5000..300000] m, B to C

;; Debug teleport. It exists so fuel can be tested without flying every leg. It must
;; be LOUD on the HUD when used — a silent teleport contaminates a travel-time verdict.
debug_teleport_enabled = true      ; false in any session judging travel feel
```

---

## Build Order

Each numbered step should leave the build in a playable state.

1. **Tuning section and debug HUD extension.** Before anything else, as with the combat POC. The instrument comes before what it measures.
2. **One system disc with a planet.** Existing manual flight, existing boundary treatment. Nothing new to fly.
3. **Ship switching roster.** Taxi, fighter, capital. Debug key only. Fly each around one system and feel the class differences at the corrected speeds. **First checkpoint** — is 15.5 m/s the right taxi speed, or does it need adjusting up or down? This is the anchor for everything downstream and is best settled before roads exist, which is why it moved ahead of docking. *The key itself landed in step 1, in the combat arena.*
4. **Planet docking.** Approach envelope, abortable sequence, refuel and rearm screen. **Second checkpoint** — does approach feel like arriving somewhere, or like a menu with a runway? The envelope is built once and reused: the portal stations in step 6 get the same mechanism, since that is where the fuel, market and customs content actually lives.
5. **Second system and the local leg, off-road only.** No highway yet. Fly A to B manually at each hull speed. This establishes the baseline the highway must beat and is the control condition for success criterion 2.
6. **Portals and the highway tube, local leg only.** Cruise drive, camera clamp, lane boundary, deck geometry. **Third checkpoint** — is a 41-second hop worth the portal at all, or does it feel like ceremony around nothing?
7. **Cruise fuel and the debug teleport.** Fuel gauge, consumption, empty behaviour. Teleport bound and logged.
8. **Third system and the trunk leg.** Curvature, elevation change, sustained road. **Fourth checkpoint and the important one** — success criterion 1. Ten minutes on the trunk road. Tune `cruise_turn_clamp_deg` against road curvature here, together, never separately.
9. **NPC traffic, road first.** Same-direction, speed spread, overtaking. **Fifth checkpoint** — does traffic make the road feel populated, and at what density does it tip into busy?
10. **Open-space traffic.** Sparse. Fly a leg off-road with traffic present and compare against step 5's memory of it empty.
11. **Verdict session.** Thirty minutes minimum, moving freely between all three systems, switching hulls, choosing routes. All four success criteria.

Expected scale: larger than the combat POC. Steps 3, 6, and 8 are the substantial ones.

---

## Notes for the Implementation Agent

- **The clamp and the curvature are one tuning problem.** `cruise_turn_clamp_deg` cannot be evaluated on a straight road. If step 8 arrives with a straight trunk leg, the verdict on success criterion 1 will be wrong and will be blamed on the clamp. Build the curvature first.
- **Do not add a docking or alignment sequence to portals.** `portal_entry_seconds` defaults to zero on purpose. If a sequence seems necessary for legibility, flag it rather than adding it.
- **Build every speed as a table keyed by hull class from the start**, with a default. They are POC globals in the tuning file for convenience, but the consumers should already be asking "what class is this ship?" See `EXPLORATION_DESIGN.md`, Enforced Invariants #5.
- **Autopilot arc speed and enemy drift must become fractions of hull maximum**, not absolutes, before the corrected taxi speed lands. See Enforced Invariants #3 and #4. At 15.5 m/s taxi speed the existing absolute values invert the intended relationships.
- **The tube must not become a loading screen.** Floating origin and collision-on-real-meshes-only apply inside the highway exactly as everywhere else. The lane is visually open and the surrounding space is real. See `EXPLORATION_DESIGN.md`, Enforced Invariants #6.
- **Weapons-disabled is a rule of the zone, not NPC behaviour.** Implement it as a property of being in cruise, checked in one place.
- **The deck convention is not exercised by this map**, but the data model should already carry a declared deck per segment rather than computing it from heading. See Enforced Invariants #1.
- **Flag, do not resolve, scope questions.** Several omissions here are deferrals rather than decisions — no faction access control, no comms chatter, no junctions. Do not write ADRs asserting these do not exist.
