# ADR 0079 — The glass is a diffuser, and "visually open" is measured as area

*Status: accepted · 2026-08-31 · from the human's note that thicker glass would let oncoming ships be rough renders*

## Decision

**The road's walls and roof are glazed; only the roadway is solid.** That is what
"the lane is visually open" (ADR 0057) means now, and it is checked as an **area
ratio**: everything along the run that is not a metal collar is a window, so the
glazed fraction is `(module_length - rib_thickness) / module_length`, and
`RoadStructure.open_fraction` is what the gate asserts.

**The glass is deliberately more opaque than the shell it replaced, and that is
load-bearing rather than a look.** The glass is a **diffuser**: a low-detail proxy
behind it reads as a plausible ship. That is what lets traffic outside the tube stay
a rough render and only become a real hull on or near the road.

**The alpha ceiling stays as a backstop.** `structure_glass_alpha` may not reach
opacity, because a pane you cannot see the stars through is the tunnel ADR 0057
forbids.

ADR 0074 is **superseded**: the lane is not a translucent shell any more, it is a
building with windows in it. ADR 0075's *"every lane is drawn, the one you are on is
brighter"* **stands** and is now carried by the markings painted on each carriageway;
its shell mechanism and its outer→divider vertex gradient are superseded.

## Why

The alpha threshold ADR 0074 shipped could not tell a window from a tinted wall. It
asked "is this number below 0.85", which a fully enclosed tube passes as easily as a
row of windows. **Area is the property the ADR was always about** — you can see out
because there is something to see out *of* — and it is both stricter and meaningful
in a way a colour never was.

The diffuser argument is the human's and it is what makes the thicker glass earn its
keep. Without it, "more opaque glass" is a preference and ADR 0074's forbid says no.
With it, the glazing is doing LOD work: it composes with the existing rule that
distant objects are background-layer visuals with no body and nothing queryable, and
it is the reason there will never need to be traffic-merge logic (ships outside are
rough renders; real hulls swap in on the road).

**A third failure mode turned up in the frame and is not covered by either check:
panes stack.** From inside you look through the near wall, the far wall, the roof and
the median at once. The first value tried — 0.7, the honest reading of "a little more
opaque than the shell" — produced a solid tube: the whole view was glass colour, with
the area check passing happily. So the glass is a **muted, dark** blue for the same
reason the old shell was (you are inside this surface, so whatever it is tinted with
tints the whole view), and the tuning comment says to judge the value looking down the
road rather than at one pane. The gate cannot see this; a frame can.

## What this forbids

- Do not check "the lane is visually open" by reading an alpha. That is the check this
  ADR replaced, and it cannot distinguish a window from a wall.
- Do not glaze the roadway or open a hole in it for the view. It is the one face that
  is deliberately solid — you drive on it — and step C's ramp entry is the only thing
  that may pierce it.
- Do not treat the glass alpha as decoration to be raised freely. It is a diffuser
  with a job, bounded above by ADR 0057 and below by that job.
- Do not judge the glass on one pane. Four of them stack in the view down the road,
  and that is the number that matters.
- Do not use a bright glass colour. You are inside the surface, and a bright pane
  lifts the black of space until the deep field stops reading.
- Do not give a rough render outside the glass a physics body or make it queryable.
  The diffuser is what lets it be rough; querying it is the bug that looks like a
  physics bug.
