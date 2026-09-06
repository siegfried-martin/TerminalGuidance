class_name TargetShip
extends Node3D
## The enemy target: a gray-box hull with destructible components bolted to it.
##
## It drifts in a straight line, turns at the edge of its patrol box, answers an
## incoming missile with a star of flares on a roll of `enemy/blocker_chance`
## (ADR 0051), and — on a long timer — sends one guided missile at the player.
##
## That last one is **the interrupt** (POC step 8), and it is the most dangerous
## thing in the build for the target experience. It is telegraphed a long way in
## advance rather than announced as it happens, because `CLAUDE.md` is explicit
## that stress here is a spike and never ambient: an interrupt you can miss is not
## a spike, it is dread. See `EnemyMissile` for the two Pillar 2 rules it honours.
##
## `enemy/interrupt_interval_seconds = 0` removes the layer entirely, which is how
## a clean reading of the steps before it is still obtainable.
##
## This is not an AI and must not become one. The blockers are a range test and a
## roll; the interrupt is a timer. Neither leads, chooses a moment, or holds fire —
## an NPC making decisions about the player is the shape ADR 0013 and ADR 0014
## keep out of this game.
##
## What is new is the components (ADR 0042). Each one carries a pool of hit points
## and every weapon spends a damage number against it; it darkens as the pool
## drains and goes up with the missile's own detonation flash when it empties.
## The pool replaced a count of hits when the turret arrived (ADR 0049) — four
## weapons with four different damages cannot share a counter. ADR 0042's
## behaviour is unchanged; only the currency is.
## They exist to answer a feel question — whether a target with several small
## things worth aiming at beats one big thing worth hitting — and they are the
## reason the hull is built out of parts now rather than being a cube. A cube
## gives the eye nothing to aim at, so "did I aim, or did I merely arrive?" is
## unanswerable, and that is the question a target-practice loop has to settle.
##
## Nothing here is a physics shape: the missile test is a swept segment (see
## FlightGeometry), which does not tunnel and runs headless. The hull is hit as the
## boxes it is drawn from, and the components as spheres mounted proud of it —
## **whichever the segment reaches FIRST wins** (ADR 0043).
##
## The first version of this got that wrong in a way worth remembering. It wrapped
## the whole ship in one 9 m sphere and tested the components before it. But the
## sphere enclosed every component, so it always resolved first and no component
## was ever reachable — the ordering was decorative and the bug presented as "my
## aim can't be that bad". Test order cannot substitute for geometry.

## `destroyed` is false for the darkening hit and true for the killing one.
signal component_damaged(index: int, position: Vector3, destroyed: bool)
## Raised `enemy/interrupt_warning_lead_seconds` BEFORE the launch, not at it.
signal interrupt_warned()
signal interrupt_launched(missile: EnemyMissile)

var radius: float = 0.0

var _drift_direction: Vector3 = Vector3.FORWARD
var _patrol_half_extent: float = 0.0
var _parts: Node3D
var _components: Node3D
var _hull_material: StandardMaterial3D

## Countermeasures. The roll happens ONCE per incoming missile, not once per frame
## — at 60 fps a per-frame roll of 0.5 fires on the first frame every time, and the
## tuned chance would mean nothing at all.
var _blocker_cooldown: float = 0.0
var _rolled_for: Dictionary = {}

## The interrupt's clock. `_warned` makes the telegraph fire once per cycle rather
## than once per frame for the whole lead.
var _interrupt_elapsed: float = 0.0
var _warned: bool = false
## Who the interrupt is aimed at. Assigned by the arena; without it nothing fires.
var player: Mothership

## Component state, parallel arrays indexed together. Offsets are in the ship's own
## frame, so the spin and the drift both come for free.
var _component_offsets: PackedVector3Array = PackedVector3Array()
var _component_damage: PackedFloat32Array = PackedFloat32Array()
var _component_respawn: PackedFloat32Array = PackedFloat32Array()
var _component_meshes: Array[MeshInstance3D] = []
var _component_materials: Array[StandardMaterial3D] = []
var _component_hit_radius: float = 0.0
var _component_hit_points: float = 1.0

