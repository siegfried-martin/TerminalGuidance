class_name ExplorationScene
extends Node3D
## The travel layer's POC scene (`docs/EXPLORATION_POC_IMPLEMENTATION.md`).
##
## Build step 2: one system disc with a planet, flown by hand. Everything is
## constructed here from tuning (ADR 0027); the `.tscn` is a shell.
##
## **Only the pilot exists here.** Every station is a person who keeps doing their
## job while the player is elsewhere, and the existing autopilot already is that for
## the helm — but this is not a combat POC, so there is no turret, no gunner, and no
## crew roster to switch between. The `ViewController` is deliberately absent: with
## one station there is no state machine, and adding one now would be inventing a
## problem to solve.
##
## Also absent, and coming with the steps that need them: missiles and the launch
## tube (there is nothing to shoot and nothing to disable in a tube yet), the
## approach envelope and docking (step 4), roads and portals (step 6).

var _system: SystemDisc
var _planet: Planet
var _ship: Mothership
var _camera: ChaseCamera
var _hud: DebugHud
## Everything in system space hangs off one node, so the floating origin is a move
## of this and nothing else has to know (ADR 0020). The disc, the planet and the
## ship are all its children — including the boundary, which is why leaning on a
## ceiling is unaffected by where the world happens to be centred.
var _root: Node3D


func _ready() -> void:
	_build_environment()
	_build_lights()
	_build_world()
	_build_ship()
	_build_hud()
	Tuning.reloaded.connect(_apply_tuning)
	_apply_tuning()
	# The tuning panel takes the pointer while it is open; hand it back after.
	DebugPanel.toggled.connect(func(open: bool) -> void:
		if not open:
			_apply_mouse_mode())
	_apply_mouse_mode()


# --- construction ------------------------------------------------------------

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


func _build_world() -> void:
	_root = Node3D.new()
	_root.name = "SystemRoot"
	add_child(_root)

	_system = SystemDisc.new()
	_system.name = "SystemDisc"
	_root.add_child(_system)

	_planet = Planet.new()
	_planet.name = "Planet"
	_root.add_child(_planet)


func _build_ship() -> void:
	_ship = Mothership.new()
	_ship.name = "Ship"
	_root.add_child(_ship)
	# The player has the helm and keeps it. There is no other station to be at, so
	# the autopilot — which is what happens when nobody is flying — never runs.
	_ship.set_autopilot(false)
	_ship.piloted = true
	# Started on the combat plane, well inside the disc, facing out across it so the
	# first thing on screen is the volume rather than the floor.
	_ship.position = Vector3(0.0, 0.0, _system.radius() * 0.45)

	_camera = ChaseCamera.new()
	_camera.name = "ChaseCamera"
	_camera.subject = _ship
	_camera.tuning_prefix = "camera/ship"
	_camera.boom_scale = _ship.hull_scale()
	add_child(_camera)
	_camera.snap()
	_camera.current = true


