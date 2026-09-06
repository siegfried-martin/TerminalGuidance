class_name CruiseTank
extends RefCounted
## The cruise drive's tank: what it holds, what a route costs, and what is left.
## Pure — no scene tree, no disk. The ship configures it from tuning and burns it;
## nothing here looks a value up.
##
## **Fuel is spent per METRE, never per second** (ADR 0017 and the tuning file's own
## note). A budget measured in time would silently change every route's cost the
## moment a speed moved, and the whole point of the resource is that the player can
## read a route's price off the map *before* pointing the ship at it.
##
## **A dry tank is slow, never stuck.** Nothing in here can immobilise a ship: it
## answers "may the drive run" and the drive is the only thing that stops. Normal
## flight is free and unaffected, which is what makes stranding recoverable rather
## than a softlock.

## What a full tank holds, and what a metre of highway costs. Both are tuning
## values, pushed in by the ship so this class stays testable without an autoload.
var capacity: float = 1.0
var per_metre: float = 0.0
## What is in it now.
var units: float = 0.0


## Adopt tuned numbers. Called at build and on every hot reload, so editing the
## capacity while the game is running cannot leave a tank holding more than it can.
func configure(new_capacity: float, new_per_metre: float) -> void:
	capacity = maxf(new_capacity, 0.0)
	per_metre = maxf(new_per_metre, 0.0)
	units = clampf(units, 0.0, capacity)


func fill() -> void:
	units = capacity


## Set the tank to a fraction of full. Spawn uses this; nothing in flight does.
func fill_to(fraction: float) -> void:
	units = capacity * clampf(fraction, 0.0, 1.0)


## Spend the metres just travelled on the highway. Returns what was actually burned,
## which is less than the price on the last frame before the tank empties.
func burn(metres: float) -> float:
	if metres <= 0.0 or per_metre <= 0.0:
		return 0.0
	var wanted := metres * per_metre
	var spent := minf(wanted, units)
	units -= spent
	return spent


func fraction() -> float:
	return 0.0 if capacity <= 0.0 else clampf(units / capacity, 0.0, 1.0)


## Empty. The drive may not engage, and a running drive winds down — see
## `Mothership._spool`. It does not take the ship off the road.
func is_dry() -> bool:
	return units <= 0.0001


## What this route would cost, and whether the tank covers it. These two are what
## ADR 0017 requires to be legible at the moment the player would point the ship,
## so the HUD's leg row asks them about the leg ahead rather than reporting a level.
func cost_for(metres: float) -> float:
	return maxf(metres, 0.0) * per_metre


func covers(metres: float) -> bool:
	return cost_for(metres) <= units


## How much highway is left in the tank, in metres. A free tank has infinite range
## and says so — reporting a price of nothing as a range of nothing would put the
## most alarming reading on the HUD for the most harmless setting.
func range_metres() -> float:
	return INF if per_metre <= 0.0 else units / per_metre
