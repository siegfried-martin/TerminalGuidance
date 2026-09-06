# ADR 0062 — The rim is a boundary, its openings are funnels, and the clamp reaches zero

*Status: accepted · 2026-08-29 · from the human's direction during exploration POC step 5 planning*

## Decision

Three changes to ADR 0011, which stands otherwise.

**1. The rim is a boundary.** A system is closed except where a road attaches.
ADR 0011's *"the rim is not a boundary: flying laterally out of a system **is**
departure"* no longer holds and is superseded.

**2. Each opening is a funnel** — wide where it meets the rim, tapering outward to
the corridor the road runs down. Past the rim, inside the throat, the disc's flat
faces stop applying and the funnel wall is the only constraint.

**3. The outbound clamp is heading-proportional and reaches zero:**

```
outbound = (1 + cos t) / 2          ; = cos²(t/2), t measured from the outward normal
reach    = clamp(metres past the edge / bounds_stop_distance, 0, 1)
scale    = 1 - reach * outbound
```

`cos²(t/2)` is 1 straight out, **0.5 tangential**, 0 straight back in. Two
distances, on opposite sides of the edge, replace the one that used to do both
jobs: `bounds_warning_band` is metres *inside* the edge where the volume reddens
and nothing else happens, and `bounds_stop_distance` is metres *outside* it over
which the outbound speed limit ramps to zero.

Ceiling, floor and rim become **one list of constraints**, each contributing a
depth and an outward normal, rather than three special cases.

## Why

**The rim closed because roads exist.** ADR 0011's open rim was not a convenience;
it was a *statement* — lateral exit was departure, continuous with the transit
lane, so a boundary there would have been a wall across the way out. ADR 0057 took
that job away from the rim and gave it to the highway: the cruise drive works on
the road and nowhere else, and there is no personal equivalent in open space. So
the open rim now leads to somewhere nothing is rendered and nothing can be reached.
That is the highway design's own renderability argument turned on the system it
came from, which is why **0011 gives and 0057 is untouched**.

**Funnels because a hole is not a destination.** The corridor is half a system
across, which sounds generous until you are inside a 3500 m disc trying to find it.
A flare at the mouth turns "leave through the 1750 m gap on that bearing" into
"aim at the wide thing", which is the same guidance a real interchange gives and
costs one cone. It also makes the opening findable from inside without a map, which
matters because the POC does not have one yet.

**The old clamp was a boolean, and the boolean was wrong.** Any outbound velocity
component at all triggered the full clamp on the whole speed, so a legal lateral
departure with a few degrees of climb in it was strangled as hard as flying
straight up. Worse, it never reached zero, so "the boundary is hard" was enforced
only by damage — and damage is the *last* stage of a telegraph, not the mechanism.

`cos²(t/2)` fixes both ends at once. Tangential travel in the red is slowed but
possible, so skimming the edge is a real option with a real cost. Pushing outward
converges on a stop, so the volume is closed without anything ever grabbing the
stick. And the way home is free at every depth, which is what keeps the telegraph
from becoming a trap.

This is still **magnitude only, never direction**, and still structurally so:
`BoundaryField` returns a scale and never sees a heading it could return.

**Constraints rather than cases, because the corners are the hard part.** With
three special-cased surfaces, a ceiling∩rim corner needs its own rule and would get
one written by whoever hit it first. As a list, the combined outward normal is the
breached normals summed and weighted by depth, so at a corner it is the diagonal —
down-and-inward is cheapest, up-and-out is stopped — and no case exists to get
wrong. The whole-map boundary the human expects to want later is then a *different
constraint set, not different code*.

## What this forbids

- Never clamp or redirect the player's heading. Magnitude only. ADR 0011's rule is
  unchanged and this ADR tightens rather than relaxes it.
- Do not put a wall, threshold, prompt, or confirmation at an aperture. The rim is
  closed; the opening is open, and flying through it is flying through it.
- Do not make the way back in cost anything, at any depth. A telegraph that taxes
  the return is a trap.
- Do not reintroduce a boolean outbound test, or a clamp with a floor above zero.
  The volume is closed by the speed model, not by the damage.
- Do not add a boundary surface as a special case. Add a constraint.
- Do not let an aperture's mouth be narrower than the corridor it feeds — that
  inverts the funnel into a pinch. A test asserts it.
- Do not let the funnel's geometry and the drawn rim disagree. The hole in the
  picture is the hole in the boundary.
