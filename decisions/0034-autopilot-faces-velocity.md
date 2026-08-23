# ADR 0034 — The combat autopilot faces its direction of travel, not the target

*Status: accepted · 2026-08-23 · human direction during the first flight session*

## Decision

While arcing at standoff, the mothership's nose follows its own velocity vector.
It does **not** point at the target. Missiles launch along that heading, which
means they leave the rail across the target rather than at it.

A screen-edge target indicator (`FlightOverlay`) exists because of this: with the
nose off-target, the player needs to be told where the target is.

## Why

With the nose held on the target, a missile fired along the ship's heading was
already pointing at the thing it was meant to hit. The player's job collapsed to
"hold still for three seconds", and the fuse never came under pressure — every
shot was a hit with no turn required.

`PROJECT_OVERVIEW.md` says launch geometry should vary every shot, and that a
faster turn-to-target converts directly into range and rate of fire. Neither is
true if the launch geometry is always zero. Facing along the arc makes the turn
mandatory and makes its size depend on where the ship happens to be — which is
the procedural variety the design was counting on getting for free.

It also matches what the ship is physically doing. A ship holding a standoff arc
is moving sideways relative to its target; pointing the nose at the target while
travelling perpendicular to it looked wrong on screen and cost nothing to fix.

## What this forbids

- Do not re-point the mothership at the target "so the player can see it". The
  screen-edge indicator is the answer to that problem.
- Do not aim the missile at launch. It leaves along the ship's heading; steering
  it is the game (ADR 0001).
- ADR 0013 is unaffected. That is the *travel* autopilot — a heading hold on a
  designated object at cruise scale. This is the combat arc, a different
  behaviour at a different scale, and neither may grow into the other.
