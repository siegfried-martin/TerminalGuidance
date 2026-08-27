# ADR 0047 — Brake and boost are missile-tier equipment, not baseline verbs

*Status: accepted · 2026-08-27 · human direction with the POC verdict: they "give a much higher skill ceiling that feels believable"*

## Decision

The starting missile flies with reticle steering, a fuse and early detonate, and
nothing else. **Brake and boost arrive with higher-tier missiles**, bought or
earned, not present from the first shot.

Dodge is not assigned a tier here. Where it sits is open.

## Why

This is Pillar 1's existing rule — "the upgrade tree is itself a difficulty dial
the player earns the right to use" — applied to the two verbs that turned out to
carry the skill ceiling. It is recorded because ADR 0039 introduced boost, brake
and dodge as though they were simply what a missile does, and that is now wrong.

The human's reading after playing it: brake and boost are what make the ceiling
high and believable. That cuts both ways. A verb that raises the ceiling that much
is also the verb that makes the first hour harder to read, and handing all of it
over at minute one spends the best progression beat the combat system has. A player
whose first missiles fly plain has somewhere to go, and the thing they are going
toward is a *capability* rather than a number.

It also protects the fuse. ADR 0002 makes fuse-as-range the load-bearing difficulty
dial, and boost buys reach against the reserve — a starting missile with boost has
a fuzzier range limit than one without, exactly when the player is still learning
to read it.

## What this forbids

- Do not ship the starting missile with brake or boost, and do not "temporarily"
  enable them for playtesting without saying so — a feel verdict taken on a fully
  equipped missile says nothing about the opening hour.
- Do not turn the tier gate into a stat bump. The point is that a higher tier gives
  a *verb*, not a bigger number; if tiers end up as +10% speed each, this decision
  has been lost.
- Do not gate reticle steering, the fuse, or early detonate. Those are the missile.
  A player who cannot aim, cannot reach, or cannot abort has no game to learn.
- Do not make an upgrade strictly better with no cost to carry. ADR 0024 biases
  toward power fantasy, but a tree of pure upgrades is a tree with no decisions in
  it; speed already costs difficulty (Pillar 1) and boost already costs reserve.
- The tuning file stays the source of truth for the *values* (ADR 0026). Tiers
  decide which keys a given missile reads, never what they contain.
