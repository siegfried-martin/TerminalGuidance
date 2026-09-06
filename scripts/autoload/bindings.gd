extends Node
## Populates InputMap from `data/input_map.json` at startup.
##
## Bindings live in a data file rather than in project.godot so they stay
## reviewable, diffable and editable without opening the Godot editor. Do not
## add actions through the editor's Input Map tab — they would be invisible
## here and would be clobbered by this autoload anyway.

const PATH := "res://data/input_map.json"

var _actions: PackedStringArray = []
var _errors: PackedStringArray = []


func _ready() -> void:
	apply()


func apply() -> void:
	_actions.clear()
	_errors.clear()
	var text := FileAccess.get_file_as_string(PATH)
	if text.is_empty():
		_error("cannot read %s" % PATH)
		return
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not (parsed as Dictionary).has("actions"):
		_error("%s must be a JSON object with an \"actions\" key" % PATH)
		return
	var actions: Variant = (parsed as Dictionary)["actions"]
	if typeof(actions) != TYPE_DICTIONARY:
		_error("\"actions\" must be an object")
		return
	for action: String in (actions as Dictionary):
		var events: Variant = (actions as Dictionary)[action]
		if typeof(events) != TYPE_ARRAY:
			_error("action '%s': value must be an array of event strings" % action)
			continue
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action)
		for spec: Variant in (events as Array):
			var ev := _parse_event(String(spec), action)
			if ev != null:
				InputMap.action_add_event(action, ev)
		_actions.append(action)
	_actions.sort()


func _parse_event(spec: String, action: String) -> InputEvent:
	var parts := spec.split(":", false, 1)
	if parts.size() != 2:
		_error("action '%s': bad event '%s' (expected 'key:X' or 'mouse:left')" % [action, spec])
		return null
	match parts[0].to_lower():
		"key":
			var keycode := OS.find_keycode_from_string(parts[1])
			if keycode == KEY_NONE:
				_error("action '%s': unknown key '%s'" % [action, parts[1]])
				return null
			var key := InputEventKey.new()
			key.physical_keycode = keycode
			return key
		"mouse":
			var button := _mouse_button(parts[1])
			if button == MOUSE_BUTTON_NONE:
				_error("action '%s': unknown mouse button '%s'" % [action, parts[1]])
				return null
			var mb := InputEventMouseButton.new()
			mb.button_index = button
			return mb
		"joybutton":
			var joy_button := _joy_button(parts[1])
			if joy_button == JOY_BUTTON_INVALID:
				_error("action '%s': unknown joypad button '%s'" % [action, parts[1]])
				return null
			var jb := InputEventJoypadButton.new()
			jb.button_index = joy_button
			return jb
		"joyaxis":
			# Trailing +/- selects the half of the axis the action listens to.
			var sign_char := parts[1].right(1)
			if sign_char != "+" and sign_char != "-":
				_error("action '%s': joyaxis '%s' needs a trailing + or -" % [action, parts[1]])
				return null
			var axis := _joy_axis(parts[1].left(parts[1].length() - 1))
			if axis == JOY_AXIS_INVALID:
				_error("action '%s': unknown joypad axis '%s'" % [action, parts[1]])
				return null
			var jm := InputEventJoypadMotion.new()
			jm.axis = axis
			jm.axis_value = 1.0 if sign_char == "+" else -1.0
			return jm
	_error("action '%s': unknown event kind '%s'" % [action, parts[0]])
	return null


func _mouse_button(name: String) -> MouseButton:
	match name.to_lower():
		"left": return MOUSE_BUTTON_LEFT
		"right": return MOUSE_BUTTON_RIGHT
		"middle": return MOUSE_BUTTON_MIDDLE
		"wheel_up": return MOUSE_BUTTON_WHEEL_UP
		"wheel_down": return MOUSE_BUTTON_WHEEL_DOWN
	return MOUSE_BUTTON_NONE


func _joy_button(name: String) -> JoyButton:
	match name.to_lower():
		"a", "cross": return JOY_BUTTON_A
		"b", "circle": return JOY_BUTTON_B
		"x", "square": return JOY_BUTTON_X
		"y", "triangle": return JOY_BUTTON_Y
		"lb", "l1": return JOY_BUTTON_LEFT_SHOULDER
		"rb", "r1": return JOY_BUTTON_RIGHT_SHOULDER
		"ls", "l3": return JOY_BUTTON_LEFT_STICK
		"rs", "r3": return JOY_BUTTON_RIGHT_STICK
		"back", "select": return JOY_BUTTON_BACK
		"start": return JOY_BUTTON_START
		"dpad_up": return JOY_BUTTON_DPAD_UP
		"dpad_down": return JOY_BUTTON_DPAD_DOWN
		"dpad_left": return JOY_BUTTON_DPAD_LEFT
		"dpad_right": return JOY_BUTTON_DPAD_RIGHT
	return JOY_BUTTON_INVALID


func _joy_axis(name: String) -> JoyAxis:
	match name.to_lower():
		"left_x": return JOY_AXIS_LEFT_X
		"left_y": return JOY_AXIS_LEFT_Y
		"right_x": return JOY_AXIS_RIGHT_X
		"right_y": return JOY_AXIS_RIGHT_Y
		"trigger_left", "lt": return JOY_AXIS_TRIGGER_LEFT
		"trigger_right", "rt": return JOY_AXIS_TRIGGER_RIGHT
	return JOY_AXIS_INVALID


func _error(msg: String) -> void:
	_errors.append(msg)
	push_error("Bindings: " + msg)


func registered_actions() -> PackedStringArray:
	return _actions


func errors() -> PackedStringArray:
	return _errors
