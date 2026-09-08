extends Node
## The map's route data: `data/routes.json`, loaded once and reloaded whenever the
## file changes on disk, the way `Tuning` reloads `tuning.cfg` (ADR 0096).
##
## Routes are DATA rather than tuning because they are what the map IS — where the
## systems are, where each highway runs, which ramps exist — and a number you can only
## nudge in another window is a worse instrument than one that relays the map out
## under you when you save.

signal reloaded

const PATH := "res://data/routes.json"
const POLL_SECONDS := 0.5

var _data: Dictionary = {}
var _error: String = ""
var _mtime: int = 0
var _poll: float = 0.0


func _ready() -> void:
	_load()


func _process(delta: float) -> void:
	_poll += delta
	if _poll < POLL_SECONDS:
		return
	_poll = 0.0
	var m := FileAccess.get_modified_time(ProjectSettings.globalize_path(PATH))
	if m != _mtime and m != 0:
		_load()
		if _error.is_empty():
			print("[routes] reloaded %s" % PATH)
			reloaded.emit()


func _load() -> void:
	_error = ""
	_mtime = FileAccess.get_modified_time(ProjectSettings.globalize_path(PATH))
	var text := FileAccess.get_file_as_string(PATH)
	if text.is_empty():
		_error = "%s is missing or empty" % PATH
		push_error(_error)
		return
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		_error = "%s line %d: %s" % [PATH, json.get_error_line(), json.get_error_message()]
		push_error(_error)
		return
	if not (json.data is Dictionary):
		_error = "%s: top level is not an object" % PATH
		push_error(_error)
		return
	_data = json.data
	for key in ["systems", "highways"]:
		if not _data.has(key):
			_error = "%s: no '%s' entry" % [PATH, key]
			push_error(_error)


func reload() -> void:
	_load()
	reloaded.emit()


func data() -> Dictionary:
	return _data


func load_error() -> String:
	return _error


## Every system's position, by name, in the map's frame.
func system_positions() -> Dictionary:
	var out := {}
	var systems: Dictionary = _data.get("systems", {})
	for name: String in systems:
		var p: Array = systems[name]
		out[name] = Vector3(p[0], p[1], p[2])
	return out


## The systems on a highway, in order, or empty.
func systems_on(highway: String) -> PackedStringArray:
	for h: Dictionary in _data.get("highways", []):
		if String(h.get("name", "")) == highway:
			var out := PackedStringArray()
			for s in h.get("systems", []):
				out.append(String(s))
			return out
	return PackedStringArray()


func highway_names() -> PackedStringArray:
	var out := PackedStringArray()
	for h: Dictionary in _data.get("highways", []):
		out.append(String(h.get("name", "")))
	return out
