class_name HullClass
extends RefCounted
## Which kind of ship this is, and every number that follows from that.
##
## `EXPLORATION_DESIGN.md` invariant 5: hull speed, turn rate, missile speed, fuse
## and cooldown all become properties of a hull or of installed equipment. The
## difference between "one value" and "a table keyed by class with a default" is
## trivial now and a refactor across every consumer later, so the *mechanism* lands
## before the table needs more than three rows.
##
## The mechanism is `num()`: a call site names both the per-class key it would use
## and the shared key it falls back to. Nothing can silently vanish, because the
## shared key is required and `Tuning` errors on a missing one — a typo'd class key
## resolves to the fallback, and a typo'd fallback fails the build.
##
##     HullClass.num(kind, "max_speed", "ship/manual_max_speed")
##     # -> exploration/fighter_max_speed, or ship/manual_max_speed if absent
##
## Classes are named in tuning rather than numbered, for the reason the turret's
## weapon slots and the crew roster are: a typo reads as something, instead of
## silently meaning whichever class happens to be index 0.

## Appended to, never reordered. The ladder in `EXPLORATION_DESIGN.md` has exactly
## these three; a carrier or a shuttle is a new row here and a new row in tuning.
enum Kind { TAXI, FIGHTER, CAPITAL }

const DEFAULT: Kind = Kind.TAXI


static func name_of(kind: Kind) -> String:
	match kind:
		Kind.FIGHTER:
			return "fighter"
		Kind.CAPITAL:
			return "capital"
	return "taxi"


static func from_name(text: String) -> Kind:
	match text.strip_edges().to_lower():
		"fighter":
			return Kind.FIGHTER
		"capital":
			return Kind.CAPITAL
	return DEFAULT


## Every class, in enum order. The debug roster (POC step 4) cycles this.
static func all() -> Array[Kind]:
	return [Kind.TAXI, Kind.FIGHTER, Kind.CAPITAL]


## The next class in the roster, wrapping. One key switches hulls so the speed
## classes can be felt back to back in a single session rather than across two.
static func next(kind: Kind) -> Kind:
	var order := all()
	return order[(order.find(kind) + 1) % order.size()]


## A number for this class, falling back to a shared key when the class has no
## entry of its own. See the class comment for why both keys are named at the site.
static func num(kind: Kind, suffix: String, shared_key: String) -> float:
	var keyed := "exploration/" + name_of(kind) + "_" + suffix
	if Tuning.has(keyed):
		return Tuning.num(keyed)
	return Tuning.num(shared_key)


static func flag(kind: Kind, suffix: String, shared_key: String) -> bool:
	var keyed := "exploration/" + name_of(kind) + "_" + suffix
	if Tuning.has(keyed):
		return Tuning.flag(keyed)
	return Tuning.flag(shared_key)


## The top speed this class may reach, clamped by the speed hierarchy.
##
## CLAUDE.md's hierarchy (lasers > missiles > ships) is structural, and this is
## where it is made so. It used to be one global fraction of missile speed, which
## cannot express both a taxi at 0.27 and a fighter at 0.67 — so the invariant it
## protects changes from *"missiles outrun ships"* to **"a missile outruns its
## intended targets"**, and each class declares its own headroom.
##
## Still a clamp and not a suggestion: no edit to a class's own speed can produce a
## ship that matches a missile, because the ceiling is applied here rather than
## trusted to a tuning session.
static func max_speed(kind: Kind) -> float:
	var ceiling := Tuning.num("missile/base_speed") * clampf(
		num(kind, "speed_ceiling_fraction", "ship/manual_speed_ceiling_fraction"),
		0.0, 0.95)
	return minf(num(kind, "max_speed", "ship/manual_max_speed"), ceiling)


## Whether this hull carries the cruise engine — and therefore whether a portal
## opens for it. The fighter's inability to use the highway is this one property,
## not a second rule: fast and local is the whole of that class's identity.
static func has_cruise_drive(kind: Kind) -> bool:
	return flag(kind, "has_cruise_drive", "exploration/taxi_has_cruise_drive")
