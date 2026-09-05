class_name RoadStructure
extends Node3D
## The BUILDING the road is: metal collars, glazed bays, a roadway, and — where two
## directions share it — a pane of glass down the middle.
##
## **A deck is the lane you fly in; the structure is the building around it** (ADR
## 0078). Those were one object and it is why the road never read as a place: a
## `RoadDeck` swept one continuous `ArrayMesh` along its path, so nothing was
## repeated and nothing looked manufactured. Here the road is MODULES stepped along
## the path, four `MultiMeshInstance3D`s deep, and the whole mainline costs four
## meshes and a transform list instead of tens of thousands of vertices.
##
## The split is also what lets ONE structure carry TWO lanes. The mainline pair is a
## single building straddling the spine with a carriageway either side of the median;
## a ramp is the same building with one lane in it and no median.
##
## **The unit section is the contract.** Every module is authored inside x, y, z in
## [-0.5, 0.5] by `tools/gen_road_modules.py`, and each instance is scaled by (full
## width, full height, that module's length). Real art replaces the .obj in place and
## nothing here changes (ADR 0030). The box is the CLEAR INTERIOR: modules sit on or
## outside its faces, so the space a ship flies through is exactly the box.
##
## **The glass is a diffuser, not decoration** (ADR 0079). It is deliberately more
## opaque than the shell it replaced, so a low-detail proxy behind it reads as a
## plausible ship — which is what lets traffic outside the tube stay a rough render.
## What ADR 0057 protects is that the surrounding space stays WITNESSED, and that is
## measured as area now: the walls and roof are glazed, and only the roadway you
## drive on is solid.
##
## Geometry is built in the MAP'S frame with the node left at identity, as with
## `RoadDeck`: there is no rotation to get backwards that way.

## Where the module meshes live. Generated, not authored — see the header of
## `tools/gen_road_modules.py` for the unit-section contract they are built to.
const MODULE_PATH := "res://assets/models/road_%s.obj"

## Which face of the building a ramp passes through. **Authored, never computed from
## a preference** (ADR 0080): a ramp is built to leave through a particular face and
## the structure is told which.
##
## There is no DOWN for an exit. The floor is the roadway — the road you dock on —
## and an exit competing with it for the meaning of "down" is clutter. Entries are
## the opposite and are always BELOW: merging upward into the only lane there is is
## unambiguous, and there is nothing else it could mean.
enum Face { RIGHT, LEFT, ABOVE, BELOW }


var structure_name: String = "structure"
## A ramp is drawn darker than a mainline, because a ramp carries a portal and a
## mainline does not, and which road leaves the highway should be something the eye
## answers rather than a sign you read (ADR 0076). The property moved here from the
## deck along with everything else that is the building rather than the lane.
var is_ramp: bool = false
## Whether a pane of glass runs down the middle. True for the mainline pair, false
## for a ramp: a median divides two directions and a ramp has only one.
var has_median: bool = false

var _path: RoadPath = RoadPath.new()
## The full interior half-extents, and the narrower ones at a portal mouth. The
## structure narrows exactly where the lane does — `LaneProfile` answers for both, so
## the building and the lane inside it cannot disagree about where the road pinches.
var _full: Vector2 = Vector2.ONE
var _mouth: Vector2 = Vector2.ONE
var _narrows_at_start: bool = false
var _narrows_at_end: bool = false

## Where ramps pierce this building, along the path, and through which face. Two
## parallel lists rather than a dictionary so both stay typed.
var _pierced_at: PackedFloat32Array = PackedFloat32Array()
var _pierced_face: PackedInt32Array = PackedInt32Array()

## Every layer of modules by name. The `open_*` layers are the same bay with one face
## left out, and they are empty on a road nothing leaves.
var _layers: Dictionary = {}


func _ready() -> void:
	for spec: Array in [
			["Ribs", "rib", false], ["Bays", "bay", true],
			["Plates", "plate", false], ["Panes", "pane", true],
			["BaysOpenRight", "bay_open_right", true],
			["BaysOpenLeft", "bay_open_left", true],
			["BaysOpenTop", "bay_open_top", true],
			["Stations", "station", false],
			["Rings", "ring", false]]:
		_layers[spec[0]] = _make_layer(spec[0], spec[1], spec[2])
	rebuild()


