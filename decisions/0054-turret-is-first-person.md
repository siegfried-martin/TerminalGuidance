# ADR 0054 — The gun station is first person, with its own field of view

*Status: accepted · 2026-08-28 · human direction after the first turret playtest*

## Decision

The turret camera sits **at the station**, not on a boom behind it
(`camera/turret_follow_distance` 2.5 m, `camera/turret_follow_height` 0), and it has
**its own, narrower field of view** (`camera/turret_fov` 52°) rather than the
`camera/fov_base` 70° the helm and the missile share.

`ChaseCamera` gains an optional per-view FOV key. Everything else about the turret
camera is unchanged: pull `turret_follow_distance` back up and the boom, its lag and
ADR 0048's pitch share all come back into play.

## Why

Human direction, 2026-08-28, after the first session with the built turret:

> "it was really hard for me to see and shoot the enemy missile. I think it would
> help if the turret was more like a first person experience, maybe the FOV also
> needs to be adjusted for this as well"

Both halves of that are about the same thing, and it is not a preference — it is a
measurement problem. The target is a **2.6 m sphere at up to 200 m**, in a field of
260 rocks. At 70° across a 1600 px viewport that is roughly three pixels.

- **First person removes a parallax that costs precision.** A boom puts the eye and
  the sight line in different places, so the crosshair is only exactly right at
  `turret/convergence_distance` and the player is judging a 3 px target through an
  offset. At the station the eye is on the sight line and the error nearly vanishes.
- **A narrow FOV is magnification, and magnification is the whole answer.** 52°
  against 70° is about 1.4× on every linear dimension. That is the difference
  between a few pixels and a target.

**The cost is peripheral vision, and it lands in the right place.** A helm wants to
see what is around it; a gun wants to see one thing clearly. That asymmetry is
exactly why this is a separate key rather than a change to `fov_base` — narrowing
the shared value would take the missile's sense of speed away, which criterion 1
already passed on.

**The instrument has to close the rest of the gap.** A narrow FOV means the incoming
missile is *off screen* more often, so the alert marker now draws an arrow at the
screen edge pointing at it, the same way the target indicator does. "Incoming" has
to be a direction the player can turn towards, or the answer to an interrupt is
sweeping the sky and hoping. The bracket also stopped pulsing in *size* — a marker
that shrinks every second is a marker that is hard to find.

## What this forbids

- **Do not narrow `camera/fov_base` to get this effect.** The helm and the ridden
  missile want the wide value; the whole point of the separate key is that these are
  different jobs.
- **Do not remove the boom machinery** because the camera currently sits on top of
  the station. `turret_follow_distance` is a tuned value, and ADR 0048's levelled
  boom is what stops a pulled-back camera diving through the hull at high elevation.
- **Do not add zoom as a held key or a toggle.** The turret's magnification is what
  it is; a second FOV the player switches between is a mechanic, and one nobody has
  asked for.
- **Do not compensate for a small target by growing its hit sphere.** `Flare`,
  `EnemyMissile` and the rocks all draw at exactly the radius they are hit at
  (ADR 0041, 0043, 0050, 0051). If an incoming missile is too hard to hit, it gets
  physically bigger, slower, or better marked — never invisibly more generous.
