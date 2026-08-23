# ADR 0004 — Splash damage is steeply worse than a direct hit

*Status: accepted · 2026-08-23 · recorded from `docs/PROJECT_OVERVIEW.md` v3 and `docs/COMBAT_POC_IMPLEMENTATION.md` v3; the decision predates this repo*

## Decision

Player-triggered early detonation deals partial damage in a radius. The splash
fraction is steeply below a direct hit (`missile.splash_damage_fraction`, starting
at 0.25).

## Why

Early detonation turns a miss from a binary anticlimax into a graded outcome, which
is worth having. But if splash is close to a direct hit, the optimal play becomes
"detonate near the target every time," which deletes the skill game that
fuse-as-range and steering exist to create.

Steeply worse keeps the graded outcome as a consolation, not a strategy.

## What this forbids

- Do not tune splash upward to make missiles feel more reliable. Reliability is
  earned by flying better, not by widening the forgiveness radius.
- Splash is a consolation, never a build.
