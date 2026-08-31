class_name SystemMap
extends Node3D
## The test map: systems in a line, joined by corridors
## (`docs/EXPLORATION_POC_IMPLEMENTATION.md`).
##
##     [ A ]────local────[ B ]────────────trunk────────────[ C ]
##
## **Step 5 builds A, B and the local leg.** Step 8 appends the trunk and C, which
## is one entry in `LEG_KEYS` — the layout walks the list, so adding a system is
## adding a leg rather than editing a topology.
##
## This node owns three things nothing else should: the **layout** (where the
## systems are, which way each aperture faces, where each corridor attaches), the
## **boundary** composed from every piece of it, and the **hot reload** of both. The
## discs and links deliberately do not subscribe to `Tuning.reloaded` themselves:
## their geometry depends on a layout they do not own, and rebuilding in signal
## order would have them do it against stale positions.
##
## Legs are measured **portal to portal** (an amendment to the POC doc), so centre
## to centre is the leg plus one system radius at each end. That is why the system
## diameter being a slider moves the systems apart as well as making them bigger.

## The legs, in order. One key per leg; systems are legs + 1, and the layout walks
## the list — so adding a system is adding a leg rather than editing a topology.
const LEG_KEYS: PackedStringArray = ["exploration/local_leg_length",
	"exploration/trunk_leg_length"]
## Placeholder identity. The POC doc calls them A, B and C, and naming them anything
## more is content this POC does not test.
const NAMES: PackedStringArray = ["SYSTEM A", "SYSTEM B", "SYSTEM C"]
const LETTERS: PackedStringArray = ["A", "B", "C"]
## ROADS HAVE NAMES. "Stay on highway A-377B" is a sentence a player can act on;
## "stay on this road" is not, and while berthed the routing readout is the only thing
## telling them what happens if they do nothing (ADR 0083).
##
## Authored here rather than derived from the systems they connect, because a real
## route number outlives the places on it — a road keeps its name when a new system is
## built on it, and deriving one would rename the whole highway.
const TRUNK_ROUTE := "A-377B"
const CROSSING_ROUTE := "K-112"

## Relayed from whichever system's envelope fired, so the dock screen can say where
## it is without the scene tracking which envelope belongs to which planet.
signal arrived(place: String)
signal departed()

var _discs: Array[SystemDisc] = []
var _planets: Array[Planet] = []
var _approaches: Array[ApproachEnvelope] = []
var _links: Array[SystemLink] = []
## The road: two mainlines running the length of the map, and a pair of ramps at each
## system. It spans the whole map rather than one leg, because the highway runs
## through the systems rather than stopping at them (ADR 0065).
var _road: RoadNetwork
## Every piece of playable space, united. Systems and corridors are regions in one
## list rather than two systems to be checked in turn (ADR 0062).
var _field: BoundaryField = BoundaryField.new()
## What is out there past the edge. Background-layer only: nothing in it is queryable
## and nothing in it collides (see `DeepField` and CLAUDE.md's LOD/collision rule).
var _deep: DeepField
## The line the whole highway is laid on, through every system and along every leg.
## Kept because the road, the corridors and the deep field all have to agree about
## where the route goes, and the way to guarantee that is one polyline.
var _spine: PackedVector3Array = PackedVector3Array()

## Seconds the player has spent outside on this excursion. Resets on return, so two
## short dips do not add up into damage the player did not see coming.
var _seconds_outside: float = 0.0
## Live, for the HUD. The player is told the timer is running before it costs them.
var _warning: float = 0.0
## What the boundary and the approach sequences together want the ship's speed
## ceiling multiplied by this frame — the tightest of them, composed here so two
## systems writing the same field cannot silently fight over it.
var _speed_scale: float = 1.0
## How much of the ship's heading was outbound, 0 to 1. Kept because the HUD has to
## report the same number the clamp used.
var _outbound: float = 0.0
## The deck the player is riding, or null. The cruise drive is not a mode the ship
## carries — it is a place the ship is in (ADR 0057), so the map knows where it is
## and the ship only ever receives a sample of the road under it.
var _riding: RoadDeck = null
## The berth on the roadway. One per map rather than one per road: it is a thing the
## player does, not a thing a stretch of road has (ADR 0082).
var _berth: RoadBerth = null
## Last frame's position, for the SWEPT portal test. At 96.7 m/s a ship covers 1.6 m
## in a frame, and a portal tested against a position rather than a segment is one
## that intermittently does not exist.
var _previous: Vector3 = Vector3.ZERO
var _has_previous: bool = false


