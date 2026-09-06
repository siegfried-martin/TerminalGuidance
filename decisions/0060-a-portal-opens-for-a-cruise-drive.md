# ADR 0060 — A portal opens for a cruise drive, and its colour says so

*Status: accepted · 2026-08-29 · from the human's direction during exploration POC planning*

## Decision

Whether a portal admits the player is decided by **the hull they are flying**, and
the portal's surface sheen shows the answer before they commit: blue for
permitted, red for refused.

In this POC the only thing that refuses is having no cruise drive, so a fighter
sees every portal red and a taxi sees every portal blue. That is not a rule about
portals — it is `<class>_has_cruise_drive`, the one property that already defines
what a fighter is, wearing a colour.

## Why

The fighter's identity in the ladder is *fast, and local*: it covers a local leg in
1.7 minutes and crosses a system in 1.5 without a cruise drive at all, and 17
minutes cross-group is where paying for a taxi becomes worth it. That identity
holds without a rule enforcing it, and adding "fighters may not use portals" as a
separate rule would be stating the consequence twice — two places to disagree.

The colour is the important half. A portal has to answer *"may I use this?"* from
across a system and before the player has spent the trip flying at it, which is the
same requirement ADR 0017 puts on fuel: a soft gate is only a gate if the cost is
legible while deciding. A refusal discovered on contact is the pressure rule's
failing case — a condition imposed on the player rather than one they chose.

Faction access control and reputation gating are out of POC scope. They land on
this same channel later, setting the same flag from a different reason, without
changing the portal.

## What this forbids

- Do not write a second rule about which ships may use portals. There is one
  property and it is the cruise drive.
- Do not let a portal refuse silently, on contact, or after the approach. The
  colour is visible from outside the system and is the whole of the answer.
- Do not use the denied state as a punishment or a script trigger. It is
  information, shown before commitment, and the player always has another route.
- Do not add access control logic in this POC beyond the cruise-drive check.
