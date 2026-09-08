class_name RoadBerth
extends Node3D
## The berth on the roadway: you stop flying and the road carries you (ADR 0082).
##
## **This is docking, in the same sense a planet is.** The ship comes to rest against
## a larger thing and stops being piloted — which is what makes the berth legal under
## ADR 0057's "no non-interactive transit": an opt-in berth inside the tube, skipping
## no time and no distance, is a different object from the tube being a conveyor.
##
## Three properties keep it honest, and a review should check all three:
##
## 1. **Chosen.** Offered on proximity to the roadway, declined by doing nothing.
## 2. **Reversible.** The same key leaves it, at any moment, at speed.
## 3. **Never optimal.** `berth_speed_fraction` of cruise (ADR 0058).
##
## A threshold aborts on input; a berth is left on purpose. It makes no routing
## decisions: it follows the centre-line of the tube it is bound to and nothing else
## (ADR 0013). The one thing that changes the road under a berthed ship is the player
## taking an exit from the strip, and that switch is a rail rebind (ADR 0083).

enum State { CLEAR, OFFERED, BERTHED }

var _state: State = State.CLEAR
## The tube the berth is bound to. Bound on engaging and stays bound: the road never
## hands a berthed ship to another tube on proximity.
var _tube: Tube = null
var _hold: BerthHold = null
## An exit the player has clicked but the ship has not reached yet.
var _taking: Tube = null
## How far along the bound tube's PATH the rail has got, as a path t. Integrated
## rather than re-derived from the ship each frame: projecting the ship and stepping
## from there makes the target recede whenever the ship is off the rail.
var _along: float = 0.0


## Offer, hold, or release, for this frame. `riding` is the tube the ship is in with
## the drive running, or null; `onward` is the tube the ridden ramp merges into, if any.
func observe(ship: Mothership, riding: Tube, onward: Tube, pressed: bool,
		delta: float) -> void:
	if riding == null or ship.cruise == null:
		release(ship)
		return

	if _state == State.BERTHED:
		if pressed:
			release(ship)
			return
		# Running out of road ends the berth — unless there is something to hand to. A
		# ramp that ENDS is not a choice: there is exactly one road it becomes, and a
		# player who berthed on the on-ramp was asking to be carried onto the highway
		# (ADR 0096).
		if _tube == null or _tube.remaining(_along) <= 0.001:
			if onward == null or onward == _tube:
				release(ship)
				return
			_tube = onward
			_along = _tube.local(ship.position)["t"]
			_taking = null
		_rebind_if_reached(ship)
		# A RAMP TO A PLANET HANDS YOU BACK (ADR 0092). It ends at a mouth, so a berth
		# carried down one would fly the ship into open space; you fly the rest of it.
		# An INTERCHANGE ramp keeps the berth: it is road to road and ends by merging.
		if _tube != null and _tube.is_ramp() and not (_tube.road.get("mouths") as Array).is_empty() \
				and _tube.travelled(_along) >= Tuning.num("exploration/berth_ramp_release_metres"):
			release(ship)
			return
		if _hold != null:
			_along = _tube.path.wrap_t(_along + _hold.speed * delta * _tube.direction)
		_hold = _sample(ship)
		ship.berth = _hold
		return

	_state = State.OFFERED if _within_reach(ship) else State.CLEAR
	if _state == State.OFFERED and pressed:
		engage(ship, riding)


## Take the berth. Public so the gate can drive it without an input device.
func engage(ship: Mothership, riding: Tube) -> void:
	if riding == null:
		return
	_tube = riding
	_state = State.BERTHED
	_along = _tube.local(ship.position)["t"]
	_hold = _sample(ship)
	ship.berth = _hold


## Leave it. The ship keeps the speed it had (ADR 0066).
func release(ship: Mothership) -> void:
	if _state == State.BERTHED and ship != null:
		ship.berth = null
	_state = State.CLEAR
	_tube = null
	_hold = null
	_taking = null
	_along = 0.0


## Near enough the roadway to be offered a berth. Measured from the FLOOR of the lane,
## because the roadway is the thing you are pulling up to.
func _within_reach(ship: Mothership) -> bool:
	var lane := ship.cruise
	if lane == null:
		return false
	return lane.vertical + lane.half_height \
		<= Tuning.num("exploration/berth_offer_height")


func _sample(ship: Mothership) -> BerthHold:
	var hold := BerthHold.new()
	var f := _tube.travel_frame(_along)
	hold.axis = f["fwd"]
	# The rail sits just above the roadway, on the carriageway's own centre-line. In a
	# berth the road is UNDER you.
	hold.point = _tube.world(_along, 0.0,
		-maxf(_tube.hh - Tuning.num("exploration/berth_ride_height"), 0.0))
	hold.speed = Tuning.num("exploration/cruise_speed") \
		* Tuning.num("exploration/berth_speed_fraction")
	hold.pull = Tuning.num("exploration/berth_pull_rate")
	hold.error = hold.point.distance_to(ship.position)
	hold.deck_name = _tube.name
	hold.metres_remaining = _tube.remaining(_along)
	return hold


## Take an exit. Called from the strip; the switch itself happens when the ship
## reaches the ramp. Passing null cancels a choice already made.
func take_exit(ramp: Tube) -> void:
	if _state != State.BERTHED:
		return
	_taking = ramp


func taking() -> Tube:
	return _taking


## Swap rails the moment the chosen ramp actually starts under the ship. Smooth by
## construction: the ramp runs level inside the carriageway for its lead, so the two
## centre-lines coincide where the rail switches.
func _rebind_if_reached(ship: Mothership) -> void:
	if _taking == null or _tube == null:
		return
	for j in _tube.junctions:
		if j["kind"] != "exit" or j["ramp"] != _taking:
			continue
		var ahead: float = _tube.path.ahead(_along, j["t"], _tube.direction)
		if _tube.path.closed and ahead > _tube.path.length * 0.5:
			ahead -= _tube.path.length
		if ahead > 0.0:
			return
		var onto: Tube = _taking
		_tube = onto
		_along = onto.local(ship.position)["t"]
		_taking = null
		return
	# The chosen ramp is not off this tube (the road changed under us); forget it.
	_taking = null


func state() -> State:
	return _state


func is_berthed() -> bool:
	return _state == State.BERTHED


func is_offered() -> bool:
	return _state == State.OFFERED


func hold() -> BerthHold:
	return _hold


func tube() -> Tube:
	return _tube
