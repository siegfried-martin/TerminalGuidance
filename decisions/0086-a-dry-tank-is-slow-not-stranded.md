# ADR 0086 — A dry tank is slow, never stranded, and the road spends fuel by the metre

*Status: accepted · 2026-09-01 · exploration POC step 7, building on ADR 0017*

## Decision

**Cruise fuel is spent per metre of highway travelled**, by whatever is carrying the
ship along it. `CruiseTank` is a fitting on the hull, not a property of the map, and it
is burned by `SystemMap` on the distance between one observation and the next.

Three consequences, each of which had a plausible alternative:

- **An empty tank refuses a portal, and nothing else.** A portal opens for a cruise
  drive that can run (ADR 0060), and a dry one cannot. Getting *on* needs fuel.
- **Running dry mid-leg winds the drive down and leaves the ship on the road.** The
  ceiling blends back to the hull's over the normal spool-down, the lane is still the
  lane, the stick is still live, and the player drives to the next system under their
  own engine. Nothing ejects them, stops them, or moves them.
- **A berth burns the same fuel as flying it.** The berth is carried by the road at a
  fraction of cruise (ADR 0082); charging it nothing would have made it the
  range-optimal way to cross the map.

Refuelling is a service on the docking screen, free for this POC, above `Depart`.

## Why

**The per-metre price is ADR 0017 made structural.** Fuel is a route budget, and a
budget in seconds is repriced by every change to a speed — the cruise number has moved
three times in four sessions and each move would silently have changed what every leg
costs. Metres cannot do that. It also means the price of a route can be quoted off the
map before the ship is pointed at it, which is the thing ADR 0017 explicitly forbids
leaving out.

**"Slow, never stranded" is the only reading that survives the target-experience rule.**
The obvious alternative — the tank empties and the road drops you into open space —
fails it twice over: it is a condition imposed mid-transit, and it arrives while the
player is doing something else. Winding the drive down costs the player exactly what
running out of fuel should cost, which is *time*, and the recovery is the thing they
were already doing. It also needs no new mechanism: the spool-down that ADR 0066 built
for leaving the road is what a dry tank triggers, so the deceleration carries momentum
for the same reason every other transition does.

**And it is only legal because the road is a place rather than a mode** (ADR 0057).
Being on a highway with no drive running is a coherent state — it is what the lane, the
markings and the structure are for — where in a mode-shaped design there would be
nothing to be in.

**The berth question is the one worth recording.** A berth that travelled free would be
slower per second and cheaper per metre, which makes it the correct way to make any
long crossing you are not in a hurry for — and "the automation is the right answer" is
precisely what ADR 0058 and ADR 0082's third property exist to prevent. Same price,
lower speed, keeps it a comfort.

## What this forbids

- **Do not price fuel in seconds**, or make consumption depend on speed, throttle, or
  spool. A metre of highway costs what a metre of highway costs.
- **Do not take the ship off the road when the tank empties**, and do not stop it,
  slow it below its hull speed, or steer it. Running dry must never be a softlock
  (ADR 0017) and must never be interdiction with a fuel gauge in front of it
  (ADR 0014).
- **Do not charge fuel for normal flight.** Off-road travel is free, and that is what
  makes stranding recoverable and what keeps step 5's control condition honest.
- **Do not make the berth cheaper per metre than flying**, in this or any later
  version. If a berth is ever to cost less, it must cost more of something else.
- Do not let a hot reload of the capacity refill the tank. Editing a number is not a
  fuel vendor.
- Do not add fuel to the combat arena. The tank exists on the hull so a ship can be
  built without a road; nothing in the arena may read it.

## The debug teleport, recorded here because it is the same change

`J` jumps the ship to the **next** system — not the nearest, which is almost always the
one it is standing in. It is gated on `debug_teleport_enabled`, it takes the ship off
the road first, and **it does not refuel**: a tool that quietly undid the resource it
exists to test would be worse than not having it.

Every use is counted, printed, and carried on the **first** row of the HUD for the rest
of the session, above every travel figure it invalidates. **A silent teleport
contaminates a travel-time verdict**, and success criterion 1 is a travel-time verdict.
Do not remove that row, do not make it quiet, and do not call the teleport from
anything that is not a key press.
