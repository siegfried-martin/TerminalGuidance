extends CanvasLayer
## In-game tuning panel — a left pane listing every value in tuning.cfg, live.
##
## Autoloaded, so any scene gets it. F2 toggles.
##
## Why this exists rather than editing the file: a slider you can drag while
## watching the missile is a different instrument from a number you type in
## another window. The feel-parameter law is unchanged — values still live in
## tuning.cfg and nowhere else (ADR 0026); this is an editor for that file, and
## Save writes back to it without touching a single comment (ADR 0033).
##
## Labels, tooltips and slider ranges all come from the file's own comments, so
## documenting a value and exposing it are the same act.

signal toggled(open: bool)

const WIDTH_FRACTION := 0.26
const MIN_WIDTH := 340.0

var _root: PanelContainer
var _rows: VBoxContainer
var _filter: LineEdit
var _status: Label
var _save_button: Button
var _controls: Dictionary = {}          ## path -> the widget showing it
var _row_nodes: Dictionary = {}         ## path -> the row Control, for filtering
var _section_headers: Array[Dictionary] = []
var _suppress_refresh := false


func _ready() -> void:
	layer = 120                          # above the debug HUD
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	Tuning.reloaded.connect(_on_tuning_reloaded)
	get_viewport().size_changed.connect(_match_viewport)


# --- construction ------------------------------------------------------------

func _build() -> void:
	_root = PanelContainer.new()
	var style := StyleBoxFlat.new()
	# Opaque: at 94% the debug HUD behind it bleeds through and both become
	# hard to read.
	style.bg_color = Color(0.045, 0.055, 0.075)
	style.border_color = Color(0.22, 0.28, 0.34)
	style.border_width_right = 1
	style.set_content_margin_all(10)
	_root.add_theme_stylebox_override("panel", style)
	add_child(_root)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_root.add_child(column)

	var title := Label.new()
	title.text = "TUNING  ·  F2"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.62, 0.74, 0.86))
	column.add_child(title)

	_filter = LineEdit.new()
	_filter.placeholder_text = "filter…"
	_filter.add_theme_font_size_override("font_size", 13)
	_filter.text_changed.connect(_apply_filter)
	column.add_child(_filter)

	# ScrollContainer gives mouse-wheel scrolling for free, which the list needs.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	column.add_child(scroll)

	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 5)
	scroll.add_child(_rows)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	column.add_child(buttons)

	_save_button = _make_button("Save to tuning.cfg", _on_save)
	_save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_save_button)
	buttons.add_child(_make_button("Revert", _on_revert))

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)

	_populate()
	_match_viewport()


func _make_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(action)
	return button


func _match_viewport() -> void:
	var viewport := get_viewport().get_visible_rect().size
	_root.position = Vector2.ZERO
	_root.size = Vector2(maxf(viewport.x * WIDTH_FRACTION, MIN_WIDTH), viewport.y)


# --- rows --------------------------------------------------------------------

func _populate() -> void:
	for child in _rows.get_children():
		child.queue_free()
	_controls.clear()
	_row_nodes.clear()
	_section_headers.clear()

	var section := ""
	for entry in Tuning.schema():
		if String(entry["section"]) != section:
			section = String(entry["section"])
			_rows.add_child(_make_section_header(section))
		var row := _make_row(entry)
		if row != null:
			_rows.add_child(row)
			_row_nodes[String(entry["path"])] = row
	_refresh_status()


func _make_section_header(section: String) -> Control:
	var label := Label.new()
	label.text = "[%s]" % section
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.98, 0.72, 0.38))
	label.custom_minimum_size.y = 26
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_section_headers.append({"section": section, "node": label})
	return label


func _make_row(entry: Dictionary) -> Control:
	var path := String(entry["path"])
	var value: Variant = Tuning.get_raw(path)
	if value == null:
		return null

	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.tooltip_text = _tooltip_for(entry, value)
	row.mouse_filter = Control.MOUSE_FILTER_PASS

	var label := Label.new()
	label.text = String(entry["key"])
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.78, 0.83, 0.88))
	label.tooltip_text = row.tooltip_text
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(label)

	var editor := _make_editor(path, value, entry)
	editor.tooltip_text = row.tooltip_text
	row.add_child(editor)
	_controls[path] = editor
	return row


func _tooltip_for(entry: Dictionary, value: Variant) -> String:
	var parts: PackedStringArray = [String(entry["path"])]
	var long := String(entry["long"])
	var short := String(entry["short"])
	if not long.is_empty():
		parts.append("")
		parts.append(long)
	if not short.is_empty():
		parts.append("")
		parts.append(short)
	if bool(entry["has_range"]):
		parts.append("")
		parts.append("range %s … %s" % [
			TuningWriter.format_float(float(entry["min"])),
			TuningWriter.format_float(float(entry["max"]))])
	parts.append("")
	parts.append("default in file: %s" % TuningWriter.format_value(value))
	return "\n".join(parts)


