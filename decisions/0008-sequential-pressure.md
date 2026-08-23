# ADR 0008 — Pressure is sequential, never parallel

*Status: accepted · 2026-08-23 · recorded from `docs/PROJECT_OVERVIEW.md` v3 and `docs/COMBAT_POC_IMPLEMENTATION.md` v3; the decision predates this repo*

## Decision

Every job — pilot, gunner, missile — gets the player's whole attention while they
are in it. The design never requires attending to two fronts at once.

## Why

This is the structural lesson of the RTS→MOBA transition: what broadened that
audience was not reduced difficulty or lower stakes, but the removal of the demand
to manage several fronts simultaneously.

The interrupt (an incoming missile while the player is riding) is the one place
this is tested, and it is bounded by two rules: its frequency is *surprisingly low*,
and it must be **possible to win both** — a player close enough and fast enough
detonates on target and still makes the turret in time. The interrupt is an
opportunity to show off, not a tax for being in the missile.

## What this forbids

- Flag any proposal that requires monitoring one system while operating another.
- Do not raise `enemy.interrupt_interval_seconds` casually. It starts disabled and
  is the single easiest way to turn a relaxed game into a stressful one.
