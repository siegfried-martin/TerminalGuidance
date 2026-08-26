class_name TargetShip
extends Node3D
## The enemy target: a gray-box hull with destructible components bolted to it.
##
## It still drifts in a straight line and turns at the edge of its patrol box, and
## it still does not shoot — blockers, return fire and the interrupt are POC steps
## 7 and 8, not this one.
##
## What is new is the components (ADR 0042). Each one takes two hits: the first
## darkens it, the second destroys it with the missile's own detonation flash.
## They exist to answer a feel question — whether a target with several small
## things worth aiming at beats one big thing worth hitting — and they are the
## reason the hull is built out of parts now rather than being a cube. A cube
## gives the eye nothing to aim at, so "did I aim, or did I merely arrive?" is
## unanswerable, and that is the question a target-practice loop has to settle.
##
## Everything here is a hit SPHERE, never a physics shape: the missile test is a
## swept segment (see FlightGeometry), which does not tunnel and runs headless.
## The components' spheres are tested before the hull's, so a shot that could
## count as either is credited to the part the player was aiming at.

## `destroyed` is false for the darkening hit and true for the killing one.
signal component_damaged(index: int, position: Vector3, destroyed: bool)

var radius: float = 0.0

var _drift_direction: Vector3 = Vector3.FORWARD
var _patrol_half_extent: float = 0.0
var _parts: Node3D
var _components: Node3D
var _hull_material: StandardMaterial3D

## Component state, parallel arrays indexed together. Offsets are in the ship's own
## frame, so the spin and the drift both come for free.
var _component_offsets: PackedVector3Array = PackedVector3Array()
var _component_hits: PackedInt32Array = PackedInt32Array()
var _component_respawn: PackedFloat32Array = PackedFloat32Array()
var _component_meshes: Array[MeshInstance3D] = []
var _component_materials: Array[StandardMaterial3D] = []
var _component_hit_radius: float = 0.0
var _hits_to_destroy: int = 2


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
	_hits_to_destroy = maxi(Tuning.integer("enemy/component_hits_to_destroy"), 1)
	_component_hit_radius = Tuning.num("enemy/component_hit_radius")
	_build_hull()
	_build_components()


## A fuselage, a nose cone, two wings and a fin. Primitives only (ADR 0030) — the
## point is a silhouette with a front and a back, so the player can tell which way
## the thing is facing and where its parts are.
func _build_hull() -> void:
	for child in _parts.get_children():
		child.free()

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

	# CylinderMesh runs along +Y, so a quarter turn about X lays it along -Z — the
	# ship's forward. A zero top radius makes it a cone.
	var nose := CylinderMesh.new()
	nose.top_radius = 0.0
	nose.bottom_radius = maxf(width, height) * 0.5
	nose.height = Tuning.num("enemy/nose_length")
	nose.radial_segments = 10
	_add_part("Nose", nose,
		Vector3(0.0, 0.0, -(length + nose.height) * 0.5),
		Basis.from_euler(Vector3(-PI * 0.5, 0.0, 0.0)))

	var span := Tuning.num("enemy/wing_span")
	var chord := Tuning.num("enemy/wing_chord")
	var thickness := Tuning.num("enemy/wing_thickness")
	var wing := BoxMesh.new()
	wing.size = Vector3(span, thickness, chord)
	_add_part("Wings", wing, Vector3(0.0, 0.0, length * 0.15), Basis.IDENTITY)

	var fin := BoxMesh.new()
	fin.size = Vector3(thickness, Tuning.num("enemy/fin_height"), chord * 0.6)
	_add_part("Fin", fin,
		Vector3(0.0, (height + Tuning.num("enemy/fin_height")) * 0.5, length * 0.3),
		Basis.IDENTITY)


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
	_component_hits.clear()
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
		var angle := TAU * float(i) / float(count)
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
		_component_hits.append(0)
		_component_respawn.append(0.0)
		_component_meshes.append(instance)
		_component_materials.append(material)


# --- flight ------------------------------------------------------------------

func _process(delta: float) -> void:
	position += _drift_direction * Tuning.num("enemy/drift_speed") * delta
	# Parent-relative bounds, so a world recentre does not teleport the patrol box.
	if absf(position.x) > _patrol_half_extent:
		_drift_direction.x = -signf(position.x)
		_drift_direction = _drift_direction.normalized()
	if absf(position.z) > _patrol_half_extent:
		_drift_direction.z = -signf(position.z)
		_drift_direction = _drift_direction.normalized()
	rotate_y(deg_to_rad(Tuning.num("enemy/spin_deg_per_sec")) * delta)
	_tick_respawns(delta)


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
			_component_hits[i] = 0
			_component_meshes[i].visible = true
			_apply_component_shade(i)


func set_drift_direction(direction: Vector3) -> void:
	_drift_direction = direction.normalized()


# --- damage ------------------------------------------------------------------

## Which component the swept segment a→b touches, or -1 for none. Coordinates are
## in this node's parent frame, like `Missile.position` (ADR 0020) — component
## offsets are ship-local, so the spin and the drift are already accounted for by
## the time they are transformed out.
func hit_test(a: Vector3, b: Vector3) -> int:
	if _component_hit_radius <= 0.0:
		return -1
	for i in _component_offsets.size():
		if _component_hits[i] >= _hits_to_destroy:
			continue
		if FlightGeometry.segment_hits_sphere(
				a, b, component_position(i), _component_hit_radius):
			return i
	return -1


## Put a hit on component `index`. Returns true if that hit destroyed it.
func damage_component(index: int) -> bool:
	if index < 0 or index >= _component_hits.size():
		return false
	if _component_hits[index] >= _hits_to_destroy:
		return false

	_component_hits[index] += 1
	var destroyed := _component_hits[index] >= _hits_to_destroy
	if destroyed:
		_component_meshes[index].visible = false
		_component_respawn[index] = Tuning.num("enemy/component_respawn_seconds")
	else:
		_apply_component_shade(index)
	component_damaged.emit(index, component_position(index), destroyed)
	return destroyed


## Darker with every hit taken, so damage is readable at standoff range without a
## health bar. A fresh component is at full colour.
func _apply_component_shade(index: int) -> void:
	var wear := float(_component_hits[index]) / float(_hits_to_destroy)
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


func component_count() -> int:
	return _component_offsets.size()


func component_hits(index: int) -> int:
	return _component_hits[index]


func is_component_alive(index: int) -> bool:
	return _component_hits[index] < _hits_to_destroy


func components_alive() -> int:
	var alive := 0
	for i in _component_hits.size():
		if _component_hits[i] < _hits_to_destroy:
			alive += 1
	return alive
