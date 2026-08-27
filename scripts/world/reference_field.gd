class_name ReferenceField
extends Node3D
## Scattered chunks of rock: a speed and distance reference, and — since ADR 0038
## — an obstacle course. A missile that touches one dies.
##
## Each rock is a cluster of 3-6 overlapping ellipsoids: one large lobe with
## smaller ones glued to it, each lobe's centre inside the main lobe so no more
## than half of it protrudes. The clustering is what makes a rock read as a rock
## rather than as a die, and — the actual reason for it — **the drawn shape and
## the hit shape are the same primitives** (ADR 0041). The old single box drew
## corners that nothing could hit, so a missile that visibly clipped a rock flew
## on; there is no such gap here, because there is only one shape.
##
## Hits are swept-segment ellipsoid tests against flat arrays. There is still no
## physics body, no `Area3D` and no `CollisionShape3D` anywhere in the arena;
## ADR 0032's mechanism rule is intact and only its "keep the rocks outside the
## engagement volume" placement rule was superseded.
##
## The test is two-phase because it runs every frame against every rock: one
## bounding-sphere reject per rock, and lobes only for the few that survive it.
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

## Broad phase, one entry per rock: a sphere enclosing the whole cluster.
var _bound_centres: PackedVector3Array = PackedVector3Array()
var _bound_radii: PackedFloat32Array = PackedFloat32Array()
## Index into the lobe arrays where each rock's lobes begin. One longer than the
## rock count, so rock i owns `_lobe_start[i] ..< _lobe_start[i + 1]` and the
## last rock needs no special case.
var _lobe_start: PackedInt32Array = PackedInt32Array()

## Narrow phase. Centres and orientations are in this node's PARENT frame, like
## `Missile.position`; the drawn radii are the ellipsoid's semi-axes as rendered.
var _lobe_centres: PackedVector3Array = PackedVector3Array()
var _lobe_radii: PackedVector3Array = PackedVector3Array()
var _lobe_orientations: Array[Basis] = []

var _collide: bool = false
var _hit_scale: float = 1.0


func _ready() -> void:
	_multi = MultiMeshInstance3D.new()
	_multi.name = "Rocks"
	_multi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_multi)
	rebuild()
	Tuning.reloaded.connect(rebuild)


