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
## Aliases. The layout arithmetic moved to `LegacyLayout` when the lattice arrived
## (ADR 0095) and both go in step D; these keep every existing reader pointing at one
## definition rather than two that can drift.
const LEG_KEYS := LegacyLayout.LEG_KEYS
## Placeholder identity. The POC doc calls them A, B and C; D and E arrived with the
## crossing highway, and naming them anything more is content this POC does not test.
const NAMES: PackedStringArray = ["SYSTEM A", "SYSTEM B", "SYSTEM C",
	"SYSTEM D", "SYSTEM E"]
const LETTERS: PackedStringArray = ["A", "B", "C", "D", "E"]

## TWO HIGHWAYS, CROSSING AT SYSTEM B. A route is the systems on it in order, the legs
## between them, a bearing off the map's own, and the height its road rides at. A
## system on more than one route is where they meet (ADR 0085).
##
## Each route is anchored on one system whose position is already fixed: route 0
## anchors A at the origin and lays the rest out from it; route 1 anchors on B, which
## route 0 has already placed, so the two can never drift apart.
const ROUTE_SYSTEMS := LegacyLayout.ROUTE_SYSTEMS
const ROUTE_LEGS := LegacyLayout.ROUTE_LEGS
const ROUTE_ANCHORS := LegacyLayout.ROUTE_ANCHORS
const ROUTE_BEARING_KEYS := LegacyLayout.ROUTE_BEARING_KEYS
const ROUTE_HEIGHT_KEYS := LegacyLayout.ROUTE_HEIGHT_KEYS
## ROADS HAVE NAMES. "Stay on highway A-377B" is a sentence a player can act on;
## "stay on this road" is not, and while berthed the routing readout is the only thing
## telling them what happens if they do nothing (ADR 0083).
##
## Authored here rather than derived from the systems they connect, because a real
## route number outlives the places on it — a road keeps its name when a new system is
## built on it, and deriving one would rename the whole highway.
const ROUTE_NAMES: PackedStringArray = ["A-377B", "K-112"]

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

## Whether the map reads the real input devices, or is told what was pressed. See
## `Mothership.reads_input`: a capture harness renders into a real window, and a map
## that polls the keyboard in one is not reproducible. Harness switch only.
var reads_input: bool = true
## Which layout places the systems and shapes the roads. `make fly` leaves this alone
## and gets the legs; `LatticeScene` sets it and gets `data/routes.json`. Read once per
## relayout and in exactly one place, because both branches go in step D.
var on_lattice: bool = false
## One-shot presses a harness queues instead. Consumed by the next observation, so a
## harness sets one the way a player taps a key rather than holding a flag down.
var pressed_dock: bool = false
var pressed_click: bool = false
## Last frame's position, for the SWEPT portal test. At 96.7 m/s a ship covers 1.6 m
## in a frame, and a portal tested against a position rather than a segment is one
## that intermittently does not exist.
var _previous: Vector3 = Vector3.ZERO
var _has_previous: bool = false


func _ready() -> void:
	_build()
	relayout()
	Tuning.reloaded.connect(relayout)
	# Saving `data/routes.json` relays the map out under the ship, the way saving
	# `tuning.cfg` re-tunes it. The road is data now, and data you cannot nudge while
	# looking at it is a worse instrument than a slider (ADR 0095).
	Routes.reloaded.connect(relayout)


func _build() -> void:
	var count := NAMES.size()
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

	# One corridor per leg, across every route. The corridor is what you fly when you
	# decline the road, so a leg without one is a leg you may only travel by highway.
	for route in ROUTE_SYSTEMS.size():
		var on_route: Array = ROUTE_SYSTEMS[route]
		for i in on_route.size() - 1:
			var from_system: int = on_route[i]
			var to_system: int = on_route[i + 1]
			var link := SystemLink.new()
			link.name = "Link%s%s" % [LETTERS[from_system], LETTERS[to_system]]
			link.link_name = "%s to %s" % [NAMES[from_system], NAMES[to_system]]
			link.from_name = NAMES[from_system]
			link.to_name = NAMES[to_system]
			add_child(link)
			_links.append(link)


