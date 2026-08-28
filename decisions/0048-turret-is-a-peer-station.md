# ADR 0048 — The gun station is a peer of the helm, and its aim is 1:1 in the arena frame

*Status: accepted, the helm-only launch clause superseded by ADR 0056 · 2026-08-27 · from building stage 1 of `docs/TURRET_MODE_IMPLEMENTATION.md`*

> **Superseded in part by ADR 0056.** Point 2 below — no TURRET → MISSILE edge —
> is reversed: `Q` launches from either station. The sequential-attention reasoning
> does not survive the crew roster, because launching moves the player *into* the
> missile in the same frame, and a helm-only launch would force the gunner to take
> the helm first and drop the autopilot every time they wanted to fire. Everything
> else here — the station as a peer of the helm, the aim in the arena frame, the
> 1:1 mouse, the levelled boom — stands.

## Decision

Four things about the turret, decided together because each one is only defensible
in the light of the others.

1. **TURRET is a third view and a peer of SHIP**, not a sub-state of it. `G` mans
   the guns exactly as `T` takes the helm. Manning the station takes the helm out
   of the player's hands — the ship keeps its autopilot or coasts, but stops
   reading input, the same way it does while a missile is being ridden.
2. **A missile is launched from the helm only.** There is no TURRET → MISSILE edge.
   `CombatArena.fire()` refuses in turret view, and the refusal lives there rather
   than in the input handler so it holds however `fire()` is reached.
3. **The aim lives in the arena frame, as an azimuth and an elevation** — not as a
   rotation of the ship, and not as a `Node3D` parented to the hull. The mount
   point rides the ship; the aim does not. The bearing is held while unmanned, and
   is set to the hull's nose exactly once, at construction.
4. **The mouse aims the gun 1:1, with no reticle and no lag.** ADR 0035's two-stage
   reticle steering is deliberately *not* used here. The gamepad stick still sweeps
   at a rate, because a stick has no other way to express a position.

A fifth, smaller, follows from 3: the turret camera's boom levels against the
horizon instead of following the gun's elevation rigidly
(`camera/turret_boom_pitch_share`). It still *looks* along the true aim.

## Why

**1 and 2 are the sequential-attention rule made structural.** `CLAUDE.md`:
"the player's attention is sequential, never parallel", and ADR 0008 says the same
in stronger terms. A turret that could be manned while still flying, or fired from
while a missile was in the air, would be exactly the parallel-attention state both
of those forbid — and it would arrive by accident rather than by decision, because
every station polls the same keys. Making the stations mutually exclusive means the
rule cannot be broken by a later change that merely forgets about it.

The `fire()` gate is in the arena rather than the input handler because a rule that
only exists on one path is a rule that the second caller will break. The headless
gate calls `fire()` directly, and it is now covered by the same refusal a click is.

**3 is what makes it a turret rather than a nose gun.** If the aim were stored
relative to the hull, an arcing autopilot would drag the gun off target at
`ship/arc_speed` while the player held still — the control would be moving without
being touched. Storing it in the arena frame (parent-relative, so ADR 0020's
floating origin leaves it valid) means the ship manoeuvres underneath a gun that
stays where it was pointed, which is both correct and the thing that makes manning
the guns while the autopilot flies a coherent act.

Storing it as two scalars rather than a basis also means **roll has nowhere to
hide** (ADR 0045). There is no third degree of freedom to accumulate into.

**4 is a real departure from ADR 0035, and the reason is the weapons.** The reticle
exists to give a *vehicle* weight: input is instant, the vehicle lags, and the gap
between them is the handling model. A gun has no mass to express. More concretely,
one of the four specified weapons is **hitscan on purpose** — the human's spec calls
that a design requirement, so lead and travel time need not be reasoned about — and
an aim that lags behind a hitscan weapon is a control that lies about where the shot
went. ADR 0035 is not superseded; it is scoped to things that fly.

**The levelled boom** is a defect fix, not a preference. The gun elevates far
enough that a rigid boom swings the camera down and back through the hull the gun
is mounted on, and the player would then be aiming from inside their own ship. A
level boom with the look point still on the true aim puts the muzzle low in frame,
which is what a turret looks like anyway. The share is tuned, so 1.0 restores the
rigid boom every other view has.

## What this forbids

- **Do not let the helm and the guns both read input in the same frame.** Any new
  station added later must take the others' input away on entry, not share it.
- **Do not add a TURRET → MISSILE transition**, and do not "helpfully" return the
  player to the turret after a missile ends. A missile is fired from the helm and
  ends at the helm.
- **Do not parent the aim to the ship**, and do not re-point the gun on entry, on a
  view change, or when the target moves. The station holds its bearing; pointing it
  is the player's job. In particular, do not add lead prediction, auto-track, or
  snap-to-target — ADR 0013's bound on the autopilot ("it does not path, avoid,
  arrive, or make decisions") is the same bound, for the same reason.
- **Do not give the turret a reticle.** If a later weapon genuinely needs one, that
  is a new ADR naming the weapon, not a quiet reuse of `ReticleSteering`.
- **Do not add roll to the station**, and do not replace the azimuth/elevation pair
  with a stored basis "for convenience". The pair is the guarantee.
- **Do not widen the elevation limit to "just in case" values.** Every ship shares
  one horizon (ADR 0045), so a gun that elevates a long way is aiming at empty
  space; the limit's real job is keeping the camera boom somewhere sane. Widening
  it is a decision about what the shared plane means, not a convenience.