## The hull's own hit volumes, one per drawn part: {offset, orientation, half}
## in the ship's frame. Boxes, tested with the exact slab method, so the hull is
## as solid as it looks rather than as solid as a sphere around it.
var _hull_volumes: Array[Dictionary] = []
## A sphere enclosing every part and every component, derived rather than tuned.
## Purely a broad-phase reject — a tuned value here could be set too small and
## would silently make the nose unhittable.
var _bound_radius: float = 0.0


func _ready() -> void:
	_parts = Node3D.new()
	_parts.name = "Parts"
	add_child(_parts)

	_components = Node3D.new()
	_components.name = "Components"
	add_child(_components)

	_apply_tuning()
	Tuning.reloaded.connect(_apply_tuning)


# --- construction ------------------------------------------------------------

func _apply_tuning() -> void:
	radius = Tuning.num("enemy/radius")
	_patrol_half_extent = Tuning.num("enemy/patrol_half_extent")
	_component_hit_points = maxf(Tuning.num("enemy/component_hit_points"), 0.001)
	_component_hit_radius = Tuning.num("enemy/component_hit_radius")
	_build_hull()
	_build_components()
	_recompute_bound()


## A fuselage, a nose cone, two wings and a fin. Primitives only (ADR 0030) — the
## point is a silhouette with a front and a back, so the player can tell which way
## the thing is facing and where its parts are.
func _build_hull() -> void:
	for child in _parts.get_children():
		child.free()
	_hull_volumes.clear()

	_hull_material = StandardMaterial3D.new()
	_hull_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_hull_material.albedo_color = Tuning.color("enemy/hull_color")
	_hull_material.emission_enabled = true
	_hull_material.emission = Tuning.color("enemy/hull_color")
	_hull_material.emission_energy_multiplier = Tuning.num("enemy/hull_emission")

	var length := Tuning.num("enemy/hull_length")
	var width := Tuning.num("enemy/hull_width")
	var height := Tuning.num("enemy/hull_height")

	var fuselage := BoxMesh.new()
	fuselage.size = Vector3(width, height, length)
	_add_part("Fuselage", fuselage, Vector3.ZERO, Basis.IDENTITY)
	_add_volume(Vector3.ZERO, Basis.IDENTITY, fuselage.size * 0.5)

	# CylinderMesh runs along +Y, so a quarter turn about X lays it along -Z — the
	# ship's forward. A zero top radius makes it a cone.
	var nose := CylinderMesh.new()
	nose.top_radius = 0.0
	nose.bottom_radius = maxf(width, height) * 0.5
	nose.height = Tuning.num("enemy/nose_length")
	nose.radial_segments = 10
	var nose_at := Vector3(0.0, 0.0, -(length + nose.height) * 0.5)
	_add_part("Nose", nose, nose_at, Basis.from_euler(Vector3(-PI * 0.5, 0.0, 0.0)))
	# The one approximation left: a cone hit as a box. Inset to 0.6 of the base
	# radius so the box stays INSIDE the cone rather than around it — under-reaching
	# forgives, over-reaching invents hull where the screen shows empty space, and
	# only one of those is a bug the player can see.
	_add_volume(nose_at, Basis.IDENTITY,
		Vector3(nose.bottom_radius * 0.6, nose.bottom_radius * 0.6, nose.height * 0.5))

	var span := Tuning.num("enemy/wing_span")
	var chord := Tuning.num("enemy/wing_chord")
	var thickness := Tuning.num("enemy/wing_thickness")
	var wing := BoxMesh.new()
	wing.size = Vector3(span, thickness, chord)
	var wing_at := Vector3(0.0, 0.0, length * 0.15)
	_add_part("Wings", wing, wing_at, Basis.IDENTITY)
	_add_volume(wing_at, Basis.IDENTITY, wing.size * 0.5)

	var fin := BoxMesh.new()
	fin.size = Vector3(thickness, Tuning.num("enemy/fin_height"), chord * 0.6)
	var fin_at := Vector3(
		0.0, (height + Tuning.num("enemy/fin_height")) * 0.5, length * 0.3)
	_add_part("Fin", fin, fin_at, Basis.IDENTITY)
	_add_volume(fin_at, Basis.IDENTITY, fin.size * 0.5)


