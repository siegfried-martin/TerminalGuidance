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
## Decks are grouped by direction rather than by leg, so the union can never hand a
## ship the oncoming lane: only decks sharing `runs_forward` are ever considered.
##
## **The two directions run side by side, and traffic runs on the right** (ADR 0077).
## Each deck is offset from the spine by half `deck_separation` along the spine's own
## rightward normal *as that deck travels*, so the offsets are opposite and the
## oncoming lane is on your left from either seat. Nothing here needs to know a
## bearing, and no segment declares a deck.

## How finely a ramp is walked when looking for where it goes through the building it
## leaves. 96 steps over a 2.6 km ramp is a 27 m answer, which is well inside one
## module. Infrastructure.
const CROSSING_STEPS := 96

## How finely a ramp's curve is tessellated. Infrastructure, not feel: enough
## segments that the polyline reads as a curve at the scale a ramp is flown, and that
## `RoadPath.max_turn_deg_per_metre` measures the ramp rather than the tessellation.
const RAMP_SEGMENTS := 24
## How near a deck's own end still counts as being ON it. `RoadPath.closest` clamps, so
## a ship past the end of a ramp still reports as sitting on its last metre — and a
## lane that has ended behind you is not a lane you can be in. Infrastructure.
const END_TOLERANCE := 0.5

var _decks: Array[RoadDeck] = []
## The buildings. **One structure per pair of decks** — the mainline pair share a
## single building straddling the spine, and every ramp is a building of its own with
## one lane in it (ADR 0078). A deck is the lane you fly in; this is what it is inside.
var _structures: Array[RoadStructure] = []
## The building over both mainlines. Held because every ramp has to tell it where it
## goes through, and that cannot be known until the ramp's curve exists.
var _mainline_structure: RoadStructure = null
## The line the whole highway is laid on, in the map's frame. Not a road itself — the
## mainlines are this lifted to each deck, and the ramps branch off it.
var _spine: RoadPath = RoadPath.new()


## Wipe and rebuild the whole network. Called on every layout, because the systems
## move when the diameter or a leg length does, and the legs change shape when the
## curvature does.
func rebuild(spine: PackedVector3Array, centres: Array[Vector3],
		names: PackedStringArray) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_decks.clear()
	_structures.clear()
	_spine.set_points(spine)
	if centres.size() < 2 or _spine.is_empty():
		return

	# The whole stack rides at `road_height` above the combat plane, not around it. A
	# highway through the middle of a system is in the way of everything that happens
	# there; up near the ceiling it is scenery you fly under, and an obstacle if a
	# fight goes that way.
	var across := Tuning.num("exploration/deck_separation") * 0.5
	var deck_base := Vector3.UP * Tuning.num("exploration/road_height")

	# ONE building for both carriageways. It straddles the spine, a carriageway either
	# side of the median, and it is the reason the deck and the structure had to be
	# split: a deck cannot own a building that also belongs to the deck coming the
	# other way. Its interior spans the two lanes and the gap between them, so the
	# outermost lane edge is exactly its inside face.
	var pair := Vector2(across * 2.0 + Tuning.num("exploration/lane_width"),
		Tuning.num("exploration/lane_height")) * 0.5
	_mainline_structure = _make_structure("StructureMainline", false, true)
	_mainline_structure.follow(_lifted(deck_base, 1.0, 0.0), pair, pair,
		false, false)

	for runs_forward in [true, false]:
		# The reversed deck runs the other way, sits on the other side of the spine,
		# and puts its ramps on the other side of the planet — so a divided highway
		# reads as two roads rather than as one road drawn twice. `sense` is which way
		# along the spine this deck's traffic moves, and every placement below is
		# written in it, including which side of the spine "right" is.
		var sense := 1.0 if runs_forward else -1.0
		var mainline := _make_deck(
			"Mainline" + ("Forward" if runs_forward else "Reverse"),
			runs_forward, false, false)
		mainline.deck_name = "%s bound mainline" % (
			names[names.size() - 1] if sense > 0.0 else names[0])
		mainline.follow(_lifted(deck_base, sense, across), "", "")

		# Which neighbour a ramp serves depends on which way this deck runs. On the
		# eastbound deck B's on-ramp leads to C and its off-ramp comes from A; on the
		# westbound deck both are the other way round.
		var onward := 1 if sense > 0.0 else -1
		for i in centres.size():
			var ahead := i + onward
			var behind := i - onward
			_build_ramps(centres[i], names[i], sense, deck_base, across, runs_forward,
				names[ahead] if ahead >= 0 and ahead < names.size() else "",
				names[behind] if behind >= 0 and behind < names.size() else "")


