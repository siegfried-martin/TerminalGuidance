class_name SystemDisc
extends Node3D
## A system: a bounded volume shaped like a disc, with hard flat faces and an open
## rim (ADR 0011). The first time that ADR has been built — the combat arena has
## always been an unbounded marker lattice.
##
## The height is asymmetric and decomposes rather than coming from a ratio
## (ADR 0061): a combat band around y = 0, `system_ceiling_height` of clearance
## above it *so the ceiling never enters a fight*, and `system_floor_depth` below,
## deep enough to hold the planet with the hard floor under it.
##
## **The rim is not a boundary.** Flying laterally out of a system *is* departure,
## continuous with the transit lane, so nothing here stops it. Only the faces are
## hard, and even they are soft in the way that matters: the treatment follows
## Bannerlord — the volume goes visibly red, a telegraphed timer runs, damage ramps
## if the player does not come back, and the outbound *speed limit* is scaled down
## so the ship strains. **Magnitude only, never direction** — see `DiscBounds`,
## which cannot redirect anything because it never returns a vector.
##
## Bounds are the player's alone. NPCs avoid the volume rather than being ejected
## from it, which is what keeps a brief dip a legitimate tactical option while
## making camping out there non-viable.
##
## Everything is parent-relative and rebuilt on hot reload (ADR 0020).

## Ceiling and floor, drawn as flat discs that redden as the player nears them.
var _ceiling: MeshInstance3D
var _floor: MeshInstance3D
## Reference markers filling the volume, so motion is legible in empty space. The
## combat arena's `GrayBoxArena` fills a cube; a disc is a different shape and gets
## its own placement rather than a shape flag on that one.
var _markers: MultiMeshInstance3D
## Seconds the player has spent past a face on this excursion. Resets on return, so
## two short dips do not add up into damage the player did not see coming.
var _seconds_outside: float = 0.0
## Live, for the HUD. The player is told the timer is running before it costs them.
var _warning: float = 0.0


func _ready() -> void:
	_ceiling = _make_face("Ceiling")
	_floor = _make_face("Floor")
	_markers = MultiMeshInstance3D.new()
	_markers.name = "SystemMarkers"
	_markers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_markers)
	rebuild()
	Tuning.reloaded.connect(rebuild)


func _make_face(face_name: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = face_name
	node.mesh = CylinderMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Both sides, because a ceiling is seen from below and a floor from above, and a
	# player who has gone past one has to still see the thing they went past.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func rebuild() -> void:
	var radius := Tuning.num("exploration/system_diameter") * 0.5
	for node: MeshInstance3D in [_ceiling, _floor]:
		var mesh := node.mesh as CylinderMesh
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		# A slab rather than a plane: seen edge-on from inside, a zero-height disc
		# vanishes exactly when the player most needs to see where it is.
		mesh.height = Tuning.num("exploration/bounds_face_thickness")
		mesh.radial_segments = 64
		mesh.rings = 1
	_ceiling.position = Vector3(0.0, ceiling_height(), 0.0)
	_floor.position = Vector3(0.0, -floor_depth(), 0.0)
	_paint(0.0)
	_rebuild_markers(radius)


## Markers filling the disc, on a lattice clipped to the cylinder. Reference
## geometry, not scenery: nothing here is queryable and nothing eats a missile.
func _rebuild_markers(radius: float) -> void:
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
	var across := int(radius / spacing)
	var up := int(ceiling_height() / spacing)
	var down := int(floor_depth() / spacing)
	for ix in range(-across, across + 1):
		for iz in range(-across, across + 1):
			var x := float(ix) * spacing
			var z := float(iz) * spacing
			if Vector2(x, z).length() > radius:
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
## looking at red before anything else happens, scale the speed limit second so the
## ship strains rather than turns, and only then start counting toward damage.
func apply_to(ship: Mothership, delta: float) -> void:
	if ship == null or not is_instance_valid(ship) or delta <= 0.0:
		return
	var y := ship.position.y
	var ceiling := ceiling_height()
	var depth := floor_depth()
	var band := Tuning.num("exploration/bounds_warning_band")

	_warning = DiscBounds.warning(y, ceiling, depth, band)
	_paint(_warning)

	ship.speed_ceiling_scale = DiscBounds.speed_ceiling_scale(
		y, ship.velocity().y, ceiling, depth, band,
		Tuning.num("exploration/bounds_outbound_speed_fraction"))

	if DiscBounds.overshoot(y, ceiling, depth) <= 0.0:
		_seconds_outside = 0.0
		return
	_seconds_outside += delta
	var rate := DiscBounds.damage_per_second(_seconds_outside,
		Tuning.num("exploration/bounds_grace_seconds"),
		Tuning.num("exploration/bounds_damage_ramp_seconds"),
		Tuning.num("exploration/bounds_damage_per_second"))
	if rate > 0.0:
		ship.take_hit(rate * delta)


## The faces are always faintly visible so the volume has a shape, and go red as
## the player nears one. Both faces light together: which one you are approaching
## is obvious from looking at it, and lighting only the near one makes the disc
## read as a plane rather than as a room.
func _paint(warning: float) -> void:
	var base := Tuning.color("exploration/bounds_face_color")
	var alarm := Tuning.color("exploration/bounds_color")
	var color := base.lerp(alarm, warning)
	color.a = lerpf(Tuning.num("exploration/bounds_face_alpha"),
		Tuning.num("exploration/bounds_alarm_alpha"), warning)
	for node: MeshInstance3D in [_ceiling, _floor]:
		(node.material_override as StandardMaterial3D).albedo_color = color


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


## For the HUD. Zero while clear, 1 at a face and beyond.
func warning() -> float:
	return _warning


func seconds_outside() -> float:
	return _seconds_outside


func marker_count() -> int:
	return 0 if _markers.multimesh == null else _markers.multimesh.instance_count
