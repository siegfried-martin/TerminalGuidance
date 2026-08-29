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
## Step 6 is under way: `G` mans the gun station (ADR 0048), and all four of its
## weapons are live — the autocannon, the hitscan pulse beam, the unguided missile
## with its blast, and the blockers. Component damage is a pool now rather than a
## hit count (ADR 0049), because four weapons with four damage numbers cannot share
## a counter.
##
## Step 5 is finished: splash damage landed with the unguided missile's warhead and
## the ridden missile now uses the same falloff (ADR 0004, `scripts/lib/damage.gd`).
## Half of step 7 is in too: the target answers an incoming missile with a star of
## flares, on a roll of `enemy/blocker_chance` (ADR 0051).
##
## Step 6 is complete: the launch tube has its cooldown, which is what makes
## success criterion 2 — "still choosing to fire, never stuck waiting" — a question
## with an answer at all.
##
## Steps 7 and 8 are in as well: the target answers missiles with flares, and on a
## long telegraphed timer it sends one guided missile at the player — **the
## interrupt**. The player is invulnerable for this build at the human's direction
## (`ship/invulnerable`): hits are counted and flashed but cost nothing, so a pacing
## reading is not mixed with a difficulty one.
##
## Deliberately absent: death, respawn and the PiP toggle (step 9), and ship damage,
## which is the same single tuning flip.
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
## The engagement envelope, measured instead of eyeballed. See EnvelopeMeter — this
## is the first link in the exploration numbers chain and it has been deferred four
## times because it reads like a chore for a human. It is a high-water mark.
var _envelope := EnvelopeMeter.new()
var _turret: Turret
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
	# The interrupt needs someone to aim at. Without this the layer stays silent,
	# which is also what `enemy/interrupt_interval_seconds = 0` does.
	_target.player = _ship
	_target.interrupt_warned.connect(_on_interrupt_warned)
	_target.interrupt_launched.connect(_on_interrupt_launched)


