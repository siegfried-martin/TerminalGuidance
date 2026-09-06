# ADR 0013 — Autopilot is a heading hold and nothing more

*Status: accepted, clarified by ADR 0058*

> **Reframed, not superseded.** `EXPLORATION_DESIGN.md` says "autopilot is your own
> character flying while you are elsewhere", and that is a statement about **what
> the autopilot already is**, not a request for a different system. Every station
> is a person who keeps doing their job — worse — when the player switches away
> from it. The heading hold below is what a pilot doing their job looks like, and
> the human's reading of it is that it already does this well.
>
> What that changes is the *framing*: a better pilot is a **better number**, not
> more authority. Competence scales; the bounds do not. Everything in §What this
> forbids holds exactly as written, and it holds harder now — "hiring a better
> pilot" must never become the reason to add pathfinding, avoidance, or arrival to
> a system that is a person's competence rather than a difficulty setting.
>
> ADR 0058 is the ceiling on that number: an NPC at any station, at any price, is
> worse than the player at it.

*Status: accepted · 2026-08-23 · recorded from `docs/PROJECT_OVERVIEW.md` v3 and `docs/COMBAT_POC_IMPLEMENTATION.md` v3; the decision predates this repo*

## Decision

Autopilot keeps the nose pointed at a designated object. The player owns the
throttle. It does not path, does not avoid, does not "arrive," does not make
decisions.

## Why

It composes with everything and overrides nothing, and it cannot gate content
because it never had authority the player did not hand it.

The delegation contract is identical at combat and travel scale: **set a heading
and walk away and you arrive safely, but blind.** What inattention forfeits is
everything you would have seen along the way — the anomalies, derelicts and
unlisted contacts on the route. It never forfeits safety.

## What this forbids

- Do not grow autopilot. Not pathfinding, not obstacle avoidance, not arrival
  deceleration, not "smart" anything.
- Do not make any content reachable only with autopilot engaged or disengaged.
