class_name RoadRehearsal
extends RefCounted
## Fly a road, on paper. Pure — no scene tree, no tuning, no disk.
##
## **The gate had no model of the ship following the road, and that is why three
## obvious faults survived it.** It bounded the road's curvature
## (`max_turn_deg_per_metre × cruise_speed ≤ turn_rate`) and it checked the collision
## shell, but "the road never demands more than the ship's whole turn rate" is a much
## weaker statement than "the ship can fly this road", and neither says anything about
## what the player is handed frame by frame.
##
## THE MISSING BOUND. The ship's nose is not glued to the road: `_road_axis` slews
## toward the lane's axis at `cruise_turn_rate_deg_per_sec` and the nose is clamped
## into a cone around THAT. So on a road that demands the ship's full turn rate, the
## slew exactly keeps up and there is nothing left over — the nose lags the road
## through the whole bend, the velocity points somewhere else again, and the camera,
## which is hung off the nose, swings without the player having touched anything.
## That is not a curvature failure; the curvature check passes. It is a failure to
## have any HEADROOM.
##
## So this walks a path at cruise speed, slews a heading after it at the ship's own
## rate, and reports the worst lag. A road the ship can fly is one where that stays
## small; a road at the curvature limit produces a lag of tens of degrees and is the
## thing that reads as "the direction I am controlling, the direction the ship is
## facing and the direction it is moving are not aligned".

## How finely the walk steps, in metres. Fine enough that a fillet's arc is sampled
## many times over. Infrastructure.
const STEP_METRES := 10.0


## The worst angle, in degrees, between the road's heading and a nose slewing after it
## at `turn_rate_deg_per_sec` while travelling at `speed`.
##
## Zero on a straight. Small wherever the road leaves the ship some authority to steer
## with. Large exactly where the road is using all of it.
static func worst_lag_deg(path: RoadPath, speed: float,
		turn_rate_deg_per_sec: float) -> float:
	if path.is_empty() or speed <= 0.0 or turn_rate_deg_per_sec <= 0.0:
		return 0.0
	var span := path.length()
	var steps := maxi(int(ceil(span / STEP_METRES)), 2)
	var delta := (span / float(steps)) / speed
	# Started ON the road, as a ship that engaged on a straight is: the lag this
	# reports is what the road does to a nose that was already pointing down it.
	var nose := path.heading_at(0.0)
	var worst := 0.0
	for i in steps + 1:
		var wanted := path.heading_at(span * float(i) / float(steps))
		worst = maxf(worst, rad_to_deg(nose.angle_to(wanted)))
		nose = FlightGeometry.turn_towards(nose, wanted,
			deg_to_rad(turn_rate_deg_per_sec) * delta)
	return worst


## What share of the ship's turn rate this road takes at its tightest, 0 to 1.
##
## The same reading `max_turn_deg_per_metre × cruise_speed ≤ turn_rate` takes, said as
## a fraction — because the number that matters is not whether it is under 1 but how
## far under. At 1 the ship can track the road and do nothing else.
static func turn_share(path: RoadPath, speed: float,
		turn_rate_deg_per_sec: float) -> float:
	if turn_rate_deg_per_sec <= 0.0:
		return 0.0
	return path.max_turn_deg_per_metre() * speed / turn_rate_deg_per_sec


## The radius a road may not be tighter than, given how much of the ship's turn rate
## it is allowed to use.
##
## This is `RoadLimits.fillet_floor`'s honest form. The old floor was
## `cruise_speed / turn_rate` — the radius at which the road takes ALL of it.
static func radius_floor(speed: float, turn_rate_deg_per_sec: float,
		share: float) -> float:
	var turning := deg_to_rad(turn_rate_deg_per_sec) * clampf(share, 0.05, 1.0)
	return 0.0 if turning <= 0.0 else speed / turning
