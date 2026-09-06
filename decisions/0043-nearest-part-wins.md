# ADR 0043 — The target is hit as its parts, and the nearest one along the shot wins

*Status: accepted · 2026-08-26 · supersedes the hull-sphere clauses of ADR 0042, from a bug report: "I didn't see any enemy ship component ever get hit"*

## Decision

The target ship's hull is hit-tested as the **boxes it is drawn from** — fuselage,
wings, fin — plus an inset box for the nose cone. Components are spheres mounted
proud of that hull. `hit_test` returns whichever shape the swept segment reaches
**first**, by entry parameter along the segment.

`enemy/radius` is no longer the kill shape. It is the HUD's range reference and the
fallback radius for a plain target with no parts. The broad-phase bound is
**derived** from what was actually built, never tuned.

Two supporting changes fall out of the same reasoning:

- **`FlightGeometry` gains entry-parameter tests** — `segment_sphere_entry` and
  `segment_box_entry` (slab method, exact) — because "which part first" is not a
  question a boolean can answer.
- **The autopilot may not fly the ship in a way the player could not.** Its
  velocity is clamped to the ship's own top speed, and it turns its nose at
  `ship/autopilot_turn_rate_deg_per_sec` instead of snapping with `look_at`.

This **supersedes ADR 0042** on two points: the hull is no longer one sphere, and
components must now sit *outside* the hull rather than inside `enemy/radius`. The
rest of ADR 0042 — what components are, why they exist, two hits, respawn, no
flash on the darkening hit — stands.

## Why

ADR 0042 said "components are tested before the hull, so a shot that could be
credited to either goes to the component." That was true and useless. Every
component sat inside the hull's 9-metre sphere, so on the frame the segment first
touched anything, it touched the sphere — nine metres out, four metres clear of
the nearest component. The ordering never came into play. **No component was
reachable, by construction**, and the bug presented not as an error but as "my aim
can't be that bad."

The lesson is worth keeping: **test order cannot substitute for geometry.** If one
volume encloses another, the enclosed one is unreachable no matter which is asked
first. The gate now checks the geometric property directly — every component's
outermost point must lie outside every hull box — rather than checking the
ordering, which was never the thing that mattered. ADR 0042's own gate asserted the
*opposite* invariant ("components sit within the hull's hit sphere") and passed.

Making the hull shape-accurate rather than shrinking the sphere is the same call
ADR 0041 made for the rocks, for the same reason: a hit shape from a different
family than the drawn shape has to be either too big or too small somewhere, and
tuning that error only moves it. The nose cone is the one remaining approximation,
and it is inset rather than circumscribed — under-reaching forgives, over-reaching
invents hull where the screen shows empty space, and only one of those is visible
to the player.

The autopilot changes are a different report — "when ending manual pilot mode the
direction of the ship (and possibly position) changes" — with the same root shape.
Both were invisible while the autopilot was the only thing flying: a `look_at`
snap costs nothing when the nose was already on the arc, and a 45 m/s station-keep
against a 34 m/s manual ceiling costs nothing when nobody can feel the difference.
Manual flight made both observable. The rule that comes out of it is worth more
than either fix: **the autopilot is a delegation, so it may not do anything the
player could not do themselves.**

## What this forbids

- Do not reintroduce a hull volume that encloses the components, however the tests
  are ordered. That is this ADR's entire subject.
- Do not resolve overlapping hit shapes by test order. Use the entry parameter.
  Order is only a tiebreak between shapes the segment reaches at the same instant.
- Do not hand-tune the broad-phase bound. A bound a metre short makes the nose
  silently unhittable with no error anywhere; deriving it is what makes that
  impossible rather than merely unlikely.
- Do not circumscribe a drawn shape with a larger hit shape "for generosity". If
  the target is too hard to hit, make the target bigger — `enemy/hull_*` — so the
  screen and the hit test keep agreeing.
- Do not let the autopilot exceed `manual_max_speed()`, and do not restore the
  `look_at` snap. If the autopilot needs to move faster or turn harder, that is a
  reason to raise the *ship's* numbers, not to give the autopilot its own.
- Do not grow the autopilot on the strength of it now having a turn rate. ADR 0013
  still governs: a heading hold plus station-keeping, which does not path, avoid,
  arrive, or decide.