## Place everything, and recompose the boundary from what was placed.
##
## Called on every tuning reload, because the diameter, the leg lengths and the
## aperture bearing are all sliders and every one of them moves the map.
func relayout() -> void:
	var layout := _layout()
	for i in _discs.size():
		var disc := _discs[i]
		disc.position = layout.positions[i]
		disc.system_name = NAMES[i]
		disc.bearings = layout.bearings[i] as Array[float]
		disc.rebuild()
		_planets[i].base = disc.position
		_planets[i].rebuild()
		_approaches[i].position = _planets[i].position
		_approaches[i].rebuild()
	for i in mini(_links.size(), layout.corridors.size()):
		_links[i].follow(layout.corridor(i))

	# THE ROAD NETWORK. Each route spans its whole run in one piece, through every
	# system on it — a highway that stops at each system is the thing ADR 0065 exists
	# to forbid — and the routes are joined afterwards, where they cross (ADR 0085).
	_spine = layout.spine
	_road.rebuild()
	for route in layout.route_count():
		var names := PackedStringArray()
		var centres: Array[Vector3] = []
		for index in layout.systems_on(route):
			centres.append(layout.positions[index])
			names.append(NAMES[index])
		if layout.on_lattice:
			_road.add_lattice_route(layout.spec_of(route), Routes.make_lattice(),
				Routes.limits(), names)
		else:
			_road.add_route(layout.line_of(route), centres, names,
				layout.route_names[route], layout.route_heights[route])
	# Interchanges are step C on the lattice: there, two roads crossing are joined by
	# authored junction tiles and a lane route between them, which closes exactly
	# rather than being fitted and then measured.
	if layout.on_lattice:
		# The ways on and off. A ramp is a lane route: it starts at a junction's socket
		# cell and ends at a mouth, and nothing about where it meets the road is
		# measured (ADR 0095).
		var lattice := Routes.make_lattice()
		var limits := Routes.limits()
		for spec in Routes.all_routes():
			if not spec.is_lane():
				continue
			var host := Routes.route(spec.from_route)
			if host != null:
				_road.add_ramp(spec, host, lattice, limits, spec.to_portal, host.name)
	else:
		_road.link_routes()

	_field.regions.clear()
	for disc in _discs:
		_field.regions.append(disc.region())
	for link in _links:
		_field.regions.append(link.region())
	# THE ROAD CARRIES ITS OWN SPACE (ADR 0091). A corridor is drawn between two
	# systems and an interchange ramp is not on one — it cuts the corner between two
	# highways crossing at an angle — so riding it put the boundary's red across the
	# view and, past `bounds_stop_distance`, walked the speed ceiling toward zero on a
	# road the player was legitimately on. Measured at 388 m outside.
	#
	# A region per deck rather than a wider corridor: the corridor is what off-road
	# travel is bounded by and widening it everywhere to cover one ramp would cost that
	# its meaning. Regions UNITE, so this can only ever add space, and the corridor
	# still governs wherever both apply.
	for deck in _road.decks():
		_field.regions.append(_space_around(deck))
	_field.warning_band = Tuning.num("exploration/bounds_warning_band")
	_field.stop_distance = Tuning.num("exploration/bounds_stop_distance")

	# LAST, and it needs both of the things above it: the deep field is scattered
	# around the spine and rejected wherever the boundary says the point is still
	# playable space, so it cannot exist until the field is composed.
	_deep.rebuild(_spine, _field)


## Where the systems go and what shape each road is. The ONE place the two layouts
## differ, and the branch goes in step D with the legs.
func _layout() -> MapLayout:
	if on_lattice:
		return LatticeLayout.build(Routes.all_routes(), Routes.anchors(),
			Routes.make_lattice(), Routes.limits(), NAMES,
			Tuning.num("exploration/system_diameter") * 0.5)
	return LegacyLayout.build(NAMES, ROUTE_NAMES)


