# ADR 0012 — Planets use an abortable approach envelope, never auto-steer

*Status: accepted · 2026-08-23 · recorded from `docs/PROJECT_OVERVIEW.md` v3 and `docs/COMBAT_POC_IMPLEMENTATION.md` v3; the decision predates this repo*

## Decision

Entering a planet's approach envelope commits to a short, clearly signposted
landing sequence — approach vector acquired, brief countdown — abortable on any
input, which returns the ship to its original vector. The envelope always resolves
before the surface is reached and doubles as the landing UI.

## Why

Taking the stick away from a player is one of the most irritating things a flight
game can do, and the fiction never rescues it. The envelope gets the convenience of
a landing sequence without the theft.

Combat spilling into the envelope is *good*: missiles cratering into a planet gives
fuse-as-range a spatial dimension.

> *Narrowed by ADR 0082, and this decision is unchanged.* The abort-on-any-input rule
> governs a THRESHOLD — a countdown to a commitment you might not have meant to make,
> which is what a planet's envelope is. A berth on the roadway is a place you
> deliberately entered and then sit inside, and it is left with the key that took it.
> The planet is untouched by that and still aborts on anything.

## What this forbids

- No auto-steer, ever, for any reason, in any system.
- Any sequence that moves the ship must abort on any player input.
