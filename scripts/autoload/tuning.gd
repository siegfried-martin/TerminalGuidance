extends Node
## Loads `tuning.cfg` and hot-reloads it whenever the file changes on disk.
##
## The feel-parameter law (see CLAUDE.md): no gameplay-feel constant may appear
## in code. Read every feel value through this singleton, at the point of use.
##
## There is deliberately no `default` argument on the getters. A default is a
## feel constant hiding in code, and it makes a typo'd key silently behave.
## A missing key is loud: it errors, and the debug HUD lists it in red.

signal reloaded

const PATH := "res://tuning.cfg"
## Infrastructure constant, not a feel value: how often the file is stat'd.
const POLL_INTERVAL_SEC := 0.25

var _config := ConfigFile.new()
var _missing: Dictionary = {}
var _last_mtime: int = 0
var _poll_accum: float = 0.0
var _load_error: String = ""
var _reload_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reload()


func _process(delta: float) -> void:
	_poll_accum += delta
	if _poll_accum < POLL_INTERVAL_SEC:
		return
	_poll_accum = 0.0
	var mtime := FileAccess.get_modified_time(PATH)
	# 0 means "unknown" (exported build, packed res://): never reload on that.
	if mtime != 0 and mtime != _last_mtime:
		reload()


## Re-read the file. Safe to call at any time; bound to F5 as well as the poll.
func reload() -> void:
	var mtime := FileAccess.get_modified_time(PATH)
	# Parse into a throwaway first. A half-written file mid-save must not wipe
	# tuning out from under a running session.
	var candidate := ConfigFile.new()
	var err := candidate.load(PATH)
	if err != OK:
		_fail("%s failed to parse (error %d); keeping previous values" % [PATH, err])
		_last_mtime = mtime
		return
	_config = candidate
	_last_mtime = mtime
	_load_error = ""
	_missing.clear()
	_reload_count += 1
	reloaded.emit()


func _fail(msg: String) -> void:
	_load_error = msg
	push_error("Tuning: " + msg)


# --- Typed accessors ---------------------------------------------------------
# `path` is slash-separated, e.g. "missile/turn_rate_deg_per_sec".

func num(path: String) -> float:
	var v: Variant = _lookup(path)
	match typeof(v):
		TYPE_FLOAT, TYPE_INT:
			return float(v)
	return 0.0


func integer(path: String) -> int:
	return int(round(num(path)))


func flag(path: String) -> bool:
	var v: Variant = _lookup(path)
	return typeof(v) == TYPE_BOOL and bool(v)


func text(path: String) -> String:
	var v: Variant = _lookup(path)
	return String(v) if typeof(v) == TYPE_STRING else ""


## Reads a hex string: "#rrggbb" or "#rrggbbaa".
##
## Colours stay strings rather than ConfigFile's Color() literal, which needs four
## float components — "#c9ccd2" is the form a human can read and edit.
func color(path: String) -> Color:
	var value := text(path)
	if value.is_empty():
		return Color.MAGENTA  # loud on purpose
	return Color(value)


## Reads a Vector3(x, y, z) literal.
func vec3(path: String) -> Vector3:
	var v: Variant = _lookup(path)
	if typeof(v) == TYPE_VECTOR3:
		return v as Vector3
	if v != null:
		_note_missing(path, "expected Vector3(x, y, z), got %s" % type_string(typeof(v)))
	return Vector3.ZERO


func has(path: String) -> bool:
	return _lookup_quiet(path) != null


# --- Introspection, for the debug HUD and headless tests ---------------------

func missing_keys() -> PackedStringArray:
	var out: PackedStringArray = []
	for k: String in _missing:
		out.append(k if String(_missing[k]).is_empty() else "%s (%s)" % [k, _missing[k]])
	out.sort()
	return out


func load_error() -> String:
	return _load_error


func reload_count() -> int:
	return _reload_count


# --- Internals ---------------------------------------------------------------

func _lookup(path: String) -> Variant:
	var v: Variant = _lookup_quiet(path)
	if v == null:
		_note_missing(path, "")
	return v


## `path` is "section/key". A key may itself contain slashes — only the first
## segment is the section — so "camera/ship/follow_distance" would look up key
## "ship/follow_distance" in section [camera] if the file were ever nested deeper.
func _lookup_quiet(path: String) -> Variant:
	var split := path.split("/", false, 1)
	if split.size() != 2:
		return null
	if not _config.has_section_key(split[0], split[1]):
		return null
	return _config.get_value(split[0], split[1])


func _note_missing(path: String, why: String) -> void:
	if _missing.has(path):
		return
	_missing[path] = why
	push_error("Tuning: missing key '%s' in %s%s" % [path, PATH, "" if why.is_empty() else " — " + why])
