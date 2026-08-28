class_name FlightOverlay
extends Control
## Screen-space instruments: where the target is, where the reticle is, and where
## the gun is pointed.
##
## The first two exist because the ship no longer points at the target (ADR 0034)
## and the missile no longer goes instantly where the stick says (ADR 0035).
## Without the indicator the player cannot find the target after launch; without
## the reticle they cannot see the turn they have asked for and have not got yet.
## The crosshair is the turret's, and means something different from both — see
## `_draw_crosshair`.
##
## Drawn against whichever camera is current, so it follows the view state machine
## without needing to know about it.

var target: Node3D
## Returns the missile currently being flown, or null.
var missile_provider: Callable = func() -> Missile: return null
## Returns the gun station while it is manned, or null.
var turret_provider: Callable = func() -> Turret: return null
## The ship, for the launch tube's reload gauge and the impact flash.
var ship: Mothership
## The target, for the interrupt's telegraph.
var enemy: TargetShip
## Seconds of alert still to show. Set by the arena when the warning is raised;
## counted down here so it survives the missile it is warning about.
var alert_seconds: float = 0.0
var alert_text: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A Control parented straight to a CanvasLayer has no parent Control to
	# resolve anchors against, so PRESET_FULL_RECT leaves it at zero size and
	# everything that reads `size` silently clamps into a degenerate rect. Set
	# the rect from the viewport instead, and keep it in step with resizes.
	_match_viewport()
	get_viewport().size_changed.connect(_match_viewport)


func _match_viewport() -> void:
	position = Vector2.ZERO
	size = get_viewport().get_visible_rect().size


func _process(delta: float) -> void:
	_process_alert(delta)
	queue_redraw()


func _draw() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	_draw_target_indicator(camera)
	_draw_reticle(camera)
	_draw_crosshair(camera)
	_draw_tube()
	_draw_alert(camera)
	_draw_hit_flash()


# --- target indicator --------------------------------------------------------

func _draw_target_indicator(camera: Camera3D) -> void:
	if target == null or not is_instance_valid(target):
		return

	var color := Tuning.color("hud/target_color")
	var half := Tuning.num("hud/target_bracket_size") * 0.5
	var margin := Tuning.num("hud/edge_margin")
	var bounds := Rect2(Vector2(margin, margin), size - Vector2(margin, margin) * 2.0)

	if not _projectable(camera, target.global_position):
		return
	var behind := camera.is_position_behind(target.global_position)
	var point := camera.unproject_position(target.global_position)
	if behind:
		# unproject_position mirrors points behind the camera through the centre;
		# flip it back so the arrow points the way the player must actually turn.
		point = size * 0.5 - (point - size * 0.5)

	if not behind and bounds.has_point(point):
		_draw_brackets(point, half, color)
		var metres := camera.global_position.distance_to(target.global_position)
		_draw_label("%.0f m" % metres, point + Vector2(half + 6.0, 4.0), color)
		return

	# Off screen: clamp to the edge and point at it.
	var centre := size * 0.5
	var direction := (point - centre)
	if direction.length_squared() < 0.001:
		direction = Vector2.DOWN
	var edge := _clamp_to_bounds(centre, direction.normalized(), bounds)
	_draw_arrow(edge, direction.angle(), Tuning.num("hud/arrow_size"), color)


func _draw_brackets(centre: Vector2, half: float, color: Color) -> void:
	var width := Tuning.num("hud/line_width")
	var leg := half * 0.45
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var origin := centre + corner * half
		draw_line(origin, origin - Vector2(corner.x * leg, 0.0), color, width)
		draw_line(origin, origin - Vector2(0.0, corner.y * leg), color, width)


func _draw_arrow(tip: Vector2, angle: float, arrow_size: float, color: Color) -> void:
	var forward := Vector2.RIGHT.rotated(angle)
	var side := forward.orthogonal()
	draw_colored_polygon(PackedVector2Array([
		tip + forward * arrow_size,
		tip - forward * arrow_size * 0.4 + side * arrow_size * 0.7,
		tip - forward * arrow_size * 0.4 - side * arrow_size * 0.7,
	]), color)


## Where the ray from `origin` along `direction` leaves `bounds`.
func _clamp_to_bounds(origin: Vector2, direction: Vector2, bounds: Rect2) -> Vector2:
	var scale := INF
	if absf(direction.x) > 0.00001:
		var edge_x := bounds.end.x if direction.x > 0.0 else bounds.position.x
		scale = minf(scale, (edge_x - origin.x) / direction.x)
	if absf(direction.y) > 0.00001:
		var edge_y := bounds.end.y if direction.y > 0.0 else bounds.position.y
		scale = minf(scale, (edge_y - origin.y) / direction.y)
	if not is_finite(scale):
		return origin
	return origin + direction * scale


# --- reticle -----------------------------------------------------------------