## One layer of modules: a mesh, a transform list, and a material.
##
## Metal is LIT and glass is not, which is a deliberate break from the unshaded
## convention the wireframe road used. That convention existed because a translucent
## tube takes its tint from whatever light it sits in, and a lane that changes
## character between systems is one the player cannot learn. A built structure is the
## opposite case: form is the whole read, and form is what shading gives. The
## exploration scene carries ONE key light for the entire map, so the road still
## looks the same everywhere — the reason for the convention does not apply here.
func _make_layer(node_name: String, module: String,
		glass: bool) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = load(MODULE_PATH % module) as Mesh
	var layer := MultiMeshInstance3D.new()
	layer.name = node_name
	layer.multimesh = multi
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	if glass:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	layer.material_override = mat
	add_child(layer)
	return layer


## Lay this structure along a path, in the map's frame.
func follow(line: PackedVector3Array, full: Vector2, mouth: Vector2,
		narrows_at_start: bool, narrows_at_end: bool) -> void:
	_path.set_points(line)
	_pierced_at = PackedFloat32Array()
	_pierced_face = PackedInt32Array()
	_full = full
	_mouth = mouth
	_narrows_at_start = narrows_at_start
	_narrows_at_end = narrows_at_end
	if _layers.is_empty():
		return
	rebuild()


## A ramp passes through this building here, through this face. Called by the network
## once it has measured where the ramp actually leaves — the crossing is *found*, not
## assumed, because a cubic ramp's shape is a consequence of four tuned numbers and
## guessing where it clears the wall is how an opening ends up in the wrong place.
func pierce(along: float, face: Face) -> void:
	_pierced_at.append(along)
	_pierced_face.append(int(face))
	if not _layers.is_empty():
		rebuild()


func rebuild() -> void:
	if _layers.is_empty():
		return
	var placed := {}
	for key: String in _layers:
		placed[key] = [] as Array[Transform3D]
	var span := _path.length()
	if span <= 0.0:
		_place(placed)
		return
	var module := maxf(Tuning.num("exploration/structure_module_length"), 1.0)
	var collar := clampf(Tuning.num("exploration/structure_rib_thickness"),
		0.0, module)
	var mouth := maxf(Tuning.num("exploration/ramp_ring_diameter"), 1.0)
	var bays := maxi(int(span / module), 1)
	var step := span / float(bays)

	# A bay fills the space BETWEEN two collars, and a collar sits on every joint
	# including both ends. That is one more rib than there are bays, and it is what
	# makes the road read as a chain of segments rather than as a striped tube.
	# A COLLAR ON EVERY JOINT, and every so often a SERVICE STATION instead of one.
	# The concept art's spine is not evenly ribbed: a long road that is, reads as an
	# extrusion with a texture on it, and the thicker segments are what make it a
	# built thing with places along it. A station takes a collar's slot and a longer
	# stretch of it.
	var every := maxi(int(Tuning.num("exploration/structure_station_spacing")), 0)
	var station := maxf(Tuning.num("exploration/structure_station_length"), collar)
	for i in bays + 1:
		if every > 0 and i > 0 and i < bays and i % every == 0:
			placed["Stations"].append(_module(float(i) * step, station))
		else:
			placed["Ribs"].append(_module(float(i) * step, collar))

	for i in bays:
		var from := float(i) * step + collar * 0.5
		var to := float(i + 1) * step - collar * 0.5
		# A bay is laid as one piece unless a ramp goes through it, and then as a
		# solid piece either side of every mouth-sized gap. More than one ramp can
		# land in the same bay — at an interchange the two carriageways' ramps pierce
		# opposite walls within metres of each other — so this walks the openings in
		# order rather than handling "the" opening.
		var here := from
		for opening: Array in _openings_in(i, step, from, to, mouth):
			var gap_from: float = opening[0]
			var gap_to: float = opening[1]
			var face: int = opening[2]
			_fill(placed, here, gap_from, -1)
			_fill(placed, gap_from, gap_to, face)
			placed["Rings"].append(
				_ring((gap_from + gap_to) * 0.5, face, mouth))
			here = gap_to
		_fill(placed, here, to, -1)

	# A ring at every portal mouth too. A ramp's ends and a ramp's side openings are
	# the same object to the player: a steel hoop that says "this is the way through".
	if _narrows_at_start:
		placed["Rings"].append(_end_ring(0.0, mouth))
	if _narrows_at_end:
		placed["Rings"].append(_end_ring(span, mouth))

	_place(placed)


