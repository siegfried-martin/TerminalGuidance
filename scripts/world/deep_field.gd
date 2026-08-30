class_name DeepField
extends Node3D
## What is out there past the edge of the map: a starfield, bodies scattered beyond
## the boundary, and a haze of near dust just outside the wall.
##
## **This exists because a bounded volume with nothing outside it cannot be moved
## through.** Once a boundary face fills the view it is one flat colour, and a ship at
## 160 m/s and a ship at rest look identical — which is exactly the report this was
## built from. Motion is only legible against things at *different distances*, so the
## field is deliberately three layers rather than one:
##
##     dust     just past the wall      strong parallax — this is the speed cue
##     bodies   kilometres out          slow parallax and a sense of scale
##     stars    effectively at infinity orientation only; they ride with the player
##
## **It is background layer, and nothing in it is queryable.** No physics body, no
## `Area3D`, no hit test, and no accessor that hands out a position. That is
## CLAUDE.md's LOD/collision invariant, and this is exactly the kind of object it was
## written about: distant scenery that must never be raycast, overlap-tested or
## treated as a place. The counts below exist for the headless gate and for the HUD,
## and nothing else reads them.
##
## Placement is seeded, so the sky is identical between runs and a test can assert
## against it, and everything is scattered around the map's **spine** — so the view
## is furnished along the whole route rather than only near the origin.

## How coarse a body is. Low-poly on purpose: these are kilometres away and a smooth
## sphere buys nothing at that range. Infrastructure, not feel.
const BODY_RINGS := 6
const BODY_SEGMENTS := 12
## How many times a scatter will retry before giving up on one instance. A rejected
## sample is one that landed inside playable space, or too far outside it to belong to
## its layer; giving up quietly beats an unbounded loop on a bad tuning.
const SCATTER_TRIES := 24

## Rides with the player, so the stars never get closer. Its children are placed once
## and the node is moved, rather than the stars being replaced every frame.
var _sky: Node3D
var _stars: MultiMeshInstance3D
var _bodies: MultiMeshInstance3D
var _dust: MultiMeshInstance3D


func _ready() -> void:
	_sky = Node3D.new()
	_sky.name = "Sky"
	add_child(_sky)
	_stars = MultiMeshInstance3D.new()
	_stars.name = "Stars"
	_stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The sky is behind everything by construction — it is 40 km out — but it is also
	# unshaded and bright, and sorting it against a translucent boundary face is not
	# worth leaving to chance.
	_stars.sorting_offset = -1.0
	_sky.add_child(_stars)
	_bodies = MultiMeshInstance3D.new()
	_bodies.name = "Bodies"
	_bodies.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bodies)
	_dust = MultiMeshInstance3D.new()
	_dust.name = "Dust"
	_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_dust)
	# NOT connected to `Tuning.reloaded`: like the discs and the corridors, this is
	# placed against a layout it does not own, and the map drives the rebuild.


## Move the starfield to wherever the player is. Called every frame by the map.
##
## Only the stars follow. If the bodies followed they would be a painted backdrop and
## would tell the player nothing about their own motion, which is the whole reason
## they are there.
func follow(point: Vector3) -> void:
	if _sky != null:
		_sky.position = point


## Rebuild the whole field around a route, rejecting anything that lands in playable
## space.
##
## `field` is the composed boundary, and it is the only test used: "past the edge" is
## `overshoot`, which already knows about every disc and every corridor. Placing
## against the boundary rather than against the systems is what keeps a body from
## appearing inside a corridor the moment a leg length changes.
func rebuild(spine: PackedVector3Array, field: BoundaryField) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = Tuning.integer("exploration/deep_seed")
	# How far the boundary can be from the route it follows. A sample has to be able to
	# REACH past the wall before it can be tested against it, and the widest thing in
	# the map is a system's own radius — a corridor is half that.
	var edge_span := maxf(Tuning.num("exploration/system_diameter") * 0.5,
		maxf(Tuning.num("exploration/corridor_diameter") * 0.5,
			Tuning.num("exploration/system_floor_depth")))
	_rebuild_stars(rng)
	_rebuild_bodies(rng, spine, field, edge_span)
	_rebuild_dust(rng, spine, field, edge_span)


