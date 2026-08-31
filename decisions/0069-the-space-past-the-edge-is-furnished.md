# ADR 0069 — The space past the edge is furnished, and it is furnished in three layers

*Status: accepted · 2026-08-30 · from the human reporting that motion had stopped reading*

## Decision

Playable space is bounded, and **the space outside it is filled with things at
different distances**. A `DeepField` scatters three layers around the whole route:

| layer | where | what it is for |
|---|---|---|
| dust | 120–1500 m past the edge | the speed cue — this is the one that matters |
| bodies | 2–26 km past the edge | slow parallax, and a sense of scale |
| stars | 40 km, riding with the player | orientation only |

Both distances for every layer are measured **from the boundary**, never from the
route. The shell then follows the shape of playable space: it hugs a corridor where
the corridor is narrow and stands off a system's rim where the system is wide.

Every boundary surface also carries a **ruled line grid** at `bounds_grid_spacing`,
on the same geometry as the surface itself.

**The whole field is background layer.** No physics body, no `Area3D`, no hit test,
and no accessor anywhere that hands out a position.

## Why

The human's report was that once a boundary face filled the view, *"it's impossible
to tell that I'm moving"* — a ship at 160 m/s and a ship at rest photograph
identically against a flat translucent wall. That is not a tuning problem. **Motion
is only ever legible against things at different distances**, and a bounded volume
with nothing outside it has exactly one distance in it.

Three layers rather than one, because they do different jobs and no single distance
does all three. Stars alone are the obvious answer and the wrong one: they cannot
parallax, so they say which way you are pointing and nothing about how fast you are
going. Distant planets read as scale but sweep a degree a minute. It is the near
dust — a few hundred metres past the wall, crossing the canopy — that answers *am I
moving*, and it answers it whether the player is looking at the highway, at a planet,
or at nothing at all.

Measuring from the edge rather than from the route is the part that is easy to get
wrong, and was got wrong first: a 1800 m shell around the route cannot reach past a
1750 m system rim at all, so dust appeared along the corridors and a player standing
inside a disc looking at the wall saw the same flat blue nothing as before.

The grid is the same argument applied to the wall itself. The boundary must stay
translucent — the space beyond it is the thing the player is being shown — so it
cannot be given a texture. Lines cost it nothing and give it a surface that slides.

It is background layer because that is what CLAUDE.md's LOD/collision invariant is
about, and scenery that can be queried is the specific bug that invariant exists to
prevent: it looks like a physics bug and it is not.

## What this forbids

- Do not give anything in the deep field a physics body, a collision shape, a hit
  test, or an accessor that returns where it is. Counts only.
- Do not make the deep field the only thing outside the boundary and then delete the
  in-system marker lattice. They are different distances and both are load-bearing.
- Do not measure a layer's placement from the road. It has to be from the boundary, or
  the field cannot follow the shape of the map.
- Do not collapse the layers into one distance to simplify the tuning. One distance is
  the state this ADR was written to leave.
- Do not make a boundary surface opaque, or draw the grid on anything other than the
  surface it rules. A wall you cannot see through hides the thing the field is for.
- Do not let the field decide anything about gameplay: no navigation off it, no
  landmarks, no "fly to the big rock". It is scenery, and it is placed by a seed.