## Hand each layer the transforms gathered for it.
func _place(placed: Dictionary) -> void:
	for key: String in _layers:
		var layer := _layers[key] as MultiMeshInstance3D
		var rows := placed[key] as Array[Transform3D]
		layer.multimesh.instance_count = rows.size()
		for i in rows.size():
			layer.multimesh.set_instance_transform(i, rows[i])
	repaint()


## Lay one stretch of the road. `face` is the face left open across it, or negative
## for a solid stretch.
##
## The floor is the odd one out: a BELOW opening lays no roadway at all, because a
## hole in the roadway IS the hole, while the walls and roof carry straight on over
## it. Everything else keeps its floor — you do not stop being able to drive because
## a ramp leaves through the wall beside you.
func _fill(placed: Dictionary, from: float, to: float, face: int) -> void:
	if to - from < 1.0:
		return
	var piece := _span(from, to)
	if face == int(Face.BELOW):
		placed["Bays"].append(piece)
	elif face < 0:
		placed["Bays"].append(piece)
		placed["Plates"].append(piece)
	else:
		placed[_open_layer(face)].append(piece)
		placed["Plates"].append(piece)
	# The median runs on through every opening. A ramp joins or leaves its own
	# carriageway and never crosses the middle of the road — that is what right-hand
	# traffic buys (ADR 0077) — so there is nothing here for a ramp to interrupt.
	if has_median:
		placed["Panes"].append(piece)


## Every opening belonging to this BAY, in order along the road, as
## `[gap_from, gap_to, face]`. Each is one ring wide and kept inside the bay.
##
## Assigned by bay index rather than by falling inside the bay's clear stretch,
## because the stretch excludes the collars at each end and an aperture landing under
## a collar would belong to no bay at all — it lost its ring and its opening, which is
## a ramp going through a solid wall with nothing to say so. Every aperture belongs to
## exactly one bay and is nudged inside it.
func _openings_in(bay: int, step: float, from: float, to: float,
		mouth: float) -> Array:
	var found: Array = []
	for i in _pierced_at.size():
		if int(_pierced_at[i] / step) != bay:
			continue
		var at := clampf(_pierced_at[i], from + mouth * 0.5, to - mouth * 0.5)
		found.append([at - mouth * 0.5, at + mouth * 0.5, _pierced_face[i]])
	found.sort_custom(func(a, b): return a[0] < b[0])
	# Two ramps can pierce within a ring of each other — at an interchange the two
	# carriageways' ramps land within metres, on opposite walls. Overlapping gaps
	# would lay geometry on top of itself, so each is pushed clear of the one before
	# and then the whole run is pulled back inside the bay. An opening is never
	# dropped: a way through with no ring on it is worse than a ring sitting a little
	# off its ramp.
	for i in range(1, found.size()):
		if found[i][0] < found[i - 1][1]:
			var shift: float = found[i - 1][1] - found[i][0]
			found[i][0] += shift
			found[i][1] += shift
	var overflow: float = found[found.size() - 1][1] - to if not found.is_empty() \
		else 0.0
	if overflow > 0.0:
		for one: Array in found:
			one[0] -= overflow
			one[1] -= overflow
	return found


func _open_layer(face: int) -> String:
	match face:
		int(Face.LEFT):
			return "BaysOpenLeft"
		int(Face.ABOVE):
			return "BaysOpenTop"
		_:
			return "BaysOpenRight"


## One module centred at `along`, `length` long.
func _module(along: float, length: float) -> Transform3D:
	var at := clampf(along, 0.0, _path.length())
	var forward := _path.tangent_at(at)
	var frame := CruiseLane.frame_for(forward)
	var extents := extents_at(at)
	return Transform3D(
		Basis(frame[0] * extents.x * 2.0, frame[1] * extents.y * 2.0,
			-forward * maxf(length, 0.01)),
		_path.point_at(at))