func _build_hud() -> void:
	_hud = DebugHud.new()
	_hud.name = "DebugHud"
	add_child(_hud)

	_hud.add_row("class", func() -> String:
		return "%s  ·  %.1f m/s top  ·  cruise drive %s" % [
			HullClass.name_of(_ship.hull_class).to_upper(),
			_ship.manual_max_speed(),
			"yes" if _ship.has_cruise_drive() else "NO — no portal opens"])
	_hud.add_row("handling", func() -> String:
		return "%.0f deg/s turn  ·  %.1f s to full / %.1f s to stop  ·  %.0f m/s strafe" % [
			_ship.turn_rate_deg_per_sec(), _ship.accel_seconds(),
			_ship.brake_seconds(), _ship.strafe_speed()])
	_hud.add_row("flight", func() -> String:
		return "throttle %3.0f%%  ·  %.0f m/s of %.0f" % [
			_ship.throttle() * 100.0, _ship.speed(), _ship.manual_max_speed()])
	# How long this hull takes to cross its own system, which is the number the
	# ladder was built to make meaningful and the one step 3 is really asking about.
	_hud.add_row("crossing", func() -> String:
		var top := _ship.manual_max_speed()
		if top <= 0.0:
			return "—"
		var seconds := _system.radius() * 2.0 / top
		return "%.0f s across the disc at full throttle  (%.1f min)" % [
			seconds, seconds / 60.0])
	# The disc, stated as the three things it decomposes into (ADR 0061) rather than
	# as one height, because that is how it is tuned.
	_hud.add_row("system", func() -> String:
		return "%.0f m across  ·  %.0f m tall (%.0f up / %.0f down)" % [
			_system.radius() * 2.0, _system.height(),
			_system.ceiling_height(), _system.floor_depth()])
	_hud.add_row("altitude", func() -> String:
		return "%+.0f m  ·  %.0f m to the nearer face" % [
			_ship.position.y,
			DiscBounds.distance_to_face(_ship.position.y,
				_system.ceiling_height(), _system.floor_depth())])
	# The telegraph, in words as well as in red. A timer the player cannot see is
	# not a telegraph, and this POC is where the treatment gets read for the first
	# time — it has never been built before.
	_hud.add_row("bounds", func() -> String:
		var overshoot := DiscBounds.overshoot(_ship.position.y,
			_system.ceiling_height(), _system.floor_depth())
		if overshoot <= 0.0:
			if _system.warning() <= 0.0:
				return "clear"
			return "APPROACHING A FACE  ·  %.0f%%" % (_system.warning() * 100.0)
		var rate := DiscBounds.damage_per_second(_system.seconds_outside(),
			Tuning.num("exploration/bounds_grace_seconds"),
			Tuning.num("exploration/bounds_damage_ramp_seconds"),
			Tuning.num("exploration/bounds_damage_per_second"))
		if rate <= 0.0:
			return "OUTSIDE  ·  %.0f m past  ·  %.1f s of grace left" % [overshoot,
				Tuning.num("exploration/bounds_grace_seconds")
					- _system.seconds_outside()]
		return "OUTSIDE  ·  %.0f m past  ·  taking %.0f hp/s" % [overshoot, rate])
	# Damage means nothing while the ship cannot be hurt, and the bounds row above
	# reports an hp/s rate whether or not it costs anything. Saying so here keeps
	# that from reading as a lie during a session where the flag is on.
	_hud.add_row("hull", func() -> String:
		if Tuning.flag("ship/invulnerable"):
			return "INVULNERABLE  ·  boundary damage is counted, not taken"
		return "%.0f hp" % Tuning.num("ship/hp"))
	_hud.add_row("strain", func() -> String:
		if is_equal_approx(_ship.speed_ceiling_scale, 1.0):
			return "—"
		return "outbound speed limit at %.0f%%" % (_ship.speed_ceiling_scale * 100.0))
	_hud.add_row("planet", func() -> String:
		return "%.0f m below  ·  r %.0f  ·  %.0f m away" % [
			-_planet.position.y, _planet.radius(),
			_ship.position.distance_to(_planet.position)])
	_hud.add_row("markers", func() -> String:
		return "%d in the disc" % _system.marker_count())
	_hud.add_row("keys", func() -> String:
		return "W/S throttle · A/D thrusters · mouse steers · H cycles hull · F1 hud · F2 tune")


func _apply_tuning() -> void:
	var env := (get_node("WorldEnvironment") as WorldEnvironment).environment
	env.background_color = Tuning.color("arena/background_color")
	env.ambient_light_color = Tuning.color("arena/background_color").lightened(0.35)
	env.ambient_light_energy = Tuning.num("arena/ambient_energy")
	env.glow_enabled = Tuning.flag("arena/glow_enabled")
	env.glow_intensity = Tuning.num("arena/glow_intensity")

	var key := get_node("KeyLight") as DirectionalLight3D
	key.light_energy = Tuning.num("arena/key_light_energy")
	key.rotation_degrees = Tuning.vec3("arena/key_light_angles_deg")
	var fill := get_node("FillLight") as DirectionalLight3D
	fill.light_energy = Tuning.num("arena/fill_light_energy")
	fill.rotation_degrees = Tuning.vec3("arena/fill_light_angles_deg")


# --- flight ------------------------------------------------------------------

func _process(delta: float) -> void:
	_system.apply_to(_ship, delta)


## The pointer steers the ship, and is released only for the tuning panel. With one
## station there is nothing else it could be doing.
func _apply_mouse_mode() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if DebugPanel.is_open() \
		else Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if DebugPanel.is_open():
		return
	if event is InputEventMouseMotion:
		_ship.add_mouse_steer((event as InputEventMouseMotion).relative)
		return
	if event.is_action_pressed("quit"):
		get_tree().quit()
	elif event.is_action_pressed("debug_toggle_hud"):
		_hud.toggle()
	elif event.is_action_pressed("debug_reload_tuning"):
		Tuning.reload()
	elif event.is_action_pressed("debug_cycle_hull"):
		cycle_hull()


## The debug roster (POC step 3). Instant, because the whole point is feeling the
## classes back to back — a transition would put the thing being compared behind an
## animation. The camera boom follows the hull so the ship stays the same size on
## screen and what changes is how it flies, not how far away it looks.
##
## Velocity is deliberately left alone. Switching from a fighter at 38 m/s into a
## capital that tops out at 11 does not teleport or snap the ship: `_fly_manual`
## limits to the new maximum on the next frame, so the ship bleeds down to its new
## class the way it would if the throttle had been pulled. That is a truthful answer
## rather than a special case.
func cycle_hull() -> void:
	_ship.set_hull_class(HullClass.next(_ship.hull_class))
	_camera.boom_scale = _ship.hull_scale()


func system() -> SystemDisc:
	return _system


func planet() -> Planet:
	return _planet


func ship() -> Mothership:
	return _ship
