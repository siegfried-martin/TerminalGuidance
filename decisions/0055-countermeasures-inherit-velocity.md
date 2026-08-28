# ADR 0055 — Countermeasures inherit the launcher's velocity; aimed shots do not

*Status: accepted · 2026-08-28 · human report after the first turret playtest: "the blocker is slower than the ship, which causes issues"*

## Decision

A flare star **carries the launching ship's own motion**, on both sides, at
`flare/velocity_inheritance` (default **1.0**, the physical answer).

Everything that is *aimed* keeps inheriting **nothing**: the ridden missile
(`missile/velocity_inheritance`, 0, ADR 0005), autocannon rounds, unguided missiles
and the pulse beam.

## Why

**A flare is an object you let go of, so it keeps your motion.** That is not a
flourish — it is the difference between the mechanic working and not working. Both
of a star's speeds are *slower than a ship at cruise*: `flare/launch_speed` is 15 m/s
against a manual top speed of 34 and an autopilot arc of ~14–19. Without inheritance
the wall is dropped in place, the ship flies straight out through its own
countermeasure within a second, and the enemy's stars fall behind the target they
were thrown to protect.

**An aimed shot is the opposite case, and for a reason that is not symmetry.** A
round that inherited the ship's velocity would be deflected sideways by it — at
34 m/s across a 320 m/s round, about six degrees — and would no longer arrive where
the crosshair says. ADR 0049 went to some trouble to make the sight honest at the
range the fight is held at; inheriting would put the lie back in, and this time it
would vary with the ship's speed, so it could not even be compensated for by habit.

ADR 0005 already made this call for the ridden missile, framing it as arcade versus
sim. This ADR says the same thing more precisely: **the question is whether the
player is aiming the thing.** If they are, it goes where they pointed. If they are
letting go of it, it keeps what it had.

**A consequence worth knowing before tuning:** `flare/launch_speed` now means speed
*relative to the launcher*, not relative to the arena. The same number is a
different quantity than it was, and it is the separation the wall achieves from the
ship that threw it.

## What this forbids

- **Do not give an aimed weapon velocity inheritance** — not the autocannon, not the
  unguided missile, not the beam, and not the ridden missile beyond ADR 0005's
  tunable. The crosshair must not lie, and it must not lie *differently* at
  different speeds.
- **Do not fix "my wall got left behind" by raising `flare/launch_speed`.** That
  changes where the wall ends up as well, and it was the wrong lever — the wall
  being left behind was missing inheritance, which is now the default.
- **Do not remove the tunable and hard-code 1.0.** 0 is how the failure is
  reproduced and looked at, which is the only way anyone will believe this ADR later.
- **Do not extend inheritance to the enemy's guided missile.** It re-aims every
  frame, so inheritance would change nothing except its first heading, and adding it
  would suggest the launcher's motion matters to a weapon where it does not.
