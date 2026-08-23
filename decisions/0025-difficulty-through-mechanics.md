# ADR 0025 — Difficulty is selected through mechanics, never through a menu

*Status: accepted · 2026-08-23 · recorded from `docs/PROJECT_OVERVIEW.md` v3 and `docs/COMBAT_POC_IMPLEMENTATION.md` v3; the decision predates this repo*

## Decision

All difficulty dials are player-controlled and diegetic: fuse-as-range (risk set
per shot), crew hiring (delegate what you do not enjoy), fixed-difficulty regions
(geography is the slider), missile speed upgrades (an optional earned difficulty
increase), and route choice.

## Why

A difficulty menu asks the player to predict, before playing, how good they will
be. A mechanical dial lets them answer that question continuously, with their
hands, in the middle of the thing they are already doing — and it means the answer
can differ shot to shot.

Faster missiles are strictly better (range, rate of fire) but harder to fly, so the
upgrade tree is itself a difficulty dial the player earns the right to use.

## What this forbids

- No difficulty setting in a menu.
- Every dial must be visible, reversible, and expressed as a thing the player does.
- The cautious setting must remain viable, not merely possible.
