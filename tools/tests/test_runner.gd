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
	"missile/flash_start_radius", "missile/damage",
	"missile/splash_radius", "missile/splash_damage_fraction",
	"missile/splash_max_fraction", "missile/splash_falloff_power",
	"missile/flash_seconds", "missile/flash_color", "missile/flash_color_dud",
	"missile/boost_multiplier", "missile/boost_seconds", "missile/boost_regen_per_sec",
	"missile/dodge_distance", "missile/dodge_seconds", "missile/dodge_cooldown_seconds",
	"missile/brake_speed_multiplier", "missile/brake_turn_multiplier",
	"ship/arc_speed_fraction", "ship/standoff_distance", "ship/muzzle_offset", "ship/hull_scale",
	"ship/range_hold_seconds", "ship/range_hold_max_speed",
	"ship/hull_tint", "ship/metallic", "ship/roughness",
	"ship/start_role", "ship/arc_depth",
	"ship/manual_accel_seconds", "ship/manual_brake_seconds",
	"ship/manual_max_speed", "ship/manual_speed_ceiling_fraction", "ship/hull_class",
	"ship/manual_turn_rate_deg_per_sec", "ship/manual_reticle_max_angle_deg",
	"ship/autopilot_turn_rate_deg_per_sec",
	"ship/manual_strafe_speed", "ship/missile_cooldown_seconds",
	"ship/invulnerable", "ship/hp", "ship/hit_radius_scale",
	"turret/mount_offset", "turret/muzzle_offset", "turret/muzzle_mount_offset",
	"turret/convergence_distance", "turret/traverse_deg_per_sec",
	"turret/elevation_limit_deg",
	"turret/loadout_1_primary", "turret/loadout_1_secondary",
	"turret/loadout_2_primary", "turret/loadout_2_secondary",
	"turret/projectile_speed_floor_fraction",
	"turret/autocannon_rounds_per_second", "turret/autocannon_damage",
	"turret/autocannon_speed", "turret/autocannon_range",
	"turret/autocannon_round_length", "turret/autocannon_round_width",
	"turret/autocannon_round_color", "turret/autocannon_blast_radius",
	"turret/unguided_magazine", "turret/unguided_reload_seconds",
	"turret/unguided_damage", "turret/unguided_speed", "turret/unguided_range",
	"turret/unguided_round_length", "turret/unguided_round_width",
	"turret/unguided_round_color",
	"turret/unguided_blast_radius", "turret/unguided_blast_damage",
	"turret/unguided_blast_max_fraction", "turret/unguided_blast_falloff_power",
	"turret/unguided_flash_seconds", "turret/unguided_flash_color",
	"turret/blocker_cooldown_seconds", "turret/blocker_flare_count",
	"flare/radius", "flare/launch_speed", "flare/spread_speed",
	"flare/velocity_inheritance", "flare/seconds",
	"flare/player_color", "flare/enemy_color",
	"flare/kill_flash_radius", "flare/kill_flash_seconds", "flare/kill_flash_color",
	"turret/pulse_range", "turret/pulse_damage_per_second",
	"turret/pulse_heat_per_second", "turret/pulse_cool_per_second",
	"turret/pulse_overheat_lockout_seconds",
	"turret/pulse_beam_width", "turret/pulse_beam_color", "turret/pulse_beam_fade_seconds",
	"turret/impact_flash_start_radius", "turret/impact_flash_end_radius",
	"turret/impact_flash_seconds", "turret/impact_flash_color",
	"turret/impact_flash_color_dud",
	"enemy/radius", "enemy/drift_speed_fraction", "enemy/hull_class",
	"enemy/spin_deg_per_sec",
	"enemy/patrol_half_extent", "enemy/hull_color", "enemy/hull_emission",
	"enemy/hull_length", "enemy/hull_width", "enemy/hull_height", "enemy/nose_length",
	"enemy/wing_span", "enemy/wing_chord", "enemy/wing_thickness", "enemy/fin_height",
	"enemy/blocker_chance", "enemy/blocker_trigger_range",
	"enemy/blocker_cooldown_seconds", "enemy/blocker_flare_count",
	"enemy/interrupt_interval_seconds", "enemy/interrupt_warning_lead_seconds",
	"enemy/missile_aim_error", "enemy/missile_speed",
	"enemy/missile_turn_rate_deg_per_sec", "enemy/missile_fuse_seconds",
	"enemy/missile_radius", "enemy/missile_hit_points", "enemy/missile_damage",
	"enemy/missile_color",
	"enemy/component_count", "enemy/component_hit_points",
	"enemy/component_radius", "enemy/component_length", "enemy/component_mount_radius",
	"enemy/component_hit_radius", "enemy/component_damaged_darken",
	"enemy/component_respawn_seconds", "enemy/component_color", "enemy/component_emission",
	"camera/fov_base", "camera/boom_hull_scale_influence", "camera/return_delay_sec", "camera/missile_view_mode",
	"camera/ship_follow_distance", "camera/ship_follow_height", "camera/ship_follow_lag",
	"camera/ship_look_ahead",
	"camera/missile_follow_distance", "camera/missile_follow_height",
	"camera/missile_follow_lag", "camera/missile_look_ahead",
	"camera/turret_follow_distance", "camera/turret_follow_height",
	"camera/turret_follow_lag", "camera/turret_look_ahead",
	"camera/turret_boom_pitch_share", "camera/turret_fov",
	"camera/free_move_speed", "camera/free_boost_multiplier", "camera/free_look_sensitivity",
	"camera/free_move_smoothing", "camera/start_position", "camera/start_look_at",
	"controls/mouse_sensitivity", "controls/stick_reticle_speed_deg_per_sec",
	"controls/deadzone", "controls/turret_mouse_sensitivity",
	"hud/font_size", "hud/line_width",
	"hud/target_color", "hud/target_bracket_size", "hud/arrow_size", "hud/edge_margin",
	"hud/reticle_color", "hud/reticle_size", "hud/reticle_distance",
	"hud/reticle_lag_line_alpha",
	"hud/turret_reticle_color", "hud/turret_reticle_size",
	"hud/turret_heat_bar_width", "hud/turret_heat_bar_height", "hud/turret_heat_bar_offset",
	"hud/turret_heat_color", "hud/turret_overheat_color",
	"hud/tube_bar_width", "hud/tube_bar_height", "hud/tube_bar_bottom_margin",
	"hud/tube_ready_color", "hud/tube_reloading_color",
	"hud/alert_color", "hud/alert_font_size", "hud/alert_top_margin",
	"hud/alert_pulse_hz", "hud/alert_bracket_size", "hud/alert_arrow_size",
	"hud/alert_seconds",
	"hud/hit_flash_seconds", "hud/hit_flash_band", "hud/hit_flash_color",
	"arena/marker_spacing", "arena/marker_count_per_axis", "arena/marker_size",
	"arena/marker_color", "arena/background_color", "arena/ambient_energy",
	"arena/glow_enabled", "arena/glow_intensity",
	"arena/key_light_energy", "arena/key_light_angles_deg",
	"arena/fill_light_energy", "arena/fill_light_angles_deg",
	"arena/rock_count", "arena/rock_inner_radius", "arena/rock_outer_radius",
	"arena/rock_slab_half_height", "arena/rock_min_size", "arena/rock_max_size",
	"arena/rock_color", "arena/rock_seed",
	"arena/rock_collision", "arena/rock_hit_radius_scale",
	"arena/rock_lobe_min", "arena/rock_lobe_max",
	"arena/rock_lobe_size_min", "arena/rock_lobe_size_max",
	"arena/rock_lobe_offset_min", "arena/rock_lobe_offset_max",
	"arena/rock_elongation",
	"probe/scale", "probe/spin_deg_per_sec", "probe/bob_amplitude", "probe/bob_period_sec",
	"probe/hull_tint", "probe/metallic", "probe/roughness",
	# The travel layer (docs/EXPLORATION_POC_IMPLEMENTATION.md). The speed ladder,
	# the lane, the portal, fuel, traffic and the test map.
	"exploration/taxi_max_speed", "exploration/fighter_max_speed",
	"exploration/capital_max_speed", "exploration/cruise_speed",
	"exploration/taxi_speed_ceiling_fraction", "exploration/fighter_speed_ceiling_fraction",
	"exploration/capital_speed_ceiling_fraction", "exploration/start_hull_class",
	"exploration/fighter_turn_rate_deg_per_sec", "exploration/fighter_accel_seconds",
	"exploration/fighter_brake_seconds", "exploration/fighter_strafe_speed",
	"exploration/fighter_reticle_max_angle_deg", "exploration/fighter_hull_scale",
	"exploration/capital_turn_rate_deg_per_sec", "exploration/capital_accel_seconds",
	"exploration/capital_brake_seconds", "exploration/capital_strafe_speed",
	"exploration/capital_reticle_max_angle_deg", "exploration/capital_hull_scale",
	"exploration/taxi_has_cruise_drive", "exploration/fighter_has_cruise_drive",
	"exploration/capital_has_cruise_drive",
	"exploration/cruise_turn_clamp_deg", "exploration/cruise_turn_rate_deg_per_sec",
	"exploration/lane_width", "exploration/lane_height", "exploration/lane_edge_softness",
	"exploration/lane_edge_speed_penalty", "exploration/lane_edge_push_accel",
	"exploration/deck_separation",
	"exploration/portal_width", "exploration/portal_height",
	"exploration/portal_flare_length", "exploration/portal_entry_seconds",
	"exploration/portal_sheen_color", "exploration/portal_denied_color",
	"exploration/portal_emission", "exploration/portal_sheen_scroll_hz",
	"exploration/cruise_fuel_capacity", "exploration/cruise_fuel_per_km",
	"exploration/cruise_fuel_start_fraction",
	"exploration/road_traffic_per_km", "exploration/road_traffic_speed_spread",
	"exploration/open_traffic_per_100km3", "exploration/traffic_despawn_distance",
	"exploration/system_diameter", "exploration/system_ceiling_height",
	"exploration/system_floor_depth",
	"exploration/bounds_warning_band", "exploration/bounds_grace_seconds",
	"exploration/bounds_damage_ramp_seconds", "exploration/bounds_damage_per_second",
	"exploration/bounds_stop_distance", "exploration/bounds_face_color",
	"exploration/bounds_color", "exploration/bounds_face_alpha",
	"exploration/bounds_alarm_alpha", "exploration/bounds_face_thickness",
	"exploration/bounds_rim_alpha_scale",
	"exploration/aperture_mouth_diameter", "exploration/aperture_funnel_length",
	"exploration/aperture_bearing_deg",
	"exploration/lane_corner_roundness",
	"exploration/lane_hull_clearance_cap", "exploration/ramp_curve_tightness",
	"exploration/road_curve_deg", "exploration/road_curve_period",
	"exploration/road_rise_deg", "exploration/road_rise_period",
	"exploration/bounds_grid_spacing", "exploration/bounds_grid_alpha_scale",
	"exploration/bounds_grid_alpha", "exploration/road_height",
	"exploration/lane_active_color", "exploration/lane_active_alpha",
	"exploration/lane_handover_margin", "exploration/lane_ramp_shade",
	"exploration/structure_module_length", "exploration/structure_rib_thickness",
	"exploration/structure_glass_alpha", "exploration/structure_metal_color",
	"exploration/structure_station_spacing",
	"exploration/structure_station_length",
	"exploration/structure_glass_color", "exploration/ramp_ring_diameter",
	"exploration/ramp_ring_depth", "exploration/ramp_ring_color",
	"exploration/crossing_bearing_deg", "exploration/crossing_road_height",
	"exploration/cross_inbound_leg_length",
	"exploration/cross_outbound_leg_length",
	"exploration/interchange_run_length",
	"exploration/interchange_curve_tightness",
	"exploration/interchange_side_offset",
	"exploration/berth_speed_fraction", "exploration/berth_offer_height",
	"exploration/berth_ride_height", "exploration/berth_pull_rate",
	"exploration/exit_sign_lead_metres", "exploration/exit_sign_metres",
	"exploration/exit_sign_inset", "exploration/exit_sign_rise",
	"exploration/exit_sign_color", "exploration/exit_sign_aimed_color",
	"exploration/exit_sign_panel_alpha",
	"exploration/exit_sign_selected_color", "exploration/exit_sign_aimed_scale",
	"exploration/exit_sign_selected_scale",
	"exploration/exit_sign_selected_panel_alpha",
	"exploration/ramp_gate_alpha_scale",
	"exploration/exit_sign_pick_deg", "exploration/berth_look_cone_deg",
	"camera/near_plane", "camera/far_plane",
	"exploration/deep_seed",
	"exploration/starfield_count", "exploration/starfield_distance",
	"exploration/starfield_size", "exploration/starfield_color",
	"exploration/deep_bodies_count", "exploration/deep_bodies_near",
	"exploration/deep_bodies_far", "exploration/deep_bodies_min_radius",
	"exploration/deep_bodies_max_radius", "exploration/deep_bodies_color",
	"exploration/deep_bodies_tint_spread",
	"exploration/deep_dust_count", "exploration/deep_dust_near",
	"exploration/deep_dust_far", "exploration/deep_dust_min_size",
	"exploration/deep_dust_max_size", "exploration/deep_dust_color",
	"exploration/lane_color", "exploration/lane_line_alpha",
	"exploration/portal_label_metres", "exploration/portal_site_offset",
	"exploration/ramp_run_length",
	"exploration/ramp_exit_side_offset", "exploration/ramp_exit_depth",
	"exploration/ramp_entry_side_offset", "exploration/ramp_entry_depth",
	"exploration/cruise_spool_seconds", "exploration/cruise_spool_down_seconds",
	"exploration/depart_speed_fraction",
	"exploration/planet_radius", "exploration/planet_center_depth",
	"exploration/planet_color", "exploration/planet_emission",
	"exploration/marker_spacing", "exploration/marker_size", "exploration/marker_color",
	"exploration/approach_envelope_radius", "exploration/approach_seconds",
	"exploration/approach_relock_seconds", "exploration/approach_abort_mouse_speed",
	"exploration/approach_color", "exploration/approach_ring_thickness",
	"exploration/approach_alpha_far",
	"exploration/approach_alpha_near",
	"exploration/dock_title_font_size", "exploration/dock_title_color",
	"exploration/corridor_diameter", "exploration/local_leg_length",
	"exploration/trunk_leg_length", "exploration/debug_teleport_enabled",
]

