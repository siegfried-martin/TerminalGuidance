# ADR 0091 — A junction is two buildings meeting; the road is playable space; and an exit is a button on a strip

*Status: accepted · 2026-09-05 · from a play session · supersedes ADR 0083's sign click
and ADR 0088's "the shell stops at the wall"*

## Decision

Five things from one session. They are one ADR because four of them are the same
mistake at different scales — **a road described at a point where it happens over a
stretch** — and the fifth is what the human asked for in its place.

### 1. An aperture is a stretch, and a ramp keeps its floor through one

`RoadStructure.pierce` takes a **span**, not a point. A ramp joining a highway rises
through its roadway over hundreds of metres, and the highway's floor is open for all of
it. Over the same stretch the **ramp** loses its *roof* — pierced ABOVE on its own
building — and keeps its floor and walls. What is left is a trough rising into a slot,
which is what a merge is.

**This supersedes ADR 0088's cut.** A ramp's building is no longer stopped at the wall.

### 2. The road carries its own playable space

Every carriageway contributes a `TubeRegion` to the boundary field, at the lane's own
corner-to-corner radius plus the warning band. Regions unite, so this only ever adds
space, and a corridor still governs wherever both apply.

### 3. An exit's mouth is not an entrance

A portal is blue only when it is **a way the player could take from where they are** —
the ways *on* while off the road, the way *off* the road being ridden. The same
predicate gates its name. Combined with `permitted` rather than replacing it: both are
"may I use this, now", which is the one question ADR 0060 says the colour answers.

### 4. The camera's road axis is slewed in a berth too

`Mothership._road_axis` follows `berth.axis` while berthed, at the same bounded rate
`_fly_cruise` uses.

### 5. An exit is a button on a strip along the bottom of the screen

`FlightHud` is a bar at the bottom. Off the road it is the ship — throttle and hull. On
a highway it is the road: which one, which way, and the turnings ahead with their
distances, **clickable while berthed**. It swaps rather than growing.

**This supersedes ADR 0083's mechanism, not its principle.** An exit is still chosen at
the moment it can be seen, still nothing is planned or routed, and taking one is still a
rail rebind that happens when the ramp arrives. What changes is the control. A closed
exit is listed, greyed and refused, which is ADR 0084 unchanged.

The signs stay in the world behind `exit_signs_visible`, off by default, as scenery. The
reticle pick is gone.

**The pointer is released in a berth**, so the strip can be pressed. Looking around a
berth is the stick's job now.

## Why

**1 — because the crossing is long, and it is long by construction.** ADR 0070 requires
a ramp to be tangential where it merges, so it arrives *shallow*: at these numbers the
on-ramp's tube straddles the highway's roadway for about seven hundred metres. A
one-hoop hole punched where the centre-line crossed left the ramp arriving under a
solid floor beside the opening, and ADR 0088's cut then removed the ramp's own building
for that whole stretch — which is a merge with no structure at all. Reported as *"there
is a gap in the on ramp before it connects to the highway… the game will let me drive
through the gap"*, with a screenshot of the reticle sitting in it.

Measured, the old geometry leaves the ship with nothing around it for **110 of 240
frames** of a merge. That number is now a gate check.

The human called this one twice, and was right both times: *"since we are going with a
tiles approach, my suggestion is to create highway junction tiles that have all the
types of on and off ramps."* This is that, expressed in the modules that already exist —
`bay_open_top` is the junction tile.

**2 — because a corridor is drawn between two systems and an interchange ramp is not on
one.** It cuts the corner between two highways crossing at an angle. Measured at **388 m
outside** the playable volume, which is past `bounds_stop_distance`: the boundary was
not merely reddening on a road the player was legitimately on, it was walking their
speed ceiling toward zero. Reported as *"at several points during/after I took the off
ramp in the junction… the red barrier was shown."*

