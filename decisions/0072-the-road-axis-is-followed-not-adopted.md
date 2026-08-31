# ADR 0072 — The road's direction is followed at a bounded rate, and a handover cannot hand you a lane you could not steer onto

*Status: accepted · 2026-08-30 · from the ship shaking violently at an interchange*

## Decision

**The ship holds its nose against a road axis it follows, not against the lane's own
axis.** `Mothership._road_axis` turns toward `cruise.axis` at
`cruise_turn_rate_deg_per_sec` and is what the cone clamp and the camera both use.

**A deck is only a handover candidate if its direction here is inside the steering
cone of the road the ship is already on.** `RoadNetwork.governing` takes the heading
being held and skips any lane more than `cruise_turn_clamp_deg` away from it.

Together: joining a lane is a merge the ship flies, and there is no frame in which
the road it is held against jumps.

## Why

The cone clamp is instantaneous by construction — every frame the nose is *put*
inside a cone around the road, which is what makes the camera lock honest. The
consequence nobody had written down is that **anything which moves the road's axis
moves the nose by the same amount in the same frame.**

A bend does that gently; ADR 0070 bounds how gently. A handover did it violently.
Drifting wide of a mainline beside an interchange made an on-ramp the nearer lane —
correctly, by ADR 0067's union — and that ramp's axis was thirty degrees away. Thirty
degrees in one frame is eighteen hundred a second, with a fourteen-metre-a-second
velocity step alongside it. Measured on the road, that is what the human felt as the
ship shaking violently when they drove out of the tube.

Both halves are needed and they fix different things. **The cone filter is
correctness**: a lane you cannot point at is not a lane you are merging onto, and
ADR 0067's union was never meant to hand you one — the union answers *which of the
lanes going my way*, and "going my way" had been left implicit. **The slew is
robustness**: it bounds every source of axis change at once, including the ones not
thought of yet, in the same way ADR 0071 bounds every source of ceiling change.

This is not junction logic and must not become it. Nothing here chooses a lane, ranks
one, or knows what an interchange is. The cone filter is the same *can I point at it*
the player is already subject to, applied to the candidate rather than to the stick;
the union still decides, on the same rule, over a smaller set.

Measured after: taking an off-ramp at cruise hands over in two steps with a worst
single-frame turn of 0.33 degrees, and drifting wide at an interchange no longer hands
over at all.

## What this forbids

- Do not clamp the nose to `cruise.axis` directly. The lane's axis is where the road
  goes; `road_axis()` is where the ship is being pointed, and only the second may
  drive the nose or the camera.
- Do not let the camera and the nose use different references. They frame the same
  road and a disagreement between them is a lie about which way it goes.
- Do not widen the handover filter to "any lane that contains the ship". That is the
  state this ADR was written to leave.
- Do not turn the filter into a ranking, a priority, or a preference between lanes.
  ADR 0067 stands: the union decides, and it decides on depth alone.
- Do not fix a snap at a handover by adding hysteresis to which deck is chosen. That
  changes how often the jump happens, not how big it is.