## Register a hit volume for a drawn part. Called beside `_add_part` rather than
## inside it, because the nose is the one part whose hit box is deliberately not
## its drawn bounds and the difference should be visible at the call site.
func _add_volume(offset: Vector3, orientation: Basis, half_extents: Vector3) -> void:
	_hull_volumes.append({
		"offset": offset, "orientation": orientation, "half": half_extents})


func _add_part(part_name: String, mesh: Mesh, offset: Vector3, orientation: Basis) -> void:
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	instance.material_override = _hull_material
	instance.transform = Transform3D(orientation, offset)
	_parts.add_child(instance)


## Cylinders ringed around the fuselage, spread along its length so no two sit on
## the same line of approach. Placement is deterministic from tuning: nothing here
## is random, so a practice run is repeatable and the headless gate can name a
## component and aim at it.
func _build_components() -> void:
	for child in _components.get_children():
		child.free()
	_component_offsets.clear()
	_component_damage.clear()
	_component_respawn.clear()
	_component_meshes.clear()
	_component_materials.clear()

	var count := maxi(Tuning.integer("enemy/component_count"), 0)
	if count == 0:
		return

	var mount_radius := Tuning.num("enemy/component_mount_radius")
	var component_radius := Tuning.num("enemy/component_radius")
	var component_length := Tuning.num("enemy/component_length")
	var hull_length := Tuning.num("enemy/hull_length")
	var base_color := Tuning.color("enemy/component_color")

	for i in count:
		# Half-step offset so the ring sits at the fuselage's corners rather than on
		# its axes: on-axis, a component shares a line of approach with the wings
		# (which are wide and flat) or the fin, and is shadowed by them.
		var angle := TAU * (float(i) + 0.5) / float(count)
		# Spread along the hull as well as around it: -0.3 to +0.3 of the length,
		# so the ring is a helix and every component has a clear approach.
		var along := hull_length * (float(i) / float(maxi(count - 1, 1)) - 0.5) * 0.6
		var offset := Vector3(cos(angle) * mount_radius, sin(angle) * mount_radius, along)

		var mesh := CylinderMesh.new()
		mesh.top_radius = component_radius
		mesh.bottom_radius = component_radius
		mesh.height = component_length
		mesh.radial_segments = 10

		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		material.albedo_color = base_color
		material.emission_enabled = true
		material.emission = base_color
		material.emission_energy_multiplier = Tuning.num("enemy/component_emission")

		var instance := MeshInstance3D.new()
		instance.name = "Component%d" % i
		instance.mesh = mesh
		instance.material_override = material
		# Laid along the hull, like the nose cone.
		instance.transform = Transform3D(
			Basis.from_euler(Vector3(-PI * 0.5, 0.0, 0.0)), offset)
		_components.add_child(instance)

		_component_offsets.append(offset)
		_component_damage.append(0.0)
		_component_respawn.append(0.0)
		_component_meshes.append(instance)
		_component_materials.append(material)


## The broad-phase sphere, derived from what was actually built. Nothing tuned:
## a hand-set bound that is a metre too small makes the nose silently unhittable,
## and there would be no error anywhere to find.
func _recompute_bound() -> void:
	_bound_radius = 0.0
	for volume in _hull_volumes:
		# `offset + half` is the wrong corner whenever the offset and the half-extent
		# disagree in sign — it lands *inside* the box and under-reports. The furthest
		# any corner can be is |offset| + |half|, whatever the orientation.
		_bound_radius = maxf(_bound_radius,
			Vector3(volume["offset"]).length() + Vector3(volume["half"]).length())
	for offset in _component_offsets:
		_bound_radius = maxf(_bound_radius, offset.length() + _component_hit_radius)


# --- flight ------------------------------------------------------------------

func _process(delta: float) -> void:
	position += velocity() * delta
	# Parent-relative bounds, so a world recentre does not teleport the patrol box.
	if absf(position.x) > _patrol_half_extent:
		_drift_direction.x = -signf(position.x)
		_drift_direction = _drift_direction.normalized()
	if absf(position.z) > _patrol_half_extent:
		_drift_direction.z = -signf(position.z)
		_drift_direction = _drift_direction.normalized()
	rotate_y(deg_to_rad(Tuning.num("enemy/spin_deg_per_sec")) * delta)
	_tick_respawns(delta)
	_tick_blockers(delta)
	_tick_interrupt(delta)


