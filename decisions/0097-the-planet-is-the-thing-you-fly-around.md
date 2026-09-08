# ADR 0097 — The planet is the thing you fly around

*Status: accepted · 2026-09-08 · from the human, after flying the stars and planets side by side — supersedes 0061*

## Decision

A system's planet sits in the **middle of the disc's volume**, on or near the combat
plane, and is large enough to fly around. The highways run along the **bottom** of
the volume, below the planet, and their ramps climb from there toward the mouths
beside it. The star is below the floor, in the out-of-bounds zone, and is a backdrop.

The numbers are sliders: `planet_radius`, `planet_center_depth` (0 is the plane,
negative lifts it), the highways' heights in `data/routes.json`, `ramp_mouth_height`,
`star_gap_below_floor`. This ADR fixes the arrangement, not the values.

## Why

ADR 0061 put the planet at the bottom, mostly under the floor with its cap showing,
and the star went below that. Flown, the two read as *"two floating spheres"* with no
way to tell which is which or how far either is: *"I can't really tell the difference
between the star size and the planet size because the star is farther away and I
don't have any real depth perception."*

A planet inside the volume, with the road passing under it, gives the eye what it
was missing: the road occludes the planet, the ribs are a ruler beside it, and flying
past it gives parallax. The star, now the only sphere below the road, stops competing
with it. And the player is *"actually flying around planets"*, which is the picture
the exploration layer was always after.

0061's reason for the bottom — that an approach envelope in the combat band arms a
landing sequence during a fight — has weakened since it was written. The envelope
is now a small, faintly drawn place rather than a large one, it starts nothing the
player did not fly into, and the exploration scene has no fight in it. If a fight
does come to a system with a planet mid-volume, the envelope's own rules (ADR 0012:
nothing steers, any input aborts) are the answer, and if that turns out to be a
papercut, the fix is `planet_center_depth`, which is a slider.

## What this rules out

- Putting the planet back under the floor, or the floor between the player and the
  planet: the point of the arrangement is that the planet is in the flyable volume.
- Growing the planet without growing `approach_envelope_radius` with it. The
  envelope has to leave a fighter's countdown outside the surface; the gate checks.
- Putting a ramp mouth inside the envelope. Mouths sit `ramp_mouth_side_offset`
  beside the system's centre, and that offset has to exceed the envelope; the gate
  checks that too.

If a later direction wants the planet somewhere else again, supersede this the same
way. It is a placement, and placements have changed here before.
