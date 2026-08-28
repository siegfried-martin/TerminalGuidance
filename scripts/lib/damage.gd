class_name Damage
extends RefCounted
## Splash falloff, shared by the ridden missile's early detonation and the
## turret's unguided missile. Pure and static — no scene tree, no tuning reads, so
## the whole rule is one testable function.
##
## ADR 0004 is the decision this file implements, and **"steeply"** is the load
## bearing word in it:
##
## > if splash is close to a direct hit, the optimal play becomes "detonate near
## > the target every time," which deletes the skill game that fuse-as-range and
## > steering exist to create.
##
## So the rule is enforced in two places at once and neither of them is a comment:
## `capped_peak` makes a blast strictly weaker than a direct hit *whatever the
## tuning says*, and the falloff power is at least quadratic, so damage collapses
## well before the edge of the radius rather than tapering politely to it.

## Damage delivered `distance` metres from the centre of a blast.
##
## Zero outside the radius, `peak` exactly at the centre, and `falloff_power`
## controls how fast it collapses in between — 1 would be a straight taper, which
## is the polite version ADR 0004 rejects, so it is floored at 2.
static func splash(peak: float, distance: float, radius: float,
		falloff_power: float) -> float:
	if radius <= 0.0 or peak <= 0.0:
		return 0.0
	var reach := clampf(1.0 - maxf(distance, 0.0) / radius, 0.0, 1.0)
	return peak * pow(reach, maxf(falloff_power, 2.0))


## The most a blast may do at its own centre, whatever its tuning says.
##
## This is ADR 0004's "do not tune splash upward to make missiles feel more
## reliable" made structural rather than asked for. `max_fraction` is itself
## tunable — the *size* of the gap is a feel question — but it can never reach 1,
## so a blast can never be worth as much as landing the shot.
static func capped_peak(tuned_peak: float, direct_damage: float,
		max_fraction: float) -> float:
	return minf(tuned_peak, direct_damage * clampf(max_fraction, 0.0, 0.9))