## One module filling the stretch between two points along the road.
func _span(from: float, to: float) -> Transform3D:
	return _module((from + to) * 0.5, to - from)


## A hoop on one face of the building, at its own uniform scale.
##
## Uniform, unlike every other module here, and that is the point: a mouth you fly
## through has to read as one size from any angle, and an ellipse does not (ADR 0080).
func _ring(along: float, face: int, diameter: float) -> Transform3D:
	var at := clampf(along, 0.0, _path.length())
	var forward := _path.tangent_at(at)
	var frame := CruiseLane.frame_for(forward)
	var extents := extents_at(at)
	var out := frame[0]
	var offset := extents.x
	match face:
		int(Face.LEFT):
			out = -frame[0]
		int(Face.ABOVE):
			out = frame[1]
			offset = extents.y
		int(Face.BELOW):
			out = -frame[1]
			offset = extents.y
	var depth := maxf(Tuning.num("exploration/ramp_ring_depth"), 0.01)
	# The hoop's hole runs along its own Z, so Z is the face normal and the other two
	# axes are anything perpendicular — here, the road and the remaining direction.
	var tall := out.cross(forward).normalized()
	return Transform3D(
		Basis(forward * diameter, tall * diameter, out * depth),
		_path.point_at(at) + out * offset)


## A hoop around the end of a road, facing along it. This is the portal mouth's
## surround: the sheen inside it says whether you may use it (ADR 0060), the steel
## says where it is.
func _end_ring(along: float, diameter: float) -> Transform3D:
	var at := clampf(along, 0.0, _path.length())
	var forward := _path.tangent_at(at)
	var frame := CruiseLane.frame_for(forward)
	var depth := maxf(Tuning.num("exploration/ramp_ring_depth"), 0.01)
	return Transform3D(
		Basis(frame[0] * diameter, frame[1] * diameter, -forward * depth),
		_path.point_at(at))


## The clear interior's half-extents at this point. The lane inside is measured
## against the same numbers (`LaneProfile`), so the building and the lane pinch in
## the same place.
func extents_at(along: float) -> Vector2:
	return LaneProfile.extents(along, _path.length(), _full, _mouth,
		Tuning.num("exploration/portal_flare_length"),
		_narrows_at_start, _narrows_at_end)


## The shell as a surface a hull does not pass through, or null where this building
## has nothing to hold (ADR 0087).
##
## `inside` is decided HERE, from where the hull is before it moves, and enforced by
## the ship after it has. That is what keeps the whole thing stateless: nothing has to
## remember which side of a wall anything was on last frame.
##
## Three places are deliberately not held, and each is a way through rather than an
## oversight: the faces a ramp pierces, the flared mouth at a portal, and the open end
## of a ramp where it meets the road it joins. Holding any of them would be a highway
## with no junctions on it.
func barrier(point: Vector3, clearance: Vector2) -> HullBarrier:
	var span := _path.length()
	if span <= 0.0:
		return null
	var found := _path.closest(point)
	var along: float = found[0]
	# A RAMP'S ENDS ARE OPENINGS. One is its portal and the other is where it merges
	# into the road it serves, and both are flown through along the tube rather than
	# across a face — so the shell stops short of them.
	var mouth := maxf(Tuning.num("exploration/ramp_ring_diameter"), 1.0)
	if is_ramp and (along <= mouth or along >= span - mouth):
		return null
	# And the flare is a threshold, not a wall. The section pinches to the portal's own
	# opening over `portal_flare_length`, and a hull held against a shrinking tube would
	# be funnelled by geometry rather than flown through it; the lane's soft push is
	# what governs a mouth (ADR 0064).
	var flare := Tuning.num("exploration/portal_flare_length")
	if (_narrows_at_start and along <= flare) \
			or (_narrows_at_end and along >= span - flare):
		return null

	var centre: Vector3 = found[1]
	var tangent: Vector3 = found[2]
	var frame := CruiseLane.frame_for(tangent)
	var offset := point - centre
	var across := offset.dot(frame[0])
	var lift := offset.dot(frame[1])
	var extents := extents_at(along)

	var held := HullBarrier.new()
	held.shell_name = structure_name
	held.centre = centre
	held.axis = tangent
	held.right = frame[0]
	held.up = frame[1]
	held.extents = extents
	held.clearance = clearance
	held.across = across
	held.lift = lift
	held.inside = absf(across) <= extents.x and absf(lift) <= extents.y
	if not held.inside:
		# A hull nowhere near this building is not this building's business. Engaging
		# only once it is about to be through the wall keeps the cost to the road the
		# ship is actually at, and keeps a road twenty kilometres away from having an
		# opinion about open space.
		var margin := Tuning.num("exploration/structure_barrier_margin")
		if absf(across) > extents.x + clearance.x + margin \
				or absf(lift) > extents.y + clearance.y + margin:
			return null
	for i in _pierced_at.size():
		if absf(_pierced_at[i] - along) > mouth:
			continue
		match _pierced_face[i]:
			int(Face.RIGHT):
				held.open_right = true
			int(Face.LEFT):
				held.open_left = true
			int(Face.ABOVE):
				held.open_above = true
			_:
				held.open_below = true
	held.has_median = has_median and held.inside
	if held.has_median and absf(across) > clearance.x:
		held.median_side = signf(across)
	return held


