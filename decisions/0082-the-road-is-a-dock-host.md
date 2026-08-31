# ADR 0082 — The road is a dock host, and a berth is left on purpose

*Status: accepted · 2026-08-31 · from the human's "the bottom is a road you can dock with"*

## Decision

**The roadway is a dock host.** Come down near it on the road and a berth is offered;
take it and the ship stops being flown and is carried along the carriageway it is
bound to, just above the floor, at `berth_speed_fraction` of cruise.

**It is the same verb as landing on a planet**, in the human's words: *"the ship is
stationary attached to a meaningful larger entity. You can't access a planet directly
from the highway."* Not a lookalike — you stop piloting and attach to infrastructure,
and that is what docking is here.

Three properties make it a dock rather than a conveyor, and a review checks all three:

1. **Chosen** — offered on proximity to the roadway, declined by doing nothing.
2. **Reversible** — the same key leaves it, at any moment, at speed.
3. **Never optimal** — a fraction of cruise. ADR 0058's rule (automation is worse than
   an engaged player) applied to travel.

**A berth is left on purpose; a threshold aborts on input.** ADR 0012's *"any sequence
that moves the ship must abort on any player input"* is **narrowed, not reversed**: it
governs a threshold you might cross by accident, which is a countdown to a commitment.
A berth is a place you deliberately entered and then sit inside — you want to look
around from it, read comms in it, and click things in it — and aborting on look would
make it useless for the one thing it is for.

**The berth makes no routing decisions.** It follows the centre-line of the road it is
bound to. The union does not hand a berthed ship from one road to another on
proximity, because that would be the berth choosing a route (ADR 0013).

**It converges, it does not snap.** `berth_pull_rate` slides the ship onto the rail at
a bounded closing speed, and the nose comes round at the ship's own turn rate.

## Why

ADR 0057 forbids non-interactive transit, and a thing that carries you at three
quarters of cruise looks exactly like that. The clause was written to stop **the tube
itself** being a loading screen — no camera cut, no scene load, the surrounding space
still rendered. An opt-in berth *inside* the tube, that skips no time and no distance
and can be left in a frame, is a different object, and the human's framing is what
makes the difference legible: it is not the road driving for you, it is you docking
with the road.

**"Never optimal" is what keeps it honest, and it is a hard requirement rather than a
taste.** At `1.0` the berth would be the correct way to drive the road and the road
would stop being driven. The fraction is the price of the comfort, and it is why this
passes the target-experience rule: the pressure to fly it yourself is a cost the player
chooses, visible before commitment, reversible at any moment.

**The mechanism is NOT `ApproachEnvelope`, and the plan said it would be.** That was
wrong and this is the correction. The envelope is a countdown that walks a speed
ceiling to zero and aborts on input; a berth is a moving hold that ignores input. The
two share the verb, the offer, and nothing else — forcing one class to do both would
have put a mode inside it that contradicts its own ADR. `RoadBerth` and `BerthHold`
mirror `RoadDeck` and `CruiseLane` instead: the road works out where the ship should
be and hands it a sample.

## What this forbids

- Do not let `berth_speed_fraction` reach 1.0. At parity the berth is not a comfort,
  it is the way to drive.
- Do not abort the berth on flight input, and do not read the throttle or the stick
  while it is engaged. It is left with the key that took it.
- Do not let the berth choose a road. It follows the one it is bound to; a rebind
  happens because the player asked for it at a place they could see.
- Do not give the berth pathing, arrival, avoidance, or a destination. ADR 0013 is
  unchanged: nothing on this ship plans a route.
- Do not snap the ship onto the rail. Every transition on this road carries its
  momentum (ADR 0066), and this is the one most tempting to teleport.
- Do not read ADR 0012's abort clause as covering this. It covers a threshold you
  might cross by accident; that decision is unchanged and still governs the planet.
- Do not fold `RoadBerth` back into `ApproachEnvelope` for tidiness. They contradict
  each other on input, which is the point.
