class_name RoadLimits
extends RefCounted
## The bounds a lattice road is built inside. Pure — no scene tree, no tuning, no
## disk; the caller reads `tuning.cfg` and hands the numbers in.
##
## One place, because the gate and the builder must agree about them. Section 5 of
## `docs/HIGHWAY_LATTICE_PLAN.md` is the list; this is the arithmetic.
##
## THE FILLET FLOOR IS DERIVED, NOT TUNED, and that is the point of the class. A
## fillet's turn rate is `cruise_speed / radius`, so a radius under
## `cruise_speed / turn_rate` builds a road that out-turns the ship and yanks the
## nose (ADR 0070). `road_fillet_radius` is a feel value the human slides while
## flying a vertex, and a slider that can be dragged past a floor derived from two
## OTHER sliders is a slider that silently breaks the road until someone runs
## `make check`. So the tuned value is clamped here, at the point of use, and
## `clamped()` says when it is being held.

var cruise_speed: float = 0.0
var turn_rate_deg_per_sec: float = 0.0
var lane_width: float = 0.0
var lane_height: float = 0.0
var deck_separation: float = 0.0
var pitch_max_deg: float = 0.0
## What `tuning.cfg` asks for, before the floor is applied.
var tuned_fillet_radius: float = 0.0
## How much of the ship's turn rate the road is allowed to take. See `fillet_floor`.
var turn_share: float = 1.0


func _init(tuned: Dictionary) -> void:
	cruise_speed = float(tuned.get("cruise_speed", 0.0))
	turn_rate_deg_per_sec = float(tuned.get("cruise_turn_rate_deg_per_sec", 0.0))
	lane_width = float(tuned.get("lane_width", 0.0))
	lane_height = float(tuned.get("lane_height", 0.0))
	deck_separation = float(tuned.get("deck_separation", 0.0))
	pitch_max_deg = float(tuned.get("road_pitch_max_deg", 0.0))
	tuned_fillet_radius = float(tuned.get("road_fillet_radius", 0.0))
	turn_share = float(tuned.get("road_turn_share", 1.0))


## The tightest fillet the road may use.
##
## Two floors, and the larger wins. The first is ADR 0070, with headroom: at
## `cruise_speed` a radius of `R` demands `cruise_speed / R` radians a second, and the
## road may take only `road_turn_share` of what the ship has — because the nose slews
## after the lane at that same rate, so a road that takes all of it leaves the nose
## lagging and nothing to steer with. The second is ADR 0077: below the deck
## separation the inner carriageway folds through itself.
func fillet_floor() -> float:
	return maxf(RoadRehearsal.radius_floor(cruise_speed, turn_rate_deg_per_sec,
		turn_share), deck_separation)


## The radius to actually build with. `asked` is a route's own request, or 0 for the
## tuned one; either way the floor wins.
func fillet_radius(asked: float = 0.0) -> float:
	return maxf(asked if asked > 0.0 else tuned_fillet_radius, fillet_floor())


## Whether the floor is currently holding the tuned value up. The debug HUD says so,
## because a slider that has stopped responding needs to say why.
func clamped() -> bool:
	return tuned_fillet_radius < fillet_floor() - 0.001


## The building's half-width across, for a profile. A pair carries both carriageways
## either side of a spine; a lane carries one.
func half_width(profile: String) -> float:
	if profile == "lane":
		return lane_width * 0.5
	return deck_separation * 0.5 + lane_width * 0.5


func half_height() -> float:
	return lane_height * 0.5


## How far each edge's building is extended past an interior vertex, so the mitre's
## outer corner is closed: `h * tan(theta/2)`, with `theta` the deflection.
func mitre_extension(profile: String, deflection_rad: float) -> float:
	return half_width(profile) * tan(clampf(deflection_rad, 0.0, PI * 0.49) * 0.5)


## The turn rate a road of this curvature demands of the ship, in degrees a second at
## cruise. This is what "too steep" means in a number, and it is the same reading the
## gate takes off every deck.
func demanded_turn_rate(deg_per_metre: float) -> float:
	return deg_per_metre * cruise_speed