## The bounded space around one carriageway. Radius is DERIVED — the lane's own
## corner-to-corner plus the warning band — so riding a road can never redden it and
## nothing here is a feel value to be tuned against the lane it wraps.
func _space_around(deck: RoadDeck) -> TubeRegion:
	var tube := TubeRegion.new()
	tube.name_of = deck.deck_name
	tube.follow(deck.path().points)
	var half := Vector2(Tuning.num("exploration/lane_width"),
		Tuning.num("exploration/lane_height")) * 0.5
	tube.radius = sqrt(half.x * half.x + half.y * half.y) \
		+ Tuning.num("exploration/bounds_warning_band")
	# No flare: a road does not narrow at its ends, and a tube that tapered would put
	# the edge back across the mouth this exists to keep clear.
	tube.mouth_radius = tube.radius
	tube.flare_length = 0.0
	return tube


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
	# Taken BEFORE the road runs, because `_ride_the_road` moves `_previous` on its
	# berthed path. Metres, not seconds: fuel is priced by the route (ADR 0017), so
	# nothing that changes a speed may change what a leg costs.
	var travelled := here.distance_to(_previous) if _has_previous else 0.0
	# Both keys are read once, up front, and the harness's are consumed here — so the
	# two consumers below cannot disagree about what was pressed this frame.
	var took_dock := Input.is_action_just_pressed("dock") if reads_input \
		else pressed_dock
	pressed_dock = false
	pressed_click = false

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
	#
	# The union's answer goes with it. A berth never changes roads on proximity (ADR
	# 0082), but a road that has ENDED is not a choice — there is exactly one thing it
	# becomes — and releasing there dropped a player at the merge they berthed for.
	_berth.observe(ship, _riding,
		_road.governing(here, ship.road_axis(), _riding, ship.lane_clearance()),
		took_dock, delta)
	# THE SHELL, measured before the ship moves and enforced after it has (ADR 0087).
	ship.hull_barrier = _shell_for(ship, here)
	# HIGHWAY METRES, whoever is doing the steering. A berth is carried by the road at
	# a fraction of cruise (ADR 0082), and a berth that also travelled free would be
	# the range-optimal way to cross the map — which is exactly the "automation is
	# never optimal" clause it was built to satisfy. So it costs the same per metre
	# and buys comfort rather than range (ADR 0086).
	if ship.is_cruising():
		ship.cruise_tank.burn(travelled)
	_offer_exits()
	_name_the_ways()
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
	# ENGAGING needs fuel; STAYING does not. A portal is refused on an empty tank —
	# it opens for a drive that can run, and a dry one cannot (ADR 0060) — but a tank
	# that empties mid-leg leaves the ship on the road at hull speed rather than
	# putting it out in open space, which would be the road dropping the player.
	var can_engage := allowed and not ship.cruise_tank.is_dry()
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
	_road.set_permitted(can_engage)
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

	if not can_engage:
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


## Which exits belong to the road under the ship, and which one is going to happen.
##
## **Nothing is picked here any more** (ADR 0091). An exit is read and taken on the
## strip along the bottom of the screen; picking a sign with the reticle could not be
## made to work, because the reticle is a direction from the SHIP and it is drawn
## projected from a camera behind and above it, so what the player aimed at and what
## the pick measured were two different rays.
##
## What is left is the fact the strip and the (optional) signs both read: an exit is
## yours if it is bolted to the carriageway you are on (ADR 0088). The signs are not
## drawn by default; `exit_signs_visible` puts them back as scenery.
func _offer_exits() -> void:
	var taking := _berth.taking()
	for sign in _road.signs():
		sign.set_relevant(_riding != null and sign.from_deck == _riding)
		sign.set_selected(taking != null and sign.ramp == taking)


