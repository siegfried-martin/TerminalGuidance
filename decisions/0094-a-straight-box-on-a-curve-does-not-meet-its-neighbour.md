# ADR 0094 — A straight box on a curve does not meet its neighbour, and coplanar faces flicker

*Status: accepted · 2026-09-05 · from a play session · authoring fixes inside ADR 0078*

## Decision

Two authoring bugs in the module system, both structural rather than incidental.

**1. Every span module is lengthened by its own curvature.** A module is a straight box
placed at the middle of its stretch with the tangent *there*, so on a bend its ends fall
short of where the path actually is — by the sagitta, `length × turn / 8` at each end.
Each module is scaled by `1 + turn/2`, measured off the path's own tangents at its two
ends, so it tucks under the collar beside it instead of leaving a wedge.

**2. The median stands on a kerb.** Floor to roof, the pane's underside was coplanar
with the roadway's top face.

## Why

**1 — because a rigid box cannot follow a curve, and the error is bigger than it looks.**
At the tuned 400 m module on a road whose weave gives a radius of roughly three
kilometres, the sagitta is about seven metres at each end — thirteen metres of
misalignment at every joint, the whole length of the road. What it looks like from the
seat is a black wedge between every bay and the collar next to it: *"still lots of places
where the glass disappears."*

Overlapping is invisible where a gap is not. A bay tucks under the opaque collar beside
it and nothing shows; at the one place two bays meet — the edge of a junction opening —
a few metres of doubled glass is nothing.

The bleed is **measured off the path** rather than tuned, so it is right for a straight
(nothing at all), for a weave, and for a ramp's tightest bend, with no number for anyone
to maintain.

**This is the honest limit of ADR 0078's win**, and it should be stated plainly because
it is the argument for authored tiles: *one affine transform has parallel end faces, and
two consecutive joints on a curve are not parallel*, so no placement of a rigid box can
make both ends meet exactly. The error falls as `length²`, so shorter modules or this
bleed both hide it — but neither removes it. A tile authored **with its curvature baked
in** is the only thing that does.

**2 — because two coplanar faces are a depth fight.** The line along the bottom of the
divider that flickered on and off for the whole length of the road. A kerb is also what a
real median has.

## What this forbids

- **Do not place a span module without its bleed.** A straight box centred on a curved
  stretch does not reach its neighbours, and the gap grows with the square of the module
  length.
- **Do not tune the bleed.** It is a property of the path at that point.
- **Do not author two coplanar faces**, here or in any module added later. If two pieces
  share a plane, one of them stands on something.
- Do not read this as "the modules were a mistake". What it bounds is what a rigid
  instance can do on a curve; the module system is what made real art droppable, and it
  is still that.
