class_name FlightHud
extends CanvasLayer
## The strip along the bottom of the screen: what the ship is doing, or — on a
## highway — where you are and what the next turnings are (ADR 0091).
##
## **Two states, never both.** Off the road it is the ship: throttle and hull, the two
## things a pilot glances down at. On the road the ship is being carried inside a cone
## it may not leave, so the throttle is most of what there is to say about flying and
## the interesting question becomes *which road am I on and what comes off it*. The
## strip swaps rather than growing, because a bar that shows everything shows nothing.
##
## **This replaces the exit signs as the way an exit is taken.** A sign was a thing in
## the world picked with the reticle, and picking it was wrong in a way that could not
## be tuned out: the reticle is a direction from the SHIP, drawn projected from a
## camera that sits behind and above it, so what the player aims at and what the pick
## measures are two different rays. The human's report — *"there's only a tiny margin
## that will let me click it when my mouse enters an area that is near but not on the
## words"* — is exactly that parallax. A button is a button.
##
## Built in code from tuning like everything else (ADR 0027). The `.tscn` files are
## shells and this is not in one.
##
## Nothing here decides anything. It reports what the map already knows and calls back
## with what the player pressed; the rail rebind is still the berth's (ADR 0083).

## Emitted when the player picks an exit. The scene hands it to the berth, which
## rebinds when the ramp actually arrives — clicking is choosing, not steering.
signal exit_picked(ramp: RoadDeck)

var _panel: PanelContainer
var _row: HBoxContainer
## The ship's own readout, and the road's. Exactly one is visible.
var _flight: HBoxContainer
var _nav: HBoxContainer
var _throttle: Label
var _throttle_bar: ProgressBar
var _hull: Label
var _hull_bar: ProgressBar
var _road: Label
var _exits: HBoxContainer
## Which ramps the exit row is currently built for. The row is rebuilt only when the
## LIST changes — rebuilding Controls every frame throws away focus and hover, and a
## button that is replaced under the pointer cannot be clicked.
var _listed: Array[RoadDeck] = []
var _buttons: Array[Button] = []


func _ready() -> void:
	layer = 1

	# ANCHORED TO A POINT, NOT A RECT. A `Control` given `PRESET_BOTTOM_WIDE` has zero
	# height, and anything given `PRESET_FULL_RECT` inside it silently collapses to a
	# degenerate rect — the same trap `FlightOverlay` documents, and the first version of
	# this strip fell into it and rendered nothing. Anchoring the panel itself to the
	# bottom centre and letting it grow from its own minimum size is what makes it size
	# to its contents, which change every time the exit list does.
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_panel)

	_row = HBoxContainer.new()
	_row.name = "Row"
	_panel.add_child(_row)

	_flight = HBoxContainer.new()
	_flight.name = "Flight"
	_row.add_child(_flight)
	_throttle = _make_label("Throttle", _flight)
	_throttle_bar = _make_bar("ThrottleBar", _flight)
	_hull = _make_label("Hull", _flight)
	_hull_bar = _make_bar("HullBar", _flight)

	_nav = HBoxContainer.new()
	_nav.name = "Nav"
	_row.add_child(_nav)
	_road = _make_label("Road", _nav)
	_exits = HBoxContainer.new()
	_exits.name = "Exits"
	_nav.add_child(_exits)

	Tuning.reloaded.connect(_apply_tuning)
	_apply_tuning()
	show_ship(0.0, 1.0)


func _make_label(node_name: String, into: Control) -> Label:
	var label := Label.new()
	label.name = node_name
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	into.add_child(label)
	return label


## A bar rather than a number alone. The number is the reading; the bar is what the eye
## takes in without reading, which is the whole point of a strip you glance at.
func _make_bar(node_name: String, into: Control) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = node_name
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1.0
	into.add_child(bar)
	return bar


