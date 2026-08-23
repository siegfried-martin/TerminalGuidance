extends Node3D
## The sandbox scene. Everything visible here is constructed in code from
## tuning.cfg — the .tscn is an empty shell holding this script and nothing
## else. That is the project's scene policy: the editor is a viewer, and a
## scene diff should never be the place a design decision hides.
##
## This is not the combat POC. It is the harness the POC gets built inside:
## a gray-box arena, a debug camera, the hot-reload loop and the HUD, all
## proven to work end to end from the command line.

const PROBE_MESH := preload("res://assets/models/probe.obj")
const HULL_TEXTURE := preload("res://assets/textures/hull_panels.png")

var _arena: GrayBoxArena
var _camera: FreeCamera
var _hud: DebugHud
var _probe: MeshInstance3D
var _probe_material: StandardMaterial3D
var _elapsed: float = 0.0


func _ready() -> void:
	_build_environment()
	_build_lights()
	_build_arena()
	_build_probe()
	_build_camera()
	_build_hud()
	Tuning.reloaded.connect(_apply_tuning)
	_apply_tuning()


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = Tuning.flag("arena/glow_enabled")
	env.glow_intensity = Tuning.num("arena/glow_intensity")

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)


func _build_lights() -> void:
	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.light_color = Color(1.0, 0.96, 0.9)
	add_child(key)

	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.light_color = Color(0.42, 0.56, 0.78)
	add_child(fill)


func _build_arena() -> void:
	_arena = GrayBoxArena.new()
	_arena.name = "Arena"
	add_child(_arena)


func _build_probe() -> void:
	_probe_material = StandardMaterial3D.new()
	_probe_material.albedo_texture = HULL_TEXTURE
	_probe_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	_probe = MeshInstance3D.new()
	_probe.name = "Probe"
	_probe.mesh = PROBE_MESH
	_probe.material_override = _probe_material
	add_child(_probe)


func _build_camera() -> void:
	_camera = FreeCamera.new()
	_camera.name = "DebugCamera"
	_camera.current = true
	_camera.far = 8000.0
	_camera.look_at_from_position(
		Tuning.vec3("camera/start_position"), Tuning.vec3("camera/start_look_at"), Vector3.UP)
	add_child(_camera)


func _build_hud() -> void:
	_hud = DebugHud.new()
	_hud.name = "DebugHud"
	add_child(_hud)
	_hud.add_row("fps", func() -> String: return str(Engine.get_frames_per_second()))
	_hud.add_row("cam pos", func() -> String: return "%.1f, %.1f, %.1f" % [
		_camera.global_position.x, _camera.global_position.y, _camera.global_position.z])
	_hud.add_row("cam speed", func() -> String: return "%.1f m/s" % _camera.speed_mps())
	_hud.add_row("markers", func() -> String: return str(_arena.marker_count()))
	_hud.add_row("arena", func() -> String: return "+/- %.0f m" % _arena.extent())
	_hud.add_row("keys", func() -> String:
		return "RMB look · WASD/QE move · Shift boost · F1 hud · F5 reload · Esc quit")


func _apply_tuning() -> void:
	var world_env := get_node("WorldEnvironment") as WorldEnvironment
	var env := world_env.environment
	env.background_color = Tuning.color("arena/background_color")
	env.ambient_light_color = Tuning.color("arena/background_color").lightened(0.35)
	env.ambient_light_energy = Tuning.num("arena/ambient_energy")
	var key := get_node("KeyLight") as DirectionalLight3D
	key.light_energy = Tuning.num("arena/key_light_energy")
	key.rotation_degrees = Tuning.vec3("arena/key_light_angles_deg")
	var fill := get_node("FillLight") as DirectionalLight3D
	fill.light_energy = Tuning.num("arena/fill_light_energy")
	fill.rotation_degrees = Tuning.vec3("arena/fill_light_angles_deg")

	_probe.scale = Vector3.ONE * Tuning.num("probe/scale")
	_probe_material.albedo_color = Tuning.color("probe/hull_tint")
	_probe_material.metallic = Tuning.num("probe/metallic")
	_probe_material.roughness = Tuning.num("probe/roughness")


func _process(delta: float) -> void:
	_elapsed += delta
	_probe.rotation.y = deg_to_rad(Tuning.num("probe/spin_deg_per_sec")) * _elapsed
	var period := Tuning.num("probe/bob_period_sec")
	if period > 0.0:
		_probe.position.y = sin(TAU * _elapsed / period) * Tuning.num("probe/bob_amplitude")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quit"):
		get_tree().quit()
	elif event.is_action_pressed("debug_toggle_hud"):
		_hud.toggle()
	elif event.is_action_pressed("debug_reload_tuning"):
		Tuning.reload()
