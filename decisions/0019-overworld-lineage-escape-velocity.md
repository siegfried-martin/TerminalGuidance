# ADR 0019 — Overworld lineage is Escape Velocity, not Mount & Blade

*Status: accepted · 2026-08-23 · recorded from `docs/PROJECT_OVERVIEW.md` v3 and `docs/COMBAT_POC_IMPLEMENTATION.md` v3; the decision predates this repo*

## Decision

The starmap is a planning and information UI. All actual play happens in a ship,
in real space. This supersedes the v1–v2 framing of "Mount & Blade's overworld
model applied to space."

Recorded as a correction because the wrong framing was load-bearing and actively
misdirected design work.

## Why

M&B's campaign map is a place you *act*: parties intercept you, army size trades
against speed, sieges happen on it. That map exists to make army logistics a
decision. This game commonly fields 2–5 ships and a couple dozen at the large end.
There is no logistics layer to model, and without one the map is a slow menu.

Since travel is continuous and real-time, *the campaign clock is carried by travel
itself* (ADR 0022).

## What this forbids

- Do not add interception, encounter rolls, or any resolved event to the starmap.
- Do not put gameplay on the map layer. It informs; it is not played.