func _draw_reticle(camera: Camera3D) -> void:
	var missile: Missile = missile_provider.call()
	if missile == null or not is_instance_valid(missile):
		return

	var aim_point := missile.global_position \
		+ missile.aim_direction() * Tuning.num("hud/reticle_distance")
	if camera.is_position_behind(aim_point) or not _projectable(camera, aim_point):
		return

	var point := camera.unproject_position(aim_point)
	var radius := Tuning.num("hud/reticle_size")
	var width := Tuning.num("hud/line_width")
	var color := Tuning.color("hud/reticle_color")

	draw_arc(point, radius, 0.0, TAU, 24, color, width)
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(point + direction * radius * 0.55, point + direction * radius * 1.5, color, width)

	# A line from the nose to the reticle makes the lag visible rather than just felt.
	var nose := missile.global_position + (-missile.global_transform.basis.z) * Tuning.num("hud/reticle_distance")
	if not camera.is_position_behind(nose) and _projectable(camera, nose):
		draw_line(camera.unproject_position(nose), point,
			Color(color, Tuning.num("hud/reticle_lag_line_alpha")), width)


## The gun's crosshair. Deliberately a different shape from the missile reticle:
## the reticle is a request the missile has not caught up with yet (ADR 0035),
## while this is where the shot goes, now. Two instruments that mean different
## things must not look alike.
func _draw_crosshair(camera: Camera3D) -> void:
	var turret: Turret = turret_provider.call()
	if turret == null or not is_instance_valid(turret) or not turret.active:
		return

	# Drawn at the range the guns are sighted at, because that is the one range at
	# which the crosshair and the shot agree (see `Turret.firing_direction`).
	var aim_point := turret.global_position \
		+ turret.aim_direction() * Tuning.num("turret/convergence_distance")
	if camera.is_position_behind(aim_point) or not _projectable(camera, aim_point):
		return

	var point := camera.unproject_position(aim_point)
	var radius := Tuning.num("hud/turret_reticle_size")
	var width := Tuning.num("hud/line_width")
	var color := Tuning.color("hud/turret_reticle_color")

	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(point + direction * radius * 0.4, point + direction * radius, color, width)
	draw_rect(Rect2(point - Vector2.ONE * width, Vector2.ONE * width * 2.0), color)
	_draw_heat(turret, point)


## The pulse beam's heat, under the crosshair rather than at the edge of the
## screen: a gauge the player has to look away from is a gauge they do not read,
## and overheating then arrives as a surprise instead of as a decision they made.
## Hidden entirely at zero heat, so the other three weapons carry no clutter.
func _draw_heat(turret: Turret, centre: Vector2) -> void:
	var heat := turret.heat()
	var overheated := turret.is_overheated()
	if heat <= 0.0 and not overheated:
		return

	var bar_width := Tuning.num("hud/turret_heat_bar_width")
	var bar_height := Tuning.num("hud/turret_heat_bar_height")
	var origin := centre + Vector2(-bar_width * 0.5, Tuning.num("hud/turret_heat_bar_offset"))
	var color := Tuning.color("hud/turret_overheat_color") if overheated \
		else Tuning.color("hud/turret_heat_color")

	draw_rect(Rect2(origin, Vector2(bar_width, bar_height)), Color(color, 0.25))
	draw_rect(Rect2(origin, Vector2(bar_width * clampf(heat, 0.0, 1.0), bar_height)), color)


## The launch tube's reload, along the bottom of the screen in every view.
##
## It is here rather than in the debug HUD because it is the one gauge the whole
## build exists to read. Success criterion 2 is "still choosing to fire, and never
## feels stuck waiting" — that is a question about this bar, and it has to be
## answerable at a glance from the turret, from the helm and from inside a missile,
## without the debug overlay switched on.
func _draw_tube() -> void:
	if ship == null or not is_instance_valid(ship):
		return
	var charge := ship.missile_charge()
	var bar_width := Tuning.num("hud/tube_bar_width")
	var bar_height := Tuning.num("hud/tube_bar_height")
	var origin := Vector2((size.x - bar_width) * 0.5,
		size.y - Tuning.num("hud/tube_bar_bottom_margin") - bar_height)
	var color := Tuning.color("hud/tube_ready_color") if ship.missile_ready() \
		else Tuning.color("hud/tube_reloading_color")

	draw_rect(Rect2(origin, Vector2(bar_width, bar_height)), Color(color, 0.2))
	draw_rect(Rect2(origin, Vector2(bar_width * charge, bar_height)), color)
	if not ship.missile_ready():
		_draw_label("%.1f s" % ship.missile_cooldown_remaining(),
			origin + Vector2(bar_width + 8.0, bar_height), color)


func _process_alert(delta: float) -> void:
	alert_seconds = maxf(alert_seconds - delta, 0.0)


