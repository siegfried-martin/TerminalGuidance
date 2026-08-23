class_name TargetShip
extends Node3D
## The dumb enemy target. Drifts slowly in a straight line and turns around at the
## edge of its patrol box. Nothing else — blockers, return fire and the interrupt
## are POC steps 7 and 8, not this one.
##
## Its collision radius is a plain number rather than a physics shape: the missile
## hit test is a swept segment against a sphere (see FlightGeometry), which does
## not tunnel and does not need the physics server to run headless.

var radius: float = 0.0

var _drift_direction: Vector3 = Vector3.FORWARD
var _patrol_half_extent: float = 0.0
var _mesh: MeshInstance3D
var _material: StandardMaterial3D


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	_mesh = MeshInstance3D.new()
	_mesh.name = "Hull"
	_mesh.mesh = BoxMesh.new()
	_mesh.material_override = _material
	add_child(_mesh)

	_apply_tuning()
	Tuning.reloaded.connect(_apply_tuning)


func _apply_tuning() -> void:
	radius = Tuning.num("enemy/radius")
	_patrol_half_extent = Tuning.num("enemy/patrol_half_extent")
	(_mesh.mesh as BoxMesh).size = Vector3.ONE * radius * 1.6
	_material.albedo_color = Tuning.color("enemy/hull_color")
	_material.emission_enabled = true
	_material.emission = Tuning.color("enemy/hull_color")
	_material.emission_energy_multiplier = Tuning.num("enemy/hull_emission")


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


func set_drift_direction(direction: Vector3) -> void:
	_drift_direction = direction.normalized()
