# ADR 0083 — An exit is a sign you click, and taking it is a rail rebind

*Status: accepted · 2026-08-31 · from the human's "while autodocked the player can click on an exit sign to get off on that exit"*
**The sign, and clicking it, are superseded by ADR 0091.** An exit is a button on the
strip along the bottom of the screen: picking a sign with the reticle could not be
made to work, because the reticle is a direction from the SHIP and it is drawn
projected from a camera behind and above it. The principle below is unchanged — an
exit is chosen at the moment it can be seen, nothing is planned or routed, and
taking one is a rail rebind that happens when the ramp arrives.

## Decision

**Exits are chosen by clicking a sign on the road.** Each off-ramp hangs a sign on the
mainline's structure `exit_sign_lead_metres` before the opening it makes, naming the
place that exit serves.

**A sign is clickable only while berthed.** Flying, a click that changed which road you
were on would be autopilot growth (ADR 0013). Berthed, the ship is not being flown, the
reticle is free, and it is a cursor.

**The pick is by the reticle**, not by a screen-space mouse cursor: the mouse is
captured while steering, and the reticle is already how this game points at a thing in
the world (ADR 0035). While berthed the stick and the mouse move the reticle inside
`berth_look_cone_deg` and move nothing else.

**Clicking takes the exit; the berth rebinds when the ramp arrives.** The ramp begins
ahead of the sign, and a rail that pulled the ship back onto the ramp's start would be
a route rather than a rebind. `RoadBerth` holds the taken exit and swaps rails the
moment the ramp is actually under the ship.

**The lead distance is a real cost, on purpose.** At cruise there is a point past which
the sign is behind you. Reading it in time is a piloting act, and missing it costs one
hop off and back on — which is the price `EXPLORATION_DESIGN.md` already sets for a
missed turn.

## Why

This looks like routing, and ADR 0013 (autopilot is a heading hold) and ADR 0067 (no
junction logic) both forbid routing. It is not, and the difference is where the
decision lives: **a sign is an object in the world, visible before commitment, chosen
at the moment it can be seen.** The player decides; the road changes which rail it is
on. Nothing is planned, nothing is ranked, no destination is held anywhere, and there
is no list of places in the game to pick from.

The bound to hold, stated exactly: **the berth follows the centre-line of the deck it
is bound to, and a click rebinds it to one other deck, once, at a fixed place.**

**It is smooth by construction rather than by tuning.** ADR 0070 already requires every
ramp to be tangential to the mainline where it leaves, so a rebind at that point has no
angle to absorb. That ADR was written about ship handling and turns out to be what
makes this safe — which is worth noticing, because it means the smoothness cannot be
lost by a tuning change without ADR 0070's own gate catching it first.

Signs are a small extension rather than new machinery: `Portal` already mounts a
world-space destination label. An exit sign is that idea moved onto the structure, with
a pick radius.

> *Amended 2026-08-31, from a play session: the decision is unchanged and one clause
> was missing.* **A sign is only live for an exit off the road you are on.** The two
> carriageways share one building with glass down the middle, so the oncoming side's
> signs are perfectly visible from here, and clicking one bound the berth to a ramp
> leaving a road going the other way. The test is the one the union already uses (ADRs
> 0072 and 0081): a ramp whose direction where it leaves is outside the steering cone
> around the road you are held against is not a road you could take. No new flag, and
> it stays right when a road crosses at an angle.

## What this forbids

- Do not make a sign clickable while flying. That is the line between a berth and an
  autopilot.
- Do not add a destination list, a route, a map pick, or a "next exit" the game
  chooses. The only way to take an exit is to see its sign and click it.
- Do not rebind on the click. The swap happens where the ramp starts, and the ramp is
  tangential there.
- Do not let the berth hold more than one taken exit, or hold one across a release.
  Anything that survives is a plan.
- Do not shorten `exit_sign_lead_metres` to "fix" a missed turn. Missing one costs a
  hop off and back on, and that price is the design.
- Do not make a sign live for a road you could not steer onto. Visible is not
  pickable, and the oncoming carriageway is visible from every metre of this one.
- Do not fix a jump at a rebind by smoothing the berth. If a rebind jumps, the ramp is
  not tangential and ADR 0070 is the thing that is broken.