func _ready() -> void:
	_build()
	relayout()
	Tuning.reloaded.connect(relayout)


func _build() -> void:
	var count := LEG_KEYS.size() + 1
	_berth = RoadBerth.new()
	_berth.name = "Berth"
	add_child(_berth)
	for i in count:
		var letter := LETTERS[i]
		var disc := SystemDisc.new()
		disc.name = "Disc" + letter
		add_child(disc)
		_discs.append(disc)

		var planet := Planet.new()
		planet.name = "Planet" + letter
		add_child(planet)
		_planets.append(planet)

		var approach := ApproachEnvelope.new()
		approach.name = "Approach" + letter
		approach.host = planet
		add_child(approach)
		_approaches.append(approach)
		var place := NAMES[i]
		approach.arrived.connect(func() -> void: arrived.emit(place))
		approach.departed.connect(func() -> void: departed.emit())

	_road = RoadNetwork.new()
	_road.name = "Road"
	add_child(_road)

	_deep = DeepField.new()
	_deep.name = "DeepField"
	add_child(_deep)

	for i in LEG_KEYS.size():
		var link := SystemLink.new()
		link.name = "Link%s%s" % [LETTERS[i], LETTERS[i + 1]]
		link.link_name = "%s to %s" % [NAMES[i], NAMES[i + 1]]
		link.from_name = NAMES[i]
		link.to_name = NAMES[i + 1]
		add_child(link)
		_links.append(link)


