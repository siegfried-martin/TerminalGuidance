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
## The union can never hand a ship the oncoming lane, and that is **geometric**: a
## candidate has to lie inside the steering cone around the road the ship is already
## held against, and a lane coming the other way is 180 degrees outside it (ADR 0081).
## `runs_forward` is a name for which way a deck runs along its own spine and nothing
## filters on it.
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
## Every exit sign on the network. Mounted on the mainline's building ahead of each
## off-ramp, naming where that exit goes.
var _signs: Array[ExitSign] = []
## The line the whole highway is laid on, in the map's frame. Not a road itself — the
## mainlines are this lifted to each deck, and the ramps branch off it.
var _spine: RoadPath = RoadPath.new()


## Wipe and rebuild the whole network. Called on every layout, because the systems
## move when the diameter or a leg length does, and the legs change shape when the
## curvature does.
func rebuild(spine: PackedVector3Array, centres: Array[Vector3],
		names: PackedStringArray, route_name: String = "",
		crossing: PackedVector3Array = PackedVector3Array(),
		crossing_name: String = "") -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_decks.clear()
	_structures.clear()
	_signs.clear()
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
		mainline.route_name = route_name
		mainline.deck_name = "%s %s bound" % [route_name,
			names[names.size() - 1] if sense > 0.0 else names[0]]
		mainline.follow(_lifted(deck_base, sense, across), "", "")

		# Which neighbour a ramp serves depends on which way this deck runs. On the
		# eastbound deck B's on-ramp leads to C and its off-ramp comes from A; on the
		# westbound deck both are the other way round.
		var onward := 1 if sense > 0.0 else -1
		for i in centres.size():
			var ahead := i + onward
			var behind := i - onward
			_build_ramps(centres[i], names[i], sense, deck_base, across, runs_forward,
				route_name,
				names[ahead] if ahead >= 0 and ahead < names.size() else "",
				names[behind] if behind >= 0 and behind < names.size() else "")

	if crossing.size() >= 2:
		_build_crossing(crossing, across, crossing_name)


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
	return _laid_on(_spine, base, sense, across)


## The same, for any route. The crossing road is laid exactly like the main one — its
## own spine, a carriageway to the right of each direction — because there is nothing
## special about the first road on the map (ADR 0081).
func _laid_on(route: RoadPath, base: Vector3, sense: float,
		across: float) -> PackedVector3Array:
	var line := PackedVector3Array()
	var count := route.points.size()
	for i in count:
		var index := count - 1 - i if sense < 0.0 else i
		line.append(route.points[index] + base
			+ _across_at(route, index) * sense * across)
	return line


## A route's rightward normal at one of its own points, from the segments either side
## of it. Taken from the route rather than from a bearing: on a weaving leg those
## differ, and a deck placed on the bearing would drift across the median.
func _across_at(route: RoadPath, index: int) -> Vector3:
	var last := route.points.size() - 1
	var travel: Vector3 = route.points[mini(index + 1, last)] \
		- route.points[maxi(index - 1, 0)]
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
		across: float, runs_forward: bool, route_name: String, ahead: String,
		behind: String) -> void:
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
		off_ramp.route_name = route_name
		off_ramp.deck_name = "%s off-ramp" % place
		var off_curve := RoadPath.ramp(leaves[0], leaves[1], off_mouth[0],
			off_mouth[1], tightness, RAMP_SEGMENTS)
		off_ramp.follow(off_curve, place, behind)
		# A ramp is a building with one lane in it and no median, narrowing to its
		# portal at the end it meets the planet.
		_make_structure("StructureRampOff" + suffix, true, false).follow(
			off_curve, _lane_section(), _mouth_section(), false, true)
		# The mainline's wall has to open where this ramp leaves through it — and a
		# sign has to hang far enough back that the choice arrives before the exit
		# does. Reading it in time is a piloting act, and missing it costs one hop off
		# and back on, which is the price ADR 0057 already sets (ADR 0083).
		_open_for(off_ramp.path(), true)
		_sign_for(off_ramp, place)

	if not ahead.is_empty():
		var on_mouth := _mouth(here + sense * gap, entry_out, entry_down, sense,
			base, across)
		var rejoins := _at(here + sense * run, base, sense, across)
		var on_ramp := _make_deck("RampOn" + suffix, runs_forward, true, false)
		on_ramp.route_name = route_name
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


