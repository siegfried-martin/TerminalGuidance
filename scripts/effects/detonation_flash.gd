class_name DetonationFlash
extends MeshInstance3D
## A short expanding emissive sphere marking where a missile ended.
##
## Placeholder feedback, not an effect: it exists so a detonation is legible in
## gray-box and so the eye has something to land on when the camera cuts back.

var _elapsed: float = 0.0
var _duration: float = 0.0
var _start_radius: float = 0.0
var _end_radius: float = 0.0
var _material: StandardMaterial3D


func setup(start_radius: float, end_radius: float, duration: float, tint: Color) -> void:
	_start_radius = start_radius
	_end_radius = end_radius
	_duration = maxf(duration, 0.001)

	var sphere := SphereMesh.new()
	sphere.radial_segments = 12
	sphere.rings = 6
	sphere.radius = 1.0
	sphere.height = 2.0
	mesh = sphere

	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.albedo_color = tint
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scale = Vector3.ONE * _start_radius


func _process(delta: float) -> void:
	_elapsed += delta
	var t := clampf(_elapsed / _duration, 0.0, 1.0)
	scale = Vector3.ONE * lerpf(_start_radius, _end_radius, t * t)
	_material.albedo_color.a = 1.0 - t
	if t >= 1.0:
		queue_free()
