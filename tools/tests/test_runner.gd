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
## tuning.cfg fails the build instead of silently zeroing a feel value.
const REQUIRED_TUNING_KEYS: Array[String] = [
	"missile/base_speed", "missile/turn_rate_deg_per_sec", "missile/fuse_seconds",
	"missile/velocity_inheritance", "missile/reticle_max_angle_deg",
	"missile/body_length", "missile/body_width", "missile/body_color",
	"missile/exhaust_length", "missile/exhaust_color",
	"missile/flash_start_radius", "missile/flash_end_radius",
	"missile/flash_seconds", "missile/flash_color", "missile/flash_color_dud",
	"missile/boost_multiplier", "missile/boost_seconds", "missile/boost_regen_per_sec",
	"missile/strafe_speed", "missile/strafe_ramp_seconds", "missile/strafe_release_seconds",
	"ship/arc_speed", "ship/standoff_distance", "ship/muzzle_offset", "ship/hull_scale",
	"ship/range_hold_seconds", "ship/range_hold_max_speed",
	"ship/hull_tint", "ship/metallic", "ship/roughness",
	"enemy/radius", "enemy/drift_speed", "enemy/spin_deg_per_sec",
	"enemy/patrol_half_extent", "enemy/hull_color", "enemy/hull_emission",
	"camera/fov_base", "camera/return_delay_sec", "camera/missile_view_mode",
	"camera/ship_follow_distance", "camera/ship_follow_height", "camera/ship_follow_lag",
	"camera/ship_look_ahead",
	"camera/missile_follow_distance", "camera/missile_follow_height",
	"camera/missile_follow_lag", "camera/missile_look_ahead",
	"camera/free_move_speed", "camera/free_boost_multiplier", "camera/free_look_sensitivity",
	"camera/free_move_smoothing", "camera/start_position", "camera/start_look_at",
	"controls/mouse_sensitivity", "controls/stick_reticle_speed_deg_per_sec",
	"controls/deadzone",
	"hud/font_size", "hud/line_width",
	"hud/target_color", "hud/target_bracket_size", "hud/arrow_size", "hud/edge_margin",
	"hud/reticle_color", "hud/reticle_size", "hud/reticle_distance",
	"hud/reticle_lag_line_alpha",
	"arena/marker_spacing", "arena/marker_count_per_axis", "arena/marker_size",
	"arena/marker_color", "arena/background_color", "arena/ambient_energy",
	"arena/glow_enabled", "arena/glow_intensity",
	"arena/key_light_energy", "arena/key_light_angles_deg",
	"arena/fill_light_energy", "arena/fill_light_angles_deg",
	"arena/rock_count", "arena/rock_inner_radius", "arena/rock_outer_radius",
	"arena/rock_slab_half_height", "arena/rock_min_size", "arena/rock_max_size",
	"arena/rock_color", "arena/rock_seed",
	"arena/rock_collision", "arena/rock_hit_radius_scale",
	"probe/scale", "probe/spin_deg_per_sec", "probe/bob_amplitude", "probe/bob_period_sec",
	"probe/hull_tint", "probe/metallic", "probe/roughness",
]

const REQUIRED_ACTIONS: Array[String] = [
	"fire", "detonate", "boost",
	"missile_left", "missile_right", "missile_up", "missile_down",
	"missile_strafe_left", "missile_strafe_right",
	"missile_strafe_up", "missile_strafe_down",
	"cam_forward", "cam_back", "cam_left", "cam_right", "cam_up", "cam_down",
	"cam_boost", "cam_look",
	"debug_toggle_hud", "debug_toggle_panel", "debug_reload_tuning",
	"debug_reverse_arc", "quit",
]

var _failures: PackedStringArray = []
var _checks: int = 0


