class_name ExplorationScene
extends Node3D
## The travel layer's POC scene (`docs/EXPLORATION_POC_IMPLEMENTATION.md`).
##
## Build step 6: two systems joined by the local leg, with the highway laid inside
## the corridor. Everything is constructed here from tuning (ADR 0027); the `.tscn`
## is a shell.
##
## **Both ways of making the crossing now exist at once**, which is the point. Step 5
## measured the hand-flown leg at 258 s in a taxi; the road does it in 41. The road
## did not replace the corridor — it was laid inside it, so declining the portal is
## still a real choice and success criterion 2 has something to be judged against
## rather than a memory of it.
##
## **Only the pilot exists here.** Every station is a person who keeps doing their
## job while the player is elsewhere, and the existing autopilot already is that for
## the helm — but this is not a combat POC, so there is no turret, no gunner, and no
## crew roster to switch between. The `ViewController` is deliberately absent: with
## one station there is no state machine, and adding one now would be inventing a
## problem to solve.
##
## Also absent, and coming with the steps that need them: missiles and the launch
## tube, fuel (step 7), the third system and the trunk leg (step 8), traffic
## (steps 9-10).

## The map: systems, corridors, planets, docking, and the one composed boundary.
var _map: SystemMap
var _ship: Mothership
var _camera: ChaseCamera
var _hud: DebugHud
## The steering reticle. The ship's nose does not go instantly where the stick says
## (ADR 0035), and on a road inside a steering cone that lag is the difference
## between holding a line and guessing at one.
var _overlay: FlightOverlay
var _dock: DockScreen
## Everything in map space hangs off one node, so the floating origin is a move of
## this and nothing else has to know (ADR 0020). At 7.5 km centre to centre the
## precision is not yet a problem — the invariant is kept because retrofitting it
## once systems assume a fixed origin is what costs.
var _root: Node3D
## The dock screen's refuel row. Held so its label can say what a fill would cost
## before it is pressed — a service that reports nothing back is one the player has
## to press to find out whether it did anything.
var _refuel: Button
## How many times the debug teleport has been used this session, and where the last
## one went. Kept so the HUD can say so permanently: a jump makes every travel figure
## on the screen untrue, and this POC exists to read travel figures.
var _teleports: int = 0
var _last_teleport: String = ""


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

	_map = SystemMap.new()
	_map.name = "SystemMap"
	_root.add_child(_map)
	_map.arrived.connect(_on_arrived)
	_map.departed.connect(_on_departed)

	_dock = DockScreen.new()
	_dock.name = "DockScreen"
	add_child(_dock)
	_dock.departed.connect(func() -> void: _map.depart())
	# POC step 7's row on the screen step 4 built as a list for exactly this. Free,
	# because an economy is explicitly out of this POC's scope — what is under test is
	# whether the gauge gets CHECKED before a route, not what a tankful is worth.
	_refuel = _dock.add_service("Refuel cruise tank", _do_refuel, true)


