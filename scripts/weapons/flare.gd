class_name Flare
extends Node3D
## A countermeasure flare. Both sides use the same one: the turret's blocker throws
## a star of them, and the target ship answers an incoming missile with its own.
##
## A missile that touches a flare of the *other* side dies. That is the whole
## behaviour — no seduction, no decoy tracking, no probability of being fooled. A
## flare is a physical object in the way, which means the counter to it is flying
## around it, and that is a thing the player can see and learn rather than a die
## roll happening off screen.
##
## Slow and short-lived on purpose: a flare is a wall thrown up for a moment, not a
## minefield. Everything about how long it hangs and how wide it spreads is tuned.
##
## Swept-segment against a sphere, like everything else that can be hit (ADR 0032).
## The drawn sphere IS the kill sphere — one number, the rule ADR 0041, ADR 0043 and
## ADR 0050 each arrived at the hard way.

## Which side threw it. A flare kills missiles belonging to the other one.
enum Side { PLAYER, ENEMY }

const GROUP := "flare"

var side: int = Side.PLAYER
## Drawn and hit at the same radius. Read once at launch so a hot reload cannot
## change the size of a flare that is already in the air.
var radius: float = 0.0

var _velocity: Vector3 = Vector3.ZERO
var _life_left: float = 0.0
var _spent: bool = false
var _material: StandardMaterial3D


func _ready() -> void:
	add_to_group(GROUP)


## Throw one flare from `from` along `direction`. Positions are parent-relative
## (ADR 0020), like everything else in the arena.
func launch(from: Vector3, direction: Vector3, flare_side: int) -> void:
	side = flare_side
	radius = Tuning.num("flare/radius")
	_velocity = direction.normalized() * Tuning.num("flare/speed")
	_life_left = Tuning.num("flare/seconds")
	position = from
	_build_body()


func _build_body() -> void:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 8
	sphere.rings = 4
	sphere.radius = radius
	sphere.height = radius * 2.0

	var tint := Tuning.color(
		"flare/player_color" if side == Side.PLAYER else "flare/enemy_color")
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.albedo_color = tint

	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = sphere
	body.material_override = _material
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(body)


func _process(delta: float) -> void:
	if _spent or delta <= 0.0:
		return
	position += _velocity * delta
	_life_left -= delta
	# Fades out rather than blinking away, so the moment it stops being a wall is
	# visible instead of being something the player has to have counted.
	var total := maxf(Tuning.num("flare/seconds"), 0.001)
	if _material != null:
		_material.albedo_color.a = clampf(_life_left / total, 0.0, 1.0)
	if _life_left <= 0.0:
		_expire()


## Spent stopping a missile. One flare, one missile — a star is worth exactly as
## many interceptions as it has flares in it.
##
## It leaves a small flash, because the alternative is a missile that simply stops
## existing and a player who cannot tell an interception from a bug. The flash is
## made here rather than by whatever was intercepted, so both the ridden missile and
## an unguided round get the same feedback from the same place.
func consume() -> void:
	var parent := get_parent_node_3d()
	if parent != null:
		var flash := DetonationFlash.new()
		flash.name = "FlareKill"
		parent.add_child(flash)
		flash.position = position
		flash.setup(radius * 0.5, Tuning.num("flare/kill_flash_radius"),
			Tuning.num("flare/kill_flash_seconds"),
			Tuning.color("flare/kill_flash_color"))
	_expire()


func _expire() -> void:
	if _spent:
		return
	_spent = true
	remove_from_group(GROUP)
	queue_free()


func is_spent() -> bool:
	return _spent


func seconds_left() -> float:
	return maxf(_life_left, 0.0)


## Where it is going. Read by the gate to check a star is a ring across the threat
## axis rather than a cone down it.
func velocity() -> Vector3:
	return _velocity


## Throw a star of `count` flares from `origin`, spread around `axis`.
##
## The star is a ring *perpendicular to the threat axis* rather than a cone along
## it: a missile arriving down that axis meets the whole ring edge-on, which is the
## shape that actually blocks something. A cone pointed at it would be a line of
## flares the missile flies between. `flare/forward_bias` leans the ring towards the
## threat so the wall is thrown out to meet it rather than dropped in place.
static func burst(world: Node3D, origin: Vector3, axis: Vector3, flare_side: int,
		count: int) -> Array[Flare]:
	var thrown: Array[Flare] = []
	if world == null or count <= 0:
		return thrown
	var forward := axis.normalized()
	if forward.length_squared() < 0.5:
		forward = Vector3.FORWARD
	var frame := FlightGeometry.basis_from_forward(forward)
	var bias := clampf(Tuning.num("flare/forward_bias"), 0.0, 1.0)

	for i in count:
		var angle := TAU * float(i) / float(count)
		var outward := frame.x * cos(angle) + frame.y * sin(angle)
		var direction := (outward * (1.0 - bias) + forward * bias).normalized()
		var flare := Flare.new()
		flare.name = "Flare"
		world.add_child(flare)
		flare.launch(origin, direction, flare_side)
		thrown.append(flare)
	return thrown


## The first flare of the opposing side that the swept segment a→b touches, or
## null. Found through the group rather than a registry, because flares free
## themselves and a hand-kept list would rot (ADR 0049's rule for shootable sets).
static func intercept(tree: SceneTree, a: Vector3, b: Vector3, missile_side: int) -> Flare:
	if tree == null:
		return null
	var best: Flare = null
	var best_t := 2.0
	for node in tree.get_nodes_in_group(GROUP):
		var flare := node as Flare
		if flare == null or flare.is_spent() or flare.side == missile_side:
			continue
		var t := FlightGeometry.segment_sphere_entry(a, b, flare.position, flare.radius)
		if t >= 0.0 and t < best_t:
			best_t = t
			best = flare
	return best
