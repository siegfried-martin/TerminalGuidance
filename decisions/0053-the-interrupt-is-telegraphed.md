# ADR 0053 — The interrupt is telegraphed before it happens, and the miss is decided at launch

*Status: accepted · 2026-08-27 · from building stage 6 of `docs/TURRET_MODE_IMPLEMENTATION.md`*

## Decision

1. **The interrupt is announced `enemy/interrupt_warning_lead_seconds` before the
   launch, not as the missile arrives.** The telegraph is a separate event from the
   launch, and it fires once per cycle.
2. **The alert is built loud, to be tuned down.** The specification asked for "a
   small alert"; `PROJECT_OVERVIEW.md` Pillar 2 asks for one that is "loud,
   telegraphed, unambiguous". Where those conflict, it ships prominent — a banner
   across the top plus a bracket on the missile itself — with every dimension in
   tuning.
3. **The aim error is sampled once at launch and never corrected.** The missile
   flies at a fixed offset from the ship, so the miss is decided when it leaves and
   is the same miss all the way in.
4. **The interrupt is a timer, and the blockers are a range test and a roll.**
   Neither leads the player, chooses a moment, or holds fire.
5. **The enemy missile is bound by the speed hierarchy from the other side:** it
   may not exceed the player's own missile at full boost.
6. **The player is invulnerable for this build**, at the human's direction, and hits
   still register — counted, and flashed round the edge of the screen.

## Why

**1 and 2 are the same rule: a spike, never ambient.** `CLAUDE.md` is explicit that
*"stress is a spike, never ambient"*, and Pillar 2 adds that it must be possible to
**win both** — a player who is quick detonates on target *and* makes the turret in
time. Neither is true of an interrupt announced as it arrives:

- With no lead, the only way to survive one is to already be at the gun, which
  means never committing to a ride. That is ambient pressure with extra steps.
- An alert small enough to miss converts a punctual spike into background dread,
  which is the precise failure the target-experience guard exists to prevent.

Building it loud and tuning down is the safe direction to be wrong in. Building it
small and tuning up means shipping the failure mode and discovering it by feel.

The lead is therefore constrained *against the fuse*: it has to exceed a typical
remaining ride, or "win both" is arithmetically impossible.

**3 keeps the outcome readable.** The alternative — perfect guidance plus a random
roll at the end — makes the missile's line tell the player nothing, and the result
arrives as a verdict. A constant offset means the missile's course *is* the
information: it is visibly going to pass wide, or visibly not, and the player can
decide whether to spend rounds on it. That is the same reasoning as ADR 0051's
flares: the game's threats should be things you can look at.

**4 is ADR 0013 and ADR 0014 applied to the other side.** Those keep NPCs from
making decisions about the player's ship; this keeps them from making decisions
about the player's *shot*. An enemy that waited for a good moment, led the player,
or held fire while they were mid-ride would be reacting to what the player was
doing — which is exactly the "pulled out of what you were doing by an NPC's
decision" that the guard forbids. A timer is not a decision.

**5 is the speed hierarchy being structural rather than one-sided.** If an enemy
missile could outrun the player's own, it would also outrun the autocannon rounds
meant to intercept it, and the interrupt would be unanswerable by construction.

**6 sharpens the reading.** Step 8 asks *"does being pulled to the turret disrupt
the rhythm?"* — a pacing question, answerable without a consequence for failing.
Damage now would mix a pacing signal with a difficulty signal and neither could be
read cleanly. But a hit must still be **legible**, or a failed intercept is
indistinguishable from one that never arrived and there is nothing to pace against.
So it is counted, and it flashes. Turning damage on later is one tuning flip, and
the plumbing has been proven by the pacing test itself.

## What this forbids

- **Do not fire an interrupt without its telegraph**, and do not shorten the lead
  below a typical remaining ride. If interrupts feel too easy, the answer is a
  shorter interval or a tougher missile, never a shorter warning.
- **Do not make the alert subtle before it has been felt.** It exists to be tuned
  down from prominent, and `hud/alert_*` is where that happens.
- **Do not correct the aim error in flight**, add terminal guidance, or re-roll at
  impact. The miss is decided at launch and stays decided.
- **Do not give the enemy a decision.** No leading, no waiting for the player to be
  mid-ride, no holding fire, no volume of fire that scales with how well the player
  is doing. A timer and a roll.
- **Do not raise `enemy/missile_speed` past the player's boosted missile.** The
  clamp will ignore it; changing the clamp makes the interrupt unanswerable.
- **Do not remove the hit counter or the flash when damage is turned on.** They are
  the feedback; HP is the consequence, and they are separate things.
