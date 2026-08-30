class_name CruiseLane
extends RefCounted
## The road, sampled at the point the ship currently occupies: which way it runs,
## how far off the centre-line the ship is, and what that costs. Pure — no scene
## tree, no tuning, no disk.
##
## A sample rather than a description, because everything the ship needs from the
## road depends on where it is in it. `RoadDeck` fills one of these in each frame
## and hands it to the ship; the ship never looks the road up.
##
## **The lane boundary pushes, and the system boundary does not** (ADR 0064). That
## is not an inconsistency: drifting out of a lane is a lane-keeping mistake on a
## road, and the road correcting you is what a road is for. Leaving the world is a
## different act and ADR 0011's magnitude-only clamp still governs it, unchanged.
## The two are composed, never merged.

## Which way the road runs here, as a unit vector, and the frame across it.
var axis: Vector3 = Vector3.FORWARD
var right: Vector3 = Vector3.RIGHT
var up: Vector3 = Vector3.UP

## The ship's offset from the centre-line, in that frame.
var lateral: float = 0.0
var vertical: float = 0.0

## The lane's half-extents *here* — they narrow toward each portal, so this is a
## sample too rather than a constant.
var half_width: float = 1.0
var half_height: float = 1.0
## The cross-section's corner exponent. 2 is an ellipse, large is a rectangle; in
## between is the rounded lozenge, so no edge is dramatically nearer than another.
var roundness: float = 4.0
## Metres past the edge over which the penalty and the push reach full.
var edge_softness: float = 1.0

var base_speed: float = 0.0
var edge_speed_penalty: float = 1.0
var push_accel: float = 0.0
var clamp_deg: float = 0.0
var turn_rate_deg: float = 0.0

var deck_name: String = "deck"
## How far along the deck the ship is, and how much is left. For the HUD, which has
## to answer "how much longer is this" without the player doing arithmetic.
var metres_travelled: float = 0.0
var metres_remaining: float = 0.0


## How far outside the lane's cross-section the ship is, in metres. Negative inside.
##
## The cross-section is a superellipse, so this is measured along the ray from the
## centre-line: scale the offset until it lands on the boundary, and the difference
## is the answer. Exact for the shape rather than an approximation of it, which
## matters because the same number drives both the penalty and the push.
func edge_distance() -> float:
	var offset := sqrt(lateral * lateral + vertical * vertical)
	if offset <= 0.0001:
		return -minf(half_width, half_height)
	var exponent := maxf(roundness, 1.0)
	var reach := pow(
		pow(absf(lateral) / maxf(half_width, 0.001), exponent)
		+ pow(absf(vertical) / maxf(half_height, 0.001), exponent),
		1.0 / exponent)
	if reach <= 0.0001:
		return -minf(half_width, half_height)
	return offset * (reach - 1.0) / reach


## How far out of the lane, 0 to 1. Zero inside, 1 once `edge_softness` past it.
func outside_fraction() -> float:
	return clampf(edge_distance() / maxf(edge_softness, 0.001), 0.0, 1.0)


func is_outside() -> bool:
	return edge_distance() > 0.0


## The cruise drive's top speed here. Full in the lane, `edge_speed_penalty` of it
## once well outside — an incentive to hold the lane, never a stop.
func top_speed() -> float:
	return base_speed * lerpf(1.0, clampf(edge_speed_penalty, 0.05, 1.0),
		outside_fraction())


## The nudge back toward the centre-line, as a velocity.
##
## `push_accel` is an acceleration, and this is the closed form of having been
## accelerated inward from this depth: `sqrt(2 a s)`. Two things fall out of writing
## it that way rather than integrating it per-ship — the ship carries no drift state
## that could survive leaving the road, and editing the value in the F2 panel takes
## effect on the frame it is saved rather than after the next excursion.
##
## It scales with depth, so it is felt as a slope rather than as a wall, and forward
## speed is penalised at the same time. The player can always keep flying outward.
func push() -> Vector3:
	var past := edge_distance()
	if past <= 0.0 or push_accel <= 0.0:
		return Vector3.ZERO
	var toward := -(right * lateral + up * vertical)
	if toward.length_squared() <= 0.000001:
		return Vector3.ZERO
	return toward.normalized() * sqrt(2.0 * push_accel * past)


## A cross-frame for a road running this way. Level, because nothing rolls
## (ADR 0045) and the lane is wide and flat to match.
static func frame_for(direction: Vector3) -> Array[Vector3]:
	var forward := direction.normalized()
	var reference := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.99 \
		else Vector3.BACK
	var across := forward.cross(reference).normalized()
	return [across, across.cross(forward).normalized()]
