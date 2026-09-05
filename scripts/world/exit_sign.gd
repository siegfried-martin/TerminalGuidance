class_name ExitSign
extends Node3D
## A sign on the road, ahead of an exit, naming where that exit goes.
##
## **A sign is not a map** (ADR 0083). It is an object in the world, mounted on the
## structure at a place you can see it from, and reading it early enough to use it is
## a piloting act. The player chooses at the moment they can see the choice; nothing
## plans, nothing routes, and there is no list of destinations anywhere.
##
## **It is no longer clicked, and by default it is not drawn** (ADR 0091). An exit is
## read and taken on the strip along the bottom of the screen, because picking a sign
## with the reticle could not be made to work: the reticle is a direction from the SHIP
## and it is drawn projected from a camera behind and above it, so what the player aims
## at and what the pick measured were two different rays. What is left here is the sign
## as scenery, behind `exit_signs_visible`, and the record of which exit belongs to
## which carriageway — which the strip reads.
##
## Drawn the way a `Portal` draws its destination — a billboard label with a panel
## behind it — because they are the same kind of object to the player: text on the
## road that says where something goes.

## Which road this sign is for. Clicking it binds the berth to this deck when the ship
## reaches it.
var ramp: RoadDeck = null
## The carriageway this sign is mounted for — the road you have to be on for this exit
## to be yours to take.
##
## **Authored where the sign is hung, never worked out from geometry** (ADR 0088). It
## used to be inferred by comparing the ramp's leaving direction against the road axis
## under the ship, which is right on a straight and wrong everywhere else: on a bend,
## and on the curving on-ramp a player joins by, every exit ahead fell outside the cone
## and no sign was takeable at all. Which wall a sign is bolted to is a fact, and the
## fact is the test.
var from_deck: RoadDeck = null
## What it reads. The place the exit serves, not the road it hangs over.
var label_text: String = ""

var _label: Label3D
var _panel: MeshInstance3D
## Whether this is the exit the berth has been told to take. SET by the map each frame;
## the sign does not look for the player. The "the reticle is on this one" state went
## with the pick (ADR 0091) — the strip along the bottom carries it now.
var _selected: bool = false
## Whether this exit is one the player could take from where they are. A sign for a
## road going somewhere else is not drawn at all: the two carriageways share one
## building with glass down the middle and a second highway crosses it, so every sign
## on the map was legible from every seat and the road read as noise (ADR 0088).
var _relevant: bool = false


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
	visible = false
	rebuild()


func rebuild() -> void:
	if _label == null:
		return
	var size := Tuning.num("exploration/exit_sign_metres")
	# A LIT SIGN IS A BIGGER SIGN. Colour alone is a weak signal at the lead distance
	# the road gives — a sign 1400 m out is a small mark in the frame — so the one that
	# is going to happen grows as well as brightens.
	if _selected:
		size *= Tuning.num("exploration/exit_sign_selected_scale")
	(_panel.mesh as QuadMesh).size = Vector2(size * 2.6, size)
	_label.text = label_text
	_label.pixel_size = size / 64.0
	repaint()


func repaint() -> void:
	if _label == null:
		return
	var key := "exploration/exit_sign_color"
	if _selected:
		key = "exploration/exit_sign_selected_color"
	var color := Tuning.color(key)
	_label.modulate = color
	_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.6)
	var panel := color.darkened(0.72)
	panel.a = Tuning.num("exploration/exit_sign_selected_panel_alpha" if _selected
		else "exploration/exit_sign_panel_alpha")
	(_panel.material_override as StandardMaterial3D).albedo_color = panel


## Is this exit takeable from where the player is? Told, not asked, exactly as `aimed`
## is — the map knows which road the ship is on and the sign does not go looking.
func set_relevant(on: bool) -> void:
	_relevant = on
	visible = on and Tuning.flag("exploration/exit_signs_visible")


func is_relevant() -> bool:
	return _relevant


## Is this the exit that is actually going to happen? The one state a player in a
## hurry has to be able to read at a glance.
func set_selected(on: bool) -> void:
	if on == _selected:
		return
	_selected = on
	rebuild()


func is_selected() -> bool:
	return _selected

