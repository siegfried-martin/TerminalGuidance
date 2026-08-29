# ADR 0013 — Autopilot is a heading hold and nothing more

*Status: accepted, clarified by ADR 0058*

> **Not superseded.** `EXPLORATION_DESIGN.md` says "autopilot is your own character
> flying while you are elsewhere", which describes a **hired crew pilot** — a future
> NPC that happens to hold the same stick. The autopilot in this codebase is
> unchanged and stays bounded exactly as below. Do not grow *this* one into that
> one; a crew pilot arrives as its own system, and until it does the forbid clause
> here holds without exception.

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
