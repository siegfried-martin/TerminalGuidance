class_name Portal
extends Node3D
## The way on and off the road. A large lit aperture carrying the name of the system
## it leads toward, whose colour is the whole of *"may I use this?"* — blue for
## permitted, red for refused (ADR 0060).
##
## **Entry is on contact and instant.** No alignment, no docking sequence, no
## confirmation (ADR 0057). At a 41-second local leg, ten seconds of ceremony is a
## quarter of the trip and the network becomes a chain of loading screens.
##
## The crossing test is **swept** (ADR 0032's habit): a ship at cruise speed covers
## 1.6 m in a frame, and a portal that can be passed through between two frames is a
## portal that intermittently does not exist. The segment is tested against the
## aperture plane, not the ship's position against a volume.

## Which way you go through it. Crossing along this is entering the road it serves;
## crossing against it is leaving.
var travel: Vector3 = Vector3.FORWARD
## What the label says — the system this portal leads toward.
var destination: String = ""
## Set from the hull the player is currently flying. It is the colour that carries
## the answer, and it has to be readable before the approach rather than on contact.
var permitted: bool = true
## Whether this mouth is a way the player could take FROM WHERE THEY ARE — a way on
## while off the road, the way off the road being ridden. An exit's mouth is not an
## entrance, and it used to be painted the same permitted blue as one; flying into it
## did nothing, which reads as the road being broken rather than as a wrong turn
## (ADR 0091).
##
## Combined with `permitted` in the colour rather than replacing it: both are "may I
## use this, now", which is the single question ADR 0060 says the colour answers.
var reachable: bool = true
## Whether this way on or off is one the player could actually use from where they
## are. The APERTURE is always drawn — it is a built thing and it does not come and go
## — but its NAME is not: a system with two highways through it carries eight mouths,
## and a seat that can read all eight names at once is reading noise rather than a
## signpost (ADR 0088).
var _named: bool = false

var _sheen: MeshInstance3D
var _frame: MeshInstance3D
var _label: Label3D
var _elapsed: float = 0.0


func _ready() -> void:
	_sheen = MeshInstance3D.new()
	_sheen.name = "Sheen"
	_sheen.mesh = QuadMesh.new()
	_sheen.material_override = _make_material()
	_sheen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sheen)

	_frame = MeshInstance3D.new()
	_frame.name = "Frame"
	_frame.material_override = _make_material()
	_frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_frame)

	_label = Label3D.new()
	_label.name = "Destination"
	# Billboarded so the name reads from anywhere in the system, which is the whole
	# job: a portal has to answer "where does this go" before the trip to it.
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)
	_label.visible = _named
	rebuild()


func _make_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Seen from both sides, because a portal is approached from one side and left
	# through the other and it must not vanish on the way out.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	return mat


## Place it, and point it down the direction of travel. Called by the deck that owns
## it, on every layout — the mouths move when the system diameter does.
func place(at: Vector3, direction: Vector3) -> void:
	travel = direction.normalized()
	position = at
	# Local -Z looks along travel, so the quad in the XY plane is the aperture.
	var z_col := -travel
	var frame := CruiseLane.frame_for(travel)
	var x_col: Vector3 = frame[1].cross(z_col).normalized()
	basis = Basis(x_col, z_col.cross(x_col).normalized(), z_col)
	if _sheen != null:
		rebuild()


func rebuild() -> void:
	var half_width := Tuning.num("exploration/portal_width") * 0.5
	var half_height := Tuning.num("exploration/portal_height") * 0.5
	(_sheen.mesh as QuadMesh).size = Vector2(half_width * 2.0, half_height * 2.0)
	_frame.mesh = _make_frame(half_width, half_height)
	_label.text = destination
	_label.pixel_size = Tuning.num("exploration/portal_label_metres") / 64.0
	_label.position = Vector3(0.0, half_height * 1.35, 0.0)
	repaint()


## The opening's outline, drawn as lines so the aperture reads as a frame around
## something you fly through rather than as a panel you would hit.
func _make_frame(half_width: float, half_height: float) -> ArrayMesh:
	var corners := [
		Vector3(-half_width, -half_height, 0.0),
		Vector3(half_width, -half_height, 0.0),
		Vector3(half_width, half_height, 0.0),
		Vector3(-half_width, half_height, 0.0),
	]
	var verts := PackedVector3Array()
	for i in 4:
		verts.append(corners[i])
		verts.append(corners[(i + 1) % 4])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return mesh


## Blue or red, and shimmering. The colour is decided per portal against the hull the
## player is flying right now, so switching class in the debug roster changes every
## portal on screen — which is the fastest way to read ADR 0060 as a player.
func is_open() -> bool:
	return permitted and reachable


func repaint() -> void:
	var color := Tuning.color("exploration/portal_sheen_color") if is_open() \
		else Tuning.color("exploration/portal_denied_color")
	var energy := Tuning.num("exploration/portal_emission")
	# The shimmer is what makes it read as a working aperture rather than a painted
	# rectangle. At 0 Hz it holds still, which is what the tuning comment promises.
	var shimmer := 0.5 + 0.5 * sin(_elapsed * TAU
		* Tuning.num("exploration/portal_sheen_scroll_hz"))
	var sheen := color
	sheen.a = lerpf(0.18, 0.42, shimmer)
	var sheen_mat := _sheen.material_override as StandardMaterial3D
	sheen_mat.albedo_color = sheen
	sheen_mat.emission = color
	sheen_mat.emission_energy_multiplier = energy * lerpf(0.6, 1.0, shimmer)
	var frame_mat := _frame.material_override as StandardMaterial3D
	frame_mat.albedo_color = color
	frame_mat.emission = color
	frame_mat.emission_energy_multiplier = energy
	_label.modulate = color
	_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.6)


func _process(delta: float) -> void:
	_elapsed += delta
	repaint()


## Did this segment cross the aperture, and which way?
##
## +1 along the direction of travel, -1 against it, 0 for no crossing. Both `from`
## and `to` are in the frame this node's position is expressed in.
##
## Swept, and bounded by the opening rather than by the plane: flying past the
## portal's *edge* is not going through it, and a plane-only test would put a ship
## into cruise for clipping the corner of the structure.
func crossed(from: Vector3, to: Vector3) -> int:
	var before := (from - position).dot(travel)
	var after := (to - position).dot(travel)
	if is_equal_approx(before, after) or (before > 0.0) == (after > 0.0):
		return 0
	var span := after - before
	if is_zero_approx(span):
		return 0
	var where := from.lerp(to, clampf(-before / span, 0.0, 1.0)) - position
	var frame := CruiseLane.frame_for(travel)
	var half_width := Tuning.num("exploration/portal_width") * 0.5
	var half_height := Tuning.num("exploration/portal_height") * 0.5
	if absf(where.dot(frame[0])) > half_width \
			or absf(where.dot(frame[1])) > half_height:
		return 0
	return 1 if after > before else -1


func width() -> float:
	return Tuning.num("exploration/portal_width")


func height() -> float:
	return Tuning.num("exploration/portal_height")


## Say where this goes, or do not — and blue or red with it. Told by the map, which
## knows whether this mouth is a way the player could take right now: off the road, the
## ways ON; on it, the way OFF the road being ridden.
func set_named(on: bool) -> void:
	if on == _named and on == reachable:
		return
	_named = on
	reachable = on
	if _label != null:
		_label.visible = on
	if _sheen != null:
		repaint()


func is_named() -> bool:
	return _named