## Place everything, and recompose the boundary from what was placed.
##
## Called on every tuning reload, because the diameter, the leg lengths and the
## aperture bearing are all sliders and every one of them moves the map.
func relayout() -> void:
	var radius := Tuning.num("exploration/system_diameter") * 0.5
	var bearing := Tuning.num("exploration/aperture_bearing_deg")
	var step := SystemDisc.bearing_to_direction(bearing)
	var curve_deg := Tuning.num("exploration/road_curve_deg")
	var curve_period := Tuning.num("exploration/road_curve_period")
	var rise_deg := Tuning.num("exploration/road_rise_deg")
	var rise_period := Tuning.num("exploration/road_rise_period")
	var here := Vector3.ZERO
	# Each leg's centre-line, mouth to mouth. Built during the layout because the next
	# system sits at the end of the leg that reaches it.
	var legs: Array[PackedVector3Array] = []

	for i in _discs.size():
		var disc := _discs[i]
		disc.position = here
		disc.system_name = NAMES[i]
		# Apertures face the legs, in order: back down the leg you arrived by, then
		# on down the next one. The last system has only the one, which is what makes
		# a line a line rather than a ring with a missing piece.
		#
		# Still ONE bearing for every aperture, even though the legs now weave: the
		# weave leaves and arrives exactly on the bearing (`RoadPath.weave` tapers its
		# amplitude to zero at both ends), so a curving leg does not move a mouth.
		var bearings: Array[float] = []
		if i > 0:
			bearings.append(bearing + 180.0)
		if i < _discs.size() - 1:
			bearings.append(bearing)
		disc.bearings = bearings
		disc.rebuild()

		_planets[i].base = here
		_planets[i].rebuild()
		_approaches[i].position = _planets[i].position
		_approaches[i].rebuild()

		if i < _links.size():
			var leg := Tuning.num(LEG_KEYS[i])
			legs.append(RoadPath.weave(here + step * radius, step, leg,
				curve_deg, curve_period, rise_deg, rise_period))
			here += step * (leg + radius * 2.0)

	for i in _links.size():
		# The CORRIDOR is mouth to mouth: it is the bounded space between two systems,
		# and it is what you fly when you decline the road. It is handed the leg's own
		# centre-line rather than two endpoints, so the corridor and the highway inside
		# it are the same curve and cannot drift apart.
		_links[i].follow(legs[i])

	# The SPINE: behind the first system, through every centre, along every leg, and
	# out past the last. The road is laid on this and the deep field is scattered
	# around it, so one polyline is the only place the route is written down.
	_spine = PackedVector3Array()
	_spine.append(_discs[0].position - step * radius)
	for i in _discs.size():
		_spine.append(_discs[i].position)
		if i < legs.size():
			for point: Vector3 in legs[i]:
				_spine.append(point)
	_spine.append(_discs[_discs.size() - 1].position + step * radius)

	# The ROAD spans the whole map in one piece, through every system, and is built
	# once rather than per leg — a highway that stops at each system is the thing
	# ADR 0065 exists to forbid.
	var centres: Array[Vector3] = []
	for disc in _discs:
		centres.append(disc.position)
	# A SECOND HIGHWAY, crossing the first over system B. It is here so the exit-face
	# rules can be flown rather than only read (ADR 0081): turning right onto a road
	# going right, and going over the top to reach one coming the other way, are the
	# two cases, and both need a road to turn onto.
	#
	# It rides ABOVE the main road, stays inside the system's own disc, and simply
	# ends at both ends — run off it and you drop into normal flight, exactly as at
	# the edge of the map. Straight, because its job is to be crossed, not driven.
	var crossing := PackedVector3Array()
	if _discs.size() > 1:
		var cross_step := SystemDisc.bearing_to_direction(
			bearing + Tuning.num("exploration/crossing_bearing_deg"))
		var reach := Tuning.num("exploration/crossing_road_length") * 0.5
		var meets := _discs[1].position \
			+ Vector3.UP * Tuning.num("exploration/crossing_road_height")
		crossing.append(meets - cross_step * reach)
		crossing.append(meets)
		crossing.append(meets + cross_step * reach)
	_road.rebuild(_spine, centres, NAMES, TRUNK_ROUTE, crossing, CROSSING_ROUTE)

	_field.regions.clear()
	for disc in _discs:
		_field.regions.append(disc.region())
	for link in _links:
		_field.regions.append(link.region())
	_field.warning_band = Tuning.num("exploration/bounds_warning_band")
	_field.stop_distance = Tuning.num("exploration/bounds_stop_distance")

	# LAST, and it needs both of the things above it: the deep field is scattered
	# around the spine and rejected wherever the boundary says the point is still
	# playable space, so it cannot exist until the field is composed.
	_deep.rebuild(_spine, _field)


## Run the whole map against the ship for this frame.
##
## The order matters and is the whole treatment: paint first so the player is
## looking at red before anything else happens, work out the strain second so the
## ship slows rather than turns, and only then start counting toward damage.
func observe(ship: Mothership, delta: float) -> void:
	_speed_scale = 1.0
	_outbound = 0.0
	if ship == null or not is_instance_valid(ship) or delta <= 0.0:
		return
	var here := to_local(ship.global_position)

	_warning = _field.warning(here)
	for disc in _discs:
		disc.paint(_warning)
	for link in _links:
		link.paint(_warning)

	var heading := _heading_of(ship)
	_outbound = BoundaryField.outbound_fraction(heading, _field.outward(here))
	_speed_scale = _field.speed_ceiling_scale(here, heading)

	# The approach sequences constrain the same ceiling. Composed here and assigned
	# once by the scene, so the tightest wins rather than whichever ran last.
	for approach in _approaches:
		approach.observe(ship, delta)
		_speed_scale = minf(_speed_scale, approach.speed_scale())

	_ride_the_road(ship, here)
	# AFTER the road, because a berth binds to the deck the ship is on and the road is
	# what decides which one that is. Reading the key here rather than inside the
	# berth keeps `RoadBerth` drivable by the gate, which has no input device.
	_berth.observe(ship, _riding, Input.is_action_just_pressed("dock"), delta)
	_aim_signs(ship, Input.is_action_just_pressed("fire_primary"))
	for gate in _road.gates():
		gate.repaint(delta)
	_road.set_active(_riding)
	# The starfield rides with the player so it never gets nearer, the way a sky does.
	# Everything else in the deep field stays where it was put, which is what makes it
	# parallax against the ship instead of moving with it.
	_deep.follow(here)
	_previous = here
	_has_previous = true

	if _field.overshoot(here) <= 0.0:
		_seconds_outside = 0.0
		return
	_seconds_outside += delta
	var rate := BoundaryField.damage_per_second(_seconds_outside,
		Tuning.num("exploration/bounds_grace_seconds"),
		Tuning.num("exploration/bounds_damage_ramp_seconds"),
		Tuning.num("exploration/bounds_damage_per_second"))
	if rate > 0.0:
		ship.take_hit(rate * delta)


