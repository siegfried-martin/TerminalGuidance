# ADR 0044 — Ships are capital-scale gunboats; the engagement is naval, not a dogfight

*Status: accepted · 2026-08-26 · a framing correction from the human: "the core concept of the game is large gunboats kinda like a naval engagement more than a dogfight"*

## Decision

The player's ship is a **capital-scale gunboat**, and its silhouette must say so at
a glance. The placeholder hull (`tools/gen_carrier_obj.py`) is 50 m stem to
wingtip and 44 m across, authored at 1 unit = 1 metre so `ship/hull_scale` is 1.0
and mesh units and tuning distances are the same units.

Specifically the *StarCraft* reading of "carrier" and not the US Navy one: a thick
faceted core with forward-swept crescent wings reaching past the prow, not a flat
runway deck with an island.

The chase camera moved out to match — `camera/ship_follow_distance` 26 → 62 — and
`ship/muzzle_offset` 6 → 30, because a 50 m hull spawns missiles inside itself at
the old value.

## Why

The framing was never written down, and the placeholder art had quietly asserted
the opposite. `probe.obj` is a 5 m dart: swept wings, a dorsal fin, engine
nacelles. It reads as a fighter, and a fighter implies a dogfight — high speed,
high agility, turning circles. That is the wrong game, and the wrong instinct for
every feel session run against it.

This matters more than art usually does at gray-box stage, because the POC is
answering feel questions and the silhouette is part of what the human is reading
when they answer them. A dart at 26 m and a gunboat at 62 m produce different
verdicts on the same tuning values.

It also settles a number that was previously arbitrary. `ship/manual_max_speed` is
34 m/s against a missile's 58 — that ratio reads as sluggish for a fighter and
about right for a hull four times the length of the distance it covers in a
second. The scale and the speed have to be decided together or neither is
judgeable.

The first attempt at this was a flat-decked Nimitz-style carrier, which was
corrected the same session. Recorded because the distinction is not obvious from
the word "carrier" alone and a future session will otherwise re-make the mistake.

## What this forbids

- Do not make the player's ship agile. ADR 0040's throttle and turn rates are slow
  on purpose; if the ship starts feeling like it needs to turn faster, that is a
  signal the *missile* is doing too little, not that the ship should do more.
- Do not shrink the ship back towards fighter scale to make the camera or the
  arena easier to frame. Move the camera; the arena is origin-local and has room.
- Do not let the enemy drift towards a fighter read either. The target ship is
  currently a 12 m fighter silhouette, which predates this decision and now
  contradicts it — see STATUS. It is deliberately left alone rather than changed
  in the same pass, but it is a known inconsistency, not a considered contrast.
- Do not treat this as licence to add capital-ship systems — shields, subsystem
  targeting, crew stations, broadsides. This is a statement about scale and
  silhouette. Everything mechanical still comes from the POC scope doc and its
  build order.
