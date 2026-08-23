# ADR 0018 — Difficulty is banded by faction, not by coordinates

*Status: accepted · 2026-08-23 · recorded from `docs/PROJECT_OVERVIEW.md` v3 and `docs/COMBAT_POC_IMPLEMENTATION.md` v3; the decision predates this repo*

## Decision

Fixed-difficulty regions, no level scaling ever. But because territory changes
hands, difficulty is a property of **factions and their fleets**, not of map
coordinates — the bands move with the war.

## Why

The map dictating difficulty is the Gothic/Morrowind/Elden Ring school, and
earning the ability to become a god in low-danger regions is the payoff, not a
balance bug. But a living overworld means the map is not static, so hard-coding
difficulty to coordinates would desynchronise from the war within hours of play.

**Accessibility constraint:** walls must be *skippable*, not merely beatable. The
lesson of Skyrim's reach versus Elden Ring's is not that Skyrim is easier — it is
that Skyrim forgives disengagement.

## What this forbids

- Never scale enemies to the player. Not level, not gear, not soft scaling.
- Do not attach a difficulty value to a region, sector, or coordinate.
- A player who whiffs six missiles in a row must still be making progress and must
  never hit a gate that says *get better at this specific thing or stop playing*.
