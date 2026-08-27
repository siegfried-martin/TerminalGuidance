# ADR 0040 — Manual ship flight lands; the autopilot becomes a mode the player leaves

*Status: accepted · 2026-08-26 · the human lifting their own scope deferral, not a design reversal*

## Decision

The player can fly the mothership. `T` hands the ship between the autopilot and
manual control; the autopilot behaviour is unchanged and still starts every run.

Under manual control:

- **`W` / `S` are a throttle**, not a boost. They move a lever that *stays where it
  is put*: `W` climbs towards full over `ship/manual_accel_seconds`, `S` falls to
  zero over `ship/manual_brake_seconds`, and releasing both holds the current
  speed. This is the difference from the missile, where the same two keys are a
  burst and a hold that both spring back.
- **`A` / `D` are held lateral thrusters**, not the missile's one-press dodge.
- **The mouse steers**, through the same reticle instrument the missile uses
  (ADR 0035), extracted to `ReticleSteering` so the two vehicles differ in their
  numbers rather than in their model.
- **The ship's top speed is clamped against `missile/base_speed`** by
  `ship/manual_speed_ceiling_fraction`. The clamp is on the whole velocity vector,
  so thrusting sideways at full throttle cannot sum past it either.
- **The ship stops reading input while a missile is being ridden.** It keeps its
  velocity and coasts. Both vehicles are on WASD and only one of them is being
  flown at a time.

## Why

`COMBAT_POC_IMPLEMENTATION.md` lists manual flight as out of scope *and* carries a
Scope Note saying, in as many words, that its absence is "a scope deferral, not a
design decision" and that no ADR may assert the ship is autopilot-only. This ADR is
the human electing to lift that deferral. It is recorded because the *shape* of
manual flight is a real decision even though its existence never was.

A throttle rather than a boost is the human's own framing — "like you might expect
for a space ship game". It is also the right one: the missile's speed verb is a
burst because a missile has eight seconds and one job, while a ship's is a state
because a ship is going somewhere. Making them behave differently on the same two
keys is the point, not an inconsistency.

Sharing the reticle with the missile was the alternative to giving the ship a
direct rotation. Direct rotation is cheaper and would have been fine, but then the
two vehicles teach different things about how the game responds to a mouse, and
the ship — which the player will spend far more time in — would be teaching the
wrong one.

The speed clamp is in code because `CLAUDE.md` says the hierarchy is structural:
"lasers > missiles > ships. Nothing may violate it by construction." A comment in
the tuning file is not a construction. A ship that can match a missile does not
produce a bug report; it produces "the POC stopped being fun", which is the
hardest possible failure to diagnose.

The alternative to the coasting rule was to let the ship keep flying on the same
keys while the player rides a missile. That is not a design option, it is a bug
with two vehicles in it.

## What this forbids

- **Do not grow the autopilot.** ADR 0013 still governs it: a heading hold plus
  station-keeping, which does not path, avoid, arrive, or decide. Manual flight
  existing is not a reason to make the autopilot smarter — it is the reason it
  never has to be.
- Do not remove the speed clamp, and do not move it into a tuning comment. Raising
  `ship/manual_max_speed` past the ceiling must keep doing nothing.
- Do not make the ship's throttle spring back to zero, and do not give the missile's
  boost a persistent lever. The asymmetry is the decision.
- Do not add a flight model — inertia, drag, angular momentum, thrust vectors. ADR
  0003 rejects that for the missile and the reasoning transfers whole: the player
  should not have to model the vehicle in their head. The ship is heavier than the
  missile because its numbers say so, not because its physics differ.
- Do not let anything other than player input take the ship off manual control, or
  put it back on. That is ADR 0014's no-interdiction rule reaching the ship's
  control mode, and an NPC that "forces you back to autopilot" is interdiction with
  an extra step.
- Do not add rock collision for the ship on the strength of the missile having it
  (ADR 0038). Killing the player's ship on a rock it drifted into is a condition
  imposed, not a decision made — it needs its own ADR and its own argument.