## Destroyed components come back after a delay so a practice run does not run out
## of things to shoot mid-session. Zero disables it and the target stays stripped.
func _tick_respawns(delta: float) -> void:
	var window := Tuning.num("enemy/component_respawn_seconds")
	if window <= 0.0:
		return
	for i in _component_respawn.size():
		if _component_respawn[i] <= 0.0:
			continue
		_component_respawn[i] = maxf(_component_respawn[i] - delta, 0.0)
		if _component_respawn[i] <= 0.0:
			_component_damage[i] = 0.0
			_component_meshes[i].visible = true
			_apply_component_shade(i)


## Answer an approaching missile with a star of flares, once, on a roll.
##
## "Approaching" is a range test, not a closing-velocity test: the player fires from
## standoff and everything they fire is coming at this ship, so the interesting
## question is when the answer is thrown, not whether it is warranted. That is
## `enemy/blocker_trigger_range`, and it is the whole difficulty of the mechanic —
## thrown too early the flares have dispersed, too late and there is no room to fly
## around them.
##
## Set `enemy/blocker_chance` to 0 to take this layer out of a test run entirely.
func _tick_blockers(delta: float) -> void:
	_blocker_cooldown = maxf(_blocker_cooldown - delta, 0.0)
	if not is_inside_tree():
		return
	var trigger_range := Tuning.num("enemy/blocker_trigger_range")
	for node in get_tree().get_nodes_in_group("player_missile"):
		var threat := node as Node3D
		if threat == null or not is_instance_valid(threat):
			continue
		var id := threat.get_instance_id()
		if _rolled_for.has(id) or position.distance_to(threat.position) > trigger_range:
			continue
		# Rolled for even when the launcher is still cooling: one answer per
		# missile, whether or not this ship was in a position to give it.
		_rolled_for[id] = true
		if _blocker_cooldown > 0.0:
			continue
		if not rolls_a_blocker(Tuning.num("enemy/blocker_chance")):
			continue
		deploy_blocker(threat.position - position)
	_prune_rolls()


## Throw the star. Public so the headless gate can ask for one without having to
## win a coin toss.
func deploy_blocker(towards: Vector3) -> Array[Flare]:
	_blocker_cooldown = Tuning.num("enemy/blocker_cooldown_seconds")
	# The star carries this ship's drift with it (ADR 0055), for the same reason the
	# player's does: a wall dropped in place by a moving ship is behind it at once.
	return Flare.burst(get_parent_node_3d(), position, towards, Flare.Side.ENEMY,
		Tuning.integer("enemy/blocker_flare_count"), velocity())


## One roll, isolated so the gate can check the tuned chance over many trials
## without simulating a missile for each one.
static func rolls_a_blocker(chance: float) -> bool:
	return randf() < clampf(chance, 0.0, 1.0)


## Missiles that have been answered but no longer exist. Left alone the dictionary
## would grow for the whole session — small, but it is a leak with a name.
func _prune_rolls() -> void:
	for id: int in _rolled_for.keys():
		if not is_instance_id_valid(id):
			_rolled_for.erase(id)


func blocker_cooldown_remaining() -> float:
	return _blocker_cooldown


# --- the interrupt -----------------------------------------------------------

## One guided missile at the player, on a timer, telegraphed first.
##
## The scope doc is emphatic that this parameter is "the single easiest way to turn
## a relaxed game into a stressful one", and that the good value is probably much
## larger than intuition suggests. It ships at the specified 60 s expecting to be
## raised. `enemy/interrupt_interval_seconds = 0` disables it outright.
func _tick_interrupt(delta: float) -> void:
	var interval := Tuning.num("enemy/interrupt_interval_seconds")
	if interval <= 0.0 or player == null or not is_instance_valid(player):
		_interrupt_elapsed = 0.0
		_warned = false
		return

	_interrupt_elapsed += delta
	var lead := minf(Tuning.num("enemy/interrupt_warning_lead_seconds"), interval)
	if not _warned and _interrupt_elapsed >= interval - lead:
		# Telegraphed BEFORE it happens, so a player mid-ride can still detonate on
		# target and make the turret in time. Pillar 2: it must be possible to win
		# both. That constrains the lead against a typical remaining ride.
		_warned = true
		interrupt_warned.emit()
	if _interrupt_elapsed < interval:
		return

	_interrupt_elapsed = 0.0
	_warned = false
	launch_interrupt()


