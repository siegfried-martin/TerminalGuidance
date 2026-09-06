# ADR 0041 — A rock is a cluster of ellipsoids, and the drawn shape is the hit shape

*Status: accepted · 2026-08-26 · from a human observation that rocks were missable where they looked solid*

## Decision

Every rock in the reference field is a cluster of 3–6 overlapping ellipsoids: one
main lobe on the rock's origin, and the rest hung off it at an offset shorter than
the main radius, so no satellite lobe is more than half exposed. Each lobe is
independently sized, stretched per-axis and rotated.

**The lobes are both what is drawn and what is hit.** `MultiMesh` renders one
sphere primitive per lobe, scaled into an ellipsoid; `ReferenceField.hit_test`
tests the swept segment against those same ellipsoids. `arena/rock_hit_radius_scale`
now defaults to `1.0` — what you see is what you hit.

The test is two-phase: one bounding-sphere reject per rock, then lobes only for the
few clusters the segment actually crosses. Measured at 46 µs per call across 260
rocks and 1193 lobes, against a 16.7 ms frame.

`FlightGeometry.segment_hits_ellipsoid` maps the segment into the ellipsoid's own
frame and divides out the radii, reducing it to the existing unit-sphere test. The
map is affine, so the answer is exact rather than approximate.

## Why

Rocks were single boxes with a single hit sphere scaled to `0.55` of the box's
bounding sphere. The human's report was precise: on rectangular prisms, "the hit
collision is missing from the corner, as if the hit box was a sphere slightly
inside the rectangular prism." It was exactly that, and it was a deliberate choice
at the time — a sphere around a box either eats the corners or reaches out into
empty space, and eating the corners was the less maddening of the two.

The mistake was accepting that trade at all. It is only forced when the drawn
shape and the hit shape are different families. Building the rock *out of* the
primitive the hit test already understands removes the gap rather than tuning it,
and it is also the fix for the other half of the complaint — that the rocks did not
look like rocks. One change answers both, which is the reason to prefer it over
the alternative of an exact oriented-box test.

Ellipsoids over spheres because a cluster of true spheres reads as a pile of balls.
The per-axis stretch is what makes it read as quarried.

This does not touch ADR 0032. The mechanism rule stands: no physics body, no
`Area3D`, no `CollisionShape3D`, swept segments against analytic shapes. ADR 0032
explicitly sanctioned "extend `FlightGeometry`" as the escape hatch for exactly
this case, and that is the path taken.

## What this forbids

- Do not reintroduce a hit shape that differs in family from the drawn shape. If a
  rock needs a new silhouette, add the primitive to `FlightGeometry` and draw it
  from that — do not approximate it with a sphere and tune the error.
- Do not raise `rock_hit_radius_scale` above 1.0 as a difficulty dial. Above 1 the
  rocks are solid where they look empty, which is the original complaint mirrored,
  and it is a worse bug than the one it came from because it is invisible.
- Do not drop the bounding-sphere broad phase. It is what keeps a per-frame,
  every-rock test affordable, and removing it would degrade quietly as rock counts
  rise rather than failing.
- Do not scale or shear the `ReferenceField` node. The lobe orientations are taken
  orthonormalised, and a scaled parent would silently make every hit test wrong.
- Do not extend this to anything with a distant stand-in. The LOD/collision
  invariant in `CLAUDE.md` governs background-layer objects; rocks are real meshes
  at every distance, which is the only reason querying them is legitimate.
