# ADR 0042 — The target carries destructible components, and they are tested before the hull

*Status: accepted · 2026-08-26 · a feel experiment the human asked for: "I want to see if something akin to target practice is better"*

## Decision

The target ship is built from primitives into a silhouette with a front and a back
— fuselage, nose cone, wings, fin — and carries `enemy/component_count` cylinders
ringed around its spine. Each component:

- has its own hit sphere, **tested before the hull's**;
- takes `enemy/component_hits_to_destroy` hits, darkening on each;
- on the last hit, disappears and borrows the missile's own detonation flash;
- returns after `enemy/component_respawn_seconds`.

`enemy/component_count = 0` restores the single-hit-sphere target, so the two can
be felt back to back.

**The target ship itself still has no hit points and never dies.** That is POC step
9 and it is not this.

## Why

The question is the human's: does a target with several small things worth aiming
at beat one big thing worth hitting? It is a real fork for the POC's third success
criterion — whether there is a felt difference between an early missile and a late
one — and it is cheap to answer now and expensive to guess.

The hull was a cube. A cube cannot answer the question, because a cube gives the
eye nothing to aim at: every hit on it is indistinguishable from arrival, so
"did I aim well?" has no observable answer. Rebuilding the hull is not decoration
here, it is the instrument.

Components are tested before the hull because they sit inside the hull's own
9-metre hit sphere, so a shot that could be credited to either would otherwise
always go to the hull, and no component would ever be hit. Ordering the test is the
whole mechanism.

Respawn exists because without it a practice run is over after a handful of hits,
and the loop cannot be felt twice in one sitting. It is a harness for the
experiment, not a claim about how a real enemy should behave.

The flash is reused rather than authored. A secondary explosion is art, and this is
gray-box (ADR 0030). The darkening hit deliberately gets *no* flash: the shade
change is the feedback, and flashing on both would make the two outcomes read the
same, which is the one thing the experiment cannot afford.

This does front-run part of POC step 9's hit feedback, at the human's explicit
direction. It is recorded here so a future session does not read it as step 9 being
done.

## What this forbids

- Do not give the target ship hit points, death or respawn on the strength of this.
  Components are not the ship. Step 9 is still step 9.
- Do not test the hull before the components. That inverts the mechanism and
  silently makes every component unreachable — a bug that presents as "the
  components do nothing" with no error anywhere.
- Do not let components extend past `enemy/radius`. The hull is not hit-tested
  shape-accurately the way the rocks are (ADR 0041), so a component outside the
  hull's sphere is reachable from angles where the hull is not, and hit generosity
  starts depending on approach direction for no stated reason. The headless gate
  checks this.
- Do not make components shoot, emit, warn, or otherwise act. They are things to
  aim at. Enemy fire is POC step 7 and the interrupt is step 8, and both have feel
  checkpoints attached that this would spoil.
- Do not tie a component's destruction to any penalty for the player. There is no
  timer on the practice loop and no cost to missing — the target-experience guard
  in `CLAUDE.md` is about exactly this, and target practice is the safest possible
  place to accidentally introduce a background threat.
