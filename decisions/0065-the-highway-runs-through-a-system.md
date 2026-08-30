# ADR 0065 — The highway runs through a system, and its ramps sit beside the planet

*Status: accepted · 2026-08-30 · from the human's first play session on the road*

## Decision

A road does not stop at a system's edge. It **runs all the way through**, entering by
one rim aperture and leaving by the other, and its on and off ramps sit **near the
planet** rather than out at the rim.

A system the road passes through therefore has **two ramp sites** — one either side
of its centre, `portal_site_offset` from it — with four portals between them, and the
stretch between the two sites is where a player is off the road and beside the
planet. An end system has one site and two portals.

This supersedes `docs/EXPLORATION_POC_IMPLEMENTATION.md`'s *"each system has portals
at both ends where a road connects"*, which put them at the rim.

## Why

**Coming off the road has to put you where the content is.** Local roads are
plumbing; `EXPLORATION_DESIGN.md` is explicit that their interesting content lives at
the portals — fuel, market, customs, the board — and that portals *"deserve art and
design attention out of proportion to their size"*. A ramp at the rim puts all of
that a system-crossing away from the planet, so every arrival ends with a
three-minute taxi to the only thing worth arriving for. The road would be fast and
getting anywhere would still be slow.

**It makes the system the road passes through into a place rather than a wall.** With
rim ramps, an A-to-C trip is: cross A, road, cross B, road, cross C. With ramps by the
planet it is: road, *a short stretch beside B's planet*, road. The off-ramp and the
on-ramp being a tuned distance apart is what makes that stretch exist at all — at zero
offset they are the same point and a through-system is a road with no exit.

**It costs nothing structurally.** The corridor between two systems is still bounded
rim to rim and is still the thing you fly when you decline the road; the road is
simply longer than it and passes through both apertures. Route choice still happens
at portals and there are still no junctions: going A to C means taking B's off-ramp
and B's on-ramp, which is the same hop-off-and-back-on the design already prices in
for a missed turn.

## What this forbids

- Do not put a portal at a system's rim. The rim is a boundary with an aperture in
  it (ADR 0062); it is not a destination.
- Do not let a system's two ramp sites collapse onto one point. The gap between them
  is the only place a through-system exists as somewhere to be.
- Do not add a junction so an A-to-C trip can skip B. Route choice happens at
  portals, and ADR 0057 forbids junctions outright.
- Do not conflate the road's length with the corridor's. The corridor is rim to rim
  and bounds the off-road crossing; the road is ramp to ramp and is longer. The
  travel-time comparison the POC turns on is between those two different numbers.
- Do not move the planet to the ramp instead. The planet's placement is ADR 0061 and
  is load-bearing for combat; the road is the thing that is free to move.
