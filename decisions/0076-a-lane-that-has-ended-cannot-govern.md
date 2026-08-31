# ADR 0076 — A lane that has ended behind you cannot govern, and a ramp is drawn darker

*Status: accepted · 2026-08-30 · from a screencast of the ship stuttering at every exit ramp*

## Decision

**A deck only governs a point its own path actually reaches.**
`RoadNetwork.governing` skips any deck whose sample is clamped at either end of its
path. This is `TubeRegion.applies_to`'s rule, applied to lanes.

**A handover needs a margin.** A candidate must be nearer than the current lane by
`lane_handover_margin` metres, not by any amount at all.

**A ramp is drawn at `lane_ramp_shade` of the highway's brightness.** A ramp carries a
portal and a mainline does not; that is the whole difference and it is enough.

ADR 0072's *"Do not fix a snap at a handover by adding hysteresis"* is **narrowed, not
reversed**: it forbade hysteresis as a substitute for fixing the snap's magnitude, and
that stands — the slew is still what bounds the magnitude. Flapping is a different
defect with a different cause, and a margin is the right tool for it.

## Why

`RoadPath.closest` clamps to the ends of a path. So a ship that has run off the top of
a ramp still reports as sitting on the ramp's **last metre**, at zero lateral offset —
the nearest lane in the world. What followed was a loop:

1. the ramp has ended, so `_ride_the_road` hands over to the mainline
2. the union is asked again and the ramp is still nearest, so it hands back
3. the ramp has ended, so it hands over again

Measured on a flown route, that alternated **every one to two frames for a third of a
second and then dropped the ship off the road entirely.** From the seat it is a
stutter at every exit ramp and a tunnel that stops rendering — both of which were
reported, and the second of which was guessed to be "on ramp / tunnel collisions". It
was not a collision and not a rendering fault; it was a lane that had ended still
claiming the ship.

The rule that fixes it is the honest one and it already existed elsewhere: a region
says where it does not apply (ADR 0063), and a lane whose path stops behind you does
not apply to where you are. The margin does not fix this case — it was tried, and a
clamped lane is at zero offset, which beats any margin — so it is kept as a guard
against genuine near-ties rather than sold as the fix.

The ramp shading is the other half of the same report: *"the game can't decide which
should be the true tunnel"*. Even with the flapping gone, four roads cross the view at
an interchange and every one of them was the same colour. Which of them leaves the
highway should be something the eye answers, not something read off a sign.

## What this forbids

- Do not let a deck govern a point outside its own span. If `closest` clamped, the
  answer is "not this lane".
- Do not fix a handover loop by remembering which deck you were on last frame. The
  geometry has to be able to answer on its own, or the union is not a union any more.
- Do not raise `lane_handover_margin` to paper over a lane that should not have been a
  candidate. If a deck is winning that it should not, the filter is wrong.
- Do not read ADR 0072's forbid as banning hysteresis outright. It bans hysteresis
  *instead of* bounding the snap, and the snap is still bounded by the slew.
- ~~Do not distinguish a ramp from a mainline by anything other than the portal it
  carries.~~ *Superseded by ADR 0081: with a second road on the map an interchange ramp
  carries no portal and a road that simply stops carries one, so the portal has stopped
  being a proxy for "this is a connector". `RoadDeck.is_ramp` is declared. The drawing
  rule — a ramp is built at `lane_ramp_shade` of the brightness — is unchanged.*
