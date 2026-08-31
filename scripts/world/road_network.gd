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
## **The network is laid on a spine**, a single polyline handed down by the map that
## runs from behind the first system, through every system centre and along every leg,
## to past the last. The legs weave and undulate now, so nothing here may assume a
## direction that holds for more than a point: every ramp is placed from the spine's
## tangent *where it starts*, not from the map's bearing.
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
## segments that the polyline reads as a curve at the scale a ramp is flown, and that
## `RoadPath.max_turn_deg_per_metre` measures the ramp rather than the tessellation.
const RAMP_SEGMENTS := 24

var _decks: Array[RoadDeck] = []
## The line the whole highway is laid on, in the map's frame. Not a road itself — the
## mainlines are this lifted to each deck, and the ramps branch off it.
var _spine: RoadPath = RoadPath.new()


## Wipe and rebuild the whole network. Called on every layout, because the systems
## move when the diameter or a leg length does, and the legs change shape when the
## curvature does.
func rebuild(spine: PackedVector3Array, centres: Array[Vector3],
		names: PackedStringArray, bearing_deg: float) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_decks.clear()
	_spine.set_points(spine)
	if centres.size() < 2 or _spine.is_empty():
		return

	# The whole stack rides at `road_height` above the combat plane, not around it. A
	# highway through the middle of a system is in the way of everything that happens
	# there; up near the ceiling it is scenery you fly under, and an obstacle if a
	# fight goes that way.
	var height := Tuning.num("exploration/deck_separation") * 0.5
	var deck_base := Vector3.UP * Tuning.num("exploration/road_height")

	for upper in [true, false]:
		# The lower deck runs the other way, is stacked under, and puts its ramps on
		# the other side of the planet — so a divided highway reads as two roads
		# rather than as one road drawn twice. `sense` is which way along the spine
		# this deck's traffic moves, and every placement below is written in it.
		var sense := 1.0 if upper == RoadDeck.rides_upper(bearing_deg) else -1.0
		var lift := deck_base + Vector3.UP * (height if upper else -height)
		var mainline := _make_deck("Mainline" + ("Upper" if upper else "Lower"),
			upper, false, false)
		mainline.deck_name = "%s bound mainline" % (
			names[names.size() - 1] if sense > 0.0 else names[0])
		mainline.follow(_lifted(lift, sense < 0.0), "", "")

		# Which neighbour a ramp serves depends on which way this deck runs. On the
		# eastbound deck B's on-ramp leads to C and its off-ramp comes from A; on the
		# westbound deck both are the other way round.
		var onward := 1 if sense > 0.0 else -1
		for i in centres.size():
			var ahead := i + onward
			var behind := i - onward
			_build_ramps(centres[i], names[i], sense, lift, upper,
				names[ahead] if ahead >= 0 and ahead < names.size() else "",
				names[behind] if behind >= 0 and behind < names.size() else "")


## The spine, moved to a deck's height, and reversed for the deck that runs the other
## way. A vertical lift rather than an offset along the curve's normal, because the
## road is near-level everywhere and a normal offset would make the two decks
## different lengths on every bend.
func _lifted(lift: Vector3, reversed: bool) -> PackedVector3Array:
	var line := PackedVector3Array()
	var count := _spine.points.size()
	for i in count:
		line.append(_spine.points[count - 1 - i if reversed else i] + lift)
	return line


