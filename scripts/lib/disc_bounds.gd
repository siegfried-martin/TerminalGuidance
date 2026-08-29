class_name DiscBounds
extends RefCounted
## Where the flat faces of a system disc are, and what happens as the player leans
## on one. Pure — no scene tree, no tuning, no disk (ADR 0011 made testable).
##
## The disc's geometry is asymmetric on purpose (ADR 0061): the combat plane is
## y = 0, the ceiling sits `ceiling` above it, and the floor sits `floor_depth`
## below it with the planet in between. So every function here takes the two
## distances separately rather than one half-height.
##
## The rim is deliberately absent. ADR 0011: *"The rim is not a boundary: flying
## laterally out of a system **is** departure."* Only the faces are hard, and this
## class only knows about them.

## How far past a face the point is, in metres. Zero anywhere inside.
static func overshoot(y: float, ceiling: float, floor_depth: float) -> float:
	if y > ceiling:
		return y - ceiling
	if y < -floor_depth:
		return -floor_depth - y
	return 0.0


## How close to leaving, 0 to 1. Zero while comfortably inside, 1 at the face and
## anywhere past it. This is the *telegraph* — it is what the red is painted from,
## and it reaches full before anything has happened to the player, which is the
## whole of Bannerlord's treatment and the reason it does not read as a punishment.
static func warning(y: float, ceiling: float, floor_depth: float, band: float) -> float:
	if band <= 0.0:
		return 1.0 if overshoot(y, ceiling, floor_depth) > 0.0 else 0.0
	return clampf(1.0 - distance_to_face(y, ceiling, floor_depth) / band, 0.0, 1.0)


## Metres to the nearer flat face. Negative once past it.
static func distance_to_face(y: float, ceiling: float, floor_depth: float) -> float:
	return minf(ceiling - y, y + floor_depth)


## Is this velocity heading further out of the disc?
##
## Measured against the *nearer* face rather than against the sign of y, so a disc
## whose floor is much deeper than its ceiling — which is every disc, since the
## planet lives down there — still answers correctly on both sides.
static func is_outbound(y: float, velocity_y: float,
		ceiling: float, floor_depth: float) -> bool:
	if ceiling - y <= y + floor_depth:
		return velocity_y > 0.0
	return velocity_y < 0.0


## What to multiply the ship's SPEED LIMIT by while it leans on a face.
##
## ADR 0011: *"maximum velocity is scaled down in the outbound direction. The clamp
## scales **magnitude only, never direction** — the stick still does what the player
## asked; the ship just feels like it is straining."*
##
## This returns a ceiling scale rather than a modified vector, which is what makes
## that structural instead of a promise: there is no code path here that can turn
## the player's ship, because nothing here ever sees a direction it could return.
##
## Inbound is never scaled. A player who has realised and is flying back must not be
## slowed down doing it — that would turn a telegraph into a trap.
static func speed_ceiling_scale(y: float, velocity_y: float, ceiling: float,
		floor_depth: float, band: float, outbound_fraction: float) -> float:
	if not is_outbound(y, velocity_y, ceiling, floor_depth):
		return 1.0
	return lerpf(1.0, clampf(outbound_fraction, 0.05, 1.0),
		warning(y, ceiling, floor_depth, band))


## Damage per second at this point in an excursion, given how long the ship has been
## past a face.
##
## Two stages, because a telegraph that hurts is not a telegraph: `grace` seconds
## pass with nothing but the red and the strain, and only then does damage begin and
## ramp over `ramp` more. A brief dip is a legitimate tactical option and costs
## nothing; camping out there does not work. That is the pressure rule holding —
## the player chose it, saw it coming, and can still turn round.
static func damage_per_second(seconds_outside: float, grace: float, ramp: float,
		full_rate: float) -> float:
	if seconds_outside <= grace:
		return 0.0
	if ramp <= 0.0:
		return full_rate
	return full_rate * clampf((seconds_outside - grace) / ramp, 0.0, 1.0)