func _apply_tuning() -> void:
	var size := Tuning.integer("hud/nav_font_size")
	var height := Tuning.num("hud/nav_bar_height")
	var width := Tuning.num("hud/nav_bar_width")
	for label: Label in [_throttle, _hull, _road]:
		label.add_theme_font_size_override("font_size", size)
		label.add_theme_color_override("font_color",
			Tuning.color("hud/nav_text_color"))
	for bar: ProgressBar in [_throttle_bar, _hull_bar]:
		bar.custom_minimum_size = Vector2(width, height)
	_row.add_theme_constant_override("separation",
		Tuning.integer("hud/nav_separation"))
	_flight.add_theme_constant_override("separation",
		Tuning.integer("hud/nav_separation"))
	_nav.add_theme_constant_override("separation",
		Tuning.integer("hud/nav_separation"))
	_exits.add_theme_constant_override("separation",
		Tuning.integer("hud/nav_separation"))
	var skin := StyleBoxFlat.new()
	var panel := Tuning.color("hud/nav_panel_color")
	panel.a = Tuning.num("hud/nav_panel_alpha")
	skin.bg_color = panel
	var pad := Tuning.integer("hud/nav_padding")
	skin.content_margin_left = pad
	skin.content_margin_right = pad
	skin.content_margin_top = pad
	skin.content_margin_bottom = pad
	skin.corner_radius_top_left = pad
	skin.corner_radius_top_right = pad
	_panel.add_theme_stylebox_override("panel", skin)
	var lift := Tuning.num("hud/nav_bottom_margin")
	_panel.offset_top = -lift
	_panel.offset_bottom = -lift
	for button in _buttons:
		_style(button)


## The ship's own readout: what the throttle is doing and how the hull is.
##
## The hull is a placeholder and says so — `ship/invulnerable` is on for this build, so
## the bar is a shape being reserved rather than a reading. A gauge that looks live and
## is not is the same failure as a screen that lies.
func show_ship(throttle: float, hull: float) -> void:
	_flight.visible = true
	_nav.visible = false
	_throttle.text = "THROTTLE %3.0f%%" % (clampf(throttle, 0.0, 1.0) * 100.0)
	_throttle_bar.value = clampf(throttle, 0.0, 1.0)
	_hull.text = "HULL %3.0f%%" % (clampf(hull, 0.0, 1.0) * 100.0)
	_hull_bar.value = clampf(hull, 0.0, 1.0)


## The road's readout: which highway, which way, and what comes off it.
##
## `exits` is `[[ramp, label, metres_ahead, may_take], …]`, nearest first. A closed
## exit is listed and greyed rather than hidden — a refusal you find out about after
## choosing is not a refusal (ADR 0084). `clickable` is true
## only in a berth — flying, a click that changed which road you were on would be
## autopilot growth (ADR 0013), and that has not changed just because the control moved
## from the world onto a strip.
func show_road(road_name: String, exits: Array, taking: RoadDeck,
		clickable: bool) -> void:
	_flight.visible = false
	_nav.visible = true
	_road.text = road_name
	var ramps: Array[RoadDeck] = []
	for one: Array in exits:
		ramps.append(one[0] as RoadDeck)
	if ramps != _listed:
		_rebuild_exits(exits)
		_listed = ramps
	for i in _buttons.size():
		if i >= exits.size():
			break
		var one: Array = exits[i]
		var ramp := one[0] as RoadDeck
		var metres: float = one[2]
		var may_take: bool = one[3]
		_buttons[i].text = "%s  %s%s" % [one[1] as String, _distance(metres),
			"" if may_take else "  CLOSED"]
		_buttons[i].disabled = not clickable or not may_take
		var tint := Tuning.color("hud/nav_exit_color")
		if not may_take:
			tint = Tuning.color("hud/nav_shut_color")
		elif ramp == taking:
			tint = Tuning.color("hud/nav_taken_color")
		_buttons[i].add_theme_color_override("font_color", tint)
		_buttons[i].add_theme_color_override("font_disabled_color", tint)


## Metres, in the unit a driver reads. Under a kilometre the metres matter; past it
## they do not, and four significant figures on a road sign is noise.
static func _distance(metres: float) -> String:
	if metres < 0.0:
		return "now"
	if metres < 1000.0:
		return "%.0f m" % metres
	return "%.1f km" % (metres / 1000.0)


func _rebuild_exits(exits: Array) -> void:
	for button in _buttons:
		button.queue_free()
	_buttons.clear()
	for one: Array in exits:
		var ramp := one[0] as RoadDeck
		var button := Button.new()
		button.name = String(ramp.name)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: exit_picked.emit(ramp))
		_style(button)
		_exits.add_child(button)
		_buttons.append(button)
	if exits.is_empty():
		var none := Button.new()
		none.name = "NoExits"
		none.text = "no exits ahead"
		none.disabled = true
		none.focus_mode = Control.FOCUS_NONE
		_style(none)
		_exits.add_child(none)
		_buttons.append(none)


func _style(button: Button) -> void:
	button.add_theme_font_size_override("font_size",
		Tuning.integer("hud/nav_font_size"))


## Which exits the strip is currently offering. For the gate; nothing in the game asks.
func listed_exits() -> Array[RoadDeck]:
	return _listed
