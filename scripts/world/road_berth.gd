class_name RoadBerth
extends Node3D
## The berth on the roadway: you stop flying and the road carries you (ADR 0082).
##
## **This is docking, in the same sense a planet is.** The ship comes to rest against
## a larger thing and stops being piloted — the human's framing, and it is what makes
## the berth legal under ADR 0057's "no non-interactive transit": that clause exists to
## stop the tube itself being a loading screen, and an opt-in berth inside it, which
## skips no time and no distance, is a different object.
##
## Three properties keep it honest, and a review should check all three:
##
## 1. **Chosen.** Offered on proximity to the roadway, declined by doing nothing.
## 2. **Reversible.** The same key leaves it, at any moment, at speed.
## 3. **Never optimal.** `berth_speed_fraction` of cruise. This is ADR 0058's rule —
##    automation is worse than an engaged player — applied to travel, so the berth is
##    a comfort you pay for rather than a route optimisation.
##
## **It differs from the planet's envelope in exactly one way, and deliberately.** A
## threshold aborts on any input (ADR 0012) because it is a countdown to a commitment
## you might not have meant. A berth is a place you sit inside and want to look around
## from, read comms in, and click things in; aborting on look would make it useless for
## the one thing it is for. **A threshold aborts on input; a berth is left on purpose.**
##
## It makes no routing decisions. It follows the centre-line of the road it is bound
## to and nothing else — there is no pathing, no arrival, no avoidance, and none may
## be added (ADR 0013).

enum State { CLEAR, OFFERED, BERTHED }

var _state: State = State.CLEAR
## The road the berth is bound to. It is bound on engaging and stays bound: the union
## does not hand a berthed ship from one road to another, because that would be the
## berth choosing a route.
var _deck: RoadDeck = null
var _hold: BerthHold = null
## An exit the player has clicked but the ship has not reached yet. The berth rebinds
## when the ramp actually begins, not when the sign is clicked: the ramp starts ahead,
## and a rail that pulled the ship back onto its start would be a route rather than a
## rebind (ADR 0083).
var _taking: RoadDeck = null


## Offer, hold, or release, for this frame. `riding` is the deck the ship is on, or
## null when it is off the road.
func observe(ship: Mothership, riding: RoadDeck, pressed: bool) -> void:
	if riding == null or ship.cruise == null:
		release(ship)
		return

	if _state == State.BERTHED:
		if pressed:
			release(ship)
			return
		# Running out of road ends the berth the same way it ends cruise: there is
		# nothing to hand to, so the ship is handed back to itself, still moving.
		if _deck == null or _deck.length() <= 0.0 \
				or _deck.sample(ship.position).metres_remaining <= 0.001:
			release(ship)
			return
		_rebind_if_reached(ship)
		_hold = _sample(ship)
		ship.berth = _hold
		return

	_state = State.OFFERED if _within_reach(ship) else State.CLEAR
	if _state == State.OFFERED and pressed:
		engage(ship, riding)


## Take the berth. Public so the gate can drive it without an input device.
func engage(ship: Mothership, riding: RoadDeck) -> void:
	if riding == null:
		return
	_deck = riding
	_state = State.BERTHED
	_hold = _sample(ship)
	ship.berth = _hold


## Leave it. The ship keeps the speed it had — a berth is left flying, the way every
## other transition on this road carries its momentum (ADR 0066).
func release(ship: Mothership) -> void:
	if _state == State.BERTHED and ship != null:
		ship.berth = null
	_state = State.CLEAR
	_deck = null
	_hold = null
	_taking = null


## Near enough the roadway to be offered a berth. Measured from the FLOOR of the lane,
## because the roadway is the thing you are pulling up to — the offer should arrive as
## you settle onto the road, not whenever you happen to be inside the tube.
func _within_reach(ship: Mothership) -> bool:
	var lane := ship.cruise
	if lane == null:
		return false
	return lane.vertical + lane.half_height \
		<= Tuning.num("exploration/berth_offer_height")


func _sample(ship: Mothership) -> BerthHold:
	var hold := BerthHold.new()
	var found := _deck.path().closest(ship.position)
	var along: float = found[0]
	var centre: Vector3 = found[1]
	var direction: Vector3 = found[2]
	var frame := CruiseLane.frame_for(direction)
	var extents := _deck.profile(along)
	hold.axis = direction
	# The rail sits just above the roadway, on the carriageway's own centre-line. In a
	# berth the road is UNDER you; that is the difference between being carried by it
	# and flying down the middle of the tube.
	hold.point = centre - frame[1] * maxf(extents.y
		- Tuning.num("exploration/berth_ride_height"), 0.0)
	hold.speed = Tuning.num("exploration/cruise_speed") \
		* Tuning.num("exploration/berth_speed_fraction")
	hold.pull = Tuning.num("exploration/berth_pull_rate")
	hold.error = hold.point.distance_to(ship.position)
	hold.deck_name = _deck.deck_name
	hold.metres_remaining = maxf(_deck.length() - along, 0.0)
	return hold


## Take an exit. Called when the player clicks its sign; the switch itself happens
## when the ship reaches the ramp.
##
## **This is a rail rebind, not a route.** Nothing is planned, nothing is chosen for
## the player, and there is no destination held anywhere: the road the berth follows
## changes, once, at a place the player could see (ADR 0083).
func take_exit(ramp: RoadDeck) -> void:
	if _state != State.BERTHED or ramp == null:
		return
	_taking = ramp


## Whether an exit has been taken and is still ahead.
func taking() -> RoadDeck:
	return _taking


## Swap rails the moment the chosen ramp actually starts under the ship.
##
## It is smooth by construction rather than by tuning: ADR 0070 already requires every
## ramp to be tangential to the mainline where it leaves, so there is no angle here to
## absorb. That ADR was written about ship handling and turns out to be what makes this
## safe.
func _rebind_if_reached(ship: Mothership) -> void:
	if _taking == null or _taking.length() <= 0.0:
		return
	var onto := _taking.sample(ship.position)
	if onto.metres_travelled <= 0.001 or onto.metres_remaining <= 0.001:
		return
	_deck = _taking
	_taking = null


func state() -> State:
	return _state


func is_berthed() -> bool:
	return _state == State.BERTHED


func is_offered() -> bool:
	return _state == State.OFFERED


func hold() -> BerthHold:
	return _hold


func deck() -> RoadDeck:
	return _deck
