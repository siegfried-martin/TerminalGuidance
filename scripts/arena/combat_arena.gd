extends Node3D
## The combat POC arena — build order steps 3 and 4.
##
## In scope here: the gray-box arena, the mothership under its one autopilot
## behaviour, one dumb target, and the missile (launch, chase cam, steering,
## fuse). This is the first feel checkpoint: success criterion 1, the 8 seconds.
##
## Step 5 has since landed in part: early detonate, boost, brake and a cooldown
## dodge (ADR 0039), plus rocks that kill a missile on contact (ADR 0038). Splash
## damage is still outstanding, because it needs the target to have hit points.
##
## Two things here are outside the POC scope doc as written, both at the human's
## explicit direction: manual ship flight (ADR 0040), which that doc always called
## a scope deferral rather than a decision, and destructible components on the
## target (ADR 0042), which front-runs part of step 9's hit feedback. The target
## ship itself still has no hit points and never dies — that is still step 9.
##
## Deliberately absent, in build order: splash damage (step 5); turret mode and the
## missile cooldown (step 6); blockers, enemy fire and ship HP (step 7); the
## interrupt (step 8); death/respawn and the PiP toggle (step 9).
## Do not add them here ahead of their step — each one has a feel checkpoint
## attached to it and adding it early destroys the reading.
##
## Everything is constructed from tuning values and rebuilt on hot reload
## (ADR 0027). The scene file is an empty shell.

var _arena_root: Node3D
var _lattice: GrayBoxArena
var _rocks: ReferenceField
var _ship: Mothership
var _target: TargetShip
var _views: ViewController
var _hud: DebugHud
var _overlay: FlightOverlay

var _shots: int = 0
var _hits: int = 0
var _last_outcome: String = "—"


func _ready() -> void:
	_build_environment()
	_build_lights()
	_build_world()
	_build_ships()
	_build_views()
	_build_hud()
	Tuning.reloaded.connect(_apply_tuning)
	_apply_tuning()


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
	# Everything that lives in arena space hangs off one node. When the floating
	# origin lands, recentring is a move of this node and nothing else has to know
	# (ADR 0020).
	_arena_root = Node3D.new()
	_arena_root.name = "ArenaRoot"
	add_child(_arena_root)

	_lattice = GrayBoxArena.new()
	_lattice.name = "Lattice"
	_arena_root.add_child(_lattice)

	_rocks = ReferenceField.new()
	_rocks.name = "Rocks"
	_arena_root.add_child(_rocks)


func _build_ships() -> void:
	_target = TargetShip.new()
	_target.name = "Target"
	_arena_root.add_child(_target)
	_target.set_drift_direction(Vector3(0.4, 0.0, 1.0))
	_target.component_damaged.connect(_on_component_damaged)

	_ship = Mothership.new()
	_ship.name = "Mothership"
	_arena_root.add_child(_ship)
	_ship.target = _target
	_ship.position = Vector3(0.0, 0.0, 1.0)   # a bearing; the standoff comes from tuning
	_ship.snap_to_standoff()


func _build_views() -> void:
	var ship_camera := ChaseCamera.new()
	ship_camera.name = "ShipCamera"
	ship_camera.far = 20000.0
	add_child(ship_camera)

	var missile_camera := ChaseCamera.new()
	missile_camera.name = "MissileCamera"
	missile_camera.far = 20000.0
	add_child(missile_camera)

	_views = ViewController.new()
	_views.name = "ViewController"
	add_child(_views)
	_views.setup(_ship, ship_camera, missile_camera)

	_overlay = FlightOverlay.new()
	_overlay.name = "FlightOverlay"
	_overlay.target = _target
	_overlay.missile_provider = func() -> Missile: return _views.piloted_missile()
	var overlay_layer := CanvasLayer.new()
	overlay_layer.name = "OverlayLayer"
	overlay_layer.layer = 90   # under the debug HUD, which is 100
	add_child(overlay_layer)
	overlay_layer.add_child(_overlay)


