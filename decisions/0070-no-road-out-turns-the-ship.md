# ADR 0070 — No road out-turns the ship, and a ramp is tangential at both ends

*Status: accepted · 2026-08-30 · from the human reporting the on-ramp was too steep*

## Decision

**No road on the map may bend faster than the ship can be turned at cruise.**
`RoadPath.max_turn_deg_per_metre` times `cruise_speed` must not exceed
`cruise_turn_rate_deg_per_sec`, on every deck, and the headless gate checks it.

**A ramp is a cubic with a tangent specified at both ends.** It leaves the mainline
along the road *and arrives at its portal along the road* — the S-curve a freeway ramp
actually is — rather than being told only where to leave from and arriving wherever
the maths put it.

**A leg curves as a weave, expressed in degrees.** `road_curve_deg` and `road_rise_deg`
are the most the road departs from the leg's bearing and from level; the amplitudes in
metres are derived from those angles and a period. Both weaves taper to zero value
*and* zero slope at each end, so a curving leg still leaves and arrives exactly on the
bearing and the systems do not move.

## Why

The ship's nose is hard-clamped into a cone around the road's axis every frame
(`Mothership._fly_cruise`). That is what makes the camera lock to the road honest —
but it also means the road's own curvature is applied to the ship's heading whether
the ship can keep up or not. **A road that turns faster than the ship turns is not a
corner; it is the game taking the nose.** That is the thing the human felt and called
"too steep", and it is checkable rather than a matter of taste: the old ramp bent at
23.7 deg/s at cruise against a 22 deg/s turn rate, and arrived at its mouth pointing
88 degrees across the mainline in a 30 degree dive.

The quadratic was the cause, not the tuning. A quadratic Bezier can be told one
tangent, and the tangent that mattered was the merge — a ramp that joins the mainline
at an angle is a corner the steering cone cannot turn. So the merge was correct and
the mouth was whatever fell out, which was a dive. A cubic controls both ends and
costs one more control point.

Angles rather than distances for the leg, because the same amplitude in metres is a
gentle sweep on an 18 km leg and a hairpin on a 2.6 km one, and the map has both. An
angle is the thing that is actually bounded — by the turn-rate ceiling above, and by
the deck divider, which this map must not cross.

The envelope on the weave is what lets curvature be added without moving anything:
value and slope both reach zero at each mouth, so the aperture bearings, the system
positions and the corridor attachments are all exactly what a straight leg gave.

## What this forbids

- Do not add curvature anywhere — a leg, a ramp, a ring road, a junction later —
  without the turn-rate check covering it. The check is on every deck for a reason.
- Do not raise `road_curve_deg` or shorten a period past what the gate allows and then
  raise `cruise_turn_rate_deg_per_sec` to make it pass. The turn rate is a feel value
  for the ship, not a budget for the road.
- Do not go back to a single-tangent ramp curve. Both ends are deliberate.
- Do not express a road's curvature as an amplitude in metres.
- Do not let a leg's weave move its endpoints or change its end tangents. If a curve
  needs the systems moved, it is the wrong curve.
- Do not weave across the northwest–southeast deck divider. The deck is declared per
  segment (ADR 0065's convention), and a stretch of upper deck on a lower-deck heading
  makes the convention worse than no rule.
