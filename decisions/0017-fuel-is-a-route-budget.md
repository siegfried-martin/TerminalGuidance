# ADR 0017 — Fuel is a route budget traded against cargo; stranding is recoverable

*Status: accepted · 2026-08-23 · recorded from `docs/PROJECT_OVERVIEW.md` v3 and `docs/COMBAT_POC_IMPLEMENTATION.md` v3; the decision predates this repo*

## Decision

Fuel is spent by the route, which makes tankage a real fitting decision traded
against cargo space — peace of mind costs you hold. Running dry is always
recoverable.

## Why

Fuel passes the pressure rule: the player chose the route, could see the cost
before committing, and can turn back. It is a planning budget, not a needle to
watch. This is exactly the case that motivated narrowing the v2 "no resource
anxiety" prohibition (see ADR 0021).

The specific failure to avoid is being broke and stranded with the money to fix it
sitting somewhere the fuel would have taken you. Rescue is expensive and
embarrassing, and the encounter is a fine place for genre color — the helpful
merchant who is sometimes a pirate springing a trap, and whose fuel you take if you
win.

## What this forbids

- Travel time and fuel cost must be visible **at the moment the player would point
  the ship**, not discovered thirty minutes in. A soft gate is only a gate if the
  cost is legible while deciding.
- Running dry must never be a softlock.
- Do not add a fuel drain the player did not elect by choosing a route.
