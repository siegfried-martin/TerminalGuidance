# ADR 0067 — Getting on and off the road is a union of lanes, not a junction

*Status: accepted · 2026-08-30 · from building the interchange*

## Decision

A direction of road is **several decks** — one mainline and a pair of ramps at each
system — and which one the ship is on is resolved the same way the boundary resolves
its regions (ADR 0063): every deck going the player's way is asked how far outside it
they are, and **the one they are least outside of governs**.

Running off the end of a deck hands over to whatever else contains the ship; running
off the end with nothing to hand to is the end of the road.

**No junction logic exists, and none should be written.** There is no merge state, no
diverge trigger, no "you have taken the exit" moment.

## Why

Merging and diverging are the only two things an interchange has to do, and both are
already implied by geometry. Approaching an off-ramp the mainline and the ramp share
a centre-line, so the mainline governs by being wider and nearer; steering toward the
ramp makes the ramp the nearer answer and it takes over. At the top of an on-ramp the
mainline contains the ship and the ramp has run out, so the handover happens because
there is nowhere else to be.

Written as a state machine instead, the same interchange needs: a trigger volume, a
decision about what counts as committed, a rule for changing your mind halfway, and a
recovery for arriving in the volume sideways. Every one of those is a place for the
road to grab the player, and **a road that decides where you are going is the
conveyor this whole design rejects** (ADR 0057).

It also means route choice keeps happening where the design says it does. ADR 0057
forbids junctions and prices a missed turn at one hop off and back on. Here, missing
an exit is exactly that and costs exactly that, with no rule saying so.

The grouping by deck is what keeps it safe: only decks sharing `is_upper` are ever
considered, so the union can never hand a ship the oncoming lane. One-way stays
structural rather than becoming a check.

## What this forbids

- Do not add a junction, a merge state, a diverge trigger, or a commitment point. If
  a change needs one, the geometry is wrong, not the resolver.
- Do not consider decks going the other way. Oncoming traffic in the player's lane is
  prevented by the grouping, not by a rule about NPCs.
- Do not snap, pull, or steer the ship onto a deck when it takes over. The handover
  changes which lane the ship is measured against and nothing else; ADR 0064's push
  is the lane's only physical influence and it is still soft.
- Do not make the end of a deck a wall or a stop. It hands over, or the road has run
  out and the drive winds down (ADR 0066).
- Do not build a ramp that serves nobody. An opening onto a road with no traffic and
  a sign with no name on it is worse than no ramp.
