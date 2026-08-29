class_name Planet
extends Node3D
## A planet, sitting below the layer fights happen in (ADR 0061).
##
## The placement is the design; the sphere is a placeholder. Three reasons it is
## down there, none of which depend on the others: it keeps ADR 0012's landing
## sequence from arming while the player manoeuvres, without adding the
## confirmation prompt that ADR forbids; nothing rolls, so there is an
## authoritative up to place things against (ADR 0045); and down is where a planet
## goes for anyone who has experienced gravity.
##
## It does not cost ADR 0012 its spatial dimension — a missile aimed downward still
## craters, which is what gave fuse-as-range a third axis. What changed is that
## reaching the surface is a choice about where you point.
##
## The approach envelope is POC step 4 and is not here yet. This is the placement.

var _body: MeshInstance3D


func _ready() -> void:
	_body = MeshInstance3D.new()
	_body.name = "Body"
	# Generated rather than authored, and replaced in place when real art exists
	# (ADR 0030). No code below knows the difference.
	_body.mesh = SphereMesh.new()
	_body.material_override = StandardMaterial3D.new()
	add_child(_body)
	rebuild()
	Tuning.reloaded.connect(rebuild)


func rebuild() -> void:
	var radius := Tuning.num("exploration/planet_radius")
	var mesh := _body.mesh as SphereMesh
	mesh.radius = radius
	mesh.height = radius * 2.0
	# Enough segments that the horizon reads as a curve at close range rather than
	# as a polygon, which is the one thing a placeholder sphere has to get right.
	mesh.radial_segments = 48
	mesh.rings = 24

	var mat := _body.material_override as StandardMaterial3D
	mat.albedo_color = Tuning.color("exploration/planet_color")
	mat.emission_enabled = true
	mat.emission = Tuning.color("exploration/planet_color")
	# Findable from across the disc without being a light source: a system's one
	# landmark has to read at 1.7 km with nothing else lit down there.
	mat.emission_energy_multiplier = Tuning.num("exploration/planet_emission")
	mat.roughness = 0.9

	# Parent-relative, so recentring the world is a move of the parent and nothing
	# else (ADR 0020).
	position = Vector3(0.0, -Tuning.num("exploration/planet_center_depth"), 0.0)


## The top of the planet, which is the number the disc's floor has to clear and the
## one a landing approach will eventually be measured from.
func surface_height() -> float:
	return position.y + Tuning.num("exploration/planet_radius")


func radius() -> float:
	return Tuning.num("exploration/planet_radius")
