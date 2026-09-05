# ADR 0090 — The road bounces, and a bounce costs the throttle

*Status: accepted · 2026-09-05 · from the human flying ADR 0087 · supersedes ADR 0087's
"it never bumps" clause*

## Decision

**Hitting the road's structure is a bounce.** The speed going *into* a face comes back
out of it, scaled by `structure_bounce_restitution`, carried as a rebound that bleeds
off over `structure_bounce_seconds`.

**A bounce costs the throttle**, once per contact, scaled by how square the hit was:
`structure_bounce_speed_keep` on a dive straight into a surface, nearly nothing on a
brush along one. The cut is to the **throttle**, not the speed, so the ship spools back
up over its own `accel_seconds`.

Everything else in ADR 0087 stands, and one clause of it is load-bearing here:

- **The bounce is normal-only.** Motion along the surface is untouched, so a glancing
  hit is deflected and a ship flying beside a wall is never stopped by it.
- **The cost is charged on the rising edge of contact and nowhere else.**
- The hull is still put back against the face; apertures, portal flares and the open
  ends of ramps are still not held; nothing gains a physics body.
- **The nose is never turned.** Velocity is reflected; the basis is not. There is still
  no code path that gives the player's ship a heading.

`structure_bounce_restitution = 0` is exactly ADR 0087's original sliding stop, so the
old behaviour is a slider away rather than gone.

## Why

**In the human's words:** *"I like the feel of the bounce in general better than the
slow. I know that reverses a previous decision. Slow makes a little more sense when the
highway is made [of] energy, but now it's made [of] hard materials. The player should
still be rewarded for flying straight though, so maybe the bounce slows them down."*

That is the whole reasoning and it is a good one. ADR 0087 absorbed the impact and let
the ship keep sliding, which is what an energy tube would do; the road stopped being one
in step B (ADR 0078) and is now steel, plate and glass. **The material changed and the
response did not.**

**It is not "physics".** The question asked was whether this needed a real collision
model or whether a flat velocity cut would do, and a flat cut does — with one
refinement. Reflecting the normal component is three lines in the pure `HullBarrier`
that was already computing exactly that component to remove it, so the bounce is
*cheaper* than the slide it replaces, not more expensive. No engine bodies, no contact
manifolds, no mass, and no restitution solver.

**The refinement, and it is what keeps this legal.** A flat "lose 20% of your speed"
charged whenever the hull is against a surface compounds: a ship sliding along a wall
touches it dozens of times a second, and 20% a frame is a full stop in under a second.
Measured — with the penalty charged per frame the gate's four-second dive at the
roadway brings the ship down to hull speed, which is a wall that stops you and is the
one thing ADR 0087 forbids the shell from being. So the cost is charged **once per
contact**, and scaled by the normal share of the incoming speed so that brushing a wall
is nearly free.

**Why the throttle rather than the speed.** `_speed` is not rate-limited upward —
acceleration is paced by the throttle's own travel and `brake_limited` only limits going
down — so cutting the speed alone is erased on the next frame and the penalty is
invisible. Cutting the throttle spends the hull's own `accel_seconds`, which is a taxi's
3.2 s and a capital's 7. That makes the cost *a property of the ship you are flying*
rather than a number, and it is what "rewarded for flying straight" actually buys.

**Why a carried rebound rather than an impulse.** Applied in one frame the reflection is
a displacement of a few metres and reads as a stutter. Over a couple of tenths it reads
as coming off a wall. The rebound is a decaying velocity the ship carries, added to its
own; nothing integrates and nothing persists past the fade.

**This does not touch the lane** (ADR 0064). The lane's soft push and its edge speed
penalty are what keep you near your centre-line and are unchanged. The bounce is the
*building*, and the two are composed exactly as ADR 0087 composed them.

## What this forbids

- **Do not charge the bounce per frame.** Once per contact, on the rising edge. If a
  ship flying along a wall can be brought to a stop, this is wrong.
- **Do not bounce along the surface.** Normal component only. A wall may deflect and
  may never stop.
- **Do not reflect the nose.** The velocity bounces; the basis does not. Nothing may
  give the player's ship a heading (ADR 0012's mechanism, ADR 0011's clamp).
- **Do not reach for a physics engine, a rigid body, or a collision shape.** The
  LOD/collision invariant is untouched: this is arithmetic against a path and a
  section, and nothing on the road is queryable.
- **Do not cut `_speed` alone** and think the penalty landed. It is erased on the next
  frame; the throttle is the lever.
- Do not apply the bounce to the world boundary, a system's faces, or an approach
  envelope. ADR 0011's magnitude-only clamp still governs those and must not become a
  wall.
