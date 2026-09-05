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
## Every route on the map, in the order they were added. A route is a spine, a
## building over both its carriageways, and the height it rides at. Roads cross;
## nothing here is "the" road (ADR 0085).
var _routes: Array[RoadPath] = []
var _route_buildings: Array[RoadStructure] = []
var _route_bases: Array[Vector3] = []
var _route_pairs: Array = []
## The buildings. **One structure per pair of decks** — the mainline pair share a
## single building straddling the spine, and every ramp is a building of its own with
## one lane in it (ADR 0078). A deck is the lane you fly in; this is what it is inside.
var _structures: Array[RoadStructure] = []
## Every exit sign on the network. Mounted on the mainline's building ahead of each
## off-ramp, naming where that exit goes.
var _signs: Array[ExitSign] = []
## The permission surface across each exit's mouth. Blue if you may take it, red if
## you may not — the same split ADR 0060 makes at a portal, on the other end of the
## ramp (ADR 0084).
var _gates: Array[RampGate] = []
## The line the whole highway is laid on, in the map's frame. Not a road itself — the
## mainlines are this lifted to each deck, and the ramps branch off it.
var _spine: RoadPath = RoadPath.new()
## A short, stable node-name prefix for a route, so two roads' carriageways and ramps
## do not collide in the tree. "A-377B" becomes "A377B".
static func _tag(route_name: String) -> String:
	return route_name.replace("-", "").replace(" ", "")


## Wipe and rebuild the whole network. Called on every layout, because the systems
## move when the diameter or a leg length does, and the legs change shape when the
## curvature does.
func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_decks.clear()
	_structures.clear()
	_signs.clear()
	_gates.clear()
	_routes.clear()
	_route_buildings.clear()
	_route_bases.clear()
	_route_pairs.clear()


## Lay one highway: a spine, a building over both carriageways, and a pair of ramps at
## every system on it that has traffic for them.
##
## Called once per route. There is no "the" road any more — the map carries a network,
## and the first road on it is not special (ADR 0085). Everything that used to reach
## for a single spine or a single building is handed this route's instead.
##
## `height` is how high above the combat plane this road rides. A road through the
## middle of a system is in the way of everything that happens there; up near the
## ceiling it is scenery you fly under, and an obstacle if a fight goes that way. Two
## roads crossing need two heights.
func add_route(spine: PackedVector3Array, centres: Array[Vector3],
		names: PackedStringArray, route_name: String, height: float) -> void:
	if centres.size() < 2 or spine.size() < 2:
		return
	var route := RoadPath.new()
	route.set_points(spine)
	var across := Tuning.num("exploration/deck_separation") * 0.5
	var base := Vector3.UP * height

	# ONE building for both carriageways. It straddles the spine, a carriageway either
	# side of the median, and it is the reason the deck and the structure had to be
	# split: a deck cannot own a building that also belongs to the deck coming the
	# other way. Its interior spans the two lanes and the gap between them, so the
	# outermost lane edge is exactly its inside face.
	var pair := Vector2(across * 2.0 + Tuning.num("exploration/lane_width"),
		Tuning.num("exploration/lane_height")) * 0.5
	var tag := _tag(route_name)
	var built := _make_structure(tag + "Structure", false, true)
	built.follow(_laid_on(route, base, 1.0, 0.0), pair, pair, false, false)
	_routes.append(route)
	_route_buildings.append(built)
	_route_bases.append(base)

	var carriageways: Array[RoadDeck] = []
	for runs_forward in [true, false]:
		# The reversed carriageway runs the other way, sits on the other side of the
		# spine, and puts its ramps on the other side of the planet — so a divided
		# highway reads as two roads rather than as one road drawn twice. `sense` is
		# which way along the spine this carriageway's traffic moves, and every
		# placement below is written in it, including which side of the spine "right"
		# is.
		var sense := 1.0 if runs_forward else -1.0
		var mainline := _make_deck(
			tag + "Mainline" + ("Forward" if runs_forward else "Reverse"),
			runs_forward, false, false)
		mainline.route_name = route_name
		mainline.deck_name = "%s %s bound" % [route_name,
			names[names.size() - 1] if sense > 0.0 else names[0]]
		mainline.follow(_laid_on(route, base, sense, across), "", "")
		carriageways.append(mainline)

		# Which neighbour a ramp serves depends on which way this carriageway runs. On
		# the eastbound one B's on-ramp leads to C and its off-ramp comes from A; on
		# the westbound one both are the other way round.
		var onward := 1 if sense > 0.0 else -1
		for i in centres.size():
			var ahead := i + onward
			var behind := i - onward
			_build_ramps(route, built, base, centres[i], names[i], sense, across,
				runs_forward, route_name, mainline,
				names[ahead] if ahead >= 0 and ahead < names.size() else "",
				names[behind] if behind >= 0 and behind < names.size() else "")
	_route_pairs.append(carriageways)


