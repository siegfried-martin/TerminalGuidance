# ADR 0021 — The Target Experience pressure rule is narrowed to chosen/visible/reversible

*Status: accepted · 2026-08-23 · recorded from `docs/PROJECT_OVERVIEW.md` v3 and `docs/COMBAT_POC_IMPLEMENTATION.md` v3; the decision predates this repo*

## Decision

The rule is: **pressure is a decision the player made, never a condition imposed on
them** — chosen, visible before commitment, and reversible. This replaces the
broader v2 prohibition on "resource anxiety."

- *Passes:* fuel spent on a route you plotted; cargo mass traded against speed;
  flying into a contested corridor because the shortcut was worth it; the
  opportunity cost of every second in the missile being a second off the gun.
- *Fails:* being pulled out of cruise by an NPC's decision; unattended systems
  degrading while you are busy; ambient dread with no avoidable cause; anything
  demanding the player attend to two things at once.

## Why

"No resource anxiety" was too wide. It forbade good systems (fuel as a
route-planning budget) alongside bad ones. The test is not whether a system creates
pressure; it is whether the player chose it, could see the cost before committing,
and can unmake the choice.

The rule is not usable as an abstraction alone. What makes it operable is the
contrast between the pass and fail examples — keep them attached to it wherever it
is quoted.

## What this forbids

- Do not quote the rule without the examples.
- Resource costs the player plans around are not covered by the prohibition.
