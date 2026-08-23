# ADR 0003 — Direct screen-space missile steering, not vector thrust

*Status: accepted · 2026-08-23 · recorded from `docs/PROJECT_OVERVIEW.md` v3 and `docs/COMBAT_POC_IMPLEMENTATION.md` v3; the decision predates this repo*

## Decision

Missile steering maps input directly to screen-space direction. The missile goes
where the stick points. No Newtonian thrust vectoring, no inertia the player has to
model in their head.

## Why

Realistic vector-thrust flight (Escape Velocity, Elite with flight assist off) is
elegant and alienating. Intuitive controls matter more than fidelity for this
audience, and the accessibility promise depends on a player being able to fly a
missile competently within seconds.

The skill ceiling is supplied by fuse pressure, blockers, and missile speed — not
by making the control scheme itself the obstacle.

## What this forbids

- Do not add flight-model realism to the missile as a difficulty source.
- Boost/afterburner is essential to satisfaction and is part of this scheme, not an
  exception to it.
