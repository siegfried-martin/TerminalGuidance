# ADR 0020 — Combat arenas are origin-local; the world uses a floating origin

*Status: accepted · 2026-08-23 · recorded from `docs/PROJECT_OVERVIEW.md` v3 and `docs/COMBAT_POC_IMPLEMENTATION.md` v3; the decision predates this repo*

## Decision

A system is a disc-shaped arena and combat is origin-local within it;
single-precision is fine at that scale. The *world* recentres on the player
periodically and everything else shifts.

This supersedes the v2 phrasing "do not build anything here that assumes a to-scale
coordinate space," which aimed at the right hazard and stated it misleadingly.

## Why

Continuous travel means large coordinates, and single-precision floats degrade
visibly in the tens-of-kilometres range — jitter in physics, camera and particles.
It will surface first as **missile flight feeling subtly wrong far from origin**,
which is the hardest possible place to diagnose it.

Floating origin avoids compiling an experimental double-precision Godot build, but
every system that stores a position must respect it, so it is an early
architectural commitment and painful to retrofit.

## What this forbids

- **No system may assume a fixed world origin, or cache a world position across
  frames without accounting for recentring.** Prefer relative positions.
- This applies inside the origin-local combat arena too, where the shift is not yet
  implemented. The POC does not have to implement it; nothing built may make it
  harder to add.
