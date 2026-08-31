# ADR 0085 — The map is a network of routes, and an interchange swings out before it changes height

*Status: accepted · 2026-08-31 · from the human: "you will need an additional 2 systems for this"*

## Decision

**The map is five systems on two crossing highways.** A-377B runs A, B, C; K-112 runs
D, B, E across it, higher. **B is on both**, which is what makes it an interchange
rather than a place two roads happen to pass.

**A route is the unit.** `SystemMap` lays each route from an anchor system — route 0
anchors A at the origin, route 1 anchors on B, which route 0 has already placed — and
`RoadNetwork` is `rebuild()` / `add_route()` per route / `link_routes()`. There is no
"the" road: the first one on the map is not special, and anything that only works for
one spine is a bug waiting for the next road.

**Every carriageway gets its own right-hand turn onto the road it crosses**, and
"right" is asked of that carriageway rather than of the route. Four carriageways at a
crossing, four ramps.

**An interchange swings OUT before it changes height.** It is two sweeps through a
point `interchange_side_offset` to the side at the same height: the first is a lane
change that clears the wall, the second is the turn and the climb or drop, entirely
outside the building.

**`RoadPath.sweep` is a second curve constructor**, sized off the chord where
`RoadPath.ramp` is sized off the along-road projection.

**Every leg is a different length, on purpose.**

## Why

**The exit-face rules could be read but not flown.** A crossing road with nothing on it
is a wall to turn onto, not a route to take, and there was no way to judge whether an
interchange reads. Two more systems is what it costs.

**A route being the unit is the honest shape and it fell out of three separate
failures.** Node names collided. Ramps pierced the wrong road's walls. And a test that
measured every ramp against one building reported a ramp coming up perfectly through
its own floor as going through a wall — the test was wrong, and it was wrong in a way
that could only exist once "the mainline structure" stopped being a meaningful phrase.

**`ramp` measures its control arms along the leaving direction on purpose**, so a
planet ramp — mostly along the road, mostly sideways at the end — cannot get an arm
long enough to loop. An interchange is the opposite shape: half of a fifty-five degree
turn is *across* the leaving direction, so that projection under-measures it badly, the
arms come out short, and the whole turn is crammed into the middle. Measured at
**52 deg/s** against a ship that turns at 34, for a curve whose honest requirement is
under 3. Two constructors, because they fail in opposite directions — the same shape of
answer as exits and entries needing different offsets (ADR 0080).

**The swing-out is the human's own rule, made geometric.** *"To the right if the highway
is below"* is not a preference about which way it looks nicer: a curve aimed straight
at a road 240 m below leaves through the FLOOR of the one it is on, which ADR 0080
forbids because the floor is the roadway. Swing out, then drop.

**Unequal legs are a design principle, in the human's words** — the short A–B and long
B–C were an accident of the first build and the reading of it is that the difference is
the point. Legs that are all the same length make a grid, and a grid makes
system-to-system transport a distance rather than a decision. The gate asserts no two
legs match.

## What this forbids

- Do not write code that assumes one road. `RoadNetwork.spine()` returns the first
  route's for convenience and nothing may steer by it.
- Do not check a ramp against a building that is not its own road's. Use
  `building_for(route_name)`.
- Do not aim an interchange ramp straight at a road at another height. It leaves
  through the floor or the roof of the one it is on, and both are forbidden.
- Do not use `ramp` for a road-to-road turn or `sweep` for a planet ramp. They fail in
  opposite directions and one constructor cannot do both.
- Do not make every leg the same length. Sameness is a grid, and the gate says so.
- Do not derive "right" for a carriageway from its route's direction. The two run
  opposite ways and cannot share an answer.
