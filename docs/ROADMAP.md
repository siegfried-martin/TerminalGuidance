# Roadmap

*Version 1 · 2026-08-27 · written after the combat POC's criterion-1 verdict, to answer "where do I start?"*

The design has many open fronts — cruise, between-system activity, economy,
missions, interactions, art. They look parallel. **They are not.** They are a
dependency chain, and most of it was already decided in `PROJECT_OVERVIEW.md`
§Sequencing and §Open Questions; this document makes the ordering explicit and
says what each stage is waiting on.

Read `DESIGN.md` for intent and `decisions/` for what is already settled. This
file is only about *order*.

---

> **Where the project actually is, 2026-08-29:** exploration POC steps 1–4 built,
> on branch `feat/exploration-tuning-and-hud` (PR #14). Next is the system border,
> then POC step 5. `STATUS.md` §START HERE is the live pointer; this file is the
> ordering argument.
>
> **Superseded in part, 2026-08-29.** Stage 1's combat bet returned *nothing here
> says rethink* and the project has moved to stage 3, the exploration prototype,
> now specified in `docs/EXPLORATION_DESIGN.md` and
> `docs/EXPLORATION_POC_IMPLEMENTATION.md`. Two things this file predicted did not
> happen in the order it gave: **the engagement envelope is still unmeasured**, and
> the exploration POC did not wait for it — `system_diameter` was handed down rather
> than derived, so the numbers chain in `PROJECT_OVERVIEW` §Open Questions 1 is now
> resolved from the wrong end. Stage 4 (the headless faction-war sim) and stage 5
> are unchanged and still downstream.
>
> **New and not on this list:** per-ship / per-faction tuning data. `tuning.cfg` is
> one global set of values, and "different for different factions" makes those
> numbers per-hull data. ADR 0059 landed the mechanism; the rows are the work.

## Where the project actually is

| | State |
|---|---|
| **Criterion 1** — the 8 seconds | ✅ **passed** 2026-08-27. Named cause: brake + boost, i.e. the speed/agility trade is what gives it a ceiling |
| **Criterion 2** — the loop | ⏳ **testable since 2026-08-27**, untested. Turret mode is built |
| **Criterion 3** — the ceiling | ⏳ same |
| `ship.max_engagement_envelope` | ⛔ **still unmeasured** after being deferred three times. Nothing blocks it but a session |

The half that passed is the half `COMBAT_POC_IMPLEMENTATION.md` predicted would
pass: *"a missile-only POC returns a verdict on a minigame, not on a game."*

---

## 1. Finish the combat bet — **now**

`docs/TURRET_MODE_IMPLEMENTATION.md`. Build-order steps 6, 7 and 8, specified
together: turret mode with four weapons, the missile cooldown, blockers on both
sides, enemy fire, and the interrupt.

> **Built on 2026-08-27** (PRs #5–#10). What is left of stage 1 is **playing it**,
> reading criteria 2 and 3, taking the envelope measurement, and then step 9 —
> target death and respawn, the PiP toggle, and the verdict session.

**Why first:** it is the last remaining question that can still return *rethink*.
Every downstream stage is priced off "does the alternation sustain for thirty
minutes", and pricing that on a guess means re-deriving whatever is built on it.

Then step 9 — death, respawn, the PiP camera toggle — and the verdict session
against all three criteria.

## 2. Measure `ship.max_engagement_envelope` — **during step 6**

The largest distance a fight sprawls across. It is an **observation, not a design
act**, and it costs one playtest.

`PROJECT_OVERVIEW.md` §Open Questions 1:

> envelope → disc height (5–10× the envelope) → cruise speeds → system diameter,
> sized in that order; each mostly determines the next. The height:diameter ratio
> is an **output**, not an input.

**Everything in stage 3 is blocked on this number.** Guess it and cruise speeds
and system size both get re-derived later. Manual flight (ADR 0040) makes it
properly observable for the first time — the standoff *chosen* when the player
owns the throttle is the reading that matters, not the one the autopilot holds.

Record it in `STATUS.md`.

## 3. Exploration prototype — the second bet

A separate prototype with its own feel questions, which the combat POC explicitly
cannot answer:

- Cruise feel at three throttle scales (ADR 0009 — one continuous space, no jump)
- The travel gauntlet: is danger-as-terrain a good time, or a chore? (Pillar 4)
- Is an off-route gray blip worth diverting for? What does one contain?
  (Open Question 2 — information is the leading candidate)
- Blip density authored **against travel time, not distance** (Open Question 3)

**Blocked on stage 2.** Sized from the envelope through the numbers chain.

## 4. Overworld design — in parallel, cheap

Design thinking in chat, no implementation. Validation is a **headless faction-war
sim at 1000× speed** long before anything visual exists, answering: does one
faction snowball? does the map reach a boring equilibrium? does threat-on-value
(ADR 0016) produce a legible danger gradient?

This can run alongside stage 1 or 3 because it costs no engine work and shares no
files. Open questions it owns: whether reputation travels between clusters (OQ 4),
whether the starting region has a visible contested edge and whether war tempo is
cyclical (OQ 5).

## 5. Economy, missions, interactions — **after cruise, not before**

These feel like the place to start and they are not, for one concrete reason:

> **Travel carries the campaign clock** (ADR 0022). The war advances in real time
> while the player flies.

So travel time sets mission cadence, and mission cadence sets economy tuning.
Cruise speeds come out of stage 3, which comes out of stage 2. Designing missions
against a guessed clock means re-tuning every reward, every deadline and every
price afterwards.

What *can* be done early, because it is structure rather than tuning:

- **The two playstyles and the earning gradient** (ADR 0046) — already decided.
  The open piece is the viability floor: the fighter path must earn *less*, never
  *not enough*. That is a number, and it waits for the clock.
- **Fuel as a route budget traded against cargo** (ADR 0017) — the shape is
  decided; the values are travel-time dependent.
- **Progression through reputation, not XP** (Pillar 8) and **missile tiers gating
  brake and boost** (ADR 0047) — structure, decidable now.

## 6. Ship-as-place, in stages

Pillar 6. Each stage gated on the previous one earning its cost. Not started, and
nothing is waiting on it.

## 7. Art — last

Placeholders are generated by scripts in `tools/` and **replaced in place**
(ADR 0030); no code knows the difference. Nothing anywhere in this chain is
blocked on art, which is exactly why it goes last: every hour spent on it before
the loop is settled is an hour spent on a silhouette that may not survive.

The one exception already taken: the player's hull was rebuilt as a capital-scale
gunboat (ADR 0044) because the *silhouette was giving a wrong feel signal* — a 5 m
dart implies a dogfight, and feel verdicts were being read against it. That is the
bar for touching art early: it changes a verdict, not that it looks better.

---

## The short answer

**Turret mode, and write the envelope number down while you are in there.**
Everything else on the list is downstream of one or the other.

---

## Known inconsistencies carried deliberately

- **The enemy target is still a 12 m fighter silhouette**, which predates ADR 0044
  and now contradicts it. If the engagement is naval, the thing being engaged
  should read as a gunboat too. Cheap to change — its hull is built from tuning
  values and the hit volumes are registered beside each drawn part, so shape and
  hit test move together.
- **Splash damage** is the last outstanding piece of POC step 5. It arrives with
  the unguided missile's blast in stage 1 rather than on its own.
