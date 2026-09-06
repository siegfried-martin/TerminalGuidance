# ADR 0052 — The launch tube's clock starts at launch, not at detonation

*Status: accepted · 2026-08-27 · from building stage 5 of `docs/TURRET_MODE_IMPLEMENTATION.md`*

## Decision

The ridden missile's cooldown (`ship/missile_cooldown_seconds`, 10 s) starts the
moment the missile **leaves the tube**, and runs while the player is riding it.

The tube reloads on its own clock regardless of which station the player is at, and
regardless of whether anyone is at one. The gauge is drawn on the flight overlay,
along the bottom of the screen, in **every** view — not in the debug HUD.

## Why

**The alternative inverts the loop's central trade.** `PROJECT_OVERVIEW.md` names
the opportunity cost of the missile as *"every second in the missile being a second
off the gun"*. Starting the clock at launch is what makes that literally true:

- Detonate early and you buy turret time — the tube is most of the way back by the
  time you are at the gun.
- Ride the fuse out and you spend it — you land with the tube nearly ready and go
  straight back to the helm.

Starting the clock at *detonation* would make a long ride free: the cooldown would
begin after the ride rather than during it, and there would be no cost at all to
watching a missile all the way in. The choice of when to end a ride is one of the
few real decisions the missile offers (ADR 0002 makes it the difficulty dial), and
it should have a price on both sides.

**The gauge is on the overlay because criterion 2 is a question about it.** The
success criterion this whole build exists to test is *"after 30 minutes the
developer is still choosing to fire, and never feels stuck waiting."* That is not
answerable if the reload is only legible with the debug HUD switched on. It has to
be readable at a glance from the turret, from the helm, and from inside a missile.

**Compare it against the fuse, not against intuition.** At
`missile_cooldown_seconds` below `missile/fuse_seconds`, the tube is always ready by
the time a full-fuse ride lands and the cooldown does nothing at all. 10 against a
fuse of 6 leaves about four seconds at the gun after a long ride and about nine
after a short one — that gap *is* the mechanic.

## What this forbids

- **Do not restart the clock at detonation, impact, or on return to the ship.** All
  three make a long ride free, which deletes the cost of the decision the missile is
  built around.
- **Do not pause the reload while the player is riding**, or at the turret, or in
  the tuning panel. A cooldown that only runs while you are watching it is a
  different mechanic and a worse one.
- **Do not move the reload gauge into the debug HUD.** It is the instrument the
  criterion is read with, and the debug HUD is toggleable.
- **Do not add a second charge, a magazine, or a queue of missiles.** ADR 0006 puts
  the rhythm on the cooldown and endurance on ammo; this is the rhythm.