## An off-ramp and an on-ramp beside one system's planet, for one direction.
##
## The off-ramp leaves the mainline tangentially before the system's centre and
## curves down and out to a portal; the on-ramp starts at a portal on the far side and
## curves back up to rejoin. **Both ends of both curves are tangential to the road**
## (`RoadPath.ramp`), so a ramp arrives at its portal pointing along the highway
## rather than square across it — a mouth you fly into rather than dive at.
##
## Both mouths are offset to the SIDE of the planet rather than above it, because
## directly above is inside the approach envelope and a ship taking the ramp would arm
## a landing sequence it did not ask for (ADR 0012).
##
## A ramp that serves nobody is not built. On the eastbound deck the westernmost
## system has nothing arriving at it and the easternmost has nowhere to go, so those
## two ramps would be openings onto a road with no traffic and a sign with no name on
## it. An empty `ahead` or `behind` is how the caller says so.
func _build_ramps(centre: Vector3, place: String, sense: float, lift: Vector3,
		upper: bool, ahead: String, behind: String) -> void:
	var run := Tuning.num("exploration/ramp_run_length")
	var gap := Tuning.num("exploration/portal_site_offset")
	var out := Tuning.num("exploration/ramp_side_offset")
	var down := Tuning.num("exploration/ramp_depth")
	var tightness := Tuning.num("exploration/ramp_curve_tightness")
	var here: float = _spine.closest(centre)[0]
	var letter := place.substr(place.length() - 1, 1)
	var suffix := letter + ("Upper" if upper else "Lower")

	if not behind.is_empty():
		var leaves := _at(here - sense * run, lift, sense)
		var off_mouth := _mouth(here - sense * gap, out, down, sense)
		var off_ramp := _make_deck("RampOff" + suffix, upper, false, true)
		off_ramp.deck_name = "%s off-ramp" % place
		off_ramp.follow(RoadPath.ramp(leaves[0], leaves[1], off_mouth[0],
			off_mouth[1], tightness, RAMP_SEGMENTS), place, behind)

	if not ahead.is_empty():
		var on_mouth := _mouth(here + sense * gap, out, down, sense)
		var rejoins := _at(here + sense * run, lift, sense)
		var on_ramp := _make_deck("RampOn" + suffix, upper, true, false)
		on_ramp.deck_name = "%s to %s on-ramp" % [place, ahead]
		# Built FORWARDS, from the mouth up to the merge. It used to be built backwards
		# and reversed, because a quadratic could only be told one tangent and the
		# merge was the end that had to be right; a cubic is told both, so the trick is
		# gone and the mouth is as deliberate as the merge.
		on_ramp.follow(RoadPath.ramp(on_mouth[0], on_mouth[1], rejoins[0],
			rejoins[1], tightness, RAMP_SEGMENTS), ahead, place)


## A point on the mainline and the direction traffic runs there, as `[point, tangent]`.
func _at(along: float, lift: Vector3, sense: float) -> Array:
	var clamped := clampf(along, 0.0, _spine.length())
	return [_spine.point_at(clamped) + lift, _spine.tangent_at(clamped) * sense]


## A ramp mouth beside the planet, and the direction the road runs past it.
##
## The side is taken from the spine's own tangent here rather than from the map's
## bearing: on a weaving leg those differ, and a mouth placed on the bearing would
## drift off the side of the interchange it belongs to.
func _mouth(along: float, out: float, down: float, sense: float) -> Array:
	var clamped := clampf(along, 0.0, _spine.length())
	var travel := _spine.tangent_at(clamped) * sense
	var side := travel.cross(Vector3.UP)
	side = Vector3.RIGHT if side.length_squared() < 0.000001 else side.normalized()
	return [_spine.point_at(clamped) + side * out + Vector3.DOWN * down, travel]


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


## The line the whole highway is laid on. For the map and for tests; nothing steers
## by it.
func spine() -> RoadPath:
	return _spine


## Which deck governs this point, among those going the same way: the one the ship is
## least outside of. Null when the network is empty.
##
## This is the whole of merging and diverging. Near an interchange the mainline and
## the ramp both contain the ship and the mainline wins because it is wider and the
## ship is nearer its centre; steering toward the ramp flips that, and the handover
## happens because the geometry says so rather than because a rule fired.
##
## `clearance` is the asking ship's own half-section, and it has to be the same one
## the ship is flown with — comparing a hull-measured depth against a point-measured
## one would hand a big ship whichever deck happened to be asked with zero.
## `along` is the direction the ship is currently being held against — the road it is
## on. A deck whose own direction here is more than the steering cone away from that
## is NOT a candidate, however near the ship happens to be to it. That is not junction
## logic and it does not choose anything: it is the same "can I point at it" the cone
## already applies to the player, applied to the lane. Without it, drifting wide of a
## mainline beside an interchange handed the ship to a ramp thirty degrees off its
## heading and swung the nose there in a single frame (ADR 0072). Pass a zero vector
## to consider every deck, which is what joining the road from outside does.
func governing(point: Vector3, upper: bool, exclude: RoadDeck = null,
		clearance: Vector2 = Vector2.ZERO,
		along: Vector3 = Vector3.ZERO) -> RoadDeck:
	var best: RoadDeck = null
	var best_depth := INF
	var cone := cos(deg_to_rad(Tuning.num("exploration/cruise_turn_clamp_deg")))
	for deck in _decks:
		if deck.is_upper != upper or deck.length() <= 0.0 or deck == exclude:
			continue
		var lane := deck.sample(point, clearance)
		if along != Vector3.ZERO and lane.axis.dot(along) < cone:
			continue
		var depth := lane.edge_distance()
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


## Which deck the ship is riding, or null. Only that one draws its ribs, and it draws
## them brighter — an interchange is four decks deep and the player has to be able to
## see which of them is the road they are on.
func set_active(riding: RoadDeck) -> void:
	for deck in _decks:
		deck.set_active(deck == riding)


func repaint() -> void:
	for deck in _decks:
		deck.repaint()
