class_name RampGate
extends Node3D
## The permission surface across the mouth of an exit: blue if you may take it, red if
## you may not.
##
## **The steel ring is the building; this is the permission** — the same split ADR 0060
## makes at a portal, in the same colours, on the other end of the ramp. An on-ramp has
## carried one since ADR 0060 and it is what a fighter sees red everywhere; an exit had
## nothing, so there was no way for a road to refuse to let you off it.
##
## Today it is closed by the same rule that reddens a portal. What it is actually FOR
## is standing: a system that will not let you off its highway because you are not in
## good terms with whoever runs it. That belongs to a reputation system that does not
## exist yet, so what is built here is the surface, the refusal, and the two places
## that have to honour it — the lane union and the exit sign.
##
## It refuses by making the ramp **not a candidate**, not by putting a wall in front of
## the ship. A road that could stop you would be interdiction with an extra step (ADR
## 0014), and a closed exit is a turn you may not take, not a collision.

## The road this gate lets you onto. The gate is the surface; the deck carries the
## `passable` flag the union and the sign both read.
var deck: RoadDeck = null

var _sheen: MeshInstance3D
var _elapsed: float = 0.0


func _ready() -> void:
	_sheen = MeshInstance3D.new()
	_sheen.name = "Sheen"
	_sheen.mesh = QuadMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Seen from the road on the way past and from the ramp once through, so it has to
	# read from both sides.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	_sheen.material_override = mat
	_sheen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sheen)
	rebuild()


func rebuild() -> void:
	if _sheen == null:
		return
	# Exactly the ring's opening, because the ring is the frame this sits in.
	var across := Tuning.num("exploration/ramp_ring_diameter")
	(_sheen.mesh as QuadMesh).size = Vector2(across, across)
	repaint(0.0)


## Blue or red, and shimmering, the same as a portal (ADR 0060). The shimmer is what
## makes it read as a working aperture rather than as a painted panel.
func repaint(delta: float) -> void:
	if _sheen == null:
		return
	_elapsed += delta
	var color := Tuning.color("exploration/portal_sheen_color") \
		if deck == null or deck.passable \
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