## The spine, raised to the road's height and moved to this deck's side of it, and
## reversed for the deck that runs the other way.
##
## The offset is LATERAL — along the spine's rightward normal at each point, signed by
## which way this deck travels. It used to be vertical, chosen so that both decks came
## out the same length on a bend; a divided highway does not have that property, and
## the inner deck is genuinely shorter through a curve. What that costs is a floor on
## the geometry: a bend tighter than the deck separation folds the inner lane through
## itself, so the gate checks the spine's minimum curve radius against it (ADR 0077).
func _lifted(base: Vector3, sense: float, across: float) -> PackedVector3Array:
	var line := PackedVector3Array()
	var count := _spine.points.size()
	for i in count:
		var index := count - 1 - i if sense < 0.0 else i
		line.append(_spine.points[index] + base
			+ _across_at(index) * sense * across)
	return line


## The spine's rightward normal at one of its own points, from the segments either
## side of it. Taken from the spine rather than from a bearing: on a weaving leg those
## differ, and a deck placed on the bearing would drift across the median.
func _across_at(index: int) -> Vector3:
	var last := _spine.points.size() - 1
	var travel: Vector3 = _spine.points[mini(index + 1, last)] \
		- _spine.points[maxi(index - 1, 0)]
	var side := travel.cross(Vector3.UP)
	return Vector3.RIGHT if side.length_squared() < 0.000001 else side.normalized()


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
func _build_ramps(centre: Vector3, place: String, sense: float, base: Vector3,
		across: float, runs_forward: bool, ahead: String, behind: String) -> void:
	var run := Tuning.num("exploration/ramp_run_length")
	var gap := Tuning.num("exploration/portal_site_offset")
	# An exit and an entry are different shapes, and this is where that is decided: an
	# exit swings wide and stays high so it reaches a WALL, an entry sits close in and
	# drops so it reaches the FLOOR (ADR 0080).
	var exit_out := Tuning.num("exploration/ramp_exit_side_offset")
	var exit_down := Tuning.num("exploration/ramp_exit_depth")
	var entry_out := Tuning.num("exploration/ramp_entry_side_offset")
	var entry_down := Tuning.num("exploration/ramp_entry_depth")
	var tightness := Tuning.num("exploration/ramp_curve_tightness")
	var here: float = _spine.closest(centre)[0]
	var letter := place.substr(place.length() - 1, 1)
	var suffix := letter + ("Forward" if runs_forward else "Reverse")

	if not behind.is_empty():
		var leaves := _at(here - sense * run, base, sense, across)
		var off_mouth := _mouth(here - sense * gap, exit_out, exit_down, sense,
			base, across)
		var off_ramp := _make_deck("RampOff" + suffix, runs_forward, false, true)
		off_ramp.deck_name = "%s off-ramp" % place
		var off_curve := RoadPath.ramp(leaves[0], leaves[1], off_mouth[0],
			off_mouth[1], tightness, RAMP_SEGMENTS)
		off_ramp.follow(off_curve, place, behind)
		# A ramp is a building with one lane in it and no median, narrowing to its
		# portal at the end it meets the planet.
		_make_structure("StructureRampOff" + suffix, true, false).follow(
			off_curve, _lane_section(), _mouth_section(), false, true)
		# The mainline's wall has to open where this ramp leaves through it.
		_open_for(off_ramp.path(), true)

	if not ahead.is_empty():
		var on_mouth := _mouth(here + sense * gap, entry_out, entry_down, sense,
			base, across)
		var rejoins := _at(here + sense * run, base, sense, across)
		var on_ramp := _make_deck("RampOn" + suffix, runs_forward, true, false)
		on_ramp.deck_name = "%s to %s on-ramp" % [place, ahead]
		# Built FORWARDS, from the mouth up to the merge. It used to be built backwards
		# and reversed, because a quadratic could only be told one tangent and the
		# merge was the end that had to be right; a cubic is told both, so the trick is
		# gone and the mouth is as deliberate as the merge.
		var on_curve := RoadPath.ramp(on_mouth[0], on_mouth[1], rejoins[0],
			rejoins[1], tightness, RAMP_SEGMENTS)
		on_ramp.follow(on_curve, ahead, place)
		_make_structure("StructureRampOn" + suffix, true, false).follow(
			on_curve, _lane_section(), _mouth_section(), true, false)
		# …and its roadway has to open where this one comes up through it.
		_open_for(on_ramp.path(), false)


