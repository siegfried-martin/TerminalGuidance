# ADR 0056 — The player holds a job, not a mode; the autopilot follows from it

*Status: accepted · 2026-08-28 · human direction after the first turret playtest*

*Supersedes ADR 0040's independent autopilot toggle, and ADR 0048's helm-only launch clause.*

## Decision

Human direction, verbatim:

> "autopilot should always be engaged when in gun mode and always disengaged when
> not. you can think of it that the player is either the pilot or the gunner (there
> might be other jobs in the future), 'T' makes the player the pilot, 'G' makes the
> player the gunner, 'Q' fires a missile"

Four things, and they are one idea:

1. **The player holds one of two jobs: PILOT or GUNNER.** `T` and `G` **select** a
   job; they are not toggles. Pressing the one you already hold does nothing.
2. **The autopilot is a consequence of the roster, not a mode.** It has the ship
   whenever the player is not the pilot, and never when they are. There is no
   independent autopilot key any more.
3. **`Q` launches a missile, from either station.** Launching no longer shares a
   button with detonating; `Space`/`LMB` now only ever ends a ride.
4. **The autopilot holds its arc on a plane `ship/arc_depth` below the target**,
   not level with it. Standoff still means slant range, so the depth only decides
   *where on that sphere* the ship sits; the arc's horizontal radius is
   `sqrt(standoff² − depth²)`.

Riding a missile is an **excursion**, not a third job: the ship keeps whatever the
roster implies while the player is away, and the ride ends back at the station they
fired from. A job cannot be changed mid-ride.

## Why

**1 and 2: "hand the ship to the autopilot" and "walk to the guns" were always the
same act, described from two ends.** ADR 0040 made the autopilot a mode the player
enters and leaves, with its own key, because at the time the guns did not exist and
there was nothing else to be doing. Once there is a second station, an independent
toggle allows three states that make no sense — at the helm with the autopilot
flying (two pilots), and at the guns with nobody flying (a ship nobody has). Binding
it to the roster deletes both by construction rather than by asking a future session
not to produce them.

Selections beat toggles for the same reason a light switch beats a clapper: a player
who has lost track of where they are can press the station they want and be right.
With a toggle they press it and end up somewhere else.

**"There might be other jobs in the future" is the load-bearing half of the
direction**, and it is why this is an enum rather than a bool. `PROJECT_OVERVIEW.md`
Pillar 6 has a crew in it, and ADR 0007 already says crew can gun but cannot ride
missiles. This is the shape that grows into that; a boolean `at_the_guns` is not.

**3 removes a genuine ambiguity, and the ADR 0048 clause it breaks was wrong under
the roster.** One button used to mean "launch" or "detonate" depending on which
station you were at — a key whose meaning depends on invisible state. Q is now the
launch and nothing else is.

ADR 0048 restricted launching to the helm on sequential-attention grounds. That
reasoning does not survive contact with 2: launching moves the player *into* the
missile in the same frame, so they are never on two things at once — and a
helm-only launch would force the gunner to take the helm first, **dropping the
autopilot every single time they wanted to fire**, which is precisely the state the
human's direction exists to prevent. The sequential-attention rule is untouched;
only the edge that was justified by it is.

**4 is geometry the turret needs.** The gun is mounted on the spine
(`turret/mount_offset` is +18 m in Y), so from a level arc it is looking *across its
own hull* at anything near the horizon — the first-person camera of ADR 0054 made
that unmissable. Flying under the target puts the enemy up and clear at about 17°.

This does not grow the autopilot in the sense ADR 0013 forbids. It is a fixed
geometric station — the same class of thing as holding a standoff — not a decision
the autopilot makes about where to be. It also *simplified* the code: the arc is now
horizontal by construction, which is ADR 0045's shared horizon arriving in the
autopilot, and it removed the degenerate near-vertical case the old version needed a
fallback axis for.

## What this forbids

- **Do not reintroduce an autopilot key**, and do not let any code set
  `Mothership.autopilot` except `ViewController._apply_role`. The three-state mess
  comes back the moment two things can set it.
- **Do not make `T` and `G` toggles.** Pressing the job you hold is a no-op, on
  purpose.
- **Do not add a third job by adding a bool.** `ViewController.Role` is an enum
  because there will be more of them; extend it.
- **Do not give `Q` a second meaning**, and do not put launching back on the
  detonate button. One key, one act.
- **Do not let a job change take effect while a missile is being ridden.** It would
  be a control acting several seconds after it was pressed. (A press *during the
  post-detonation flash* does take effect, and outranks the pending return — the
  player is flying nothing at that point.)
- **Do not treat `ship/arc_depth` as a way to change the engagement range.**
  Standoff is slant range and stays the number compared against missile reach;
  depth only moves the ship around that sphere.
