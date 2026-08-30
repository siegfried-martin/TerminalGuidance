# ADR 0068 — The lane is measured against the hull, not against the ship's centre

*Status: accepted · 2026-08-30 · from the human flying a capital down the highway*

## Decision

A ship is **out of its lane when its hull crosses the rail**, not when its centre
point does. `CruiseLane` carries the asking ship's half-section and shrinks the band
its centre may occupy by exactly that much.

**The drawn lane does not change.** The rails stay where they are, at the tuned
`lane_width` and `lane_height`, exactly as a road's markings do not move for a wide
lorry. What changes is who is inside them.

A hull may claim at most `lane_hull_clearance_cap` of the lane's half-section. A ship
too big for the road it is on is left a lane to fly in rather than being outside its
own road everywhere it sits.

The same clearance is used **everywhere the lane is sampled in a frame**, including
the union that decides which deck governs (ADR 0067). Comparing a hull-measured depth
against a point-measured one would hand a big ship whichever deck happened to be
asked with zero.

## Why

The lane was sized as *"three ships side by side"* against a 43.6 m taxi, and then
the roster grew a capital drawn at 1.75 — 76 m across and 42 m tall. Measured at the
centre point, that ship could sit with two thirds of itself through the rails and
nothing anywhere would say so: no penalty, no push, no readout. The picture and the
rule had come apart, and the picture was the one telling the truth.

The alternative was to leave the rule alone and treat the overhang as cosmetic. That
loses the one thing the lane is for. The lane's whole job is to make holding a line
worth something, and a rule that cannot see the ship cannot ask it to hold anything.
It also makes the road's own sizing untestable — with a point-measured lane there is
no arithmetic that says a portal is too small for a hull, so the gate cannot catch a
roster the road can no longer carry, which is exactly what it failed to catch here.

The cap exists because the honest reading of "this ship is too wide for this road" is
*no room to manoeuvre*, not *permanently in the wrong*. Without it a hull wider than
the lane gets a band of zero, is outside it wherever it sits, and is slowed and
pushed for existing — which reads as the road being broken rather than as the ship
being large.

## What this forbids

- Do not move the drawn rails per hull. The road is one shape and every ship on it
  sees the same one; only the room inside it differs.
- Do not measure the lane against a bounding sphere. Fitting through an aperture is an
  axis-by-axis question — a 72 m bounding sphere around a 44 x 24 m gunboat condemns
  openings it flies through with room to spare (`Mothership.hull_extents`).
- Do not sample a lane with a clearance different from the one the ship is flown
  with, anywhere in the same frame.
- Do not let the clearance take the whole lane. The cap is not a rounding guard; it is
  the reason a capital can still use the highway.
- Do not use the lane's length as a clearance. How long a ship is does not decide
  whether it is in its lane.
