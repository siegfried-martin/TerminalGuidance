class_name ApproachEnvelope
extends Node3D
## The way you arrive somewhere: fly into it, and it resolves (ADR 0012).
##
## Built once and mounted on anything you can dock with. The planet is its first
## host (POC step 4); the stations on the portals' entrance and exit ramps get the
## same node in step 6, which is where the fuel, market and customs content
## actually lives. One mechanism, several placements.
##
## **Nothing here steers the ship.** ADR 0012 says *"No auto-steer, ever, for any
## reason, in any system"* and then *"any sequence that moves the ship must abort on
## any player input"* — which reads like a contradiction until you notice it is the
## same distinction the system boundary already makes: **magnitude, never
## direction.** The sequence brings the ship to rest *along the vector the player
## was already flying*, by walking its speed ceiling down to zero, and there is no
## code path in it that can produce a heading. That is why it reuses
## `Mothership.speed_ceiling_scale` rather than touching velocity: the mechanism
## makes the guarantee, and a comment would only have promised it.
##
## The lock is not a commitment either. Any flight input aborts it and the ship
## carries on with the throttle it had — so the envelope is a place you may pass
## through, not a trap laid where you were flying.

signal locked
signal aborted
signal arrived
signal departed

enum State { CLEAR, LOCKED, DOCKED, RELOCKING }

## What is being docked with. The envelope is centred on it and sized from tuning.
var host: Node3D

var _state: State = State.CLEAR
## Counts up while locked, and down while relocking.
var _timer: float = 0.0
## Three orthogonal rings marking the threshold. See `_ready` for why not a shell.
var _shell: Node3D
var _speed_scale: float = 1.0


func _ready() -> void:
	# THREE RINGS, NOT A SPHERE. The first build drew the envelope as a translucent
	# shell, and a rendered frame showed why that is wrong: from just outside, an
	# 840 m sphere fills the entire view and everything behind it — the planet, the
	# disc, the markers — is seen through a coloured filter. That is not a signpost,
	# it is a tint. Rings mark exactly the same boundary, are unmistakably a
	# threshold rather than a fog, and leave the view alone.
	_shell = Node3D.new()
	_shell.name = "Rings"
	add_child(_shell)
	for i in 3:
		var ring := MeshInstance3D.new()
		ring.name = "Ring%d" % i
		ring.mesh = TorusMesh.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# Seen from outside on the way in and from inside once through; it has to
		# read both times or the player cannot tell which side of it they are on.
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		ring.material_override = mat
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_shell.add_child(ring)
	# Three orthogonal planes, so the boundary reads as a sphere from any bearing
	# rather than as a hoop that vanishes when approached edge-on.
	(_shell.get_child(1) as Node3D).rotation_degrees = Vector3(90.0, 0.0, 0.0)
	(_shell.get_child(2) as Node3D).rotation_degrees = Vector3(0.0, 0.0, 90.0)
	rebuild()
	Tuning.reloaded.connect(rebuild)


func rebuild() -> void:
	var thickness := maxf(Tuning.num("exploration/approach_ring_thickness"), 0.1)
	for child in _shell.get_children():
		var mesh := (child as MeshInstance3D).mesh as TorusMesh
		mesh.inner_radius = maxf(radius() - thickness, 0.05)
		mesh.outer_radius = radius() + thickness
		mesh.rings = 72
		mesh.ring_segments = 6
	_paint(0.0)


