# ADR 0002 — Fuse-as-range is the player-facing difficulty dial

*Status: accepted · 2026-08-23 · recorded from `docs/PROJECT_OVERVIEW.md` v3 and `docs/COMBAT_POC_IMPLEMENTATION.md` v3; the decision predates this repo*

## Decision

Missiles carry a short fuse that detonates them at expiry. Fuse length is therefore
effective range, and upgrading the fuse is how range grows. Every shot is the
player choosing a range, and therefore choosing a difficulty.

## Why

Firing at the edge of fuse range demands a near-perfect turn-to-target or the fuse
eats the missile. Firing closer is nearly free but concedes a volley. The player
wagers against their own honest assessment of their hands, and the system
auto-calibrates: a cautious player succeeds slowly, a confident one feels like a
god. That is difficulty selected through a mechanic rather than through a menu.

It also generates procedural variety for free — launch geometry differs every shot
because the ship's relative position differs — and it converts skill directly into
throughput, since a faster turn-to-target means both more range and a higher rate
of fire.

## What this forbids

- **Nothing may make max-range shots mandatory.** The cautious setting must remain
  viable, not merely possible. If winning requires edge-of-fuse shots, the dial is
  decorative and this pillar is dead.
- Do not add a mechanic that extends range without going through the fuse.
- Playing it safe should be *slower*, never *failing*.
