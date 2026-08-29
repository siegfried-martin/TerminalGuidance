# ADR 0058 — NPCs are worse than an engaged player at every station, gunners included

*Status: accepted · 2026-08-29 · supersedes ADR 0007; from `docs/EXPLORATION_DESIGN.md` §Crew and station switching*

## Decision

Every hired crew member is worse at their station than the player would be at it.
The best affordable gunner is roughly a mediocre player, and by the time the player
can afford one they have improved past it.

This replaces ADR 0007's "NPC gunners can be genuinely excellent". It does not
change 0007's other half: NPC missile use stays dumb fire-and-forget, permanently.

## Why

ADR 0007 already forbade any build outperforming an engaged human at the same
station, and then described gunners as "genuinely excellent" — which is the same
sentence pulling in two directions. The tension resolves the way the pressure rule
resolves everything: **the fantasy has to hold in both directions.** The summoner
build stays comfortable and viable because a hired crew flies the ship well enough
that delegating is never a punishment. The hands-on build stays strictly stronger
because sitting down at any station beats what was happening while you were away.

Skill-for-price is what makes crew a live money sink and a source of texture, and
that only works if the top of the range is still visibly below the player.

Also settled here: **autopilot is your own character flying while you are
elsewhere** — a person's competence, not a system with a difficulty setting.
Hiring a better pilot produces a better autopilot. See ADR 0059 for what that does
and does not mean for the autopilot that exists today.

## What this forbids

- Do not write an NPC that outperforms an engaged player at any station, for any
  price, at any reputation.
- Do not improve NPC missile accuracy as a convenience feature. Unchanged from
  ADR 0007.
- Do not gate content behind hiring a crew member, which would make the ceiling on
  their competence a ceiling on the player's access.
- `docs/PROJECT_OVERVIEW.md` Pillar 4's "genuinely excellent" language is superseded
  by this and should read as the above wherever it is quoted.
