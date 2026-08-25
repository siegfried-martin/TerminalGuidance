# ADR 0038 — Reference rocks are obstacles, inside the engagement volume

*Status: accepted · 2026-08-25 · asked for alongside side thrusters, to give them something to dodge*

## Decision

The reference rock field moves **inside** the engagement volume
(`arena/rock_inner_radius` 420 m → 60 m, `rock_count` 120 → 260) and a missile
that touches a rock dies (`EndReason.ROCK_IMPACT`).

Hits are swept-segment sphere tests against a flat array of centres and radii held
by `ReferenceField`, using the same `FlightGeometry.segment_hits_sphere` the target
uses. The arena still contains **no physics body, no `Area3D` and no
`CollisionShape3D`.**

This **supersedes only the placement clause of ADR 0032** — "reference rocks and
the marker lattice are visual only… placed outside the engagement volume". ADR
0032's actual decision, that hits are swept-segment tests rather than physics
bodies, is untouched and now covers one more thing.

`arena/rock_collision = false` restores the pre-0038 arena.

## Why

The rocks were placed outside the fight precisely so nothing had to decide whether
a missile collides with them. That was the cheap answer while the missile had no
reason to dodge. Side thrusters (ADR 0037) give it one, and a dodge verb with
nothing to dodge cannot be judged.

ADR 0032 anticipated this and named the way through: "extend `FlightGeometry` with
a swept test for that shape rather than reaching for the physics server." That is
what this is. 260 segment-sphere tests per frame is nothing, and it keeps the whole
flight path headlessly simulable, which is the property 0032 was protecting.

The cost is real and accepted: the rocks were the **far-field** speed reference,
and pulling them in degrades that. The marker lattice still supplies the near-field
cue. If the far-field reference turns out to be missed, the answer is a second,
sparse, non-colliding layer — not moving these back out.

Hit spheres are scaled by `rock_hit_radius_scale` (0.55) so they sit near the
inscribed sphere of each box rather than its bounding sphere. Clipping a rock's
drawn silhouette and surviving is the intended bias; being killed by empty space
next to a corner is not.

## What this forbids

- Do not add a physics body, `Area3D` or `CollisionShape3D` to make rock collision
  "work properly". ADR 0032's mechanism rule survives this ADR intact.
- Do not extend queryability to anything with a distant stand-in. Rocks are real
  meshes at every distance. The LOD/collision invariant in `CLAUDE.md` still
  forbids querying background-layer planets and stations, and that is a different
  class of object.
- Do not make rocks damage the mothership or the target. This is a missile-only
  hazard; a ship that can be stopped by scenery is interdiction by geometry
  (ADR 0014).
- Do not move the rocks back outside the engagement volume to "restore" ADR 0032.
  Set `rock_collision = false` if the obstacle course is unwanted; the placement
  decision is this ADR's to own now.
- Rock hits must stay ordered after target hits in `Missile._process`. A missile
  reaching the target inside a rock field scores.
