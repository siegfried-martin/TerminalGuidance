# ADR 0063 — Playable space is a union of regions, and a region says where it does not apply

*Status: accepted · 2026-08-29 · from building exploration POC step 5*

## Decision

The map's playable space is a **union of regions** — a system disc, a corridor, and
whatever comes later. Two composition rules, and no third:

```
within a region   constraints INTERSECT — you are inside only if inside all of them
between regions   regions UNITE — you are outside only if outside all of them
```

The region you are *least* outside of governs: it supplies the depth, the outward
normal, the name the HUD prints, and the constraint list everything else reads.

A region with limited extent declares itself **inapplicable** outside that extent
rather than growing an end cap. Inapplicable is not the same as outside: an
inapplicable region is skipped, and the neighbouring region answers instead.

Regions carry their own placement. A map is a list, not a hierarchy.

## Why

This is ADR 0062's *"a disc is one constraint set; the whole-map boundary later is a
different set, not different code"*, built. Two systems and a corridor arrived one
step later and the single-shape field could not express them, exactly as predicted.

**The union is not optional, and getting it wrong is invisible in code review.** A
flat list of every surface fails in two ways that both look like polish bugs:

- The volume glows red while you fly up the middle of an opening, because the rim is
  "still there" despite having a hole in it.
- A ship drifting wide in a corridor is told to fly *backward into the system it
  left*, because the rim's normal is the only one on offer. That is not a cosmetic
  error; it points the player the wrong way at the moment they are asking for help.

**No end caps, because a cap is a wall reported where two regions merely meet.** The
corridor's ends are not boundaries — they are where the corridor becomes a system.
Cap them and the far end of a legal four-kilometre route paints red as you approach
it, and `distance_to_edge` reports the distance to a surface the player can fly
straight through. Inapplicability says the true thing: *this region has no opinion
here, ask the next one.*

**A hole is a hole in a wall, not a tunnel through space.** The first version of the
disc dropped its rim constraint wherever a point lined up with an aperture, at any
distance. A system then claimed an unbounded tube along its own bearing, and a ship a
kilometre outside still read as being in it. The opening is angular and it is *in the
wall*: past the rim there is no hole to be in, and what is out there belongs to the
corridor.

## What this forbids

- Do not add a boundary surface as a special case. Add a region, or a constraint to
  one.
- Do not give a region an end cap where it meets another region. Use `applies_to`.
- Do not intersect regions, or take the deepest across them. Between regions the
  shallowest wins, or the map becomes the intersection of its pieces — which is
  empty.
- Do not let a region answer outside its own extent, including "helpfully" clamping
  a point onto itself first.
- Do not resolve an opening in a wall by testing the query point's own distance from
  an axis. That widens the hole with distance and hands the region space it does not
  own.
- Do not put the boundary's placement in the scene tree and its shape in the region.
  One of them will be updated without the other, and the picture and the rule will
  disagree.
