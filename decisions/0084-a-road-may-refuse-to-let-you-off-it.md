# ADR 0084 — A road may refuse to let you off it, and it refuses by not being a candidate

*Status: accepted · 2026-08-31 · from the human: "the same red barrier … should exist for any vehicle entering an off ramp"*

## Decision

**Every exit carries a permission surface across its mouth**, blue if you may take it
and red if you may not — the same split ADR 0060 makes at a portal, in the same
colours, at the other end of the ramp. **The steel ring is the building; the sheen is
the permission** (ADR 0080).

`RoadDeck.passable` is what it gates, and exactly two things read it:

- **The lane union** does not offer a road you may not take.
- **The exit sign** for a closed ramp is dark and cannot be clicked.

**It refuses; it does not block.** Nothing stops the ship, slows it, or steers it. A
closed exit is a turn you may not take, and the player drives past it.

Today it is driven by the same rule that reddens a portal. **What it is for is
standing** — a system that will not let you off its highway because you are not on good
terms with whoever runs it.

## Why

An on-ramp has been able to refuse since ADR 0060, and it is the clearest thing in the
game: cycle to a fighter and every portal on screen turns red. An **exit** had nothing.
There was no surface, no colour, and no way for a road to decline. That asymmetry was
invisible while the only reason to refuse was "this hull has no cruise drive" — a hull
that cannot get on the road never needs to be told it cannot get off it — and it
becomes load-bearing the moment refusal has a second reason.

**Refusing by candidacy rather than by collision is the whole design.** ADR 0014
forbids anything that stops the player's ship, and a barrier across an exit is exactly
that with a friendlier name. Removing the ramp from the union is the honest expression:
the road is still there, you can still see it, and the geometry simply never hands it
to you. The player finds out by reading a red mouth from the road they are on — before
committing, which is what ADR 0012 asks of everything that offers something.

**The sign has to go dark with it.** A refusal you only discover after choosing is not
a refusal, it is a trap, and the berth's whole value is that a player in a hurry can
select an exit and trust it.

**What is deliberately not built:** the reason. There is no reputation, no faction, and
no rule about who closes what. This is the surface and the two honourings; the reason
belongs to a system that does not exist yet, and inventing one here would be an ADR
asserting something nobody has decided.

## What this forbids

- Do not make a closed exit stop, slow, or deflect the ship. It is not a candidate;
  that is all it is.
- Do not let a closed exit's sign stay clickable, or let a click on one fail silently.
  Dark before the choice, not refused after it.
- Do not invent the reason a road refuses. When standing exists it sets `passable`, and
  until then the only source is the same one that reddens a portal.
- Do not add a third reader of `passable`. Two things honour it — the union and the
  sign — and a third would be a rule about refusal rather than a consequence of it.
- Do not put the gate on the ramp. It is read from the road you are on, before you are
  committed, which is why it hangs in the opening rather than down the ramp.
