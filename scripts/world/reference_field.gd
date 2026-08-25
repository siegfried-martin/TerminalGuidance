class_name ReferenceField
extends Node3D
## Scattered chunks of rock: a speed and distance reference, and — since ADR 0038
## — an obstacle course. A missile that touches one dies.
##
## Hits are swept-segment sphere tests against a plain array of centres and radii.
## There is still no physics body, no `Area3D` and no `CollisionShape3D` anywhere
## in the arena; ADR 0032's mechanism rule is intact and only its "keep the rocks
## outside the engagement volume" placement rule was superseded.
##
## On the LOD/collision invariant in CLAUDE.md: these are real meshes that exist in
## full at every distance, so querying them is legitimate. The invariant governs
## distant *background-layer* objects — planets and stations that are a billboard
## until swapped in. Nothing here is one of those. Do not extend this pattern to
## anything that has a far-away stand-in.
##
## Placement is seeded, so the arena is identical between runs and a headless test
## can assert against it.

var _multi: MultiMeshInstance3D
## Parent-relative rock centres and hit radii, rebuilt with the mesh. Kept as flat
## arrays rather than nodes because the only question ever asked of them is a
## distance test, and because a rebuild must not orphan scene-tree state.
var _centres: PackedVector3Array = PackedVector3Array()
var _radii: PackedFloat32Array = PackedFloat32Array()
var _collide: bool = false


func _ready() -> void:
	_multi = MultiMeshInstance3D.new()
	_multi.name = "Rocks"
	_multi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_multi)
	rebuild()
	Tuning.reloaded.connect(rebuild)


func rebuild() -> void:
	_centres.clear()
	_radii.clear()
	_collide = Tuning.flag("arena/rock_collision")

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
	var radius_scale := Tuning.num("arena/rock_hit_radius_scale")

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

		# `size.length() * 0.5` is the box's bounding sphere. Scaling it down by the
		# tuned factor trades the corners away: at 0.55 the sphere sits near the
		# inscribed one, so a missile can clip a rock's silhouette and live. A
		# rotation-exact box test is the ADR 0032 escape hatch if that ever matters.
		_centres.append(transform * origin)
		_radii.append(size.length() * 0.5 * radius_scale)

	_multi.multimesh = mm


## Does the swept segment a→b touch a rock? Returns the rock's centre, or the
## sentinel `Vector3.INF` for a clean pass — the caller wants the impact point for
## the detonation flash, and a nullable Vector3 costs an allocation per frame.
##
## `a` and `b` must be in this node's parent frame, like `Missile.position`. That
## is the floating-origin rule (ADR 0020): a recentre moves the shared parent and
## leaves both sides of the comparison valid.
func hit_test(a: Vector3, b: Vector3) -> Vector3:
	if not _collide:
		return Vector3.INF
	for i in _centres.size():
		if FlightGeometry.segment_hits_sphere(a, b, _centres[i], _radii[i]):
			return _centres[i]
	return Vector3.INF


## Rock `index`'s centre and hit radius in the parent frame. These exist for the
## headless gate, which has to aim a segment at a rock it can name; nothing in the
## game reads them.
func rock_centre(index: int) -> Vector3:
	return _centres[index]


func rock_radius(index: int) -> float:
	return _radii[index]


func rock_count() -> int:
	return 0 if _multi.multimesh == null else _multi.multimesh.instance_count


## How many rocks a missile can actually hit — zero when collision is tuned off,
## which is what the headless gate asserts against.
func hittable_count() -> int:
	return _centres.size() if _collide else 0