## A SECOND HIGHWAY, crossing the first. Its own spine, its own pair of carriageways
## in its own building, and two ramps from the main road onto it.
##
## It exists so the exit-face rules can be FLOWN. An exit rule you cannot fly is an
## exit rule you cannot judge, and both interesting cases — turning right onto a road
## going right, and going over the top to reach one coming the other way — need a
## second road to turn onto.
##
## It carries no portals and simply ENDS, the way the main road ends at the edge of
## the map: run off it and you drop into normal flight. That is deliberate rather than
## unfinished — a portal at the end would make a mainline read as a ramp (ADR 0076
## keyed that off the portal), and there is nothing on the far side of it yet.
func _build_crossing(line: PackedVector3Array, across: float,
		route_name: String) -> void:
	var route := RoadPath.new()
	route.set_points(line)
	var pair := Vector2(across * 2.0 + Tuning.num("exploration/lane_width"),
		Tuning.num("exploration/lane_height")) * 0.5
	_make_structure("StructureCrossing", false, true).follow(
		_laid_on(route, Vector3.ZERO, 1.0, 0.0), pair, pair, false, false)

	var carriageways: Array[RoadDeck] = []
	for runs_forward in [true, false]:
		var sense := 1.0 if runs_forward else -1.0
		var deck := _make_deck(
			"Crossing" + ("Forward" if runs_forward else "Reverse"),
			runs_forward, false, false)
		deck.route_name = route_name
		deck.deck_name = "%s crossing" % route_name
		deck.follow(_laid_on(route, Vector3.ZERO, sense, across), "", "")
		carriageways.append(deck)

	# WHICH WAY EACH ONE GOES, from the main road's point of view. The exit-face rule
	# is written in those terms — right onto a road going right, over the top onto one
	# going left — so this is the one thing the interchange has to work out, and it is
	# a cross product rather than a decision.
	var meeting: float = _spine.closest(route.point_at(route.length() * 0.5))[0]
	var main_travel := _spine.tangent_at(meeting)
	# ONLY THE RIGHT-HAND TURN IS BUILT, and that is a real gap rather than an
	# omission of taste. Turning onto the carriageway coming the OTHER way is better
	# than ninety degrees of rotation, and `RoadPath.ramp` is a cubic: asked to hold
	# that much it puts all the turning in one place, measured at 72 deg/s against a
	# ship that turns at 34, and chaining two cubics through a crest measured worse
	# still at 132. What that ramp needs is an arc — a curve built to a bounded
	# radius rather than to two tangents — and that is a `RoadPath` primitive that
	# does not exist yet, with its own gate. It is not a tuning problem and it must
	# not be "fixed" by relaxing ADR 0070's check.
	for deck: RoadDeck in carriageways:
		var turn := main_travel.cross(
			deck.path().tangent_at(deck.length() * 0.5)).dot(Vector3.UP)
		if turn < 0.0:
			_build_interchange(deck, meeting, true, across)


## One ramp from the main road onto the crossing road.
##
## `to_the_right` says which of the two rules applies. Only the right-hand turn is
## built: swing out through the wall and climb. The other rule — over the top and down
## onto the carriageway coming the other way — is more than ninety degrees of rotation
## and needs a curve built to a bounded radius, which `RoadPath` cannot make yet.
## Which face the ramp actually uses is measured, and the gate holds the rule (ADR
## 0080).
func _build_interchange(onto: RoadDeck, meeting: float, to_the_right: bool,
		across: float) -> void:
	var run := Tuning.num("exploration/interchange_run_length")
	var base := Vector3.UP * Tuning.num("exploration/road_height")
	var lead := run if to_the_right else run * 1.7
	var leaves := _at(meeting - lead, base, 1.0, across)
	var lands: float = onto.path().closest(
		_spine.point_at(meeting))[0] + run * 0.45
	lands = clampf(lands, 0.0, onto.length())
	var ramp := _make_deck("Interchange" + ("Right" if to_the_right else "Over"),
		true, false, false, true)
	ramp.route_name = onto.route_name
	ramp.deck_name = "to %s" % onto.route_name
	var tightness := Tuning.num("exploration/ramp_curve_tightness")
	var arrives: Vector3 = onto.path().point_at(lands)
	var joins: Vector3 = onto.path().tangent_at(lands)
	var curve := RoadPath.ramp(leaves[0], leaves[1], arrives, joins, tightness,
		RAMP_SEGMENTS)
	ramp.follow(curve, "", "")
	_make_structure("Structure" + ramp.name, true, false).follow(
		curve, _lane_section(), _lane_section(), false, false)
	_open_for(ramp.path(), true)


