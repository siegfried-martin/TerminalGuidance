# ADR 0037 — Side thrusters are a bounded slide, not vector thrust

*Status: accepted · 2026-08-25 · asked for during the first tuning-panel session, and checked against ADR 0003 before building*

## Decision

The missile gets side thrusters on WASD. They apply a **lateral slide** — a
bounded offset in the missile's own frame that moves toward the commanded speed at
one tuned rate and back to zero at another. Releasing the key returns the slide to
zero. Nothing is integrated: there is no lateral velocity that survives input.

Boost lands in the same change, on a held button drawing from a reserve that does
not refill in flight (`missile/boost_seconds`, `boost_regen_per_sec = 0`).

This **clarifies ADR 0003 rather than superseding it.** Steering remains direct
screen-space reticle steering. Strafe is a second, translational verb layered on
top of it, and boost was already named in 0003 as part of the scheme.

## Why

ADR 0003 rejects "vector thrust" and "inertia the player has to model in their
head". Side thrusters are literally lateral thrust, so the question had to be
asked rather than assumed.

What 0003 actually objects to is **momentum that outlives the input** — the
Newtonian coast that makes a player integrate their own velocity to know where
they will be. A slide that stops when you let go never asks that. The player's
model stays "the missile goes where I point, and it can also lean", which is the
Star Fox Arwing anchor named in `CLAUDE.md`, not the Elite-with-assist-off one
0003 was written against.

Ramp and release are separate values because they are the difference between a
lane-snap and something with weight, and because snappy-on / slower-off is a real
arcade idiom that would be inexpressible with one shared time. Both default to
under 0.15 s and both may be set to zero.

The alternative — true thrusters with acceleration and damping — was rejected as a
direct supersede of a decision accepted two days earlier, for a feel nobody has
asked for yet. It remains available: it is a change to `_apply_strafe` and a new
ADR, not a rewrite.

## What this forbids

- Do not give the slide momentum that outlives the input. No damping coefficient,
  no coast, no velocity that persists after `move_toward` reaches zero. The moment
  that appears, this ADR is superseded rather than extended.
- Do not let strafe rotate the missile or accumulate roll. It translates only;
  roll ambiguity is what ADR 0003 and `FlightGeometry._level_roll` exist to stop.
- Do not add forward/back on the strafe axes. Forward speed is `base_speed` and
  boost, and a throttle would make the fuse stop meaning range (ADR 0002).
- Do not let `base_speed * boost_multiplier` exceed whatever a laser ends up
  doing. The speed hierarchy in `CLAUDE.md` is structural.
- Boost is held, never toggled. A toggle makes it a mode rather than a spend.
