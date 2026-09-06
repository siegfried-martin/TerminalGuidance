# ADR 0011 — Systems are discs: hard flat faces, open rim

*Status: accepted · 2026-08-23 · recorded from `docs/PROJECT_OVERVIEW.md` v3 and `docs/COMBAT_POC_IMPLEMENTATION.md` v3; the decision predates this repo*

> **The open rim and the outbound clamp are superseded by ADR 0062.** The rim is a
> boundary now, opening only where a road attaches, because ADR 0057 moved
> departure onto the highway and left an open rim leading nowhere rendered. The
> clamp became heading-proportional and reaches zero. Everything else here — the
> disc shape, height as the sneak dimension, the Bannerlord treatment, magnitude
> never direction, and bounds being the player's alone — stands unchanged.

## Decision

Each system is a self-contained, origin-local arena shaped like a disc —
substantial vertical room, but a ceiling and floor much closer than the diameter.
The flat faces are hard boundaries. The rim is not a boundary: flying laterally out
of a system **is** departure, continuous with the transit lane.

## Why

Combat occupies a thin slab, so *height is the sneak dimension*. Coming in on a
high arc and dropping onto a target from above the engagement layer is a real
approach option that costs nothing to support, because the space already exists.

The out-of-bounds treatment follows Bannerlord: the volume is visibly red, entering
starts a telegraphed timer, damage ramps if the player does not return, and maximum
velocity is scaled down in the outbound direction. The clamp scales **magnitude
only, never direction** — the stick still does what the player asked; the ship just
feels like it is straining.

Bounds apply to the player only. NPCs avoid the volume rather than being ejected
from it, which makes a brief dip a legitimate tactical option while ramping damage
makes camping non-viable.

## What this forbids

- Never clamp or redirect the player's heading. Magnitude only.
- ~~Do not put a wall, threshold, or prompt at the rim.~~ — superseded by ADR 0062;
  the rim is closed except at an aperture. No threshold or prompt at the aperture,
  though.
- Do not eject NPCs from the out-of-bounds volume; have them avoid it.
