class_name RoadNetwork
extends Node3D
## Every road on the map, in both directions: two mainlines that run the length of it
## and a pair of ramps at each system.
##
## **The highway runs entirely through a system** (ADR 0065). It does not stop at a
## rim and it does not stop at a planet — it passes through, and the way on and off is
## a ramp that leaves it tangentially and curves down to a portal beside the planet.
## That is what makes a system the road passes through a *place on the way* rather
## than a wall across the route.
##
## Getting on and off is therefore a **union of lanes**, resolved the same way the
## boundary resolves its regions (ADR 0063): every deck going the player's way is
## asked how far outside it they are, and the one they are least outside of governs.
## Merging and diverging fall straight out of that — near an interchange both the
## mainline and the ramp contain the ship, and steering toward the ramp is what makes
## the ramp the answer. **No junction logic exists, and none should be written.**
##
## Decks are grouped by deck rather than by leg, so the union can never hand a ship
## the oncoming lane: only decks sharing `is_upper` are ever considered.

## How finely a ramp's curve is tessellated. Infrastructure, not feel: enough
## segments that the polyline reads as a curve at the scale a ramp is flown.
const RAMP_SEGMENTS := 14

var _decks: Array[RoadDeck] = []


## Wipe and rebuild the whole network. Called on every layout, because the systems
## move when the diameter or a leg length does.
func rebuild(centres: Array[Vector3], names: PackedStringArray,
		bearing_deg: float) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_decks.clear()
	if centres.size() < 2:
		return

	var forward := SystemDisc.bearing_to_direction(bearing_deg)
	var height := Tuning.num("exploration/deck_separation") * 0.5
	var radius := Tuning.num("exploration/system_diameter") * 0.5
	var last: Vector3 = centres[centres.size() - 1]

	for upper in [true, false]:
		# The lower deck runs the other way, is stacked under, and puts its ramps on
		# the other side of the planet — so a divided highway reads as two roads
		# rather than as one road drawn twice.
		var direction := forward if upper == RoadDeck.rides_upper(bearing_deg) \
			else -forward
		var lift := Vector3.UP * (height if upper else -height)
		var side := direction.cross(Vector3.UP).normalized()
		var from: Vector3 = centres[0] - forward * radius + lift
		var to := last + forward * radius + lift
		var mainline := _make_deck("Mainline" + ("Upper" if upper else "Lower"),
			upper, false, false)
		mainline.deck_name = "%s bound mainline" % (
			names[names.size() - 1] if direction.dot(forward) > 0.0 else names[0])
		mainline.follow(RoadPath.straight(from if direction.dot(forward) > 0.0 else to,
			to if direction.dot(forward) > 0.0 else from), "", "")

		# Which neighbour a ramp serves depends on which way this deck runs. On the
		# eastbound deck B's on-ramp leads to C and its off-ramp comes from A; on the
		# westbound deck both are the other way round.
		var onward := 1 if direction.dot(forward) > 0.0 else -1
		for i in centres.size():
			var ahead := i + onward
			var behind := i - onward
			_build_ramps(centres[i], names[i], direction, side, lift, upper,
				names[ahead] if ahead >= 0 and ahead < names.size() else "",
				names[behind] if behind >= 0 and behind < names.size() else "")


## An off-ramp and an on-ramp beside one system's planet, for one direction.
##
## The off-ramp leaves the mainline tangentially before the system's centre and
## curves down and out to a portal; the on-ramp starts at a portal on the far side and
## curves back up to rejoin. Both mouths are offset to the SIDE of the planet rather
## than above it, because directly above is inside the approach envelope and a ship
## taking the ramp would arm a landing sequence it did not ask for (ADR 0012).
##
## A ramp that serves nobody is not built. On the eastbound deck the westernmost
## system has nothing arriving at it and the easternmost has nowhere to go, so those
## two ramps would be openings onto a road with no traffic and a sign with no name on
## it. An empty `ahead` or `behind` is how the caller says so.
func _build_ramps(centre: Vector3, place: String, direction: Vector3,
		side: Vector3, lift: Vector3, upper: bool, ahead: String,
		behind: String) -> void:
	var run := Tuning.num("exploration/ramp_run_length")
	var gap := Tuning.num("exploration/portal_site_offset")
	var out := Tuning.num("exploration/ramp_side_offset")
	var down := Tuning.num("exploration/ramp_depth")
	var letter := place.substr(place.length() - 1, 1)
	var suffix := letter + ("Upper" if upper else "Lower")

	if not behind.is_empty():
		var leaves := centre + lift - direction * run
		var off_mouth := centre - direction * gap + side * out + Vector3.DOWN * down
		var off_ramp := _make_deck("RampOff" + suffix, upper, false, true)
		off_ramp.deck_name = "%s off-ramp" % place
		off_ramp.follow(RoadPath.ramp(leaves, direction, off_mouth, RAMP_SEGMENTS),
			place, behind)

	if not ahead.is_empty():
		var on_mouth := centre + direction * gap + side * out + Vector3.DOWN * down
		var rejoins := centre + lift + direction * run
		var on_ramp := _make_deck("RampOn" + suffix, upper, true, false)
		on_ramp.deck_name = "%s to %s on-ramp" % [place, ahead]
		# Built backwards from the mainline and reversed, so it MEETS the mainline
		# tangentially — which is the end that matters. A ramp that merges at an angle
		# is a corner the steering cone cannot turn.
		var backwards := RoadPath.ramp(rejoins, -direction, on_mouth, RAMP_SEGMENTS)
		var forwards := PackedVector3Array()
		for i in range(backwards.size() - 1, -1, -1):
			forwards.append(backwards[i])
		on_ramp.follow(forwards, ahead, place)


func _make_deck(deck_name: String, upper: bool, start_portal: bool,
		end_portal: bool) -> RoadDeck:
	var deck := RoadDeck.new()
	deck.name = deck_name
	deck.is_upper = upper
	deck.has_start_portal = start_portal
	deck.has_end_portal = end_portal
	add_child(deck)
	_decks.append(deck)
	return deck


func decks() -> Array[RoadDeck]:
	return _decks


## Which deck governs this point, among those going the same way: the one the ship is
## least outside of. Null when the network is empty.
##
## This is the whole of merging and diverging. Near an interchange the mainline and
## the ramp both contain the ship and the mainline wins because it is wider and the
## ship is nearer its centre; steering toward the ramp flips that, and the handover
## happens because the geometry says so rather than because a rule fired.
func governing(point: Vector3, upper: bool, exclude: RoadDeck = null) -> RoadDeck:
	var best: RoadDeck = null
	var best_depth := INF
	for deck in _decks:
		if deck.is_upper != upper or deck.length() <= 0.0 or deck == exclude:
			continue
		var depth := deck.sample(point).edge_distance()
		if depth < best_depth:
			best_depth = depth
			best = deck
	return best


## Every portal on the network. Only the ramps have them: a mainline is joined and
## left through the ramps, which is what keeps the highway continuous.
func portals() -> Array[Portal]:
	var found: Array[Portal] = []
	for deck in _decks:
		if deck.start_portal() != null:
			found.append(deck.start_portal())
		if deck.end_portal() != null:
			found.append(deck.end_portal())
	return found


func set_permitted(allowed: bool) -> void:
	for deck in _decks:
		deck.set_permitted(allowed)


func repaint() -> void:
	for deck in _decks:
		deck.repaint()
