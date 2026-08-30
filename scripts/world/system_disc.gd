class_name SystemDisc
extends Node3D
## A system: a bounded volume shaped like a disc, with hard flat faces and a rim
## that opens only where a road attaches (ADR 0011, as amended by ADR 0062).
##
## The height is asymmetric and decomposes rather than coming from a ratio
## (ADR 0061): a combat band around y = 0, `system_ceiling_height` of clearance
## above it *so the ceiling never enters a fight*, and `system_floor_depth` below,
## deep enough to hold the planet with the hard floor under it.
##
## **The rim is a boundary, and its openings are funnels.** ADR 0011 left the rim
## open because lateral exit *was* departure; once roads exist, departure is through
## the corridor and an open rim leads somewhere nothing is rendered. Each aperture
## is wide where it meets the rim and tapers outward to the corridor, so leaving is
## aimed rather than threaded.
##
## The treatment follows Bannerlord — the volume goes visibly red, a telegraphed
## timer runs, damage ramps if the player does not come back, and the outbound
## *speed limit* is scaled down so the ship strains. **Magnitude only, never
## direction** — see `BoundaryField`, which cannot redirect anything because it
## never returns a vector.
##
## Bounds are the player's alone. NPCs avoid the volume rather than being ejected
## from it, which is what keeps a brief dip a legitimate tactical option while
## making camping out there non-viable.
##
## Everything is parent-relative and rebuilt on hot reload (ADR 0020).

## How finely the rim is tessellated. Infrastructure, not feel: enough segments
## that the aperture's edge is not visibly faceted at the disc's scale.
const RIM_SEGMENTS := 128

## Ceiling and floor, drawn as flat slabs that redden as the player nears them.
var _ceiling: MeshInstance3D
var _floor: MeshInstance3D
## The rim wall, built as an ArrayMesh so the apertures can be holes in it rather
## than decals over it — the drawn shape is the boundary shape (ADR 0043's habit).
var _rim: MeshInstance3D
## One funnel per aperture, hanging off a container so a rebuild can change how
## many there are without leaking nodes.
var _apertures: Node3D
## Reference markers filling the volume, so motion is legible in empty space. The
## combat arena's `GrayBoxArena` fills a cube; a disc is a different shape and gets
## its own placement rather than a shape flag on that one.
var _markers: MultiMeshInstance3D
## The boundary itself: a list of constraints, rebuilt from tuning on reload. The
## geometry above is drawn *from* this, so what is on screen is what is enforced.
var _field: BoundaryField = BoundaryField.new()
## Seconds the player has spent past the edge on this excursion. Resets on return,
## so two short dips do not add up into damage the player did not see coming.
var _seconds_outside: float = 0.0
## Live, for the HUD. The player is told the timer is running before it costs them.
var _warning: float = 0.0
## What the boundary wants the ship's speed ceiling multiplied by this frame.
## Reaches zero when the player keeps pushing straight out (ADR 0062) — but only
## for that heading; turning back is never taxed.
var _speed_scale: float = 1.0
## How much of the ship's heading was outbound this frame, 0 to 1. Kept because the
## HUD has to report the same number the clamp used: recomputing it there from
## `velocity()` silently disagrees whenever the fallback in `_heading_of` fires,
## which is exactly when the ship has been brought to a stop and the player most
## needs the readout to be true.
var _outbound: float = 0.0


func _ready() -> void:
	_ceiling = _make_surface("Ceiling")
	_floor = _make_surface("Floor")
	_rim = _make_surface("Rim")
	_apertures = Node3D.new()
	_apertures.name = "Apertures"
	add_child(_apertures)
	_markers = MultiMeshInstance3D.new()
	_markers.name = "SystemMarkers"
	_markers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_markers)
	rebuild()
	Tuning.reloaded.connect(rebuild)