## Stars on a shell around the player. Drawn as camera-facing quads so a star stays a
## point of light rather than becoming a visible cube at the edge of the frame.
func _rebuild_stars(rng: RandomNumberGenerator) -> void:
	var count := Tuning.integer("exploration/starfield_count")
	var distance := Tuning.num("exploration/starfield_distance")
	var size := Tuning.num("exploration/starfield_size")
	if count <= 0 or distance <= 0.0:
		_stars.multimesh = null
		return
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Tuning.color("exploration/starfield_color")
	quad.material = mat

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = quad
	multi.instance_count = count
	for i in count:
		# Uniform on the sphere: z uniform in [-1, 1] and the angle uniform, which is
		# the one placement that does not pile stars up at the poles.
		var z := rng.randf_range(-1.0, 1.0)
		var a := rng.randf_range(0.0, TAU)
		var r := sqrt(maxf(1.0 - z * z, 0.0))
		var at := Vector3(r * cos(a), z, r * sin(a)) * distance
		# Size and brightness vary together, which is what reads as depth in a field
		# that has none: a dim small star looks further away than a bright large one.
		var bright := rng.randf_range(0.25, 1.0)
		multi.set_instance_transform(i,
			Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * bright), at))
		multi.set_instance_color(i, Color(1.0, 1.0, 1.0, bright))
	_stars.multimesh = multi


## Bodies past the boundary: planets, moons, the big rocks. Lit rather than unshaded,
## so they read as spheres with a terminator instead of as flat discs — a flat disc at
## this distance is indistinguishable from a star and gives no parallax cue at all.
func _rebuild_bodies(rng: RandomNumberGenerator, spine: PackedVector3Array,
		field: BoundaryField, edge_span: float) -> void:
	var count := Tuning.integer("exploration/deep_bodies_count")
	var near := Tuning.num("exploration/deep_bodies_near")
	var far := Tuning.num("exploration/deep_bodies_far")
	var smallest := Tuning.num("exploration/deep_bodies_min_radius")
	var largest := Tuning.num("exploration/deep_bodies_max_radius")
	var spread := clampf(Tuning.num("exploration/deep_bodies_tint_spread"), 0.0, 1.0)
	var base := Tuning.color("exploration/deep_bodies_color")

	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = BODY_SEGMENTS
	sphere.rings = BODY_RINGS
	var mat := StandardMaterial3D.new()
	mat.roughness = 1.0
	mat.vertex_color_use_as_albedo = true
	sphere.material = mat

	var places := scatter(rng, spine, field, count, near, far, edge_span)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = sphere
	multi.instance_count = places.size()
	for i in places.size():
		var radius := rng.randf_range(smallest, maxf(largest, smallest))
		# Squashed a little on one axis and tilted, so a field of them does not read as
		# a bag of identical marbles.
		var shape := Basis.from_euler(Vector3(rng.randf_range(0.0, TAU),
			rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU))).scaled(
			Vector3(radius, radius * rng.randf_range(1.0 - spread * 0.4, 1.0),
				radius))
		multi.set_instance_transform(i, Transform3D(shape, places[i]))
		multi.set_instance_color(i, _tinted(base, rng, spread))
	_bodies.multimesh = multi


