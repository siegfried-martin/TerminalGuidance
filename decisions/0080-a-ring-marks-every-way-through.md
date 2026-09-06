# ADR 0080 — A steel ring marks every way through, and which face a ramp uses is authored

*Status: accepted · 2026-08-31 · from the human's interchange sketch, and from the road becoming solid*

## Decision

**Every way through the road's structure is marked by a steel ring**: the mouth at
each end of a ramp, and the opening in the building where a ramp leaves or joins.

**The ring is the one piece of the road drawn at a uniform scale.** Everything else
is a module stretched to the section it sits in. A mouth you fly through has to read
as one size from any angle, and an ellipse does not, so `ramp_ring_diameter` is a real
diameter in metres. The gate checks it against **the hull's diagonal** for every class
in the roster — a round mouth is cleared corner to corner, not by width and height
taken separately. That is the check ADR 0068 said the gate ought to be able to make
and could not.

**A ring is never shaded down**, unlike the rest of a ramp (ADR 0076's
`lane_ramp_shade`). A ramp is drawn darker so the eye can tell which road leaves the
highway; the ring's job is the opposite one, and a dimmed signpost is a worse signpost.

**Which face of the building a ramp uses is authored, and the rule is:**

- An **exit** leaves through a **wall or the roof, never the floor.** The floor is the
  roadway — the road you dock on — and an exit competing with it for the meaning of
  "down" is clutter.
- Onto a road going right: exit right. Onto one going left: **above** if it is above,
  **right** if it is below.
- An **entry** comes up through the **floor**, always. Merging upward into the only
  lane there is is unambiguous, and there is nothing else it could mean.

**Where a ramp goes through is measured, not assumed** (`RoadNetwork.crossing`). The
ramp is walked from the end that touches the mainline until it is outside the
building, and the opening is put there.

**An exit and an entry are therefore different shapes, and need different numbers.**
`ramp_exit_side_offset` / `ramp_exit_depth` and `ramp_entry_side_offset` /
`ramp_entry_depth` replace the single pair that served both.

## Why

Step B made the road solid. A building has faces, and a ramp that used to pass through
open air now has to pass through *something* — so every ramp needs an aperture, and
the question "which one" became a real question rather than a stylistic one. The
human's rule already existed and this is the step that had to obey it.

**One pair of offsets cannot satisfy both halves of the rule.** A ramp leaves the
mainline along the road's own direction (ADR 0070), so the only thing deciding which
face it reaches first is the ratio of how far its mouth sits *out* to how far it sits
*down*, measured in section-widths. An exit needs that ratio high and an entry needs
it low. At 520 out and 120 down every ramp on the map reached a wall — the entry rule
was quietly false. At 260 and 240 every ramp reached the floor — the exit rule was
quietly false instead. Two pairs of numbers is not tidiness; it is the minimum that
can express the rule.

**The gate checks the rule, not the values.** All four numbers may move as long as
each ratio holds, and the gate names the ramp that broke it.

**A ramp is a chord across a bend, and that is what actually broke first.** With both
ratios satisfied on paper, `RampOnAForward` still reached a wall: the local leg weaves,
and a cubic strung between two points on a curving road bulges outward from it. The
straight-road arithmetic is necessary and not sufficient, which is why the gate
measures against the real curve and why `ramp_entry_depth` ended up at 520 rather than
at the 320 the algebra allows.

## What this forbids

- Do not let a ramp leave through the floor. Down is the roadway, and step D's berth
  sits on it.
- Do not let a ramp join through anything but the floor. An entry from the side is a
  merge across a lane the player cannot see into.
- Do not scale a ring non-uniformly to make it fit. If it does not fit, the section is
  too small or the ring is too big, and both are numbers.
- Do not shade a ring down on a ramp. It is the signpost, not the road.
- Do not size a round mouth against a hull's width and height. It is cleared corner to
  corner.
- Do not compute which face a ramp *should* use from a preference or a heading. It is
  authored, and where it actually crosses is measured.
- Do not check the exit-face rule against a straight road. A ramp bulges across a
  bend, and the bend is where it fails.
