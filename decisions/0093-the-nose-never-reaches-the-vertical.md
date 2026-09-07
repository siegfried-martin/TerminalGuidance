# ADR 0093 — The nose never reaches the vertical, and the boom follows it less and less; a wall opens where a ramp goes through it

*Status: accepted · 2026-09-05 · the camera half is the human's own proposal · refines
ADR 0091's aperture*

**Decision 1 is superseded by ADR 0096**: a wall is open exactly where another tube passes through it, by one rule shared with the collider. The camera half stands.

## Decision

### 1. A wall opens where a ramp goes through it; a roadway opens for the whole merge

An aperture is still a stretch (ADR 0091), but the stretch is measured differently for
the two kinds of face.

- A **roadway** opens over the whole span the ramp straddles it. The ramp really is
  rising through the floor for all of it, the floor is metal, and a long slot reads as
  the merging lane it is.
- A **wall** opens `junction_wall_opening_metres`, centred on where the ramp's own curve
  crosses. The rest of the ramp passes behind the glass, at a separation of nothing.

And a ramp opens **the face opposite the one the building opened**, over the same
stretch — not the face pointing at the building's centre-line.

### 2. The nose never reaches the vertical

The ship's forward is clamped to `ship/max_pitch_deg`, and its reticle with it.

### 3. The camera's boom follows the nose less and less

The chase camera's boom keeps the subject's bearing and takes a **compressed** share of
its pitch: near the horizon it follows all but exactly, and at the nose's own limit it
has stopped at `camera/ship_pitch_ceiling_deg`. The boom and the look direction use the
same compressed frame, so the subject stays centred and pitches inside the frame.

A quarter-sine, which needs no second knob: it leaves the horizon at `ceiling / limit`
of one-to-one and arrives at the ceiling with zero slope. Empty keys mean a rigid boom,
which is what the missile and turret views keep.

## Why

**1 — because a ramp leaves ALONG the road it is on.** ADR 0070 makes every ramp
tangential where it diverges, so its outer edge is flush with the highway's wall from
the divergence and only gets clear of it a kilometre later. Measured as "where the ramp
is in the way", the opening ran **900 to 1900 metres** — two to five bays of missing
glass at every exit, which from the seat is the highway having lost a side. *"Still lots
of places where the glass disappears."*

What has to be open is where the *ship* goes through, and that is short. The ramp's own
outer wall and the highway's are coincident there, so nothing shows.

**The face bug is the same class of error as ADR 0091's.** A ramp's own opening was
asked geometrically — which way the building's centre-line lies — and a building's
centre-line is the *spine*, while a ramp sits beside a *carriageway* 120 m off it. So the
answer came back sideways: every on-ramp opened a side wall and kept the roof it had to
come up through. The two faces are opposite sides of one hole, and a ramp is tangential
where it joins, so "opposite" needs no measurement at all.

**2 and 3 — because the world has an absolute up, and the human named the fix.**

> *"Since there's an absolute 'up' direction, panning the camera up can lead to
> inconsistent behavior when you near the vertical axis. I thought about having the
> vertical camera fixed and only show the ship move up and down, but that model really
> only works if there is a pretty limiting max angle the ship can point up or down. So I
> thought, what if we do a combination of both? Have a pretty high max angle but less
> than 90 degrees, and as the ship rotates more in the up or down direction the camera
> will pan less and less toward the new direction?"*

It makes sense, and it is better than either half alone. Near the vertical, `up` stops
being a usable reference: `basis_from_forward` has to swap its reference axis, yaw
collapses into roll, and a boom on a near-vertical nose swings through the horizon. Both
of the obvious single answers are worse — a **fixed** vertical camera needs a punishing
pitch limit to stay legible, and a **rigid** boom has the singularity in it at any limit.
Together they give a steep, usable nose and a camera that never goes near the place the
problem lives.

**The reticle is clamped with the nose** for the reason the road's cone clamps it: a
control that can be parked somewhere the ship may not go is a control that lies
(ADR 0035).

It is also the same bargain the road already makes. `cruise_turn_clamp_deg` bounds the
nose to 18 degrees off the road and nobody experiences that as a restriction, because
what it buys — a camera that frames the road — is worth more than the freedom it costs.

## What this forbids

- **Do not open a wall for the whole stretch a ramp is inside a building.** That is the
  glass going.
- **Do not shorten a roadway's opening to match.** A ramp is genuinely rising through
  the floor for the whole merge.
- **Do not ask geometry which face a ramp opens.** It is the opposite of the building's,
  and a building's centre-line is not a carriageway's.
- **Do not let the nose reach 90 degrees**, and do not add a code path that handles the
  vertical instead. The whole point is that the case does not arise.
- **Do not let the reticle go where the nose may not.**
- **Do not make the boom rigid on the ship view**, and do not compress the missile's or
  the turret's: a missile's whole job is pointing wherever the player asks, and the
  turret has `pitch_share` for its own, different reason.
- Do not add a second curve knob. The ceiling and the limit are the two numbers; the
  shape between them is not a third.