## The exits ahead on the road being ridden, nearest first, as
## `[[ramp, label, metres_ahead, may_take], …]`. Empty off the road.
##
## A **closed** exit is listed and refused rather than hidden. ADR 0084's rule is that
## a refusal you only find out about after choosing is not a refusal — so the turning
## is on the strip, greyed, and pressing it does nothing.
##
## Measured to where the RAMP LEAVES rather than to where its sign hangs: what the
## player is deciding about is the turning, and the sign was only ever a lead distance
## in front of it. An exit already taken stays listed a little past zero, so the one
## that is about to happen does not vanish off the strip at the moment it matters.
func upcoming_exits(here: Vector3) -> Array:
	var found: Array = []
	if _riding == null:
		return found
	var line := _riding.path()
	var ship_at: float = line.closest(here)[0]
	var horizon := Tuning.num("exploration/nav_exit_horizon_metres")
	var taking := _berth.taking()
	for sign in _road.signs():
		if sign.from_deck != _riding or sign.ramp == null:
			continue
		# MEASURED TO THE WAY OUT, not to where the ramp's centre-line begins. A ramp
		# starts ON the carriageway and runs beside it for hundreds of metres before it
		# clears the wall, so the distance to its start is a distance to a point in the
		# lane you are already in — the strip said 257 m while the opening was still
		# most of a kilometre ahead. The gate the tile declares IS the way out.
		var leaves := sign.ramp.path().start()
		for gate in _road.gates():
			if gate.deck == sign.ramp:
				leaves = gate.position
				break
		var metres: float = line.closest(leaves)[0] - ship_at
		if metres > horizon:
			continue
		# A ramp that is behind you is a turning you have missed — unless it is the one
		# you have chosen, which the strip keeps until the rebind actually happens.
		if metres < 0.0 and sign.ramp != taking:
			continue
		found.append([sign.ramp, sign.label_text, metres, sign.ramp.passable])
	found.sort_custom(func(a, b) -> bool: return (a[2] as float) < (b[2] as float))
	return found


## Take an exit, from the strip. The rail rebind is still the berth's and still happens
## when the ramp arrives rather than when the button is pressed (ADR 0083); this is the
## same toggle the sign click was, moved to a control that can actually be hit.
func take_exit(ramp: RoadDeck) -> void:
	if ramp != null and not ramp.passable:
		return
	_berth.take_exit(null if ramp == _berth.taking() else ramp)


## Which mouths say where they go.
##
## Off the road, the ways ON are the choices and they are named; on it, the way OFF the
## road you are riding is. A mouth that is neither is still DRAWN — it is a built thing
## and a structure that came and went would be worse than clutter — it simply stops
## shouting its destination across the system (ADR 0088).
func _name_the_ways() -> void:
	for deck in _road.decks():
		var joining := deck.start_portal()
		var leaving := deck.end_portal()
		if joining != null:
			joining.set_named(_riding == null or _riding == deck)
		if leaving != null:
			leaving.set_named(_riding == deck)


## The shell the ship is held against this frame, in the SHIP's own frame (ADR 0087).
##
## Measured here rather than in the ship because the road is the map's, and handed down
## exactly as `cruise` is: the ship never looks the road up. The conversion is not
## ceremony — a barrier carries a POINT, and a point is the one thing a floating-origin
## recentre can invalidate (ADR 0020).
func _shell_for(ship: Mothership, here: Vector3) -> HullBarrier:
	var held := _road.barrier(here, ship.lane_clearance())
	if held == null:
		return null
	var parent := ship.get_parent_node_3d()
	if parent != null:
		held.centre = parent.to_local(to_global(held.centre))
	return held


## The exit that is going to happen, as its sign. For the HUD and for tests.
func selected_sign() -> ExitSign:
	for sign in _road.signs():
		if sign.is_selected():
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


## Put a ship in a system, back from one of its apertures and facing out along it.
##
## One placement rule, used by the spawn and by the debug teleport, so a teleport
## lands the ship exactly where a fresh run would put it — anywhere else and the two
## would slowly diverge into "it behaves differently after a jump". The offset keeps
## the ship well clear of the planet's approach envelope, which sits on the centre:
## arriving already inside a landing sequence nobody asked for is the thing ADR 0012
## exists to prevent.
func place_ship(ship: Node3D, index: int) -> void:
	if ship == null or index < 0 or index >= _discs.size():
		return
	var disc := _discs[index]
	var home := disc.position
	var mouth := disc.aperture_mouth(disc.aperture_count() - 1)
	var out := (mouth - home).normalized()
	ship.global_position = to_global(home - out * disc.radius() * 0.45)
	ship.look_at(to_global(mouth), Vector3.UP)