func _ready() -> void:
	print("── missile rider: headless checks ──")
	_test_tuning()
	_test_tuning_file_hygiene()
	_test_bindings()
	_test_scripts_compile()
	_test_no_godot3_api()
	_test_assets()
	_test_flight_geometry()
	_test_missile_flight()
	_test_reticle_steering()
	_test_reference_field()
	_test_tuning_schema()
	_test_tuning_writer()
	_test_debug_panel()
	_test_autopilot_holds_standoff()
	await _test_sandbox_builds()
	await _test_arena_builds()

	print("── %d checks, %d failed ──" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAIL  " + f)
	get_tree().quit(0 if _failures.is_empty() else 1)


# --- checks ------------------------------------------------------------------

func _test_tuning() -> void:
	_expect(Tuning.load_error().is_empty(), "tuning.cfg parses", Tuning.load_error())
	for key in REQUIRED_TUNING_KEYS:
		_expect(Tuning.has(key), "tuning key present: " + key, "missing from tuning.cfg")


## `#` is not a comment character in a ConfigFile — it is parsed into the next key
## and corrupts the file with no obvious error (ADR 0033). It is legitimate inside
## a quoted string, which is how hex colours are written. Catch the other case.
func _test_tuning_file_hygiene() -> void:
	var lines := FileAccess.get_file_as_string(Tuning.PATH).split("\n")
	var offenders: PackedStringArray = []
	for i in lines.size():
		var outside := _outside_quotes(lines[i])
		var comment_at := outside.find(";")
		if comment_at >= 0:
			outside = outside.substr(0, comment_at)
		if outside.contains("#"):
			offenders.append("line %d: %s" % [i + 1, lines[i].strip_edges()])
	_expect(offenders.is_empty(),
		"tuning.cfg uses ';' for comments, never '#'", ", ".join(offenders))


## Everything on the line that is not inside double quotes.
func _outside_quotes(line: String) -> String:
	var parts := line.split("\"")
	var out := ""
	for i in parts.size():
		if i % 2 == 0:
			out += parts[i]
	return out


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


func _test_flight_geometry() -> void:
	_expect(FlightGeometry.segment_hits_sphere(
			Vector3(0, 0, 0), Vector3(0, 0, 100), Vector3(0, 0, 50), 5.0),
		"swept segment hits a sphere on its path", "missed a direct pass")
	_expect(not FlightGeometry.segment_hits_sphere(
			Vector3(0, 0, 0), Vector3(0, 0, 100), Vector3(40, 0, 50), 5.0),
		"swept segment misses a sphere off its path", "false positive")
	# The reason the test is swept and not per-point: a fast missile steps clean
	# over a small target between frames.
	_expect(FlightGeometry.segment_hits_sphere(
			Vector3(0, 0, -10), Vector3(0, 0, 10), Vector3.ZERO, 2.0),
		"swept segment catches a target it would tunnel past", "tunnelled")
	_expect(not FlightGeometry.segment_hits_sphere(
			Vector3(0, 0, 20), Vector3(0, 0, 40), Vector3.ZERO, 2.0),
		"swept segment does not hit behind its start", "hit something behind it")

	var cone := FlightGeometry.clamp_to_cone(
		Vector3(1, 0, 0), Vector3(0, 0, -1), deg_to_rad(30.0))
	_expect(is_equal_approx(rad_to_deg(cone.angle_to(Vector3(0, 0, -1))), 30.0),
		"clamp_to_cone pulls a wide direction back to the cone edge",
		"%.2f deg" % rad_to_deg(cone.angle_to(Vector3(0, 0, -1))))
	var inside := FlightGeometry.clamp_to_cone(
		Vector3(0, 0, -1).rotated(Vector3.UP, deg_to_rad(10.0)), Vector3(0, 0, -1), deg_to_rad(30.0))
	_expect(is_equal_approx(rad_to_deg(inside.angle_to(Vector3(0, 0, -1))), 10.0),
		"clamp_to_cone leaves a direction already inside the cone alone",
		"%.2f deg" % rad_to_deg(inside.angle_to(Vector3(0, 0, -1))))

	var partial := FlightGeometry.turn_towards(
		Vector3(0, 0, -1), Vector3(1, 0, 0), deg_to_rad(15.0))
	_expect(is_equal_approx(rad_to_deg(partial.angle_to(Vector3(0, 0, -1))), 15.0),
		"turn_towards moves by exactly the step when the target is further",
		"%.2f deg" % rad_to_deg(partial.angle_to(Vector3(0, 0, -1))))

	var from_forward := FlightGeometry.basis_from_forward(Vector3(0.3, 0.2, -1).normalized())
	_expect(is_equal_approx(from_forward.determinant(), 1.0),
		"basis_from_forward stays right-handed", "det=%f" % from_forward.determinant())
	_expect(absf(from_forward.x.dot(Vector3.UP)) < 0.0001,
		"basis_from_forward has no roll", "right=%s" % from_forward.x)
	var vertical := FlightGeometry.basis_from_forward(Vector3.UP)
	_expect(is_equal_approx(vertical.determinant(), 1.0),
		"basis_from_forward survives a straight-up heading",
		"det=%f" % vertical.determinant())

	var steered := FlightGeometry.steer_basis(Basis.IDENTITY, deg_to_rad(30.0), 0.0)
	_expect(absf(steered.x.dot(Vector3.UP)) < 0.0001,
		"steering leaves roll at zero", "right vector picked up roll: %s" % steered.x)
	var forward := -steered.z
	_expect(forward.x < -0.001 and forward.z < 0.0,
		"positive yaw turns the nose consistently", "forward=%s" % forward)
	_expect(is_equal_approx(steered.determinant(), 1.0),
		"steering keeps the basis orthonormal", "det=%f" % steered.determinant())


func _test_missile_flight() -> void:
	# Free-standing, stepped by hand: no scene tree, no frame timing, no waiting on
	# a 5-second fuse. Deterministic because an unpiloted missile reads no input.
	var target := Node3D.new()
	target.position = Vector3(0, 0, -240)

	var outcome := {"fired": false, "hit": false, "reason": -1}
	var missile := Missile.new()
	missile.detonated.connect(func(_m: Missile, reason: int, hit: bool) -> void:
		outcome["fired"] = true
		outcome["hit"] = hit
		outcome["reason"] = reason)
	missile.launch(Vector3.ZERO, Basis.IDENTITY, Vector3.ZERO, target, 9.0)

	_expect(is_equal_approx(missile.fuse_remaining(), Tuning.num("missile/fuse_seconds")),
		"missile fuse is armed from tuning", "%f" % missile.fuse_remaining())
	_expect(is_equal_approx(missile.speed(), Tuning.num("missile/base_speed")),
		"missile speed is base_speed at zero inheritance", "%f" % missile.speed())

	var step := 1.0 / 60.0
	for _i in 600:
		if outcome["fired"]:
			break
		missile._process(step)

	_expect(bool(outcome["fired"]), "a missile fired straight at the target resolves",
		"still flying after 10 simulated seconds")
	_expect(bool(outcome["hit"]), "…and it resolves as a hit",
		"reason=%d" % int(outcome["reason"]))
	_expect(int(outcome["reason"]) == Missile.EndReason.IMPACT,
		"…for the impact reason", "reason=%d" % int(outcome["reason"]))
	target.free()

	# A missile pointed away must run its fuse out and report a miss.
	var away_outcome := {"fired": false, "hit": true}
	var away_target := Node3D.new()
	away_target.position = Vector3(0, 0, -240)
	var away := Missile.new()
	away.detonated.connect(func(_m: Missile, _r: int, hit: bool) -> void:
		away_outcome["fired"] = true
		away_outcome["hit"] = hit)
	away.launch(Vector3.ZERO, Basis.IDENTITY.rotated(Vector3.UP, PI), Vector3.ZERO,
		away_target, 9.0)
	for _i in 600:
		if away_outcome["fired"]:
			break
		away._process(step)
	_expect(bool(away_outcome["fired"]) and not bool(away_outcome["hit"]),
		"a missile pointed away expires on its fuse", "did not miss cleanly")
	away_target.free()


## Regression: the reticle is an intended direction the missile chases, not a
## direct rotation of the missile (ADR 0035).
func _test_reticle_steering() -> void:
	var missile := Missile.new()
	missile.piloted = true
	add_child(missile)
	missile.launch(Vector3.ZERO, Basis.IDENTITY, Vector3.ZERO, null, 0.0)

	var step := 1.0 / 60.0
	var max_turn_per_step := Tuning.num("missile/turn_rate_deg_per_sec") * step

	# A hard flick of the mouse: far more than one frame of turn.
	missile.add_mouse_steer(Vector2(400.0, 0.0))
	var before := -missile.basis.z
	missile._process(step)
	var after := -missile.basis.z
	var turned := rad_to_deg(before.angle_to(after))

	_expect(turned <= max_turn_per_step + 0.001,
		"a flick cannot turn the missile faster than its turn rate",
		"turned %.2f deg in one step, cap is %.2f" % [turned, max_turn_per_step])
	_expect(missile.aim_offset_degrees() > 1.0,
		"the reticle leads the nose after a flick",
		"offset %.2f deg — the missile is tracking input directly" % missile.aim_offset_degrees())

	# Hold the flick: the reticle must stop at the cone edge, not run away.
	for _i in 120:
		missile.add_mouse_steer(Vector2(400.0, 0.0))
		missile._process(step)
	var limit := Tuning.num("missile/reticle_max_angle_deg")
	_expect(missile.aim_offset_degrees() <= limit + 0.5,
		"the reticle stays inside its cone",
		"offset %.2f deg exceeds reticle_max_angle_deg %.2f" % [
			missile.aim_offset_degrees(), limit])

	# Released, the missile should catch up to where the reticle is parked.
	for _i in 240:
		missile._process(step)
	_expect(missile.aim_offset_degrees() < 1.0,
		"the missile catches up to a stationary reticle",
		"still %.2f deg behind" % missile.aim_offset_degrees())
	missile.queue_free()


## Regression for the bug that made hot reload look broken: the autopilot has to
## actually hold the tuned standoff against a drifting target. The original
## controller normalised tangent and radial together, so its range authority
## collapsed at the setpoint and the held range wandered away indefinitely.
func _test_autopilot_holds_standoff() -> void:
	var target := Node3D.new()
	add_child(target)
	var ship := Mothership.new()
	add_child(ship)
	ship.set_process(false)   # stepped by hand below
	ship.target = target
	ship.position = Vector3(0.0, 0.0, 1.0)   # a bearing to snap along, as the arena does
	ship.snap_to_standoff()

	var standoff := Tuning.num("ship/standoff_distance")
	_expect(is_equal_approx(ship.range_to_target(), standoff),
		"snap_to_standoff lands exactly on the tuned distance",
		"%.1f m vs %.1f m" % [ship.range_to_target(), standoff])

	var step := 1.0 / 60.0
	var drift := Tuning.num("enemy/drift_speed")
	var worst := 0.0
	for i in 1800:   # 30 simulated seconds
		target.position += Vector3(1.0, 0.0, 0.3).normalized() * drift * step
		ship._process(step)
		if i > 240:   # let it settle first
			worst = maxf(worst, absf(ship.range_to_target() - standoff))

	# Steady-state error is bounded by drift * range_hold_seconds; allow headroom.
	var allowed := drift * Tuning.num("ship/range_hold_seconds") * 2.5
	_expect(worst <= allowed,
		"autopilot holds standoff against a drifting target over 30 s",
		"drifted %.1f m off, budget is %.1f m" % [worst, allowed])

	# And a standoff edit must be visible at once, not converged towards.
	ship.position = target.position + Vector3(0.0, 0.0, standoff * 3.0)
	ship.snap_to_standoff()
	_expect(absf(ship.range_to_target() - standoff) < 0.01,
		"a standoff change applies immediately, not over tens of seconds",
		"%.1f m after snap" % ship.range_to_target())

	ship.queue_free()
	target.queue_free()


const SAMPLE_CFG := """; banner comment, not documentation
[missile]

;; First line of the long description.
;; Second line.
base_speed = 90.0                  ; [20..400] m/s, the short label
plain = 3                          ; no range on this one
quoted = "a ; semicolon inside"    ; and a real comment after it
bare = true
"""


## The rock field is the only thing in the arena a missile can collide with, and
## it does so without a physics body (ADR 0032 mechanism, ADR 0038 placement). All
## of that is plain geometry, so it is verifiable headlessly.
func _test_reference_field() -> void:
	var field := ReferenceField.new()
	add_child(field)

	_expect(field.rock_count() == Tuning.integer("arena/rock_count"),
		"reference field builds every tuned rock",
		"drew %d of %d" % [field.rock_count(), Tuning.integer("arena/rock_count")])
	_expect(field.hittable_count() == field.rock_count(),
		"every drawn rock is hittable while rock_collision is on",
		"%d drawn, %d hittable" % [field.rock_count(), field.hittable_count()])

	if field.rock_count() > 0:
		var centre := field.rock_centre(0)
		var radius := field.rock_radius(0)
		_expect(radius > 0.0, "a rock has a positive hit radius", "radius=%f" % radius)

		var above := centre + Vector3(0.0, radius * 4.0, 0.0)
		var below := centre - Vector3(0.0, radius * 4.0, 0.0)
		_expect(field.hit_test(above, below) != Vector3.INF,
			"hit_test catches a segment through a rock", "passed straight through")

		# The whole reason for a swept test: both endpoints sit clear of the rock,
		# so a per-frame point check would report a clean miss (ADR 0032).
		_expect(field.hit_test(above, below) == centre,
			"hit_test reports which rock was hit", "wrong centre returned")

		var far_away := centre + Vector3(0.0, radius * 50.0, 0.0)
		_expect(field.hit_test(far_away, far_away + Vector3(0.0, 1.0, 0.0)) == Vector3.INF,
			"hit_test lets a clear segment through", "false positive")

	# rock_collision is the escape hatch back to the pre-ADR-0038 arena, so it has
	# to actually disarm the field rather than merely hiding the readout.
	Tuning.set_value("arena/rock_collision", false)
	field.rebuild()
	_expect(field.hittable_count() == 0,
		"rock_collision = false disarms the field", "%d still hittable" % field.hittable_count())
	_expect(field.hit_test(Vector3(-9000.0, 0.0, 0.0), Vector3(9000.0, 0.0, 0.0)) == Vector3.INF,
		"rock_collision = false makes rocks pure scenery", "still collided")
	Tuning.revert()
	field.rebuild()
	_expect(field.hittable_count() == field.rock_count(),
		"reverting tuning re-arms the field", "revert left the field disarmed")

	field.queue_free()


func _test_tuning_schema() -> void:
	var entries := TuningSchema.parse(SAMPLE_CFG)
	_expect(entries.size() == 4, "schema finds every key", "found %d" % entries.size())
	if entries.size() < 4:
		return

	var first := entries[0]
	_expect(String(first["path"]) == "missile/base_speed", "schema builds section/key paths",
		String(first["path"]))
	_expect(String(first["long"]) == "First line of the long description.\nSecond line.",
		"';;' lines become the long description", String(first["long"]))
	_expect(String(first["short"]) == "m/s, the short label",
		"the range marker is stripped out of the short label", String(first["short"]))
	_expect(bool(first["has_range"]) and is_equal_approx(float(first["min"]), 20.0)
			and is_equal_approx(float(first["max"]), 400.0),
		"'[min..max]' parses into a slider range",
		"%s %f..%f" % [first["has_range"], first["min"], first["max"]])

	_expect(not bool(entries[1]["has_range"]), "a key with no range marker gets no slider",
		"claimed a range")
	_expect(String(entries[1]["long"]).is_empty(),
		"a banner ';' comment is not treated as documentation", String(entries[1]["long"]))
	_expect(String(entries[2]["short"]) == "and a real comment after it",
		"a semicolon inside a quoted value is not a comment", String(entries[2]["short"]))
	_expect(String(entries[3]["short"]).is_empty(), "a key with no comment parses",
		String(entries[3]["short"]))

	# Every value the game reads must be visible in the panel.
	var known := {}
	for entry in Tuning.schema():
		known[String(entry["path"])] = true
	var unlisted: PackedStringArray = []
	for key in REQUIRED_TUNING_KEYS:
		if not known.has(key):
			unlisted.append(key)
	_expect(unlisted.is_empty(), "every required tuning key appears in the panel schema",
		", ".join(unlisted))


func _test_tuning_writer() -> void:
	var updated := TuningWriter.apply(SAMPLE_CFG, {
		"missile/base_speed": 175.5,
		"missile/plain": 9,
		"missile/bare": false,
	})

	_expect(updated.contains("base_speed = 175.5"), "writer replaces the value",
		"value not updated")
	_expect(updated.contains("; [20..400] m/s, the short label"),
		"writer keeps the inline comment and its range marker", "comment lost")
	_expect(updated.contains(";; First line of the long description."),
		"writer keeps the long description", "documentation lost")
	_expect(updated.contains("; banner comment, not documentation"),
		"writer keeps banner comments", "banner lost")
	_expect(updated.contains("plain = 9") and not updated.contains("plain = 9.0"),
		"an int stays an int", "int was written as a float")
	_expect(updated.contains("bare = false"), "a bool round-trips", "bool not written")
	_expect(updated.contains("quoted = \"a ; semicolon inside\""),
		"an untouched line is byte-identical", "untouched line was rewritten")

	# The result must still parse, with the right types.
	var config := ConfigFile.new()
	_expect(config.parse(updated) == OK, "the rewritten file still parses", "parse failed")
	_expect(typeof(config.get_value("missile", "base_speed")) == TYPE_FLOAT,
		"a float stays a float after a round-trip",
		type_string(typeof(config.get_value("missile", "base_speed"))))
	_expect(typeof(config.get_value("missile", "plain")) == TYPE_INT,
		"an int stays an int after a round-trip",
		type_string(typeof(config.get_value("missile", "plain"))))

	# 90.0 -> 90 would silently change the type on the next load.
	_expect(TuningWriter.format_float(90.0) == "90.0",
		"a whole float keeps its decimal point", TuningWriter.format_float(90.0))
	_expect(TuningWriter.format_value(Vector3(1.0, 2.5, -3.0)) == "Vector3(1.0, 2.5, -3.0)",
		"a Vector3 round-trips as a literal", TuningWriter.format_value(Vector3(1.0, 2.5, -3.0)))

	# Nothing dirty must mean nothing written.
	_expect(TuningWriter.apply(SAMPLE_CFG, {}) == SAMPLE_CFG,
		"no changes leaves the file untouched", "file was rewritten anyway")


func _test_debug_panel() -> void:
	_expect(DebugPanel != null, "the tuning panel autoload exists", "not registered")
	_expect(not DebugPanel.is_open(), "the tuning panel starts closed", "opened itself")

	DebugPanel.set_open(true)
	_expect(DebugPanel.is_open(), "the tuning panel opens", "stayed closed")
	var rows := DebugPanel.row_count()
	_expect(rows >= Tuning.schema().size(),
		"the panel builds a row for every documented value",
		"%d rows for %d entries" % [rows, Tuning.schema().size()])
	DebugPanel.set_open(false)
	_expect(not DebugPanel.is_open(), "the tuning panel closes", "stayed open")

	# Editing marks the file dirty without touching disk, and revert undoes it.
	var before := Tuning.num("missile/base_speed")
	Tuning.set_value("missile/base_speed", before + 11.0)
	_expect(Tuning.is_dirty("missile/base_speed"), "an edit is tracked as unsaved",
		"not marked dirty")
	_expect(is_equal_approx(Tuning.num("missile/base_speed"), before + 11.0),
		"an edit takes effect immediately", "%f" % Tuning.num("missile/base_speed"))
	Tuning.revert()
	_expect(is_equal_approx(Tuning.num("missile/base_speed"), before),
		"revert restores the value from disk", "%f" % Tuning.num("missile/base_speed"))
	_expect(Tuning.dirty_paths().is_empty(), "revert clears the unsaved list",
		", ".join(Tuning.dirty_paths()))


func _test_arena_builds() -> void:
	var packed := load("res://scenes/arena.tscn") as PackedScene
	_expect(packed != null, "arena.tscn loads", "scene failed to load")
	if packed == null:
		return
	var arena := packed.instantiate()
	add_child(arena)
	await get_tree().process_frame
	await get_tree().process_frame

	for path in ["WorldEnvironment", "KeyLight", "FillLight", "ArenaRoot",
			"ArenaRoot/Lattice", "ArenaRoot/Rocks", "ArenaRoot/Target",
			"ArenaRoot/Mothership", "ShipCamera", "MissileCamera",
			"ViewController", "DebugHud"]:
		_expect(arena.has_node(path), "arena builds node: " + path, "not constructed")

	var views := arena.call("views") as ViewController
	_expect(views != null and views.view_name() == "SHIP",
		"arena starts in ship view", "view=%s" % (views.view_name() if views else "null"))

	var ship := arena.call("ship") as Mothership
	_expect(ship != null and ship.target != null,
		"autopilot has a commanded target", "target not assigned")

	var missile := arena.call("fire") as Missile
	_expect(missile != null, "fire() launches a missile", "returned null")
	_expect(int(arena.call("shots_fired")) == 1, "fire() counts the shot",
		"shots=%d" % int(arena.call("shots_fired")))
	if views != null:
		_expect(views.view_name() == "MISSILE", "firing enters missile view",
			"view=%s" % views.view_name())
	_expect(arena.call("fire") == null,
		"a second fire() is refused while riding", "launched two piloted missiles")

	_expect(arena.has_node("OverlayLayer/FlightOverlay"),
		"arena builds the flight overlay", "reticle and target indicator missing")
	var overlay := arena.get_node_or_null("OverlayLayer/FlightOverlay") as FlightOverlay
	# A Control under a CanvasLayer does not get sized by anchors. At zero size
	# the edge-clamping maths degenerates and the target indicator vanishes.
	_expect(overlay != null and overlay.size.x > 1.0 and overlay.size.y > 1.0,
		"flight overlay is sized to the viewport",
		"size=%s — indicator would clamp into a zero rect" % (overlay.size if overlay else "null"))

	_expect(bool(arena.call("detonate_current")),
		"detonate_current() ends the ride", "nothing to detonate")
	_expect(not bool(arena.call("detonate_current")),
		"detonate_current() is a no-op with no missile", "detonated twice")

	_expect(Tuning.missing_keys().is_empty(), "no tuning key was requested and missing",
		", ".join(Tuning.missing_keys()))
	arena.queue_free()


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
