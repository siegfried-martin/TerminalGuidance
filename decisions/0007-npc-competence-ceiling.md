# ADR 0007 — Crew can gun; crew cannot ride missiles

*Status: superseded by ADR 0058 — gunners are no longer "genuinely excellent"; the missile clause stands*

*Status: accepted · 2026-08-23 · recorded from `docs/PROJECT_OVERVIEW.md` v3 and `docs/COMBAT_POC_IMPLEMENTATION.md` v3; the decision predates this repo*

## Decision

NPC gunners can be genuinely excellent at turret work. NPC missile use is dumb
fire-and-forget with a mediocre hit rate, permanently.

## Why

Both supported fantasies have to be first-class: "four excellent gunners while I
pilot" and "I'll fly every station myself." Excellent hired guns make the summoner
build viable and pleasant. But a manually flown missile must remain the one thing
in the universe nobody can do for the player — that is what keeps hands-on
strictly stronger without making delegation feel like a punishment.

Turret work is tracking and prediction, which an NPC can plausibly be great at.
Missile riding is the game.

## What this forbids

- Do not improve NPC missile accuracy as a convenience feature.
- Do not let any build, automation, or upgrade outperform an engaged human at the
  same station. Hired crew is convenience, never superiority.
