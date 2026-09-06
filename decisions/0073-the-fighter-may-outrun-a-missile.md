# ADR 0073 — The fighter may outrun a missile; the classes a missile is *for* may not

*Status: accepted · 2026-08-30 · from the human asking for an 80 m/s fighter*

## Decision

The speed hierarchy's clause is **"a missile outruns its intended targets"**
(ADR 0059), and **the fighter is declared not to be one of them.**

- `HullClass.outrun_by_missile()` names which classes are: the **taxi** and the
  **capital**. The gate holds those under `missile/base_speed`, whatever they are
  tuned to.
- The **fighter** declares its own ceiling and may set it above 1.0.
  `fighter_speed_ceiling_fraction` is 1.45 and `fighter_max_speed` is 80 against a
  58 m/s missile.
- The clamp is still a clamp. `MAX_CEILING_FRACTION` exists only so a typo cannot
  produce a ship faster than the game; it is not a hierarchy.

Lasers are unaffected and still outrun everything.

## Why

The human flew the exploration map, raised cruise to 400 and liked it, settled on 250,
and asked for the fighter at 80 to match. At the old clamp — every class capped at
0.95 of missile speed — 80 would have silently become 52.2, which is exactly the
failure the tuning file's own comment warns about and has already been met once.
Giving them 52 and calling it 80 was not an option.

The interesting part is that the invariant did not actually forbid this. ADR 0059
already reasoned that *"a missile at ~1.5x fighter speed cannot run down a fighter
that turns well, so fighter-versus-fighter resolves to guns and missiles are
anti-capital."* The fighter was never what missiles are for. What the hierarchy
protects is that the player's hands — the missile — can always reach a **taxi** or a
**capital**, because those are the things a missile is aimed at and a target that can
simply drive away from the one weapon the game is about is the whole design failing.
A global 0.95 was a proxy for that, and the proxy has now been outgrown.

**This is a combat change and it should be watched.** A fighter can now leave a
missile behind in a straight line rather than having to turn, so the missile's answer
to a fighter goes from "hard" to "only with a lead you set at launch". The combat POC
was validated with a fighter that could not do that. If arena play says this is wrong,
the fix is `fighter_speed_ceiling_fraction`, not a new rule.

The alternative was to raise `missile/base_speed` to about 89 so 80 fits under a
global cap. It loses because base speed times fuse is the missile's *reach*: that edit
takes the missile from 348 m to 534 m and re-opens every range number the combat POC
did settle, to protect an invariant that was never about fighters.

## What this forbids

- Do not restore a single global ceiling fraction across all classes. It cannot
  express what this ADR is about.
- Do not raise `missile/base_speed` to make a ship number fit. Base speed is reach,
  and reach is a combat decision, not a travel one.
- Do not add a class that outruns a missile without adding it to
  `outrun_by_missile()`'s exception by name and saying why. The default is that a
  missile can catch you.
- Do not let a taxi or a capital past missile speed at any tuning. That is the part
  the gate is guarding, and it is the part that matters.
- Do not read `MAX_CEILING_FRACTION` as a design statement. It is a typo guard.