## A point on the mainline and the direction traffic runs there, as `[point, tangent]`.
## On this deck's own side of the spine, so a ramp leaves the road rather than the
## line the road was laid on.
func _at(along: float, base: Vector3, sense: float, across: float) -> Array:
	var clamped := clampf(along, 0.0, _spine.length())
	var travel := _spine.tangent_at(clamped) * sense
	return [_spine.point_at(clamped) + base + _side_of(travel) * across, travel]


## A ramp mouth beside the planet, and the direction the road runs past it.
##
## The side is taken from the spine's own tangent here rather than from the map's
## bearing: on a weaving leg those differ, and a mouth placed on the bearing would
## drift off the side of the interchange it belongs to.
## `out` is measured from the DECK, not from the spine, so the shape of a ramp does not
## change when the two carriageways are moved apart.
func _mouth(along: float, out: float, down: float, sense: float, base: Vector3,
		across: float) -> Array:
	var clamped := clampf(along, 0.0, _spine.length())
	var travel := _spine.tangent_at(clamped) * sense
	return [_spine.point_at(clamped) + base + _side_of(travel) * (across + out)
		+ Vector3.DOWN * down, travel]


## Which way is right, for something travelling this way. The whole of right-hand
## traffic is this one expression (ADR 0077).
func _side_of(travel: Vector3) -> Vector3:
	var side := travel.cross(Vector3.UP)
	return Vector3.RIGHT if side.length_squared() < 0.000001 else side.normalized()


## Open the mainline's building where a ramp goes through it.
##
## **Measured, not assumed.** A ramp is a cubic whose shape falls out of four tuned
## numbers, so where it clears the wall moves the moment any of them moves; an opening
## placed by arithmetic would drift off its ramp the first time the human touched a
## slider. Walk the ramp from the end that touches the mainline until it is outside
## the building, and ask the building where that was.
##
## The FACE is **authored**, not chosen. An entry comes up through the floor and
## nothing else; an exit leaves through whichever wall or roof its own curve reaches,
## and never the floor (ADR 0080). What is measured is WHERE, and — through
## `crossing()` — whether the ramp actually obeys the rule it was authored to.
func _open_for(ramp: RoadPath, leaving: bool) -> void:
	if _mainline_structure == null or ramp.length() <= 0.0:
		return
	var found := crossing(_mainline_structure, ramp, leaving)
	if found.is_empty():
		return
	_mainline_structure.pierce(found[0],
		found[1] if leaving else RoadStructure.Face.BELOW)