## The near haze: small rocks a few hundred metres to a few kilometres past the wall.
##
## This is the layer that actually answers "am I moving". A body 20 km out sweeps a
## degree a minute; a rock 400 m past the boundary sweeps past the canopy, and it does
## it whether the player is looking at the highway, at a planet or at nothing.
func _rebuild_dust(rng: RandomNumberGenerator, spine: PackedVector3Array,
		field: BoundaryField, edge_span: float) -> void:
	var count := Tuning.integer("exploration/deep_dust_count")
	var near := Tuning.num("exploration/deep_dust_near")
	var far := Tuning.num("exploration/deep_dust_far")
	var smallest := Tuning.num("exploration/deep_dust_min_size")
	var largest := Tuning.num("exploration/deep_dust_max_size")

	var rock := SphereMesh.new()
	rock.radius = 0.5
	rock.height = 1.0
	rock.radial_segments = 6
	rock.rings = 3
	var mat := StandardMaterial3D.new()
	mat.roughness = 1.0
	mat.albedo_color = Tuning.color("exploration/deep_dust_color")
	rock.material = mat

	var places := scatter(rng, spine, field, count, near, far, edge_span)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = rock
	multi.instance_count = places.size()
	for i in places.size():
		var size := rng.randf_range(smallest, maxf(largest, smallest))
		var shape := Basis.from_euler(Vector3(rng.randf_range(0.0, TAU),
			rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU))).scaled(
			Vector3(size, size * rng.randf_range(0.5, 1.0),
				size * rng.randf_range(0.6, 1.0)))
		multi.set_instance_transform(i, Transform3D(shape, places[i]))
	_dust.multimesh = multi


## Points scattered around the route and **outside the boundary**, between `near` and
## `far` metres PAST it.
##
## Both distances are measured from the EDGE, never from the route, and that is the
## whole of why this works. Measured from the route, a shell 1800 m wide cannot reach
## past a system's 1750 m rim at all: dust appears along the corridors and a player
## standing inside a disc looking at the wall sees exactly the flat blue nothing this
## was built to fix. Measured from the edge, the shell follows the shape of playable
## space — it hugs a corridor where the corridor is narrow and stands off a system's
## rim where the system is wide.
##
## `edge_span` is how far the wall can be from the route, and it only sizes the search:
## a sample has to be able to reach past the boundary before it can be tested against
## it. The test is `overshoot`, which already knows about every disc and every corridor,
## so nothing here has to know the shape of the map.
static func scatter(rng: RandomNumberGenerator, spine: PackedVector3Array,
		field: BoundaryField, count: int, near: float, far: float,
		edge_span: float) -> PackedVector3Array:
	var places := PackedVector3Array()
	if count <= 0 or spine.size() < 2 or far <= near:
		return places
	var furthest := edge_span + far
	for i in count:
		for attempt in SCATTER_TRIES:
			var anchor: Vector3 = spine[rng.randi_range(0, spine.size() - 1)]
			var z := rng.randf_range(-1.0, 1.0)
			var a := rng.randf_range(0.0, TAU)
			var r := sqrt(maxf(1.0 - z * z, 0.0))
			var direction := Vector3(r * cos(a), z, r * sin(a))
			# Cube-rooted, so the search volume is sampled evenly rather than being
			# crowded around the route — which would put every rejected sample in the
			# same place and every accepted one in a thin band at the far edge.
			var at := anchor + direction * (furthest * pow(rng.randf(), 1.0 / 3.0))
			var past := field.overshoot(at)
			if past < near or past > far:
				continue
			places.append(at)
			break
	return places


func _tinted(base: Color, rng: RandomNumberGenerator, spread: float) -> Color:
	return Color(
		clampf(base.r + rng.randf_range(-spread, spread) * 0.5, 0.0, 1.0),
		clampf(base.g + rng.randf_range(-spread, spread) * 0.5, 0.0, 1.0),
		clampf(base.b + rng.randf_range(-spread, spread) * 0.5, 0.0, 1.0),
		1.0)


# --- what the gate and the HUD ask it ----------------------------------------
#
# Counts only, and deliberately. There is no accessor here that hands out a position,
# because the moment one exists something will query the scenery and that bug looks
# like a physics bug (CLAUDE.md, LOD / collision).

func star_count() -> int:
	return 0 if _stars.multimesh == null else _stars.multimesh.instance_count


func body_count() -> int:
	return 0 if _bodies.multimesh == null else _bodies.multimesh.instance_count


func dust_count() -> int:
	return 0 if _dust.multimesh == null else _dust.multimesh.instance_count
