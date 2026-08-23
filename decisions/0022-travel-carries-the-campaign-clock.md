# ADR 0022 — Travel carries the campaign clock

*Status: accepted · 2026-08-23 · recorded from `docs/PROJECT_OVERVIEW.md` v3 and `docs/COMBAT_POC_IMPLEMENTATION.md` v3; the decision predates this repo*

## Decision

The war advances in real time while the player flies. There is no abstracted jump
duration and no separate campaign tick the player watches.

## Why

This falls out of continuous travel (ADR 0009) and is why it matters: the player
arrives at a board that changed for reasons they can feel, rather than watching a
counter report. Invasions are witnessed, not reported.

Void Crew's most cited weakness among solo players is that its world felt empty and
lifeless. Consequence-bearing faction activity running on the travel clock is the
antidote.

## What this forbids

- Do not add a time-skip, a "wait" action, or a campaign advance the player
  triggers.
- The world sim must run on wall-clock play time, not on discrete travel events.
