# ADR 0014 — No interdiction — and cruise does not drop on damage either

*Status: accepted · 2026-08-23 · recorded from `docs/PROJECT_OVERVIEW.md` v3 and `docs/COMBAT_POC_IMPLEMENTATION.md` v3; the decision predates this repo*

## Decision

Cruise is dropped by player input alone. Never by an NPC's decision, and never by
taking damage. Sustained fire degrades top cruise speed instead, which lengthens
exposure on a curve the player can read.

## Why

"Drops on damage" is interdiction with an extra step: any pirate with a long-range
gun stops the player. That is the correction that makes the rest of the travel
design work.

The consequence is the point. Traveling through hostile space does not stop you; it
**costs** you. Cross the contested corridor and arrive scraped up, or route around
and pay in time and fuel. Dangerous regions become terrain — expensive to avoid,
costly to cross — which is the fixed-difficulty-region pillar expressed spatially.

A heavily defended corridor can genuinely bring a ship down, but gradually, on a
legible curve, with turning back available the whole way. That is a wager going
wrong rather than an ambush.

## What this forbids

- Flag any proposal that stops the player's ship because of something an NPC did.
  It is the genre default and it is deliberately rejected here.
- Damage may degrade speed. It may never interrupt.
