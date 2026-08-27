# ADR 0046 — Two supported playstyles, and the economy leans toward the gunboat

*Status: accepted · 2026-08-27 · human direction after the combat POC verdict*

## Decision

The game supports two ways to fight, and the player chooses:

1. **The gunboat** — a large hull, missile riding and turret work. This is the
   thesis (ADR 0001, Pillar 1) and the loop the POC was built to test.
2. **The fighter** — a small fast hull with **ship-facing, pilot-controlled guns**.
   You aim by aiming the ship. No missile riding, no turret station.

The **economy leans toward the gunboat**: merchant hulls are large, they carry
more, and hauling is the reliable money. A player who wants to fly a fighter can,
and the game does not punish it — but the earning curve points at the big ship.

## Why

Both halves matter and they pull against each other, which is why this is written
down rather than assumed.

The fighter has to exist because a player who wants to fly one will try, and a game
that has ships and guns but only one legitimate way to use them reads as narrow.
It is also cheap: ship-facing guns need no turret station, no second camera and no
crew, and manual flight (ADR 0040) is most of the work already.

The gradient has to exist because a game with a thesis should point at it. Missile
riding is the bet; if fighter play paid the same, the design would be shrugging at
its own best idea. Making the reward structural — bigger hull, more cargo, more
money — rather than mechanical means the player is never told they are playing
wrong, they simply notice that the big ship earns.

## The tension, stated rather than resolved

ADR 0025 says difficulty is player-selected through mechanics and **the cautious
path stays viable**. The same logic applies here and is the thing most likely to go
wrong: a playstyle that exists but cannot pay its own upkeep is a trap dressed as a
choice, and "supported" would be a lie.

The distinction to hold: the fighter should earn **less**, never **not enough**. A
fighter pilot who never touches a missile must be able to fuel, arm, repair and
upgrade indefinitely, and reach the same regions — more slowly. If playtesting ever
shows the fighter path stalling out rather than progressing slowly, that is a bug
in this decision and not in the player's choice.

## What this forbids

- Do not gate progression on cargo income. Reputation is the progression axis
  (Pillar 8); money is a means. A fighter must be able to earn reputation by
  fighting.
- Do not give the fighter missile riding as a consolation. The two playstyles are
  distinguished by *what your hands do*; blurring that leaves one mode.
- Do not give the fighter a turret station either. Ship-facing guns are the whole
  control scheme; adding a second station is how it becomes a small gunboat.
- Do not balance by making fighters fragile enough to be unplayable. The gradient
  is economic, not lethal — the fighter should feel good and earn less, not feel
  bad and earn the same.
- Do not add a third playstyle without revisiting this. Two is a choice; four is a
  menu, and each one dilutes the tuning attention the missile loop needs.
- Roll is still forbidden on a fighter (ADR 0045), whatever the genre expects.