## A sign on the mainline, ahead of an exit, naming where it goes.
##
## Placed from the opening the ramp actually makes, not from the ramp's own start: what
## the player has to see coming is the hole in the wall, and the sign belongs a lead
## distance back from that, on the same side, tucked just inside the section.
func _sign_for(ramp: RoadDeck, place: String) -> void:
	if _mainline_structure == null:
		return
	var openings := _mainline_structure.apertures()
	if openings.is_empty():
		return
	var opening: Array = openings[openings.size() - 1]
	var at: float = opening[0]
	var face: int = opening[1]
	var lead := Tuning.num("exploration/exit_sign_lead_metres")
	var along := clampf(at - lead, 0.0, _mainline_structure.length())
	var line := _mainline_structure.path()
	var frame := CruiseLane.frame_for(line.tangent_at(along))
	var extents := _mainline_structure.extents_at(along)
	var side := 1.0 if face == int(RoadStructure.Face.LEFT) else -1.0
	var sign := ExitSign.new()
	sign.name = "Sign" + ramp.name
	sign.ramp = ramp
	sign.label_text = "EXIT  %s" % place
	# Just inside the wall the exit is in, and up out of the traffic on the roadway.
	sign.position = line.point_at(along) \
		- frame[0] * side * extents.x * Tuning.num("exploration/exit_sign_inset") \
		+ frame[1] * extents.y * Tuning.num("exploration/exit_sign_rise")
	add_child(sign)
	_signs.append(sign)


## Every exit sign on the network. For the berth, the HUD and the gate.
func signs() -> Array[ExitSign]:
	return _signs


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
		end_portal: bool, ramp: bool = false) -> RoadDeck:
	var deck := RoadDeck.new()
	deck.name = deck_name
	deck.runs_forward = runs_forward
	deck.is_ramp = ramp or start_portal or end_portal
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
## on — and it is **required**. A deck whose own direction here is more than the
## steering cone away from it is NOT a candidate, however near the ship happens to be.
## That is not junction logic and it does not choose anything: it is the same "can I
## point at it" the cone already applies to the player, applied to the lane. Without
## it, drifting wide of a mainline beside an interchange handed the ship to a ramp
## thirty degrees off its heading and swung the nose there in a single frame (ADR
## 0072); and with a second highway crossing the first, it is also the only thing that
## keeps the union from handing you a road going somewhere else entirely (ADR 0081).
func governing(point: Vector3, along: Vector3, exclude: RoadDeck = null,
		clearance: Vector2 = Vector2.ZERO) -> RoadDeck:
	var best: RoadDeck = null
	var best_depth := INF
	var cone := cos(deg_to_rad(Tuning.num("exploration/cruise_turn_clamp_deg")))
	for deck in _decks:
		if deck.length() <= 0.0 or deck == exclude:
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
		# THE WHOLE OF "never the oncoming lane", and of "never a road you could not
		# steer onto". `along` is the direction the ship is being held against, so a
		# deck more than the steering cone away from it is not a candidate however
		# near the ship happens to be to it — which excludes the lane coming the other
		# way at 180 degrees, every deck of a highway crossing at an angle, and the
		# ramp thirty degrees off the heading that shook the ship (ADR 0072).
		if lane.axis.dot(along) < cone:
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
	for sign in _signs:
		sign.rebuild()
