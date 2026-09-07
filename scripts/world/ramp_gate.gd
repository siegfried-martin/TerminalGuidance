class_name RampGate
extends Node3D
## The permission surface across an exit, where the ramp has cleared the highway's
## wall: blue if you may take it, red if you may not.
##
## **The structure is the building; this is the permission** — the same split ADR 0060
## makes at a portal, in the same colours, on the other end of the ramp. What it is
## FOR is standing: a system that will not let you off its highway because you are not
## in good terms with whoever runs it. That belongs to a reputation system that does
## not exist yet, so what is built here is the surface, the refusal, and the two places
## that honour it — the tube's `passable` flag and the strip.
##
## It refuses by making the ramp **not a candidate**, not by putting a wall in front of
## the ship. A road that could stop you would be interdiction with an extra step (ADR
## 0014), and a closed exit is a turn you may not take, not a collision.

## The ramp this gate stands across. The gate is the surface; the tube carries the
## `passable` flag the strip reads.
var tube: Tube = null

var _sheen: MeshInstance3D
var _size: Vector2 = Vector2(100.0, 60.0)
var _elapsed: float = 0.0


func _ready() -> void:
	_sheen = MeshInstance3D.new()
	_sheen.name = "Sheen"
	_sheen.mesh = QuadMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Seen from the road on the way past and from the ramp once through.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	_sheen.material_override = mat
	_sheen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sheen)
	rebuild()


## Stand across the ramp at `at`, facing along `direction`, filling `size`.
func place(at: Vector3, direction: Vector3, size: Vector2) -> void:
	position = at
	_size = size
	var z_col := -direction.normalized()
	var frame := RoadPath.frame_from_tangent(direction.normalized())
	var x_col: Vector3 = (frame["up"] as Vector3).cross(z_col).normalized()
	basis = Basis(x_col, z_col.cross(x_col).normalized(), z_col)
	rebuild()


func rebuild() -> void:
	if _sheen == null:
		return
	(_sheen.mesh as QuadMesh).size = _size
	repaint(0.0)


## Blue or red, and shimmering, the same as a portal (ADR 0060).
func repaint(delta: float) -> void:
	if _sheen == null:
		return
	_elapsed += delta
	var color := Tuning.color("exploration/portal_sheen_color") \
		if tube == null or tube.passable \
		else Tuning.color("exploration/portal_denied_color")
	var shimmer := 0.5 + 0.5 * sin(_elapsed * TAU
		* Tuning.num("exploration/portal_sheen_scroll_hz"))
	var sheen := color
	sheen.a = lerpf(0.10, 0.30, shimmer) \
		* Tuning.num("exploration/ramp_gate_alpha_scale")
	var mat := _sheen.material_override as StandardMaterial3D
	mat.albedo_color = sheen
	mat.emission = color
	mat.emission_energy_multiplier = Tuning.num("exploration/portal_emission") \
		* lerpf(0.6, 1.0, shimmer)