## Getting on and off the road.
##
## Entry is **on contact and instant** (ADR 0057): crossing a start portal in its own
## direction of travel puts the cruise drive on, and there is no alignment, no
## sequence and no prompt between those two things. Leaving is the far portal, or
## turning round and going back out the way you came in.
##
## Every portal's colour is set from the hull the player is flying *this frame*, so
## cycling the debug roster recolours the map (ADR 0060). A fighter has no cruise
## drive, sees red everywhere, and is refused — which is one property wearing a
## colour rather than a second rule about who may use a portal.
func _ride_the_road(ship: Mothership, here: Vector3) -> void:
	var allowed := ship.has_cruise_drive()
	# A BERTHED SHIP DOES NOT CHANGE ROADS. The berth is bound to one carriageway and
	# follows its centre-line; letting the union hand it to a ramp on proximity would
	# be the berth choosing a route, which is the one thing it must never do (ADR
	# 0082). It still gets a lane sample, because the HUD and the speed ceiling read
	# it, and it still comes off the road when the drive or the road runs out.
	if ship.is_berthed() and _riding != null:
		if not allowed:
			_riding = null
			ship.cruise = null
			ship.leave_road()
			ship.reset_reticle()
			return
		# The one thing that DOES change the road under a berthed ship is the player
		# taking an exit, and that switch is the berth's (ADR 0083).
		if _berth.deck() != null:
			_riding = _berth.deck()
		ship.cruise = _riding.sample(here, ship.lane_clearance())
		_previous = here
		return
	# The hull's own half-section. The lane is measured against the ship rather than
	# against a point, and every sample below has to be taken with the SAME clearance
	# or the union would compare a hull-measured depth against a point-measured one.
	var clearance := ship.lane_clearance()
	_road.set_permitted(allowed)
	if not _has_previous:
		return

	if _riding != null:
		# Losing the drive mid-road drops you where you are, at hull speed. That is
		# the honest reading of the drive belonging to the hull, and it is the only
		# way the roster can answer "what is the road worth" for a fighter.
		if not allowed or _left_through_a_portal(here):
			_riding = null
			ship.cruise = null
			ship.leave_road()
			ship.reset_reticle()
			return
		# Merging and diverging, with no junction logic in it. Every deck going the
		# player's way is asked how far outside it they are; steering toward a ramp
		# makes the ramp the nearer answer and it takes over, and running to the end
		# of a ramp hands off to whatever else contains the ship. The handover happens
		# because the geometry says so, not because a rule fired (ADR 0063's rule,
		# applied to lanes instead of regions).
		var lane := _riding.sample(here, clearance)
		# Candidates are limited to decks the ship could actually be steered onto, so
		# a handover is a merge rather than a snap (ADR 0072).
		var alternative := _road.governing(here, ship.road_axis(), _riding,
			clearance)
		if lane.metres_remaining <= 0.001:
			# Off the end of this deck. A ramp ends on the mainline and hands over; a
			# mainline ends at the edge of the map, where there is nothing to hand to
			# and the road has simply run out.
			if alternative == null or alternative.sample(here, clearance).is_outside():
				_riding = null
				ship.cruise = null
				ship.leave_road()
				ship.reset_reticle()
				return
			_riding = alternative
		# BY A MARGIN, not by a hair. Near a divergence the mainline and the ramp are
		# nearly equally near and the winner alternates frame to frame — the road you
		# are on flickers between the two, and with it the lane's speed penalty, which
		# is felt as a stutter. ADR 0072 forbade hysteresis as a fix for the SNAP, and
		# that stands: the snap is fixed by the slew, and this is a different defect
		# with a different cause (ADR 0076).
		elif alternative != null \
				and alternative.sample(here, clearance).edge_distance() \
					< lane.edge_distance() - Tuning.num("exploration/lane_handover_margin"):
			_riding = alternative
		ship.cruise = _riding.sample(here, clearance)
		return

	if not allowed:
		return
	for deck in _road.decks():
		if deck.start_portal() != null \
				and deck.start_portal().crossed(_previous, here) > 0:
			_riding = deck
			ship.cruise = deck.sample(here, clearance)
			ship.adopt_road_axis(ship.cruise.axis)
			ship.reset_reticle()
			return


