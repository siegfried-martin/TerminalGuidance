# ADR 0077 — Traffic runs on the right, and the deck convention is retired

*Status: accepted · 2026-08-31 · from concept art of an industrial highway, and from
four sessions of tuning a road that never read as a place*

## Decision

**The two directions run side by side, not stacked.** Each carriageway sits half of
`deck_separation` to the side of the spine, along the spine's own rightward normal
*as that carriageway travels*. In code the whole of it is one expression, evaluated
per point:

```gdscript
var side := travel.cross(Vector3.UP)   # travel already carries the deck's sense
```

**Traffic runs on the right.** The consequence is that the oncoming lane is on your
left from either driver's seat, at any bearing, in any frame.

**The upper/lower deck convention is retired, not replaced.** `RoadDeck.rides_upper`
is deleted, `is_upper` becomes `runs_forward`, and *Enforced Invariant 1* —
"no road segment's heading may cross the northwest–southeast divider", with its
physical twist and its ban on ring roads — goes with it.

`runs_forward` survives as a **grouping key and nothing else**: the union may only
consider decks that agree on it, so ADR 0067's "no oncoming traffic in your lane"
stays structural. It carries no side information and nothing may derive one from it.

**One new invariant replaces the one deleted: the road may not bend tighter than the
carriageways are far apart.** Minimum curve radius must exceed `deck_separation`.

## Why

The convention existed to be a **mistake-catcher** — *"I am heading east, why am I on
the lower deck?"* — and its cost was an invariant that forbade a road from turning
more than 180 degrees over its whole length. That is a large thing to pay for a
mnemonic, and it made X4's signature ring road illegal here.

**Right-hand traffic is self-orienting, so the mnemonic is not needed.** Two
anti-parallel lanes side by side answer "which one is mine" from the geometry alone,
with nothing declared, nothing derived from a heading, and no arc to remember. What
was a rule is now a fact about the section, and it holds at every bearing — which is
exactly what the divider invariant existed to prevent the old convention from having
to do. Deleting the rule and deleting its enforcement are the same act.

Three things fall out that were not the reason but are worth having. Ring roads and
long curved trunk routes become legal. `shade()` loses its deck argument entirely —
the median is on the left of both carriageways, so one function answers for both and
the seam is one colour by construction rather than by two mirrored cases agreeing.
And the road's roof drops by half a separation, since the pair is now wide rather
than tall.

**The cost is real and is why the new invariant exists.** `_lifted` chose a vertical
offset specifically so both decks came out the same length on a bend. A lateral offset
does not have that property: through a curve the inner carriageway is genuinely
shorter, which is what a divided highway does — until the bend is tighter than the
offset, at which point the inner lane folds through itself and stops being a lane.
That is a geometric floor, not a feel value, so the gate checks it against the spine's
own `max_turn_deg_per_metre`.

This is step A of `docs/HIGHWAY_STRUCTURE_PLAN.md`, and it is deliberately the *only*
thing in it: the same shell, moved. The structure becoming modules is step B and has
its own ADR.

## What this forbids

- Do not reintroduce a deck convention, a divider, a bearing arc, or a twist. Which
  side a carriageway is on is a consequence of which way it goes, and there is nothing
  left to declare or to check a declaration against.
- Do not derive a side, an up, or a colour from `runs_forward`. It is a grouping key.
  Anything that needs a side takes it from `travel.cross(Vector3.UP)` at the point it
  cares about, because on a weaving leg the two answers differ.
- Do not stack the carriageways again to recover equal deck lengths. Unequal lengths
  through a bend are correct; the radius floor is what keeps them sane.
- Do not raise `deck_separation` to fix a road that folds. The road is bending too
  tightly — the separation is the measurement being violated, not the cause.
- Do not let `deck_separation` fall below `lane_width`. Below it the two lanes
  intersect and "no oncoming traffic in your lane" quietly stops being structural.
- Do not read the retirement of Enforced Invariant 1 as permission for a road to turn
  arbitrarily. ADR 0070 still stands: no road out-turns the ship.