## Send one. Public so the gate can ask for an interrupt without waiting a minute.
func launch_interrupt() -> EnemyMissile:
	var world := get_parent_node_3d()
	if world == null or player == null or not is_instance_valid(player):
		return null
	var missile := EnemyMissile.new()
	missile.name = "EnemyMissile"
	world.add_child(missile)
	missile.launch(position, player, EnemyMissile.random_error())
	interrupt_launched.emit(missile)
	return missile


## Seconds until the next interrupt, or -1 when the layer is switched off.
func seconds_to_interrupt() -> float:
	var interval := Tuning.num("enemy/interrupt_interval_seconds")
	if interval <= 0.0 or player == null:
		return -1.0
	return maxf(interval - _interrupt_elapsed, 0.0)


## Has the warning for the next one already gone out?
func interrupt_warned_already() -> bool:
	return _warned


## How fast this ship is moving, in the parent frame. Its flares inherit it.
##
## A fraction of its hull class's top speed, never an absolute. The old absolute
## 20 m/s was set against a 34 m/s player ship; at the corrected taxi speed of 15.5
## it would let an enemy of the same class simply LEAVE, outrunning the ship sent to
## fight it with no rule anywhere saying it may (EXPLORATION_DESIGN.md invariant 4).
func drift_speed() -> float:
	return tuned_drift_speed()


## The same number without needing an instance, so a test — or anything sizing an
## arena against it — reads it from one place rather than restating the formula.
static func tuned_drift_speed() -> float:
	return HullClass.max_speed(tuned_hull_class()) \
		* clampf(Tuning.num("enemy/drift_speed_fraction"), 0.0, 0.95)


static func tuned_hull_class() -> HullClass.Kind:
	return HullClass.from_name(Tuning.text("enemy/hull_class"))


func velocity() -> Vector3:
	return _drift_direction * drift_speed()


func set_drift_direction(direction: Vector3) -> void:
	_drift_direction = direction.normalized()


# --- damage ------------------------------------------------------------------

## What the swept segment a→b hits first, as
## `{"hit": bool, "component": int, "point": Vector3}` — `component` is -1 for the
## hull. Coordinates are in this node's parent frame, like `Missile.position`
## (ADR 0020); the offsets below are ship-local, so the spin and the drift are
## already accounted for by the time they are transformed out.
##
## **Nearest along the segment wins.** Not "components first": components sit proud
## of the hull, so the geometry decides, and a shot aimed at one reaches it before
## the hull it is bolted to. Ordering the tests instead was the bug in the first
## version — see the note at the top of this file.
func hit_test(a: Vector3, b: Vector3) -> Dictionary:
	var miss := {"hit": false, "component": -1, "point": Vector3.ZERO}
	if not FlightGeometry.segment_hits_sphere(a, b, position, _bound_radius):
		return miss

	var best := 2.0
	var best_component := -1

	for i in _component_offsets.size():
		if not is_component_alive(i):
			continue
		var t := FlightGeometry.segment_sphere_entry(
			a, b, component_position(i), _component_hit_radius)
		if t >= 0.0 and t < best:
			best = t
			best_component = i

	for volume in _hull_volumes:
		var t := FlightGeometry.segment_box_entry(a, b,
			transform * Vector3(volume["offset"]),
			transform.basis.orthonormalized() * (volume["orientation"] as Basis),
			volume["half"])
		if t >= 0.0 and t < best:
			best = t
			best_component = -1

	if best > 1.0:
		return miss
	return {"hit": true, "component": best_component,
		"point": a + (b - a) * best, "t": best}


## Spend `amount` of damage on component `index`. Returns true if that emptied it.
##
## Every weapon goes through here with its own number, which is the whole reason
## the pool replaced a hit count (ADR 0049): an autocannon round, a beam's tick and
## a missile warhead are not interchangeable, and a counter cannot tell them apart.
## A beam calls this every frame with damage-per-second times delta, so the
## darkening is continuous rather than stepped, and that is intended.
func damage_component(index: int, amount: float) -> bool:
	if index < 0 or index >= _component_damage.size():
		return false
	if amount <= 0.0 or not is_component_alive(index):
		return false

	_component_damage[index] = minf(
		_component_damage[index] + amount, _component_hit_points)
	var destroyed := not is_component_alive(index)
	if destroyed:
		_component_meshes[index].visible = false
		_component_respawn[index] = Tuning.num("enemy/component_respawn_seconds")
	else:
		_apply_component_shade(index)
	component_damaged.emit(index, component_position(index), destroyed)
	return destroyed