func _build_views() -> void:
	var ship_camera := ChaseCamera.new()
	ship_camera.name = "ShipCamera"
	ship_camera.far = 20000.0
	add_child(ship_camera)

	var missile_camera := ChaseCamera.new()
	missile_camera.name = "MissileCamera"
	missile_camera.far = 20000.0
	add_child(missile_camera)

	var turret_camera := ChaseCamera.new()
	turret_camera.name = "TurretCamera"
	turret_camera.far = 20000.0
	add_child(turret_camera)

	# The station lives in arena space, not on the ship, so the hull can rotate
	# under it without dragging the aim around (ADR 0020 and Turret's header).
	# Added after the Mothership so it reads a mount point the ship has already
	# moved this frame rather than one frame of stale position.
	_turret = Turret.new()
	_turret.name = "Turret"
	_turret.ship = _ship
	_arena_root.add_child(_turret)
	# The guns are told what they can reach rather than looking it up, so a shot
	# fired into a torn-down arena cannot resurrect it.
	_turret.setup(_arena_root, _target, _rocks)

	_views = ViewController.new()
	_views.name = "ViewController"
	add_child(_views)
	_views.setup(_ship, ship_camera, missile_camera, _turret, turret_camera)

	_overlay = FlightOverlay.new()
	_overlay.name = "FlightOverlay"
	_overlay.target = _target
	_overlay.missile_provider = func() -> Missile: return _views.piloted_missile()
	_overlay.turret_provider = func() -> Turret: return _turret
	_overlay.ship = _ship
	_overlay.enemy = _target
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
	_hud.add_row("job", func() -> String:
		return "%s  ·  %s has the ship" % [
			_views.role_name(), "autopilot" if _ship.autopilot else "you"])
	_hud.add_row("class", func() -> String:
		return "%s  ·  %.1f m/s top  ·  cruise drive %s" % [
			HullClass.name_of(_ship.hull_class).to_upper(),
			_ship.manual_max_speed(),
			"yes" if _ship.has_cruise_drive() else "NO — no portal opens"])
	_hud.add_row("flight", func() -> String:
		if _ship.autopilot:
			return "AUTOPILOT  ·  %.0f m/s  ·  %.0f m under the target" % [
				_ship.speed(), _ship.depth_below_target()]
		return "MANUAL  ·  throttle %3.0f%%  ·  %.0f m/s of %.0f" % [
			_ship.throttle() * 100.0, _ship.speed(), _ship.manual_max_speed()])
	_hud.add_row("turret", func() -> String:
		return "%s  ·  loadout %d  ·  L %s / R %s" % [
			"MANNED" if _turret.active else "unmanned",
			_turret.loadout(),
			Turret.weapon_label(_turret.primary()),
			Turret.weapon_label(_turret.secondary())])
	_hud.add_row("gun aim", func() -> String:
		return "%+.0f deg bearing  ·  %+.0f deg elevation" % [
			_turret.azimuth_degrees(), _turret.elevation_degrees()])
	_hud.add_row("interrupt", func() -> String:
		var due := _target.seconds_to_interrupt()
		if due < 0.0:
			return "off — enemy/interrupt_interval_seconds is 0"
		var state := "  WARNED" if _target.interrupt_warned_already() else ""
		return "%.0f s of %.0f%s" % [
			due, Tuning.num("enemy/interrupt_interval_seconds"), state])
	_hud.add_row("hull", func() -> String:
		if _ship.is_invulnerable():
			return "INVULNERABLE  ·  %d hits taken" % _ship.hits_taken()
		return "%.0f of %.0f hp  ·  %d hits taken" % [
			_ship.hp(), Tuning.num("ship/hp"), _ship.hits_taken()])
	_hud.add_row("tube", func() -> String:
		if _ship.missile_ready():
			return "READY"
		return "reloading — %.1f s of %.0f" % [
			_ship.missile_cooldown_remaining(),
			Tuning.num("ship/missile_cooldown_seconds")])
	_hud.add_row("blockers", func() -> String:
		var mine := "ready" if _turret.blocker_ready() \
			else "%.1f s" % _turret.blocker_cooldown_remaining()
		var theirs := "ready" if _target.blocker_cooldown_remaining() <= 0.0 \
			else "%.1f s" % _target.blocker_cooldown_remaining()
		return "mine %s (%d flares thrown)  ·  theirs %s at %.0f%%" % [
			mine, _turret.flares_thrown(), theirs,
			Tuning.num("enemy/blocker_chance") * 100.0])
	_hud.add_row("unguided", func() -> String:
		var reload := _turret.unguided_reload_remaining()
		var state := "IN FLIGHT — click to detonate" if _turret.unguided_in_flight() \
			else ("+1 in %.0f s" % reload if reload > 0.0 else "magazine full")
		return "%d of %d  ·  %s" % [
			_turret.unguided_remaining(),
			Tuning.integer("turret/unguided_magazine"), state])
	_hud.add_row("guns", func() -> String:
		var beam := "OVERHEATED %.1f s" % _turret.overheat_remaining() \
			if _turret.is_overheated() else "heat %3.0f%%" % (_turret.heat() * 100.0)
		return "%d rounds fired  ·  %s  ·  %s" % [
			_turret.rounds_fired(),
			"cannon ready" if _turret.autocannon_ready() else "cannon %.2f s" \
				% _turret.autocannon_cooldown_remaining(),
			beam])
	_hud.add_row("components", func() -> String:
		var total := _target.component_count()
		if total == 0:
			return "none — hull only"
		var parts: PackedStringArray = []
		for i in total:
			parts.append("×" if not _target.is_component_alive(i)
				else "%.0f%%" % (_target.component_health_fraction(i) * 100.0))
		return "%d of %d alive at %.0f hp  [%s]" % [
			_target.components_alive(), total,
			_target.component_hit_points(), " ".join(parts)])
	_hud.add_row("aim off", func() -> String:
		var missile := _views.piloted_missile()
		return "—" if missile == null else "%.0f deg" % missile.aim_offset_degrees())
	_hud.add_row("standoff", func() -> String:
		return "%.0f m held / %.0f m tuned  ·  %.0f m deep / %.0f tuned" % [
			_ship.range_to_target(), Tuning.num("ship/standoff_distance"),
			_ship.depth_below_target(), Tuning.num("ship/arc_depth")])
	# THE reading the exploration layer is waiting on (CLAUDE.md §Session hygiene).
	# It sizes the system disc, and disc height is 5-10x it "so the ceiling never
	# enters a fight" — which is why the vertical figure is reported separately from
	# the span rather than being inferred from it.
	_hud.add_row("envelope", func() -> String: return _envelope.summary())
	_hud.add_row("last", func() -> String: return _last_outcome)
	_hud.add_row("keys", func() -> String:
		match _views.view():
			ViewController.View.MISSILE:
				return "W boost · S brake · A/D dodge · mouse aims · Space/LMB detonate · F1 hud · F2 tune"
			ViewController.View.TURRET:
				return "mouse aims · LMB/RMB fire · 1/2 loadout · Q missile · T take the helm · F1 hud · F2 tune"
		return "W/S throttle · A/D thrusters · mouse steers · Q missile · G guns · R reverse arc · H hull · F1 hud · F2 tune")


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

