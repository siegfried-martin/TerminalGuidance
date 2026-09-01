class_name DockScreen
extends CanvasLayer
## What you see once an approach has resolved: the services this place offers, and
## the way out (ADR 0012 — the envelope "doubles as the landing UI").
##
## Deliberately thin. The doc asks for refuel, rearm and depart and *"nothing
## else"*, and of those only depart has anything behind it yet — cruise fuel is POC
## step 7 and the exploration scene carries no missiles. So the screen is built as a
## **list of services** with one row in it, and step 7 adds a row rather than
## reworking a layout. Dead placeholder buttons would be worse than a short list:
## they teach the player that this screen lies.
##
## Mounted by whatever owns the envelope, so a station on a portal ramp shows the
## same screen with a different service list.

signal departed

var _panel: PanelContainer
var _rows: VBoxContainer
var _title: Label


func _ready() -> void:
	layer = 2
	visible = false

	var centre := CenterContainer.new()
	centre.name = "Centre"
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	centre.add_child(_panel)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)

	_title = Label.new()
	_title.name = "Title"
	column.add_child(_title)

	_rows = VBoxContainer.new()
	_rows.name = "Services"
	_rows.add_theme_constant_override("separation", 6)
	column.add_child(_rows)

	add_service("Depart", func() -> void: departed.emit())
	Tuning.reloaded.connect(_apply_tuning)
	_apply_tuning()


## Add a service. Step 7's "refuel cruise tank" and the magazine refill are each one
## of these, not a change to this file.
##
## `at_top` puts it above `Depart`, which is where a service belongs: `open` focuses
## the first row, and a screen that lands the focus on the way out is a screen whose
## default answer is "leave". Depart is built first only because it is the one thing
## every place offers.
func add_service(label: String, action: Callable, at_top: bool = false) -> Button:
	var button := Button.new()
	button.name = label
	button.text = label
	button.pressed.connect(action)
	_rows.add_child(button)
	if at_top:
		_rows.move_child(button, 0)
	return button


func open(place: String) -> void:
	_title.text = place
	visible = true
	# The pointer is a pointer here rather than a stick. Whoever opened this is
	# responsible for taking it back on close.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var first := _rows.get_child(0) as Button
	if first != null:
		first.grab_focus()


func close() -> void:
	visible = false


func _apply_tuning() -> void:
	_title.add_theme_font_size_override(
		"font_size", Tuning.integer("exploration/dock_title_font_size"))
	_title.add_theme_color_override(
		"font_color", Tuning.color("exploration/dock_title_color"))