func _build_hud() -> void:
	_hud = DebugHud.new()
	_hud.name = "DebugHud"
	add_child(_hud)
	_hud.add_row("view", func() -> String: return _views.view_name())
	_hud.add_row("fuse", func() -> String:
		var missile := _views.piloted_missile()
		return "—" if missile == null else "%.2f s" % missile.fuse_remaining())
	_hud.add_row("missile", func() -> String:
		var missile := _views.piloted_missile()
		return "—" if missile == null else "%.0f m/s" % missile.speed())
	_hud.add_row("to target", func() -> String:
		var missile := _views.piloted_missile()
		if missile != null:
			return "%.0f m" % missile.distance_to_target()
		return "%.0f m (ship)" % _ship.position.distance_to(_target.position))
	_hud.add_row("shots", func() -> String:
		var rate := 0.0 if _shots == 0 else 100.0 * float(_hits) / float(_shots)
		return "%d fired · %d hit · %.0f%%" % [_shots, _hits, rate])
	_hud.add_row("boost", func() -> String:
		var missile := _views.piloted_missile()
		if missile == null:
			return "—"
		var state := ""
		if missile.is_boosting():
			state = "  BOOST"
		elif missile.is_braking():
			state = "  BRAKE"
		return "%.2f s left%s" % [missile.boost_remaining(), state])
	_hud.add_row("dodge", func() -> String:
		var missile := _views.piloted_missile()
		if missile == null:
			return "—"
		if missile.is_dodging():
			return "DODGING"
		var cooldown := missile.dodge_cooldown_remaining()
		return "ready" if cooldown <= 0.0 else "%.2f s" % cooldown)
	_hud.add_row("rocks", func() -> String:
		return "%d rocks · %d lobes · %d hittable" % [
			_rocks.rock_count(), _rocks.lobe_count(), _rocks.hittable_count()])
	_hud.add_row("flight", func() -> String:
		if _ship.autopilot:
			return "AUTOPILOT  ·  %.0f m/s" % _ship.speed()
		return "MANUAL  ·  throttle %3.0f%%  ·  %.0f m/s of %.0f" % [
			_ship.throttle() * 100.0, _ship.speed(), _ship.manual_max_speed()])
	_hud.add_row("components", func() -> String:
		var total := _target.component_count()
		if total == 0:
			return "none — hull only"
		var parts: PackedStringArray = []
		for i in total:
			parts.append("×" if not _target.is_component_alive(i)
				else str(_target.component_hits(i)))
		return "%d of %d alive  [%s]" % [
			_target.components_alive(), total, " ".join(parts)])
	_hud.add_row("aim off", func() -> String:
		var missile := _views.piloted_missile()
		return "—" if missile == null else "%.0f deg" % missile.aim_offset_degrees())
	_hud.add_row("standoff", func() -> String:
		return "%.0f m held / %.0f m tuned" % [
			_ship.range_to_target(), Tuning.num("ship/standoff_distance")])
	_hud.add_row("last", func() -> String: return _last_outcome)
	_hud.add_row("keys", func() -> String:
		if _views.view() == ViewController.View.MISSILE:
			return "W boost · S brake · A/D dodge · mouse/stick aims · Space/LMB detonate · F1 hud · F2 tune"
		if _ship.autopilot:
			return "LMB/Space fire · T fly manually · R reverse arc · F1 hud · F2 tune · F5 reload · Esc quit"
		return "W/S throttle · A/D thrusters · mouse steers · LMB/Space fire · T autopilot · F1 hud · F2 tune")


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