func _make_surface(surface_name: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = surface_name
	node.material_override = _make_material()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func _make_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Both sides, because a ceiling is seen from below and a floor from above, and a
	# player who has gone past one has to still see the thing they went past.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func rebuild() -> void:
	_rebuild_field()
	for node: MeshInstance3D in [_ceiling, _floor]:
		if node.mesh == null:
			node.mesh = CylinderMesh.new()
		var mesh := node.mesh as CylinderMesh
		mesh.top_radius = _field.radius
		mesh.bottom_radius = _field.radius
		# A slab rather than a plane: seen edge-on from inside, a zero-height disc
		# vanishes exactly when the player most needs to see where it is.
		mesh.height = Tuning.num("exploration/bounds_face_thickness")
		mesh.radial_segments = 64
		mesh.rings = 1
	_ceiling.position = Vector3(0.0, ceiling_height(), 0.0)
	_floor.position = Vector3(0.0, -floor_depth(), 0.0)
	_rebuild_rim()
	_rebuild_apertures()
	_paint(0.0)
	_rebuild_markers(_field.radius)


## The boundary, from tuning. Built once per reload rather than per frame, and it
## is the same object the drawn geometry is measured from.
func _rebuild_field() -> void:
	_field.radius = Tuning.num("exploration/system_diameter") * 0.5
	_field.ceiling = ceiling_height()
	_field.floor_depth = floor_depth()
	_field.warning_band = Tuning.num("exploration/bounds_warning_band")
	_field.stop_distance = Tuning.num("exploration/bounds_stop_distance")
	_field.aperture_radius = Tuning.num("exploration/aperture_mouth_diameter") * 0.5
	_field.funnel_length = Tuning.num("exploration/aperture_funnel_length")
	_field.corridor_radius = Tuning.num("exploration/corridor_diameter") * 0.5
	_field.apertures = [bearing_to_direction(
		Tuning.num("exploration/aperture_bearing_deg"))]


## A compass bearing as a horizontal unit vector. 0 is -Z, counting clockwise, so
## the number in `tuning.cfg` reads the way a bearing reads.
static func bearing_to_direction(degrees: float) -> Vector3:
	var radians := deg_to_rad(degrees)
	return Vector3(sin(radians), 0.0, -cos(radians))


## The rim wall, with the apertures as actual holes.
##
## An ArrayMesh rather than a cylinder with something drawn over it: a hole you can
## fly through has to be a hole in the thing being drawn, or the picture and the
## boundary disagree and the player learns to distrust the picture.
func _rebuild_rim() -> void:
	var top := ceiling_height()
	var bottom := -floor_depth()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in RIM_SEGMENTS:
		var a0 := TAU * float(i) / float(RIM_SEGMENTS)
		var a1 := TAU * float(i + 1) / float(RIM_SEGMENTS)
		var mid := Vector3(sin((a0 + a1) * 0.5), 0.0,
			-cos((a0 + a1) * 0.5)) * _field.radius
		if _field.rim_is_open(mid):
			continue
		var d0 := Vector3(sin(a0), 0.0, -cos(a0))
		var d1 := Vector3(sin(a1), 0.0, -cos(a1))
		var p0 := d0 * _field.radius
		var p1 := d1 * _field.radius
		for corner: Array in [
				[p0, bottom, d0], [p1, bottom, d1], [p1, top, d1],
				[p0, bottom, d0], [p1, top, d1], [p0, top, d0]]:
			var base: Vector3 = corner[0]
			verts.append(Vector3(base.x, corner[1], base.z))
			normals.append(corner[2])

	if verts.is_empty():
		_rim.mesh = null
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_rim.mesh = mesh


## One funnel per aperture: a cone open at both ends, wide where it meets the rim
## and tapering outward to the corridor's cross-section.
func _rebuild_apertures() -> void:
	for child in _apertures.get_children():
		child.queue_free()
		_apertures.remove_child(child)
	for i in _field.apertures.size():
		var axis: Vector3 = _field.apertures[i]
		var node := MeshInstance3D.new()
		node.name = "Aperture%d" % i
		var mesh := CylinderMesh.new()
		# Bottom is the wide end at the rim; top is the corridor it feeds.
		mesh.bottom_radius = _field.aperture_radius
		mesh.top_radius = _field.corridor_radius
		mesh.height = maxf(_field.funnel_length, 0.01)
		mesh.radial_segments = 48
		mesh.rings = 1
		mesh.cap_top = false
		mesh.cap_bottom = false
		node.mesh = mesh
		node.material_override = _make_material()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The mesh's axis is +Y; stand it up along the bearing and slide it out so
		# its wide end sits in the rim.
		node.basis = Basis(Quaternion(Vector3.UP, axis))
		node.position = axis * (_field.radius + _field.funnel_length * 0.5)
		_apertures.add_child(node)


## Markers filling the disc, on a lattice clipped to the cylinder. Reference
## geometry, not scenery: nothing here is queryable and nothing eats a missile.
func _rebuild_markers(radius_m: float) -> void:
	var spacing := Tuning.num("exploration/marker_spacing")
	if spacing <= 0.0:
		return
	var mesh := BoxMesh.new()
	var size := Tuning.num("exploration/marker_size")
	mesh.size = Vector3.ONE * size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Tuning.color("exploration/marker_color")

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	var places: Array[Vector3] = []
	var across := int(radius_m / spacing)
	var up := int(ceiling_height() / spacing)
	var down := int(floor_depth() / spacing)
	for ix in range(-across, across + 1):
		for iz in range(-across, across + 1):
			var x := float(ix) * spacing
			var z := float(iz) * spacing
			if Vector2(x, z).length() > radius_m:
				continue
			for iy in range(-down, up + 1):
				places.append(Vector3(x, float(iy) * spacing, z))
	multi.instance_count = places.size()
	for i in places.size():
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, places[i]))
	_markers.multimesh = multi
	_markers.material_override = mat