## Where a ramp first leaves the building it is inside, walking from the end that
## touches the mainline, as `[along, face]`. Empty if it never does.
##
## **Measured, not assumed.** A ramp is a cubic whose shape falls out of four tuned
## numbers, so where it clears the wall moves the moment any of them moves; an opening
## placed by arithmetic would drift off its ramp the first time the human touched a
## slider.
##
## Static and public because the gate needs the same answer: the rule that an entry
## comes from below is only true if the ramp's curve actually crosses the FLOOR before
## it crosses a wall, and that is a property of four sliders rather than of this code.
static func crossing(built: RoadStructure, ramp: RoadPath,
		leaving: bool) -> Array:
	var line := built.path()
	for i in CROSSING_STEPS + 1:
		var t := float(i) / float(CROSSING_STEPS)
		var point := ramp.point_at(ramp.length() * (t if leaving else 1.0 - t))
		var found := line.closest(point)
		var here: float = found[0]
		var frame := CruiseLane.frame_for(found[2] as Vector3)
		var offset: Vector3 = point - (found[1] as Vector3)
		var extents := built.extents_at(here)
		var across := offset.dot(frame[0])
		var up := offset.dot(frame[1])
		var out_across := absf(across) / maxf(extents.x, 0.001)
		var out_up := absf(up) / maxf(extents.y, 0.001)
		if out_across <= 1.0 and out_up <= 1.0:
			continue
		var face := RoadStructure.Face.BELOW
		if out_across >= out_up:
			face = RoadStructure.Face.RIGHT if across > 0.0 \
				else RoadStructure.Face.LEFT
		elif up > 0.0:
			face = RoadStructure.Face.ABOVE
		return [here, face]
	return []


## One carriageway's own half-section, and the narrower one at a portal mouth. Read
## here rather than inside the structure so a ramp's building and a ramp's lane are
## handed the same two numbers.
func _lane_section() -> Vector2:
	return Vector2(Tuning.num("exploration/lane_width"),
		Tuning.num("exploration/lane_height")) * 0.5


func _mouth_section() -> Vector2:
	return Vector2(Tuning.num("exploration/portal_width"),
		Tuning.num("exploration/portal_height")) * 0.5


func _make_structure(structure_name: String, ramp: bool,
		median: bool) -> RoadStructure:
	var built := RoadStructure.new()
	built.name = structure_name
	built.structure_name = structure_name
	built.is_ramp = ramp
	built.has_median = median
	add_child(built)
	_structures.append(built)
	return built


func _make_deck(deck_name: String, runs_forward: bool, start_portal: bool,
		end_portal: bool) -> RoadDeck:
	var deck := RoadDeck.new()
	deck.name = deck_name
	deck.runs_forward = runs_forward
	deck.has_start_portal = start_portal
	deck.has_end_portal = end_portal
	add_child(deck)
	_decks.append(deck)
	return deck


func decks() -> Array[RoadDeck]:
	return _decks


## Every building on the network: one for the mainline pair, one per ramp.
func structures() -> Array[RoadStructure]:
	return _structures


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
func governing(point: Vector3, runs_forward: bool, exclude: RoadDeck = null,
		clearance: Vector2 = Vector2.ZERO,
		along: Vector3 = Vector3.ZERO) -> RoadDeck:
	var best: RoadDeck = null
	var best_depth := INF
	var cone := cos(deg_to_rad(Tuning.num("exploration/cruise_turn_clamp_deg")))
	for deck in _decks:
		if deck.runs_forward != runs_forward or deck.length() <= 0.0 \
				or deck == exclude:
			continue
		var lane := deck.sample(point, clearance)
		# A deck that does not REACH this point cannot govern it. `closest` clamps to
		# the ends, so without this a ship at the top of a ramp is reported as sitting
		# on the ramp's last metre for ever: the ramp hands over because it has ended,
		# the union hands straight back because the ramp is still the nearest thing,
		# and the two alternate every frame until the ship falls off the road (ADR
		# 0076). This is `TubeRegion.applies_to`'s rule, for lanes.
		if lane.metres_travelled <= END_TOLERANCE \
				or lane.metres_remaining <= END_TOLERANCE:
			continue
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
	for built in _structures:
		built.repaint()
