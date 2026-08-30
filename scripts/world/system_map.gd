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

## Relayed from whichever system's envelope fired, so the dock screen can say where
## it is without the scene tracking which envelope belongs to which planet.
signal arrived(place: String)
signal departed()

var _discs: Array[SystemDisc] = []
var _planets: Array[Planet] = []
var _approaches: Array[ApproachEnvelope] = []
var _links: Array[SystemLink] = []
## Every piece of playable space, united. Systems and corridors are regions in one
## list rather than two systems to be checked in turn (ADR 0062).
var _field: BoundaryField = BoundaryField.new()

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
	var here := Vector3.ZERO
	for i in _discs.size():
		var disc := _discs[i]
		disc.position = here
		disc.system_name = NAMES[i]
		# Apertures face the legs, in order: back down the leg you arrived by, then
		# on down the next one. The last system has only the one, which is what makes
		# a line a line rather than a ring with a missing piece.
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
			here += step * (Tuning.num(LEG_KEYS[i]) + radius * 2.0)

	# The road's ramps sit INSIDE each system, one either side of its centre — the
	# highway runs all the way through, and coming off it puts you beside the planet
	# rather than a system-crossing away from it. A system the road passes through
	# therefore has two ramp sites and four portals; an end system has one and two.
	var ramp := Tuning.num("exploration/portal_site_offset")
	for i in _links.size():
		_links[i].leg_bearing_deg = bearing
		# The CORRIDOR is mouth to mouth: it is the bounded space between two systems.
		# The outgoing aperture is the last on the system you leave and the first on
		# the one you arrive at, which falls out of the order the bearings were
		# appended in above.
		_links[i].span(_discs[i].aperture_mouth(_discs[i].aperture_count() - 1),
			_discs[i + 1].aperture_mouth(0))
		# The ROAD is ramp to ramp, which is longer: it runs out through one rim and
		# in through the other.
		_links[i].road_span(_discs[i].position + step * ramp,
			_discs[i + 1].position - step * ramp)

	_field.regions.clear()
	for disc in _discs:
		_field.regions.append(disc.region())
	for link in _links:
		_field.regions.append(link.region())
	_field.warning_band = Tuning.num("exploration/bounds_warning_band")
	_field.stop_distance = Tuning.num("exploration/bounds_stop_distance")


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
	for link in _links:
		for deck in link.decks():
			deck.set_permitted(allowed)
	if not _has_previous:
		return

	if _riding != null:
		# Losing the drive mid-road drops you where you are, at hull speed. That is
		# the honest reading of the drive belonging to the hull, and it is the only
		# way the roster can answer "what is the road worth" for a fighter.
		if not allowed \
				or _riding.end_portal().crossed(_previous, here) > 0 \
				or _riding.start_portal().crossed(_previous, here) < 0:
			_riding = null
			ship.cruise = null
			ship.reset_reticle()
		else:
			ship.cruise = _riding.sample(here)
		return

	if not allowed:
		return
	for link in _links:
		for deck in link.decks():
			if deck.start_portal().crossed(_previous, here) > 0:
				_riding = deck
				ship.cruise = deck.sample(here)
				ship.reset_reticle()
				return


## The deck the player is riding, or null. For the HUD and for tests.
func riding() -> RoadDeck:
	return _riding


## Every portal on the map, both decks of every leg, both ends.
func portals() -> Array[Portal]:
	var found: Array[Portal] = []
	for link in _links:
		for deck in link.decks():
			if deck.start_portal() != null:
				found.append(deck.start_portal())
			if deck.end_portal() != null:
				found.append(deck.end_portal())
	return found


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


## Every ramp site on the map, in order along the road. For the HUD and for tests —
## an end system has one and a system the road passes through has two.
func ramp_sites() -> Array[Vector3]:
	var sites: Array[Vector3] = []
	for link in _links:
		for deck in link.decks():
			if deck.start_portal() != null:
				sites.append(deck.start_portal().position)
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