## Run the boundary against the ship for this frame.
##
## The order matters and is the whole treatment: paint first so the player is
## looking at red before anything else happens, work out the strain second so the
## ship slows rather than turns, and only then start counting toward damage.
func observe(ship: Mothership, delta: float) -> void:
	_speed_scale = 1.0
	_outbound = 0.0
	if ship == null or not is_instance_valid(ship) or delta <= 0.0:
		return
	var here := ship.position

	_warning = _field.warning(here)
	_paint(_warning)

	# Stored rather than assigned: the approach envelope constrains the same field,
	# and two systems both writing it would silently fight with the loser being
	# whichever happened to run last. The scene composes and assigns the tightest.
	var heading := _heading_of(ship)
	_outbound = BoundaryField.outbound_fraction(heading, _field.outward(here))
	_speed_scale = _field.speed_ceiling_scale(here, heading)

	if _field.overshoot(here) <= 0.0:
		_seconds_outside = 0.0
		return
	_seconds_outside += delta
	var rate := BoundaryField.damage_per_second(_seconds_outside,
		Tuning.num("exploration/bounds_grace_seconds"),
		Tuning.num("exploration/bounds_damage_ramp_seconds"),
		Tuning.num("exploration/bounds_damage_per_second"))
	if rate > 0.0:
		ship.take_hit(rate * delta)


## Where the ship is trying to go.
##
## Velocity is the truthful answer — it includes thrusters, which genuinely move
## you — but at the far edge the clamp drives velocity to zero, and a zero vector
## has no heading to judge. The nose is what the throttle would push along, so it
## is the right thing to fall back to and it keeps the stopped case from chattering
## between "outbound" and "no idea".
func _heading_of(ship: Mothership) -> Vector3:
	var moving := ship.velocity()
	if moving.length_squared() > 0.01:
		return moving
	return -ship.basis.z


## The surfaces are always faintly visible so the volume has a shape, and go red as
## the player nears one. All of them light together: which one you are approaching
## is obvious from looking at it, and lighting only the near one makes the disc
## read as a plane rather than as a room.
func _paint(warning_level: float) -> void:
	var base := Tuning.color("exploration/bounds_face_color")
	var alarm := Tuning.color("exploration/bounds_color")
	var color := base.lerp(alarm, warning_level)
	var alpha := lerpf(Tuning.num("exploration/bounds_face_alpha"),
		Tuning.num("exploration/bounds_alarm_alpha"), warning_level)
	color.a = alpha
	for node: MeshInstance3D in [_ceiling, _floor]:
		(node.material_override as StandardMaterial3D).albedo_color = color
	# The rim and the funnel are single-thickness walls seen face-on, where the
	# slabs are seen edge-on and stack their own depth. Same colour, more of it.
	var wall := color
	wall.a = clampf(alpha * Tuning.num("exploration/bounds_rim_alpha_scale"), 0.0, 1.0)
	(_rim.material_override as StandardMaterial3D).albedo_color = wall
	for node in _apertures.get_children():
		((node as MeshInstance3D).material_override as StandardMaterial3D) \
			.albedo_color = wall


func ceiling_height() -> float:
	return Tuning.num("exploration/system_ceiling_height")


func floor_depth() -> float:
	return Tuning.num("exploration/system_floor_depth")


## Floor to ceiling. Derived, never tuned: the two halves are set separately
## because the planet lives under one of them (ADR 0061), and a single height key
## would make that relationship impossible to express.
func height() -> float:
	return ceiling_height() + floor_depth()


func radius() -> float:
	return Tuning.num("exploration/system_diameter") * 0.5


## The boundary, for anything that needs to ask it a question — the HUD, the tests,
## and later the road, which has to attach to an aperture rather than guess at one.
func field() -> BoundaryField:
	return _field


## For the HUD. Zero while clear, 1 at the edge and beyond.
func warning() -> float:
	return _warning


## What this frame's boundary state wants the ship's speed ceiling scaled by.
func speed_scale() -> float:
	return _speed_scale


## How much of the ship's heading the boundary counted as outbound this frame.
## Zero while inside, since nothing is measured against a normal that does not exist.
func outbound() -> float:
	return _outbound


func seconds_outside() -> float:
	return _seconds_outside


func marker_count() -> int:
	return 0 if _markers.multimesh == null else _markers.multimesh.instance_count


## Where the rim opens, as a world-space point in the middle of the aperture's
## mouth. What step 6 attaches the local leg's portal to.
func aperture_mouth(index: int) -> Vector3:
	if index < 0 or index >= _field.apertures.size():
		return Vector3.ZERO
	return _field.apertures[index] * _field.radius


func aperture_count() -> int:
	return _field.apertures.size()
