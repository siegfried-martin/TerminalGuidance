# ADR 0009 — No hyperspace or jump mode: one continuous space at three throttle scales

*Status: accepted · 2026-08-23 · recorded from `docs/PROJECT_OVERVIEW.md` v3 and `docs/COMBAT_POC_IMPLEMENTATION.md` v3; the decision predates this repo*

## Decision

There is no travel mode. No hyperspace, no jump animation, no map layer you play
on, no loading screen wearing a costume. The player points the ship and burns, and
the same stick does the same thing threading a fight, crossing a system, or running
a gap between systems.

## Why

This is the single organizing decision of the exploration layer; most of the
travel design is a consequence of it. It is also what makes "invasions are
witnessed, not reported" nearly free — a system *is* the arena, so there is no
combat venue to drop into and no transition to hide.

American/Euro Truck Simulator show that travel sustains hundreds of hours when the
player is performing the core verb continuously. It does not endorse a
non-interactive transit with activities bolted on, which is a lounge attached to a
loading screen.

## What this forbids

- Do not introduce any mode transition for travel, however brief or well dressed.
- Do not add a separate combat scene, arena instance, or level load.
- Fast travel is not a solution to empty space. Fill the space instead.
