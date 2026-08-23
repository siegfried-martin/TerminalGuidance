# ADR 0006 — Cooldown governs rhythm; ammo governs endurance; they are tuned independently

*Status: accepted · 2026-08-23 · recorded from `docs/PROJECT_OVERVIEW.md` v3 and `docs/COMBAT_POC_IMPLEMENTATION.md` v3; the decision predates this repo*

## Decision

Two separate levers. `missile.cooldown_seconds` (~15–25s, upgradeable) paces the
alternation between missile and turret. `missile.ammo_capacity` (defaulting to
effectively unlimited) is a logistics pressure on the travel layer. They are never
collapsed into one resource.

## Why

Cooldown guarantees the alternation and makes a wasted long-range shot sting
immediately and concretely — you spend the reload on the gun thinking about it. It
is legible in the moment and never punishes the player for playing the game.

Ammo operates at a coarser grain: generous enough that nobody hoards within an
engagement, tight enough that a long expedition without resupply is felt.

Scarcity of a *fun* mechanic reliably produces hoarding. If players routinely end
fights with missiles unspent, the design is telling them the best mode is a mistake
to use.

## What this forbids

- Do not gate the missile behind a scarce resource in combat. Cooldown is the
  primary lever; ammo is generous by default.
- Do not merge the two into "charges". They answer different questions.
- Test cooldown-only, ammo-only, and both.