# --- firing ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# With the tuning panel open the pointer belongs to the UI, so a click in the
	# game area must not also launch or detonate a missile.
	if DebugPanel.is_open():
		if event.is_action_pressed("quit"):
			get_tree().quit()
		return

	# The same button fires and detonates; which one it means depends on the view.
	# Riding a missile, the only thing left to decide is when it ends.
	if _views.view() == ViewController.View.MISSILE:
		if event.is_action_pressed("detonate"):
			detonate_current()
	elif event.is_action_pressed("fire"):
		fire()

	if event.is_action_pressed("quit"):
		get_tree().quit()
	elif event.is_action_pressed("debug_toggle_hud"):
		_hud.toggle()
		_overlay.visible = _hud.visible
	elif event.is_action_pressed("debug_reload_tuning"):
		Tuning.reload()
	elif event.is_action_pressed("debug_reverse_arc"):
		_ship.reverse_arc()
	elif event.is_action_pressed("toggle_autopilot"):
		_ship.set_autopilot(not _ship.autopilot)
		# Manual flight steers with the mouse, so handing the ship over changes who
		# owns the pointer. Nothing else can change that without a view change.
		_views.refresh_mouse_mode()


## Launch along the ship's current heading and ride it. One missile at a time —
## that falls out of riding, and is not a cooldown. Cooldown is step 6.
func fire() -> Missile:
	if _views.piloted_missile() != null:
		return null

	var missile := Missile.new()
	missile.name = "Missile"
	_arena_root.add_child(missile)
	missile.launch(_ship.muzzle_position(), _ship.basis, _ship.velocity(),
		_target, _target.radius, _rocks)
	missile.detonated.connect(_on_missile_detonated)

	_shots += 1
	_views.enter_missile_view(missile)
	return missile


## End the ride early. Returns true if there was a missile to end.
func detonate_current() -> bool:
	var missile := _views.piloted_missile()
	if missile == null:
		return false
	missile.detonate_early()
	return true


func _on_missile_detonated(missile: Missile, reason: int, hit: bool) -> void:
	if hit:
		_hits += 1
		_last_outcome = "HIT"
	elif reason == Missile.EndReason.EARLY_DETONATE:
		_last_outcome = "detonated at %.0f m" % missile.distance_to_target()
	elif reason == Missile.EndReason.ROCK_IMPACT:
		_last_outcome = "hit a rock at %.0f m" % missile.distance_to_target()
	else:
		_last_outcome = "fuse expired at %.0f m" % missile.distance_to_target()

	var flash := DetonationFlash.new()
	flash.name = "Flash"
	_arena_root.add_child(flash)
	flash.position = missile.position
	flash.setup(
		Tuning.num("missile/flash_start_radius"),
		Tuning.num("missile/flash_end_radius"),
		Tuning.num("missile/flash_seconds"),
		Tuning.color("missile/flash_color" if hit else "missile/flash_color_dud"))

	if reason == Missile.EndReason.IMPACT:
		pass  # the target's own hit points, death and respawn are still step 9


## A component going up borrows the missile's detonation flash, at the human's
## direction — a real secondary explosion is art, and this is gray-box (ADR 0030).
## The darkening hit gets no flash: the shade change is the feedback, and a flash
## on both would make the two outcomes read the same.
func _on_component_damaged(index: int, where: Vector3, destroyed: bool) -> void:
	_last_outcome = "component %d %s" % [index, "DESTROYED" if destroyed else "damaged"]
	if not destroyed:
		return
	var flash := DetonationFlash.new()
	flash.name = "ComponentFlash"
	_arena_root.add_child(flash)
	flash.position = where
	flash.setup(
		Tuning.num("missile/flash_start_radius"),
		Tuning.num("missile/flash_end_radius"),
		Tuning.num("missile/flash_seconds"),
		Tuning.color("missile/flash_color"))


# --- readouts for the headless gate ------------------------------------------

func shots_fired() -> int:
	return _shots


func hits() -> int:
	return _hits


func ship() -> Mothership:
	return _ship


func target() -> TargetShip:
	return _target


func views() -> ViewController:
	return _views
