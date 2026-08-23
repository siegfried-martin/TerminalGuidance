# ADR 0024 — The audience is the sim/sandbox player; default tuning biases to power fantasy

*Status: accepted · 2026-08-23 · recorded from `docs/PROJECT_OVERVIEW.md` v3 and `docs/COMBAT_POC_IMPLEMENTATION.md` v3; the decision predates this repo*

## Decision

The audience is the Bannerlord / Starsector / X4 player, not the action-game
player. Default tuning biases toward power fantasy. **Build for depth, tune for
accessibility — in that order.**

## Why

That audience's pleasure is accumulation expressed as dominance, not adversity.
They are not seeking a challenge to overcome; they are seeking a world to become
powerful in.

Default difficulty is a late, reversible edit to a tuning file. Depth is an early
architectural commitment. A deep system can always be made gentler; a shallow one
cannot be made deep.

The threat model for this genre is not "bounced off in hour one" — sandbox players
invest hundreds of hours — it is **boredom at hour thirty**.

## What this forbids

- Do not trade depth for accessibility early. Set the floor gentle and keep the
  ceiling high; these are not in tension.
- Do not tune against an action-game player's expectations.