## Feed the envelope meter. Ships and steered things only: a gun round is a stream
## rather than a participant, and its reach is already a tuned constant.
##
## Everything here is in `_arena_root`'s frame, which is what makes the reading
## survive a floating-origin recentre — the meter measures distances BETWEEN
## participants and never a distance from an origin (ADR 0020).
func _process(_delta: float) -> void:
	var points: Array[Vector3] = []
	if _ship != null and is_instance_valid(_ship):
		points.append(_ship.position)
	if _target != null and is_instance_valid(_target):
		points.append(_target.position)
	for group in ["player_missile", EnemyMissile.GROUP]:
		for node in get_tree().get_nodes_in_group(group):
			var flyer := node as Node3D
			if flyer != null and is_instance_valid(flyer):
				points.append(flyer.position)
	_envelope.observe(points)


func _unhandled_input(event: InputEvent) -> void:
	# With the tuning panel open the pointer belongs to the UI, so a click in the
	# game area must not also launch or detonate a missile.
	if DebugPanel.is_open():
		if event.is_action_pressed("quit"):
			get_tree().quit()
		return

	# Q launches, and nothing else does. It used to share a button with detonate,
	# which meant one key meant two things depending on where you were standing;
	# now launching has a key of its own and Space/LMB only ever ends a ride. Q
	# works from EITHER station (ADR 0056 supersedes ADR 0048's helm-only clause) —
	# see `fire()` for why that does not break sequential attention.
	if _views.view() == ViewController.View.MISSILE:
		if event.is_action_pressed("detonate"):
			detonate_current()
	elif event.is_action_pressed("fire_missile"):
		fire()
	# The turret's own weapons are held rather than clicked, so they are polled in
	# its `_process` and there is nothing to do for them on the event.

	if event.is_action_pressed("quit"):
		get_tree().quit()
	elif event.is_action_pressed("debug_toggle_hud"):
		_hud.toggle()
		_overlay.visible = _hud.visible
	elif event.is_action_pressed("debug_reload_tuning"):
		Tuning.reload()
	elif event.is_action_pressed("debug_reverse_arc"):
		_ship.reverse_arc()
	# The speed ladder is per hull class (ADR 0059), and the classes only mean
	# anything felt back to back. This is the exploration POC's debug roster arriving
	# early, because "is 15.5 m/s the right taxi speed" is the anchor for every
	# number downstream of it and is answerable in the arena that already exists.
	elif event.is_action_pressed("debug_cycle_hull"):
		# Through the setter, so the silhouette changes with the class rather than
		# staying at the previous one's size until the next hot reload.
		_ship.set_hull_class(HullClass.next(_ship.hull_class))
	elif event.is_action_pressed("loadout_1"):
		_turret.set_loadout(1)
	elif event.is_action_pressed("loadout_2"):
		_turret.set_loadout(2)
	# T and G pick a job rather than toggling anything (ADR 0056). The autopilot
	# follows from the choice, so there is no separate key for it any more.
	elif event.is_action_pressed("role_pilot"):
		_views.set_role(ViewController.Role.PILOT)
	elif event.is_action_pressed("role_gunner"):
		_views.set_role(ViewController.Role.GUNNER)