## The interrupt's telegraph, and a bracket on the missile itself once it is in
## the air.
##
## Deliberately loud. The specification asked for "a small alert"; the scope doc's
## Pillar 2 asks for one that is "loud, telegraphed, unambiguous", and those pull
## in opposite directions. It is built prominent so the human can tune it *down* —
## an alert small enough to miss stops being a punctual spike and becomes ambient
## dread, which is precisely what the target-experience guard exists to prevent.
## Every dimension of it is in tuning.
func _draw_alert(camera: Camera3D) -> void:
	var inbound := _nearest_inbound()
	if alert_seconds <= 0.0 and inbound == null:
		return

	var color := Tuning.color("hud/alert_color")
	# A slow pulse rather than a hard blink: readable in a still frame, and it does
	# not compete with the reticle for attention every few frames.
	var pulse := 0.55 + 0.45 * sin(
		Time.get_ticks_msec() * 0.001 * TAU * Tuning.num("hud/alert_pulse_hz"))
	var banner := alert_text
	if inbound != null:
		banner = "INCOMING MISSILE — %.0f m" % inbound.distance_to_ship()
	if banner.is_empty():
		return

	var font := ThemeDB.fallback_font
	var font_size := int(Tuning.num("hud/alert_font_size"))
	var width := font.get_string_size(banner, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := Vector2((size.x - width) * 0.5, Tuning.num("hud/alert_top_margin"))
	draw_string(font, at, banner, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		Color(color, pulse))

	_draw_inbound_marker(camera, inbound, Color(color, pulse))


## A bracket on the incoming missile, and an arrow at the screen edge when it is
## not on screen.
##
## The arrow is the important half. A 2.6 m missile at two hundred metres is a few
## pixels in a rock field, and at the turret's narrow field of view it is off screen
## more often than not — "incoming" has to be a *direction* the player can turn
## towards, or the answer to an interrupt is sweeping the sky and hoping.
##
## The bracket does not pulse in SIZE, only in brightness. A marker that shrinks
## every second is a marker that is hard to find, which is the opposite of the job.
func _draw_inbound_marker(camera: Camera3D, inbound: EnemyMissile, color: Color) -> void:
	if inbound == null or not _projectable(camera, inbound.global_position):
		return

	var margin := Tuning.num("hud/edge_margin")
	var bounds := Rect2(Vector2(margin, margin), size - Vector2(margin, margin) * 2.0)
	var behind := camera.is_position_behind(inbound.global_position)
	var point := camera.unproject_position(inbound.global_position)
	if behind:
		# unproject_position mirrors points behind the camera through the centre;
		# flip it back so the arrow points the way the player must actually turn.
		point = size * 0.5 - (point - size * 0.5)

	if not behind and bounds.has_point(point):
		_draw_brackets(point, Tuning.num("hud/alert_bracket_size") * 0.5, color)
		return

	var centre := size * 0.5
	var direction := point - centre
	if direction.length_squared() < 0.001:
		direction = Vector2.DOWN
	_draw_arrow(_clamp_to_bounds(centre, direction.normalized(), bounds),
		direction.angle(), Tuning.num("hud/alert_arrow_size"), color)


## The closest live enemy missile, or null.
func _nearest_inbound() -> EnemyMissile:
	var tree := get_tree()
	if tree == null:
		return null
	var best: EnemyMissile = null
	var closest := INF
	for node in tree.get_nodes_in_group(EnemyMissile.GROUP):
		var missile := node as EnemyMissile
		if missile == null or missile.is_spent():
			continue
		var distance := missile.distance_to_ship()
		if distance < closest:
			closest = distance
			best = missile
	return best


## A tint round the edge of the screen when the ship is hit. It fires whether or
## not the hit cost anything — with `ship/invulnerable` on, a failed intercept has
## to still be distinguishable from one that never arrived, or there is nothing to
## pace against (docs/TURRET_MODE_IMPLEMENTATION.md, Flag 3).
func _draw_hit_flash() -> void:
	if ship == null or not is_instance_valid(ship):
		return
	var strength := ship.hit_flash()
	if strength <= 0.0:
		return
	var band := Tuning.num("hud/hit_flash_band")
	var color := Color(Tuning.color("hud/hit_flash_color"), strength)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, band)), color)
	draw_rect(Rect2(Vector2(0.0, size.y - band), Vector2(size.x, band)), color)
	draw_rect(Rect2(Vector2.ZERO, Vector2(band, size.y)), color)
	draw_rect(Rect2(Vector2(size.x - band, 0.0), Vector2(band, size.y)), color)


## Can `unproject_position` be asked about this point at all?
##
## It builds a `Plane` from the camera-local position and normalises it, and
## `Plane::normalize()` zeroes the whole plane when the normal has zero length —
## which is the `p.d == 0` assert in camera_3d.cpp. In other words it fails for
## exactly one input: a point sitting on the camera's own origin.
##
## That happens on the first frame of every run. Nodes are constructed at their
## parent's origin and only placed afterwards, so for one frame the chase camera
## and the target are both at the arena origin and the indicator asks where the
## camera is from where the camera is. There is no sensible screen position for a
## point at the eye, so the answer is to draw nothing that frame.
func _projectable(camera: Camera3D, world_point: Vector3) -> bool:
	return not camera.global_position.is_equal_approx(world_point)


func _draw_label(text: String, at: Vector2, color: Color) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		int(Tuning.num("hud/font_size")), color)
