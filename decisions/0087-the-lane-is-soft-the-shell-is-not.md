# ADR 0087 — The lane is soft; the shell is not

*Status: accepted · 2026-09-05 · narrows ADR 0064, and is the fix that plan predicted*
**The "it never bumps" clause is superseded by ADR 0090.** The road bounces: the speed
going into a face comes back out of it, and a bounce costs the throttle once per
contact. Everything else below stands, and one clause of it is what keeps the bounce
legal — the correction is still NORMAL-ONLY, so motion along a surface is untouched and
a wall may deflect but may never stop. The sliding stop described here is
`structure_bounce_restitution = 0`.

## Decision

**A hull does not pass through the road's structure, from whichever side it is on.**

`HullBarrier` is a surface: inside the building it holds the ship in, outside it holds
the ship out. It is measured against the hull's own half-section, exactly as the lane
is (ADR 0068), so the ship is held when its *side* reaches the wall rather than when
its centre does.

**It never bumps.** *(Superseded by ADR 0090 — it bounces, and the bounce costs the
throttle once per contact. What survives, and what ADR 0090 depends on, is the clause
in bold.)* There is no impulse, no bounce, and no stop. The hull is put back
against the face it was crossing and the component of its velocity going *through*
that face is dropped; **everything along the surface is untouched**, and the forward
speed the throttle drives is never reduced. A ship held against the roadway keeps
flying down the road at the speed it had.

Three things are deliberately not held, and each is a way through rather than an
oversight:

- **The faces a ramp pierces.** An aperture is a hole in both directions — it is the
  way on and the way off.
- **The flared mouth at a portal.** The section pinches to the portal's own opening
  there, and a hull held against a shrinking tube would be funnelled by geometry. A
  mouth is governed by the lane's soft push, as it always was.
- **The open ends of a ramp**, where it meets the road it serves.

**The lane's push is unchanged.** ADR 0064 still describes the lane: a slope back
toward the centre-line, an incentive rather than a wall. The two are composed, never
merged — the lane keeps you near the middle of your carriageway, and the shell is the
building around both of them.

**The median is part of the shell**, holding a hull on the side of the pane it is
already on. A hull still astride the pane is left free rather than pinned to a side it
never chose.

## Why

**A slope loses to a ship pointed through it.** At cruise 250 inside the 18-degree
steering cone a ship carries 77 m/s downward; `lane_edge_push_accel` at 8 m/s² is worth
about 35 m/s at the roadway. So the floor of a ramp was something you sank through and
came out the bottom of — and once outside the lane and past the end of the deck, the
union had nothing to hand you and the road dropped you. Reported from the seat as *"I
was able to go through the floor of the on ramp and it looks like it took me off
altogether."*

That is not a soft boundary. It is a missing one, and raising `lane_edge_push_accel`
until it holds would have made the *lane* a wall — which is the thing ADR 0064 exists
to forbid, and which would have cost the lane its whole character on the axis where it
was working.

**`HIGHWAY_STRUCTURE_PLAN.md` predicted exactly this** and named the honest fix:
*"if it is not, the honest fix is narrowing ADR 0064 to 'the lane is soft, the
structure is not', not widening the push."* This is that narrowing.

**Why the median was already right, and why generalising it is the whole change.** The
human's own framing: *"the no bump barrier was correct for the middle divider, let's
just make that for all inside surfaces for a ship on the highway and for all outside
surfaces for a ship outside the highway."* The median only *appeared* to hold because
it is 240 m away across a lane where the push has room to work; the floor is 75 m away
and it did not. One number differed, not one rule — so the rule is stated once and
applied to every surface.

**A barrier is not interdiction.** The target-experience rule is about pressure
*imposed on the player by something that decided to*. A wall decides nothing: it is
terrain, it is visible before you reach it, and it is where it was the whole time. What
would break the rule is a road that *stopped* you — and this cannot, because it never
touches motion along the surface.

**Which building governs is "the one you are deepest inside of."** Buildings overlap
where roads cross. Picking the tightest instead pinned a ship flying down the middle of
the mainline against the wall of an interchange ramp passing through it, which is being
held by a building you are not in. Deepest-inside is also right from outside, where the
same measure picks the nearest wall.

**It is stateless.** The map decides which side of the shell the ship is on *before* it
moves and the ship enforces it *after* — so nothing has to remember which side of a
wall anything was on last frame, and a hot reload or a teleport cannot leave a stale
side behind.

## What this forbids

- ~~**Do not make the shell bump.**~~ *(Retired by ADR 0090.)* What still holds: **no
  reduction of speed ALONG the surface**, ever. If a ship flying beside a wall can be
  brought to a stop by it, this is wrong.
- **Do not widen ADR 0064's push to do this job.** The lane is soft and stays soft; a
  lane you can be stopped by is still wrong.
- **Do not hold an aperture, a portal flare, or the open end of a ramp.** Those are
  the junctions, and a highway whose junctions are closed is not a highway.
- **Do not give the structure a physics body.** Nothing here is a collision shape,
  nothing is queryable, and the LOD/collision invariant is untouched — this is
  arithmetic against a path and a section.
- **Do not let the ship look the road up.** The barrier is handed down each frame the
  way `cruise` is, in the ship's own frame. A point cached across a floating-origin
  recentre is the one thing that would break (ADR 0020).
- Do not use it to stop a player leaving the map, or a system, or anything that is not
  the road's own structure. ADR 0011's magnitude-only clamp still governs the world's
  edges and must not be replaced by a wall.
