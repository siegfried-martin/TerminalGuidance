# ADR 0092 — A hoop marks a mouth, not a junction; an exit's building starts where it clears the highway; and a ramp hands the berth back

*Status: accepted · 2026-09-05 · from a play session · refines ADR 0091, narrows ADR
0080's ring and ADR 0082's berth*

## Decision

Five things, from five screenshots and one complaint about the tuning file.

### 1. A hoop is only ever at a portal mouth

Junction apertures carry no steel hoop. The hoops that remain are at the ends of ramps,
where a mouth really is a mouth, and `ramp_ring_diameter` is sized to **frame the
portal it surrounds** rather than to fit inside a wall it no longer sits in.

**This narrows ADR 0080's "a steel ring marks every way through."** A ring still marks
every *mouth*; a junction is not one.

### 2. No collar stands inside an opening

A rib is a frame across the whole section, so one at a joint inside a junction is a
hoop across the merging lane. Those joints carry nothing.

### 3. An exit's building starts where it clears the highway; an entry keeps its trough

ADR 0091 gave every ramp a trough through the junction. That is right for an **entry**,
whose roadway is nowhere near the one it is joining. It is wrong for an **exit**, which
leaves sideways at lane height: its roadway and the highway's are the same surface where
they meet, so drawn there it is a second roadway laid on the first and a wall standing
in the lane.

So the asymmetry is authored: **an entry troughs, an exit is cut.**

### 4. A ramp to a planet hands the berth back

A berth carried onto a planet ramp releases after `berth_ramp_release_metres` and the
player flies the rest. An **interchange** ramp keeps the berth: it is road to road and
ends by merging.

### 5. The tuning file is grouped, and its filter works

Every section is subdivided with `;;;` groups, not just `[exploration]`. Fifteen dead
keys are deleted. Two panel bugs are fixed: the filter matched a row's `section/key`
path against a fold labelled `section · group`, so **it hid every fold containing its
own results**; and every fold's row count read zero for the same reason.

## Why

**1 — because a junction is a slot, not a mouth.** ADR 0091 made an aperture a stretch
hundreds of metres long that you drift sideways out of. A circle hung across part of one
is smaller than the way through, never aligned with it, and in the way: *"you can see
the hole is misaligned and also the circle holes are just way too small in general. I
think we can just remove the rings that overlap with the on ramp merging onto the
highway."* The size was never the problem — a hoop cannot mark a slot at any size, and
the constraint that kept it small (fit inside the wall it pierces) only existed because
it used to sit in one.

**2 — because a rib is a wall you cannot see is a wall.** *"You can see assets of the
highway running into the off ramp."* A junction is a couple of joints long and reads as
an open span without them.

**3 — because the two cases really are different, and the first version treated them
alike.** An entry comes from below with its roadway a section-height under the one it is
joining; cut off at the wall, the last several hundred metres of the merge had no
structure at all, which was the gap. An exit leaves at the same height; given a trough,
it is a second roadway z-fighting the first. One rule could not be right for both, and
ADR 0091 picked the entry's.

The user's other half of that report — *"I drove through a wall because it's impossible
to drive through a hole sideways to get off"* — is the same geometry: with the ramp's own
walls standing in the lane there was structure between the player and their exit.

**4 — because a berth on a planet ramp has nowhere to end.** A planet ramp finishes at a
portal, so a berth carried down one either flies the ship into the mouth or sits on the
last metre when the road runs out: *"when I used the off ramp while docking and didn't
undock it has some really weird behavior."* The human's own answer, and it is the right
one: *"we just need to force undocking a short distance after getting off the off ramp.
It's reasonable to make the player steer most of the length of an off ramp or on ramp.
For a junction dock mode can be kept on."* A ramp is a piloting act; a junction is not.

**5 — because a value nobody can find is a value that does not exist.** *"I tried to see
where I can change the color/opacity for the highway glass and couldn't find it."* Three
separate causes, all real:

- The glass colours had been pushed out of the "highway structure" group by a later
  insertion and were filed under **"The bounce"**.
- Every section but `[exploration]` was one flat list — forty-eight sliders in `[turret]`,
  twenty-nine in `[hud]` — which is the scroll hunt the groups were introduced to end.
- **The filter was broken**, and had been since groups were introduced: it keyed matches
  by the section in a row's path and compared them against a fold's `section · group`
  label, so a search hid the very folds its results were in. It went unnoticed because
  the only grouped section was `[exploration]` and the test filtered inside a flat one.
  Typing "glass" returned an empty panel.

The deletions are keys nothing reads: the sign pick's angles and colours (the pick is
gone, ADR 0091), `portal_entry_seconds` and `start_hull_class` (both superseded), and
the four traffic values for a system that does not exist yet. They come back with the
thing that needs them.

## What this forbids

- **Do not hang a hoop on a junction.** A hoop marks a mouth you fly through. Making it
  bigger does not make it right.
- **Do not size a hoop against a wall.** It frames the portal it surrounds.
- **Do not give an exit ramp a building inside the highway**, and do not take an entry
  ramp's away. The asymmetry is the decision.
- **Do not keep a berth on a ramp to a planet.** A ramp is flown.
- **Do not add a tuning key without a `;;;` group above it**, and do not let a later
  insertion orphan the keys under an existing one. The gate now fails on any key with no
  group.
- **Do not key a panel lookup on a section name.** A fold is `section · group`; ask the
  row which fold it is in.
- Do not carry keys for a system that does not exist. They read as settings that do
  nothing, which is worse than their absence.
