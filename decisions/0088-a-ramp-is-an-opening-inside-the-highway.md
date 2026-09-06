# ADR 0088 — Inside the highway a ramp is an opening, not a tube; and a sign belongs to a carriageway

*Status: accepted · 2026-09-05 · from a play session; builds on ADRs 0078, 0080, 0083*
**Decision 1's cut is superseded by ADR 0091.** A ramp's building is no longer stopped
at the wall — it keeps its floor and walls through the junction and loses only its
roof, because cutting it left the last several hundred metres of a merge with no
structure at all. Decisions 2, 3 and 4 stand, and decision 3's `from_deck` is what
the bottom strip reads.

## Decision

Four things, from one session's report. They are one ADR because they are one shape of
mistake: **a road was being described by geometry measured in the wrong frame**, and
the fix in each case is to author the fact instead.

### 1. A ramp's building stops at the wall it goes through

A ramp's **lane** runs its whole length — the union needs it to, or a handover has
nothing to hand to. Its **building** does not. It is cut where the ramp enters the
building of the road it serves, at exactly the crossing `RoadNetwork.crossing` already
measures for the aperture.

Inside the highway a ramp is not a tube. It is a hole in the floor or a gap in the
wall, and what surrounds you there is the mainline's own building.

An interchange ramp is cut at **both** ends, and the road it lands on gets an aperture
too — measured, through whichever face the curve actually reaches, because a ramp
climbing to a road above enters through its floor and one dropping to a road below
enters through its roof. Both are entries; ADR 0080's authored `BELOW` is the rule for a
ramp coming up from a planet, not for every arrival anywhere.

### 2. An interchange's swing point is measured off the road

The lane change that takes an interchange ramp out through the side wall is now aimed
at a point on the **road** at that distance, offset sideways, rather than at a point
along the leaving **tangent**.

### 3. An exit sign says which carriageway it is bolted to

`ExitSign.from_deck` is set where the sign is hung. "Is this exit mine" is that
comparison and nothing else — for the pick *and* for whether the sign is drawn at all,
so what can be seen and what can be clicked cannot disagree.

**Signs and portal names are drawn only when they are choices.** A sign is visible when
it belongs to the carriageway the ship is on; a portal's *name* shows when it is a way
the player could take — the ways ON while off the road, the way OFF the road being
ridden. The apertures themselves are always drawn: they are built things, and a
structure that came and went would be worse than clutter. A **closed** exit's sign is
dark, never absent (ADR 0084).

### 4. A berth follows a road that ends

When the road a berth is bound to runs out and the union has somewhere to hand the
ship, the berth goes with it instead of releasing.

## Why

**1 — because a ramp drawn as a tube plugs its own opening.** The human: *"where the
highway enters from below the bottom of the road should not be closed, and where it
enters from above the ramp should not extend into the highway."* Both halves are the
same defect seen from two sides. The mainline's floor plate is already left out over an
entry aperture (ADR 0078), but the on-ramp's own roadway carried straight on underneath
it and plugged the hole; from above, an interchange ramp's roof and walls stood inside
the lane. The building had no business being there: it is the mainline's building you
are inside.

It also makes ADR 0087's shell tractable. Two overlapping tubes give a hull two
contradictory answers about which surface it may not cross; cut at the wall, there is
one building at a time and the joint is the aperture.

**2 — because a straight line beside a weaving road is not beside it for long.** The
leaving tangent is the road *there*; over two kilometres of a road that weaves 20° and
undulates 7°, a curve held on that tangent drifts out of the section vertically and
leaves through the **floor** — which the exit-face gate caught the moment the leg length
moved, and which left the ramp's shell standing inside the highway. Asked of the road at
each point, the lane change is parallel to the road for its whole length and the only
face it can reach is the side wall.

The same frame error, one scale up, is why an interchange now lands one `ramp_run_length`
past the system's own merge: the roads cross **at** a system, so the merge from that
system's planet is already using that stretch of road, and landing on top of it handed a
ship coming up the on-ramp an interchange ramp that was about to end — the stutter ADR
0076 is about.

**3 — because the geometric test was right about the wrong thing.** The pick compared a
ramp's leaving tangent against the road axis *under the ship* (ADRs 0072, 0081). The
axis under the ship is the road **here**; an exit's tangent is the road **there**. On a
straight they agree. On a bend, and on the curving on-ramp a player joins by, they
differ by more than the steering cone — measured from the seat, **no exit ahead was
takeable at all**, which is exactly what came back: *"I couldn't get the click off ramp
feature to work at all"*, and *"my mouse won't fully move to be able to click on an off
ramp"*, which is what a reticle that never lights anything up feels like.

Which wall a sign is bolted to is a fact about where it was hung. Facts do not need to
be re-derived from angles.

The visibility half is the same fact spent twice. Two carriageways share one building
with glass down the middle and a second highway crosses it, so every sign and every
portal name on the map was legible from every seat: *"seeing all the signs from all the
directions makes it look very chaotic and confusing."* The predicate that decides
whether an exit is yours is the predicate that decides whether you can see it.

**4 — because a ramp that ends is not a choice.** ADR 0082 forbids the union handing a
berthed ship a road **on proximity**, because that is the berth choosing a route. A road
that has *ended* offers no choice: there is exactly one thing it becomes. Releasing
there dropped a player at the merge they berthed for — and the on-ramp is where a
player first meets the offer, so it was the first berth of most sessions.

## What this forbids

- **Do not draw a ramp's building inside the building it goes through.** If the two ever
  overlap again, the shell has two answers and the aperture has a roof over it.
- **Do not measure an interchange's shape off a tangent.** Any point a ramp is aimed at,
  on a road that weaves, is asked of the road at that distance.
- **Do not re-derive "is this exit mine" from an angle.** It is `from_deck`, it is
  authored where the sign is hung, and the pick and the draw read the same one.
- **Do not hide a sign or a portal because it is refused.** A closed exit is dark
  (ADR 0084); an exit you cannot see is a road that never had one.
- **Do not hide the apertures themselves.** Only names and signs come and go.
- **Do not let a berth change roads on proximity.** ADR 0082 stands: the only two things
  that may move it are a clicked sign and a road that has run out.
- **Do not turn any of this into junction logic.** Nothing here plans, chooses, or
  routes; every one of the four is a fact being read from where it was written down.
