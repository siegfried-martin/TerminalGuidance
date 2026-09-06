class_name LatticeScene
extends ExplorationScene
## The exploration POC with its roads laid on the lattice (ADR 0095) — `make lattice`.
##
## **The same scene, with a different layout.** Every system, corridor, planet,
## boundary, HUD and control here is the one `make fly` uses; what changes is that
## `SystemMap` reads `data/routes.json` instead of walking a list of tuned leg
## lengths. That is the price of "it must work correctly above anything else": the old
## road keeps working while the new one is built, and the human can fly both and say
## when the new one is ready. Step D swaps them and deletes this file.
##
## **There is no way ON to this road yet.** Junctions are authored tiles and their
## ramps land in step C, so a fresh run starts ON the trunk carriageway and the debug
## teleport walks the road's vertices rather than its systems. The vertex rule is the
## one thing in step B that has to be judged from the seat, and this is the seat.

## How far before a vertex the debug drop puts the ship, so the bend is ahead of you
## rather than under you. Infrastructure: far enough to see it coming at cruise, near
## enough not to spend the trip getting there.
const APPROACH_METRES := 2500.0
## And how far into the road it will never put you closer than, so a drop near the
## western stub does not leave you hanging out of the open end of the highway.
const INSET_METRES := 400.0

## Which stop the debug teleport is on. Cycles the vertices of every carriageway that
## runs forward, in route order.
var _stop: int = -1


func uses_lattice() -> bool:
	return true


## Start on the road, at the first stop the teleport would take you to.
func place_start() -> void:
	_stop = -1
	if not _next_stop():
		super.place_start()


## THE DEBUG TELEPORT, pointed at vertices instead of systems.
##
## Same rule as the one it overrides and the same reason for existing: the trunk is
## twenty-one kilometres and judging two bends by flying to each of them is most of a
## session. Every use is still counted and still said out loud, because a jump makes
## every travel figure on the screen untrue.
func teleport_onward() -> void:
	if not Tuning.flag("exploration/debug_teleport_enabled"):
		return
	if not _next_stop():
		return
	_teleports += 1
	_last_teleport = "%s at %.0f s" % [_stop_name(), Time.get_ticks_msec() / 1000.0]
	print("[debug] drop %d — onto %s" % [_teleports, _last_teleport])


## Move to the next stop, or report that there are none.
func _next_stop() -> bool:
	var stops := _stops()
	if stops.is_empty():
		return false
	_stop = (_stop + 1) % stops.size()
	var stop: Array = stops[_stop]
	_map.drop_on_road(_ship, stop[0] as RoadDeck, float(stop[1]))
	return true


func _stop_name() -> String:
	var stops := _stops()
	if stops.is_empty() or _stop < 0 or _stop >= stops.size():
		return "nowhere"
	var stop: Array = stops[_stop]
	return "%s, %.1f km along" % [(stop[0] as RoadDeck).deck_name,
		float(stop[1]) / 1000.0]


## Every place worth being dropped: a short run before each of the road's own
## vertices, on each carriageway that runs forward.
##
## Derived from the route data rather than listed, so authoring a bend into
## `data/routes.json` adds a stop to the teleport with no code change — which is the
## loop the hot reload exists for.
func _stops() -> Array:
	var found: Array = []
	var lattice := Routes.make_lattice()
	var specs: Array[RouteSpec] = []
	for spec in Routes.all_routes():
		if not spec.is_lane():
			specs.append(spec)
	var decks := _map.forward_mainlines()
	for i in mini(decks.size(), specs.size()):
		var deck := decks[i]
		var spec := specs[i]
		var world := spec.world_vertices(lattice)
		for vertex in range(1, world.size() - 1):
			var at: float = deck.path().closest(world[vertex])[0]
			found.append([deck, clampf(at - APPROACH_METRES, INSET_METRES,
				maxf(deck.length() - INSET_METRES, 0.0))])
	return found