## Every aperture in this building, as `[along, face]`. For the gate — nothing in the
## game asks, and the exit-face rules are only checkable from here.
func apertures() -> Array:
	var found: Array = []
	for i in _pierced_at.size():
		found.append([_pierced_at[i], _pierced_face[i]])
	return found


func path() -> RoadPath:
	return _path


func length() -> float:
	return _path.length()


## How much of the outward-facing envelope is GLASS rather than metal.
##
## This is what "the lane is visually open" means now (ADR 0079). It used to be a
## number someone picked — an alpha below a threshold — and that could not tell a
## window from a tinted wall. Around the section the walls and roof are entirely
## glazed and only the roadway is solid; along the road, every metre that is not a
## collar is a bay. So the ratio is the collars' share of the run, and the gate
## checks it rather than checking a colour.
##
## Pure and static, so the gate can ask without building a road.
static func open_fraction(module_length: float, rib_thickness: float) -> float:
	if module_length <= 0.0:
		return 0.0
	return clampf((module_length - rib_thickness) / module_length, 0.0, 1.0)


func repaint() -> void:
	if _layers.is_empty():
		return
	var shade := Tuning.num("exploration/lane_ramp_shade") if is_ramp else 1.0
	shade = clampf(shade, 0.0, 1.0)
	var metal := Tuning.color("exploration/structure_metal_color").darkened(
		1.0 - shade)
	# THE GLASS IS NOT SHADED DOWN. A ramp is drawn darker so the eye can tell which
	# road leaves the highway (ADR 0076), and that is the STEEL's job — darkening the
	# panes as well took a diffuser at alpha 0.3 down to something you look straight
	# through, and the human reported the interchange as "a highway with no glass".
	# ADR 0079 makes the glass load-bearing rather than decorative: a pane a rough
	# render is not visible behind is not a diffuser, on a ramp or anywhere else.
	var glass := Tuning.color("exploration/structure_glass_color")
	glass.a = Tuning.num("exploration/structure_glass_alpha")
	# A RING IS NEVER SHADED DOWN. Everything else on a ramp is drawn darker so the eye
	# can tell which road leaves the highway (ADR 0076); the ring is the opposite job —
	# it is the thing that says "the way through is here", and a dimmed signpost is a
	# worse signpost. Steel, at full brightness, on a mainline and a ramp alike.
	for key: String in _layers:
		var mat := (_layers[key] as MultiMeshInstance3D).material_override \
			as StandardMaterial3D
		if key == "Rings":
			mat.albedo_color = Tuning.color("exploration/ramp_ring_color")
		elif key == "Ribs" or key == "Plates" or key == "Stations":
			mat.albedo_color = metal
		else:
			mat.albedo_color = glass
