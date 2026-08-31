# ADR 0064 — The lane pushes you back; the world only slows you down

*Status: accepted · 2026-08-29 · from building exploration POC step 6*

## Decision

There are **two soft boundaries in the game and they behave differently on purpose**.

**The system boundary** (ADR 0011, as amended by 0062) scales a speed *ceiling* and
never touches the heading. Magnitude only, never direction, and structurally so:
`BoundaryField` returns a scale and has no heading to return.

**The lane boundary** on a road scales the cruise drive's ceiling *and* adds a
velocity back toward the centre-line. It is a nudge that grows with depth, it never
reaches a magnitude that could overpower the drive, and the player can keep flying
outward through it for as long as they like.

The two are **composed, never merged**: a ship out of its lane inside a corridor is
subject to both, and the road's push does not exempt it from the world's clamp.

## Why

They are answers to different questions and merging them would get one of them
wrong.

**Leaving the world is not a mistake, it is a decision** — the player wants to be
somewhere the game does not render, and the honest response is to make going there
cost more and more until it costs everything, while never touching what they
actually asked for. Pushing them back would be the game flying their ship.

**Leaving a lane is a lane-keeping error on a road, and a road correcting you is
what a road is for.** The lane is a place inside the world, not its edge. Both sides
of it are rendered, both sides are legal, and there is nothing on the far side to
protect the player from — so the correction is free to be a physical one, and
`EXPLORATION_DESIGN.md` specifies it as exactly that: *"drifting out slows the
player and pushes them back."*

The push is written as a closed form — `sqrt(2 a s)`, the velocity you would have
from accelerating inward from that depth — rather than integrated per ship. That is
not a shortcut: it means the ship carries no drift state that could survive leaving
the road, and editing the value in the F2 panel takes effect on the frame it is
saved rather than after the next excursion.

## What this forbids

- Do not give the system boundary a push, a nudge, or a bounce. ADR 0011's clause is
  unchanged and this ADR is the reason it looks inconsistent with the lane.
- Do not remove the lane's push to "make it consistent" with the world's. Consistency
  between two different things is not a virtue.
- Do not let the lane's push reach a magnitude that can stop the player, reverse
  them, or overpower the cruise drive. If the player can be *held* by it, it is a
  wall, and a wall on a road is the conveyor this whole design rejects.
- Do not apply the lane's push along the road's axis. It corrects your line; the
  speed penalty is the only thing that touches your progress.
- Do not integrate the push into per-ship drift state. It has to vanish the instant
  the ship leaves the road.