## Did the ship just fly out through a portal? Out an off-ramp's mouth, or back out
## the on-ramp it came in by.
##
## Both are the player's own flying. Nothing else ends cruise — there is no
## interdiction, and a road that could drop you would be one.
func _left_through_a_portal(here: Vector3) -> bool:
	for deck in _road.decks():
		if deck.end_portal() != null \
				and deck.end_portal().crossed(_previous, here) > 0:
			return true
		if deck.start_portal() != null \
				and deck.start_portal().crossed(_previous, here) < 0:
			return true
	return false


## Which exit sign the player is looking at, and taking it if they click.
##
## Only while berthed. Flying, a click that changed which road you were on would be
## autopilot growth (ADR 0013); berthed, the ship is not being flown and the reticle
## is free, so it is a cursor (ADR 0083).
##
## The pick is by the RETICLE rather than by a screen-space cursor, because the mouse
## is captured while the player is steering and the reticle is the game's existing
## way of pointing at a thing in the world (ADR 0035).
func _aim_signs(ship: Mothership, clicked: bool) -> void:
	var picked: ExitSign = null
	if _berth.is_berthed() and _berth.hold() != null:
		var looking := ship.aim_direction()
		var best := Tuning.num("exploration/exit_sign_pick_deg")
		# ONLY EXITS OFF THE ROAD YOU ARE ON. The two carriageways share one building
		# with glass down the middle, so the oncoming side's signs are perfectly
		# visible from here — and clicking one would bind the berth to a ramp leaving
		# a road going the other way.
		#
		# The test is the one the union already uses (ADR 0072, ADR 0081): a ramp
		# whose direction where it leaves is outside the steering cone around the road
		# you are held against is not a road you could take. An oncoming carriageway's
		# ramp is 180 degrees outside it. No new flag, and it stays right when a road
		# crosses at an angle.
		var heading := _berth.hold().axis
		var cone := cos(deg_to_rad(Tuning.num("exploration/cruise_turn_clamp_deg")))
		for sign in _road.signs():
			# A closed exit is dark. The road is refusing to let you off it, and a
			# sign you can still click would be a refusal you only discover after
			# choosing (ADR 0084).
			if sign.ramp == null or not sign.ramp.passable \
					or sign.ramp.path().tangent_at(0.0).dot(heading) < cone:
				continue
			var off := sign.offset_degrees(ship.position, looking)
			if off >= 0.0 and off < best:
				best = off
				picked = sign
	var taking := _berth.taking()
	for sign in _road.signs():
		sign.set_aimed(sign == picked)
		sign.set_selected(taking != null and sign.ramp == taking)
	if picked != null and clicked:
		# A TOGGLE. Clicking the exit that is already going to happen cancels it and
		# puts the ship back on the highway, which is the only way out of a choice made
		# in a hurry short of leaving the berth entirely.
		_berth.take_exit(null if picked.ramp == taking else picked.ramp)


## The exit that is going to happen, as its sign. For the HUD and for tests.
func selected_sign() -> ExitSign:
	for sign in _road.signs():
		if sign.is_selected():
			return sign
	return null