func _make_editor(path: String, value: Variant, entry: Dictionary) -> Control:
	match typeof(value):
		TYPE_BOOL:
			var check := CheckBox.new()
			check.button_pressed = bool(value)
			check.text = "on"
			check.add_theme_font_size_override("font_size", 12)
			check.toggled.connect(func(on: bool) -> void: _commit(path, on))
			return check
		TYPE_INT:
			var spin := SpinBox.new()
			spin.step = 1
			spin.allow_greater = true
			spin.allow_lesser = true
			if bool(entry["has_range"]):
				spin.min_value = float(entry["min"])
				spin.max_value = float(entry["max"])
			else:
				spin.min_value = -1000000
				spin.max_value = 1000000
			spin.value = float(value)
			spin.value_changed.connect(func(v: float) -> void: _commit(path, int(v)))
			return spin
		TYPE_FLOAT:
			return _make_float_editor(path, float(value), entry)
		TYPE_COLOR:
			var picker := ColorPickerButton.new()
			picker.color = value as Color
			picker.custom_minimum_size.y = 22
			picker.color_changed.connect(func(c: Color) -> void: _commit(path, c))
			return picker
		TYPE_VECTOR3:
			return _make_vector_editor(path, value as Vector3)
	# Hex colours are stored as strings on purpose (ADR 0033), but editing one by
	# typing hex while watching the screen is hopeless. Give it a picker that
	# writes the value straight back out as "#rrggbb".
	if typeof(value) == TYPE_STRING and _is_hex_colour(String(value)):
		var swatch := ColorPickerButton.new()
		swatch.color = Color(String(value))
		swatch.custom_minimum_size.y = 20
		swatch.color_changed.connect(func(c: Color) -> void:
			_commit(path, "#" + c.to_html(false)))
		return swatch

	var line := LineEdit.new()
	line.text = String(value)
	line.add_theme_font_size_override("font_size", 12)
	line.text_submitted.connect(func(t: String) -> void: _commit(path, t))
	line.focus_exited.connect(func() -> void: _commit(path, line.text))
	return line


static func _is_hex_colour(text: String) -> bool:
	if not text.begins_with("#") or (text.length() != 7 and text.length() != 9):
		return false
	return text.substr(1).is_valid_hex_number(false)


func _make_vector_editor(path: String, value: Vector3) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var spins: Array[SpinBox] = []
	for axis in 3:
		var spin := SpinBox.new()
		spin.step = 0.1
		spin.allow_greater = true
		spin.allow_lesser = true
		spin.min_value = -1000000
		spin.max_value = 1000000
		spin.value = value[axis]
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spins.append(spin)
		box.add_child(spin)
	for spin in spins:
		spin.value_changed.connect(func(_v: float) -> void:
			_commit(path, Vector3(spins[0].value, spins[1].value, spins[2].value)))
	return box


func _make_float_editor(path: String, value: float, entry: Dictionary) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)

	var spin := SpinBox.new()
	spin.step = 0.01
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.min_value = -1000000
	spin.max_value = 1000000
	spin.value = value
	spin.custom_minimum_size.x = 84
	spin.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	if bool(entry["has_range"]):
		var slider := HSlider.new()
		slider.min_value = float(entry["min"])
		slider.max_value = float(entry["max"])
		slider.step = maxf((float(entry["max"]) - float(entry["min"])) / 400.0, 0.0001)
		slider.value = clampf(value, slider.min_value, slider.max_value)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.custom_minimum_size.y = 18
		slider.value_changed.connect(func(v: float) -> void:
			if _suppress_refresh:
				return
			spin.set_value_no_signal(v)
			_commit(path, v))
		spin.value_changed.connect(func(v: float) -> void:
			if _suppress_refresh:
				return
			slider.set_value_no_signal(clampf(v, slider.min_value, slider.max_value))
			_commit(path, v))
		box.add_child(slider)
	else:
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.value_changed.connect(func(v: float) -> void: _commit(path, v))

	box.add_child(spin)
	box.set_meta("spin", spin)
	return box


func _commit(path: String, value: Variant) -> void:
	if _suppress_refresh:
		return
	Tuning.set_value(path, value)
	_refresh_status()


# --- filtering ---------------------------------------------------------------

func _apply_filter(text: String) -> void:
	var needle := text.strip_edges().to_lower()
	var visible_sections := {}
	for path: String in _row_nodes:
		var row := _row_nodes[path] as Control
		var shown := needle.is_empty() or path.to_lower().contains(needle) \
			or row.tooltip_text.to_lower().contains(needle)
		row.visible = shown
		if shown:
			visible_sections[path.split("/")[0]] = true
	for header in _section_headers:
		(header["node"] as Control).visible = \
			needle.is_empty() or visible_sections.has(header["section"])


# --- state -------------------------------------------------------------------

func _on_tuning_reloaded() -> void:
	# A reload from disk replaces everything; rebuild rather than reconcile.
	if Tuning.dirty_paths().is_empty():
		_suppress_refresh = true
		_populate()
		_suppress_refresh = false
	_refresh_status()


func _refresh_status() -> void:
	var dirty := Tuning.dirty_paths()
	var error := Tuning.load_error()
	if not error.is_empty():
		_status.text = "ERROR — " + error
		_status.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	elif dirty.is_empty():
		_status.text = "in sync with tuning.cfg"
		_status.add_theme_color_override("font_color", Color(0.55, 0.7, 0.6))
	else:
		_status.text = "%d unsaved: %s" % [dirty.size(), ", ".join(dirty)]
		_status.add_theme_color_override("font_color", Color(0.98, 0.78, 0.4))
	_save_button.disabled = dirty.is_empty()


func _on_save() -> void:
	if Tuning.save() == OK:
		_status.text = "saved to tuning.cfg"
	_refresh_status()


func _on_revert() -> void:
	Tuning.revert()
	_suppress_refresh = true
	_populate()
	_suppress_refresh = false


# --- visibility --------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle_panel"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	set_open(not visible)


func set_open(open: bool) -> void:
	if visible == open:
		return
	visible = open
	if open:
		_populate()
		# The panel needs the pointer; whoever had it gets it back on close.
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	toggled.emit(open)


func is_open() -> bool:
	return visible


## Number of value rows currently built, for the headless gate.
func row_count() -> int:
	return _row_nodes.size()
