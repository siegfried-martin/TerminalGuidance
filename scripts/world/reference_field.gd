class_name ReferenceField
extends Node3D
## Scattered chunks of rock, so speed and distance are legible in empty space.
##
## Visual only — no physics body, nothing queryable. That is the LOD/collision
## invariant (ADR 0020's sibling in CLAUDE.md) applied early: the moment something
## in the arena is raycast-able but shouldn't be, the resulting bug looks like a
## physics bug and is not.
##
## Placement is seeded, so the arena is identical between runs and a headless test
## can assert against it.
##
## `rock_inner_radius` is tuned to sit *outside* the engagement volume. Rocks
## inside it would read as cover and as obstacles a missile should hit — and since
## they have no collision, flying straight through one is exactly the bug the
## invariant above is meant to prevent. Reference geometry stays at the edges;
## near-field speed cues come from the marker lattice.

var _multi: MultiMeshInstance3D


func _ready() -> void:
	_multi = MultiMeshInstance3D.new()
	_multi.name = "Rocks"
	_multi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_multi)
	rebuild()
	Tuning.reloaded.connect(rebuild)


func rebuild() -> void:
	var count := Tuning.integer("arena/rock_count")
	var inner := Tuning.num("arena/rock_inner_radius")
	var outer := Tuning.num("arena/rock_outer_radius")
	var slab := Tuning.num("arena/rock_slab_half_height")
	if count <= 0 or outer <= inner:
		_multi.multimesh = null
		return

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Tuning.color("arena/rock_color")
	mat.roughness = 1.0

	var rock := BoxMesh.new()
	rock.size = Vector3.ONE
	rock.material = mat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = rock
	mm.instance_count = count

	var rng := RandomNumberGenerator.new()
	rng.seed = Tuning.integer("arena/rock_seed")
	var min_size := Tuning.num("arena/rock_min_size")
	var max_size := Tuning.num("arena/rock_max_size")

	for i in count:
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(inner, outer)
		var origin := Vector3(
			cos(angle) * distance,
			rng.randf_range(-slab, slab),
			sin(angle) * distance,
		)
		var rotation_basis := Basis.from_euler(Vector3(
			rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU)))
		var size := Vector3(
			rng.randf_range(min_size, max_size),
			rng.randf_range(min_size, max_size),
			rng.randf_range(min_size, max_size),
		)
		mm.set_instance_transform(i, Transform3D(rotation_basis.scaled(size), origin))
	_multi.multimesh = mm


func rock_count() -> int:
	return 0 if _multi.multimesh == null else _multi.multimesh.instance_count