## Where routes cross, join them.
##
## Every carriageway gets its RIGHT-HAND TURN onto the road it crosses: swing out
## through the wall and climb or drop to it. Four carriageways at a crossing, four
## ramps, and the interchange is symmetric.
##
## **The left turns are not built**, and that is a real gap rather than an omission of
## taste. Turning onto the carriageway coming the other way is better than ninety
## degrees of rotation, and `RoadPath.ramp` is a cubic told two tangents: asked to hold
## that much it puts all the turning in one place — measured at 72 deg/s against a
## ship that turns at 34, and 132 for two chained cubics through a crest. What that
## ramp needs is a curve built to a bounded RADIUS, which `RoadPath` cannot make yet.
## It must not be "fixed" by relaxing ADR 0070's turn check.
func link_routes() -> void:
	var across := Tuning.num("exploration/deck_separation") * 0.5
	for a in _routes.size():
		for b in _routes.size():
			if a == b:
				continue
			_link(a, b, across)


func _link(from_route: int, to_route: int, across: float) -> void:
	var here: RoadPath = _routes[from_route]
	var there: RoadPath = _routes[to_route]
	# WHERE THEY CROSS, in plan. Both roads are near-level, so the nearest approach of
	# one to the other along its own length is the crossing — and it is measured
	# rather than authored, because a weaving leg moves it.
	var meeting := -1.0
	var nearest := INF
	for i in CROSSING_STEPS + 1:
		var along := here.length() * float(i) / float(CROSSING_STEPS)
		var flat := here.point_at(along)
		flat.y = 0.0
		var other := there.closest(Vector3(flat.x, there.points[0].y, flat.z))
		var gap: float = (Vector3(flat.x, 0.0, flat.z)
			- Vector3((other[1] as Vector3).x, 0.0, (other[1] as Vector3).z)).length()
		if gap < nearest:
			nearest = gap
			meeting = along
	if meeting < 0.0 or nearest > Tuning.num("exploration/system_diameter") * 0.5:
		return
	# EVERY CARRIAGEWAY GETS ITS OWN RIGHT-HAND TURN, and "right" is asked of that
	# carriageway rather than of the route: the two run opposite ways, so the road
	# that is a right turn from one is a left turn from the other and they cannot
	# share an answer.
	var at: Vector3 = here.point_at(meeting)
	for leaving: RoadDeck in _route_pairs[from_route]:
		var leaving_travel := leaving.path().tangent_at(
			leaving.path().closest(at)[0])
		for onto: RoadDeck in _route_pairs[to_route]:
			var turn := leaving_travel.cross(onto.path().tangent_at(
				onto.path().closest(at)[0])).dot(Vector3.UP)
			if turn >= 0.0:
				continue
			_build_interchange(from_route, to_route, leaving, onto, meeting,
					across)


