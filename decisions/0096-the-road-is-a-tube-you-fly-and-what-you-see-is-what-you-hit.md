# ADR 0096 — The road is a tube you fly, and what you see is what you hit

*Status: accepted · 2026-09-07 · from the human, after a clean-room rebuild of the
highway from a one-page requirement produced in one session what eight days of
sessions had not: "it did an incredible job… I would like to throw away what we have
for highway, replace with something copied from this new system"*

## Decision

**A road is a centre-line of straight legs joined by circular arcs (`RoadPath`),
with one or two rectangular tubes swept along it (`Tube`).** A highway is two
carriageways side by side under one roof with a glass median, traffic on the right
(ADR 0077); a ramp is one carriageway. Every query on the curve is analytic — no
polyline, no baking — so the tangent is continuous and the lane, the mesh and the
collision read the same curve to the millimetre.

**The tube is the only collision primitive, and the ship is always in exactly one
tube or in open space.** Inside a tube the hull's centre is kept within the section
shrunk by the hull's own extents (ADR 0068). **A side of a tube is passable only
where the point straight through the wall lies inside a neighbouring tube — and the
mesh leaves the wall out by exactly that rule.** `RoadMesh` and `RoadCollider` share
one number (`RoadCollider.OPEN_EPS`) and one definition of "open", so what is drawn
and what holds the ship cannot disagree. This is the ADR 0041 principle, "the drawn
shape is the hit shape", applied to the road.

**A ramp is built by one rule, never measured.** An exit runs level inside the
carriageway for a lead, then diverges to the right through the wall at a small
angle; an entry approaches from below and climbs through the floor, then runs level
inside the carriageway before its tube ends. The wall or floor is open wherever the
ramp's tube is and nowhere else. Exits leave through a wall or the roof, never the
floor; entries come up through the floor (ADR 0080's rule, kept). Planet ramps are
declared by system and side in the data and shaped by the rule; interchange ramps are
authored as the waypoints between the standard head and the standard tail, and a
ramp may be the half-turn mirror of another about a system.

**Routes are data**, in `data/routes.json`, hot-reloaded like `tuning.cfg`: the
systems' positions, each highway's waypoints and corner radii, and which ramps exist.
Leg lengths, bearings and heights are not tuning keys; they are what the map is. The
ramp *rule*'s numbers are tuning keys, because they are how every ramp is built and
are nudged while looking.

**The mesh streams; the collision does not.** A road is chunks, built on worker
threads within `road_detail_radius` of the ship and dropped behind it, with a coarse
unclipped far version standing in beyond. The collider is analytic and holds the ship
everywhere, loaded or not.

**The road is verified by flying it.** A `RoadProbe` — the same collider and lane
sample the ship uses — flies every carriageway, every ramp, dives at every wall
around every junction and every bend, and flies drunk on every tube, and the gate
fires rays at the *rendered triangles* to assert the probe never passes through a
surface, is never stopped, and always has structure on four sides. Bounding the
geometry is not verification; being handed the wrong thing frame by frame is what
the human found in seconds, every time.

**What survives from the road this replaces, restated here so the ADRs that carried
them can go:** no road may use more than `road_turn_share` of the ship's turn rate
(ADR 0070's rule, tightened: the nose slews after the road at that rate, so a road
using all of it leaves the nose lagging through the whole bend); the lane is soft and
the structure is not (ADR 0087's principle); hitting the structure bounces, normal
only, and costs the throttle once per contact, never below a floor (ADR 0090); every
carriageway is drawn and the ridden one brighter, a ramp darker (ADRs 0075, 0076);
the glass stays below opaque so the world stays witnessed (ADR 0079); the map is
five systems on two crossing highways (ADR 0085); a berth on a ramp to a planet hands
the ship back (ADR 0092); a closed exit is listed and refused (ADR 0084).

## Why

The old road derived its collision from a path and a section and declared every
opening as an exception on top — ramp ends not held, flares not held, apertures open
for a stretch plus a margin, and a network-wide "deepest inside wins" tiebreak. Every
junction bug was a wrong exception. Its mesh was independent of that collision *by
design*, so a tile could lose an entire wall while every check passed. And each
session's fix was promoted to an ADR with a "what this forbids" list, until a fresh
agent handed the docs rebuilt the same shape because the docs told it to.

The clean-room POC was given one sentence — *a tileset of square tubes that can
connect and branch and allow a ship to move through with bounce collision on the
walls* — and no direction on how. It produced 2,600 lines against the old road's
6,000, with one idea in it: the mesh and the collision share the rule for where a
wall is open. The human flew it and found the connectedness and the collision
correct on the first drive, including on and off ramps, which the old road had never
managed. That is the whole case.

Two things the POC got wrong are not carried: it built every road's full mesh up
front (minutes of black screen on a full map), and its ship and camera were worse
than this project's. The road is ported; the mothership, camera, berth, strip and
fuel are kept and rewired to it.

**On physics bodies.** ADRs 0032, 0038 and 0041 chose swept tests over physics bodies
for missiles and rocks, and 0087 cited that as if it were the LOD/collision invariant
in `CLAUDE.md`. It is not: that invariant is about *distant stand-ins* having no
collision, and the road is a real mesh at the player. The arithmetic says the
missile was never a tunnelling risk either (1.8 m per tick against a 4 m target).
The road uses its own analytic collider because one rule serving both mesh and
collision is the property that matters, not because the engine's physics is
forbidden. A future road may use collision shapes if that property holds.

## What this forbids

- **Do not derive collision from anything but the tube, and do not derive the
  opening from anything but the neighbour rule.** No declared apertures, no
  per-face exceptions, no "not held near a mouth" margins. If a wall is open where
  it should not be, a neighbour tube is where it should not be — fix the data.
- **Do not let the mesh and the collider disagree about what is open.** They share
  `RoadCollider.OPEN_EPS` and the containment test. A mesh change that needs its own
  rule is a change to `Tube.contains`.
- **Do not measure where a ramp meets a road.** Ramps are built by the rule from
  where the data says they start and end. If one does not fit, `make roads` names it;
  move it.
- **Do not put a road's shape in `tuning.cfg`.** Waypoints, radii, which ramps exist
  and where: `data/routes.json`. The ramp rule's numbers and the section: tuning.
- **Do not verify the road by data alone.** Anything that changes the road runs the
  probe suite in the gate, and a new kind of junction gets a new flight in it.
- **Do not build the whole mesh up front in the game.** Chunks stream; the far
  version stands in; `build_all_now` is the gate's and nothing else's.
- **Do not promote a bug-fix session into an ADR with a forbids list.** This ADR
  exists partly because that habit boxed the road in. A collision implementation
  choice is a commit message; an ADR is for a decision about the game.
