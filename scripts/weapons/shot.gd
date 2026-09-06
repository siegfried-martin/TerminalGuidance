class_name Shot
extends RefCounted
## What a shot reaches first, along the segment it swept.
##
## Every weapon in the game asks the same question — a travelling round asks it of
## the metre it crossed this frame, a hitscan beam asks it of its whole range in
## one go — so the answer is derived once here rather than three times with three
## subtly different orderings. That ordering bug has already been paid for once:
## ADR 0043 exists because a test order stood in for geometry and made every
## component unreachable.
##
## **Nearest along the segment wins, across every kind of thing at once.** A rock
## between the gun and the target stops the shot at the rock. A component mounted
## proud of the hull is reached before the hull. Neither of those is a special
## case in a caller; they both fall out of comparing one parameter.
##
## Still swept segments against analytic shapes, never a physics body — ADR 0032's
## mechanism rule is untouched by the turret arriving.
##
## Coordinates are parent-relative (arena space), like everything else that flies
## (ADR 0020).

enum Kind { NOTHING, HULL, COMPONENT, ROCK, ENEMY_MISSILE }

## Returns
## `{"kind": Kind, "t": float, "point": Vector3, "component": int, "node": Node}`.
## `t` is the fraction along a→b at which the shot was stopped, -1 for nothing hit.
## `component` is the index of the component reached, or -1. `node` is the enemy
## missile that was reached, or null.
##
## `tree` is optional and only needed for the group-membership sets — the enemy's
## missiles. A caller with no tree simply cannot hit them, which is the right
## answer for a headless geometry test.
static func resolve(a: Vector3, b: Vector3, target: TargetShip,
		rocks: ReferenceField, tree: SceneTree = null) -> Dictionary:
	var kind := Kind.NOTHING
	var best := 2.0
	var point := Vector3.ZERO
	var component := -1
	var node: Node = null

	if target != null and is_instance_valid(target):
		var on_ship := target.hit_test(a, b)
		if bool(on_ship["hit"]):
			node = null
			best = float(on_ship["t"])
			point = on_ship["point"]
			component = int(on_ship["component"])
			kind = Kind.COMPONENT if component >= 0 else Kind.HULL

	if rocks != null and is_instance_valid(rocks):
		var on_rock := rocks.hit_entry(a, b)
		var t := float(on_rock["t"])
		if t >= 0.0 and t < best:
			best = t
			point = on_rock["point"]
			component = -1
			node = null
			kind = Kind.ROCK

	# The interrupt has to be answerable by the guns, which means an incoming
	# missile is just another thing on the segment and wins if it is nearest.
	if tree != null:
		for candidate in tree.get_nodes_in_group(EnemyMissile.GROUP):
			var missile := candidate as EnemyMissile
			if missile == null or missile.is_spent():
				continue
			var t := FlightGeometry.segment_sphere_entry(
				a, b, missile.position, missile.hit_radius)
			if t >= 0.0 and t < best:
				best = t
				point = a + (b - a) * t
				component = -1
				node = missile
				kind = Kind.ENEMY_MISSILE

	if kind == Kind.NOTHING:
		return {"kind": Kind.NOTHING, "t": -1.0, "point": b,
			"component": -1, "node": null}
	return {"kind": kind, "t": best, "point": point,
		"component": component, "node": node}


## Did this result stop the shot? Everything solid does, including a rock and a
## hull with no hit points of its own — a round that carried on through the hull
## because the hull cannot be damaged yet would score on whatever was behind it.
static func stops_a_shot(result: Dictionary) -> bool:
	return int(result["kind"]) != Kind.NOTHING


static func kind_label(kind: Kind) -> String:
	match kind:
		Kind.HULL:
			return "hull"
		Kind.COMPONENT:
			return "component"
		Kind.ROCK:
			return "rock"
		Kind.ENEMY_MISSILE:
			return "incoming missile"
	return "nothing"