func _build_ship() -> void:
	_ship = Mothership.new()
	_ship.name = "Ship"
	_root.add_child(_ship)
	# The player has the helm and keeps it. There is no other station to be at, so
	# the autopilot — which is what happens when nobody is flying — never runs.
	_ship.set_autopilot(false)
	_ship.piloted = true
	# Started in system A, on the combat plane, back from the aperture and facing
	# down the leg — so the first thing on screen is the way out of the system and
	# the trip that is being measured. The map owns the rule, because the debug
	# teleport has to land the ship the same way a fresh run does.
	_map.place_ship(_ship, 0)

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

	# Its own layer, above the world and below the dock screen, exactly as the arena
	# stacks it. The tube gauge is off: there is no launch tube here, and a reload
	# bar for a weapon that cannot fire is decoration that lies.
	var overlay_layer := CanvasLayer.new()
	overlay_layer.name = "OverlayLayer"
	add_child(overlay_layer)
	_overlay = FlightOverlay.new()
	_overlay.name = "FlightOverlay"
	_overlay.ship = _ship
	_overlay.show_tube = false
	_overlay.reticle_provider = func() -> Node3D:
		return null if _map.is_docked() else _ship
	overlay_layer.add_child(_overlay)

	# THE DEBUG TELEPORT, and it is the FIRST row on purpose. Every travel figure
	# below it stops being a reading the moment a jump is made, and this POC exists to
	# read travel figures — so the warning sits above them rather than under them.
	_hud.add_row("teleport", func() -> String:
		if not Tuning.flag("exploration/debug_teleport_enabled"):
			return "disabled  ·  travel times this session are a reading"
		if _teleports == 0:
			return "J jumps to the next system  ·  unused, travel times are a reading"
		return "USED %d ×  ·  last: %s  ·  TRAVEL TIMES THIS SESSION ARE NOT A READING" % [
			_teleports, _last_teleport])
	_hud.add_row("class", func() -> String:
		return "%s  ·  %.0f m/s top  ·  cruise drive %s" % [
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
	# THE CRUISE TANK (POC step 7). Level, and the thing the level is actually for —
	# how much highway is left in it. ADR 0017 asks for the cost of a route to be
	# legible while the route is being chosen, and metres of road are what a player
	# compares against a map; units are only what they are counted in.
	_hud.add_row("fuel", func() -> String:
		var tank := _ship.cruise_tank
		if tank.is_dry():
			return "TANK DRY  ·  every portal is red  ·  on the road you coast at " \
				+ "hull speed  ·  refuel at any planet"
		var left := tank.range_metres()
		return "%.1f / %.0f units  ·  %.0f%%  ·  %s of highway  ·  %.2f per km" % [
			tank.units, tank.capacity, tank.fraction() * 100.0,
			"unlimited" if is_inf(left) else "%.1f km" % (left / 1000.0),
			Tuning.num("exploration/cruise_fuel_per_km")])
	# Where the player is, in the map's own words. This is the step-5 row: the whole
	# question is what four kilometres of hand-flown corridor feels like, and that
	# starts with knowing whether you have left yet.
	_hud.add_row("where", func() -> String:
		return _map.place_of(_ship_in_map()))
	# The road. This is step 6's row: whether cruise is running, which deck, and how
	# much of the leg is left — the last one because the third checkpoint asks
	# whether a 41-second hop is worth the portal, and that is a question about time.
	_hud.add_row("road", func() -> String:
		var lane := _ship.cruise
		if lane == null:
			var winding := _ship.cruise_spool()
			if winding > 0.001:
				return "OFF THE ROAD  ·  drive winding down, %.0f%% left" % (
					winding * 100.0)
			if not _ship.has_cruise_drive():
				return "no cruise drive — every portal is red (ADR 0060)"
			return "off the road  ·  fly a portal to engage"
		# DRY, AND STILL ON THE ROAD. The road does not drop you when the tank empties
		# (ADR 0086), so this state has to be said out loud — a speed that falls with
		# nothing else on the HUD changing reads as a bug rather than as a fuel state.
		if _ship.is_coasting_dry():
			return "DRY ON THE ROAD  ·  %s  ·  %.0f m left  ·  drive winding down, " % [
				lane.deck_name, lane.metres_remaining] \
				+ "coasting at hull speed"
		# Stopped on the road there is no "at this speed", so the row quotes the
		# ceiling instead. An ETA of `inf` is not a reading, it is a division.
		var moving := _ship.speed() > 0.1
		var reference := _ship.speed() if moving else _ship.manual_max_speed()
		var seconds := 0.0 if reference <= 0.001 else lane.metres_remaining / reference
		var spool := _ship.cruise_spool()
		# No deck side is reported. It used to say "upper" or "lower", which was the
		# deck convention's mistake-catcher; right-hand traffic retired the convention
		# (ADR 0077) and `deck_name` already says which road this is and where it goes.
		return "CRUISE %s ·  %s  ·  %.0f m left  ·  %.0f s %s" % [
			"SPOOLING %.0f%%  " % (spool * 100.0) if spool < 0.999 else " ",
			lane.deck_name, lane.metres_remaining, seconds,
			"at this speed" if moving else "at full throttle"]
	)
	# THE BERTH. Its own row rather than a word on the road row, because the offer has
	# to be readable at a glance while the player is settling onto the roadway, and
	# because "you are being carried" is a different fact about the ship than "you are
	# on this road" (ADR 0082).
	_hud.add_row("berth", func() -> String:
		var berth := _map.berth()
		if berth.is_offered():
			return "ROADWAY BELOW  ·  press C to dock  ·  %.0f%% of cruise, C again to leave" % (
				Tuning.num("exploration/berth_speed_fraction") * 100.0)
		if not berth.is_berthed():
			return "—"
		var hold := berth.hold()
		if hold == null:
			return "DOCKED"
		var settling := "settling, %.0f m off the rail" % hold.error \
			if hold.error > 1.0 else "on the rail"
		return "DOCKED  ·  %s  ·  %.0f m/s  ·  %s  ·  C to leave" % [
			hold.deck_name, hold.speed, settling]
	)
	# WHAT HAPPENS IF YOU DO NOTHING. While berthed this is the only thing telling the
	# player the road is theirs to redirect, and it is why the default is a sentence
	# rather than a dash: "stay on highway A-377B" says both what will happen and that
	# something else could (ADR 0083).
	_hud.add_row("route", func() -> String:
		if not _map.berth().is_berthed():
			return "—"
		var riding := _map.riding()
		var staying := "stay on highway %s" % riding.route_name \
			if riding != null and not riding.route_name.is_empty() \
			else "stay on this road"
		var taken := _map.selected_sign()
		var aimed := _map.aimed_sign()
		if taken != null:
			return "%s  ·  %s to cancel" % [taken.label_text.to_upper(),
				"click it again" if aimed == taken else "look back at the sign"]
		if aimed != null:
			return "%s  ·  click to take %s instead" % [staying.to_upper(),
				aimed.label_text]
		return "%s  ·  look at an exit sign and click to take it" % staying.to_upper()
	)
	# Lane position, stated as metres rather than as a bar. The lane boundary is soft
	# and the penalty is proportional, so "how far out am I" is the number that
	# explains why the speed row is reading low.
	_hud.add_row("lane", func() -> String:
		var lane := _ship.cruise
		if lane == null:
			return "—"
		var past := lane.edge_distance()
		if past <= 0.0:
			return "in lane  ·  %+.0f m across, %+.0f m up  ·  %.0f m to the edge" % [
				lane.lateral, lane.vertical, -past]
		return "OUT OF LANE  ·  %.0f m past  ·  speed limit at %.0f%%, pushed back" % [
			past, (lane.top_speed() / maxf(lane.base_speed, 0.001)) * 100.0]
	)
	# Where the nearest way on or off is, and whether it will open. The colour is the
	# whole of the answer (ADR 0060); this row is for reading it from the terminal
	# while tuning, not a second channel the player is meant to need.
	_hud.add_row("portal", func() -> String:
		var here := _ship_in_map()
		var nearest := _map.nearest_portal(here)
		if nearest == null:
			return "—"
		# The label already says TO or FROM. Prefixing it again reads "to TO SYSTEM B".
		var refused := "REFUSED — no cruise drive" if not _ship.has_cruise_drive() \
			else "REFUSED — cruise tank dry"
		return "%s  ·  %.0f m  ·  %s" % [
			nearest.destination if not nearest.destination.is_empty() else "portal",
			here.distance_to(nearest.position),
			"OPEN" if nearest.permitted else refused]
	)
	# THE step-5 number. The leg at this hull's top speed is the baseline the
	# highway has to beat in step 6, and it is worth reading before flying it as well
	# as during — a figure the player predicted and then lived through is a much
	# stronger verdict than one they only lived through.
	_hud.add_row("leg", func() -> String:
		var here := _ship_in_map()
		var next := _map.nearest_system(here)
		var onward := next + 1 if next + 1 < _map.systems().size() else next - 1
		if onward < 0:
			return "—"
		# The road's own speed rather than the ship's ceiling right now: mid-spool the
		# ceiling is somewhere between hull and cruise, and quoting the leg against it
		# gives a number that is true of no journey. What this row is for is the
		# comparison — by road against by hand — and both halves have to be the speed
		# the trip is actually made at.
		var by_road := Tuning.num("exploration/cruise_speed")
		var by_hand := HullClass.max_speed(_ship.hull_class)
		var span := _map.system_center(next).distance_to(_map.system_center(onward))
		if by_road <= 0.0 or by_hand <= 0.0:
			return "—"
		# AND WHAT IT COSTS. ADR 0017's forbid is that travel time and fuel cost must
		# be visible "at the moment the player would point the ship" — this row is that
		# moment, so the price of the leg ahead belongs on it rather than being worked
		# out from the gauge and a distance.
		var tank := _ship.cruise_tank
		return "%s to %s: %.0f m  ·  %.0f s by road, %.0f s by hand  ·  %.1f fuel, %s" % [
			_map.system_name(next), _map.system_name(onward), span,
			span / by_road, span / by_hand, tank.cost_for(span),
			"tank covers it" if tank.covers(span) else "TANK IS SHORT"]
	)
	# How far there is left to go, either way. Off-road travel with no map is the
	# control condition, not a puzzle — the POC is testing whether the crossing is
	# worth making, not whether it can be navigated blind.
	_hud.add_row("route", func() -> String:
		var here := _ship_in_map()
		var parts := PackedStringArray()
		for i in _map.systems().size():
			parts.append("%s %.0f m" % [_map.system_name(i),
				here.distance_to(_map.system_center(i))])
		return "  ·  ".join(parts))
	_hud.add_row("system", func() -> String:
		var disc := _map.systems()[maxi(_map.nearest_system(_ship_in_map()), 0)]
		return "%.0f m across  ·  %.0f m tall (%.0f up / %.0f down)  ·  %d aperture" % [
			disc.radius() * 2.0, disc.height(),
			disc.ceiling_height(), disc.floor_depth(), disc.aperture_count()])
	_hud.add_row("altitude", func() -> String:
		return "%+.0f m  ·  %.0f m of open space to the nearest edge" % [
			_ship.position.y,
			_map.field().distance_to_edge(_ship_in_map())])
	# The telegraph, in words as well as in red. A timer the player cannot see is not
	# a telegraph.
	_hud.add_row("bounds", func() -> String:
		var overshoot := _map.field().overshoot(_ship_in_map())
		if overshoot <= 0.0:
			if _map.warning() <= 0.0:
				return "clear"
			return "NEARING THE EDGE  ·  %.0f%%" % (_map.warning() * 100.0)
		var rate := BoundaryField.damage_per_second(_map.seconds_outside(),
			Tuning.num("exploration/bounds_grace_seconds"),
			Tuning.num("exploration/bounds_damage_ramp_seconds"),
			Tuning.num("exploration/bounds_damage_per_second"))
		if rate <= 0.0:
			return "OUTSIDE  ·  %.0f m past  ·  %.1f s of grace left" % [overshoot,
				Tuning.num("exploration/bounds_grace_seconds")
					- _map.seconds_outside()]
		return "OUTSIDE  ·  %.0f m past  ·  taking %.0f hp/s" % [overshoot, rate])
	# Damage means nothing while the ship cannot be hurt, and the bounds row above
	# reports an hp/s rate whether or not it costs anything. Saying so here keeps that
	# from reading as a lie during a session where the flag is on.
	_hud.add_row("hull", func() -> String:
		if Tuning.flag("ship/invulnerable"):
			return "INVULNERABLE  ·  boundary damage is counted, not taken"
		return "%.0f hp" % Tuning.num("ship/hp"))
	# The clamp is heading-proportional (ADR 0062), so this row has to say what the
	# ship is doing as well as how hard it is being held: at the same point in the
	# red, straight out is stopped, along the edge is halved, and back in is free.
	_hud.add_row("strain", func() -> String:
		if is_equal_approx(_ship.speed_ceiling_scale, 1.0):
			return "—"
		return "speed limit at %.0f%%  ·  heading is %.0f%% outbound" % [
			_ship.speed_ceiling_scale * 100.0, _map.outbound() * 100.0])
	_hud.add_row("approach", func() -> String:
		var approach := _map.active_approach(_ship_in_map())
		return "—" if approach == null else approach.state_label())
	_hud.add_row("markers", func() -> String:
		return "%d across the map" % _map.marker_count())
	_hud.add_row("keys", func() -> String:
		return "W/S throttle · A/D thrusters · mouse steers · C berth · H hull · " \
			+ "J teleport · F1 hud · F2 tune")


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

## The ship, in the map's frame. Every boundary question is asked in that frame, and
## with more than one system the ship and the map's contents are no longer siblings.
func _ship_in_map() -> Vector3:
	return _map.to_local(_ship.global_position)


func _process(delta: float) -> void:
	_map.observe(_ship, delta)
	_ship.speed_ceiling_scale = _map.speed_scale()
	# On the road the camera frames the ROAD, not the nose, and the ship yaws inside
	# the frame (ADR 0057). With the camera on the nose, steering left and the road
	# curving left look identical and the player has nothing to hold a line against.
	# The SLEWED road axis, not the lane's raw one: the camera and the nose are held
	# against the same vector, so a bend or a handover can never move one without the
	# other (ADR 0072).
	_camera.heading_override = Vector3.ZERO if _ship.cruise == null \
		else _ship.road_axis()


## Arriving takes the helm, because there is nowhere to fly from a docked ship. The
## sequence never took the stick on the way in — it only capped what the throttle
## could reach — so this is the first moment control actually changes hands, and it
## happens after the countdown the player watched, not before it.
func _on_arrived(place: String) -> void:
	_ship.piloted = false
	_label_refuel()
	_dock.open(place)


## What a fill would do, said before it is pressed and again after. A service button
## whose label never changes is one the player has to press to find out whether it
## did anything, which is the same failure as a screen that lies.
func _label_refuel() -> void:
	if _refuel == null or _ship == null:
		return
	var tank := _ship.cruise_tank
	_refuel.text = "Cruise tank full (%.0f units)" % tank.capacity \
		if tank.fraction() >= 0.999 \
		else "Refuel cruise tank (%.0f → %.0f units)" % [tank.units, tank.capacity]


func _do_refuel() -> void:
	_ship.cruise_tank.fill()
	_label_refuel()


## Leaving takes off rather than releasing the controls where they were. The ship
## arrived pointing down at a surface, and handing it back at rest in that attitude
## makes every departure start with the same climb out of the same hole. It leaves on
## the reflection of its arrival instead — see `Mothership.launch_from_dock`.
func _on_departed() -> void:
	_dock.close()
	_ship.piloted = true
	_ship.launch_from_dock(Tuning.num("exploration/depart_speed_fraction"))
	_apply_mouse_mode()


## The pointer steers the ship, and is released only for the tuning panel. With one
## station there is nothing else it could be doing.
func _apply_mouse_mode() -> void:
	if DebugPanel.is_open() or (_map != null and _map.is_docked()):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if DebugPanel.is_open() or _map.is_docked():
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
	elif event.is_action_pressed("debug_teleport"):
		teleport_onward()


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


## THE DEBUG TELEPORT (POC step 7, item 13). It exists so fuel limits and route
## choices can be tested without flying every leg — the trunk is eighteen kilometres
## and testing it twice by hand is a nine-minute round trip.
##
## It jumps to the NEXT system rather than to the nearest, which the POC doc's wording
## asks for: the nearest system is almost always the one the ship is standing in, and
## a key that usually does nothing is a key that gets pressed twice. Cycling reaches
## every system on the map, including the two on the crossing highway.
##
## Every use is counted, printed, and carried on the HUD's first row for the rest of
## the session. A silent teleport contaminates a travel-time verdict, and this POC's
## first success criterion is a travel-time verdict.
func teleport_onward() -> void:
	if not Tuning.flag("exploration/debug_teleport_enabled"):
		return
	var count := _map.systems().size()
	if count <= 1:
		return
	var next := (maxi(_map.nearest_system(_ship_in_map()), 0) + 1) % count
	_map.warp_to_system(_ship, next)
	_teleports += 1
	_last_teleport = "%s at %.0f s" % [_map.system_name(next),
		Time.get_ticks_msec() / 1000.0]
	print("[debug] teleport %d — to %s" % [_teleports, _last_teleport])


## How many jumps have been made this session. For the gate, which asserts that the
## teleport is loud rather than that it moved the ship.
func teleport_count() -> int:
	return _teleports


func map() -> SystemMap:
	return _map


func dock_screen() -> DockScreen:
	return _dock


func ship() -> Mothership:
	return _ship