func rebuild() -> void:
	_bound_centres.clear()
	_bound_radii.clear()
	_lobe_start.clear()
	_lobe_centres.clear()
	_lobe_radii.clear()
	_lobe_orientations.clear()
	_collide = Tuning.flag("arena/rock_collision")
	_hit_scale = Tuning.num("arena/rock_hit_radius_scale")

	var count := Tuning.integer("arena/rock_count")
	var inner := Tuning.num("arena/rock_inner_radius")
	var outer := Tuning.num("arena/rock_outer_radius")
	var slab := Tuning.num("arena/rock_slab_half_height")
	if count <= 0 or outer <= inner:
		_multi.multimesh = null
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = Tuning.integer("arena/rock_seed")
	var min_size := Tuning.num("arena/rock_min_size")
	var max_size := Tuning.num("arena/rock_max_size")
	var lobe_min := maxi(Tuning.integer("arena/rock_lobe_min"), 1)
	var lobe_max := maxi(Tuning.integer("arena/rock_lobe_max"), lobe_min)
	var size_min := Tuning.num("arena/rock_lobe_size_min")
	var size_max := Tuning.num("arena/rock_lobe_size_max")
	var offset_min := Tuning.num("arena/rock_lobe_offset_min")
	var offset_max := Tuning.num("arena/rock_lobe_offset_max")
	var elongation := clampf(Tuning.num("arena/rock_elongation"), 0.0, 0.9)

	# The node's own transform maps local placement into the parent frame. Rotation
	# is taken orthonormalised: a scaled ReferenceField would silently break the
	# ellipsoid tests, and nothing needs one.
	var to_parent := transform
	var to_parent_basis := transform.basis.orthonormalized()

	# Local-space lobe transforms, collected first so the MultiMesh can be sized
	# once. Lobe counts vary per rock, so the total is not known up front.
	var local_transforms: Array[Transform3D] = []

	for i in count:
		_lobe_start.append(_lobe_centres.size())

		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(inner, outer)
		var origin := Vector3(
			cos(angle) * distance,
			rng.randf_range(-slab, slab),
			sin(angle) * distance,
		)
		var main_radius := rng.randf_range(min_size, max_size) * 0.5
		var lobes := rng.randi_range(lobe_min, lobe_max)
		var bound := 0.0

		for lobe in lobes:
			# Lobe 0 is the body of the rock and sits on its origin. The rest hang
			# off it at an offset shorter than the main radius, which is what keeps
			# each one less than half exposed.
			var offset := Vector3.ZERO
			var scale_factor := 1.0
			if lobe > 0:
				var direction := Vector3(
					rng.randf_range(-1.0, 1.0),
					rng.randf_range(-1.0, 1.0),
					rng.randf_range(-1.0, 1.0))
				if direction.length_squared() < 0.0001:
					direction = Vector3.UP
				offset = direction.normalized() \
					* main_radius * rng.randf_range(offset_min, offset_max)
				scale_factor = rng.randf_range(size_min, size_max)

			# Per-axis jitter is what stops the cluster reading as a pile of balls.
			var radii := Vector3(
				rng.randf_range(1.0 - elongation, 1.0 + elongation),
				rng.randf_range(1.0 - elongation, 1.0 + elongation),
				rng.randf_range(1.0 - elongation, 1.0 + elongation),
			) * main_radius * scale_factor
			var orientation := Basis.from_euler(Vector3(
				rng.randf_range(0.0, TAU),
				rng.randf_range(0.0, TAU),
				rng.randf_range(0.0, TAU)))

			local_transforms.append(
				Transform3D(orientation.scaled(radii), origin + offset))
			_lobe_centres.append(to_parent * (origin + offset))
			_lobe_radii.append(radii)
			_lobe_orientations.append(to_parent_basis * orientation)

			# Conservative: the hit scale can be tuned above 1, which grows the
			# ellipsoids past what is drawn, and the bound has to still contain them.
			var reach := offset.length() \
				+ maxf(radii.x, maxf(radii.y, radii.z)) * maxf(_hit_scale, 1.0)
			bound = maxf(bound, reach)

		_bound_centres.append(to_parent * origin)
		_bound_radii.append(bound)

	_lobe_start.append(_lobe_centres.size())

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Tuning.color("arena/rock_color")
	mat.roughness = 1.0

	# Low-poly on purpose: a thousand-plus lobes at full tessellation buys nothing
	# a gray-box arena can use, and the faceting reads as rock.
	var lobe_mesh := SphereMesh.new()
	lobe_mesh.radius = 1.0
	lobe_mesh.height = 2.0
	lobe_mesh.radial_segments = 8
	lobe_mesh.rings = 4
	lobe_mesh.material = mat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = lobe_mesh
	mm.instance_count = local_transforms.size()
	for i in local_transforms.size():
		mm.set_instance_transform(i, local_transforms[i])
	_multi.multimesh = mm


## Does the swept segment a→b touch a rock? Returns the centre of the lobe it hit,
## or the sentinel `Vector3.INF` for a clean pass — the caller wants the impact
## point for the detonation flash, and a nullable Vector3 costs an allocation per
## frame.
##
## `a` and `b` must be in this node's parent frame, like `Missile.position`. That
## is the floating-origin rule (ADR 0020): a recentre moves the shared parent and
## leaves both sides of the comparison valid.
func hit_test(a: Vector3, b: Vector3) -> Vector3:
	if not _collide:
		return Vector3.INF
	for rock in _bound_centres.size():
		if not FlightGeometry.segment_hits_sphere(
				a, b, _bound_centres[rock], _bound_radii[rock]):
			continue
		for lobe in range(_lobe_start[rock], _lobe_start[rock + 1]):
			if FlightGeometry.segment_hits_ellipsoid(a, b, _lobe_centres[lobe],
					_lobe_orientations[lobe], _lobe_radii[lobe] * _hit_scale):
				return _lobe_centres[lobe]
	return Vector3.INF


## Rock `index`'s cluster centre and enclosing radius, in the parent frame. These
## exist for the headless gate, which has to aim a segment at a rock it can name;
## nothing in the game reads them.
func rock_centre(index: int) -> Vector3:
	return _bound_centres[index]


func rock_radius(index: int) -> float:
	return _bound_radii[index]


func rock_count() -> int:
	return _bound_centres.size()


## Total ellipsoids drawn across every rock — one MultiMesh instance each.
func lobe_count() -> int:
	return _lobe_centres.size()


## How many rocks a missile can actually hit — zero when collision is tuned off,
## which is what the headless gate asserts against.
func hittable_count() -> int:
	return _bound_centres.size() if _collide else 0