const REQUIRED_ACTIONS: Array[String] = [
	"fire_missile", "detonate", "boost", "brake", "dodge_left", "dodge_right",
	"aim_left", "aim_right", "aim_up", "aim_down",
	"throttle_up", "throttle_down", "strafe_left", "strafe_right", "dock",
	"role_pilot", "role_gunner",
	"fire_primary", "fire_secondary", "loadout_1", "loadout_2",
	"cam_forward", "cam_back", "cam_left", "cam_right", "cam_up", "cam_down",
	"cam_boost", "cam_look",
	"debug_toggle_hud", "debug_toggle_panel", "debug_reload_tuning",
	"debug_reverse_arc", "debug_cycle_hull", "quit",
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
	_test_dodge_and_brake()
	_test_manual_flight()
	_test_hull_classes()
	_test_lane_geometry()
	_test_deep_field()
	_test_envelope_meter()
	_test_disc_bounds()
	_test_the_road()
	_test_hull_roster()
	_test_approach_envelope()
	_test_target_components()
	_test_turret_station()
	_test_turret_weapons()
	_test_splash_and_unguided()
	_test_flares_and_blockers()
	_test_missile_cooldown()
	_test_interrupt()
	_test_overlay_projection_guard()
	_test_tuning_schema()
	_test_tuning_writer()
	_test_debug_panel()
	_test_autopilot_holds_standoff()
	await _test_sandbox_builds()
	await _test_arena_builds()
	await _test_exploration_builds()

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
	for model in ["probe", "carrier"]:
		var mesh := load("res://assets/models/%s.obj" % model) as Mesh
		_expect(mesh != null, "%s.obj imports as a Mesh" % model,
			"import failed — run `make import`")
		if mesh == null:
			continue
		_expect(mesh.get_surface_count() > 0, "%s.obj has surfaces" % model, "0 surfaces")
		var aabb := mesh.get_aabb()
		_expect(aabb.size.length() > 0.1, "%s.obj has non-degenerate bounds" % model, str(aabb))

	# The carrier is authored at 1 unit = 1 metre (ADR 0044), so the mesh and every
	# distance in tuning.cfg are in the same units. A generator change that silently
	# rescaled it would put the chase camera inside the hull.
	var carrier := load("res://assets/models/carrier.obj") as Mesh
	if carrier != null:
		var length := carrier.get_aabb().size.z
		_expect(length > 40.0 and length < 60.0,
			"the carrier hull is a capital-scale 50 m, not a fighter",
			"%.1f m stem to stern" % length)
		_expect(carrier.get_aabb().size.x > 30.0,
			"…and wider than it is tall, across the crescent",
			"%.1f m span" % carrier.get_aabb().size.x)

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

	# Ellipsoids, the primitive a rock is built from (ADR 0041). A long thin one
	# must be hittable down its length and missable across its waist at the same
	# distance — which is the whole reason a single radius was not enough.
	var stretched := Vector3(3.0, 12.0, 3.0)
	_expect(FlightGeometry.segment_hits_ellipsoid(
			Vector3(0, 20, -30), Vector3(0, 20, 30), Vector3(0, 20, 0),
			Basis.IDENTITY, stretched),
		"a segment through an ellipsoid's centre hits it", "missed a direct pass")
	_expect(FlightGeometry.segment_hits_ellipsoid(
			Vector3(0, 9, -30), Vector3(0, 9, 30), Vector3.ZERO, Basis.IDENTITY, stretched),
		"…and one along its long axis, inside it", "missed the tall part")
	_expect(not FlightGeometry.segment_hits_ellipsoid(
			Vector3(9, 0, -30), Vector3(9, 0, 30), Vector3.ZERO, Basis.IDENTITY, stretched),
		"…and misses at the same distance across its short axis",
		"an ellipsoid that behaves like a sphere is not an ellipsoid")
	# Rotating the ellipsoid by a quarter turn swaps which of those two is true.
	var turned := Basis.from_euler(Vector3(0.0, 0.0, PI * 0.5))
	_expect(FlightGeometry.segment_hits_ellipsoid(
			Vector3(9, 0, -30), Vector3(9, 0, 30), Vector3.ZERO, turned, stretched),
		"the ellipsoid's orientation is respected", "rotation was ignored")
	_expect(not FlightGeometry.segment_hits_ellipsoid(
			Vector3(0, 0, 40), Vector3(0, 0, 80), Vector3.ZERO, Basis.IDENTITY, stretched),
		"a segment entirely past an ellipsoid misses it", "hit something behind it")

	# Entry parameters. A target made of several hittable parts needs to know which
	# part the segment reaches *first*, and that is not a question a boolean answers
	# (ADR 0043).
	var entry := FlightGeometry.segment_sphere_entry(
		Vector3(0, 0, -100), Vector3(0, 0, 100), Vector3.ZERO, 10.0)
	_expect(is_equal_approx(entry, 0.45),
		"segment_sphere_entry reports where the segment enters, not just whether",
		"t=%f, expected 0.45" % entry)
	_expect(is_equal_approx(FlightGeometry.segment_sphere_entry(
			Vector3.ZERO, Vector3(0, 0, 100), Vector3.ZERO, 10.0), 0.0),
		"…and reports 0 for a segment that starts inside", "did not clamp to zero")
	_expect(FlightGeometry.segment_sphere_entry(
			Vector3(0, 40, -100), Vector3(0, 40, 100), Vector3.ZERO, 10.0) < 0.0,
		"…and -1 for a clean miss", "false positive")

	# The ordering property the target ship depends on: a nearer sphere must return
	# a smaller t than a further one along the same segment.
	var near_t := FlightGeometry.segment_sphere_entry(
		Vector3(0, 0, -100), Vector3(0, 0, 100), Vector3(0, 0, -40), 5.0)
	var far_t := FlightGeometry.segment_sphere_entry(
		Vector3(0, 0, -100), Vector3(0, 0, 100), Vector3(0, 0, 20), 5.0)
	_expect(near_t >= 0.0 and far_t >= 0.0 and near_t < far_t,
		"the nearer of two spheres on one segment reports the smaller entry",
		"near=%f far=%f" % [near_t, far_t])

	var box_t := FlightGeometry.segment_box_entry(
		Vector3(0, 0, -100), Vector3(0, 0, 100), Vector3.ZERO,
		Basis.IDENTITY, Vector3(4.0, 4.0, 10.0))
	_expect(is_equal_approx(box_t, 0.45),
		"segment_box_entry finds the near face of an oriented box", "t=%f" % box_t)
	_expect(FlightGeometry.segment_box_entry(
			Vector3(20, 0, -100), Vector3(20, 0, 100), Vector3.ZERO,
			Basis.IDENTITY, Vector3(4.0, 4.0, 10.0)) < 0.0,
		"…and misses a box it passes beside", "false positive")
	# A quarter turn about Y swaps the box's long axis, so a segment that missed
	# down one side now runs into it.
	_expect(FlightGeometry.segment_box_entry(
			Vector3(20, 0, -100), Vector3(20, 0, 100), Vector3.ZERO,
			Basis.from_euler(Vector3(0.0, PI * 0.5, 0.0)), Vector3(4.0, 4.0, 30.0)) >= 0.0,
		"…and respects the box's orientation", "rotation was ignored")
	_expect(FlightGeometry.segment_box_entry(
			Vector3(0, 0, 40), Vector3(0, 0, 80), Vector3.ZERO,
			Basis.IDENTITY, Vector3(4.0, 4.0, 10.0)) < 0.0,
		"…and does not hit a box entirely behind the segment", "hit something behind it")

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
	# Explicitly, rather than relying on `ship/start_role`: this test is about the
	# autopilot, and it should not start passing or failing because the tuned
	# starting job changed (ADR 0056).
	ship.set_autopilot(true)
	ship.position = Vector3(0.0, 0.0, 1.0)   # a bearing to snap along, as the arena does
	ship.snap_to_standoff()

	var standoff := Tuning.num("ship/standoff_distance")
	_expect(is_equal_approx(ship.range_to_target(), standoff),
		"snap_to_standoff lands exactly on the tuned distance",
		"%.1f m vs %.1f m" % [ship.range_to_target(), standoff])

	# The station is under the target, so the turret has a line over its own hull
	# (ADR 0056). Standoff still means SLANT range, so the assertion above is
	# unchanged by it — the depth only decides where on that sphere the ship sits.
	var depth := Tuning.num("ship/arc_depth")
	_expect(absf(ship.depth_below_target() - depth) < 0.01,
		"…on the arc plane below the target, not level with it",
		"%.1f m below, tuned %.1f" % [ship.depth_below_target(), depth])

	var step := 1.0 / 60.0
	var drift := TargetShip.tuned_drift_speed()
	var worst := 0.0
	var worst_depth := 0.0
	for i in 1800:   # 30 simulated seconds
		target.position += Vector3(1.0, 0.0, 0.3).normalized() * drift * step
		ship._process(step)
		if i > 240:   # let it settle first
			worst = maxf(worst, absf(ship.range_to_target() - standoff))
			worst_depth = maxf(worst_depth, absf(ship.depth_below_target() - depth))

	# Steady-state error is bounded by drift * range_hold_seconds; allow headroom.
	var allowed := drift * Tuning.num("ship/range_hold_seconds") * 2.5
	_expect(worst <= allowed,
		"autopilot holds standoff against a drifting target over 30 s",
		"drifted %.1f m off, budget is %.1f m" % [worst, allowed])
	_expect(worst_depth <= allowed,
		"…and holds the arc plane under it just as well",
		"drifted %.1f m off the plane, budget is %.1f m" % [worst_depth, allowed])

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
## Dodge and brake are the two verbs that read input every frame, so unlike the
## rest of the flight path they cannot be tested by stepping a dumb missile. Godot
## honours `Input.action_press` headlessly, which is enough to drive them for real.
func _test_dodge_and_brake() -> void:
	var step := 1.0 / 60.0
	var distance := Tuning.num("missile/dodge_distance")
	var duration := Tuning.num("missile/dodge_seconds")

	var missile := Missile.new()
	missile.launch(Vector3.ZERO, Basis.IDENTITY, Vector3.ZERO, null, 0.0)
	missile.piloted = true

	_expect(missile.dodge_cooldown_remaining() <= 0.0,
		"a fresh missile can dodge immediately", "launched on cooldown")

	Input.action_press("dodge_right")
	missile._process(step)
	Input.action_release("dodge_right")
	_expect(missile.is_dodging(), "a press starts a dodge", "nothing started")

	for _i in int(ceil(duration / step)) + 2:
		missile._process(step)

	# The eased profile is integrated with a left Riemann sum at 60 Hz, so it lands
	# a few percent long. The contract is "about dodge_distance to the right", not
	# an exact integral — a tighter bound here would be testing the step size.
	var moved := missile.position.x
	_expect(absf(moved - distance) < distance * 0.15,
		"one press displaces the missile by about dodge_distance",
		"moved %.1f m, tuned %.1f m" % [moved, distance])
	_expect(not missile.is_dodging(), "the dodge ends on its own", "still dodging")
	_expect(missile.dodge_cooldown_remaining() > 0.0,
		"a dodge leaves a cooldown behind", "dodge was free")

	# Mashing must not stack: the cooldown is the whole reason this is a decision.
	var before := missile.position.x
	Input.action_press("dodge_left")
	missile._process(step)
	Input.action_release("dodge_left")
	for _i in 4:
		missile._process(step)
	_expect(is_equal_approx(missile.position.x, before),
		"a dodge on cooldown is refused", "moved %.2f m anyway" % (missile.position.x - before))

	# --- brake -----------------------------------------------------------------
	Input.action_press("brake")
	missile._process(step)
	_expect(missile.is_braking(), "brake engages while held", "not braking")
	_expect(is_equal_approx(missile.speed(),
			Tuning.num("missile/base_speed") * Tuning.num("missile/brake_speed_multiplier")),
		"brake scales speed by brake_speed_multiplier", "%.1f m/s" % missile.speed())

	Input.action_press("boost")
	missile._process(step)
	_expect(not missile.is_boosting(), "brake overrides boost while both are held",
		"boosted through the brake")
	Input.action_release("brake")
	missile._process(step)
	_expect(missile.is_boosting(), "boost resumes when the brake releases", "stayed off")
	Input.action_release("boost")
	missile._process(step)
	_expect(not missile.is_braking() and not missile.is_boosting(),
		"releasing both returns the missile to base speed", "a modifier stuck on")
	missile.free()

	# Brake's actual point: it buys turn rate. Two identical missiles given the same
	# steering input, one braking, must not turn the same amount.
	var free_turn := _turn_over_half_second(false)
	var braked_turn := _turn_over_half_second(true)
	_expect(braked_turn > free_turn * 1.2,
		"brake widens the turn rate",
		"braked %.1f deg vs free %.1f deg" % [braked_turn, free_turn])


## Degrees the nose swings in half a second of full left stick, with or without the
## brake held. Separate loops because both missiles would otherwise read the same
## global Input state in the same frame.
func _turn_over_half_second(braking: bool) -> float:
	var missile := Missile.new()
	missile.launch(Vector3.ZERO, Basis.IDENTITY, Vector3.ZERO, null, 0.0)
	missile.piloted = true
	Input.action_press("aim_left")
	if braking:
		Input.action_press("brake")
	for _i in 30:
		missile._process(1.0 / 60.0)
	Input.action_release("aim_left")
	if braking:
		Input.action_release("brake")
	var turned := rad_to_deg((-missile.basis.z).angle_to(Vector3(0.0, 0.0, -1.0)))
	missile.free()
	return turned


## Manual flight (ADR 0040). Driven through real `Input` actions, which work
## headlessly, so this exercises the same path a hand on the keyboard does.
func _test_manual_flight() -> void:
	var target := Node3D.new()
	add_child(target)
	var ship := Mothership.new()
	add_child(ship)
	ship.set_process(false)   # stepped by hand below
	ship.target = target
	ship.position = Vector3(0.0, 0.0, 1.0)
	ship.snap_to_standoff()

	_expect(ship.autopilot == (Tuning.text("ship/start_role") == "gunner"),
		"the ship starts in the mode its tuned crew role implies",
		"start_role is %s but the ship is on %s" % [
			Tuning.text("ship/start_role"), ship.mode_name()])

	# The speed hierarchy is structural, not advisory (CLAUDE.md): whatever the
	# ship's own top speed says, it may not reach a missile's.
	var missile_speed := Tuning.num("missile/base_speed")
	_expect(ship.manual_max_speed() < missile_speed,
		"a manually flown ship cannot reach missile speed",
		"ship %.1f m/s vs missile %.1f m/s" % [ship.manual_max_speed(), missile_speed])

	# Raised on the CLASS key, which is what the ship actually reads now — raising
	# the shared `ship/manual_max_speed` fallback would prove nothing, because a
	# class with an entry of its own never consults it.
	Tuning.set_value("exploration/taxi_max_speed", missile_speed * 10.0)
	_expect(ship.manual_max_speed() < missile_speed,
		"…even when the ship's own tuning is raised past it",
		"clamp let %.1f m/s through" % ship.manual_max_speed())
	Tuning.revert()

	ship.set_autopilot(false)
	_expect(not ship.autopilot, "the ship hands over to manual", "stayed on autopilot")

	var step := 1.0 / 60.0
	# Throttle is held state, not a burst: it climbs while W is down and STAYS
	# where it was left. That is the whole difference from the missile's boost.
	Input.action_press("throttle_up")
	for _i in 30:
		ship._process(step)
	Input.action_release("throttle_up")
	var half_second := ship.throttle()
	_expect(half_second > 0.0, "throttle climbs while accelerate is held",
		"throttle stayed at %.2f" % half_second)

	for _i in 30:
		ship._process(step)
	_expect(is_equal_approx(ship.throttle(), half_second),
		"throttle holds its position when released — it is a lever, not a burst",
		"drifted from %.3f to %.3f" % [half_second, ship.throttle()])

	Input.action_press("throttle_down")
	for _i in 600:
		ship._process(step)
	Input.action_release("throttle_down")
	_expect(is_equal_approx(ship.throttle(), 0.0),
		"the brake runs the throttle all the way to zero", "%.3f left" % ship.throttle())

	# Full travel of the lever must take about the tuned number of seconds.
	Input.action_press("throttle_up")
	var frames := 0
	while ship.throttle() < 1.0 and frames < 6000:
		ship._process(step)
		frames += 1
	Input.action_release("throttle_up")
	var took := float(frames) * step
	var tuned := Tuning.num("ship/manual_accel_seconds")
	_expect(absf(took - tuned) < maxf(tuned * 0.1, 2.0 * step),
		"zero to full throttle takes ship/manual_accel_seconds",
		"took %.2f s, tuned %.2f s" % [took, tuned])

	var flat_out := ship.position
	ship._process(step)
	_expect(is_equal_approx(ship.position.distance_to(flat_out), ship.manual_max_speed() * step),
		"full throttle flies at the clamped top speed",
		"moved %.3f m in a frame" % ship.position.distance_to(flat_out))

	# Lateral thrusters are held on the ship, unlike the missile's one-press dodge.
	var before_strafe := ship.position
	Input.action_press("strafe_right")
	ship._process(step)
	Input.action_release("strafe_right")
	var sideways := (ship.position - before_strafe).dot(ship.basis.x)
	_expect(sideways > 0.0, "a held thruster moves the ship sideways",
		"moved %.4f m along its own right" % sideways)

	# Thrusting sideways at full throttle must not sum past the ceiling: the
	# hierarchy has to hold against two keys held together, not just against an
	# edit to one number.
	Input.action_press("throttle_up")
	Input.action_press("strafe_right")
	for _i in 10:
		ship._process(step)
	Input.action_release("throttle_up")
	Input.action_release("strafe_right")
	_expect(ship.speed() <= ship.manual_max_speed() + 0.001,
		"a thruster held at full throttle does not sum past the top speed",
		"%.2f m/s against a ceiling of %.2f" % [ship.speed(), ship.manual_max_speed()])

	# Riding a missile must not also fly the ship. Both read W.
	ship.piloted = false
	var coast_throttle := ship.throttle()
	var coast_from := ship.position
	Input.action_press("throttle_down")
	for _i in 60:
		ship._process(step)
	Input.action_release("throttle_down")
	_expect(is_equal_approx(ship.throttle(), coast_throttle),
		"an unpiloted ship ignores input — W and S do not fly two vehicles at once",
		"throttle moved to %.3f while riding a missile" % ship.throttle())
	_expect(ship.position.distance_to(coast_from) > 0.0,
		"…but it keeps coasting rather than stopping dead", "the ship froze")
	ship.piloted = true

	# Handing back must not yank the ship out of the player's hands. The autopilot
	# used to `look_at` its direction of travel, which snapped the nose through
	# whatever angle the player had left it at, on the first frame.
	var handover_nose := -ship.basis.z
	ship.set_autopilot(true)
	ship._process(step)
	var swing := rad_to_deg(handover_nose.angle_to(-ship.basis.z))
	var allowed := Tuning.num("ship/autopilot_turn_rate_deg_per_sec") * step + 0.001
	_expect(swing <= allowed,
		"handing back to the autopilot turns the nose, it does not snap it",
		"swung %.1f deg in one frame against a budget of %.3f" % [swing, allowed])

	# And the autopilot may not fly the ship faster than the player can.
	var ceiling := ship.manual_max_speed()
	var fastest := 0.0
	var standoff := Tuning.num("ship/standoff_distance")
	for _i in 1800:
		ship._process(step)
		fastest = maxf(fastest, ship.speed())
	_expect(fastest <= ceiling + 0.001,
		"the autopilot stays inside the ship's own top speed",
		"reached %.1f m/s against a ceiling of %.1f" % [fastest, ceiling])
	for _i in 600:
		ship._process(step)
	_expect(absf(ship.range_to_target() - standoff) < standoff * 0.25,
		"the autopilot recovers standoff after a manual excursion",
		"%.0f m held against %.0f m tuned" % [ship.range_to_target(), standoff])

	ship.queue_free()
	target.queue_free()


## Destructible components on the target (ADR 0042).
func _test_target_components() -> void:
	var enemy := TargetShip.new()
	add_child(enemy)
	enemy.set_process(false)

	var expected := Tuning.integer("enemy/component_count")
	_expect(enemy.component_count() == expected,
		"the target builds every tuned component",
		"built %d of %d" % [enemy.component_count(), expected])
	if enemy.component_count() == 0:
		enemy.queue_free()
		return
	_expect(enemy.components_alive() == expected,
		"components start intact", "%d alive" % enemy.components_alive())

	# THE invariant, and the one the first version got backwards. A component has to
	# stand PROUD of the hull along its own mounting direction. Inside it, the hull
	# is what a segment reaches first and the component is unaimable — which is
	# exactly what shipped: every component sat inside a 9 m hull sphere and none of
	# them was ever hit (ADR 0043).
	for i in enemy.component_count():
		var exposure := enemy.component_exposure(i)
		_expect(exposure > 0.0,
			"component %d stands proud of the hull, so a shot can reach it" % i,
			"buried %.2f m inside it — unaimable however the tests are ordered" % -exposure)

	var damaged := {"count": 0, "destroyed": 0}
	enemy.component_damaged.connect(func(_i: int, _p: Vector3, destroyed: bool) -> void:
		damaged["count"] += 1
		if destroyed:
			damaged["destroyed"] += 1)

	var centre := enemy.component_position(0)
	var radius := Tuning.num("enemy/component_hit_radius")
	# Fired straight down the component's own mounting direction, from outside the
	# ship: the shot a player lining one up would actually take.
	var approach := Vector3(centre.x, centre.y, 0.0).normalized()
	var from := centre + approach * enemy.bound_radius() * 3.0
	var through := centre - approach * radius * 0.5

	var aimed := enemy.hit_test(from, through)
	_expect(bool(aimed["hit"]), "a shot aimed at a component hits the ship at all",
		"passed clean through")
	_expect(int(aimed["component"]) == 0,
		"…and is credited to the component, not the hull it is bolted to",
		"credited to %d — the hull is resolving first" % int(aimed["component"]))

	# The hull is still hittable where there is no component: down the spine, from
	# dead astern.
	var astern := enemy.position + Vector3(0.0, 0.0, Tuning.num("enemy/hull_length"))
	var hull_shot := enemy.hit_test(astern, enemy.position)
	_expect(bool(hull_shot["hit"]) and int(hull_shot["component"]) == -1,
		"a shot down the spine still hits the hull",
		"hit=%s component=%d" % [hull_shot["hit"], int(hull_shot["component"])])

	var clear_of_it := centre + approach * enemy.bound_radius() * 40.0
	_expect(not bool(enemy.hit_test(clear_of_it,
			clear_of_it + approach).get("hit")),
		"a segment nowhere near the ship reports no hit", "false positive")

	# The broad-phase sphere is derived, so it has to actually contain the nose —
	# a bound a metre short would make the tip silently unhittable.
	var nose_tip := Vector3(0.0, 0.0,
		-(Tuning.num("enemy/hull_length") * 0.5 + Tuning.num("enemy/nose_length")))
	_expect(enemy.bound_radius() >= nose_tip.length(),
		"the derived bound contains the nose tip",
		"bound %.1f m against a tip at %.1f m" % [enemy.bound_radius(), nose_tip.length()])

	# The damage pool (ADR 0049). Half the pool must not destroy; the second half
	# must — which is ADR 0042's two-missile-hit behaviour, now expressed in the
	# currency four weapons can share.
	var pool := enemy.component_hit_points()
	_expect(not enemy.damage_component(0, pool * 0.5),
		"half a component's pool damages it without destroying it", "destroyed early")
	_expect(enemy.is_component_alive(0), "…and it is still alive", "already gone")
	_expect(is_equal_approx(enemy.component_health_fraction(0), 0.5),
		"…and reads as half health",
		"%.2f left" % enemy.component_health_fraction(0))
	_expect(enemy.damage_component(0, pool * 0.5), "the rest of the pool destroys it",
		"survived a full pool of damage")
	_expect(not enemy.is_component_alive(0), "…and it reads as destroyed", "still alive")
	_expect(enemy.components_alive() == expected - 1,
		"the alive count drops", "%d alive" % enemy.components_alive())
	_expect(int(damaged["count"]) == 2 and int(damaged["destroyed"]) == 1,
		"one signal per damaging hit, and exactly one of them destroying",
		"%d signals, %d destroying" % [damaged["count"], damaged["destroyed"]])
	_expect(not enemy.damage_component(1, 0.0),
		"zero damage is not a hit", "counted as one")
	_expect(is_equal_approx(enemy.component_health_fraction(1), 1.0),
		"…and left the component untouched",
		"%.2f left" % enemy.component_health_fraction(1))

	# A destroyed component is not a target any more. The shot still lands — on the
	# hull behind where it used to be.
	var after := enemy.hit_test(from, through)
	_expect(int(after["component"]) != 0,
		"a destroyed component stops catching shots", "still credited with hits")
	_expect(not enemy.damage_component(0, pool),
		"…and cannot be damaged again", "took another hit")

	# It comes back, so a practice run does not run out of things to shoot.
	var window := Tuning.num("enemy/component_respawn_seconds")
	if window > 0.0:
		for _i in int(ceil(window * 60.0)) + 4:
			enemy._tick_respawns(1.0 / 60.0)
		_expect(enemy.is_component_alive(0),
			"a destroyed component returns after component_respawn_seconds",
			"still gone after %.1f s" % window)
		_expect(is_equal_approx(enemy.component_health_fraction(0), 1.0),
			"…undamaged", "came back at %.2f health" % enemy.component_health_fraction(0))

	enemy.queue_free()


## Regression: `unproject_position` asserts for a point sitting on the camera's own
## origin, which is true of the target on the first frame of every run — nodes are
## built at their parent's origin and placed afterwards. The engine prints the
## assert and carries on, so nothing fails; it just shouts once per launch.
## The gun station (POC step 6, stage 1). Driven through real `Input` actions and
## real mouse deltas, so this exercises the same path a hand on the desk does.
func _test_turret_station() -> void:
	var ship := Mothership.new()
	ship.set_process(false)
	add_child(ship)
	var turret := Turret.new()
	turret.ship = ship
	turret.set_process(false)   # stepped by hand below
	add_child(turret)

	var step := 1.0 / 60.0
	_expect(absf(turret.azimuth_degrees()) < 0.001 and absf(turret.elevation_degrees()) < 0.001,
		"the station starts pointed down the hull's nose",
		"bearing %.2f, elevation %.2f" % [turret.azimuth_degrees(), turret.elevation_degrees()])

	# The whole point of the station: the hull turns under it and the aim does not
	# move. A nose gun would have swung 90 degrees here.
	ship.basis = Basis(Vector3.UP, deg_to_rad(90.0))
	ship.position = Vector3(10.0, 0.0, -4.0)
	turret._process(step)
	_expect(absf(turret.azimuth_degrees()) < 0.001,
		"the hull turning under the station does not drag the aim with it",
		"bearing moved to %.2f deg" % turret.azimuth_degrees())

	# The mount, unlike the aim, does ride the hull.
	var mount := Tuning.vec3("turret/mount_offset")
	_expect(turret.position.is_equal_approx(ship.position + ship.basis * mount),
		"the mount point rides the hull, in the ship's own axes",
		"station at %s, hull mount at %s" % [turret.position, ship.position + ship.basis * mount])

	# An unmanned station takes no input at all — neither device.
	var held := turret.azimuth_degrees()
	turret.add_mouse_aim(Vector2(500.0, 0.0))
	Input.action_press("aim_right")
	turret._process(step)
	Input.action_release("aim_right")
	_expect(absf(turret.azimuth_degrees() - held) < 0.001,
		"an unmanned station holds its bearing and ignores input",
		"drifted to %.2f deg" % turret.azimuth_degrees())

	ship.basis = Basis.IDENTITY
	turret.active = true
	turret.set_aim_direction(Vector3.FORWARD)

	# 1:1 and instant. There is no reticle here and no lag to measure — a hitscan
	# weapon behind a lagging aim is a control that lies (ADR 0035 does not apply).
	var sensitivity := Tuning.num("controls/turret_mouse_sensitivity")
	turret.add_mouse_aim(Vector2(100.0, 0.0))
	turret._process(step)
	_expect(absf(turret.azimuth_degrees() - 100.0 * sensitivity) < 0.001,
		"the mouse aims the gun 1:1, in one frame",
		"100 px gave %.3f deg, tuned %.3f" % [turret.azimuth_degrees(), 100.0 * sensitivity])
	_expect(turret.aim_local().x > 0.0, "mouse right aims right",
		"aim went to %s" % turret.aim_local())

	turret.set_aim_direction(Vector3.FORWARD)
	turret.add_mouse_aim(Vector2(0.0, 100.0))
	turret._process(step)
	_expect(turret.aim_local().y < 0.0, "mouse down aims down",
		"aim went to %s" % turret.aim_local())

	# Elevation is bounded; bearing is not. Every ship shares one plane (ADR 0045),
	# so a gun that can point at the zenith is aiming at nothing.
	var limit := Tuning.num("turret/elevation_limit_deg")
	turret.add_mouse_aim(Vector2(0.0, -100000.0))
	turret._process(step)
	_expect(absf(turret.elevation_degrees() - limit) < 0.001,
		"elevation clamps at turret/elevation_limit_deg",
		"reached %.2f deg against a limit of %.2f" % [turret.elevation_degrees(), limit])
	turret.add_mouse_aim(Vector2(0.0, 100000.0))
	turret._process(step)
	_expect(absf(turret.elevation_degrees() + limit) < 0.001,
		"…and at the same angle below the horizon",
		"reached %.2f deg" % turret.elevation_degrees())

	# The stick, unlike the mouse, sweeps at a rate.
	turret.set_aim_direction(Vector3.FORWARD)
	Input.action_press("aim_right")
	for _i in 30:
		turret._process(1.0 / 60.0)
	Input.action_release("aim_right")
	var tuned_sweep := Tuning.num("turret/traverse_deg_per_sec") * 0.5
	_expect(absf(turret.azimuth_degrees() - tuned_sweep) < maxf(tuned_sweep * 0.02, 0.5),
		"the stick sweeps the gun at turret/traverse_deg_per_sec",
		"swept %.1f deg in half a second, tuned %.1f" % [turret.azimuth_degrees(), tuned_sweep])

	# Loadouts. Four weapons over two buttons means switching is what it costs to
	# reach the other two — so the two loadouts must actually differ.
	_expect(turret.loadout() == 1, "the station starts on loadout 1",
		"started on %d" % turret.loadout())
	var first_pair := [turret.primary(), turret.secondary()]
	_expect(turret.set_loadout(2) == 2, "2 switches loadout", "stayed on %d" % turret.loadout())
	_expect(turret.primary() != first_pair[0] or turret.secondary() != first_pair[1],
		"the two loadouts are not the same pair of weapons",
		"both hold %s / %s" % [Turret.weapon_label(turret.primary()),
			Turret.weapon_label(turret.secondary())])
	_expect(turret.set_loadout(3) == 2, "a loadout outside 1..2 is refused",
		"landed on %d" % turret.loadout())
	_expect(turret.set_loadout(1) == 1, "1 switches back", "stayed on %d" % turret.loadout())

	for slot: String in ["loadout_1_primary", "loadout_1_secondary",
			"loadout_2_primary", "loadout_2_secondary"]:
		var raw := Tuning.text("turret/" + slot)
		var known := Turret.weapon_from_name(raw) != Turret.Weapon.NONE \
			or raw.strip_edges().to_lower() == "none"
		_expect(known, "turret/%s names a real weapon, or \"none\"" % slot,
			"got \"%s\"" % raw)

	# Names rather than indices, so a typo cannot silently arm the wrong weapon.
	_expect(Turret.weapon_from_name("autocanon") == Turret.Weapon.NONE,
		"a misspelt weapon name reads as nothing, not as its neighbour",
		"resolved to %s" % Turret.weapon_label(Turret.weapon_from_name("autocanon")))

	turret.free()
	ship.free()



## The turret's first two weapons (stage 2): the autocannon and the pulse beam.
##
## The geometry is set up so the gun looks straight down the axis at component 0
## with nothing in the way, which makes every assertion below about the WEAPON
## rather than about whether the shot happened to clear a wing.
func _test_turret_weapons() -> void:
	var world := Node3D.new()
	add_child(world)

	var enemy := TargetShip.new()
	enemy.set_process(false)
	world.add_child(enemy)
	enemy.position = Vector3(0.0, 0.0, -160.0)
	if enemy.component_count() == 0:
		# enemy/component_count is a tuned A/B switch; with no components there is
		# nothing for damage to land on and these assertions would be vacuous.
		world.free()
		return

	var ship := Mothership.new()
	ship.set_process(false)
	world.add_child(ship)

	var turret := Turret.new()
	turret.ship = ship
	turret.set_process(false)
	world.add_child(turret)
	turret.setup(world, enemy, null)

	# The speed hierarchy is structural, not advisory (CLAUDE.md). A round has to
	# outrun a BOOSTING missile — a boosting missile is still a missile.
	var missile_top := Tuning.num("missile/base_speed") * Tuning.num("missile/boost_multiplier")
	_expect(Projectile.resolved_speed("turret/autocannon") > missile_top,
		"an autocannon round outruns a boosting missile",
		"round %.0f m/s against a missile top of %.0f" % [
			Projectile.resolved_speed("turret/autocannon"), missile_top])
	Tuning.set_value("turret/autocannon_speed", 1.0)
	_expect(Projectile.resolved_speed("turret/autocannon") > missile_top,
		"…even when the round's own tuning says 1 m/s",
		"clamp let %.1f m/s through" % Projectile.resolved_speed("turret/autocannon"))
	Tuning.revert()

	# Park the gun on component 0's axis, aimed straight down it, at the range the
	# guns are sighted for. A travelling round leaves an offset muzzle and converges
	# on the crosshair, so it is exact at exactly this range — putting the test
	# anywhere else would be testing the parallax rather than the weapon.
	var step := 1.0 / 60.0
	turret.active = true
	var aim_at := enemy.component_position(0)
	var park := func(metres: float) -> void:
		ship.position = aim_at + Vector3(0.0, 0.0, metres) \
			- Tuning.vec3("turret/mount_offset")
		turret._process(step)
		turret.set_aim_direction(Vector3.FORWARD)
	park.call(Tuning.num("turret/convergence_distance"))

	var pool := enemy.component_hit_points()
	var round_shot := Projectile.new()
	world.add_child(round_shot)
	round_shot.launch(turret.muzzle_position(), turret.firing_direction(),
		"turret/autocannon", enemy, null)
	for _i in 240:
		round_shot._process(step)
	_expect(enemy.component_health_fraction(0) < 1.0,
		"an autocannon round damages the component it reaches",
		"component 0 still at full health")
	_expect(is_equal_approx(
			enemy.component_health_fraction(0),
			1.0 - Tuning.num("turret/autocannon_damage") / pool),
		"…for exactly turret/autocannon_damage",
		"took %.1f of a %.0f pool" % [
			(1.0 - enemy.component_health_fraction(0)) * pool, pool])

	# Fire rate. Two seconds of held trigger against the tuned rounds per second;
	# a frame of quantisation either way is expected and does not matter.
	_expect(turret.primary() == Turret.Weapon.AUTOCANNON,
		"loadout 1's left button holds the autocannon",
		"holds %s" % Turret.weapon_label(turret.primary()))
	var before := turret.rounds_fired()
	Input.action_press("fire_primary")
	for _i in 120:
		turret._process(step)
	Input.action_release("fire_primary")
	var fired := turret.rounds_fired() - before
	var expected_rounds := Tuning.num("turret/autocannon_rounds_per_second") * 2.0
	_expect(absf(float(fired) - expected_rounds) <= 1.0,
		"the autocannon fires at turret/autocannon_rounds_per_second",
		"%d rounds in 2 s, expected about %.0f" % [fired, expected_rounds])

	var idle := turret.rounds_fired()
	for _i in 120:
		turret._process(step)
	_expect(turret.rounds_fired() == idle,
		"…and nothing at all with the trigger released",
		"%d rounds fired while idle" % (turret.rounds_fired() - idle))

	# The pulse beam. Hitscan, so it damages on the frame it is held — there is no
	# travel time to wait out, which is the point of it. And unlike a round it is
	# resolved along the sight line, so it is exact at ranges the autocannon is not:
	# tested at 60% of its own range, well inside convergence_distance.
	_expect(turret.secondary() == Turret.Weapon.PULSE,
		"loadout 1's right button holds the pulse beam",
		"holds %s" % Turret.weapon_label(turret.secondary()))
	park.call(Tuning.num("turret/pulse_range") * 0.6)
	var health_before := enemy.component_health_fraction(0)
	Input.action_press("fire_secondary")
	turret._process(step)
	_expect(enemy.component_health_fraction(0) < health_before,
		"the beam damages on the very frame it is held — no travel time",
		"nothing landed in one frame")
	_expect(turret.heat() > 0.0, "…and builds heat", "heat stayed at zero")

	# The property that separates it from a travelling round: it lands where it is
	# pointed at ANY range, not only where the guns are sighted.
	park.call(Tuning.num("turret/pulse_range") * 0.25)
	var near_health := enemy.component_health_fraction(0)
	turret._process(step)
	_expect(enemy.component_health_fraction(0) < near_health,
		"…and it is exact at close range too, where a slung round would land low",
		"nothing landed at a quarter of its range")

	# Heat is the beam's whole limiter, so it has to actually lock out.
	var to_overheat := int(ceil(60.0 / maxf(Tuning.num("turret/pulse_heat_per_second"), 0.01))) + 4
	for _i in to_overheat:
		turret._process(step)
	Input.action_release("fire_secondary")
	_expect(turret.is_overheated(), "holding the beam overheats it and locks it out",
		"heat reached %.2f without locking out" % turret.heat())

	var locked_health := enemy.component_health_fraction(0)
	Input.action_press("fire_secondary")
	turret._process(step)
	Input.action_release("fire_secondary")
	_expect(is_equal_approx(enemy.component_health_fraction(0), locked_health),
		"an overheated beam does no damage however hard the button is held",
		"still burning through the lockout")

	var hot := turret.heat()
	turret._process(step)
	_expect(turret.heat() < hot, "…and it cools while locked out",
		"heat stuck at %.2f" % turret.heat())

	var lockout := Tuning.num("turret/pulse_overheat_lockout_seconds")
	for _i in int(ceil(lockout * 60.0)) + 4:
		turret._process(step)
	_expect(not turret.is_overheated(),
		"the lockout clears after turret/pulse_overheat_lockout_seconds",
		"still locked out after %.1f s" % lockout)

	# A slot set to "none" is how a weapon is taken out of a test run without a
	# code change — part of the build's independently-disableable requirement.
	Tuning.set_value("turret/loadout_1_primary", "none")
	_expect(turret.primary() == Turret.Weapon.NONE,
		"a loadout slot set to \"none\" arms nothing",
		"holds %s" % Turret.weapon_label(turret.primary()))
	var quiet := turret.rounds_fired()
	Input.action_press("fire_primary")
	for _i in 120:
		turret._process(step)
	Input.action_release("fire_primary")
	_expect(turret.rounds_fired() == quiet,
		"…and firing it does nothing",
		"%d rounds from an empty slot" % (turret.rounds_fired() - quiet))
	Tuning.revert()

	world.free()



## Splash (ADR 0004) and the unguided missile, which is the weapon it was built
## for. The rule under test is not "splash exists" but "splash is a consolation,
## never a build" — so most of these assertions are about how much it *cannot* do.
func _test_splash_and_unguided() -> void:
	# The pure rule first, with no scene tree in the way.
	var peak := 100.0
	var radius := 20.0
	var power := Tuning.num("missile/splash_falloff_power")
	_expect(is_equal_approx(Damage.splash(peak, 0.0, radius, power), peak),
		"splash is full strength at the centre of the blast",
		"%.2f of %.2f" % [Damage.splash(peak, 0.0, radius, power), peak])
	_expect(is_equal_approx(Damage.splash(peak, radius, radius, power), 0.0),
		"…and nothing at all at the edge",
		"%.2f at the edge" % Damage.splash(peak, radius, radius, power))
	_expect(is_equal_approx(Damage.splash(peak, radius * 2.0, radius, power), 0.0),
		"…or beyond it", "still doing damage outside the radius")
	# "Steeply" is the load-bearing word in ADR 0004: halfway out must be much less
	# than half strength, or the blast is a polite taper and detonating near the
	# target becomes the optimal play.
	_expect(Damage.splash(peak, radius * 0.5, radius, power) < peak * 0.25,
		"splash collapses faster than linearly — ADR 0004's 'steeply'",
		"%.1f%% at half the radius" % Damage.splash(peak, radius * 0.5, radius, power))
	_expect(is_equal_approx(Damage.splash(peak, radius * 0.5, radius, 1.0),
			Damage.splash(peak, radius * 0.5, radius, 2.0)),
		"…and a falloff power below 2 is floored, so no tuning buys a straight taper",
		"a linear falloff got through the floor")

	var direct := 100.0
	_expect(Damage.capped_peak(1000.0, direct, 5.0) < direct,
		"a blast can never be worth as much as a direct hit, whatever tuning says",
		"capped at %.1f against a direct hit of %.1f" % [
			Damage.capped_peak(1000.0, direct, 5.0), direct])

	# Now the weapon.
	var world := Node3D.new()
	add_child(world)
	var enemy := TargetShip.new()
	enemy.set_process(false)
	world.add_child(enemy)
	if enemy.component_count() < 2:
		world.free()
		return
	var pool := enemy.component_hit_points()

	# The reason the weapon exists: one blast reaching several components at once.
	var touched := enemy.damage_in_radius(enemy.position,
		Tuning.num("turret/unguided_blast_radius"),
		Tuning.num("turret/unguided_blast_damage"),
		Tuning.num("turret/unguided_blast_falloff_power"))
	_expect(touched >= 2, "one blast reaches several components at once",
		"only touched %d" % touched)
	var alive_and_hurt := 0
	for i in enemy.component_count():
		if enemy.component_health_fraction(i) < 1.0:
			alive_and_hurt += 1
	_expect(alive_and_hurt >= 2, "…and all of them actually lost health",
		"only %d took damage" % alive_and_hurt)

	# A direct hit must not also be splashed by its own warhead, or it would
	# quietly be worth more than its damage number says.
	var fresh := TargetShip.new()
	fresh.set_process(false)
	world.add_child(fresh)
	fresh.damage_in_radius(fresh.component_position(0), 100.0, 50.0, 2.0, 0)
	_expect(is_equal_approx(fresh.component_health_fraction(0), 1.0),
		"a blast skips the component its own direct hit already paid for",
		"double-counted: %.2f left" % fresh.component_health_fraction(0))

	# The ridden missile's early detonation, which is the last of POC step 5.
	var victim := TargetShip.new()
	victim.set_process(false)
	world.add_child(victim)
	var missile := Missile.new()
	missile.set_process(false)
	world.add_child(missile)
	missile.launch(victim.component_position(0) + Vector3(0.0, 0.0, 5.0),
		Basis.IDENTITY, Vector3.ZERO, victim, victim.radius, null)
	var before := victim.component_health_fraction(0)
	missile.detonate_early()
	var spent := (before - victim.component_health_fraction(0)) * pool
	_expect(spent > 0.0, "an early detonation splashes what the missile was near",
		"nothing landed 5 m from a component")
	_expect(spent < Tuning.num("missile/damage"),
		"…for steeply less than a direct hit would have done",
		"%.1f damage against a direct hit of %.1f" % [spent, Tuning.num("missile/damage")])

	# The magazine, and the second click.
	var ship := Mothership.new()
	ship.set_process(false)
	world.add_child(ship)
	var turret := Turret.new()
	turret.ship = ship
	turret.set_process(false)
	world.add_child(turret)
	turret.setup(world, enemy, null)
	turret.active = true
	turret.set_loadout(2)
	_expect(turret.primary() == Turret.Weapon.UNGUIDED,
		"loadout 2's left button holds the unguided missile",
		"holds %s" % Turret.weapon_label(turret.primary()))
	_expect(Turret.is_click_weapon(Turret.Weapon.UNGUIDED)
			and not Turret.is_click_weapon(Turret.Weapon.AUTOCANNON),
		"the unguided missile is clicked and the autocannon is held",
		"both are treated the same way")

	var step := 1.0 / 60.0
	var click := func() -> void:
		Input.action_press("fire_primary")
		turret._process(step)
		Input.action_release("fire_primary")
		turret._process(step)

	# The round has to be drawn from its OWN tuning group. It was not: the body was
	# built in `_ready`, which fires when the node enters the tree and therefore
	# before `launch` has said which weapon this is, so every round was drawn with
	# the autocannon's size and colour.
	var sample := Projectile.new()
	world.add_child(sample)
	sample.launch(Vector3.ZERO, Vector3.FORWARD, "turret/unguided", null, null)
	var drawn := (sample.get_node_or_null("Round") as MeshInstance3D)
	var drawn_mesh := drawn.mesh as BoxMesh if drawn != null else null
	_expect(drawn_mesh != null and is_equal_approx(
			drawn_mesh.size.z, Tuning.num("turret/unguided_round_length")),
		"a round is drawn from its own tuning group, not the autocannon's",
		"drew a body of %s" % (drawn_mesh.size if drawn_mesh != null else "nothing"))
	sample.free()

	var magazine := Tuning.integer("turret/unguided_magazine")
	_expect(turret.unguided_remaining() == magazine,
		"the magazine starts full", "%d of %d" % [turret.unguided_remaining(), magazine])

	click.call()
	_expect(turret.unguided_remaining() == magazine - 1,
		"a click spends a round", "%d left" % turret.unguided_remaining())
	_expect(turret.unguided_in_flight(), "…and puts one in the air", "nothing in flight")

	click.call()
	_expect(not turret.unguided_in_flight(),
		"the second click detonates the one in the air", "still flying")
	_expect(turret.unguided_remaining() == magazine - 1,
		"…and costs no ammunition", "%d left" % turret.unguided_remaining())

	# Held rather than clicked, this weapon would empty its magazine in a fifth of
	# a second. Two seconds of held trigger may spend exactly the one round the
	# initial press asked for, and no more.
	var before_hold := turret.unguided_remaining()
	Input.action_press("fire_primary")
	for _i in 120:
		turret._process(step)
	Input.action_release("fire_primary")
	turret._process(step)
	_expect(turret.unguided_remaining() == before_hold - 1,
		"two seconds of held trigger spends one round, not the magazine",
		"lost %d rounds to one held press" % (before_hold - turret.unguided_remaining()))

	# Run it dry. Two clicks per round: one to fire, one to detonate.
	for _i in magazine * 2:
		click.call()
	_expect(turret.unguided_remaining() == 0, "the magazine runs dry",
		"%d left after emptying it" % turret.unguided_remaining())
	click.call()
	_expect(not turret.unguided_in_flight(),
		"…and an empty magazine launches nothing", "fired on an empty magazine")

	# The trickle back. One round per turret/unguided_reload_seconds, not the whole
	# magazine at once, so running dry is a slope rather than a cliff.
	var reload := Tuning.num("turret/unguided_reload_seconds")
	if reload > 0.0:
		for _i in int(ceil(reload * 60.0)) + 2:
			turret._process(step)
		_expect(turret.unguided_remaining() == 1,
			"one round trickles back after turret/unguided_reload_seconds",
			"%d back after %.1f s" % [turret.unguided_remaining(), reload])

	Tuning.set_value("turret/unguided_reload_seconds", 0.0)
	var dry := turret.unguided_remaining()
	for _i in 3600:
		turret._process(step)
	_expect(turret.unguided_remaining() == dry,
		"a reload time of 0 means the magazine never refills in a session",
		"gained %d rounds anyway" % (turret.unguided_remaining() - dry))
	Tuning.revert()

	world.free()



## Flares and blockers (ADR 0051). The behaviour worth pinning down is not "a flare
## can stop a missile" but the three things around it: it stops only the other
## side's, it is spent doing so, and the enemy rolls for it once per missile rather
## than once per frame — which is the difference between a tuned chance and a
## chance that always fires on the first frame.
func _test_flares_and_blockers() -> void:
	var world := Node3D.new()
	add_child(world)
	var step := 1.0 / 60.0

	var parked := Flare.new()
	world.add_child(parked)
	parked.launch(Vector3(0.0, 0.0, -60.0), Vector3.ZERO, Flare.Side.ENEMY)
	var through_it_a := Vector3(0.0, 0.0, -40.0)
	var through_it_b := Vector3(0.0, 0.0, -80.0)

	_expect(Flare.intercept(get_tree(), through_it_a, through_it_b, Flare.Side.PLAYER) == parked,
		"a flare stops a missile of the other side", "let it through")
	_expect(Flare.intercept(get_tree(), through_it_a, through_it_b, Flare.Side.ENEMY) == null,
		"…and never one of its own", "shot down its own side")
	_expect(Flare.intercept(get_tree(), through_it_a + Vector3(500.0, 0.0, 0.0),
			through_it_b + Vector3(500.0, 0.0, 0.0), Flare.Side.PLAYER) == null,
		"a flare does nothing to a missile that misses it", "false positive")

	# A ridden missile flying into one, through the real flight path.
	var enemy := TargetShip.new()
	enemy.set_process(false)
	world.add_child(enemy)
	enemy.position = Vector3(0.0, 0.0, -400.0)
	var missile := Missile.new()
	missile.set_process(false)
	world.add_child(missile)
	missile.launch(Vector3.ZERO, Basis.IDENTITY, Vector3.ZERO, enemy, enemy.radius, null)
	var ended := {"reason": -1}
	missile.detonated.connect(func(_m: Missile, reason: int, _hit: bool) -> void:
		ended["reason"] = reason)
	for _i in 600:
		if int(ended["reason"]) >= 0:
			break
		missile._process(step)
	_expect(int(ended["reason"]) == Missile.EndReason.FLARE_INTERCEPT,
		"a missile flown into a flare is stopped by it",
		"ended with reason %d" % int(ended["reason"]))
	_expect(parked.is_spent(), "…and the flare is spent doing it",
		"the same flare could stop another")
	_expect(Flare.intercept(get_tree(), through_it_a, through_it_b, Flare.Side.PLAYER) == null,
		"…and stops being a wall immediately", "a spent flare still blocks")

	# The star. A ring ACROSS the threat axis is a wall; a cone down it is a line of
	# flares the missile flies between.
	var star := Flare.burst(world, Vector3(0.0, 0.0, 900.0), Vector3.FORWARD,
		Flare.Side.PLAYER, 6)
	_expect(star.size() == 6, "a blocker throws the number of flares it was asked for",
		"threw %d" % star.size())
	# The two components are separately tuned and each has a job: the launch speed
	# moves the whole wall towards the threat, the spread speed opens the ring. A
	# star with no spread is a clump; a star with no launch is dropped in place.
	var sideways_total := Vector3.ZERO
	var least_sideways := INF
	var least_forward := INF
	for thrown in star:
		var velocity := thrown.velocity()
		var forward_part := velocity.dot(Vector3.FORWARD)
		var sideways := velocity - Vector3.FORWARD * forward_part
		sideways_total += sideways
		least_sideways = minf(least_sideways, sideways.length())
		least_forward = minf(least_forward, forward_part)
	_expect(least_forward > 0.0,
		"…with the whole wall travelling towards the threat",
		"a flare went backwards: %.2f m/s along the axis" % least_forward)
	_expect(least_sideways > 0.0,
		"…and every flare opening away from the others, so it is a wall not a clump",
		"a flare had no sideways component at all")
	_expect(sideways_total.length() < least_sideways * 0.01,
		"…evenly, so the sideways parts cancel and the ring is not lopsided",
		"the star leans by %s" % sideways_total)
	_expect(is_equal_approx(least_sideways, Tuning.num("flare/spread_speed"))
			and is_equal_approx(least_forward, Tuning.num("flare/launch_speed")),
		"…at exactly the two tuned speeds",
		"%.1f m/s out and %.1f along, tuned %.1f and %.1f" % [
			least_sideways, least_forward,
			Tuning.num("flare/spread_speed"), Tuning.num("flare/launch_speed")])

	# Both flare speeds are slower than a ship at cruise, so a star that did not
	# carry the launcher's motion would be behind it the moment it was thrown — the
	# ship flies out through its own countermeasure (ADR 0055).
	var carrier := Vector3(0.0, 0.0, -40.0)
	var moving := Flare.burst(world, Vector3(0.0, 0.0, 1600.0), Vector3.FORWARD,
		Flare.Side.PLAYER, 4, carrier)
	var slowest_along := INF
	for thrown in moving:
		slowest_along = minf(slowest_along, thrown.velocity().dot(carrier.normalized()))
	_expect(slowest_along > carrier.length(),
		"a star carries the launching ship's own motion, and then some",
		"the slowest flare makes %.1f m/s against a ship doing %.1f" % [
			slowest_along, carrier.length()])

	Tuning.set_value("flare/velocity_inheritance", 0.0)
	var dropped := Flare.burst(world, Vector3(0.0, 0.0, 2400.0), Vector3.FORWARD,
		Flare.Side.PLAYER, 4, carrier)
	var fastest_along := -INF
	for thrown in dropped:
		fastest_along = maxf(fastest_along, thrown.velocity().dot(carrier.normalized()))
	_expect(fastest_along < carrier.length(),
		"…and an inheritance of 0 drops it in place, which is the bug it fixes",
		"still keeping up at %.1f m/s" % fastest_along)
	Tuning.revert()

	# A flare stops being a wall when it burns out.
	var timed := Flare.new()
	world.add_child(timed)
	timed.launch(Vector3(0.0, 0.0, 4000.0), Vector3.ZERO, Flare.Side.ENEMY)
	for _i in int(ceil(Tuning.num("flare/seconds") * 60.0)) + 4:
		timed._process(step)
	_expect(timed.is_spent(), "a flare burns out after flare/seconds",
		"%.2f s still on the clock" % timed.seconds_left())

	# The roll, on its own, over enough trials for the tuned chance to mean something.
	var wins := 0
	for _i in 800:
		if TargetShip.rolls_a_blocker(0.5):
			wins += 1
	_expect(absf(float(wins) / 800.0 - 0.5) < 0.08,
		"the tuned blocker chance is honoured over many trials",
		"%d of 800 — %.0f%%" % [wins, float(wins) / 8.0])
	_expect(not TargetShip.rolls_a_blocker(0.0), "a chance of 0 never answers", "it did")
	_expect(TargetShip.rolls_a_blocker(1.0), "a chance of 1 always does", "it did not")

	# And in place, against something in the group. A bare node stands in for a
	# missile: what is under test is the ship's decision, not the missile's flight.
	var decoy := Node3D.new()
	world.add_child(decoy)
	decoy.add_to_group("player_missile")
	decoy.position = enemy.position + Vector3(0.0, 0.0, 40.0)

	var flare_count := func() -> int: return get_tree().get_nodes_in_group("flare").size()
	Tuning.set_value("enemy/blocker_chance", 0.0)
	var before_none := int(flare_count.call())
	for _i in 30:
		enemy._tick_blockers(step)
	_expect(int(flare_count.call()) == before_none,
		"enemy/blocker_chance = 0 takes the whole layer out of a run",
		"threw flares anyway")

	# A fresh missile, because the first one has already been rolled for.
	decoy.remove_from_group("player_missile")
	var decoy_two := Node3D.new()
	world.add_child(decoy_two)
	decoy_two.add_to_group("player_missile")
	decoy_two.position = enemy.position + Vector3(0.0, 0.0, 40.0)

	Tuning.set_value("enemy/blocker_chance", 1.0)
	var before_star := int(flare_count.call())
	enemy._tick_blockers(step)
	var expected_star := Tuning.integer("enemy/blocker_flare_count")
	_expect(int(flare_count.call()) == before_star + expected_star,
		"an incoming missile inside blocker_trigger_range is answered with a star",
		"threw %d flares" % (int(flare_count.call()) - before_star))

	# Once per missile, not once per frame. The cooldown is zeroed so that it is the
	# per-missile roll being tested and not the launcher being busy.
	Tuning.set_value("enemy/blocker_cooldown_seconds", 0.0)
	var after_star := int(flare_count.call())
	for _i in 60:
		enemy._tick_blockers(step)
	_expect(int(flare_count.call()) == after_star,
		"a missile is answered once, not once per frame",
		"threw %d more flares over a second" % (int(flare_count.call()) - after_star))
	Tuning.revert()

	# Out of range is not answered at all.
	var distant := Node3D.new()
	world.add_child(distant)
	distant.add_to_group("player_missile")
	distant.position = enemy.position \
		+ Vector3(0.0, 0.0, Tuning.num("enemy/blocker_trigger_range") * 4.0)
	Tuning.set_value("enemy/blocker_chance", 1.0)
	var before_far := int(flare_count.call())
	for _i in 30:
		enemy._tick_blockers(step)
	_expect(int(flare_count.call()) == before_far,
		"a missile beyond blocker_trigger_range is not answered",
		"answered something %.0f m away" % enemy.position.distance_to(distant.position))
	Tuning.revert()

	world.free()



## The launch tube's cooldown (POC step 6). Small, and the single most consequential
## number in the build: success criterion 2 is a question about it.
func _test_missile_cooldown() -> void:
	var world := Node3D.new()
	add_child(world)
	var target := Node3D.new()
	world.add_child(target)
	var ship := Mothership.new()
	ship.set_process(false)
	world.add_child(ship)
	ship.target = target
	ship.position = Vector3(0.0, 0.0, 1.0)
	ship.snap_to_standoff()

	var step := 1.0 / 60.0
	var tuned := Tuning.num("ship/missile_cooldown_seconds")
	_expect(ship.missile_ready(), "the tube starts loaded", "started cold")
	_expect(is_equal_approx(ship.missile_charge(), 1.0),
		"…and reads as fully charged", "%.2f" % ship.missile_charge())

	ship.note_missile_launched()
	_expect(not ship.missile_ready(), "launching empties the tube", "still ready")
	_expect(ship.missile_charge() < 0.05,
		"…and the gauge drops to nothing", "%.2f charged" % ship.missile_charge())

	# The tube reloads on its own clock, whichever station the player is at — while
	# riding, at the guns, or flying. That is the whole of the rhythm this build
	# exists to read.
	ship.piloted = false
	var frames := 0
	while not ship.missile_ready() and frames < 6000:
		ship._process(step)
		frames += 1
	var took := float(frames) * step
	_expect(absf(took - tuned) < maxf(tuned * 0.05, 2.0 * step),
		"the tube reloads in ship/missile_cooldown_seconds, unattended",
		"took %.2f s against a tuned %.2f" % [took, tuned])
	_expect(ship.missile_ready(), "…and is ready at the end of it", "still cold")

	# Halfway through, the gauge has to say halfway — the bar is the instrument.
	ship.note_missile_launched()
	for _i in int(tuned * 30.0):
		ship._process(step)
	_expect(absf(ship.missile_charge() - 0.5) < 0.05,
		"the reload gauge tracks the cooldown", "%.2f at halfway" % ship.missile_charge())

	# 0 is the escape hatch back to the pre-step-6 arena.
	Tuning.set_value("ship/missile_cooldown_seconds", 0.0)
	ship.note_missile_launched()
	_expect(ship.missile_ready(),
		"a cooldown of 0 removes the mechanic entirely", "still made us wait")
	Tuning.revert()

	world.free()



## The interrupt (POC step 8). The most dangerous thing in the build for the target
## experience, so most of what is pinned down here is that it can be switched off,
## that it is telegraphed before it happens, and that every weapon that should be
## able to answer it can.
func _test_interrupt() -> void:
	var world := Node3D.new()
	add_child(world)
	var ship := Mothership.new()
	ship.set_process(false)
	world.add_child(ship)
	var enemy := TargetShip.new()
	enemy.set_process(false)
	world.add_child(enemy)
	enemy.position = Vector3(0.0, 0.0, -Tuning.num("ship/standoff_distance"))
	enemy.player = ship
	var step := 1.0 / 60.0

	var live := func() -> int:
		return get_tree().get_nodes_in_group(EnemyMissile.GROUP).size()

	# Off is off. This is the escape hatch that keeps a clean reading of steps 6 and
	# 7 obtainable while step 8 exists.
	Tuning.set_value("enemy/interrupt_interval_seconds", 0.0)
	var before_off := int(live.call())
	for _i in 600:
		enemy._tick_interrupt(step)
	_expect(int(live.call()) == before_off,
		"enemy/interrupt_interval_seconds = 0 never launches anything",
		"launched %d anyway" % (int(live.call()) - before_off))
	_expect(enemy.seconds_to_interrupt() < 0.0,
		"…and reports itself as off", "still counting down")

	# Telegraphed BEFORE the launch, not at it. Pillar 2: it must be possible to win
	# both, which is only true if the warning arrives with time left to act on.
	Tuning.set_value("enemy/interrupt_interval_seconds", 4.0)
	Tuning.set_value("enemy/interrupt_warning_lead_seconds", 2.0)
	var warned := {"count": 0, "at": -1.0}
	var launched := {"count": 0}
	enemy.interrupt_warned.connect(func() -> void:
		warned["count"] = int(warned["count"]) + 1
		warned["at"] = 4.0 - enemy.seconds_to_interrupt())
	enemy.interrupt_launched.connect(func(_m: EnemyMissile) -> void:
		launched["count"] = int(launched["count"]) + 1)

	var before_cycle := int(live.call())
	# A shade over the interval: 240 sixtieths of a second accumulate to slightly
	# under 4.0 in floating point, and the launch is on `>=`.
	for _i in 260:
		enemy._tick_interrupt(step)
	_expect(int(warned["count"]) == 1, "the interrupt is telegraphed exactly once",
		"%d warnings in one cycle" % int(warned["count"]))
	_expect(absf(float(warned["at"]) - 2.0) < 0.1,
		"…a full interrupt_warning_lead_seconds before the launch",
		"warned %.2f s in, launch at 4.0" % float(warned["at"]))
	_expect(int(launched["count"]) == 1, "the interrupt fires on its interval",
		"%d launches" % int(launched["count"]))
	_expect(int(live.call()) == before_cycle + 1,
		"…and puts exactly one missile in the air",
		"%d in the air" % (int(live.call()) - before_cycle))
	Tuning.revert()

	# Clear the one the timing test put up. Every interrupt launches from the same
	# point, so leaving it there would make the assertions below name whichever of
	# two overlapping missiles the group happened to list first.
	for node in get_tree().get_nodes_in_group(EnemyMissile.GROUP):
		(node as EnemyMissile).take_damage(1e9)

	# The speed hierarchy applies to both sides: an enemy missile that outran the
	# player's own would outrun the rounds meant to intercept it.
	var missile_top := Tuning.num("missile/base_speed") * Tuning.num("missile/boost_multiplier")
	Tuning.set_value("enemy/missile_speed", missile_top * 10.0)
	_expect(EnemyMissile.resolved_speed() <= missile_top + 0.001,
		"an enemy missile cannot outrun the player's own at full boost",
		"%.0f m/s against a top of %.0f" % [EnemyMissile.resolved_speed(), missile_top])
	Tuning.revert()

	# The aim error is bounded, and zero means it never misses.
	var spread := Tuning.num("enemy/missile_aim_error")
	var worst := 0.0
	for _i in 200:
		worst = maxf(worst, EnemyMissile.random_error().length())
	_expect(worst <= spread + 0.001, "the aim error stays inside enemy/missile_aim_error",
		"drew %.1f m against a spread of %.1f" % [worst, spread])
	_expect(worst > spread * 0.5,
		"…and actually uses the spread it is given",
		"never drew more than %.1f m of a possible %.1f" % [worst, spread])
	Tuning.set_value("enemy/missile_aim_error", 0.0)
	_expect(EnemyMissile.random_error().is_equal_approx(Vector3.ZERO),
		"an aim error of 0 means it never misses", "still wandered")
	Tuning.revert()

	# Shootable: it is simply another thing on the segment, and wins if it is nearest.
	var incoming := enemy.launch_interrupt()
	_expect(incoming != null, "launch_interrupt() puts one in the air", "returned null")
	if incoming == null:
		world.free()
		return
	incoming.set_process(false)
	var across_a := incoming.position + Vector3(0.0, 0.0, 40.0)
	var across_b := incoming.position - Vector3(0.0, 0.0, 40.0)
	var found := Shot.resolve(across_a, across_b, null, null, get_tree())
	_expect(int(found["kind"]) == Shot.Kind.ENEMY_MISSILE,
		"a turret shot resolves against an incoming missile",
		"resolved to %s" % Shot.kind_label(int(found["kind"])))
	_expect(found["node"] == incoming, "…and names the one it reached", "named something else")

	# Answerable from loadout 1. If the autocannon cannot bring one down in a
	# handful of rounds the interrupt is unanswerable unless you switched loadout
	# before it arrived, which the player has no way of knowing to do.
	var rounds := 0
	while not incoming.is_spent() and rounds < 200:
		rounds += 1
		incoming.take_damage(Tuning.num("turret/autocannon_damage"))
	_expect(incoming.is_spent(), "the autocannon brings an incoming missile down",
		"survived %d rounds" % rounds)
	_expect(rounds <= 8, "…in a handful of rounds, not a magazine",
		"took %d rounds at %.1f each" % [rounds, Tuning.num("turret/autocannon_damage")])

	var by_beam := enemy.launch_interrupt()
	by_beam.set_process(false)
	by_beam.take_damage(Tuning.num("turret/pulse_damage_per_second") * 1.0)
	_expect(by_beam.is_spent(), "one second of pulse beam brings one down",
		"%.0f%% health left" % (by_beam.health_fraction() * 100.0))

	# The unguided missile's stated second job: "potentially useful for killing
	# enemy missiles as well as damaging multiple components".
	var by_blast := enemy.launch_interrupt()
	by_blast.set_process(false)
	var peak := Damage.capped_peak(Tuning.num("turret/unguided_blast_damage"),
		Tuning.num("turret/unguided_damage"),
		Tuning.num("turret/unguided_blast_max_fraction"))
	var killed := EnemyMissile.splash(get_tree(), by_blast.position,
		Tuning.num("turret/unguided_blast_radius"), peak,
		Tuning.num("turret/unguided_blast_falloff_power"))
	_expect(killed >= 1 and by_blast.is_spent(),
		"an unguided missile's blast kills an incoming one it goes off on",
		"killed %d" % killed)

	# And a player flare stops one, which is the blockers' other half.
	var by_flare := enemy.launch_interrupt()
	var wall := Flare.new()
	world.add_child(wall)
	wall.launch(by_flare.position - (by_flare.position - ship.position).normalized() * 10.0,
		Vector3.ZERO, Flare.Side.PLAYER)
	var flare_end := {"reason": -1}
	by_flare.ended.connect(func(_m: EnemyMissile, reason: int, _p: Vector3) -> void:
		flare_end["reason"] = reason)
	for _i in 120:
		if int(flare_end["reason"]) >= 0:
			break
		by_flare._process(step)
	_expect(int(flare_end["reason"]) == EnemyMissile.EndReason.FLARE_INTERCEPT,
		"a player flare stops an incoming missile",
		"ended with reason %d" % int(flare_end["reason"]))

	# Invulnerability. The pacing build ships with it on: a hit is counted and
	# flashed, and costs nothing.
	Tuning.set_value("ship/invulnerable", true)
	var before_hits := ship.hits_taken()
	var full := ship.hp()
	_expect(not ship.take_hit(Tuning.num("enemy/missile_damage")),
		"an invulnerable ship reports the hit as costing nothing", "took damage")
	_expect(ship.hits_taken() == before_hits + 1,
		"…but the hit is still counted", "not counted")
	_expect(ship.hit_flash() > 0.0, "…and still flashes", "no feedback at all")
	_expect(is_equal_approx(ship.hp(), full), "…and no hit points were spent",
		"%.0f of %.0f left" % [ship.hp(), full])

	Tuning.set_value("ship/invulnerable", false)
	_expect(ship.take_hit(Tuning.num("enemy/missile_damage")),
		"…and with the flag off, a hit costs hit points", "still free")
	_expect(ship.hp() < full, "…and the pool actually drops",
		"%.0f of %.0f left" % [ship.hp(), full])
	Tuning.revert()

	# The one hit shape left as a sphere around a mesh has to at least contain it.
	_expect(ship.hit_radius() > Tuning.num("ship/hull_scale"),
		"the ship's hit sphere is derived from its hull, not from nothing",
		"%.1f m" % ship.hit_radius())

	world.free()


func _test_overlay_projection_guard() -> void:
	var overlay := FlightOverlay.new()
	add_child(overlay)
	var camera := Camera3D.new()
	add_child(camera)
	camera.global_position = Vector3(12.0, -4.0, 30.0)

	_expect(not overlay._projectable(camera, camera.global_position),
		"the overlay refuses to project a point at the camera's own origin",
		"would hit the p.d == 0 assert in camera_3d.cpp")
	_expect(overlay._projectable(camera, camera.global_position + Vector3(0.0, 0.0, -25.0)),
		"…and still projects a point in front of it", "guard is too greedy")
	_expect(overlay._projectable(camera, camera.global_position + Vector3(0.0, 0.0, 25.0)),
		"…and one behind it, which the caller handles separately", "guard is too greedy")

	camera.free()
	overlay.free()


func _test_reference_field() -> void:
	var field := ReferenceField.new()
	add_child(field)

	_expect(field.rock_count() == Tuning.integer("arena/rock_count"),
		"reference field builds every tuned rock",
		"drew %d of %d" % [field.rock_count(), Tuning.integer("arena/rock_count")])
	_expect(field.hittable_count() == field.rock_count(),
		"every drawn rock is hittable while rock_collision is on",
		"%d drawn, %d hittable" % [field.rock_count(), field.hittable_count()])

	_expect(field.lobe_count() >= field.rock_count() * Tuning.integer("arena/rock_lobe_min"),
		"every rock is built from at least rock_lobe_min ellipsoids",
		"%d lobes across %d rocks" % [field.lobe_count(), field.rock_count()])
	_expect(field.lobe_count() <= field.rock_count() * Tuning.integer("arena/rock_lobe_max"),
		"…and no more than rock_lobe_max",
		"%d lobes across %d rocks" % [field.lobe_count(), field.rock_count()])

	if field.rock_count() > 0:
		var centre := field.rock_centre(0)
		var radius := field.rock_radius(0)
		_expect(radius > 0.0, "a rock has a positive hit radius", "radius=%f" % radius)

		var above := centre + Vector3(0.0, radius * 4.0, 0.0)
		var below := centre - Vector3(0.0, radius * 4.0, 0.0)
		_expect(field.hit_test(above, below) != Vector3.INF,
			"hit_test catches a segment through a rock", "passed straight through")

		# The whole reason for a swept test: both endpoints sit clear of the rock,
		# so a per-frame point check would report a clean miss (ADR 0032). What
		# comes back is the LOBE that was hit — the flash belongs where the missile
		# actually struck, not at the cluster's notional centre.
		var struck := field.hit_test(above, below)
		_expect(struck.distance_to(centre) <= radius,
			"hit_test reports the lobe that was hit, inside the rock it belongs to",
			"returned %s for a rock centred on %s" % [struck, centre])

		var far_away := centre + Vector3(0.0, radius * 50.0, 0.0)
		_expect(field.hit_test(far_away, far_away + Vector3(0.0, 1.0, 0.0)) == Vector3.INF,
			"hit_test lets a clear segment through", "false positive")

		# hit_entry answers *where*, which is what a turret round needs and a
		# missile does not: a rock between the gun and the target has to stop the
		# shot at the rock rather than let it score behind one.
		var entry := field.hit_entry(above, below)
		var t := float(entry["t"])
		var entry_point: Vector3 = entry["point"]
		_expect(t >= 0.0 and t <= 1.0, "hit_entry parameterises the same hit", "t=%f" % t)
		_expect(entry_point.distance_to(above + (below - above) * t) < 0.001,
			"…and its point lies on the segment",
			"%s is not at t=%f" % [entry_point, t])
		# The segment spans eight radii centred on the rock, so an entry anywhere on
		# a lobe has to land in the middle quarter of it. An EXIT point would land
		# past that, which is the mistake this guards against.
		_expect(absf(t - 0.5) < 0.2, "…and it is the ENTRY, not the exit",
			"t=%f — too far along to be where the shot first met the rock" % t)
		_expect(entry_point.distance_to(centre) <= radius + 0.001,
			"…inside the rock it belongs to",
			"%s against a rock of radius %.1f" % [entry_point, radius])
		_expect(float(field.hit_entry(far_away, far_away + Vector3(0.0, 1.0, 0.0))["t"]) < 0.0,
			"hit_entry lets a clear segment through", "false positive")

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

	# One collapsible fold per [section] AND per `;;;` group inside it, so the list is
	# navigable rather than one two-hundred-row scroll. `[exploration]` alone is over a
	# hundred keys, which is a scroll hunt whatever the section header says.
	var expected_sections := {}
	var grouped := {}
	for entry in Tuning.schema():
		var label := String(entry["section"])
		var group := String(entry.get("group", ""))
		if not group.is_empty():
			label += "  ·  " + group
			grouped[String(entry["section"])] = true
		expected_sections[label] = true
	_expect(grouped.has("exploration"),
		"the biggest section is subdivided into groups rather than left as one list",
		"exploration carries no `;;;` groups")
	# A group heading must not eat the documentation of the key under it.
	for entry in Tuning.schema():
		if String(entry["key"]) == "lane_width":
			_expect(String(entry["long"]).contains("GROWN from 150 x 100")
					and String(entry["group"]) == "The lane, and how wide it is",
				"…and a group heading keeps the tooltip of the key beneath it",
				"group %s, long %d chars" % [entry["group"],
					String(entry["long"]).length()])
	_expect(DebugPanel.section_count() == expected_sections.size(),
		"the panel builds one collapsible fold per section and per group",
		"%d sections for %d in the file" % [
			DebugPanel.section_count(), expected_sections.size()])
	_expect(DebugPanel.open_section_count() == 0,
		"sections start collapsed", "%d opened themselves" % DebugPanel.open_section_count())
	DebugPanel.set_section_open("missile", true)
	_expect(DebugPanel.open_section_count() == 1,
		"a section opens on demand", "%d open" % DebugPanel.open_section_count())
	# A filter has to reach into collapsed sections, or it hides its own results.
	DebugPanel.set_filter("standoff")
	_expect(DebugPanel.visible_row_count() > 0,
		"filtering finds values inside collapsed sections",
		"the filter matched nothing it could show")
	_expect(DebugPanel.visible_row_count() < rows,
		"…and hides the rest", "%d of %d rows still shown" % [
			DebugPanel.visible_row_count(), rows])
	DebugPanel.set_filter("")
	_expect(DebugPanel.open_section_count() == 1,
		"clearing the filter restores the human's fold state",
		"%d open after clearing" % DebugPanel.open_section_count())
	DebugPanel.set_section_open("missile", false)
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
			"ArenaRoot/Target/Parts", "ArenaRoot/Target/Parts/Fuselage",
			"ArenaRoot/Target/Parts/Nose", "ArenaRoot/Target/Components",
			"ArenaRoot/Mothership", "ArenaRoot/Turret",
			"ShipCamera", "MissileCamera", "TurretCamera",
			"ViewController", "DebugHud"]:
		_expect(arena.has_node(path), "arena builds node: " + path, "not constructed")

	var views := arena.call("views") as ViewController
	_expect(views != null and views.view_name() == "SHIP",
		"arena starts in ship view", "view=%s" % (views.view_name() if views else "null"))

	var ship := arena.call("ship") as Mothership
	_expect(ship != null and ship.target != null,
		"autopilot has a commanded target", "target not assigned")

	# The crew roster (ADR 0056): the player holds one job, T and G select it, and
	# the autopilot is a consequence of not being the pilot rather than a mode.
	var station := arena.call("turret") as Turret
	_expect(station != null and not station.active,
		"the station starts unmanned when the player is the pilot",
		"manned before anyone went there")
	if views != null and station != null and ship != null:
		_expect(views.set_role(ViewController.Role.GUNNER), "G takes the guns", "refused")
		_expect(views.view_name() == "TURRET", "…and that is the turret view",
			"view=%s" % views.view_name())
		_expect(station.active, "…the station starts taking input", "still unmanned")
		_expect(ship.autopilot,
			"…and the autopilot takes the ship, because nobody is flying it",
			"the ship is unattended and not on autopilot")
		_expect(not ship.piloted,
			"…while the helm stops reading input", "ship still piloted")

		# Selections, not toggles: pressing the job you already hold is a no-op,
		# so a player who has lost track can press what they want and be right.
		views.set_role(ViewController.Role.GUNNER)
		_expect(views.view_name() == "TURRET" and ship.autopilot,
			"G again keeps the guns rather than toggling back",
			"view=%s" % views.view_name())

		# A missile launches from either station now (ADR 0056 supersedes ADR
		# 0048's helm-only clause): a helm-only launch would drop the autopilot
		# every time the gunner wanted to fire.
		var from_guns := arena.call("fire") as Missile
		_expect(from_guns != null, "Q launches a missile from the guns", "refused")
		_expect(views.view_name() == "MISSILE", "…and the ride starts",
			"view=%s" % views.view_name())
		_expect(not views.set_role(ViewController.Role.PILOT),
			"a job cannot be changed mid-ride — the player is at neither station",
			"changed jobs while in a missile")
		arena.call("detonate_current")

		views.set_role(ViewController.Role.PILOT)
		_expect(views.view_name() == "SHIP", "T takes the helm",
			"view=%s" % views.view_name())
		_expect(not ship.autopilot,
			"…and the autopilot hands over, because the player is flying now",
			"still on autopilot at the helm")
		_expect(not station.active, "…leaving the guns unmanned", "still manned")
		Tuning.set_value("ship/missile_cooldown_seconds", 0.0)
		ship.note_missile_launched()
		Tuning.revert()

	var missile := arena.call("fire") as Missile
	_expect(missile != null, "fire() launches a missile", "returned null")
	_expect(int(arena.call("shots_fired")) == 2, "fire() counts the shot",
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
	# And still refused after the ride, because the tube is cold — that refusal is
	# the between-missiles the whole build exists to create.
	if ship != null and Tuning.num("ship/missile_cooldown_seconds") > 0.0:
		_expect(not ship.missile_ready(),
			"the tube is cold after a launch", "reloaded instantly")
		_expect(arena.call("fire") == null,
			"…and fire() is refused until it reloads", "launched on a cold tube")
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

## The hull-class table (EXPLORATION_DESIGN.md invariants 2 and 5). The mechanism
## is what is expensive to retrofit, so it is tested before the table has more than
## three rows in it.
func _test_hull_classes() -> void:
	for kind in HullClass.all():
		var text := HullClass.name_of(kind)
		_expect(HullClass.from_name(text) == kind,
			"hull class '%s' survives a round trip through its name" % text,
			"got %s" % HullClass.name_of(HullClass.from_name(text)))
		_expect(HullClass.from_name(text.to_upper()) == kind,
			"…and is read case-insensitively", text)

	# A name rather than an index, so a typo reads as something. It must land on the
	# default rather than on whichever class happens to be enum member 0 by accident.
	_expect(HullClass.from_name("frigate") == HullClass.DEFAULT,
		"an unknown hull class falls back to the default rather than erroring",
		"got %s" % HullClass.name_of(HullClass.from_name("frigate")))

	# THE speed ladder. These orderings are the whole of EXPLORATION_DESIGN.md's
	# §Speed Ladder, and every consequence in it — missiles are anti-capital, turrets
	# are the anti-fighter answer, capitals cannot outrun anything — falls out of
	# them rather than being imposed by a rule anywhere.
	var missile_speed := Tuning.num("missile/base_speed")
	var taxi := HullClass.max_speed(HullClass.Kind.TAXI)
	var fighter := HullClass.max_speed(HullClass.Kind.FIGHTER)
	var capital := HullClass.max_speed(HullClass.Kind.CAPITAL)
	_expect(capital < taxi and taxi < fighter,
		"the speed ladder is ordered: capital < taxi < fighter",
		"capital %.1f, taxi %.1f, fighter %.1f" % [capital, taxi, fighter])
	# THE CLAUSE IS "a missile outruns its INTENDED targets" (ADR 0059), and the
	# fighter is not one of them (ADR 0073). What has to hold is that the classes a
	# missile is FOR — the taxi and the capital — stay under it, and that the fighter
	# stays the fastest thing in the roster.
	_expect(taxi < missile_speed and capital < missile_speed,
		"a missile outruns the classes it is meant to kill: the taxi and the capital",
		"taxi %.1f, capital %.1f against a missile at %.1f" % [
			taxi, capital, missile_speed])
	_expect(fighter > taxi,
		"…and the fighter is the fastest hull there is, whichever side of a missile",
		"fighter %.1f, taxi %.1f" % [fighter, taxi])

	# The ceiling is a clamp, not a suggestion, for every class a missile is meant to
	# kill — a tuning session must not be able to produce one that matches a missile
	# by accident. The fighter declares its own and is checked against that instead.
	for kind in HullClass.all():
		var key := "exploration/%s_max_speed" % HullClass.name_of(kind)
		Tuning.set_value(key, missile_speed * 10.0)
		if not HullClass.outrun_by_missile(kind):
			_expect(HullClass.max_speed(kind) <= missile_speed
					* HullClass.MAX_CEILING_FRACTION,
				"%s is still clamped by its class's own declared ceiling" % key,
				"clamp let %.1f m/s through" % HullClass.max_speed(kind))
			continue
		_expect(HullClass.max_speed(kind) < missile_speed,
			"%s speed is clamped below a missile however high it is tuned" % key,
			"clamp let %.1f m/s through" % HullClass.max_speed(kind))
		Tuning.revert()

	# A fighter has no cruise drive, and that ONE property is why no portal opens
	# for it. If this ever becomes a separate rule about portals, this is the test
	# that should have stopped it.
	_expect(HullClass.has_cruise_drive(HullClass.Kind.TAXI),
		"a taxi carries the cruise drive", "it does not")
	_expect(not HullClass.has_cruise_drive(HullClass.Kind.FIGHTER),
		"a fighter does not, which is the whole of why it cannot use a portal",
		"it does")

	# The fallback path: a class with no entry of its own resolves to the shared key,
	# and a class with one ignores it. This is the half of `num()` that lets the
	# table grow a row at a time without an edit at any call site.
	_expect(is_equal_approx(
			HullClass.num(HullClass.Kind.TAXI, "not_a_real_property",
				"ship/manual_turn_rate_deg_per_sec"),
			Tuning.num("ship/manual_turn_rate_deg_per_sec")),
		"a property no class overrides resolves to the shared fallback",
		"it did not")
	_expect(is_equal_approx(
			HullClass.num(HullClass.Kind.FIGHTER, "max_speed", "ship/manual_max_speed"),
			Tuning.num("exploration/fighter_max_speed")),
		"…and a property the class DOES override ignores the fallback",
		"it did not")

	# Invariants 3 and 4: the autopilot and the enemy move as fractions of their own
	# hull's maximum, never as absolutes. The failure these catch is silent — an
	# absolute that was fine at 34 m/s inverts at 15.5 and nothing errors.
	var ship := Mothership.new()
	add_child(ship)
	var arc := ship.manual_max_speed() \
		* clampf(Tuning.num("ship/arc_speed_fraction"), 0.0, 0.95)
	_expect(arc < ship.manual_max_speed(),
		"the autopilot arc is slower than flying the ship yourself (Pillar 1)",
		"arc %.1f vs manual %.1f" % [arc, ship.manual_max_speed()])
	_expect(arc > ship.manual_max_speed() * 0.25,
		"…but not so much slower that delegating is a punishment",
		"arc is %.2f of manual" % (arc / ship.manual_max_speed()))
	ship.free()

	_expect(TargetShip.tuned_drift_speed() < HullClass.max_speed(HullClass.Kind.TAXI),
		"an enemy of the player's class cannot simply outrun the ship sent at it",
		"enemy drifts at %.1f, player tops out at %.1f" % [
			TargetShip.tuned_drift_speed(), HullClass.max_speed(HullClass.Kind.TAXI)])


## Lane, deck and portal geometry. These are the relationships that have to hold
## whatever the numbers are tuned to; the numbers themselves are the human's.
func _test_lane_geometry() -> void:
	var lane_width := Tuning.num("exploration/lane_width")
	var lane_height := Tuning.num("exploration/lane_height")
	_expect(lane_height < lane_width,
		"the lane is wider than it is tall — monitor aspect, and roll is locked",
		"%.0f wide x %.0f tall" % [lane_width, lane_height])
	_expect(Tuning.num("exploration/deck_separation") >= lane_width,
		"the two decks are separated by more than one deck's WIDTH, so they do not intersect",
		"separation %.0f across vs width %.0f" % [
			Tuning.num("exploration/deck_separation"), lane_width])
	_expect(Tuning.num("exploration/lane_edge_softness") < lane_width * 0.5,
		"the soft edge is a gradient, not the whole lane",
		"softness %.0f against a half-width of %.0f" % [
			Tuning.num("exploration/lane_edge_softness"), lane_width * 0.5])
	_expect(Tuning.num("exploration/lane_edge_speed_penalty") > 0.0,
		"outside the lane is SLOWER, never stopped — the boundary is soft (ADR 0014)",
		"a zero penalty is a wall")

	# The portal is the on-ramp mouth and is deliberately NARROWER than the road it
	# feeds. What must hold is that it clears the hull: a ship that cannot fit
	# through an "unmissable, drive in, no ceremony" opening is the failure here.
	# EVERY hull in the roster, not just the shared scale. The capital is drawn at
	# 1.75 and is 76 m across; checking the aperture against the 1.0 hull passed
	# happily while the ship the human was actually flying cleared it by 12 m and had
	# nowhere to be in the lane behind it. A roster the road cannot carry is a bug in
	# the road, and it has to be one number that says so.
	var hull := load("res://assets/models/carrier.obj") as Mesh
	var portal_width := Tuning.num("exploration/portal_width")
	var portal_height := Tuning.num("exploration/portal_height")
	var widest := Vector2.ZERO
	for kind: HullClass.Kind in HullClass.all():
		var box := hull.get_aabb().size \
			* HullClass.num(kind, "hull_scale", "ship/hull_scale")
		widest = Vector2(maxf(widest.x, box.x), maxf(widest.y, box.y))
		_expect(portal_width > box.x * 1.5 and portal_height > box.y * 1.5,
			"a %s clears the portal aperture with margin, across and up"
				% HullClass.name_of(kind),
			"%.0f x %.0f opening against a %.1f x %.1f hull" % [
				portal_width, portal_height, box.x, box.y])
	# …and once through it, the lane it feeds has to leave that hull somewhere to be.
	# The lane is measured against the hull, so a ship whose half-section fills the
	# lane's is outside it wherever it sits.
	var cap := Tuning.num("exploration/lane_hull_clearance_cap")
	_expect(widest.x * 0.5 < lane_width * 0.5 * cap
			and widest.y * 0.5 < lane_height * 0.5 * cap,
		"…and the widest hull leaves itself room in the lane rather than filling it",
		"%.1f x %.1f hull in a %.0f x %.0f lane at a %.2f cap" % [
			widest.x, widest.y, lane_width, lane_height, cap])
	_expect(portal_width <= lane_width,
		"the portal is the ramp mouth, no wider than the road it feeds",
		"portal %.0f vs lane %.0f" % [portal_width, lane_width])
	_expect(is_zero_approx(Tuning.num("exploration/portal_entry_seconds")),
		"portal entry is instant — a local leg is 41 s and cannot afford ceremony",
		"%.1f s of entry sequence" % Tuning.num("exploration/portal_entry_seconds"))

	# The corridor has to hold both decks with room around them, or "the lane is
	# visually open" is not true and the tube has become a tunnel. The decks are side
	# by side, so the widest the road gets is ACROSS, not up.
	var span := Tuning.num("exploration/deck_separation") + lane_width
	_expect(Tuning.num("exploration/corridor_diameter") > span * 1.5,
		"the bounded corridor is bigger than the road laid inside it",
		"corridor %.0f against a %.0f m span" % [
			Tuning.num("exploration/corridor_diameter"), span])
	var disc_height := Tuning.num("exploration/system_ceiling_height") \
		+ Tuning.num("exploration/system_floor_depth")
	_expect(disc_height < Tuning.num("exploration/system_diameter"),
		"a system is a DISC: floor and ceiling closer than the diameter (ADR 0011)",
		"%.0f tall in a %.0f disc" % [disc_height,
			Tuning.num("exploration/system_diameter")])

	# The speed ladder's whole purpose is that the highway beats flying it yourself
	# by a lot at range and by little up close. If cruise ever stops beating a
	# fighter, the road has no reason to exist.
	_expect(Tuning.num("exploration/cruise_speed")
			> HullClass.max_speed(HullClass.Kind.FIGHTER) * 2.0,
		"cruise is at least twice the fastest hull, or the road buys nothing",
		"cruise %.1f vs fighter %.1f" % [Tuning.num("exploration/cruise_speed"),
			HullClass.max_speed(HullClass.Kind.FIGHTER)])

## The deep field: what is out there past the boundary, and why.
##
## The placement rule is the whole of it — everything is at least `near` metres
## OUTSIDE playable space — because the failure it prevents is a rock appearing inside
## a corridor the moment a leg length is nudged. `DeepField.scatter` is static so this
## can be checked directly; the node itself deliberately has no accessor that hands
## out a position, and nothing may add one (CLAUDE.md, LOD / collision).
func _test_deep_field() -> void:
	var disc := DiscRegion.new()
	disc.ceiling = 400.0
	disc.floor_depth = 750.0
	disc.radius = 1750.0
	disc.name_of = "SYSTEM A"
	var field := BoundaryField.new()
	field.regions = [disc]
	var spine := PackedVector3Array([Vector3(-1750.0, 0.0, 0.0),
		Vector3.ZERO, Vector3(1750.0, 0.0, 0.0)])
	var rng := RandomNumberGenerator.new()
	rng.seed = 1

	var near := 300.0
	var places := DeepField.scatter(rng, spine, field, 400, near, 4000.0, 1750.0)
	_expect(places.size() > 300,
		"the deep field places what it is asked for, near enough",
		"%d of 400 placed" % places.size())
	var intruder := 0
	for point: Vector3 in places:
		if field.overshoot(point) < near or field.overshoot(point) > 4000.0:
			intruder += 1
	_expect(intruder == 0,
		"…and every piece of it is OUTSIDE playable space, in its own layer's band",
		"%d of %d landed inside the system" % [intruder, places.size()])
	_expect(DeepField.scatter(rng, spine, field, 0, near, 4000.0, 1750.0).is_empty()
			and DeepField.scatter(rng, PackedVector3Array(), field, 10, near,
				4000.0, 1750.0).is_empty(),
		"…and a field with no route or no count is empty rather than at the origin",
		"something was placed anyway")

	# The three layers are three distances on purpose: motion is only legible against
	# things that are NOT all the same distance away. If the dust ever reaches out as
	# far as the bodies, the field collapses to one layer and the speed cue with it.
	_expect(Tuning.num("exploration/deep_dust_far")
			< Tuning.num("exploration/deep_bodies_far"),
		"the dust is nearer than the bodies — three layers, not one",
		"dust to %.0f m, bodies to %.0f m" % [
			Tuning.num("exploration/deep_dust_far"),
			Tuning.num("exploration/deep_bodies_far")])
	_expect(Tuning.num("exploration/starfield_distance")
			> Tuning.num("exploration/deep_bodies_far") * 1.2,
		"…and the stars are past the furthest of them, so they read as a sky",
		"stars at %.0f m, bodies out to %.0f m" % [
			Tuning.num("exploration/starfield_distance"),
			Tuning.num("exploration/deep_bodies_far")])


## The engagement-envelope meter. It is an instrument, so what is tested is that it
## reports the truth and that nothing about it depends on where the origin happens
## to be this frame (ADR 0020).
func _test_envelope_meter() -> void:
	var meter := EnvelopeMeter.new()

	meter.observe([] as Array[Vector3])
	_expect(is_zero_approx(meter.span) and meter.participants == 0,
		"an empty fight has no envelope", "span %.1f" % meter.span)
	meter.observe([Vector3.ZERO] as Array[Vector3])
	_expect(is_zero_approx(meter.span) and meter.participants == 1,
		"…and neither does one participant on its own — a span needs two",
		"span %.1f" % meter.span)

	# The span is the largest distance between ANY two participants, which on a
	# diagonal is not an axis extent. A bounding box would be cheaper and wrong.
	meter.observe([Vector3(-100.0, 0.0, 0.0), Vector3(100.0, 0.0, 0.0),
		Vector3(0.0, 40.0, 300.0)] as Array[Vector3])
	var diagonal := Vector3(-100.0, 0.0, 0.0).distance_to(Vector3(0.0, 40.0, 300.0))
	_expect(is_equal_approx(meter.current_span, diagonal),
		"the span is the longest pair, not the widest axis",
		"got %.1f, longest pair is %.1f" % [meter.current_span, diagonal])
	_expect(is_equal_approx(meter.current_vertical, 40.0),
		"…and the vertical figure is the up-axis spread alone, reported separately",
		"got %.1f" % meter.current_vertical)

	# A high-water mark: a fight that closes back up does not un-measure how far it
	# sprawled, because the disc has to hold the largest moment, not the last one.
	var widest := meter.span
	meter.observe([Vector3.ZERO, Vector3(1.0, 0.0, 0.0)] as Array[Vector3])
	_expect(is_equal_approx(meter.span, widest),
		"the record survives the fight closing back up",
		"record fell from %.1f to %.1f" % [widest, meter.span])
	_expect(meter.current_span < meter.span,
		"…while the live figure follows the fight down",
		"live %.1f, record %.1f" % [meter.current_span, meter.span])

	# Floating origin: the reading is of distances BETWEEN participants, so shifting
	# every participant by the same amount must change nothing. If this ever fails,
	# the envelope number has been silently measuring distance-from-origin.
	var shifted := EnvelopeMeter.new()
	var shift := Vector3(9000.0, -4000.0, 12000.0)
	var points: Array[Vector3] = [Vector3(-100.0, 0.0, 0.0), Vector3(100.0, 0.0, 0.0),
		Vector3(0.0, 40.0, 300.0)]
	var moved: Array[Vector3] = []
	for point in points:
		moved.append(point + shift)
	shifted.observe(moved)
	_expect(is_equal_approx(shifted.span, meter.span)
			and is_equal_approx(shifted.vertical, meter.vertical),
		"a floating-origin recentre does not move the envelope reading",
		"%.1f/%.1f against %.1f/%.1f" % [shifted.span, shifted.vertical,
			meter.span, meter.vertical])

	meter.reset()
	_expect(is_zero_approx(meter.span) and is_zero_approx(meter.vertical),
		"reset forgets the record", "span %.1f" % meter.span)

## The system boundary (ADR 0011, as amended by ADR 0062). The rules under test are
## the ones that make it a telegraph rather than a wall, the heading model that lets
## it stop the player without ever taking the stick, and the union that makes a
## corridor continuous with the systems at its ends.
func _test_disc_bounds() -> void:
	var disc := DiscRegion.new()
	disc.ceiling = 400.0
	disc.floor_depth = 750.0
	disc.radius = 1750.0
	disc.aperture_radius = 1100.0
	disc.apertures = [Vector3.RIGHT]
	disc.name_of = "SYSTEM A"

	var tube := TubeRegion.new()
	tube.span_between(Vector3(1750.0, 0.0, 0.0), Vector3(5750.0, 0.0, 0.0))
	tube.mouth_radius = 1100.0
	tube.radius = 875.0
	tube.flare_length = 800.0
	tube.name_of = "corridor"

	var field := BoundaryField.new()
	field.regions = [disc, tube]
	field.warning_band = 120.0
	field.stop_distance = 260.0

	# --- where the edges are ---
	_expect(is_zero_approx(field.overshoot(Vector3.ZERO)),
		"the centre of the combat plane is inside the disc", "it is not")
	_expect(is_equal_approx(field.overshoot(Vector3(0.0, 460.0, 0.0)), 60.0),
		"overshoot past the ceiling is measured from the face",
		"%.1f" % field.overshoot(Vector3(0.0, 460.0, 0.0)))
	_expect(is_equal_approx(field.overshoot(Vector3(0.0, -800.0, 0.0)), 50.0),
		"…and past the floor, which sits deeper because the planet is under it",
		"%.1f" % field.overshoot(Vector3(0.0, -800.0, 0.0)))

	# ADR 0062: the rim IS a boundary now. ADR 0011 left it open because lateral exit
	# WAS departure; roads made that untrue, and an open rim leads to unrendered space.
	_expect(is_equal_approx(field.overshoot(Vector3(0.0, 0.0, 1850.0)), 100.0),
		"the RIM is a boundary too — flying laterally out is no longer free",
		"%.1f m past" % field.overshoot(Vector3(0.0, 0.0, 1850.0)))
	_expect(is_zero_approx(field.overshoot(Vector3(0.0, 0.0, 1700.0))),
		"…and just inside it is still clear", "already outside")
	_expect(field.label(Vector3.ZERO) == "SYSTEM A",
		"…and the field can say which piece of the map you are in",
		field.label(Vector3.ZERO))

	# --- the aperture, and the corridor that is the same shape ---
	_expect(disc.aperture_at(Vector3(1740.0, 0.0, 0.0)) == 0,
		"the rim OPENS on the aperture's bearing", "the opening was not found")
	_expect(disc.aperture_at(Vector3(-1740.0, 0.0, 0.0)) < 0
			and field.overshoot(Vector3(-1850.0, 0.0, 0.0)) > 0.0,
		"…and the OPPOSITE bearing is closed — one opening, not a symmetric pair",
		"the far side is open too")
	# The hole is a hole in the WALL, not a tunnel through space. Past the rim there
	# is no hole to be in, and what is out there belongs to the corridor. Without
	# this the disc reports itself unbounded along its own bearing, and a kilometre
	# past the rim still reads as "in SYSTEM A".
	_expect(disc.aperture_at(Vector3(3000.0, 0.0, 0.0)) < 0,
		"…and past the rim there is no opening to be in — a hole is not a tunnel",
		"the disc claimed space a kilometre outside itself")
	# The opening is ANGULAR, measured where the bearing cuts the wall. Using the
	# point's own distance from the axis instead widens the hole for anything deep
	# inside the disc, which is where it matters least and is wrong most.
	var off_bearing := Vector3(600.0, 0.0, 1500.0)
	_expect(disc.aperture_at(off_bearing) < 0,
		"…and the opening is angular: 68 deg off the bearing is wall, not hole",
		"a point 68 deg round the rim read as the opening")
	_expect(tube.profile(0.0) > tube.profile(tube.flare_length),
		"the corridor FLARES at its mouth: wide at the rim, corridor-sized after",
		"%.0f m at the mouth, %.0f m along" % [
			tube.profile(0.0), tube.profile(tube.flare_length)])
	_expect(is_equal_approx(tube.profile(tube.length() * 0.5), tube.radius),
		"…and is the corridor down the middle", "%.1f" % tube.profile(
			tube.length() * 0.5))
	_expect(is_equal_approx(tube.profile(tube.length()), tube.mouth_radius),
		"…and flares again at the far end, so arriving opens out too",
		"%.1f" % tube.profile(tube.length()))
	# Past the rim the disc's faces stop applying: a ceiling 400 m up has nothing to
	# say about a corridor 1750 m across, and leaving a flat system for a round tube
	# should open out rather than pinch.
	_expect(is_zero_approx(field.overshoot(Vector3(2000.0, 600.0, 0.0))),
		"inside the corridor the disc's ceiling no longer applies — the tube is taller",
		"%.1f m past" % field.overshoot(Vector3(2000.0, 600.0, 0.0)))
	_expect(field.label(Vector3(3500.0, 0.0, 0.0)) == "corridor",
		"…and the corridor is what governs out there",
		field.label(Vector3(3500.0, 0.0, 0.0)))

	# --- the union, which is where the seams would be ---
	# Playable space is the disc PLUS the corridor, so flying out through the mouth
	# must be continuous: no step at the rim plane, and above all no red glow while
	# passing through the middle of the opening.
	_expect(is_zero_approx(field.warning(Vector3(1700.0, 0.0, 0.0))),
		"no red while flying up the middle of the aperture — the rim is not there",
		"%.2f warning 50 m short of the rim plane" % field.warning(
			Vector3(1700.0, 0.0, 0.0)))
	_expect(field.warning(Vector3(0.0, 0.0, 1700.0)) > 0.0,
		"…while the same distance from the CLOSED rim does warn",
		"%.2f" % field.warning(Vector3(0.0, 0.0, 1700.0)))
	# A tube has NO END CAPS. A cap is a wall reported where two regions merely meet,
	# and it would paint the far end of a legal four-kilometre route red.
	_expect(is_zero_approx(field.warning(Vector3(5600.0, 0.0, 0.0))),
		"…and no red at the far mouth either — regions meet, they do not wall",
		"%.2f 150 m short of the far rim" % field.warning(Vector3(5600.0, 0.0, 0.0)))
	_expect(not tube.applies_to(Vector3(1000.0, 0.0, 0.0)),
		"the tube declares itself INAPPLICABLE behind its own mouth, rather than capped",
		"it answered for a point inside the disc")
	# Drifting wide in the corridor is caught by the tube wall, and the way back is
	# toward the axis — not backward into the disc, which is the answer a rim-only
	# model gives and it points the player the wrong way.
	var wide := Vector3(3500.0, 0.0, 915.0)
	_expect(field.overshoot(wide) > 0.0 and field.overshoot(wide) < 100.0,
		"drifting wide in the corridor is outside — by the TUBE's margin, not the rim's",
		"%.1f m past" % field.overshoot(wide))
	_expect(absf(field.outward(wide).z) > 0.9,
		"…and the way back in is sideways toward the axis, not back down the corridor",
		"outward (%.2f, %.2f, %.2f)" % [field.outward(wide).x,
			field.outward(wide).y, field.outward(wide).z])

	# --- the telegraph ---
	# It reaches full BEFORE anything happens to the player. That ordering is the
	# whole of the Bannerlord treatment, and it is why this is not a punishment.
	_expect(is_zero_approx(field.warning(Vector3.ZERO)),
		"no warning in the middle of the disc", "%.2f" % field.warning(Vector3.ZERO))
	_expect(field.warning(Vector3(0.0, disc.ceiling - 60.0, 0.0)) > 0.4,
		"the red is well up before the ceiling is reached",
		"%.2f" % field.warning(Vector3(0.0, disc.ceiling - 60.0, 0.0)))
	_expect(is_equal_approx(field.warning(Vector3(0.0, disc.ceiling, 0.0)), 1.0),
		"…and is full AT the face, while nothing has been taken yet",
		"%.2f" % field.warning(Vector3(0.0, disc.ceiling, 0.0)))
	_expect(is_equal_approx(field.warning(Vector3(0.0, 9999.0, 0.0)), 1.0),
		"…and does not exceed full past it",
		"%.2f" % field.warning(Vector3(0.0, 9999.0, 0.0)))
	# The warning band is metres INSIDE the edge and does nothing but paint. The two
	# distances used to be one, and conflating them is the easy mistake here.
	_expect(is_equal_approx(field.speed_ceiling_scale(
			Vector3(0.0, disc.ceiling - 10.0, 0.0), Vector3.UP), 1.0),
		"the warning band is TELEGRAPH ONLY — nothing is clamped inside the edge",
		"clamped while still inside")

	# --- the clamp: magnitude, never direction, and heading-proportional ---
	# THE invariant, and it is structural: the function returns a scale and never
	# sees a heading it could return.
	var above := Vector3(0.0, disc.ceiling + field.stop_distance * 0.5, 0.0)
	_expect(field.speed_ceiling_scale(above, Vector3.UP) < 1.0,
		"pushing further out past a face scales the speed LIMIT down",
		"no strain applied")
	_expect(is_equal_approx(field.speed_ceiling_scale(above, Vector3.DOWN), 1.0),
		"…and flying BACK IN is never taxed, at any depth — the way home stays free",
		"the way home was clamped")
	# cos²(t/2): 1 straight out, 0.5 tangential, 0 straight back in. Tangential is
	# SLOWED but not stopped — this is the correction to the first model, which made
	# anything not-straight-out free.
	_expect(is_equal_approx(BoundaryField.outbound_fraction(
			Vector3.UP, Vector3.UP), 1.0)
			and is_equal_approx(BoundaryField.outbound_fraction(
				Vector3.RIGHT, Vector3.UP), 0.5)
			and is_zero_approx(BoundaryField.outbound_fraction(
				Vector3.DOWN, Vector3.UP)),
		"the heading term is cos²(t/2): 1 out, 0.5 ALONG the edge, 0 back in",
		"out %.2f, along %.2f, back %.2f" % [
			BoundaryField.outbound_fraction(Vector3.UP, Vector3.UP),
			BoundaryField.outbound_fraction(Vector3.RIGHT, Vector3.UP),
			BoundaryField.outbound_fraction(Vector3.DOWN, Vector3.UP)])
	var sideways := field.speed_ceiling_scale(above, Vector3.BACK)
	_expect(sideways < 1.0 and sideways > field.speed_ceiling_scale(above, Vector3.UP),
		"…so flying ALONG the edge is slowed, but less than flying out of it",
		"%.2f along vs %.2f out" % [
			sideways, field.speed_ceiling_scale(above, Vector3.UP)])
	# And it reaches zero. A ship that keeps pushing outward is brought to a halt and
	# has to turn; the boundary stops it by making outward cost everything.
	var far_out := Vector3(0.0, disc.ceiling + field.stop_distance, 0.0)
	_expect(is_zero_approx(field.speed_ceiling_scale(far_out, Vector3.UP)),
		"a full stop_distance out, straight outbound is STOPPED — not merely slowed",
		"%.2f" % field.speed_ceiling_scale(far_out, Vector3.UP))
	_expect(is_equal_approx(field.speed_ceiling_scale(far_out, Vector3.DOWN), 1.0),
		"…and at that same point, turning round restores full speed immediately",
		"%.2f" % field.speed_ceiling_scale(far_out, Vector3.DOWN))
	_expect(is_equal_approx(field.speed_ceiling_scale(
			Vector3(0.0, 8000.0, 0.0), Vector3.UP), 0.0),
		"…and no further than that: the clamp bottoms out rather than going negative",
		"%.2f" % field.speed_ceiling_scale(Vector3(0.0, 8000.0, 0.0), Vector3.UP))

	# --- the corner, which is arithmetic rather than a case ---
	# Past both the ceiling and the rim, the combined outward normal is the diagonal,
	# so down-and-inward is free and up-and-out is stopped. Nothing is written for it.
	var corner := Vector3(0.0, disc.ceiling + 80.0, disc.radius + 80.0)
	var out_dir := field.outward(corner)
	_expect(out_dir.y > 0.3 and out_dir.z > 0.3,
		"at a ceiling-and-rim corner the outward normal is the DIAGONAL",
		"(%.2f, %.2f, %.2f)" % [out_dir.x, out_dir.y, out_dir.z])
	_expect(field.speed_ceiling_scale(corner, -out_dir) > \
			field.speed_ceiling_scale(corner, Vector3.UP),
		"…so the way back in from a corner is the cheapest heading there",
		"straight up was no worse than the diagonal")
	_expect(field.constraints(corner).size() == 3,
		"…and it is three constraints, not a corner case", "%d constraints" %
			field.constraints(corner).size())

	# --- regions carry their own placement ---
	# The map is a list of regions, not a hierarchy, so a system a kilometre away has
	# to answer about its own space and no one else's.
	var far_disc := DiscRegion.new()
	far_disc.center = Vector3(5750.0 + 1750.0, 0.0, 0.0)
	far_disc.ceiling = 400.0
	far_disc.floor_depth = 750.0
	far_disc.radius = 1750.0
	far_disc.name_of = "SYSTEM B"
	field.regions = [disc, tube, far_disc]
	_expect(field.label(far_disc.center) == "SYSTEM B",
		"a second system placed down the corridor answers for its own space",
		field.label(far_disc.center))
	_expect(is_zero_approx(field.overshoot(far_disc.center))
			and is_zero_approx(field.overshoot(Vector3.ZERO)),
		"…and both systems are in bounds at once — the map is a UNION, not a mode",
		"one of them reported outside")
	_expect(is_zero_approx(field.overshoot(Vector3(4000.0, 0.0, 0.0))),
		"…with the corridor between them in bounds all the way across",
		"%.1f m past, mid-corridor" % field.overshoot(Vector3(4000.0, 0.0, 0.0)))
	field.regions = [disc, tube]

	# Damage is the LAST stage and starts only after the grace the player watched
	# run down. A brief tactical dip has to cost nothing (ADR 0011).
	_expect(is_zero_approx(BoundaryField.damage_per_second(3.9, 4.0, 6.0, 12.0)),
		"a dip shorter than the grace costs nothing",
		"%.2f hp/s" % BoundaryField.damage_per_second(3.9, 4.0, 6.0, 12.0))
	_expect(BoundaryField.damage_per_second(7.0, 4.0, 6.0, 12.0) > 0.0
			and BoundaryField.damage_per_second(7.0, 4.0, 6.0, 12.0) < 12.0,
		"…then damage begins and RAMPS rather than arriving at full rate",
		"%.2f hp/s" % BoundaryField.damage_per_second(7.0, 4.0, 6.0, 12.0))
	_expect(is_equal_approx(BoundaryField.damage_per_second(99.0, 4.0, 6.0, 12.0), 12.0),
		"…reaching the full rate, so camping out there does not work",
		"%.2f hp/s" % BoundaryField.damage_per_second(99.0, 4.0, 6.0, 12.0))

	# The corridor only funnels if its mouth is wider than what it feeds. Tuned
	# values, not the fixture's — the two keys are independent and inverting them
	# silently turns the guide into a pinch.
	_expect(Tuning.num("exploration/aperture_mouth_diameter")
			> Tuning.num("exploration/corridor_diameter"),
		"the tuned aperture mouth is WIDER than the corridor it feeds",
		"%.0f m mouth vs %.0f m corridor" % [
			Tuning.num("exploration/aperture_mouth_diameter"),
			Tuning.num("exploration/corridor_diameter")])
	_expect(Tuning.num("exploration/aperture_mouth_diameter")
			< Tuning.num("exploration/system_diameter"),
		"…and narrower than the disc, so there is a rim left to be a boundary",
		"%.0f m mouth in a %.0f m disc" % [
			Tuning.num("exploration/aperture_mouth_diameter"),
			Tuning.num("exploration/system_diameter")])
	# Two flares have to fit in the shortest leg, or the corridor is all mouth and
	# never reaches its own width.
	_expect(Tuning.num("exploration/aperture_funnel_length") * 2.0
			< Tuning.num("exploration/local_leg_length"),
		"…and the two flares fit inside the shortest leg with corridor left between",
		"%.0f m of flare in a %.0f m leg" % [
			Tuning.num("exploration/aperture_funnel_length") * 2.0,
			Tuning.num("exploration/local_leg_length")])

	# ADR 0061: the floor goes UNDER the planet, never between the player and it.
	var surface := Tuning.num("exploration/planet_radius") \
		- Tuning.num("exploration/planet_center_depth")
	var planet_bottom := -Tuning.num("exploration/planet_center_depth") \
		- Tuning.num("exploration/planet_radius")
	_expect(planet_bottom > -Tuning.num("exploration/system_floor_depth"),
		"the disc's hard floor sits below the whole planet",
		"planet reaches %.0f, floor is at %.0f" % [planet_bottom,
			-Tuning.num("exploration/system_floor_depth")])
	_expect(surface < 0.0,
		"…and the planet's surface is below the combat plane, not in it (ADR 0061)",
		"surface at %+.0f" % surface)


## The road (POC step 6): the lane, the portals, and the two carriageways. What is
## under test is that the highway is a PLACE rather than a travel mode — every
## property ADR 0057 asks a review to check is checkable here.
##
## There is no deck-convention test any more. Traffic runs on the right and each deck
## sits on its own right, so which side a deck is on is a consequence of which way it
## goes rather than a rule to be declared and checked against a heading (ADR 0077).
func _test_the_road() -> void:
	# --- the lane's cross-section ---
	var lane := CruiseLane.new()
	lane.axis = Vector3.RIGHT
	lane.right = Vector3.BACK
	lane.up = Vector3.UP
	lane.half_width = 75.0
	lane.half_height = 50.0
	lane.roundness = 4.0
	lane.edge_softness = 10.0
	lane.base_speed = 96.7
	lane.edge_speed_penalty = 0.45
	lane.push_accel = 8.0

	_expect(lane.edge_distance() < 0.0 and not lane.is_outside(),
		"the centre of the lane is in the lane",
		"%.1f m past" % lane.edge_distance())
	lane.lateral = 74.0
	_expect(not lane.is_outside(),
		"…and so is just inside the near edge", "%.1f" % lane.edge_distance())
	lane.lateral = 80.0
	_expect(lane.is_outside() and is_equal_approx(lane.edge_distance(), 5.0),
		"…and 5 m past it is 5 m past it", "%.2f" % lane.edge_distance())
	# The cross-section is a rounded lozenge so no edge is dramatically nearer than
	# another. At the corner a plain rectangle would still be inside and an ellipse
	# would be well outside; the lozenge sits between them, and the DRAWN ribs use
	# this same curve so the picture and the rule are one shape.
	lane.lateral = 75.0 * 0.9
	lane.vertical = 50.0 * 0.9
	_expect(lane.is_outside(),
		"the corner of the lane is outside it — the section is a lozenge, not a box",
		"%.2f m past at 90%% of both extents" % lane.edge_distance())
	lane.lateral = 75.0 * 0.7
	lane.vertical = 50.0 * 0.7
	_expect(not lane.is_outside(),
		"…but not as far in as an ellipse would put it — nor a rounded diamond",
		"%.2f m past at 70%% of both" % lane.edge_distance())

	# --- the soft boundary: an incentive, never a wall (ADR 0064) ---
	lane.vertical = 0.0
	lane.lateral = 0.0
	_expect(is_equal_approx(lane.top_speed(), lane.base_speed)
			and lane.push() == Vector3.ZERO,
		"in the lane there is no penalty and no push at all",
		"%.1f m/s, push %.1f" % [lane.top_speed(), lane.push().length()])
	lane.lateral = 90.0
	_expect(lane.top_speed() < lane.base_speed
			and lane.top_speed() > lane.base_speed * 0.4,
		"out of the lane the cruise drive is slower — an incentive to hold a line",
		"%.1f m/s of %.1f" % [lane.top_speed(), lane.base_speed])
	# THE invariant of the lane: it must never be able to stop the player. If it can,
	# it is a wall, and a wall on a road is the conveyor this design rejects.
	lane.lateral = 100000.0
	_expect(lane.top_speed() >= lane.base_speed * clampf(
			Tuning.num("exploration/lane_edge_speed_penalty"), 0.05, 1.0) - 0.001,
		"…and no slower than the penalty, however far out — the lane cannot STOP you",
		"%.1f m/s" % lane.top_speed())
	_expect(lane.top_speed() > Tuning.num("exploration/taxi_max_speed"),
		"…in fact still faster than flying the leg by hand, which is why it is soft",
		"%.1f m/s out of lane vs %.1f by hand" % [lane.top_speed(),
			Tuning.num("exploration/taxi_max_speed")])
	lane.lateral = 90.0
	var nudge := lane.push()
	_expect(nudge.length() > 0.0 and nudge.dot(Vector3.BACK) < 0.0,
		"…and the push is back toward the centre-line, not along the road",
		"(%.1f, %.1f, %.1f)" % [nudge.x, nudge.y, nudge.z])
	_expect(is_zero_approx(nudge.dot(lane.axis)),
		"…with nothing along the axis: the road corrects your LINE, never your speed",
		"%.3f m/s along the road" % nudge.dot(lane.axis))
	lane.lateral = 200.0
	_expect(lane.push().length() > nudge.length(),
		"…and it grows with depth, so it is felt as a slope rather than as a wall",
		"%.1f then %.1f" % [nudge.length(), lane.push().length()])
	# EASED IN, and this is the fix for a shudder rather than a nicety. `sqrt` has an
	# infinite slope at zero, so the bare closed form arrived at full strength on the
	# frame the edge was crossed, shoved the ship back inside, vanished — it is a
	# function of position — and let it drift out again. A slope is what was promised;
	# a limit cycle at the rail is what a big hull got.
	lane.lateral = lane.half_width + 0.05
	var toe := lane.push().length()
	lane.lateral = lane.half_width + lane.edge_softness
	_expect(toe < lane.push().length() * 0.05,
		"…and it eases IN from nothing at the edge, rather than arriving at full",
		"%.2f m/s a hair past the rail against %.2f m/s a softness past it" % [
			toe, lane.push().length()])

	# --- a ceiling that drops does not drop the ship with it (ADR 0071) ---
	# This is the stutter the human flew into: cross the rail at cruise and the lane
	# halves the drive's ceiling, and with nothing pacing the fall the ship lost eighty
	# metres a second in ONE FRAME, got pushed back in, got it all back, and drifted
	# out again. A limit cycle at the rail, which reads as being skipped forward.
	var frame_time := 1.0 / 60.0
	var braked := Mothership.brake_limited(160.0, 72.0, 160.0, 2.4, frame_time)
	_expect(braked > 158.0,
		"a ceiling that halves in one frame takes the ship's own brakes to follow",
		"%.1f m/s after one frame of a 160 to 72 drop" % braked)
	var settle := 160.0
	var frames := 0
	while settle > 72.5 and frames < 600:
		settle = Mothership.brake_limited(settle, 72.0, 160.0, 2.4, frame_time)
		frames += 1
	_expect(frames > 30 and frames < 240,
		"…and gets there in about the seconds its brakes are tuned for, not instantly",
		"%.2f s to fall from 160 to 72" % (float(frames) * frame_time))
	# Going UP is not limited. Acceleration is already paced by the throttle lever's
	# own travel, and pacing it twice would make the lever slower than it is tuned to
	# be — which is a feel change smuggled in behind a bug fix.
	_expect(is_equal_approx(
			Mothership.brake_limited(10.0, 160.0, 160.0, 2.4, frame_time), 160.0),
		"…while gaining speed is untouched: the throttle already paces that",
		"acceleration was limited too")
	# A throttle simply released already falls at exactly this rate, so the guard has
	# nothing to say about it. If it did, every hull would brake slower than tuned.
	var released := Mothership.brake_limited(160.0, 160.0 - 160.0 / 2.4 * frame_time,
		160.0, 2.4, frame_time)
	_expect(is_equal_approx(released, 160.0 - 160.0 / 2.4 * frame_time),
		"…and a released throttle is a no-op for it, at exactly the tuned rate",
		"%.3f m/s" % released)

	# --- the lane is measured against the HULL, not against a point ---
	# A capital is 76 m across. A lane that only notices the ship's centre lets most
	# of it hang through the rails before anything reports it, which is what the human
	# flew into. Clearance shrinks the band the CENTRE may occupy; the drawn lane is
	# unchanged, exactly as a road's markings do not move for a wide lorry.
	var wide := CruiseLane.new()
	wide.right = Vector3.BACK
	wide.up = Vector3.UP
	wide.half_width = 120.0
	wide.half_height = 75.0
	wide.roundness = 4.0
	wide.edge_softness = 10.0
	wide.clearance_cap = 0.5
	wide.lateral = 90.0
	_expect(not wide.is_outside(),
		"a point-sized ship 90 m off a 120 m half-lane is still in its lane",
		"%.1f m past" % wide.edge_distance())
	wide.clearance = Vector2(38.0, 21.0)
	_expect(wide.is_outside(),
		"…and a 76 m hull in the same place is not, because its side is through the rail",
		"%.1f m past" % wide.edge_distance())
	wide.lateral = 0.0
	wide.vertical = 0.0
	_expect(not wide.is_outside() and wide.push() == Vector3.ZERO,
		"…while down the middle it is still in its lane and unpushed",
		"%.1f m past" % wide.edge_distance())
	# A hull that is too big for the road still has to be able to FLY it. Without the
	# cap it would be handed a lane of zero width, be outside wherever it sat, and be
	# pushed and slowed for existing.
	wide.clearance = Vector2(1000.0, 1000.0)
	_expect(wide.usable_extents().x > 0.0 and wide.usable_extents().y > 0.0
			and not wide.is_outside(),
		"…and an absurd hull is left a lane rather than being outside its own road",
		"%.1f x %.1f of usable lane" % [wide.usable_extents().x,
			wide.usable_extents().y])
	_expect(is_equal_approx(wide.usable_extents().x, 120.0 * 0.5),
		"…capped at the tuned share of the section, and no further",
		"%.1f m of a 120 m half-lane left" % wide.usable_extents().x)
	_expect(lane.push().length() < lane.base_speed,
		"…but never overpowers the drive itself", "%.1f m/s of push against %.1f" % [
			lane.push().length(), lane.base_speed])

	# --- ADR 0057: entry is on contact and instant ---
	_expect(is_zero_approx(Tuning.num("exploration/portal_entry_seconds")),
		"portal entry has no sequence — at a 41 s leg, ceremony is a loading screen",
		"%.2f s of entry" % Tuning.num("exploration/portal_entry_seconds"))
	_expect(Tuning.num("exploration/portal_width")
			< Tuning.num("exploration/lane_width")
			and Tuning.num("exploration/portal_height")
				< Tuning.num("exploration/lane_height"),
		"the portal is NARROWER than the lane it feeds — an on-ramp, not a gate",
		"%.0f x %.0f opening into a %.0f x %.0f lane" % [
			Tuning.num("exploration/portal_width"),
			Tuning.num("exploration/portal_height"),
			Tuning.num("exploration/lane_width"),
			Tuning.num("exploration/lane_height")])
	# The road only pays if it beats flying the leg. This is the ratio the third
	# checkpoint is about, and it is arithmetic rather than opinion.
	_expect(Tuning.num("exploration/cruise_speed")
			> Tuning.num("exploration/fighter_max_speed"),
		"cruise outruns the fastest hull, so the road is worth the detour to it",
		"%.1f m/s cruise vs %.1f fighter" % [Tuning.num("exploration/cruise_speed"),
			Tuning.num("exploration/fighter_max_speed")])
	# The decks sit side by side and must not intersect, or the lanes stop being
	# separate and "no oncoming traffic in your lane" quietly stops being structural.
	_expect(Tuning.num("exploration/deck_separation")
			>= Tuning.num("exploration/lane_width"),
		"the two decks run clear of each other — one-way lanes stay separate",
		"%.0f m apart for %.0f m of lane" % [
			Tuning.num("exploration/deck_separation"),
			Tuning.num("exploration/lane_width")])


## The exploration scene builds its nodes. Same gate the arena and sandbox get: a
## scene that is constructed in code has no editor to catch a missing child.
## One frame of the exploration scene, the way the engine runs it: the scene's
## `_process` and then the ship's, in tree order.
##
## The tests step by hand rather than awaiting real frames, because a three-second
## drive spool is 180 of them and awaiting those would make the gate wait three real
## seconds for a number it can reach instantly. Stepping only the scene was a quiet
## lie about what a frame is — anything living in `Mothership._process` never ran.
func _step_exploration(scene: ExplorationScene, delta: float) -> void:
	scene._process(delta)
	scene.ship()._process(delta)


func _test_exploration_builds() -> void:
	var packed := load("res://scenes/exploration.tscn") as PackedScene
	_expect(packed != null, "exploration.tscn loads", "scene failed to load")
	if packed == null:
		return
	var scene := packed.instantiate() as ExplorationScene
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame

	for path in ["WorldEnvironment", "KeyLight", "FillLight", "SystemRoot",
			"SystemRoot/SystemMap",
			"SystemRoot/SystemMap/DiscA", "SystemRoot/SystemMap/DiscA/Ceiling",
			"SystemRoot/SystemMap/DiscA/Floor", "SystemRoot/SystemMap/DiscA/Rim",
			"SystemRoot/SystemMap/DiscA/SystemMarkers",
			"SystemRoot/SystemMap/PlanetA", "SystemRoot/SystemMap/PlanetA/Body",
			"SystemRoot/SystemMap/ApproachA",
			"SystemRoot/SystemMap/DiscB", "SystemRoot/SystemMap/DiscB/Rim",
			"SystemRoot/SystemMap/PlanetB", "SystemRoot/SystemMap/PlanetB/Body",
			"SystemRoot/SystemMap/ApproachB",
			"SystemRoot/SystemMap/LinkAB", "SystemRoot/SystemMap/LinkAB/Wall",
			"SystemRoot/SystemMap/LinkAB/LinkMarkers",
			"SystemRoot/SystemMap/DiscC", "SystemRoot/SystemMap/PlanetC",
			"SystemRoot/SystemMap/LinkBC",
			"SystemRoot/SystemMap/Road",
			"SystemRoot/SystemMap/Road/A377BMainlineForward",
			"SystemRoot/SystemMap/Road/A377BMainlineReverse",
			"SystemRoot/SystemMap/Road/A377BRampOnAForward",
			"SystemRoot/SystemMap/Road/A377BRampOffBForward",
			"SystemRoot/SystemMap/Road/A377BRampOnBReverse",
			"SystemRoot/Ship", "ChaseCamera", "DebugHud"]:
		_expect(scene.get_node_or_null(path) != null,
			"exploration builds " + path, "missing")

	var map := scene.map()
	var field := map.field()
	# FIVE SYSTEMS ON TWO CROSSING HIGHWAYS. A-377B runs A, B, C; K-112 runs D, B, E
	# across it. B is on both, which is what makes it an interchange rather than a
	# place two roads happen to pass (ADR 0085).
	_expect(map.systems().size() == 5 and map.links().size() == 4,
		"the map is five systems on two crossing highways, and a corridor per leg",
		"%d systems, %d links" % [map.systems().size(), map.links().size()])
	# EVERY LEG A DIFFERENT LENGTH, on purpose. Legs that are all the same make a
	# grid, and a grid makes system-to-system transport a distance rather than a
	# decision — the human's reading of the first build's short A-B and long B-C.
	var seen_lengths := {}
	for key: String in SystemMap.LEG_KEYS:
		seen_lengths[Tuning.num(key)] = true
	_expect(seen_lengths.size() == SystemMap.LEG_KEYS.size(),
		"…and no two legs are the same length, so the map is not a grid",
		"%d distinct lengths across %d legs" % [seen_lengths.size(),
			SystemMap.LEG_KEYS.size()])
	_expect(map.marker_count() > 0,
		"the whole map is filled with reference markers, corridor included",
		"%d markers" % map.marker_count())
	_expect(map.links()[0].marker_count() > 0,
		"…and the CORRIDOR has its own: 4 km of empty tube reads as a still image",
		"%d in the corridor" % map.links()[0].marker_count())

	# The drawn rim and the enforced rim have to be the same thing, or the player
	# learns to distrust the picture. The hole is a hole in the mesh, not a decal.
	var rim := scene.get_node_or_null(
		"SystemRoot/SystemMap/DiscA/Rim") as MeshInstance3D
	if rim != null and rim.mesh != null:
		var rim_verts: PackedVector3Array = rim.mesh.surface_get_arrays(0)[
			Mesh.ARRAY_VERTEX]
		var drawn := rim_verts.size() / 6
		_expect(drawn > 0 and drawn < SystemDisc.RIM_SEGMENTS,
			"the rim is drawn with an actual HOLE in it where the aperture is",
			"%d of %d segments drawn" % [drawn, SystemDisc.RIM_SEGMENTS])

	# A LINE, not a ring: the end systems have one aperture each, and it is the one
	# the leg actually attaches to. An aperture facing nowhere is a hole in the
	# boundary with unrendered space behind it.
	var discs := map.systems()
	_expect(discs[0].aperture_count() == 1
			and discs[discs.size() - 1].aperture_count() == 1,
		"each END system opens its rim exactly once — a line, not a ring",
		"%d and %d apertures" % [discs[0].aperture_count(),
			discs[discs.size() - 1].aperture_count()])
	# B is on BOTH highways, so it opens four times: a mouth each way along each road
	# through it. That is what makes it an interchange rather than a place two roads
	# happen to pass (ADR 0085).
	_expect(discs[1].aperture_count() == 4,
		"…and the one both roads pass through opens four times, twice per road",
		"%d apertures" % discs[1].aperture_count())
	_expect(discs[2].aperture_count() == 1 and discs[3].aperture_count() == 1,
		"…while a system on one road opens once at each end of it",
		"%d and %d apertures" % [discs[2].aperture_count(),
			discs[3].aperture_count()])
	var link := map.links()[0]
	_expect(link.region().from().distance_to(discs[0].aperture_mouth(0)) < 1.0
			and link.region().to().distance_to(discs[1].aperture_mouth(0)) < 1.0,
		"…and the corridor attaches to those two mouths, not near them",
		"%.1f m and %.1f m off" % [
			link.region().from().distance_to(discs[0].aperture_mouth(0)),
			link.region().to().distance_to(discs[1].aperture_mouth(0))])
	# Legs are measured PORTAL TO PORTAL (an amendment to the POC doc), so this is
	# the number the highway has to beat and it must be the tuned one, not the
	# centre-to-centre distance that would be easy to conflate it with.
	#
	# The tuned number is the STRAIGHT LINE between the mouths. A leg weaves now, so
	# what you actually fly is a little longer than what you tuned — which is the
	# honest reading and the reason both are checked here rather than one.
	_expect(absf(link.region().from().distance_to(link.region().to())
			- Tuning.num("exploration/local_leg_length")) < 1.0,
		"the leg is the tuned length MOUTH TO MOUTH, not centre to centre",
		"%.0f m of a tuned %.0f" % [link.length(),
			Tuning.num("exploration/local_leg_length")])
	_expect(link.length() > Tuning.num("exploration/local_leg_length")
			and link.length() < Tuning.num("exploration/local_leg_length") * 1.2,
		"…and flying it is a little further than that, because the leg curves",
		"%.0f m of road across a %.0f m gap" % [link.length(),
			Tuning.num("exploration/local_leg_length")])
	_expect(absf(discs[0].position.distance_to(discs[1].position)
			- (Tuning.num("exploration/local_leg_length")
				+ Tuning.num("exploration/system_diameter"))) < 1.0,
		"…so centre to centre is the leg plus one system radius at each end",
		"%.0f m apart" % discs[0].position.distance_to(discs[1].position))
	_expect(absf(map.links()[1].region().from().distance_to(
				map.links()[1].region().to())
			- Tuning.num("exploration/trunk_leg_length")) < 1.0,
		"…and the trunk leg is its own tuned length, an order up from the local one",
		"%.0f m of a tuned %.0f" % [map.links()[1].length(),
			Tuning.num("exploration/trunk_leg_length")])

	# You can fly from one to the other without leaving the map. This is the whole of
	# step 5 as one assertion: if any point along the route is out of bounds, the
	# control condition cannot be flown and success criterion 2 is untestable.
	var route_ok := true
	var worst := 0.0
	for i in 81:
		var t := float(i) / 80.0
		var point := discs[0].position.lerp(discs[1].position, t)
		worst = maxf(worst, field.overshoot(point))
		if field.overshoot(point) > 0.0:
			route_ok = false
	_expect(route_ok,
		"the whole route from A to B is in bounds — the leg can actually be flown",
		"worst point is %.1f m outside" % worst)
	# And the corridor is not a second way of saying "the disc". Halfway along, the
	# governing region has to be the tube.
	# ALONG the corridor rather than between its mouths: a leg weaves now, and the
	# straight-line midpoint of a curved leg is not on it.
	var midpoint := link.region().path.point_at(link.region().length() * 0.5)
	_expect(map.place_of(midpoint) == link.region().name_of,
		"…and halfway along it, the CORRIDOR is what governs, not either system",
		map.place_of(midpoint))
	_expect(map.place_of(discs[1].position) == SystemMap.NAMES[1],
		"…while the far end is system B, which the HUD can therefore name",
		map.place_of(discs[1].position))

	# The ship has to start somewhere it can actually be. A closed rim plus a start
	# position derived from the radius is exactly the pair that could silently put
	# the player outside their own system.
	_expect(is_zero_approx(field.overshoot(map.to_local(
			scene.ship().global_position))),
		"the ship starts INSIDE the bounded volume, not on the wrong side of the rim",
		"%.1f m past" % field.overshoot(map.to_local(scene.ship().global_position)))
	_expect(map.place_of(map.to_local(scene.ship().global_position))
			== SystemMap.NAMES[0],
		"…and it starts in system A, with the crossing still ahead of it",
		map.place_of(map.to_local(scene.ship().global_position)))

	# The player owns the helm and keeps it. There is no other station here, so the
	# autopilot — which is what happens when nobody is flying — must never run.
	_expect(not scene.ship().autopilot and scene.ship().piloted,
		"the player is at the helm and stays there — no roster in this scene",
		"autopilot %s, piloted %s" % [scene.ship().autopilot, scene.ship().piloted])
	_expect(scene.ship().position.y < discs[0].ceiling_height()
			and scene.ship().position.y > -discs[0].floor_depth(),
		"…and starts inside the disc", "y %.1f" % scene.ship().position.y)
	# Every system gets a planet, each below its OWN combat plane. A planet that
	# derived its depth from the world rather than its system would sit correctly at
	# A and be buried at B, which is a bug that only shows up after a four-minute flight.
	for i in map.planets().size():
		var planet := map.planets()[i]
		_expect(is_equal_approx(planet.depth_below_system(),
				Tuning.num("exploration/planet_center_depth")),
			"%s's planet is below ITS OWN combat plane (ADR 0061)" % SystemMap.NAMES[i],
			"%.1f m below a system centred at y %.1f" % [
				planet.depth_below_system(), planet.base.y])

	# --- the road (POC step 6, reshaped after the first play session) ---
	# The highway runs entirely THROUGH each system and never stops (ADR 0065). What
	# stops is the ramp: it leaves the mainline tangentially and curves down and out
	# to a portal beside the planet.
	var road := map.road()
	# A ramp is DECLARED now, not inferred from the portal it carries. Once there is a
	# second highway both halves of that inference break at once: an interchange ramp
	# joins two roads and carries no portal (ADR 0081).
	var mainlines: Array[RoadDeck] = []
	var ramps: Array[RoadDeck] = []
	for deck in road.decks():
		if deck.is_ramp:
			ramps.append(deck)
		elif deck.route_name == SystemMap.ROUTE_NAMES[0]:
			mainlines.append(deck)
	_expect(mainlines.size() == 2,
		"there is one mainline per direction, spanning the whole map",
		"%d mainlines" % mainlines.size())
	_expect(mainlines[0].runs_forward != mainlines[1].runs_forward,
		"…running opposite ways, so there is never oncoming traffic in the player's lane",
		"both run %s" % ("forward" if mainlines[0].runs_forward else "reversed"))
	# …and they are laid on opposite sides of the spine, which is what right-hand
	# traffic MEANS here. Sampled at the middle of the map, where the spine is not
	# near either end and the answer is unambiguous.
	var middle: Vector3 = road.spine().point_at(road.spine().length() * 0.5)
	var forward: RoadDeck = mainlines[0] if mainlines[0].runs_forward else mainlines[1]
	var reverse: RoadDeck = mainlines[1] if mainlines[0].runs_forward else mainlines[0]
	var spine_across: Vector3 = road.spine().tangent_at(
		road.spine().length() * 0.5).cross(Vector3.UP).normalized()
	var forward_side: float = (forward.path().closest(middle)[1] - middle).dot(
		spine_across)
	var reverse_side: float = (reverse.path().closest(middle)[1] - middle).dot(
		spine_across)
	_expect(forward_side > 0.0 and reverse_side < 0.0,
		"…each on the RIGHT of its own direction of travel — traffic runs on the right",
		"forward deck %+.0f m across, reverse deck %+.0f m" % [
			forward_side, reverse_side])
	# And what that buys: the oncoming deck is on your LEFT, from either seat. This is
	# the property that replaced the upper/lower convention, so it is the one asserted.
	var forward_travel: Vector3 = forward.path().closest(middle)[2]
	var toward_oncoming: Vector3 = reverse.path().closest(middle)[1] \
		- forward.path().closest(middle)[1]
	_expect(toward_oncoming.dot(forward_travel.cross(Vector3.UP)) < 0.0,
		"…so the oncoming lane is on your left, with no convention to remember",
		"the oncoming deck came out on the right")
	# Four ramps at a system the road passes through, two at each end of the line — a
	# ramp that serves nobody is not built, because it would be an opening onto a road
	# with no traffic and a sign with no name on it.
	var through := map.systems().size() - 2
	var planet_ramps: Array[RoadDeck] = []
	var interchange_ramps: Array[RoadDeck] = []
	for ramp: RoadDeck in ramps:
		if ramp.start_portal() != null or ramp.end_portal() != null:
			planet_ramps.append(ramp)
		else:
			interchange_ramps.append(ramp)
	_expect(planet_ramps.size() == through * 4 + 4,
		"…and every system has the ramps it has traffic for, and no others",
		"%d ramps for %d systems, %d of them through-systems" % [
			planet_ramps.size(), map.systems().size(), through])
	# THE CROSSING HIGHWAY. It is here so an exit-face rule can be flown rather than
	# only read, and it is a road like any other: its own spine, a carriageway either
	# side of it, its own building. It carries no portals and simply ends.
	var crossing: Array[RoadDeck] = []
	for deck in road.decks():
		if deck.route_name == SystemMap.ROUTE_NAMES[1] and not deck.is_ramp:
			crossing.append(deck)
	_expect(crossing.size() == 2,
		"a second highway crosses the first, one carriageway per direction",
		"%d crossing carriageways" % crossing.size())
	_expect(crossing.size() == 2 and crossing[0].start_portal() == null
			and crossing[0].end_portal() == null,
		"…and it carries no portals — it ends, the way the main road ends at the map's edge",
		"the crossing road has a portal on it")
	_expect(interchange_ramps.size() >= 1,
		"…and at least one ramp turns onto it, so the exit-face rule is flyable",
		"%d interchange ramps" % interchange_ramps.size())
	# It rides ABOVE the road it crosses, which is what makes "over the top" the answer
	# for the carriageway coming the other way — and its own roof still has to clear
	# the system's ceiling by more than the warning band.
	var main_roof := Tuning.num("exploration/road_height") \
		+ Tuning.num("exploration/lane_height") * 0.5
	var cross_floor := Tuning.num("exploration/crossing_road_height") \
		- Tuning.num("exploration/lane_height") * 0.5
	_expect(cross_floor > main_roof,
		"…and it passes clear ABOVE the road it crosses",
		"its floor is at %.0f m over a %.0f m roof" % [cross_floor, main_roof])
	var cross_head := Tuning.num("exploration/system_ceiling_height") \
		- (Tuning.num("exploration/crossing_road_height")
			+ Tuning.num("exploration/lane_height") * 0.5)
	_expect(cross_head > Tuning.num("exploration/bounds_warning_band"),
		"…with head room over it too, so the upper road is not a red alarm either",
		"%.0f m of head room" % cross_head)
	_expect(Tuning.num("exploration/crossing_road_length")
			< Tuning.num("exploration/system_diameter"),
		"…and it stays inside the system's own disc rather than running out of bounds",
		"%.0f m of road in a %.0f m disc" % [
			Tuning.num("exploration/crossing_road_length"),
			Tuning.num("exploration/system_diameter")])
	# The sign has to name the NEIGHBOUR, not the system you are standing in. "TO
	# SYSTEM B" on a portal inside system B is the kind of thing only a frame catches.
	# Planet ramps only: an interchange ramp joins two roads and carries no sign.
	for ramp: RoadDeck in planet_ramps:
		var sign_at: Portal = ramp.start_portal() if ramp.start_portal() != null \
			else ramp.end_portal()
		var home := map.system_name(map.nearest_system(sign_at.position))
		if sign_at.destination.ends_with(home):
			_expect(false,
				"a ramp's sign names the neighbour it serves, not the system it is in",
				"%s reads \"%s\" while standing in %s" % [
					ramp.name, sign_at.destination, home])
			break
	for ramp: RoadDeck in planet_ramps:
		var ends := 0
		if ramp.start_portal() != null:
			ends += 1
		if ramp.end_portal() != null:
			ends += 1
		if ends != 1:
			_expect(false, "a ramp carries exactly one portal, at its planet end",
				"%s has %d" % [ramp.name, ends])
			break

	# THE thing the reshape was for: the mainline passes through every system's
	# middle. A road that stopped at each one would put every arrival a
	# system-crossing from the only thing worth arriving for.
	# It no longer passes through the exact centre: the carriageways sit half a
	# separation either side of the spine, and the SPINE is what runs through the
	# middle. So what is checked is that the mainline holds its own side of it all the
	# way, rather than wandering across the median or drifting off the system.
	var runs_through := true
	var own_side := Tuning.num("exploration/deck_separation") * 0.5
	var worst_drift := 0.0
	# Only the systems ON this road. With two highways crossing, the others are
	# kilometres off to one side and mean nothing to this carriageway.
	for i: int in SystemMap.ROUTE_SYSTEMS[0]:
		var lane := mainlines[0].sample(map.system_center(i))
		worst_drift = maxf(worst_drift, absf(absf(lane.lateral) - own_side))
		if lane.metres_travelled <= 0.0 or lane.metres_remaining <= 0.0:
			runs_through = false
	_expect(runs_through,
		"the mainline runs THROUGH every system, ending at neither of them",
		"it stops inside one")
	_expect(worst_drift < 1.0,
		"…holding its own carriageway past each, half a separation off the spine",
		"%.1f m off its side" % worst_drift)
	_expect(mainlines[0].length() > map.system_center(0).distance_to(
			map.system_center(map.systems().size() - 1)),
		"…and out past the far rim at each end, rather than stopping at a centre",
		"%.0f m of road across a %.0f m map" % [mainlines[0].length(),
			map.system_center(0).distance_to(
				map.system_center(map.systems().size() - 1))])

	# --- the road's SHAPE (POC step 8) ---
	# THE steepness check, and the one that makes "too steep" a number rather than an
	# opinion. The ship's nose is hard-clamped into a cone around the road's axis
	# every frame, so a road that turns faster than the ship can be turned yanks the
	# nose instead of being flown — which is what a diving ramp feels like. Measured
	# on every road on the map, at full cruise, because the tightest bend is the one
	# that decides it.
	var cruise := Tuning.num("exploration/cruise_speed")
	var allowance := Tuning.num("exploration/cruise_turn_rate_deg_per_sec")
	var steepest := 0.0
	var steepest_name := ""
	for deck in road.decks():
		var rate := deck.path().max_turn_deg_per_metre() * cruise
		if rate > steepest:
			steepest = rate
			steepest_name = deck.name
	_expect(steepest <= allowance,
		"no road on the map turns faster than the ship can be turned at cruise",
		"%s bends at %.1f deg/s against a %.1f deg/s turn rate" % [
			steepest_name, steepest, allowance])
	# …and it is not zero, or success criterion 1 has nothing to be judged on: "a
	# generous clamp on a straight road still feels like nothing".
	# THE TRUNK, by name. It used to be "the last link", and with a second highway on
	# the map the last link is a leg of the other road on a different bearing.
	var trunk: SystemLink = map.links()[1]
	for one: SystemLink in map.links():
		if one.from_name == SystemMap.NAMES[1] and one.to_name == SystemMap.NAMES[2]:
			trunk = one
	var trunk_line := trunk.region().path
	_expect(trunk_line.max_turn_deg_per_metre() > 0.0,
		"the trunk leg CURVES — a straight road cannot answer success criterion 1",
		"the trunk leg is straight")
	var lowest := INF
	var highest := -INF
	for point: Vector3 in trunk_line.points:
		lowest = minf(lowest, point.y)
		highest = maxf(highest, point.y)
	_expect(highest - lowest > Tuning.num("exploration/lane_height"),
		"…and changes elevation by more than the lane is tall, so the rise is felt",
		"%.0f m of rise and fall" % (highest - lowest))
	# A weaving leg still has to leave and arrive ON the bearing, or the aperture and
	# the corridor disagree about where the road goes and the mouths move.
	var on_bearing := SystemDisc.bearing_to_direction(
		Tuning.num("exploration/aperture_bearing_deg"))
	_expect(trunk_line.tangent_at(0.0).dot(on_bearing) > 0.999
			and trunk_line.tangent_at(trunk_line.length()).dot(on_bearing) > 0.999,
		"…and leaves and arrives exactly on the bearing, so the mouths do not move",
		"%.3f in, %.3f out" % [trunk_line.tangent_at(0.0).dot(on_bearing),
			trunk_line.tangent_at(trunk_line.length()).dot(on_bearing)])
	# THE CURVE RADIUS FLOOR. The two carriageways are offset SIDEWAYS from the spine
	# now, so the inner one is shorter than the outer through every bend — which is
	# what a divided highway does, and is fine until the bend is tighter than the
	# offset. At a radius below the separation the inner carriageway folds through
	# itself and the lane stops being a lane. This replaces the northwest-southeast
	# divider invariant, which right-hand traffic retired (ADR 0077).
	var turn := trunk_line.max_turn_deg_per_metre()
	var radius := INF if turn <= 0.0 else 180.0 / (PI * turn)
	_expect(radius > Tuning.num("exploration/deck_separation"),
		"…and never bends tighter than the two carriageways are far apart",
		"a %.0f m radius against a %.0f m separation" % [
			radius, Tuning.num("exploration/deck_separation")])
	# The corridor is the space AROUND the road, so it has to still contain it once
	# both curve. The far top corner of the outboard lane is the worst case, and it is
	# now a diagonal: half the separation plus half the width across, half the height up.
	var out_across := Tuning.num("exploration/deck_separation") * 0.5 \
		+ Tuning.num("exploration/lane_width") * 0.5
	var up_by := Tuning.num("exploration/lane_height") * 0.5
	var worst_escape := -INF
	for i in 40:
		var along := trunk_line.length() * float(i) / 39.0
		var across := trunk_line.tangent_at(along).cross(Vector3.UP).normalized()
		for side: float in [1.0, -1.0]:
			worst_escape = maxf(worst_escape, trunk.region().depth(
				trunk_line.point_at(along) + across * side * out_across
					+ Vector3.UP * up_by))
	_expect(worst_escape < 0.0,
		"…and the corridor still contains the road laid inside it, all the way",
		"the lane's far corner is %.1f m outside the corridor" % worst_escape)

	# --- where the road SITS (2026-08-30) ---
	# High, not through the middle. Two things bound it and both are cheap to get
	# wrong by nudging one slider: the ceiling above, and the planet's approach
	# envelope below — which the road must never enter, or riding the highway arms a
	# landing nobody asked for (ADR 0012).
	# Side by side, so the roof is the lane's own half-height above the road's centre.
	# The separation is an ACROSS measurement now and adds nothing here.
	var stack_top := Tuning.num("exploration/road_height") \
		+ Tuning.num("exploration/lane_height") * 0.5
	var head_room := Tuning.num("exploration/system_ceiling_height") - stack_top
	_expect(head_room > Tuning.num("exploration/bounds_warning_band"),
		"the road clears the ceiling by more than the warning band, so riding it is not an alarm",
		"%.0f m of head room against a %.0f m band" % [head_room,
			Tuning.num("exploration/bounds_warning_band")])
	_expect(Tuning.num("exploration/road_height")
			> Tuning.num("exploration/lane_height"),
		"…and rides ABOVE the combat plane rather than straddling it",
		"the road is centred at %.0f m" % Tuning.num("exploration/road_height"))
	var envelope := Tuning.num("exploration/approach_envelope_radius")
	var nearest_envelope := INF
	for deck in road.decks():
		var line := deck.path()
		for i in 60:
			var at: Vector3 = line.point_at(line.length() * float(i) / 59.0)
			var system := map.nearest_system(at)
			nearest_envelope = minf(nearest_envelope,
				at.distance_to(map.planets()[system].position))
	_expect(nearest_envelope > envelope,
		"…and no road anywhere enters an approach envelope (ADR 0012)",
		"a road passes %.0f m from a planet, envelope is %.0f" % [
			nearest_envelope, envelope])

	# --- one lane is lit, and it is the one being flown ---
	# Four carriageways cross the view at an interchange. The player has to be able to
	# see which of them is theirs, and the answer is the only one painted bright.
	# Checked on the MATERIAL rather than on visibility: every carriageway is drawn now
	# (ADR 0075), so what says "yours" is the colour and nothing else.
	map.road().set_active(mainlines[0])
	var lit := 0
	var mismatched := ""
	var bright := Tuning.num("exploration/lane_active_alpha")
	for deck in road.decks():
		var paint := deck.get_node_or_null("Lines") as MeshInstance3D
		var paint_mat := paint.material_override as StandardMaterial3D \
			if paint != null else null
		if paint_mat == null:
			mismatched = deck.name
			continue
		var is_lit := is_equal_approx(paint_mat.albedo_color.a, bright)
		if is_lit != deck.is_active():
			mismatched = deck.name
		if is_lit:
			lit += 1
	_expect(mismatched.is_empty() and lit == 1,
		"exactly one carriageway is painted bright, and it is the one being ridden",
		"%d lit%s" % [lit,
			"" if mismatched.is_empty() else ", %s disagrees" % mismatched])
	_expect(mainlines[0].is_active() and not mainlines[1].is_active(),
		"…and never both directions at once",
		"first %s, second %s" % [mainlines[0].is_active(), mainlines[1].is_active()])
	map.road().set_active(null)

	# --- a handover cannot hand you a lane you could not steer onto (ADR 0072) ---
	# This is what shook the ship: drifting wide of a mainline beside an interchange
	# handed it to a ramp thirty degrees off its heading, and the nose is clamped into
	# a cone around the road every frame, so thirty degrees arrived in one of them.
	var probe := map.system_center(1) + Vector3.UP * Tuning.num("exploration/road_height")
	var main_axis: Vector3 = mainlines[0].sample(probe).axis
	# The ONCOMING lane is never a candidate, and that is now geometry rather than a
	# flag: asked along the mainline's own direction the union answers with a road
	# going that way, and asked along the reverse it answers with the other
	# carriageway. Nothing filters on which way a deck runs (ADR 0081).
	var aligned_pick := road.governing(probe, main_axis, null, Vector2.ZERO)
	var against_pick := road.governing(probe, -main_axis, null, Vector2.ZERO)
	_expect(aligned_pick != null and against_pick != null,
		"a deck governs the middle of an interchange from either direction",
		"nothing does")
	_expect(aligned_pick != against_pick,
		"…and it is a different one each way — the union never hands you the oncoming lane",
		"the same deck governs both directions")
	# A DECK THAT HAS ENDED BEHIND YOU CANNOT GOVERN. `RoadPath.closest` clamps, so a
	# ship at the top of a ramp reports as sitting on the ramp's last metre for ever:
	# the ramp hands over because it has ended, the union hands straight back because
	# the ramp is still the nearest thing, and the two alternate every frame until the
	# ship falls off the road. That is the stutter at an exit ramp (ADR 0076).
	var an_on_ramp := road.get_node_or_null("A377BRampOnBForward") as RoadDeck
	if an_on_ramp != null:
		var at_the_top: Vector3 = an_on_ramp.path().finish()
		var after := road.governing(at_the_top,
			an_on_ramp.path().tangent_at(an_on_ramp.length()), null, Vector2.ZERO)
		_expect(after != null and after != an_on_ramp,
			"a ramp that has ended does not govern the point it ended at — something else does",
			"the union handed back the ramp the ship just ran off")
		_expect(after == null or not after.is_ramp,
			"…and what takes over at a merge is the mainline",
			"handed to %s" % (after.name if after != null else "nothing"))
	if aligned_pick != null:
		var picked: Vector3 = aligned_pick.sample(probe).axis
		_expect(rad_to_deg(picked.angle_to(main_axis))
				<= Tuning.num("exploration/cruise_turn_clamp_deg") + 0.01,
			"…and asking along a heading only ever returns one inside the steering cone",
			"%.1f deg off" % rad_to_deg(picked.angle_to(main_axis)))

	# The ramp mouths sit BESIDE the planet, not above it. Directly above is inside
	# the approach envelope, and a ship taking the ramp would arm a landing sequence
	# it did not ask for (ADR 0012).
	var closest_to_planet := INF
	var deepest_mouth := 0.0
	for mouth: Vector3 in map.ramp_sites():
		var system := map.nearest_system(mouth)
		closest_to_planet = minf(closest_to_planet,
			mouth.distance_to(map.planets()[system].position))
		deepest_mouth = maxf(deepest_mouth, field.overshoot(mouth))
	_expect(closest_to_planet > Tuning.num("exploration/approach_envelope_radius"),
		"every ramp mouth clears the approach envelope — taking a ramp is not landing",
		"nearest is %.0f m from a planet, envelope is %.0f" % [closest_to_planet,
			Tuning.num("exploration/approach_envelope_radius")])
	_expect(is_zero_approx(deepest_mouth),
		"…and every one is inside the bounded volume of its own system",
		"%.1f m outside" % deepest_mouth)
	# THE ENVELOPE HAS TO REACH THE COMBAT PLANE. The planet sits below it by decision
	# (ADR 0061), and at 420 m against a 450 m depth the envelope's roof was thirty
	# metres UNDER y = 0: a ship flying level at a planet closed to exactly 450 m,
	# stopped, and never entered. Docking read as not existing, and was reported that
	# way. Arriving is still a descent; the way in just has to start where the player is.
	var envelope_top := Tuning.num("exploration/approach_envelope_radius") \
		- Tuning.num("exploration/planet_center_depth")
	_expect(envelope_top > Tuning.num("exploration/planet_radius") * 0.25,
		"the approach envelope reaches the combat plane — docking is enterable by flying at it",
		"its roof is %.0f m from y = 0" % envelope_top)
	_expect(closest_to_planet < discs[0].radius(),
		"…while still being BESIDE the planet rather than somewhere else entirely",
		"%.0f m away in a %.0f m disc" % [closest_to_planet, discs[0].radius() * 2.0])

	# A ramp has to MEET the mainline tangentially, or joining it is a corner the
	# steering cone cannot turn.
	var on_ramp := road.get_node_or_null("A377BRampOnBForward") as RoadDeck
	_expect(on_ramp != null, "system B has an on-ramp on the forward deck", "missing")
	if on_ramp != null:
		var merge := on_ramp.path().tangent_at(on_ramp.length())
		var main := mainlines[0].sample(on_ramp.path().finish()).axis
		_expect(rad_to_deg(merge.angle_to(main))
				< Tuning.num("exploration/cruise_turn_clamp_deg"),
			"…and it merges inside the steering cone, so joining is a steer not a turn",
			"%.1f deg off the mainline" % rad_to_deg(merge.angle_to(main)))

	# --- the road is a BUILDING, and it is built from modules (ADR 0078) ---
	# One structure for the mainline pair, and one per ramp. The pair sharing a
	# building is the whole reason the deck and the structure had to be split: a deck
	# cannot own a building that also belongs to the deck coming the other way.
	var built := road.structures()
	var pair_structures := 0
	var ramp_structures := 0
	for one: RoadStructure in built:
		if one.is_ramp:
			ramp_structures += 1
		else:
			pair_structures += 1
	# One building per PAIR of carriageways — the main road's and the crossing road's —
	# and one per ramp. A pair sharing a building is the whole reason the deck and the
	# structure had to be split: a deck cannot own a building that also belongs to the
	# deck coming the other way.
	_expect(pair_structures == 2,
		"each pair of carriageways shares ONE building — a deck is the lane, not the road",
		"%d shared structures" % pair_structures)
	_expect(ramp_structures == ramps.size(),
		"…and every ramp is a building of its own, with one lane in it",
		"%d structures for %d ramps" % [ramp_structures, ramps.size()])
	var median_count := 0
	for one: RoadStructure in built:
		if one.has_median:
			median_count += 1
	_expect(median_count == pair_structures,
		"…and a median in every one that divides two directions, and in no ramp",
		"%d medians for %d shared structures" % [median_count, pair_structures])

	# MODULES, not an extrusion. Four layers of them, each a MultiMesh: this is what
	# makes real art a mesh swap rather than a rewrite (ADR 0030), and it is what the
	# old swept ArrayMesh could never be.
	var pair_built: RoadStructure = null
	for one: RoadStructure in built:
		if one.structure_name == "A377BStructure":
			pair_built = one
	_expect(pair_built != null,
		"…and the main road's building is findable by name, so the gate can ask it things",
		"the A-377B structure is missing")
	var layered := true
	var instances := 0
	for layer_name: String in ["Ribs", "Bays", "Plates", "Panes"]:
		var layer := pair_built.get_node_or_null(layer_name) as MultiMeshInstance3D
		if layer == null or layer.multimesh == null or layer.multimesh.mesh == null \
				or layer.multimesh.instance_count <= 0:
			layered = false
		else:
			instances += layer.multimesh.instance_count
	_expect(layered,
		"the mainline is built from collars, bays, roadway and median — four layers of modules",
		"a layer is missing, empty, or has no mesh")
	_expect(instances > 0 and instances < 20000,
		"…and the whole highway is a handful of meshes and a transform list",
		"%d module instances" % instances)
	# There is one more collar than there are bays: a collar sits on every joint,
	# including both ends, which is what makes the road read as a chain of segments
	# rather than as a striped tube. Counted against the module length rather than
	# against the glazing, because a bay that a ramp goes through is laid as several
	# pieces and the glazing count is no longer the number of bays.
	var collars := (pair_built.get_node_or_null("Ribs") as MultiMeshInstance3D)
	var glazing := (pair_built.get_node_or_null("Bays") as MultiMeshInstance3D)
	var expected_bays := maxi(int(pair_built.length()
		/ Tuning.num("exploration/structure_module_length")), 1)
	# A joint carries either a collar or a service station, and every joint carries
	# one. Counted together, because a station takes a collar's place.
	var joints := collars.multimesh.instance_count \
		+ (pair_built.get_node_or_null("Stations")
			as MultiMeshInstance3D).multimesh.instance_count
	_expect(joints == expected_bays + 1,
		"…with a collar or a station on every joint, both ends included",
		"%d joints for %d bays" % [joints, expected_bays])
	_expect(glazing.multimesh.instance_count >= expected_bays,
		"…and a bay in every gap between them",
		"%d bay pieces for %d gaps" % [glazing.multimesh.instance_count,
			expected_bays])
	# SERVICE STATIONS take a collar's place every so many joints, so the road has
	# landmarks rather than an unbroken run of identical ribs. Counted against the
	# collars they replaced: every station is a joint that is not a rib.
	var stations := (pair_built.get_node_or_null("Stations")
		as MultiMeshInstance3D)
	var every := maxi(int(Tuning.num("exploration/structure_station_spacing")), 0)
	var due := 0 if every <= 0 else maxi((expected_bays - 1) / every, 0)
	_expect(stations != null and stations.multimesh.instance_count == due,
		"…with a service station in place of a collar every few joints",
		"%d stations, %d due" % [
			0 if stations == null else stations.multimesh.instance_count, due])
	_expect(collars.multimesh.instance_count + due == expected_bays + 1,
		"…and a station REPLACES a collar rather than being added beside one",
		"%d collars and %d stations for %d joints" % [
			collars.multimesh.instance_count, due, expected_bays + 1])

	# --- RINGS AND EXIT FACES (ADR 0080) ---
	# Every ramp goes through the mainline's building somewhere, and the building has
	# to be open where it does. The opening is MEASURED off the ramp's own curve, so
	# this is also the check that the measurement found every one of them.
	# ONE ROAD'S BUILDING, one road's ramps. With two highways crossing, `ramps` is
	# every ramp on the map and most of them go through the other one's walls.
	var route_ramps: Array[RoadDeck] = []
	var route_signs: Array[ExitSign] = []
	for ramp: RoadDeck in ramps:
		if ramp.route_name == SystemMap.ROUTE_NAMES[0]:
			route_ramps.append(ramp)
	for sign: ExitSign in road.signs():
		if sign.ramp != null and sign.ramp.route_name == SystemMap.ROUTE_NAMES[0]:
			route_signs.append(sign)
	_expect(pair_built.apertures().size() == route_ramps.size(),
		"the building opens once for every ramp that goes through it",
		"%d openings for %d ramps" % [pair_built.apertures().size(),
			route_ramps.size()])
	# THE EXIT-FACE RULE, asked of each ramp's own curve rather than of the opening it
	# was given. An exit leaves through a wall or the roof and NEVER through the floor
	# — the floor is the roadway, and an exit competing with it for the meaning of
	# "down" is clutter. An entry is the opposite and comes up through the floor,
	# because merging upward into the only lane there is is unambiguous.
	#
	# The entry half is the one that can quietly stop being true: it holds only while
	# a ramp drops faster, in section-widths, than it swings out — and the exit half
	# needs exactly the opposite. `ramp_*_depth` against `ramp_*_side_offset` is what
	# decides each, and all four are sliders. Measured against the road's real curve
	# rather than a straight one: a ramp is a chord across a bend and bulges outward,
	# which is where this first went wrong, at system A on the weaving local leg.
	var exits_downward := ""
	var entries_not_from_below := ""
	# Every ramp, planet and interchange alike: an interchange ramp leaves the main
	# road through a wall exactly as a planet off-ramp does, and the rule is the rule.
	#
	# AGAINST ITS OWN ROAD'S BUILDING. Measured against the other road's walls, a ramp
	# that comes up perfectly through its own floor reads as going through a wall —
	# which is exactly what this reported when the map grew a second highway, and it
	# was the test that was wrong rather than the road.
	for ramp: RoadDeck in ramps:
		var leaving := not ramp.has_start_portal
		var owner := road.building_for(ramp.route_name)
		if owner == null:
			continue
		var found := RoadNetwork.crossing(owner, ramp.path(), leaving)
		if found.is_empty():
			continue
		var face: int = found[1]
		if leaving and face == int(RoadStructure.Face.BELOW):
			exits_downward = "%s leaves through the floor" % ramp.name
		if not leaving and face != int(RoadStructure.Face.BELOW):
			entries_not_from_below = "%s reaches a wall before the floor" % ramp.name
	_expect(exits_downward.is_empty(),
		"no ramp leaves through the FLOOR — down is the roadway, and it is not an exit",
		exits_downward)
	_expect(entries_not_from_below.is_empty(),
		"…and every ramp joins from BELOW, up through the roadway",
		entries_not_from_below)

	# THE RING PASSES THE LARGEST HULL. This is the check ADR 0068 said the gate should
	# be able to make and could not: a mouth is round, so what has to clear it is the
	# hull's DIAGONAL, not its width and height taken separately.
	var ring := Tuning.num("exploration/ramp_ring_diameter")
	var carrier := load("res://assets/models/carrier.obj") as Mesh
	for kind: HullClass.Kind in HullClass.all():
		var body := carrier.get_aabb().size \
			* HullClass.num(kind, "hull_scale", "ship/hull_scale")
		var diagonal := sqrt(body.x * body.x + body.y * body.y)
		_expect(ring > diagonal * 1.25,
			"a %s passes through a ramp ring with room around it, corner to corner"
				% HullClass.name_of(kind),
			"%.0f m ring against a %.0f m diagonal" % [ring, diagonal])
	# …and a ring may not be taller than the wall it sits in. A side opening is the
	# wall's full height, and a hoop bigger than that stands proud of the road.
	_expect(ring <= Tuning.num("exploration/lane_height"),
		"…and no bigger than the wall it opens, so it sits in the building",
		"%.0f m ring in a %.0f m section" % [ring,
			Tuning.num("exploration/lane_height")])
	var hoops := pair_built.get_node_or_null("Rings") as MultiMeshInstance3D
	_expect(hoops != null
			and hoops.multimesh.instance_count == route_ramps.size(),
		"…and every opening actually carries one",
		"%d rings for %d openings" % [
			0 if hoops == null else hoops.multimesh.instance_count,
			route_ramps.size()])

	# THE BUILDING CONTAINS THE LANES. The pair's interior spans both carriageways and
	# the gap between them, so the outermost lane edge is exactly its inside face. If
	# this ever goes the other way a ship flying its own lane is inside a wall.
	var interior := pair_built.extents_at(pair_built.length() * 0.5)
	var lane_reach := Tuning.num("exploration/deck_separation") * 0.5 \
		+ Tuning.num("exploration/lane_width") * 0.5
	_expect(interior.x >= lane_reach - 0.01
			and interior.y >= Tuning.num("exploration/lane_height") * 0.5 - 0.01,
		"the building contains both lanes — the far lane edge is its inside face",
		"%.0f x %.0f interior against a %.0f x %.0f reach" % [interior.x, interior.y,
			lane_reach, Tuning.num("exploration/lane_height") * 0.5])

	# ADR 0057 says the lane is VISUALLY OPEN, and ADR 0079 says what that MEANS: not
	# an alpha below a threshold — that cannot tell a window from a tinted wall — but
	# that the outward-facing envelope is mostly glass. Around the section the walls
	# and roof are glazed and only the roadway is solid; along the road, every metre
	# that is not a collar is a bay. So the number is the collars' share of the run.
	var open_area := RoadStructure.open_fraction(
		Tuning.num("exploration/structure_module_length"),
		Tuning.num("exploration/structure_rib_thickness"))
	_expect(open_area > 0.5,
		"most of the road's outward-facing envelope is GLASS, so the space beyond it stays witnessed",
		"only %.0f%% of the run is glazed" % (open_area * 100.0))
	_expect(RoadStructure.open_fraction(100.0, 100.0) == 0.0
			and RoadStructure.open_fraction(100.0, 0.0) == 1.0,
		"…and the measure is honest at both ends: all collar is closed, no collar is open",
		"the ratio does not reach its own bounds")
	# The glass is deliberately MORE opaque than the shell it replaced — it is a
	# diffuser, and that is what lets a rough render behind it read as a ship. It
	# still may not reach opacity: a pane you cannot see the stars through is the
	# tunnel ADR 0057 forbids.
	_expect(Tuning.num("exploration/structure_glass_alpha") < 0.85,
		"…and the glass never reaches opacity, so it stays a window rather than a wall",
		"glass at %.2f" % Tuning.num("exploration/structure_glass_alpha"))
	var glass_mat := glazing.material_override as StandardMaterial3D
	_expect(glass_mat != null
			and glass_mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED,
		"…and it is actually a transparent material, not merely a pale colour",
		"the glazing is opaque")

	# EVERY CARRIAGEWAY IS MARKED, and the one being ridden is brighter (ADR 0075).
	# The structure carries the tunnel now, so a deck's own drawing is paint on the
	# road — but "every lane is drawn" is the clause that matters and it still holds.
	var marked := 0
	for deck in road.decks():
		var paint := deck.get_node_or_null("Lines") as MeshInstance3D
		if paint != null and paint.mesh != null and paint.visible \
				and paint.mesh.surface_get_primitive_type(0) == Mesh.PRIMITIVE_LINES:
			marked += 1
	_expect(marked == road.decks().size(),
		"every carriageway is marked, ridden or not — a road you cannot see is not a choice",
		"%d marked for %d carriageways" % [marked, road.decks().size()])
	_expect(Tuning.num("exploration/lane_line_alpha")
			< Tuning.num("exploration/lane_active_alpha"),
		"…and the one you are on is the brighter of them",
		"idle %.2f against active %.2f" % [
			Tuning.num("exploration/lane_line_alpha"),
			Tuning.num("exploration/lane_active_alpha")])

	# The aperture has to clear the hull with room to fly through rather than to aim.
	# Measured axis by axis, not against the bounding sphere: the sphere of a
	# 44 x 24 x 48 m gunboat is 72 m across and would condemn an opening the ship
	# flies through with 13 m to spare.
	var hull := scene.ship().hull_extents()
	_expect(Tuning.num("exploration/portal_width") > hull.x
			and Tuning.num("exploration/portal_height") > hull.y,
		"the aperture clears the hull on both axes, with room to fly rather than aim",
		"%.0f x %.0f m opening for a %.1f x %.1f m hull" % [
			Tuning.num("exploration/portal_width"),
			Tuning.num("exploration/portal_height"), hull.x, hull.y])

	# Getting on the road. Two frames either side of an on-ramp's portal, because the
	# crossing test is swept — and driven through the real scene so the wiring from
	# portal to cruise drive to speed ceiling is covered, not just the arithmetic.
	var gate := on_ramp.start_portal()
	var travel := on_ramp.path().tangent_at(0.0)
	scene.ship().position = gate.position - travel * 20.0
	_step_exploration(scene, 1.0 / 60.0)
	_expect(scene.ship().cruise == null,
		"short of the portal the cruise drive is off", "it engaged early")
	scene.ship().position = gate.position + travel * 20.0
	_step_exploration(scene, 1.0 / 60.0)
	_expect(scene.ship().cruise != null and map.riding() == on_ramp,
		"crossing the portal engages cruise ON CONTACT — no sequence (ADR 0057)",
		"it did not engage")
	# The drive SPOOLS rather than snapping. Entry is still instant — the ship is
	# through, steering, holding its own throttle — but the engine takes time to wind
	# up, which is the ship doing something rather than something done to the ship.
	var at_entry := scene.ship().manual_max_speed()
	_expect(at_entry < Tuning.num("exploration/cruise_speed") * 0.5,
		"…and the ceiling does NOT snap to cruise speed on the entry frame",
		"%.1f m/s of %.1f in one frame" % [at_entry,
			Tuning.num("exploration/cruise_speed")])
	for _i in int(Tuning.num("exploration/cruise_spool_seconds") * 60.0) + 6:
		_step_exploration(scene, 1.0 / 60.0)
	_expect(scene.ship().manual_max_speed()
			> Tuning.num("exploration/taxi_max_speed") * 2.0
			and scene.ship().cruise_spool() > 0.999,
		"…but it winds up to the cruise drive's, which is what the road buys",
		"%.1f m/s at %.0f%% spool" % [scene.ship().manual_max_speed(),
			scene.ship().cruise_spool() * 100.0])
	# The camera frames the ROAD while cruising, not the nose.
	_expect((scene.get_node("ChaseCamera") as ChaseCamera)
			.heading_override.length_squared() > 0.5,
		"…and the camera locks to the road's direction, not the ship's nose",
		"the camera stayed on the nose")

	# Riding up the ramp and onto the mainline. No junction logic exists: whichever
	# deck going this way the ship is least outside of governs, so a ramp hands over
	# to the mainline because the geometry says so.
	scene.ship().position = on_ramp.path().finish()
	_step_exploration(scene, 1.0 / 60.0)
	_expect(map.riding() == mainlines[0] or map.riding() == on_ramp,
		"at the top of the ramp the ship is on the ramp or the mainline, not adrift",
		"riding %s" % ("nothing" if map.riding() == null else map.riding().name))
	# On the mainline over system B. Asked of the deck's own path rather than built
	# out of the separation by hand: the offset is lateral now, and a test that
	# reconstructs it is a test that has to be rewritten every time it moves.
	scene.ship().position = mainlines[0].path().closest(map.system_center(1))[1]
	_step_exploration(scene, 1.0 / 60.0)
	_expect(map.riding() == mainlines[0] and scene.ship().cruise != null,
		"…and out on the mainline over a system's centre it is on the MAINLINE",
		"riding %s" % ("nothing" if map.riding() == null else map.riding().name))

	# --- THE BERTH ON THE ROADWAY (ADR 0082) ---
	# The road is a dock host. What is under test is the three properties that make it
	# a dock rather than a conveyor: chosen, reversible, and never the fast route.
	var berth := map.berth()
	_expect(Tuning.num("exploration/berth_speed_fraction") < 1.0,
		"the berth is SLOWER than driving yourself — automation is never the fast route",
		"%.2f of cruise" % Tuning.num("exploration/berth_speed_fraction"))
	_expect(Tuning.num("exploration/berth_ride_height")
			< Tuning.num("exploration/berth_offer_height"),
		"…and it is offered before you are in it, not once you already are",
		"held at %.0f m, offered at %.0f" % [
			Tuning.num("exploration/berth_ride_height"),
			Tuning.num("exploration/berth_offer_height")])
	_expect(Tuning.num("exploration/berth_offer_height")
			< Tuning.num("exploration/lane_height"),
		"…and offered near the ROADWAY rather than anywhere in the tube",
		"offered %.0f m up a %.0f m section" % [
			Tuning.num("exploration/berth_offer_height"),
			Tuning.num("exploration/lane_height")])

	# CHOSEN. Up in the middle of the lane there is no offer; down by the roadway
	# there is, and doing nothing declines it.
	var mid_lane: Vector3 = mainlines[0].path().closest(map.system_center(1))[1]
	scene.ship().position = mid_lane
	_step_exploration(scene, 1.0 / 60.0)
	_expect(not berth.is_offered() and not berth.is_berthed(),
		"out in the middle of the lane no berth is offered",
		"the berth offered itself in mid-air")
	var floor_point: Vector3 = mid_lane - Vector3.UP * (
		Tuning.num("exploration/lane_height") * 0.5
		- Tuning.num("exploration/berth_ride_height"))
	scene.ship().position = floor_point
	_step_exploration(scene, 1.0 / 60.0)
	_expect(berth.is_offered(),
		"…and down by the roadway it is, without taking itself",
		"no offer beside the road")
	_step_exploration(scene, 1.0 / 60.0)
	_expect(not berth.is_berthed(),
		"…and doing nothing declines it — an offer is not a commitment",
		"the berth engaged on its own")

	# TAKEN, and it CONVERGES rather than snapping. Engaged well off the rail on
	# purpose: a berth that teleported the ship onto the centre-line would be the one
	# transition on this road that did not carry momentum (ADR 0066).
	scene.ship().position = floor_point + mainlines[0].sample(floor_point).right * 40.0
	_step_exploration(scene, 1.0 / 60.0)
	berth.engage(scene.ship(), map.riding())
	_expect(berth.is_berthed() and scene.ship().is_berthed(),
		"pressing dock takes the berth, and the ship knows it is being carried",
		"the berth did not engage")
	var was_off := berth.hold().error
	var biggest_step := 0.0
	var before_step := scene.ship().position
	for _i in 90:
		_step_exploration(scene, 1.0 / 60.0)
		biggest_step = maxf(biggest_step,
			(scene.ship().position - before_step).length())
		before_step = scene.ship().position
	_expect(berth.hold().error < was_off,
		"…and the ship slides ONTO the rail rather than being put on it",
		"%.1f m off, was %.1f" % [berth.hold().error, was_off])
	var reach := Tuning.num("exploration/cruise_speed") / 60.0 * 1.5
	_expect(biggest_step < reach,
		"…never moving further in a frame than a ship at cruise could have",
		"a %.1f m frame against a %.1f m budget" % [biggest_step, reach])

	# NOT STEERED BY INPUT, and that is the difference from the planet's threshold: a
	# threshold aborts on any input because it is a countdown to a commitment, a berth
	# is a place you sit inside and is left on purpose (ADR 0082).
	var bound := berth.deck()
	scene.ship().add_mouse_steer(Vector2(400.0, 0.0))
	_step_exploration(scene, 1.0 / 60.0)
	_expect(berth.is_berthed() and berth.deck() == bound,
		"looking around does not abort the berth, and does not change which road it is on",
		"the berth let go or changed roads")

	# NEVER THE FAST ROUTE, measured rather than asserted from the tuning value.
	var carried := scene.ship().speed()
	_expect(carried < Tuning.num("exploration/cruise_speed") - 1.0,
		"…and it carries the ship below cruise speed, as the fraction says",
		"%.0f m/s against a %.0f m/s road" % [carried,
			Tuning.num("exploration/cruise_speed")])

	# REVERSIBLE, and left FLYING. A berth that dropped the ship to a stop would be a
	# trap with an exit rather than a berth.
	berth.release(scene.ship())
	_step_exploration(scene, 1.0 / 60.0)
	_expect(not berth.is_berthed() and not scene.ship().is_berthed(),
		"pressing dock again leaves the berth, at any moment",
		"the berth would not let go")
	_expect(scene.ship().speed() > carried * 0.8,
		"…still carrying its speed, so leaving is not a stop",
		"%.0f m/s after leaving, was %.0f" % [scene.ship().speed(), carried])
	_expect(map.riding() != null and scene.ship().cruise != null,
		"…and back on the road it was already on, flying it again",
		"it came off the road entirely")

	# --- EXIT SIGNS (ADR 0083) ---
	# A sign is an object on the road, not a map. What is under test is that there is
	# one for every exit, that it hangs far enough back to be read in time, and that
	# clicking it changes which RAIL the berth is on rather than planning a route.
	var signs := road.signs()
	# A sign for every way OFF a road: the planet off-ramps and the interchange ramps
	# onto the road that crosses it. An on-ramp needs none — you are not on the road
	# yet, and there is nothing to choose.
	var exits := 0
	for deck in road.decks():
		if deck.is_ramp and deck.start_portal() == null:
			exits += 1
	_expect(signs.size() == exits,
		"there is a sign for every exit, and only for exits",
		"%d signs for %d exits" % [signs.size(), exits])
	var lead_ok := true
	var worst_lead := 0.0
	for sign: ExitSign in route_signs:
		var opening := RoadNetwork.crossing(
			road.building_for(sign.ramp.route_name), sign.ramp.path(), true)
		if opening.is_empty():
			continue
		var sign_at: float = pair_built.path().closest(sign.position)[0]
		var gap: float = float(opening[0]) - sign_at
		worst_lead = maxf(worst_lead, absf(
			gap - Tuning.num("exploration/exit_sign_lead_metres")))
		if gap <= 0.0:
			lead_ok = false
	_expect(lead_ok,
		"…and every sign hangs BEFORE the exit it names, not level with it or past it",
		"a sign sits at or beyond its own exit")
	_expect(worst_lead < 60.0,
		"…at the lead distance the road promises, so reading it in time is the same act everywhere",
		"one sign is %.0f m off its lead" % worst_lead)
	var named := true
	for sign: ExitSign in signs:
		if not sign.label_text.begins_with("EXIT"):
			named = false
	_expect(named, "…and reads as an exit, naming where it goes",
		"a sign does not name its exit")

	# CLICKABLE ONLY WHILE BERTHED. Flying, a click that changed which road you were on
	# would be autopilot growth (ADR 0013).
	scene.ship().position = floor_point
	_step_exploration(scene, 1.0 / 60.0)
	_expect(not berth.is_berthed() and map.aimed_sign() == null,
		"no sign is aimable while flying — a click may not change the road you are on",
		"a sign was live off the berth")

	# TAKEN, and the swap happens WHEN THE RAMP ARRIVES rather than when the sign is
	# clicked. The ramp starts ahead, and a rail that pulled the ship back onto its
	# start would be a route rather than a rebind.
	var exit_ramp := road.get_node_or_null("A377BRampOffCForward") as RoadDeck
	if exit_ramp != null:
		var main_line := mainlines[0].path()
		var diverge: float = main_line.closest(exit_ramp.path().start())[0]
		var before: Vector3 = main_line.point_at(maxf(diverge - 900.0, 0.0))
		var frame_at := CruiseLane.frame_for(
			main_line.tangent_at(maxf(diverge - 900.0, 0.0)))
		scene.ship().position = before - frame_at[1] * (
			Tuning.num("exploration/lane_height") * 0.5
			- Tuning.num("exploration/berth_ride_height"))
		_step_exploration(scene, 1.0 / 60.0)
		berth.engage(scene.ship(), map.riding())
		berth.take_exit(exit_ramp)
		_expect(berth.deck() == mainlines[0] and berth.taking() == exit_ramp,
			"clicking a sign does not move the ship — the exit is taken, not yet reached",
			"the berth swapped rails on the click")
		var jumped := 0.0
		var was_at := scene.ship().position
		for _i in 600:
			_step_exploration(scene, 1.0 / 60.0)
			jumped = maxf(jumped, (scene.ship().position - was_at).length())
			was_at = scene.ship().position
			if berth.deck() == exit_ramp:
				break
		_expect(berth.deck() == exit_ramp,
			"…and the berth swaps rails once the ramp is actually under the ship",
			"the exit was never reached")
		_expect(jumped < Tuning.num("exploration/cruise_speed") / 60.0 * 1.5,
			"…without a jump, because a ramp is tangential where it leaves (ADR 0070)",
			"a %.1f m frame at the rebind" % jumped)
		_expect(berth.taking() == null,
			"…and the exit is spent, so nothing is still holding a destination",
			"the berth is still carrying a route")
		berth.release(scene.ship())

	# LIT, AND CANCELLABLE. "I am pointing at this" and "this is what is going to
	# happen" are different facts, and the second is the one a player docking just
	# before an exit is relying on. Exactly one sign is lit, and clicking it again
	# puts the ship back on the highway.
	scene.ship().position = floor_point
	_step_exploration(scene, 1.0 / 60.0)
	berth.engage(scene.ship(), map.riding())
	var some_exit := road.get_node_or_null("A377BRampOffCForward") as RoadDeck
	berth.take_exit(some_exit)
	_step_exploration(scene, 1.0 / 60.0)
	var glowing := 0
	for sign: ExitSign in signs:
		if sign.is_selected():
			glowing += 1
	_expect(glowing == 1 and map.selected_sign() != null
			and map.selected_sign().ramp == some_exit,
		"exactly one sign is lit, and it is the exit that is going to happen",
		"%d signs lit" % glowing)
	berth.take_exit(null)
	_step_exploration(scene, 1.0 / 60.0)
	_expect(berth.taking() == null and map.selected_sign() == null,
		"…and taking it back stays on the highway, so a choice made in a hurry is not final",
		"the exit could not be cancelled")
	_expect(map.riding() != null and not map.riding().route_name.is_empty(),
		"…and the road has a NAME to stay on, which is what the readout says by default",
		"the road the berth is on is unnamed")

	# NO EXIT OFF THE ONCOMING CARRIAGEWAY. The two share one building with glass down
	# the middle, so the other side's signs are perfectly visible from here — and
	# clicking one would bind the berth to a ramp leaving a road going the other way.
	# Reported from a play session, watching the ship take an exit to its left.
	var wrong_way := 0
	var heading: Vector3 = berth.hold().axis
	var cone := cos(deg_to_rad(Tuning.num("exploration/cruise_turn_clamp_deg")))
	for sign: ExitSign in signs:
		if sign.ramp.path().tangent_at(0.0).dot(heading) < cone:
			wrong_way += 1
	_expect(wrong_way > 0,
		"the oncoming carriageway's exit signs ARE visible from here — they are one building",
		"there is nothing on the other side to exclude")
	# …and none of them can be the live one, whatever the reticle is doing.
	var reachable := true
	for sign: ExitSign in signs:
		if sign.is_aimed() \
				and sign.ramp.path().tangent_at(0.0).dot(heading) < cone:
			reachable = false
	_expect(reachable,
		"…and none of them is ever the live pick, because you could not steer onto it",
		"a sign for a road going the other way was live")
	# A CLOSED EXIT (ADR 0084). The same red barrier that keeps a fighter off an
	# on-ramp now exists at the other end: a road can refuse to let you off it. Today
	# it is driven by the same rule that reddens a portal — which a ship on the road
	# never fails, because a hull with no cruise drive is never on the road at all —
	# so it is closed directly here. What standing will need is the refusal and the
	# two places that honour it, and those are what is under test.
	var shut := road.get_node_or_null("A377BRampOffCForward") as RoadDeck
	if shut != null:
		berth.engage(scene.ship(), map.riding())
		shut.passable = false
		_step_exploration(scene, 1.0 / 60.0)
		var still_live := false
		for sign: ExitSign in signs:
			if sign.ramp == shut and sign.is_aimed():
				still_live = true
		_expect(not still_live,
			"a closed exit's sign is dark — a refusal you find out about after choosing is not a refusal",
			"the sign for a shut exit was still live")
		var offered := road.governing(scene.ship().position,
			map.riding().sample(scene.ship().position).axis, null, Vector2.ZERO)
		_expect(offered != shut,
			"…and the union never hands you a road you may not take",
			"a shut ramp governed the ship")
		# It REFUSES rather than blocks: nothing stops the ship, which would be
		# interdiction with an extra step (ADR 0014).
		var still_moving := scene.ship().speed()
		_step_exploration(scene, 1.0 / 60.0)
		_expect(scene.ship().speed() > still_moving * 0.5,
			"…and nothing stops the ship — a closed exit is a turn you may not take",
			"the ship was slowed by a refusal")
		shut.passable = true
		berth.release(scene.ship())

	# Getting off, through an off-ramp's portal beside a planet.
	var off_ramp := road.get_node_or_null("A377BRampOffCForward") as RoadDeck
	_expect(off_ramp != null, "system C has an off-ramp on the forward deck", "missing")
	var exit_gate := off_ramp.end_portal()
	var exit_travel := off_ramp.path().tangent_at(off_ramp.length())
	scene.ship().position = exit_gate.position - exit_travel * 20.0
	_step_exploration(scene, 1.0 / 60.0)
	scene.ship().position = exit_gate.position + exit_travel * 20.0
	_step_exploration(scene, 1.0 / 60.0)
	_expect(scene.ship().cruise == null and map.riding() == null,
		"flying out an off-ramp's portal drops you back into normal flight",
		"still cruising past the end of the ramp")
	# And it winds DOWN rather than stopping dead.
	_expect(scene.ship().cruise_spool() > 0.5,
		"…still carrying most of its speed on the frame after, not stopped dead",
		"%.0f%% spool" % (scene.ship().cruise_spool() * 100.0))
	for _i in int(Tuning.num("exploration/cruise_spool_down_seconds") * 60.0) + 6:
		_step_exploration(scene, 1.0 / 60.0)
	_expect(is_zero_approx(scene.ship().cruise_spool())
			and is_equal_approx(scene.ship().manual_max_speed(),
				HullClass.max_speed(scene.ship().hull_class)),
		"…and settles back to the hull's own speed once the drive has wound down",
		"%.1f m/s at %.0f%% spool" % [scene.ship().manual_max_speed(),
			scene.ship().cruise_spool() * 100.0])

	# ADR 0060: a portal opens for a cruise drive, and its colour says so.
	scene.ship().set_hull_class(HullClass.Kind.FIGHTER)
	scene.ship().position = gate.position - travel * 20.0
	_step_exploration(scene, 1.0 / 60.0)
	_expect(not gate.permitted,
		"a fighter has no cruise drive, so every portal reads REFUSED (ADR 0060)",
		"the portal showed permitted")
	scene.ship().position = gate.position + travel * 20.0
	_step_exploration(scene, 1.0 / 60.0)
	_expect(scene.ship().cruise == null,
		"…and flying into one does nothing — the refusal was visible before contact",
		"a fighter got onto the road")
	scene.ship().set_hull_class(HullClass.Kind.TAXI)
	_step_exploration(scene, 1.0 / 60.0)
	_expect(gate.permitted,
		"…while a taxi sees the same portal open, on the frame it switches",
		"the portal did not recolour")

	# The strain is applied to the ship by the map, each frame, and released when the
	# ship turns round. Driven through the real nodes rather than the pure library so
	# the wiring is covered too.
	#
	# Note the ship has to be PAST the ceiling, not merely near it: since ADR 0062
	# the warning band inside the edge only paints, and the clamp lives entirely in
	# `bounds_stop_distance` outside it. That split is the easy thing to get wrong.
	scene.ship().position = discs[0].position \
		+ Vector3(0.0, discs[0].ceiling_height() + 40.0, 0.0)
	scene.ship()._velocity = Vector3(0.0, 10.0, 0.0)
	_step_exploration(scene, 1.0 / 60.0)
	_expect(scene.ship().speed_ceiling_scale < 1.0,
		"pushing out past the ceiling strains the ship's speed limit",
		"scale %.2f" % scene.ship().speed_ceiling_scale)
	var strained := scene.ship().manual_max_speed()
	# Same point, opposite heading. The way home is free at any depth (ADR 0062), so
	# this releases without the ship having moved an inch.
	scene.ship()._velocity = Vector3(0.0, -10.0, 0.0)
	_step_exploration(scene, 1.0 / 60.0)
	_expect(is_equal_approx(scene.ship().speed_ceiling_scale, 1.0)
			and scene.ship().manual_max_speed() > strained,
		"…and TURNING ROUND releases it on the spot, without moving back in",
		"scale %.2f" % scene.ship().speed_ceiling_scale)
	# Mid-corridor, four kilometres from either system, nothing is clamped. The
	# boundary following the player across the map is the thing this checks.
	scene.ship().position = link.region().path.point_at(
		link.region().length() * 0.5)
	scene.ship()._velocity = Vector3(0.0, 0.0, 10.0)
	_step_exploration(scene, 1.0 / 60.0)
	_expect(is_equal_approx(scene.ship().speed_ceiling_scale, 1.0),
		"…and nothing is clamped in the middle of the corridor either",
		"scale %.2f" % scene.ship().speed_ceiling_scale)

	# --- leaving a planet (post-test feedback) ---
	# Departing must not hand the ship back at rest pointing at the surface it just
	# left: that starts every visit with the same climb out of the same hole. It
	# leaves on the REFLECTION of its arrival — same bearing, vertical flipped.
	scene.ship().set_hull_class(HullClass.Kind.TAXI)
	scene.ship().position = map.planets()[0].position + Vector3(0.0, 300.0, 0.0)
	scene.ship().look_at(map.planets()[0].global_position, Vector3.FORWARD)
	var descending := -scene.ship().basis.z
	scene.ship().launch_from_dock(Tuning.num("exploration/depart_speed_fraction"))
	var climbing := -scene.ship().basis.z
	_expect(descending.y < 0.0 and climbing.y > 0.0,
		"taking off flips the arrival's vertical: a descent becomes a climb",
		"came in at %.2f, left at %.2f" % [descending.y, climbing.y])
	_expect(absf(climbing.x - descending.x) < 0.01
			and absf(climbing.z - descending.z) < 0.01,
		"…on the same bearing, so it is a reflection rather than a turn",
		"(%.2f, %.2f) became (%.2f, %.2f)" % [descending.x, descending.z,
			climbing.x, climbing.z])
	_expect(scene.ship().speed() > 0.0
			and is_equal_approx(scene.ship().throttle(),
				Tuning.num("exploration/depart_speed_fraction")),
		"…already moving, with the THROTTLE set to match so it is not a shove",
		"%.1f m/s at %.0f%% throttle" % [scene.ship().speed(),
			scene.ship().throttle() * 100.0])

	scene.queue_free()
	await get_tree().process_frame

## The debug roster (POC step 3). What is under test is that the three classes are
## actually three *ships* rather than three top speeds, and that switching between
## them rebuilds everything that follows from the class.
func _test_hull_roster() -> void:
	var ship := Mothership.new()
	add_child(ship)

	# The taxi overrides nothing on purpose: it IS the shared fallback, which is
	# what keeps the roster from disturbing the ship the combat POC was validated
	# on. If this ever fails, adding a class has changed the existing one.
	ship.set_hull_class(HullClass.Kind.TAXI)
	_expect(is_equal_approx(ship.turn_rate_deg_per_sec(),
			Tuning.num("ship/manual_turn_rate_deg_per_sec"))
			and is_equal_approx(ship.accel_seconds(),
				Tuning.num("ship/manual_accel_seconds"))
			and is_equal_approx(ship.hull_scale(), Tuning.num("ship/hull_scale")),
		"the taxi is the shared default and the roster cannot disturb it",
		"turn %.1f, accel %.1f, scale %.2f" % [ship.turn_rate_deg_per_sec(),
			ship.accel_seconds(), ship.hull_scale()])

	var taxi_turn := ship.turn_rate_deg_per_sec()
	var taxi_accel := ship.accel_seconds()
	var taxi_scale := ship.hull_scale()
	var taxi_top := ship.manual_max_speed()

	# A class has to differ in more than one number, or it is a speed setting rather
	# than a ship. These orderings are what makes each one legible in the hand.
	ship.set_hull_class(HullClass.Kind.FIGHTER)
	_expect(ship.manual_max_speed() > taxi_top
			and ship.turn_rate_deg_per_sec() > taxi_turn
			and ship.accel_seconds() < taxi_accel
			and ship.strafe_speed() > Tuning.num("ship/manual_strafe_speed")
			and ship.hull_scale() < taxi_scale,
		"a fighter is faster, turns harder, spools quicker and is smaller",
		"top %.1f turn %.0f accel %.1f scale %.2f" % [ship.manual_max_speed(),
			ship.turn_rate_deg_per_sec(), ship.accel_seconds(), ship.hull_scale()])
	_expect(not ship.has_cruise_drive(),
		"…and has no cruise drive, which is the whole of why no portal opens for it",
		"it has one")

	ship.set_hull_class(HullClass.Kind.CAPITAL)
	_expect(ship.manual_max_speed() < taxi_top
			and ship.turn_rate_deg_per_sec() < taxi_turn
			and ship.accel_seconds() > taxi_accel
			and ship.hull_scale() > taxi_scale,
		"a capital is slower, turns worse, spools longer and is bigger",
		"top %.1f turn %.0f accel %.1f scale %.2f" % [ship.manual_max_speed(),
			ship.turn_rate_deg_per_sec(), ship.accel_seconds(), ship.hull_scale()])
	_expect(ship.has_cruise_drive(),
		"…and does carry the cruise drive", "it does not")

	# Drawn shape is hit shape (ADR 0043). A fighter drawn at a quarter size with a
	# gunboat's hit sphere would be hit from four hull-widths away and nothing
	# anywhere would report it.
	var capital_radius := ship.hit_radius()
	ship.set_hull_class(HullClass.Kind.FIGHTER)
	_expect(ship.hit_radius() < capital_radius,
		"the hit sphere follows the silhouette, not the shared hull scale",
		"fighter %.1f m against capital %.1f m" % [ship.hit_radius(), capital_radius])

	# Switching rebuilds what depends on the class. A bare assignment left the drawn
	# hull at the previous size until something else triggered a hot reload.
	var drawn := (ship.get_node("Hull") as MeshInstance3D).scale.x
	_expect(is_equal_approx(drawn, ship.hull_scale()),
		"switching class resizes the drawn hull immediately",
		"drawn at %.2f, class wants %.2f" % [drawn, ship.hull_scale()])
	ship.free()

	# The roster wraps, so one key reaches every class without a menu.
	var seen := {}
	var kind := HullClass.DEFAULT
	for _i in HullClass.all().size():
		seen[kind] = true
		kind = HullClass.next(kind)
	_expect(seen.size() == HullClass.all().size() and kind == HullClass.DEFAULT,
		"cycling reaches every class and wraps back round",
		"saw %d of %d" % [seen.size(), HullClass.all().size()])

	# The camera boom follows the hull, so what the player compares between classes
	# is how the ship flies rather than how far away it looks.
	var camera := ChaseCamera.new()
	add_child(camera)
	_expect(is_equal_approx(camera.boom_scale, 1.0),
		"a chase camera defaults to an unscaled boom", "%.2f" % camera.boom_scale)
	camera.free()

## The approach envelope (ADR 0012). What is under test is the ADR's two hard rules:
## the sequence never produces a heading, and any input hands the ship back.
func _test_approach_envelope() -> void:
	var host := Node3D.new()
	add_child(host)
	var envelope := ApproachEnvelope.new()
	add_child(envelope)
	envelope.host = host
	var ship := Mothership.new()
	add_child(ship)
	ship.set_process(false)   # stepped by hand below
	var step := 1.0 / 60.0

	# "The envelope always resolves before the surface is reached" — at the FASTEST
	# hull and with no deceleration at all, which is the conservative case. The
	# sequence actually slows the ship, so the real margin is larger.
	var clearance := Tuning.num("exploration/approach_envelope_radius") \
		- Tuning.num("exploration/planet_radius")
	var fastest := HullClass.max_speed(HullClass.Kind.FIGHTER)
	_expect(clearance / fastest > Tuning.num("exploration/approach_seconds"),
		"the countdown always resolves before the surface, even at fighter speed",
		"%.1f s of clearance against a %.1f s countdown" % [clearance / fastest,
			Tuning.num("exploration/approach_seconds")])
	_expect(Tuning.num("exploration/approach_envelope_radius")
			> Tuning.num("exploration/planet_radius"),
		"…and the envelope is outside the planet rather than inside it",
		"envelope %.0f, planet %.0f" % [
			Tuning.num("exploration/approach_envelope_radius"),
			Tuning.num("exploration/planet_radius")])

	# Outside, nothing happens and nothing is constrained.
	ship.position = Vector3(0.0, 0.0, envelope.radius() * 3.0)
	envelope.observe(ship, step)
	_expect(envelope.state() == ApproachEnvelope.State.CLEAR
			and is_equal_approx(envelope.speed_scale(), 1.0),
		"outside the envelope the ship is unconstrained",
		"state %d, scale %.2f" % [envelope.state(), envelope.speed_scale()])

	# Entering locks, and the ceiling walks DOWN rather than the ship being stopped.
	ship.position = Vector3(0.0, 0.0, envelope.radius() * 0.5)
	envelope.observe(ship, step)
	_expect(envelope.state() == ApproachEnvelope.State.LOCKED,
		"entering the envelope starts the sequence", "state %d" % envelope.state())
	# Stepped until the state changes rather than for an exact frame count: at
	# 1/60 s per frame the accumulated float lands a hair under the tuned seconds,
	# and a count derived from it is one frame short.
	var frames := int(Tuning.num("exploration/approach_seconds") / step) + 6
	var previous := envelope.speed_scale()
	var monotonic := true
	for _i in frames:
		envelope.observe(ship, step)
		if envelope.state() != ApproachEnvelope.State.LOCKED:
			break
		if envelope.speed_scale() > previous + 0.0001:
			monotonic = false
		previous = envelope.speed_scale()
	_expect(monotonic,
		"the speed ceiling only ever walks down during an approach — magnitude, "
			+ "never direction (ADR 0012)", "it went back up")
	_expect(envelope.state() == ApproachEnvelope.State.DOCKED,
		"…and the sequence resolves into docked", "state %d" % envelope.state())
	_expect(is_zero_approx(envelope.speed_scale()),
		"…with the ship at rest", "scale %.2f" % envelope.speed_scale())

	# Departing relocks, so the envelope you are sitting in does not pull you back.
	envelope.depart()
	_expect(envelope.state() == ApproachEnvelope.State.RELOCKING,
		"departing relocks rather than re-arming instantly",
		"state %d" % envelope.state())
	envelope.observe(ship, step)
	_expect(envelope.state() == ApproachEnvelope.State.RELOCKING,
		"…and staying inside does not re-arm it either",
		"state %d" % envelope.state())
	for _i in int(Tuning.num("exploration/approach_relock_seconds") / step) + 6:
		envelope.observe(ship, step)
	_expect(envelope.state() == ApproachEnvelope.State.RELOCKING,
		"…it stays relocked until the player has actually left",
		"re-armed while still inside")
	ship.position = Vector3(0.0, 0.0, envelope.radius() * 3.0)
	envelope.observe(ship, step)
	_expect(envelope.state() == ApproachEnvelope.State.CLEAR,
		"…and clears once outside", "state %d" % envelope.state())

	# THE rule of ADR 0012: any input aborts, and the ship is handed straight back.
	# Driven through real Input actions, which work headlessly.
	ship.position = Vector3(0.0, 0.0, envelope.radius() * 0.5)
	envelope.observe(ship, step)
	envelope.observe(ship, step)
	_expect(envelope.state() == ApproachEnvelope.State.LOCKED,
		"the sequence is running again", "state %d" % envelope.state())
	Input.action_press("throttle_up")
	envelope.observe(ship, step)
	Input.action_release("throttle_up")
	_expect(envelope.state() == ApproachEnvelope.State.RELOCKING,
		"any flight input aborts the approach (ADR 0012)",
		"state %d" % envelope.state())
	_expect(is_equal_approx(envelope.speed_scale(), 1.0),
		"…and the ship is unconstrained the same frame — no drag on the way out",
		"scale %.2f" % envelope.speed_scale())

	# THE SECOND LANDING. Reported from a play session: after docking and leaving a
	# planet once, it stopped accepting a landing at all and the ship flew straight
	# through. The cause was the abort reading `Input.get_last_mouse_velocity()`,
	# which is the velocity of the LAST motion event and never decays — one brisk
	# movement, which opening the dock screen is, left it high for ever and aborted
	# every approach on its first frame. The rate is asked of the ship now, and the
	# ship totals the motion it is actually fed.
	#
	# WHAT THIS CAN AND CANNOT PROVE. Headless, the engine's own value reads zero, so
	# no test here could have caught the original defect — it was only ever visible
	# from the seat. What is checked instead is the replacement's defining property:
	# the reading falls to zero on its own, a second landing resolves, and a mouse
	# that is really moving still aborts. If someone reaches for `Input` again, the
	# first of those is what fails.
	ship.position = Vector3(0.0, 0.0, envelope.radius() * 3.0)
	for _i in int(Tuning.num("exploration/approach_relock_seconds") / step) + 6:
		envelope.observe(ship, step)
	_expect(envelope.state() == ApproachEnvelope.State.CLEAR,
		"…and after all that the envelope is armed again", "state %d" % envelope.state())
	# A mouse that moved once and then stopped is a mouse that is not flying. Fed a
	# large motion and then nothing, exactly as a dock screen leaves it.
	ship.add_mouse_steer(Vector2(4000.0, 0.0))
	ship._process(step)
	ship._process(step)
	_expect(is_zero_approx(ship.mouse_speed()),
		"a mouse that moved and then stopped reads as stopped, not as still moving",
		"%.0f px/s after two idle frames" % ship.mouse_speed())
	ship.position = Vector3(0.0, 0.0, envelope.radius() * 0.5)
	for _i in int(Tuning.num("exploration/approach_seconds") / step) + 8:
		envelope.observe(ship, step)
		ship._process(step)
	_expect(envelope.state() == ApproachEnvelope.State.DOCKED,
		"…so the SECOND landing resolves, the same as the first",
		"state %d" % envelope.state())
	# …and the abort still fires for a mouse that really is moving.
	envelope.depart()
	ship.position = Vector3(0.0, 0.0, envelope.radius() * 3.0)
	for _i in int(Tuning.num("exploration/approach_relock_seconds") / step) + 6:
		envelope.observe(ship, step)
	ship.position = Vector3(0.0, 0.0, envelope.radius() * 0.5)
	envelope.observe(ship, step)
	envelope.observe(ship, step)
	ship.add_mouse_steer(Vector2(
		Tuning.num("exploration/approach_abort_mouse_speed") * step * 4.0, 0.0))
	ship._process(step)
	envelope.observe(ship, step)
	_expect(envelope.state() == ApproachEnvelope.State.RELOCKING,
		"…while a mouse that is actually moving still aborts it (ADR 0012)",
		"state %d" % envelope.state())

	# Flying out the far side is not an abort: nothing refused, the geometry just
	# did not resolve. It must clear rather than relock, or passing through a system
	# on your way somewhere else would leave the envelope disarmed behind you.
	for _i in int(Tuning.num("exploration/approach_relock_seconds") / step) + 6:
		ship.position = Vector3(0.0, 0.0, envelope.radius() * 3.0)
		envelope.observe(ship, step)
	ship.position = Vector3(0.0, 0.0, envelope.radius() * 0.5)
	envelope.observe(ship, step)
	_expect(envelope.state() == ApproachEnvelope.State.LOCKED,
		"re-entering after the relock starts a fresh sequence",
		"state %d" % envelope.state())
	ship.position = Vector3(0.0, 0.0, envelope.radius() * 3.0)
	envelope.observe(ship, step)
	_expect(envelope.state() == ApproachEnvelope.State.CLEAR,
		"flying out the far side clears rather than relocking — nothing was refused",
		"state %d" % envelope.state())

	ship.free()
	envelope.free()
	host.free()
