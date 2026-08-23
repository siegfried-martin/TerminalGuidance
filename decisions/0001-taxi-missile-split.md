# ADR 0001 — Ships are taxis by choice; missiles are the player's hands

*Status: accepted · 2026-08-23 · recorded from `docs/PROJECT_OVERVIEW.md` v3 and `docs/COMBAT_POC_IMPLEMENTATION.md` v3; the decision predates this repo*

## Decision

The piloting fantasy relocates from the ship to the munition. The player fires a
missile, the camera cuts to close third-person behind it, and they fly it to the
target. The mothership can still be flown manually — that is the primary mode for
exploration and for getting launch geometry — but autopilot is available and is a
delegation the player *elects*.

## Why

Munitions are fast and ships are slow, in this game and in real naval warfare.
Putting the player's hands where the speed is means realism and fun pull the same
direction instead of fighting. It also sidesteps the 3D interception problem that
every space game has to cheat around, rather than cheating around it again.

Autopilot is deliberately tuned to be *safe and adequate*: it holds range, it does
not die, it never embarrasses you. If autopilot were as good as manual flight,
manual flight would be decoration.

## What this forbids

- Do not write an ADR, a code comment, or a system that asserts the ship is
  autopilot-only. Manual flight exists and is central; its absence from the POC is
  a scope deferral, not a design decision.
- Do not make autopilot better at positioning than a human. Adequate is the target.