## The exit sign the reticle is on, or null. For the HUD and for tests.
func aimed_sign() -> ExitSign:
	for sign in _road.signs():
		if sign.is_aimed():
			return sign
	return null


## The deck the player is riding, or null. For the HUD and for tests.
func riding() -> RoadDeck:
	return _riding


## The berth on the roadway. For the HUD and for tests.
func berth() -> RoadBerth:
	return _berth


## Every portal on the map. Only the ramps carry one — a mainline is joined and left
## through them, which is what keeps the highway continuous through a system.
func portals() -> Array[Portal]:
	return _road.portals()


func road() -> RoadNetwork:
	return _road


## What is out there past the boundary. For the scene and for the gate; nothing in
## the game queries it, and CLAUDE.md's LOD/collision rule says nothing may.
func deep_field() -> DeepField:
	return _deep


## The line the whole highway is laid on. For tests and for anything that needs to
## know where the route goes without asking a deck which piece of it it owns.
func spine() -> PackedVector3Array:
	return _spine


## The nearest way on or off the road. For the HUD — the player is meant to read the
## answer off the portal's colour, not off a readout.
func nearest_portal(point: Vector3) -> Portal:
	var best: Portal = null
	var best_distance := INF
	for portal in portals():
		var distance := point.distance_to(portal.position)
		if distance < best_distance:
			best_distance = distance
			best = portal
	return best


## Where the ship is trying to go.
##
## Velocity is the truthful answer — it includes thrusters, which genuinely move you
## — but at the far edge the clamp drives velocity to zero, and a zero vector has no
## heading to judge. The nose is what the throttle would push along, so it is the
## right thing to fall back to and it keeps the stopped case from chattering between
## "outbound" and "no idea".
func _heading_of(ship: Mothership) -> Vector3:
	var moving := ship.velocity()
	if moving.length_squared() > 0.01:
		return moving
	return -ship.basis.z


# --- what the scene and the HUD ask it ---------------------------------------

func field() -> BoundaryField:
	return _field


func systems() -> Array[SystemDisc]:
	return _discs


func links() -> Array[SystemLink]:
	return _links


func planets() -> Array[Planet]:
	return _planets


func approaches() -> Array[ApproachEnvelope]:
	return _approaches


## What the player would call where they are — a system's name, or the corridor's.
func place_of(point: Vector3) -> String:
	return _field.label(point)


## The system nearest this point, and how far its centre is. Two returns because
## every caller wants both and computing it twice is the way they drift apart.
func nearest_system(point: Vector3) -> int:
	var best := -1
	var best_distance := INF
	for i in _discs.size():
		var distance := point.distance_to(_discs[i].position)
		if distance < best_distance:
			best_distance = distance
			best = i
	return best


func system_center(index: int) -> Vector3:
	return Vector3.ZERO if index < 0 or index >= _discs.size() \
		else _discs[index].position


func system_name(index: int) -> String:
	return "—" if index < 0 or index >= NAMES.size() else NAMES[index]


## Whichever approach sequence is doing something, or the nearest one when none is.
func active_approach(point: Vector3) -> ApproachEnvelope:
	for approach in _approaches:
		if approach.state() != ApproachEnvelope.State.CLEAR:
			return approach
	var index := nearest_system(point)
	return null if index < 0 else _approaches[index]


func is_docked() -> bool:
	for approach in _approaches:
		if approach.is_docked():
			return true
	return false


## Let go of wherever the player is docked. One of them is; the rest no-op.
func depart() -> void:
	for approach in _approaches:
		if approach.is_docked():
			approach.depart()


## Every ramp mouth on the map. For the HUD and for tests.
func ramp_sites() -> Array[Vector3]:
	var sites: Array[Vector3] = []
	for portal in _road.portals():
		sites.append(portal.position)
	return sites


func warning() -> float:
	return _warning


func speed_scale() -> float:
	return _speed_scale


func outbound() -> float:
	return _outbound


func seconds_outside() -> float:
	return _seconds_outside


func marker_count() -> int:
	var total := 0
	for disc in _discs:
		total += disc.marker_count()
	for link in _links:
		total += link.marker_count()
	return total
