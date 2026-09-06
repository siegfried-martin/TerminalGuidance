class_name BerthHold
## Everything the ship needs to sit in a berth on the road, in one object. Pure — no
## scene tree, no tuning, no disk.
##
## The same shape as `CruiseLane`: the road works out where the ship should be and
## hands it a sample, and the ship never has to look the road up. What differs is what
## the sample means. A `CruiseLane` says *here is the lane, fly it*; a `BerthHold` says
## *here is the rail, you are on it* — the ship stops steering and is carried.
##
## **This is a dock, in the same sense a planet is** (ADR 0082). The ship stops being
## flown and attaches to a larger thing that is going somewhere. It is chosen, it is
## reversible at any moment, and it is deliberately slower than flying yourself, which
## is what keeps it a comfort rather than a route optimisation.

## Where on the roadway the ship is held: the bound carriageway's centre-line, dropped
## to just above the floor. The road is under you in a berth, not around you.
var point: Vector3 = Vector3.ZERO
## Which way the road runs here. The nose is turned toward it, at the ship's own rate.
var axis: Vector3 = Vector3.FORWARD
## How fast the berth carries you. A fraction of cruise, never all of it.
var speed: float = 0.0
## How quickly the ship converges onto the rail, in metres per second of closing
## speed per metre of error. Engaging is a move the ship makes, not a snap: a berth
## that teleported you onto the centre-line would be the one moment on the road that
## did not carry momentum (ADR 0066).
var pull: float = 0.0
## How far off the rail the ship still is. For the HUD, and for the gate to check that
## engaging converges rather than jumping.
var error: float = 0.0
## Which road this berth is bound to, for the HUD.
var deck_name: String = "road"
## How much of the bound road is left ahead, in metres.
var metres_remaining: float = 0.0


## How fast to close the remaining distance to the rail this frame. Proportional and
## capped, so a ship that engages a long way off the centre-line slides in at a
## sensible rate rather than being yanked.
func closing_speed() -> float:
	return minf(error * pull, speed)