## Launch along the ship's current heading and ride it.
##
## Fired from **either** station. ADR 0048 originally allowed it only from the helm,
## on sequential-attention grounds; under the crew roster that reasoning no longer
## holds and the rule became actively wrong. Launching moves the player *into* the
## missile in the same frame, so they are never on two things at once — and with the
## autopilot bound to the roster (ADR 0056), a helm-only launch would force the
## gunner to take the helm first, dropping the autopilot every single time they
## wanted to fire. The ride ends back at whichever station they left.
##
## Refused for two reasons, and they are different ones: only one missile is ridden
## at a time (which falls out of riding), and the tube has a cooldown (`Mothership`).
func fire() -> Missile:
	if _views.piloted_missile() != null:
		return null
	if not _ship.missile_ready():
		return null

	var missile := Missile.new()
	missile.name = "Missile"
	_arena_root.add_child(missile)
	missile.launch(_ship.muzzle_position(), _ship.basis, _ship.velocity(),
		_target, _target.radius, _rocks)
	missile.detonated.connect(_on_missile_detonated)

	_ship.note_missile_launched()
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
	elif reason == Missile.EndReason.FLARE_INTERCEPT:
		_last_outcome = "BLOCKED by a flare at %.0f m" % missile.distance_to_target()
	else:
		_last_outcome = "fuse expired at %.0f m" % missile.distance_to_target()

	# Drawn at exactly the radius the warhead damaged, so the blast cannot look
	# bigger than it reached (ADR 0049's rule, and ADR 0041's before it).
	var flash := DetonationFlash.new()
	flash.name = "Flash"
	_arena_root.add_child(flash)
	flash.position = missile.position
	flash.setup(
		Tuning.num("missile/flash_start_radius"),
		Tuning.num("missile/splash_radius"),
		Tuning.num("missile/flash_seconds"),
		Tuning.color("missile/flash_color" if hit else "missile/flash_color_dud"))

	if reason == Missile.EndReason.IMPACT:
		pass  # the target's own hit points, death and respawn are still step 9


## A component going up borrows the missile's detonation flash, at the human's
## direction — a real secondary explosion is art, and this is gray-box (ADR 0030).
## The darkening hit gets no flash: the shade change is the feedback, and a flash
## on both would make the two outcomes read the same.
## The telegraph. Raised BEFORE the launch, not at it — see `TargetShip._tick_interrupt`.
func _on_interrupt_warned() -> void:
	_last_outcome = "MISSILE LAUNCH DETECTED"
	if _overlay != null:
		_overlay.alert_text = "MISSILE LAUNCH DETECTED"
		_overlay.alert_seconds = Tuning.num("hud/alert_seconds")


func _on_interrupt_launched(missile: EnemyMissile) -> void:
	missile.ended.connect(_on_interrupt_ended)


func _on_interrupt_ended(_missile: EnemyMissile, reason: int, where: Vector3) -> void:
	match reason:
		EnemyMissile.EndReason.HIT_SHIP:
			_last_outcome = "SHIP HIT (%d total)" % _ship.hits_taken()
		EnemyMissile.EndReason.SHOT_DOWN:
			_last_outcome = "incoming missile SHOT DOWN"
		EnemyMissile.EndReason.FLARE_INTERCEPT:
			_last_outcome = "incoming missile blocked by a flare"
		_:
			_last_outcome = "incoming missile timed out"

	if reason == EnemyMissile.EndReason.HIT_SHIP:
		return
	var flash := DetonationFlash.new()
	flash.name = "InterceptFlash"
	_arena_root.add_child(flash)
	flash.position = where
	flash.setup(
		Tuning.num("turret/impact_flash_start_radius"),
		Tuning.num("turret/impact_flash_end_radius"),
		Tuning.num("turret/impact_flash_seconds"),
		Tuning.color("turret/impact_flash_color"))


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
		Tuning.num("missile/splash_radius"),
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


## The envelope reading, for tests and for whatever eventually writes it down.
func envelope() -> EnvelopeMeter:
	return _envelope


func turret() -> Turret:
	return _turret
