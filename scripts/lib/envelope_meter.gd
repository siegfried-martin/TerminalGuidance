class_name EnvelopeMeter
extends RefCounted
## How far a fight sprawls, measured rather than estimated.
##
## `ship.max_engagement_envelope` is the first link in the exploration numbers
## chain — envelope → disc height → cruise speeds → system diameter, each mostly
## determining the next — and it has been deferred four times because it reads like
## something a human has to remember to eyeball. It is not. It is a high-water mark
## over a handful of positions, and the arena can keep it without being asked.
##
## Two numbers, because the chain wants them for different things:
##
## - **span** — the largest distance between any two participants. This is the
##   envelope proper, and it sizes the disc's diameter and the reference field.
## - **vertical** — the largest spread along the up axis alone. This is what
##   `PROJECT_OVERVIEW` §Open Questions 1 actually needs, because the reason disc
##   height is 5–10x the envelope is *"so the ceiling never enters a fight"*, and a
##   ceiling is only ever entered vertically. Sizing height against the horizontal
##   sprawl over-builds it by whatever the aspect of a fight happens to be.
##
## Participants are ships and things that are steered — missiles on both sides.
## Gun rounds are deliberately excluded: they are a stream rather than a
## participant, and their reach is already a tuned constant that needs no measuring.
##
## Pure: no scene tree, no disk, no tuning. The arena feeds it positions.

## High-water marks, held for the whole session. These are the readings.
var span: float = 0.0
var vertical: float = 0.0

## The same two for this frame only, so the HUD can show a live figure beside the
## record and the human can see which moment produced it.
var current_span: float = 0.0
var current_vertical: float = 0.0

## How many participants the last observation saw. A span measured across one node
## is zero and means nothing; the HUD uses this to say so rather than showing 0 m.
var participants: int = 0


## Feed the meter this frame's participants, in any frame — the measurement is of
## distances between them, so it is invariant to a floating-origin recentre as long
## as every point is in the same space.
func observe(points: Array[Vector3]) -> void:
	participants = points.size()
	current_span = 0.0
	current_vertical = 0.0
	if points.size() < 2:
		return
	# O(n^2) over a handful of nodes. A bounding box would be cheaper and wrong:
	# the largest distance between two points on a diagonal is not an axis extent.
	for i in points.size():
		for j in range(i + 1, points.size()):
			current_span = maxf(current_span, points[i].distance_to(points[j]))
	var lowest := points[0].y
	var highest := points[0].y
	for point in points:
		lowest = minf(lowest, point.y)
		highest = maxf(highest, point.y)
	current_vertical = highest - lowest
	span = maxf(span, current_span)
	vertical = maxf(vertical, current_vertical)


## Forget the record. Not called by anything yet — it exists so a session that
## wants a per-fight reading rather than a per-session one has somewhere to ask.
func reset() -> void:
	span = 0.0
	vertical = 0.0
	current_span = 0.0
	current_vertical = 0.0
	participants = 0


## The reading, for the HUD and for pasting into STATUS.md.
func summary() -> String:
	if participants < 2:
		return "%.0f m across · %.0f m tall  (nothing in the air)" % [span, vertical]
	return "%.0f m across · %.0f m tall  (now %.0f / %.0f)" % [
		span, vertical, current_span, current_vertical]
