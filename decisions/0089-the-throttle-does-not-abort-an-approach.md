# ADR 0089 — The throttle does not abort an approach; steering does

*Status: accepted · 2026-09-05 · narrows ADR 0012*

## Decision

**`ApproachEnvelope` aborts on steering, not on the throttle.** A moved stick, a
thruster, or mouse motion past `approach_abort_mouse_speed` hands the ship back. A held
throttle, a held brake, and a held boost do not.

**An abort re-arms where the player stands.** After `approach_relock_seconds` the
sequence is available again without leaving the envelope. A **departure** still requires
the player to actually leave first, which is what that rule was written for.

`Mothership` now answers two questions rather than one: `has_flight_input()` — is
anything flying this ship — and `is_steering()` — is the player asking to go somewhere
*else*. The envelope asks the second.

## Why

**ADR 0012's clause is about heading, and it was being read as being about input.** The
rule is that a sequence which *moves the ship* must hand it back the moment the player
asks to fly somewhere else, and it exists so an envelope is a place you may pass through
rather than a trap laid where you were flying.

This sequence moves the ship in exactly one way: it walks the **speed ceiling** down to
zero. So the two inputs are not alike.

- A held **throttle** is a request for speed *under* that ceiling. The ceiling already
  answers it, completely and visibly — the HUD's "of N" comes down while the player
  watches. Nothing is being overridden.
- A moved **stick** is a request for a *heading*. Nothing else answers it, and the
  sequence must never be the thing that decides one (ADR 0012's "magnitude, never
  direction" is the whole mechanism).

**Under the old rule the envelope was unreachable in practice.** You arrive at a planet
flying, so the lock broke on its first frame every time; and because a relock cleared
only once the player had *left*, one aborted attempt closed the planet until the ship
flew back out of a 560 m sphere it was trying to land in. Reported from the seat as
*"planet landing sequence detection doesn't engage at all"* — which it did not, from a
ship being flown.

The gate could not have caught it. Every headless test drove the envelope with the
throttle released, which is a state a player is almost never in on approach.

**"Not that time" is not "not here."** An abort and a departure were sharing one relock
rule and they mean different things. A departure is a ship that has just been on the
surface and is climbing away, and re-arming while it is still inside would put it
straight back into the sequence it walked out of. An abort is a player who twitched.

## What this forbids

- **Do not abort on the throttle**, in this or any other sequence that constrains the
  ship by a speed ceiling. If a sequence ever constrains a *heading*, it is illegal
  under ADR 0012 regardless of what it aborts on.
- **Do not ask `Input` directly.** Both halves are asked of the ship, which knows
  whether a capture harness is holding its controls, and which totals mouse motion
  itself because `Input.get_last_mouse_velocity()` never decays. Reaching for `Input`
  here has already been a bug twice.
- **Do not make an abort require leaving.** A landing that costs one countdown is a
  cost; one that costs a round trip is a refusal.
- Do not widen this to say "no input aborts anything". A **berth** is left on purpose
  and a **threshold** aborts on steering, and that divergence (ADR 0082) is unchanged.

## Still open, and not fixed here

`approach_alpha_far = 0` means the envelope is **invisible until you are nearly in it**,
which costs ADR 0012's "a visible place before a commitment" clause and is a second,
independent reason a landing is hard to find. It has been flagged since
`HIGHWAY_STRUCTURE_PLAN.md` was written. It is a feel value and it is the human's to
set; this ADR records that it is still zero.