## Spend a blast's damage on every live component within `radius` of `centre`,
## falling off with distance (ADR 0004). Returns how many it touched.
##
## `except_index` is the component a direct hit already paid for — a warhead that
## landed on a component should not then also splash that same component, which
## would make a direct hit quietly worth more than its own damage number. Pass -1
## when nothing was hit directly.
##
## Distance is measured to the component's *surface*, not its centre: a blast that
## reaches the skin of a fuel cell has reached it, and measuring to the middle
## would make bigger components harder to splash than small ones.
func damage_in_radius(centre: Vector3, radius: float, peak: float,
		falloff_power: float, except_index: int = -1) -> int:
	if radius <= 0.0 or peak <= 0.0:
		return 0
	var touched := 0
	for i in _component_offsets.size():
		if i == except_index or not is_component_alive(i):
			continue
		var distance := maxf(
			component_position(i).distance_to(centre) - _component_hit_radius, 0.0)
		var amount := Damage.splash(peak, distance, radius, falloff_power)
		if amount <= 0.0:
			continue
		damage_component(i, amount)
		touched += 1
	return touched


## Darker with every hit taken, so damage is readable at standoff range without a
## health bar. A fresh component is at full colour.
func _apply_component_shade(index: int) -> void:
	var wear := clampf(_component_damage[index] / _component_hit_points, 0.0, 1.0)
	var amount := Tuning.num("enemy/component_damaged_darken") * wear
	var base_color := Tuning.color("enemy/component_color")
	var material := _component_materials[index]
	material.albedo_color = base_color.darkened(amount)
	material.emission = base_color.darkened(amount)
	material.emission_energy_multiplier = \
		Tuning.num("enemy/component_emission") * (1.0 - amount)


# --- readouts ----------------------------------------------------------------

## Component `index`'s centre in the parent frame.
func component_position(index: int) -> Vector3:
	return transform * _component_offsets[index]


## The sphere that encloses every part and every component. Derived, not tuned.
func bound_radius() -> float:
	return _bound_radius


## How far component `index`'s outermost point clears the hull, in metres.
## Positive means it stands proud and a shot down its mounting direction reaches it
## before the hull; negative means it is buried and unaimable *however the tests
## are ordered*, which was the shipped bug (ADR 0043).
##
## Measured as the point's distance outside the nearest hull box, not by comparing
## support functions — a wide flat wing has a far corner along a diagonal, but that
## corner is somewhere else in space and says nothing about whether this particular
## point is inside the wing.
func component_exposure(index: int) -> float:
	var offset := Vector3(_component_offsets[index])
	var outward := Vector3(offset.x, offset.y, 0.0)
	if outward.length_squared() < 0.000001:
		return -_component_hit_radius
	var tip := offset + outward.normalized() * _component_hit_radius

	var clearance := INF
	for volume in _hull_volumes:
		var half: Vector3 = volume["half"]
		var local: Vector3 = (volume["orientation"] as Basis).transposed() \
			* (tip - Vector3(volume["offset"]))
		# Positive on any axis means outside that pair of faces; the largest is how
		# far outside the box the point is.
		clearance = minf(clearance, maxf(absf(local.x) - half.x,
			maxf(absf(local.y) - half.y, absf(local.z) - half.z)))
	return clearance


func component_count() -> int:
	return _component_offsets.size()


## How much of component `index`'s pool is left, 0 to 1. The HUD shows it, and it
## is what the shade is derived from.
func component_health_fraction(index: int) -> float:
	return clampf(1.0 - _component_damage[index] / _component_hit_points, 0.0, 1.0)


## The size of one component's pool. Weapons are tuned against this number, so it
## is worth being able to read it back.
func component_hit_points() -> float:
	return _component_hit_points


func is_component_alive(index: int) -> bool:
	return _component_damage[index] < _component_hit_points


func components_alive() -> int:
	var alive := 0
	for i in _component_damage.size():
		if is_component_alive(i):
			alive += 1
	return alive
