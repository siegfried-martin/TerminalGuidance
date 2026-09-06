# ADR 0057 — The highway is a place, not a travel mode

*Status: accepted · 2026-08-29 · supersedes ADR 0009; from `docs/EXPLORATION_DESIGN.md` and the human's direction that the exploration docs supersede prior decisions*

## Decision

Travel happens on a **road network**: physical tubes in space, entered and left
through portals, on which a cruise drive works and nowhere else. The road is a
place inside the one continuous space, built from geometry the player flies
through, and it replaces ADR 0009's "three throttle scales" with two: normal
flight everywhere, and cruise on the road.

ADR 0009's *reasoning* is unchanged and is the reason this is the shape it is. Its
forbid clause was written to stop a loading screen in a costume, and the road is
checkable against a restated version of exactly that:

- **No camera cut.** The player flies through the portal aperture; nothing fades.
- **No scene load, no arena instance, no separate level.** The road is geometry in
  the same space as everything else.
- **No non-interactive transit.** The player steers within a cone off the road
  axis, holds their own throttle, and can leave the lane at any time. Drifting
  out is slow, never stopped.
- **The surrounding space stays rendered and real.** The lane is visually open;
  the system and the war outside it are visible from inside the tube. Events
  happen *beside* the road, never on it.
- **Floating origin and collision-on-real-meshes-only apply inside the tube**,
  exactly as everywhere else.

## Why

ADR 0009 was written against Starfield's fast travel and it was right about it.
But it left the travel layer with no answer to the four things that pull against
each other — vastness, population, directness, and one developer's ability to
render any of it. A road network answers all four with one idea: roads concentrate
traffic, leave the space between them empty, are the direct route by construction,
and bound what must be rendered.

The lineage is Freelancer's trade lanes, which demonstrated this working. The
difference is agency: Freelancer's lanes were a conveyor with no steering and no
route choice, and this one is piloted. The cautionary lineage is X Rebirth, whose
highways were disliked for four specific reasons — impervious conveyor, redundancy
with a personal travel drive, an AI pathfinder that ignored the roads, and blue
strips with no fictional motivation — each of which `EXPLORATION_DESIGN.md`
answers directly.

The alternative was keeping 0009 literally: open space at three throttle scales,
with density authored into the emptiness. That is the design that has no answer to
renderability, and it is the one Starfield failed at from the other end.

## What this forbids

- Do not build the tube as a loading screen, a transition, or a skippable
  sequence. Every bullet above is a property a review can check.
- Do not add a personal cruise drive that works off the road. Redundancy with the
  highway is X Rebirth's first failure mode, and it is what makes roads optional
  and therefore empty.
- Do not add junctions. Route choice happens at portals; a missed turn costs one
  hop off and back on.
- Do not add an alignment, docking, or confirmation sequence to portal entry.
  Entry is on contact and instant — see `exploration/portal_entry_seconds`.
- Fast travel is still not a solution to empty space. The debug teleport is a test
  instrument, is logged, and is loud on the HUD when used.
