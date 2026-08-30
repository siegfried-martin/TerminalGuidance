# ADR 0071 — A ceiling that drops does not drop the ship with it

*Status: accepted · 2026-08-30 · from the human being stuttered forward at the lane's rail*

## Decision

**A ship may not lose speed faster than its own brakes can take it off.**
`Mothership.brake_limited` rate-limits the fall in forward speed to
`ceiling / brake_seconds`, in both flight models.

**Gaining speed is untouched.** Acceleration is already paced by the throttle lever's
own travel, and pacing it a second time would make the lever slower than it is tuned
to be — a feel change smuggled in behind a bug fix.

This is ADR 0066's rule applied one level down. 0066 says a *transition* carries
momentum: the drive spools, a departure leaves flying. This says the same thing about
every ceiling the ship is ever given, whether or not anyone called it a transition.

## Why

The throttle travels over `accel_seconds` and `brake_seconds`. The ceiling it
multiplies had no travel at all, and speed was written as `throttle x ceiling`
directly — so any ceiling that changed in one frame changed the ship's speed in one
frame with it.

The lane's edge is exactly such a ceiling. Cross the rail at 160 m/s and
`lane_edge_speed_penalty` takes 55% off the cruise drive over `lane_edge_softness`
metres, which at an 18 degree steering cone is about a fifth of a second of sideways
travel. The ship lost eighty metres a second almost instantly, `CruiseLane.push` — a
function of position — shoved it back inside, the penalty released, the ship got all
of that speed back just as instantly, and it drifted out again. **A limit cycle at the
rail, at a couple of hertz**, which from the cockpit is being skipped forward and back.
The human reported it as flying with part of the ship in the wall and the screen
stuttering, and that is a precise description of what the code did.

Three things were wrong and only one of them was the cause. The push arriving at full
strength on the frame the edge was crossed (`sqrt` has an infinite slope at zero) made
the cycle sharper, and a 10 m gradient at cruise speed is a step rather than a slope —
both were fixed, and **neither was the cause.** With the rate limit in place the trace
is smooth and monotonic at a 10 m gradient and at an 80 m one alike: the ship settles
outside the lane at the penalised speed and stays there. So `lane_edge_softness` was
put back to the value the human tuned rather than widened, because widening it is a
feel decision and there is no longer a bug asking for it.

The alternative was to smooth the lane's penalty specifically — a per-ship easing of
`outside_fraction`. It loses on two counts: it puts drift state on the ship that could
survive leaving the road, which ADR 0064 deliberately avoided, and it fixes one
symptom of a defect that belongs to every ceiling in the game. The boundary clamp, a
hull swap and the spool are all the same shape of change and all get this for free.

## What this forbids

- Do not write a ship's speed as `throttle x ceiling` again. The ceiling is a limit
  the ship approaches, not a value it is assigned.
- Do not rate-limit acceleration here. The throttle already does it, and doing it
  twice compounds into a lever slower than its own tuning says.
- Do not give `CruiseLane`, `BoundaryField`, or any other source of a ceiling its own
  smoothing to fix a jolt. The smoothing belongs to the ship, once, and those stay
  pure functions of position.
- Do not "fix" a speed jolt by widening a soft edge. That is a feel change, and this
  ADR exists because it was tried and was not the cause.
- Do not let the limit hold a ship above a ceiling indefinitely. It bounds the RATE of
  the fall, never its destination, and the destination is still the ceiling.