## DEBUG ONLY, and only until step C: put the ship on a carriageway, pointing along
## it, `along` metres in, **with the cruise drive running**.
##
## The lattice road has no ramps yet — junctions are authored tiles and they land in
## step C — so there is no portal to fly and therefore no way to engage. Without this
## the new road can be looked at and not flown, and the vertex rule is the one thing in
## it that has to be judged from the seat: a bend at 30 m/s and the same bend at 250
## are not the same question.
##
## **It stands in for a portal and does exactly what the portal branch does** — adopt
## the road's axis, take a lane sample, reset the reticle — rather than inventing a
## second way on to a road. When step C lands, the ramps are the way on and this goes
## with the scene it serves. It engages only for a hull that HAS a drive, because the
## speed ladder is keyed by class and a fighter on the road is still a fighter
## (ADR 0059); a dry tank is not checked, because a dry tank is slow and not stranded
## (ADR 0086) and being stuck at hull speed with no explanation is the thing this
## exists to stop.
##
## The ship is taken off whatever it was on first, the way the teleport does: arriving
## somewhere else with a lane sample from the old road still attached is an engine
## running in open space.
func drop_on_road(ship: Mothership, deck: RoadDeck, along: float) -> void:
	if ship == null or deck == null or deck.length() <= 0.0:
		return
	_berth.release(ship)
	_riding = null
	ship.cruise = null
	ship.leave_road()
	ship.reset_reticle()
	var at := clampf(along, 0.0, deck.length())
	var centre := deck.path().point_at(at)
	ship.global_position = to_global(centre)
	ship.look_at(to_global(centre + deck.path().tangent_at(at) * 1000.0), Vector3.UP)
	# `_previous` is the swept portal test's other end, and there is no portal here —
	# but it is also what `_ride_the_road` refuses to run without, so it is set to
	# where the ship now is rather than left a system away.
	_previous = centre
	_has_previous = true
	if not ship.has_cruise_drive():
		return
	_riding = deck
	ship.cruise = deck.sample(centre, ship.lane_clearance())
	ship.adopt_road_axis(ship.cruise.axis)
	ship.reset_reticle()


## Every mainline carriageway that runs forward, in route order. The debug drop picks
## from these; nothing in the game reads them.
func forward_mainlines() -> Array[RoadDeck]:
	var found: Array[RoadDeck] = []
	for deck in _road.decks():
		if not deck.is_ramp and deck.runs_forward:
			found.append(deck)
	return found


## THE DEBUG TELEPORT (POC step 7). It exists so fuel and route choices can be tested
## without flying every leg, and it is a debug tool rather than a mechanic: nothing in
## the game may call it, and the HUD says loudly that it was used, because a silent
## teleport contaminates the travel-time verdict this POC is measuring.
##
## The ship is taken off the road first. Being moved several kilometres while a lane
## sample from the old road is still attached would hand the ship a road that is no
## longer under it, and the ship's own memory of where the road went — the slewed axis
## and the wound-up spool — would arrive at the far end as an engine running in open
## space.
func warp_to_system(ship: Mothership, index: int) -> void:
	if ship == null or index < 0 or index >= _discs.size():
		return
	_berth.release(ship)
	_riding = null
	ship.cruise = null
	ship.leave_road()
	ship.reset_reticle()
	place_ship(ship, index)
	# The previous position is a system away now, and the segment between the two
	# crosses whatever happens to lie on the line. Forgetting it is what keeps the
	# portal-crossing test from reading a jump as a trip through a portal.
	_has_previous = false
	_previous = to_local(ship.global_position)


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
