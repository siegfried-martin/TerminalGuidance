# ADR 0045 — Every vehicle shares one horizon; nothing accumulates roll

*Status: accepted · 2026-08-27 · human verdict after playing the combat POC: "I like the fact that all ships are kept on the same plane, I think the ability to rotate would be too confusing"*

## Decision

No vehicle in the game accumulates roll. "Up" is the same direction for every ship,
every missile, and every camera, always.

To be precise about what this does and does not say, because "kept on the same
plane" is easy to over-read:

- Ships and missiles **may pitch and climb freely.** Space is three-dimensional and
  a fight sprawls vertically. This is not a 2D plane.
- What is fixed is the **horizon**: the basis every vehicle steers in is re-derived
  from its forward vector and world up every frame, so roll is never carried
  (`FlightGeometry._level_roll`). Bank a missile through a hard turn and it comes
  out the far side with the same "up" it went in with.
- A **cosmetic** bank on a mesh is allowed and probably wanted. It must never enter
  the basis used for steering, hit testing, or the camera.

## Why

This started as a missile-steering property, not a world rule. ADR 0003 chose
direct screen-space steering over vector thrust, and roll-free bases fell out of
it: a rolling missile makes "up" ambiguous and turns direct steering into a flight
model the player has to hold in their head. Manual ship flight (ADR 0040) inherited
the same instrument, so the ships came out level too — as a side effect, not a
decision.

The human then played it and named it as one of the things that works. That
promotes it from an implementation detail to a rule, which is the point of writing
it down: the next session that adds a vehicle will otherwise reach for a roll axis
because every other space game has one, and the reason not to is nowhere in the
code.

It also pays for itself twice over elsewhere. A shared horizon is what makes the
screen-edge target indicator legible, what makes "left" and "right" mean the same
thing in the missile and in the ship, and what will make a station or a docking
approach readable without an artificial horizon instrument. The cost — that a
barrel roll is not available — is a cost only for a dogfighting game, and ADR 0044
says this is not one.

## What this forbids

- Do not add a roll input, on any vehicle, at any scale. Not for the ship, not for
  the missile, not for a future fighter (ADR 0046).
- Do not store or propagate a basis that carries roll. `steer_basis` and
  `basis_from_forward` re-level deliberately; a caller that wants "just this once"
  is the start of the flight model ADR 0003 rejects.
- Do not read a cosmetic bank back into gameplay. If a mesh leans through a turn,
  that lean lives on a child node and nothing queries it.
- Do not build content whose challenge is orientation — a corridor that must be
  entered rotated, a docking port that requires a roll to align. That is the
  "confusing" this decision exists to prevent.
- This is not licence to flatten the world. Vertical separation in a fight is
  wanted; the disc height in the exploration numbers chain is sized against it.
