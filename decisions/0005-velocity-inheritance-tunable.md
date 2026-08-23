# ADR 0005 — Missile velocity inheritance is a tunable, defaulting to zero

*Status: accepted · 2026-08-23 · recorded from `docs/PROJECT_OVERVIEW.md` v3 and `docs/COMBAT_POC_IMPLEMENTATION.md` v3; the decision predates this repo*

## Decision

`missile.velocity_inheritance` controls what fraction of the mothership's velocity
the missile carries at launch. It defaults to 0.0 (arcade) and is a feel parameter,
not a physics commitment.

## Why

Full inheritance is physically correct and makes launch geometry depend on ship
motion in a way that may be either interesting or infuriating; zero is predictable
and arcade-clean. Which one feels better is a human verdict that cannot be reached
by argument, only by flying both.

Making it a tunable costs nothing now and preserves the choice.

## What this forbids

- Do not hard-code either behaviour anywhere in missile spawning.
- Do not treat 0.0 as the decision. It is the starting position for a feel session.
