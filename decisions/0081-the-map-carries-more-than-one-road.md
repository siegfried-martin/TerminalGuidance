# ADR 0081 — The map carries more than one road, so the union's guard is geometric and a ramp is declared

*Status: accepted · 2026-08-31 · from building a second highway across the first*

## Decision

**A second highway crosses the first over system B**, on its own bearing, above it,
inside the system's own disc. It carries no portals and simply ends: run off it and
you drop into normal flight, exactly as at the edge of the map.

Two things that were true of one road are not true of a network, and both are retired:

**1. The union's guard is geometric.** `RoadNetwork.governing` no longer filters on a
direction flag. A candidate must lie inside the steering cone around the road the ship
is already held against, and `along` is now **required**. ADR 0067's *"only decks
sharing `is_upper` are ever considered"* and ADR 0077's *"`runs_forward` survives as a
grouping key"* are both superseded by that; the property they protected — **the union
never hands you the oncoming lane** — is unchanged and now holds by geometry.

**2. A ramp is declared, not inferred.** `RoadDeck.is_ramp` is set at construction.
ADR 0065's *"a ramp carries a portal and a mainline does not"* and ADR 0076's forbid
on distinguishing them any other way are superseded.

**The "over the top" exit is not built.** ADR 0080's rule stands and is unbuilt for the
left-going case; see below.

## Why

**A direction flag cannot survive a second route.** An interchange ramp leaves the main
road and joins the crossing one, so it would have to carry the main road's flag to be
reachable from it and the crossing road's flag to hand off onto it. One boolean cannot
be both, and authoring it either way breaks the other end. Worse, the flag is *per
route* — "forward along its own spine" says nothing about two spines that cross.

The cone filter already did the whole job in the live path. `_ride_the_road` has
always passed `ship.road_axis()`, so the only caller that ever relied on the flag was
a test. Deleting it is a **simplification that makes the guarantee stronger**: it
excludes the oncoming lane at 180 degrees, every deck of a road crossing at an angle,
and the ramp thirty degrees off the heading that shook the ship (ADR 0072) — all by the
same rule, with nothing declared.

**The portal was a proxy for "this is a connector", and a network breaks it from both
ends at once.** An interchange ramp joins two roads and carries no portal. A road that
simply stops carries one without being a ramp. The proxy was fine while every ramp led
to a planet; it is not a property of ramps, it was a property of the map having one
road on it.

**Why a second road exists at all:** an exit rule you cannot fly is an exit rule you
cannot judge. ADR 0080 wrote three cases down and the map had nothing to turn onto.

## What is not built, and why it is not a tuning problem

**Turning onto the carriageway coming the other way — the "over the top" case — is not
built.** It is better than ninety degrees of rotation, and `RoadPath.ramp` is a cubic
told two tangents: asked to hold that much turn it puts all of it in one place.
Measured at **72 deg/s** against a ship that turns at 34; chaining two cubics through a
crest measured **132**. The physics is fine — 125 degrees at the ship's own minimum
radius is under a kilometre of arc — so what is missing is a curve built to a
**bounded radius** rather than to two tangents. That is a `RoadPath` primitive with its
own gate, and it is the next piece of road work.

Turning right onto a road going right is built and flyable, which is what makes the
mechanism judgeable now.

## What this forbids

- Do not reintroduce a direction flag as a filter. If the union is handing out a lane
  it should not, the cone is wrong or `along` is wrong.
- Do not call `governing` without the heading the ship is held against. There is no
  "consider every deck" mode, and adding one back reopens the oncoming lane.
- Do not infer that a road is a ramp from the portal it carries, or that it is a
  mainline from the absence of one.
- Do not build the over-the-top ramp out of cubics, and **do not relax ADR 0070's turn
  check to make one pass.** The turn rate is a feel value for the ship, not a budget
  for the road.
- Do not put a portal on the crossing road's ends to tidy them. There is nothing on
  the far side of it yet, and a portal there would make a mainline read as a ramp.
- Do not assume one road on the map anywhere else. `_laid_on` takes a route; anything
  that only works for `_spine` is a bug waiting for the next road.
