# ADR 0010 — Continuous engine speed contested by mass, not tiered drive tech

*Status: accepted · 2026-08-23 · recorded from `docs/PROJECT_OVERVIEW.md` v3 and `docs/COMBAT_POC_IMPLEMENTATION.md` v3; the decision predates this repo*

## Decision

Engines upgrade continuously. There is no drive tech that gates a category of
destination. Speed is contested by mass — a larger cargo hold is slower — so the
hauler and the courier are different ships and neither is upgrading toward the
other. Distance gates regions *softly*: time, fuel, and zero standing on arrival.

## Why

A mass/speed tradeoff generates a decision on every trip (sell more, or beat the
other merchants to a temporary high-demand market). A tech gate generates one
decision, once.

Soft gating is also more consistent with fixed-difficulty regions than a tech
unlock would be. A distant cluster is reachable at hour two, but the crossing is
long, the fuel cost is real, and you arrive with no standing and no contacts. The
door is open and the world tells you *not yet*. That is the Morrowind gate; a tech
unlock is a menu wearing an engine's clothes.

## What this forbids

- Do not add a drive tier, jump-range class, or any unlock that makes a destination
  reachable that was not reachable before.
- Do not let engine upgrades escape the mass tradeoff.