Widening the corridor instead would have cost the corridor its meaning — it is what
*off-road* travel is bounded by, and it is sized against that. The road is a place
(ADR 0057); a place you can be is playable space, and saying so once is cheaper than
keeping two numbers in step for ever.

**3 — because a blue mouth means "come in".** *"I tried going in on the wrong entrance
ramp (marked as blue which is already a bug) and nothing prevented me from entering
it."* Every mouth was painted from the drive-and-fuel test alone, so an off-ramp's exit
read exactly like an on-ramp's entrance; flying into one did nothing, which reads as the
road being broken rather than as a wrong turn. The refusal is a colour and not a wall,
which is ADR 0084's rule unchanged: *a road refuses by not being a candidate*.

**4 — because `_road_axis` is only updated where the ship is flying itself.** The camera
frames the road rather than the nose (ADR 0057), and in a berth the axis froze at
whichever way the road went when the berth was taken. Invisible on a straight; on an
interchange ramp that turns fifty-five degrees it left the camera pointing down the
highway you had just left. *"The junction off ramp stop locking camera so I couldn't see
where I was going."*

**5 — because the sign pick could not be made to work, and the fix is not a better
pick.** *"There's only a tiny margin that will let me click it when my mouse enters an
area that is near but not on the words. When my mouse is on the words the option to
click goes away."*

That is parallax, and it is structural. The reticle is a **direction from the ship**
(ADR 0035); it is drawn projected from a camera that sits behind and above the ship. So
the ray the player aims along and the ray the pick measures start from different points,
and the error grows with how far away the thing is — which for a sign at its lead
distance is exactly the range that matters. Every fix is a fudge factor.

The human's own answer, and it is better than a fixed pick: *"the bottom nav system will
just be easier."* A button is a button. It also puts the distance to each turning on
screen, which a sign in the world never could, and it is the same list whether you are
flying or berthed — so what changes in a berth is that you can press it, not what you
know.

**Why the strip swaps rather than grows.** Off the road, throttle and hull are what a
pilot glances down at. On it, the ship is carried inside a cone it may not leave, so the
interesting question becomes *which road am I on and what comes off it*. A bar that
shows everything shows nothing.

## What this forbids

- **Do not go back to a point aperture.** A merge is a stretch; an opening sized to one
  hoop is a ramp arriving under a solid floor.
- **Do not cut a ramp's building off at a wall.** Inside a highway a ramp is a trough,
  not a tube and not nothing.
- **Do not widen the corridor to cover a road.** The corridor is what off-road travel is
  bounded by. A road carries its own space.
- **Do not paint a mouth from the drive test alone.** Blue means "a way you can take,
  now". And it still refuses by colour, never by a wall (ADR 0084, ADR 0014).
- **Do not bring back a world-space reticle pick** for signs, labels, or anything else
  at range. The reticle is a direction from the ship and the camera is not at the ship;
  anything picked that way is wrong by a parallax that grows with distance.
- **Do not let the strip plan a route.** It lists what is ahead on the road you are on,
  inside `nav_exit_horizon_metres`, and nothing else. No destination is held anywhere,
  and the rebind is still the berth's, still on arrival (ADR 0083).
- **Do not make the strip clickable while flying.** ADR 0013 has not moved because the
  control did.
- Do not hide a closed exit. Listed, greyed, refused (ADR 0084).

## Also fixed here, and worth recording

`make check` reported **"0 failed" while quietly skipping 58 checks**: a runtime error
inside a test function stops that function and returns to the caller without failing
anything, because GDScript does not unwind. `MINIMUM_CHECKS` is a floor on the total —
adding tests never trips it, and the only way it fails is a suite that stopped early.
Lower it on purpose, never to make a run go green.

## Not fixed, and reported

*"When I finally undocked on the other highway it put me facing the right way with the
camera offset and the ship teleported to the lane on the other side."* The human said
the state was probably too broken to be worth reproducing and asked to see whether it
recurs once the rest of this landed. It is not diagnosed and nothing here is claimed to
address it.
