# ADR 0039 — The missile's three verbs: boost, brake, and a dodge on a cooldown

*Status: accepted · 2026-08-26 · replaces the held slide of ADR 0037 after one session of flying it*

## Decision

The missile has three verbs on top of reticle steering, and none of them is held
except by the two that are:

- **Boost** (W, held) — multiplies forward speed from a reserve.
- **Brake** (S, held) — multiplies forward speed *down* and turn rate *up*. It
  overrides boost while both are held.
- **Dodge** (A / D, one press) — a single discrete lateral displacement of
  `dodge_distance`, eased out over `dodge_seconds`, then a cooldown. **Left and
  right only.** There is no vertical dodge and no held strafe.

This **supersedes ADR 0037**, which gave the missile a held, ramped lateral slide
on all four of WASD. Detonate takes Space back, since boost vacated it.

## Why

The slide was tuned and flown, and a held lateral axis makes the missile a thing
you *position* rather than a thing you *aim*. A press-and-cooldown dodge is a
decision with a cost and a moment; a held axis is just a second steering input, and
the missile already has one that works (ADR 0035). The chase camera also reads a
discrete flick far better than a drift, which was observed rather than predicted.

Dropping the vertical axis is part of the same point. Up/down slide competed
directly with the reticle for the same intent, and having both meant two ways to
move the missile up with different feel — the sort of ambiguity ADR 0003 exists to
prevent.

Brake is new and is the more interesting half. It makes speed and agility a live
trade the player works during a flight rather than a number set before it, and it
costs range for free: the fuse is a timer, so flying slower means arriving less far
(ADR 0002). No reserve, no meter, no cooldown — the cost is already structural.
It beats boost when both are held because the verb that recovers control should
win over the verb that commits to a line.

Boost keeps its reserve. Nothing about it changed except the key.

## What this forbids

- Do not restore a held lateral axis, and do not add a vertical dodge. That is the
  decision this ADR exists to make; ADR 0037 is the record of the alternative.
- Do not let a dodge be interrupted, queued or stacked. A press during a dodge or
  during its cooldown is discarded, not buffered — buffering makes mashing optimal
  and the cooldown decorative.
- Do not give brake a reserve, a meter or a cooldown. Its cost is the range it
  spends, and adding a second cost double-charges it.
- Do not let brake raise `reticle_max_angle_deg`. Brake changes how fast the nose
  chases the reticle, not how far the reticle may be parked from it — those are
  different things and conflating them makes the cone meaningless.
- `dodge_cooldown_seconds` below `dodge_seconds` degenerates into a held strafe.
  Nothing enforces it, deliberately, but do not ship a default that does it.
