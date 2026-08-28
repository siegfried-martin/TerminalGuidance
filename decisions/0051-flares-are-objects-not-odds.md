# ADR 0051 — A flare is an object in the way, not a chance of being fooled

*Status: accepted · 2026-08-27 · from building stage 4 of `docs/TURRET_MODE_IMPLEMENTATION.md`*

## Decision

1. **A flare is a physical sphere.** A missile whose swept segment touches a flare
   of the other side dies. There is no seduction, no decoy tracking, no probability
   of being fooled, and no lock to break.
2. **One flare stops one missile and is spent.** A star of six is worth six
   interceptions, and the star is drawn as exactly the six spheres it is.
3. **A star is a ring perpendicular to the threat axis**, leaned towards it by
   `flare/forward_bias` — a wall across the missile's path, not a cone down it.
4. **The enemy rolls once per incoming missile, not once per frame.** The roll is
   recorded against that missile's instance and never repeated, whether or not the
   launcher was in a position to answer.
5. **Membership is by Godot group** (`player_missile`, `flare`), not by a registry.
   A warhead joins `player_missile`; a solid autocannon round does not.

## Why

**1 is the target-experience guard applied to a countermeasure.** The genre default
here is a probability: the missile is "seduced" and the player watches a die roll
resolve off screen. That is a condition imposed on them — they cannot see it coming,
cannot act on it, and cannot learn anything from it. A flare that is simply *there*
is the opposite: it is visible before the missile reaches it, the counter to it is
flying around it, and getting better at that is a skill the player can feel
themselves acquiring. It also fits `DESIGN.md`'s bet, which is that the missile is
the game — anything that resolves the missile's fate without the player's hands on
it is taking the game away.

The doc's Flag 6 already cleared enemy countermeasures against the pressure rule:
the player chose to fire, the counter is a visible answer to their own action, the
missile is expendable, and nothing is imposed while they are doing something else.
This ADR is what makes "visible" literally true.

**2 keeps the accounting legible.** A flare that stopped a missile and stayed would
make a single star an impassable wall for its whole four seconds, and the player
could not tell how much was left of it. One flare, one missile, and what is left is
what is on screen.

**3 is geometry, not decoration.** A cone thrown down the threat axis is a line of
flares the missile flies between; the ring across it is the shape that actually
blocks. The forward bias exists so the wall is thrown out to meet the missile
rather than dropped in place, and it is bounded below 1 because at 1 the star
degenerates into that useless line.

**4 is the difference between a tuned chance and no chance at all.** At 60 fps a
per-frame roll of 0.5 fires on the first frame every time, and `enemy/blocker_chance`
would be a number with no effect that nobody would notice was broken. Recording the
roll against the missile also means "answered" and "answered successfully" stay
distinct: a missile arriving while the launcher is cooling has still had its roll,
so a fast second shot is not silently given two chances at a blocker.

**5 is because flares free themselves.** A hand-kept list of live countermeasures
would rot the first time one expired without telling anyone. The warhead/bullet
distinction is joined at `launch` rather than in `_ready`, because which weapon a
`Projectile` is only becomes known when it is launched.

## What this forbids

- **Do not give a flare a chance to work.** No seduction roll, no lock-break
  probability, no "the missile is distracted for N seconds". If flares turn out to
  be too strong, they get fewer, smaller, slower or shorter-lived — all of which the
  player can see.
- **Do not let one flare stop two missiles**, and do not draw a star as anything
  other than the flares it contains.
- **Do not roll per frame** anywhere a per-event chance is meant, and do not re-roll
  a missile that has already been answered.
- **Do not make the enemy's blocker a decision** — a range test and a roll is the
  whole of it. Leading the missile, choosing the moment, or holding fire for a
  better one would be an NPC making decisions about the player's shot, which is the
  shape ADR 0013 and ADR 0014 keep out of this game.
- **Do not put solid rounds in `player_missile`.** A countermeasure that stops
  bullets is a shield, which is a different mechanic and not one this game has.
