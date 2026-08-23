# ADR 0015 — Proximity inhibition is admissible where interdiction is not

*Status: accepted · 2026-08-23 · recorded from `docs/PROJECT_OVERVIEW.md` v3 and `docs/COMBAT_POC_IMPLEMENTATION.md` v3; the decision predates this repo*

## Decision

The drive will not spool with a hostile inside a set radius. Stopping in dangerous
space is the dangerous act; moving through it is not.

## Why

This and ADR 0014 look identical from outside and were separated deliberately. The
distinction is **a law of the world versus an agent's decision**. Inhibition is
legible, learnable, avoidable by giving hostiles a berth, and resolvable by
breaking contact. Interdiction is something done *to* the player by someone else's
choice.

Two tuning constraints keep it honest: the radius must be small enough that a wide
berth genuinely works, and enemies must not chase far enough to re-establish
inhibition indefinitely.

## What this forbids

- The radius is a world constant, never an NPC ability, buff, or module.
- No enemy may extend, project, or trigger inhibition as an action.
- Pursuit must have a range beyond which contact is genuinely broken.
