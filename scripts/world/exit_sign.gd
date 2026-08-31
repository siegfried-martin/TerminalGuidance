class_name ExitSign
extends Node3D
## A sign on the road, ahead of an exit, naming where that exit goes.
##
## **A sign is not a map** (ADR 0083). It is an object in the world, mounted on the
## structure at a place you can see it from, and reading it early enough to use it is
## a piloting act. The player chooses at the moment they can see the choice; nothing
## plans, nothing routes, and there is no list of destinations anywhere.
##
## It is **clickable only while berthed**. Flying, a click that changed which road you
## were on would be autopilot growth (ADR 0013); berthed, the ship is not being flown
## and the reticle is free, so it is a cursor.
##
## Drawn the way a `Portal` draws its destination — a billboard label with a panel
## behind it — because they are the same kind of object to the player: text on the
## road that says where something goes.

## Which road this sign is for. Clicking it binds the berth to this deck when the ship
## reaches it.
var ramp: RoadDeck = null
## What it reads. The place the exit serves, not the road it hangs over.
var label_text: String = ""

var _label: Label3D
var _panel: MeshInstance3D
## Whether the reticle is on this sign right now. Set by the map each frame; the sign
## does not look for the player.
var _aimed: bool = false


func _ready() -> void:
	_panel = MeshInstance3D.new()
	_panel.name = "Panel"
	_panel.mesh = QuadMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_panel.material_override = mat
	_panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_panel)

	_label = Label3D.new()
	_label.name = "Text"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)
	rebuild()


func rebuild() -> void:
	if _label == null:
		return
	var size := Tuning.num("exploration/exit_sign_metres")
	(_panel.mesh as QuadMesh).size = Vector2(size * 2.6, size)
	_label.text = label_text
	_label.pixel_size = size / 64.0
	repaint()


func repaint() -> void:
	if _label == null:
		return
	var color := Tuning.color("exploration/exit_sign_aimed_color" if _aimed
		else "exploration/exit_sign_color")
	_label.modulate = color
	_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.6)
	var panel := color.darkened(0.72)
	panel.a = Tuning.num("exploration/exit_sign_panel_alpha")
	(_panel.material_override as StandardMaterial3D).albedo_color = panel


## Is the reticle on this sign? Told, not asked: the map knows where the player is
## looking and the sign does not go hunting for them.
func set_aimed(on: bool) -> void:
	if on == _aimed:
		return
	_aimed = on
	repaint()


func is_aimed() -> bool:
	return _aimed


## How far off the reticle this sign is, in degrees, from a point looking a way.
## Negative when it is behind the viewer, which is never a pick.
func offset_degrees(from: Vector3, looking: Vector3) -> float:
	var toward := position - from
	if toward.length_squared() < 0.001 or toward.dot(looking) <= 0.0:
		return -1.0
	return rad_to_deg(toward.normalized().angle_to(looking))
