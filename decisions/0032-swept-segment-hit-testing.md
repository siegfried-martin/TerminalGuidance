# ADR 0032 — Missile hits are swept-segment tests, not physics bodies

*Status: accepted · 2026-08-23 · made while building POC steps 3–4*

## Decision

A missile hit is a segment-versus-sphere test between the missile's previous and
current position and the target's centre and radius (`FlightGeometry`). The POC
arena contains **no physics bodies and no collision shapes at all**. Targets carry
a plain `radius` number.

## Why

A missile at 90 m/s covers 1.5 m per frame at 60 fps, and it is supposed to get
faster — speed is an explicit upgrade axis (ADR 0025). A per-frame overlap test
tunnels straight through a target that size; testing the swept segment does not,
and it is closer to what a proximity fuse physically does anyway.

It also keeps the whole flight and hit path runnable headlessly with no physics
server and no frame timing, which is why `make check` can simulate a full missile
flight deterministically by stepping `_process` by hand. That test found a
mirrored-basis bug in the steering before it ever reached the screen.

Physics bodies would buy collision response and queries this design does not want.
The LOD/collision invariant already says distant objects must not be queryable;
having no query surface at all in the arena means there is nothing to get that
wrong with yet.

## What this forbids

- Do not add an `Area3D`, `RigidBody3D` or `CollisionShape3D` to the missile, the
  target, or the reference geometry to "fix" hit detection.
- Reference rocks and the marker lattice are visual only. They are placed outside
  the engagement volume precisely so nothing has to decide whether a missile
  collides with them.
- If a future target needs a shape more complex than a sphere, extend
  `FlightGeometry` with a swept test for that shape rather than reaching for the
  physics server.
