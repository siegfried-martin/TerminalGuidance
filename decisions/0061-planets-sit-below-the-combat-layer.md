# ADR 0061 — Planets sit below the combat layer, because down is already a direction

*Status: accepted · 2026-08-29 · from the human's proposal during exploration POC planning*

## Decision

A system's planet sits at the **bottom of the disc**, below the layer fights happen
in. The combat band occupies the upper part of the disc's height and the planet
occupies the lower part; the disc's hard floor is beneath the planet, not above it.

An approach envelope is therefore something the player descends into deliberately,
not something they blunder through while manoeuvring.

## Why

Three reasons, and they are independent, which is why this is worth fixing in an
ADR rather than leaving to whoever places the mesh.

**It stops an accident that is not fun.** ADR 0012 commits a landing sequence to
starting on envelope entry — deliberately, so arriving has no ceremony. In a
tightened disc that puts a large abortable sequence in the middle of the volume a
fight uses. Aborting on any input makes it survivable, but "the landing sequence
keeps arming while I fight" is a papercut with no upside, and the fix is placement
rather than another rule.

**There is already an authoritative up.** Ships do not roll and every ship is kept
on a shared horizon (ADR 0045). A world with a fixed up can put things *down* and
have that mean something; a roll-free game that then placed landmarks at arbitrary
bearings would be throwing away the one spatial convention it has.

**Down is where a planet goes.** For gravity-experiencing players this needs no
teaching, and it makes a planet findable from anywhere in the system by looking in
a direction they will look in anyway.

This does not cost ADR 0012 its spatial dimension. *"Missiles cratering into a
planet gives fuse-as-range a spatial dimension"* still holds — a missile aimed
downward reaches the surface exactly as before. What changes is that reaching it is
a choice about where you point, which is the same thing fuse-as-range already is.

It also gives disc height a **principled decomposition** instead of a ratio: combat
band, plus clearance so the ceiling never enters a fight, plus the planet band
below. That is three measurable things rather than one guess.

## What this forbids

- Do not place a planet, or anything else carrying an approach envelope, inside the
  band a fight occupies.
- Do not add a confirmation prompt, a threshold, or a "are you sure" to the
  approach envelope to solve accidental entry. ADR 0012 forbids it and placement
  makes it unnecessary.
- Do not put the disc's hard floor between the player and the planet. The planet is
  inside the bounded volume; ADR 0011's floor is below it.
- Do not derive disc height from a single ratio now that it decomposes. Size the
  combat band from the measured engagement envelope, and add the planet band.