## Run the envelope for this frame. Returns nothing; read `state()` and
## `speed_scale()` after. The caller composes the scale with whatever else is
## constraining the ship, rather than this writing it — two systems both assigning
## the same field would silently fight, and the loser would be whichever ran last.
func observe(ship: Mothership, delta: float) -> void:
	_speed_scale = 1.0
	if ship == null or not is_instance_valid(ship) or host == null:
		return
	# Global rather than parent-relative: with more than one system on the map the
	# ship and the host are no longer siblings, and comparing two different frames
	# is the kind of bug that reads as "docking is broken at system B only".
	var range_to_host := ship.global_position.distance_to(host.global_position)
	var inside := range_to_host <= radius()
	_paint(clampf(1.0 - (range_to_host - radius()) / maxf(radius(), 1.0), 0.0, 1.0))

	match _state:
		State.CLEAR:
			if inside:
				_state = State.LOCKED
				_timer = 0.0
				locked.emit()
		State.LOCKED:
			if not inside:
				# Flown out the far side without touching anything. Not an abort —
				# nothing was refused, the geometry simply did not resolve.
				_state = State.CLEAR
				_timer = 0.0
				return
			if _has_flight_input(ship):
				abort()
				return
			_timer += delta
			var seconds := maxf(Tuning.num("exploration/approach_seconds"), 0.01)
			# Magnitude only. The ship comes to rest along the vector it was already
			# flying, and this function has no way to express a different one.
			_speed_scale = clampf(1.0 - _timer / seconds, 0.0, 1.0)
			if _timer >= seconds:
				_state = State.DOCKED
				_timer = 0.0
				arrived.emit()
		State.DOCKED:
			_speed_scale = 0.0
		State.RELOCKING:
			_timer = maxf(_timer - delta, 0.0)
			# Only re-arm once the player has actually left, so departing does not
			# put them straight back into the sequence they just walked out of.
			if _timer <= 0.0 and not inside:
				_state = State.CLEAR


## Any flight input at all breaks the lock (ADR 0012). Mouse motion counts, above a
## threshold — a hand resting on a desk must not abort an approach, and a hand that
## has decided to fly somewhere else must.
##
## The mouse rate is asked of the SHIP rather than of `Input`. The engine's
## `get_last_mouse_velocity()` is the velocity of the last motion event and does not
## decay: once the mouse has been moved briskly — opening the dock screen does it —
## the reading stays high for ever, so every approach after the first was aborted on
## its first frame and the planet stopped accepting a landing at all. The ship totals
## the motion events it is fed and the total falls to zero on its own.
func _has_flight_input(ship: Mothership) -> bool:
	for action in ["throttle_up", "throttle_down", "strafe_left", "strafe_right",
			"aim_left", "aim_right", "aim_up", "aim_down", "boost", "brake"]:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			return true
	return ship.mouse_speed() \
		> Tuning.num("exploration/approach_abort_mouse_speed")


## Break the lock and hand the ship back. The player keeps the throttle they had:
## the sequence never took it, it only capped what the throttle could reach.
func abort() -> void:
	if _state != State.LOCKED:
		return
	_state = State.RELOCKING
	_timer = Tuning.num("exploration/approach_relock_seconds")
	_speed_scale = 1.0
	aborted.emit()


## Leave. Same relock as an abort, so the envelope you are sitting in the middle of
## does not immediately pull you back in.
func depart() -> void:
	if _state != State.DOCKED:
		return
	_state = State.RELOCKING
	_timer = Tuning.num("exploration/approach_relock_seconds")
	_speed_scale = 1.0
	departed.emit()


## Faint at range so the envelope is a visible place before it is a commitment, and
## brighter as it is neared. The pressure rule wants this: an approach the player
## chose, saw before committing to, and can still turn out of.
func _paint(nearness: float) -> void:
	var color := Tuning.color("exploration/approach_color")
	color.a = lerpf(Tuning.num("exploration/approach_alpha_far"),
		Tuning.num("exploration/approach_alpha_near"), clampf(nearness, 0.0, 1.0))
	for child in _shell.get_children():
		((child as MeshInstance3D).material_override as StandardMaterial3D) \
			.albedo_color = color


func radius() -> float:
	return Tuning.num("exploration/approach_envelope_radius")


func state() -> State:
	return _state


func is_docked() -> bool:
	return _state == State.DOCKED


## What to multiply the ship's speed ceiling by. 1 unless the sequence is running.
func speed_scale() -> float:
	return _speed_scale


## Seconds left on the countdown, for the HUD. The player watches this run.
func seconds_left() -> float:
	if _state != State.LOCKED:
		return 0.0
	return maxf(Tuning.num("exploration/approach_seconds") - _timer, 0.0)


func state_label() -> String:
	match _state:
		State.LOCKED:
			return "APPROACH  ·  %.1f s  ·  any input aborts" % seconds_left()
		State.DOCKED:
			return "DOCKED"
		State.RELOCKING:
			return "clear  ·  re-arms in %.1f s" % _timer
	return "clear"
