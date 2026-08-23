# ADR 0016 — Threat sits on value, not on coordinates

*Status: accepted · 2026-08-23 · recorded from `docs/PROJECT_OVERVIEW.md` v3 and `docs/COMBAT_POC_IMPLEMENTATION.md` v3; the decision predates this repo*

## Decision

Enemies occupy what the war is currently about: stations, trade lanes, the
approaches to inhabited planets. Danger is not painted onto regions of the map.

## Why

This gates access to a destination in proportion to how much that destination
matters, and leaves the backwater open — more interesting than uniform gating. It
produces the danger gradient that fixed-difficulty regions need, lets the living
world express itself positionally rather than through a menu, and means an invasion
is happening *around* the player at arrival instead of parked somewhere static.

**Spatial commitment does the pacing work.** If the valuable things sit deep in the
disc and the player enters at the rim, going for a defended planet means a long run
back out under fire. A shallow raid and a deep one are genuinely different risk
profiles without anything being tuned.

## What this forbids

- Do not place spawners or danger zones by coordinate.
- Do not distribute threat uniformly across a system.
