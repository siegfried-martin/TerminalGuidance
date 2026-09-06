# ADR 0059 — Every ship number is keyed by hull class, with a shared default

*Status: accepted · 2026-08-29 · from `docs/EXPLORATION_DESIGN.md` Enforced Invariants 2–5*

## Decision

Speeds, and eventually turn rates, missile properties, fuse and cooldown, are read
through `HullClass.num(kind, suffix, shared_key)` rather than by name. A call site
names both the per-class key it would use and the shared key it falls back to when
that class has no entry of its own.

Three consequences land with it:

1. **The speed ceiling is per class.** One global fraction of missile speed cannot
   express a taxi at 0.27 and a fighter at 0.67. What the invariant protects widens
   from *"missiles outrun ships"* to **"a missile outruns its intended targets"**,
   and each class declares its own headroom. Still a clamp applied in code, not a
   number a tuning session is trusted to respect.
2. **Autopilot arc speed is a fraction of the hull's own maximum, never an
   absolute.** 13.8 m/s was 0.41 of a 34 m/s ship; against a 15.5 m/s taxi the same
   absolute is 0.89, at which point flying yourself is decoration.
3. **Enemy drift is a fraction of its hull class's maximum.** 20 m/s against a
   15.5 m/s taxi means an enemy of the player's own class can simply leave.

## Why

The difference between "one value" and "a table keyed by class with a default" is
trivial now and a refactor across every consumer later. The *mechanism* is the
expensive part to retrofit, not the rows — so it lands while the table has three
of them, and a new class becomes a row in `tuning.cfg` rather than an edit at any
call site.

Naming both keys at the site is what keeps the feel-parameter law intact. A
`Tuning` getter takes no default, on purpose, so a typo errors instead of behaving
plausibly. Here the shared key is required and errors if absent; only the *class*
key is optional, and a typo in one resolves to the shared value rather than to
silence. That is the weakest point of this design and it is the reason every class
speed is in `REQUIRED_TUNING_KEYS`.

Absolutes are the specific failure this exists to stop, and it is a silent one:
a number that was correct at 34 m/s inverts a relationship at 15.5 and nothing
anywhere reports an error. It presents as "the enemy runs away now."

## What this forbids

- Do not read a per-ship number straight out of `Tuning` at a call site that knows
  what class the ship is. Ask `HullClass`.
- Do not express a speed relationship between two ships as an absolute. Arc speed,
  drift, patrol, and every escort or formation speed that arrives later are
  fractions of a hull maximum.
- Do not widen the shared `ship/manual_speed_ceiling_fraction` to fit a fast hull.
  Give that class its own ceiling.
- Do not add a hull class in code. It is an enum row plus tuning rows, and both
  land in the same change.
