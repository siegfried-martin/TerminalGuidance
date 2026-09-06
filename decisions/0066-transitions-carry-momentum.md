# ADR 0066 — Transitions carry momentum

*Status: accepted · 2026-08-30 · from the human's first play session on the road*

## Decision

Two places where the game hands control back or changes what the ship can do, and
one rule for both: **the ship is already moving, and speed changes take time.**

**The cruise drive spools.** Joining the road winds the ceiling up from hull speed to
cruise over `cruise_spool_seconds`; leaving it winds down over
`cruise_spool_down_seconds`. The blend is on the *ceiling*, not on the velocity, so
the throttle keeps meaning what it meant.

**A departure leaves already flying.** Undocking sets the ship on the reflection of
its arrival — same bearing, vertical component flipped — at
`depart_speed_fraction` of its top speed, with the throttle set to match.

## Why

**A snap is not a transition, it is a cut.** Crossing a portal used to take the ship
from 30 m/s to 140 in one frame, and arriving used to do the reverse. Both read as
teleports rather than as an engine, and the second one is worse: a ship that arrives
in a system still doing cruise speed has not left the road, and one that drops to
hull speed instantly has been caught in a net.

**The spool is not entry ceremony and must not become it.** ADR 0057 forbids an
alignment, docking, or confirmation sequence at a portal, and `portal_entry_seconds`
is pinned at zero for the reason that ten seconds of ceremony is a quarter of a local
leg. The spool is a different thing and the distinction is checkable: through the
whole wind-up the player is already past the aperture, steering, holding their own
throttle, and free to turn round. **What takes time is the ship doing something, not
something being done to the ship.** If that ever stops being true, it has become the
thing 0057 forbids.

**A departure that hands the ship back at rest starts every visit in a hole.** The
ship arrived pointing down at a surface. Releasing the controls in that attitude with
no speed means the first ten seconds of every single visit are the same climb out,
and it is not interesting the second time. The reflection is the cheapest honest
answer: it is where the ship *would* be if it had flown back out the way it came, it
needs no camera move and no animation, and the planet is behind you on the first
frame.

The throttle is set to match the speed rather than left at zero for the same reason —
a ship given velocity and no throttle bleeds it off over the next second, and the
takeoff reads as a shove instead of as flying away.

## What this forbids

- Do not implement the spool by ramping the velocity. It is a ceiling, and the
  throttle stays the player's the whole way through.
- Do not gate anything on the spool: no waiting, no reduced steering, no locked
  controls, no "drive charging" that has to complete before something else may
  happen. The moment the player is waiting rather than flying, it is entry ceremony
  and ADR 0057 forbids it.
- Do not raise `portal_entry_seconds` to get a wind-up feel. It is a different value
  measuring a different thing and it is pinned at zero.
- Do not carry spool state across a session, a dock, or a hull change. It belongs to
  the drive that is running now.
- Do not add a cutscene, camera move, or animation to a departure. It is a velocity
  and a heading.
- Do not turn the departure into a menu choice ("which way out?"). The reflection is
  the answer precisely because it needs no decision.
