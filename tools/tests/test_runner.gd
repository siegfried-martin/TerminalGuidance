extends Node
## Headless test + lint harness.  `make check`  /  `godot --headless --scene res://tools/tests/test_runner.tscn`
##
## Runs inside a real scene tree rather than as `--script`, because autoloads
## (Tuning, Bindings) only exist when the project's main loop is up — a bare
## `--check-only --script` run reports "Identifier not found: Tuning" and is
## therefore useless as a gate for any script that reads a tuning value.
##
## Exit code is 0 only if every check passes.

const SCRIPT_DIRS: Array[String] = ["res://scripts", "res://tools"]

## Godot 3.x API denylist lives in a data file so the linter cannot flag itself.
const GODOT3_DENYLIST := "res://tools/tests/godot3_denylist.json"

## Tuning keys the sandbox needs. Keeping the list here means a rename in
## tuning.json fails the build instead of silently zeroing a feel value.
const REQUIRED_TUNING_KEYS: Array[String] = [
	"camera/free_move_speed", "camera/free_boost_multiplier", "camera/free_look_sensitivity",
	"camera/free_move_smoothing", "camera/fov_base",
	"camera/start_position", "camera/start_look_at",
	"arena/marker_spacing", "arena/marker_count_per_axis", "arena/marker_size",
	"arena/marker_color", "arena/background_color", "arena/ambient_energy",
	"arena/key_light_energy", "arena/key_light_angles_deg",
	"arena/fill_light_energy", "arena/fill_light_angles_deg",
	"probe/scale", "probe/spin_deg_per_sec", "probe/bob_amplitude", "probe/bob_period_sec",
	"probe/hull_tint", "probe/metallic", "probe/roughness",
]

const REQUIRED_ACTIONS: Array[String] = [
	"cam_forward", "cam_back", "cam_left", "cam_right", "cam_up", "cam_down",
	"cam_boost", "cam_look", "debug_toggle_hud", "debug_reload_tuning", "quit",
]

var _failures: PackedStringArray = []
var _checks: int = 0


func _ready() -> void:
	print("── missile rider: headless checks ──")
	_test_tuning()
	_test_bindings()
	_test_scripts_compile()
	_test_no_godot3_api()
	_test_assets()
	await _test_sandbox_builds()

	print("── %d checks, %d failed ──" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAIL  " + f)
	get_tree().quit(0 if _failures.is_empty() else 1)


# --- checks ------------------------------------------------------------------

func _test_tuning() -> void:
	_expect(Tuning.load_error().is_empty(), "tuning.json parses", Tuning.load_error())
	for key in REQUIRED_TUNING_KEYS:
		_expect(Tuning.has(key), "tuning key present: " + key, "missing from tuning.json")


func _test_bindings() -> void:
	_expect(Bindings.errors().is_empty(), "input_map.json parses", ", ".join(Bindings.errors()))
	for action in REQUIRED_ACTIONS:
		_expect(InputMap.has_action(action), "input action bound: " + action, "not in data/input_map.json")
		if InputMap.has_action(action):
			_expect(InputMap.action_get_events(action).size() > 0, "input action has an event: " + action, "empty binding")


func _test_scripts_compile() -> void:
	for path in _gd_files():
		# CACHE_MODE_REUSE deliberately: re-loading a `class_name` script with
		# CACHE_MODE_IGNORE duplicates it in the global class table and segfaults 4.7.
		var res: Resource = ResourceLoader.load(path, "Script")
		var script := res as GDScript
		# load() still returns a GDScript object for a file that failed to parse.
		# can_instantiate() is the signal that actually flips. (It would also be
		# false for an abstract or static-only script; there are none yet, and a
		# spurious failure here is the safe direction.)
		_expect(script != null and script.can_instantiate(), "compiles: " + path,
			"parse or compile error — see the SCRIPT ERROR above")


func _test_no_godot3_api() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(GODOT3_DENYLIST))
	if typeof(raw) != TYPE_DICTIONARY or not (raw as Dictionary).has("rules"):
		_fail("cannot read denylist " + GODOT3_DENYLIST)
		return
	var rules: Array = (raw as Dictionary)["rules"]

	var compiled: Array[Dictionary] = []
	for rule: Variant in rules:
		var d := rule as Dictionary
		var re := RegEx.new()
		if re.compile(String(d["pattern"])) != OK:
			_fail("denylist pattern does not compile: " + String(d["pattern"]))
			continue
		compiled.append({"re": re, "why": String(d["why"])})

	var hits := 0
	for path in _gd_files():
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var line := lines[i]
			if line.contains("godot4-lint: ignore"):
				continue
			for c in compiled:
				if (c["re"] as RegEx).search(line) != null:
					hits += 1
					_fail("%s:%d — %s\n          %s" % [path, i + 1, c["why"], line.strip_edges()])
	_expect(hits == 0, "no Godot 3 APIs in %d scripts (%d rules)" % [_gd_files().size(), compiled.size()], "%d hits" % hits)


func _test_assets() -> void:
	var mesh := load("res://assets/models/probe.obj") as Mesh
	_expect(mesh != null, "probe.obj imports as a Mesh", "import failed — run `make import`")
	if mesh != null:
		_expect(mesh.get_surface_count() > 0, "probe.obj has surfaces", "0 surfaces")
		var aabb := mesh.get_aabb()
		_expect(aabb.size.length() > 0.1, "probe.obj has non-degenerate bounds", str(aabb))

	var tex := load("res://assets/textures/hull_panels.png") as Texture2D
	_expect(tex != null, "hull_panels.png imports as a Texture2D", "import failed")
	if tex != null:
		_expect(tex.get_width() > 0 and tex.get_height() > 0, "hull texture has size", "0x0")


func _test_sandbox_builds() -> void:
	var packed := load("res://scenes/sandbox.tscn") as PackedScene
	_expect(packed != null, "sandbox.tscn loads", "scene failed to load")
	if packed == null:
		return
	var scene := packed.instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame

	for child_name in ["WorldEnvironment", "KeyLight", "Arena", "Probe", "DebugCamera", "DebugHud"]:
		_expect(scene.has_node(child_name), "sandbox builds node: " + child_name, "not constructed in _ready()")

	var arena := scene.get_node_or_null("Arena") as GrayBoxArena
	if arena != null:
		var per_axis := Tuning.integer("arena/marker_count_per_axis")
		_expect(arena.marker_count() == per_axis ** 3,
			"arena lattice matches tuning (%d³)" % per_axis,
			"got %d markers" % arena.marker_count())

	var probe := scene.get_node_or_null("Probe") as MeshInstance3D
	if probe != null:
		_expect(is_equal_approx(probe.scale.x, Tuning.num("probe/scale")),
			"probe scale comes from tuning", "scale=%s" % probe.scale)

	_expect(Tuning.missing_keys().is_empty(), "no tuning key was requested and missing",
		", ".join(Tuning.missing_keys()))
	scene.queue_free()


# --- helpers -----------------------------------------------------------------

func _gd_files() -> PackedStringArray:
	var out: PackedStringArray = []
	for root in SCRIPT_DIRS:
		_walk(root, out)
	out.sort()
	return out


func _walk(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full := dir_path.path_join(entry)
			if dir.current_is_dir():
				_walk(full, out)
			elif entry.ends_with(".gd"):
				out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()


func _expect(condition: bool, what: String, detail: String) -> void:
	_checks += 1
	if condition:
		print("  ok    " + what)
	else:
		_fail("%s — %s" % [what, detail])


func _fail(msg: String) -> void:
	_failures.append(msg)
