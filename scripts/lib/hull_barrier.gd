class_name HullBarrier
extends RefCounted
## The road's shell, as a surface a hull does not pass through. Pure — no scene
## tree, no tuning, no disk.
##
## **The lane is soft; the structure is not.** ADR 0064 makes the *lane* boundary a
## nudge, and that is still right: drifting wide of the centre-line is a lane-keeping
## mistake and the road correcting it is what a road is for. But the lane's push is a
## slope, and a slope loses to a ship pointed through it — at cruise 250 inside an 18
## degree cone the ship carries 77 m/s downward against a push worth 35, so the floor
## of a ramp is something you sink through and out the bottom of. That is not a soft
## boundary, it is a missing one (ADR 0087).
##
## So the shell is held, from **whichever side the hull is on**: out of the tube if
## you are inside it, out of the walls if you are outside them. The ways through are
## the apertures a ramp makes, the open ends of a ramp, and the portal mouths — and
## those are told to this object as open faces rather than guessed at.
##
## **It bounces** (ADR 0090, reversing ADR 0087's original "never bumps"). The hull is
## put back against the face it was crossing and the speed going *through* that face
## comes back out of it, scaled by `restitution`. A road of steel and glass is a thing
## you rebound off; the sliding stop the first version did was the reading that suited
## an energy tube, and the structure is not one any more.
##
## What survives from that first version, and is still the property to check: **motion
## ALONG the surface is untouched.** The bounce is in the normal direction only, so a
## glancing hit is deflected and a ship is never stopped by a wall it is flying beside.
## What the bounce costs is the caller's to apply — see `into_wall`, which is the speed
## the surface actually absorbed.

## Which building this came from. For the gate and the HUD; nothing steers by it.
var shell_name: String = ""

## The shell's frame here: the point on its spine, and the two directions across it.
var centre: Vector3 = Vector3.ZERO
var axis: Vector3 = Vector3.FORWARD
var right: Vector3 = Vector3.RIGHT
var up: Vector3 = Vector3.UP

## The clear interior's half-section, and the hull's own. The hull is held when its
## SIDE reaches the surface, not when its centre does — the same measurement the lane
## makes (`CruiseLane.clearance`), for the same reason: a capital is 84 m across and a
## shell that only noticed the centre would let most of it through the wall.
var extents: Vector2 = Vector2.ONE
var clearance: Vector2 = Vector2.ZERO

## The hull's offset across and up, in the shell's own frame. Measured once where the
## barrier is built so the network can compare two shells without re-projecting, and
## so the HUD can say how much room there is.
var across: float = 0.0
var lift: float = 0.0

## Which side of the shell the hull was on when this was measured. Decided by the map
## before the ship moves and enforced after, so nothing here has to remember anything.
var inside: bool = true

## Faces a ramp goes through near this point. An open face is not a wall in either
## direction — it is the way on and the way off, and holding it would be a road with
## no junctions on it.
var open_right: bool = false
var open_left: bool = false
var open_above: bool = false
var open_below: bool = false

## Whether a pane of glass runs down the middle of this shell, and which side of it
## the hull is on: +1, -1, or 0 for a hull sitting astride it, which is left free
## rather than pinned to a side it never chose.
var has_median: bool = false
var median_side: float = 0.0

## How much of the speed going into a face comes back out of it. 0 is the sliding stop
## this class was first written with; 1 would be a superball. A feel value, so it is
## pushed in from the structure rather than read here.
var restitution: float = 0.0


## How much room there is to the nearest face: positive inside, negative outside. What
## the network compares when two shells both have an opinion — the one the hull is
## deepest inside of governs, exactly as the lane union picks a deck (ADR 0063).
func room() -> float:
	return minf(extents.x - absf(across), extents.y - absf(lift))


## Hold a hull that has moved to `point`, as
## `[held_point, held_velocity, kick, into_wall]`.
##
## `kick` is the rebound: an outward velocity the caller carries for a moment, so the
## bounce reads as a bounce rather than as one frame of displacement. `into_wall` is
## the speed the surface absorbed, which is how square the hit was and therefore what
## it should cost — a glancing touch is nearly zero and a dive into the roadway is
## nearly the whole speed.
##
## Each axis is clamped independently and only the velocity going *through* the face is
## touched, so a ship pressed against the roadway still travels along it.
func hold(point: Vector3, velocity: Vector3) -> Array:
	var offset := point - centre
	var across := offset.dot(right)
	var lift := offset.dot(up)
	var held_across := across
	var held_lift := lift

	if inside:
		var wall_x := maxf(extents.x - clearance.x, 0.0)
		var wall_y := maxf(extents.y - clearance.y, 0.0)
		if across > wall_x and not open_right:
			held_across = wall_x
		elif across < -wall_x and not open_left:
			held_across = -wall_x
		if lift > wall_y and not open_above:
			held_lift = wall_y
		elif lift < -wall_y and not open_below:
			held_lift = -wall_y
		# THE MEDIAN, which is a wall in the middle rather than at the edge. A hull
		# still astride the pane is left alone: pinning it to whichever side its centre
		# happens to be on would move a ship sideways for no reason it could see.
		if has_median and not is_zero_approx(median_side):
			held_across = maxf(held_across, clearance.x) if median_side > 0.0 \
				else minf(held_across, -clearance.x)
	else:
		var reach_x := extents.x + clearance.x
		var reach_y := extents.y + clearance.y
		if absf(across) < reach_x and absf(lift) < reach_y:
			# Inside a shell it is meant to be outside of. Out through the NEAREST
			# face, which is the one it came in by — and if that face is open it came
			# in legitimately, so nothing is held and the map reads it as inside next
			# frame.
			var side := signf(across) if not is_zero_approx(across) \
				else -signf(velocity.dot(right))
			var vertical := signf(lift) if not is_zero_approx(lift) \
				else -signf(velocity.dot(up))
			if reach_x - absf(across) <= reach_y - absf(lift):
				if not (open_right if side > 0.0 else open_left):
					held_across = reach_x * (side if not is_zero_approx(side) else 1.0)
			elif not (open_above if vertical > 0.0 else open_below):
				held_lift = reach_y * (vertical if not is_zero_approx(vertical) else 1.0)

	if is_equal_approx(held_across, across) and is_equal_approx(held_lift, lift):
		return [point, velocity, Vector3.ZERO, 0.0]

	var held := centre + right * held_across + up * held_lift \
		+ axis * offset.dot(axis)
	var kept := velocity
	var kick := Vector3.ZERO
	var into_wall := 0.0
	var bounce := clampf(restitution, 0.0, 1.0)
	# Only the component GOING THROUGH the face is touched. Coming back off it is the
	# player flying away from the wall and must be left alone, or a hull resting against
	# the roadway could never leave it.
	if not is_equal_approx(held_across, across):
		var v := kept.dot(right)
		if signf(v) == signf(across - held_across):
			kept -= right * v
			kick -= right * v * bounce
			into_wall += absf(v)
	if not is_equal_approx(held_lift, lift):
		var v := kept.dot(up)
		if signf(v) == signf(lift - held_lift):
			kept -= up * v
			kick -= up * v * bounce
			into_wall += absf(v)
	return [held, kept, kick, into_wall]