## A route, raised to its road's height and moved to one carriageway's side of it, and
## reversed for the carriageway that runs the other way.
##
## The offset is LATERAL — along the spine's rightward normal at each point, signed by
## which way this carriageway travels. It used to be vertical, chosen so that both came
## out the same length on a bend; a divided highway does not have that property, and
## the inner one is genuinely shorter through a curve. What that costs is a floor on
## the geometry: a bend tighter than the deck separation folds the inner lane through
## itself, so the gate checks the spine's minimum curve radius against it (ADR 0077).
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
func _build_ramps(route: RoadPath, built: RoadStructure, base: Vector3,
		centre: Vector3, place: String, sense: float, across: float,
		runs_forward: bool, route_name: String, mainline: RoadDeck, ahead: String,
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
	var here: float = route.closest(centre)[0]
	var letter := place.substr(place.length() - 1, 1)
	var suffix := _tag(route_name) + "Ramp%s" + letter \
		+ ("Forward" if runs_forward else "Reverse")

	if not behind.is_empty():
		var leaves := _at(route, here - sense * run, base, sense, across)
		var off_mouth := _mouth(route, here - sense * gap, exit_out, exit_down, sense,
			base, across)
		var off_ramp := _make_deck(suffix % "Off", runs_forward, false, true)
		off_ramp.route_name = route_name
		off_ramp.deck_name = "%s off-ramp" % place
		var off_curve := RoadPath.ramp(leaves[0], leaves[1], off_mouth[0],
			off_mouth[1], tightness, RAMP_SEGMENTS)
		off_ramp.follow(off_curve, place, behind)
		# The mainline's wall has to open where this ramp leaves through it — and a
		# sign has to hang far enough back that the choice arrives before the exit
		# does. Reading it in time is a piloting act, and missing it costs one hop off
		# and back on, which is the price ADR 0057 already sets (ADR 0083).
		var off_hole := _open_for(built, off_ramp.path(), true)
		# A ramp is a building with one lane in it and no median, narrowing to its
		# portal at the end it meets the planet — and it STARTS at the mainline's wall.
		# Built along its whole curve it stood inside the highway, roofing over the
		# opening it comes out of and putting a second roadway across the lane (ADR
		# 0088). The lane is untouched: only the building is cut.
		_make_structure("Structure" + (suffix % "Off"), true, false).follow(
			_shell_of(off_ramp.path(), off_hole, true),
			_lane_section(), _mouth_section(), false, true)
		_sign_for(built, off_ramp, place, mainline, off_hole)
		_gate_for(built, off_ramp, off_hole)

	if not ahead.is_empty():
		var on_mouth := _mouth(route, here + sense * gap, entry_out, entry_down, sense,
			base, across)
		var rejoins := _at(route, here + sense * run, base, sense, across)
		var on_ramp := _make_deck(suffix % "On", runs_forward, true, false)
		on_ramp.route_name = route_name
		on_ramp.deck_name = "%s to %s on-ramp" % [place, ahead]
		# Built FORWARDS, from the mouth up to the merge. It used to be built backwards
		# and reversed, because a quadratic could only be told one tangent and the
		# merge was the end that had to be right; a cubic is told both, so the trick is
		# gone and the mouth is as deliberate as the merge.
		var on_curve := RoadPath.ramp(on_mouth[0], on_mouth[1], rejoins[0],
			rejoins[1], tightness, RAMP_SEGMENTS)
		on_ramp.follow(on_curve, ahead, place)
		# …and its roadway has to open where this one comes up through it.
		var on_hole := _open_for(built, on_ramp.path(), false)
		# The on-ramp's own building STOPS at that hole, for the same reason the
		# off-ramp's starts at one: past it the ramp is inside the highway, and a tube
		# drawn there plugs the floor it is supposed to be coming up through (ADR 0088).
		_make_structure("Structure" + (suffix % "On"), true, false).follow(
			_shell_of(on_ramp.path(), on_hole, false),
			_lane_section(), _mouth_section(), true, false)


## A point on the mainline and the direction traffic runs there, as `[point, tangent]`.
## On this deck's own side of the spine, so a ramp leaves the road rather than the
## line the road was laid on.
func _at(route: RoadPath, along: float, base: Vector3, sense: float,
		across: float) -> Array:
	var clamped := clampf(along, 0.0, route.length())
	var travel := route.tangent_at(clamped) * sense
	return [route.point_at(clamped) + base + _side_of(travel) * across, travel]


## A ramp mouth beside the planet, and the direction the road runs past it.
##
## The side is taken from the spine's own tangent here rather than from the map's
## bearing: on a weaving leg those differ, and a mouth placed on the bearing would
## drift off the side of the interchange it belongs to.
## `out` is measured from the DECK, not from the spine, so the shape of a ramp does not
## change when the two carriageways are moved apart.
func _mouth(route: RoadPath, along: float, out: float, down: float, sense: float,
		base: Vector3, across: float) -> Array:
	var clamped := clampf(along, 0.0, route.length())
	var travel := route.tangent_at(clamped) * sense
	return [route.point_at(clamped) + base + _side_of(travel) * (across + out)
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
## Returns the crossing it made, as `crossing` reports it, so the caller can cut the
## ramp's own building at the same place rather than measuring it twice.
func _open_for(built: RoadStructure, ramp: RoadPath, leaving: bool,
		measured_entry: bool = false) -> Array:
	if built == null or ramp.length() <= 0.0:
		return []
	var found := crossing(built, ramp, leaving)
	if found.is_empty():
		return []
	var through: int = found[1] if leaving or measured_entry \
		else int(RoadStructure.Face.BELOW)
	built.pierce(found[0], through as RoadStructure.Face)
	return [found[0], through, found[2]]


## A ramp's own building: its curve, cut where it enters the building of the road it
## serves.
##
## **The lane runs the whole way and the shell does not** (ADR 0088). Inside the
## highway the ramp is not a tube — it is a hole in the floor or a gap in the wall,
## and the mainline's own building is what surrounds you there. Drawn as a tube it
## roofed over its own opening from below and hung a second roadway across the lane
## from above, which is exactly what the human reported.
func _shell_of(ramp: RoadPath, hole: Array, leaving: bool) -> PackedVector3Array:
	if hole.is_empty():
		return ramp.points
	var at: float = hole[2]
	var line := ramp.section(at, ramp.length()) if leaving else ramp.section(0.0, at)
	# A cut that leaves nothing is not a cut. Better a ramp that reaches too far than
	# one with no building at all — the gate checks the rule, not this fallback.
	return ramp.points if line.size() < 2 else line


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
		var walked := ramp.length() * (t if leaving else 1.0 - t)
		var point := ramp.point_at(walked)
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
		return [here, face, walked]
	return []


## One RIGHT-HAND TURN from one carriageway onto another road's.
##
## Swing out through the wall and climb or drop to it. The left turn — over the top
## and down onto the carriageway coming the other way — is more than ninety degrees of
## rotation and needs a curve built to a bounded radius, which `RoadPath` cannot make
## yet (ADR 0085). Which face the ramp actually uses is measured, and the gate holds
## the rule (ADR 0080).
func _build_interchange(from_route: int, to_route: int, leaving: RoadDeck,
		onto: RoadDeck, meeting: float, across: float) -> void:
	var route: RoadPath = _routes[from_route]
	var built: RoadStructure = _route_buildings[from_route]
	var base: Vector3 = _route_bases[from_route]
	var run := Tuning.num("exploration/interchange_run_length")
	var sense := 1.0 if leaving.runs_forward else -1.0
	var leaves := _at(route, meeting - sense * run, base, sense, across)
	# WHERE IT LANDS, and it has to land clear of the system's own on-ramp. The roads
	# cross AT a system, so the merge from that system's planet is already using this
	# stretch — landed on top of it, the union handed a ship coming up the on-ramp an
	# interchange ramp that was about to end, which is the stutter ADR 0076 is about.
	# One ramp run past that merge is the separation, taken from the ramp rather than
	# picked (ADR 0088).
	var lands: float = onto.path().closest(route.point_at(meeting))[0] \
		+ Tuning.num("exploration/ramp_run_length") + run * 0.45
	lands = clampf(lands, 0.0, onto.length())
	var ramp := _make_deck("%sTo%s%s" % [_tag(leaving.route_name),
		_tag(onto.route_name), "Forward" if leaving.runs_forward else "Reverse"],
		leaving.runs_forward, false, false, true)
	ramp.route_name = leaving.route_name
	ramp.deck_name = "%s to %s" % [leaving.route_name, onto.route_name]
	var tightness := Tuning.num("exploration/interchange_curve_tightness")
	var arrives: Vector3 = onto.path().point_at(lands)
	var joins: Vector3 = onto.path().tangent_at(lands)
	# OUT FIRST, THEN ACROSS. An interchange ramp goes to a road at a different height,
	# and a curve aimed straight at it leaves through the FLOOR or the roof of the one
	# it is on — measured, on the ramp down from the upper road. The exit-face rule
	# says a ramp leaves through a wall (ADR 0080), and the human's own statement of
	# it is "to the right if the highway is below": you swing out of the building
	# first, and you climb or drop once you are outside it.
	#
	# So it is two sweeps through a point out to the side of the road. The first is a
	# lane change and clears the wall; the second is the turn and the height, entirely
	# outside the building.
	#
	# THE SWING POINT IS MEASURED OFF THE ROAD, not off the leaving tangent. Held on the
	# tangent it was a straight line beside a road that weaves and undulates, so over
	# two kilometres it drifted out of the building's section vertically and left
	# through the FLOOR — which the exit-face gate caught, and which also left the
	# ramp's shell standing inside the highway. Asked of the road at that point, the
	# lane change is parallel to the road for its whole length and the only face it can
	# reach is the side wall (ADR 0088).
	var swung := _at(route, meeting - sense * run * 0.55, base, sense, across)
	var via: Vector3 = (swung[0] as Vector3) + _side_of(swung[1] as Vector3) \
		* Tuning.num("exploration/interchange_side_offset")
	# A SWEEP, not a ramp. The two differ in how the control arms are measured, and an
	# interchange is the case `ramp` measures badly: half of a fifty-five degree turn
	# is across the leaving direction, so the along-road projection under-measures it
	# and crams the whole turn into the middle (ADR 0085).
	var curve := RoadPath.sweep(leaves[0], leaves[1], via, swung[1], tightness,
		RAMP_SEGMENTS)
	var onward := RoadPath.sweep(via, swung[1], arrives, joins, tightness,
		RAMP_SEGMENTS * 2)
	for i in range(1, onward.size()):
		curve.append(onward[i])
	ramp.follow(curve, "", "")
	# An interchange is an exit like any other: it opens the wall it leaves through,
	# it hangs a sign naming where it goes, and it carries a gate that can refuse.
	var hole := _open_for(built, ramp.path(), true)
	# AND AN ENTRANCE AT THE FAR END. It arrives inside the OTHER road's building, so
	# that one needs an opening too. The face is the measured one rather than the
	# authored BELOW a planet on-ramp gets: a ramp climbing to a road above enters
	# through its floor and one dropping to a road below enters through its roof, and
	# both are entries (ADR 0088).
	var landing := _open_for(_route_buildings[to_route], ramp.path(), false, true)
	# Cut at BOTH ends: inside either building the ramp is an opening rather than a
	# tube, and what surrounds you there is the mainline's own building.
	var shell := ramp.path().section(
		float(hole[2]) if not hole.is_empty() else 0.0,
		float(landing[2]) if not landing.is_empty() else ramp.length())
	_make_structure("Structure" + ramp.name, true, false).follow(
		curve if shell.size() < 2 else shell,
		_lane_section(), _lane_section(), false, false)
	_sign_for(built, ramp, onto.route_name, leaving, hole)
	_gate_for(built, ramp, hole)


## A sign on the mainline, ahead of an exit, naming where it goes.
##
## Placed from the opening the ramp actually makes, not from the ramp's own start: what
## the player has to see coming is the hole in the wall, and the sign belongs a lead
## distance back from that, on the same side, tucked just inside the section.
func _sign_for(built: RoadStructure, ramp: RoadDeck, place: String,
		mainline: RoadDeck, opening: Array) -> void:
	if built == null or opening.is_empty():
		return
	var at: float = opening[0]
	var face: int = opening[1]
	var lead := Tuning.num("exploration/exit_sign_lead_metres")
	var along := clampf(at - lead, 0.0, built.length())
	var line := built.path()
	var frame := CruiseLane.frame_for(line.tangent_at(along))
	var extents := built.extents_at(along)
	var side := 1.0 if face == int(RoadStructure.Face.LEFT) else -1.0
	var sign := ExitSign.new()
	sign.name = "Sign" + ramp.name
	sign.ramp = ramp
	# WHICH CARRIAGEWAY THIS SIGN IS FOR. Authored where the sign is hung rather than
	# worked out from geometry later: a sign is mounted on one road's wall, and "is
	# this exit mine" is that fact and nothing else (ADR 0088).
	sign.from_deck = mainline
	sign.label_text = "EXIT  %s" % place
	# Just inside the wall the exit is in, and up out of the traffic on the roadway.
	sign.position = line.point_at(along) \
		- frame[0] * side * extents.x * Tuning.num("exploration/exit_sign_inset") \
		+ frame[1] * extents.y * Tuning.num("exploration/exit_sign_rise")
	add_child(sign)
	_signs.append(sign)


## The permission surface across an exit's mouth, in the opening the ramp makes.
##
## Mounted on the mainline's building rather than on the ramp, because what it gates is
## the decision to LEAVE — it has to be read from the road you are on, before you are
## committed, which is the same clause ADR 0012 asks of everything else that offers
## you something.
func _gate_for(built: RoadStructure, ramp: RoadDeck, opening: Array) -> void:
	if built == null or opening.is_empty():
		return
	var at: float = opening[0]
	var face: int = opening[1]
	var line := built.path()
	var frame := CruiseLane.frame_for(line.tangent_at(at))
	var extents := built.extents_at(at)
	var out := frame[0]
	var reach := extents.x
	match face:
		int(RoadStructure.Face.LEFT):
			out = -frame[0]
		int(RoadStructure.Face.ABOVE):
			out = frame[1]
			reach = extents.y
		int(RoadStructure.Face.BELOW):
			out = -frame[1]
			reach = extents.y
	var gate := RampGate.new()
	gate.name = "Gate" + ramp.name
	gate.deck = ramp
	add_child(gate)
	gate.position = line.point_at(at) + out * reach
	# Facing out through the opening, so it fills the ring rather than edging it.
	gate.look_at(gate.position + out, Vector3.UP if absf(out.dot(Vector3.UP)) < 0.99
		else Vector3.BACK)
	_gates.append(gate)


## Every exit's permission surface. For the scene and the gate.
func gates() -> Array[RampGate]:
	return _gates


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


## Every building on the network: one per route's pair of carriageways, one per ramp.
func structures() -> Array[RoadStructure]:
	return _structures


## The building over one route's carriageways, by the route's name. Every ramp on that
## route goes through THIS building and no other, which is the thing a check on the
## exit-face rule has to get right — measured against the wrong road's walls, a ramp
## that comes up perfectly through its own floor reads as going through a wall.
func building_for(route_name: String) -> RoadStructure:
	for built in _structures:
		if built.structure_name == _tag(route_name) + "Structure":
			return built
	return null


## Every route's spine. For the map and for tests; nothing steers by them.
func routes() -> Array[RoadPath]:
	return _routes


## The first route's spine. For the map and for tests; nothing steers by it.
func spine() -> RoadPath:
	return _routes[0] if not _routes.is_empty() else _spine


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
		if deck.length() <= 0.0 or deck == exclude or not deck.passable:
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


## Which shell holds this hull, or null when none does (ADR 0087).
##
## Resolved the same way the lane union is (ADR 0063): every building is asked how it
## sees the hull, and one of them governs.
##
## **The one with the MOST room governs** — the building the hull is deepest inside of.
## Buildings overlap where roads cross, and picking the tightest instead pinned a ship
## flying down the middle of the mainline against the wall of an interchange ramp
## passing through it, which is being held by a building you are not in. Deepest-inside
## is also the right answer outside: there `room` is negative, so the largest is the
## nearest wall, which is the one the hull is about to be through.
##
## An INSIDE answer always beats an OUTSIDE one. A ship can be inside one building and
## within a wall's thickness of another, and the shell it is in is the one whose
## surfaces it may not leave.
func barrier(point: Vector3, clearance: Vector2) -> HullBarrier:
	var best: HullBarrier = null
	for built in _structures:
		var held := built.barrier(point, clearance)
		if held == null:
			continue
		if best == null or (held.inside and not best.inside) \
				or (held.inside == best.inside and held.room() > best.room()):
			best = held
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
	for gate in _gates:
		gate.rebuild()
