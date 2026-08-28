class_name BeamFlash
extends MeshInstance3D
## The pulse beam's tracer. A visual and nothing else — the beam's damage is
## resolved by `Shot` against a segment, and this only draws that segment.
##
## One long-lived node rather than one spawned per frame: the beam is continuous
## while the button is held, so a spawn-and-fade per frame would be sixty nodes a
## second doing the work of one. `strike()` refreshes it; left alone it fades out
## on its own, which is also what a single tap should look like.

var _fade_seconds: float = 0.1
var _alpha: float = 0.0
## Set by `strike`, cleared by the next `_process`. Without it a frame long enough
## to consume the whole fade would draw the beam and erase it in the same frame,
## and the beam would be invisible at low frame rates — which is exactly what
## `make shot` runs at, and what a bad frame in the real game looks like.
var _struck_this_frame: bool = false
var _material: StandardMaterial3D


func _ready() -> void:
	var box := BoxMesh.new()
	# Unit length along -Z, so the mesh can be scaled to the segment directly.
	box.size = Vector3(1.0, 1.0, 1.0)
	mesh = box
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


## Draw the beam between two points in the parent's frame, at full brightness.
## Call it every frame the beam is firing; stop calling it and it fades.
func strike(from: Vector3, to: Vector3, width: float, tint: Color, fade_seconds: float) -> void:
	var span := to - from
	var length := span.length()
	if length < 0.001:
		return
	_fade_seconds = maxf(fade_seconds, 0.001)
	_alpha = 1.0
	_struck_this_frame = true
	_material.albedo_color = tint
	position = from + span * 0.5
	basis = FlightGeometry.basis_from_forward(span / length)
	scale = Vector3(width, width, length)
	visible = true


func _process(delta: float) -> void:
	if not visible:
		return
	if _struck_this_frame:
		_struck_this_frame = false
		_material.albedo_color.a = _alpha
		return
	_alpha = maxf(_alpha - delta / _fade_seconds, 0.0)
	_material.albedo_color.a = _alpha
	if _alpha <= 0.0:
		visible = false
