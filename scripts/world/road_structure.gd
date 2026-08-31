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

var _ribs: MultiMeshInstance3D
var _bays: MultiMeshInstance3D
var _plates: MultiMeshInstance3D
var _panes: MultiMeshInstance3D


func _ready() -> void:
	_ribs = _make_layer("Ribs", "rib", false)
	_bays = _make_layer("Bays", "bay", true)
	_plates = _make_layer("Plates", "plate", false)
	_panes = _make_layer("Panes", "pane", true)
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
	_full = full
	_mouth = mouth
	_narrows_at_start = narrows_at_start
	_narrows_at_end = narrows_at_end
	if _ribs == null:
		return
	rebuild()


func rebuild() -> void:
	if _ribs == null:
		return
	var span := _path.length()
	if span <= 0.0:
		for layer: MultiMeshInstance3D in [_ribs, _bays, _plates, _panes]:
			layer.multimesh.instance_count = 0
		return
	var module := maxf(Tuning.num("exploration/structure_module_length"), 1.0)
	var collar := clampf(Tuning.num("exploration/structure_rib_thickness"),
		0.0, module)
	var bays := maxi(int(span / module), 1)
	var step := span / float(bays)

	# A bay fills the space BETWEEN two collars, and a collar sits on every joint
	# including both ends. That is one more rib than there are bays, and it is what
	# makes the road read as a chain of segments rather than as a striped tube.
	_lay(_ribs, bays + 1, step, 0.0, collar)
	_lay(_bays, bays, step, 0.5, step - collar)
	_lay(_plates, bays, step, 0.5, step)
	_lay(_panes, bays if has_median else 0, step, 0.5, step)
	repaint()


## Place `count` copies of one module, `step` apart, each `length` long.
##
## `offset` is where in its own slot a module sits: 0 puts it on the joint (a collar
## straddling the seam), 0.5 puts it in the middle of the bay (everything else).
func _lay(layer: MultiMeshInstance3D, count: int, step: float, offset: float,
		length: float) -> void:
	layer.multimesh.instance_count = count
	for i in count:
		var along := clampf((float(i) + offset) * step, 0.0, _path.length())
		var forward := _path.tangent_at(along)
		var frame := CruiseLane.frame_for(forward)
		var extents := extents_at(along)
		layer.multimesh.set_instance_transform(i, Transform3D(
			Basis(frame[0] * extents.x * 2.0, frame[1] * extents.y * 2.0,
				-forward * maxf(length, 0.01)),
			_path.point_at(along)))


## The clear interior's half-extents at this point. The lane inside is measured
## against the same numbers (`LaneProfile`), so the building and the lane pinch in
## the same place.
func extents_at(along: float) -> Vector2:
	return LaneProfile.extents(along, _path.length(), _full, _mouth,
		Tuning.num("exploration/portal_flare_length"),
		_narrows_at_start, _narrows_at_end)


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
	if _ribs == null:
		return
	var shade := Tuning.num("exploration/lane_ramp_shade") if is_ramp else 1.0
	shade = clampf(shade, 0.0, 1.0)
	var metal := Tuning.color("exploration/structure_metal_color").darkened(
		1.0 - shade)
	var glass := Tuning.color("exploration/structure_glass_color").darkened(
		1.0 - shade)
	glass.a = Tuning.num("exploration/structure_glass_alpha")
	for layer: MultiMeshInstance3D in [_ribs, _plates]:
		(layer.material_override as StandardMaterial3D).albedo_color = metal
	for layer: MultiMeshInstance3D in [_bays, _panes]:
		(layer.material_override as StandardMaterial3D).albedo_color = glass
