class_name ChaseCamera
extends Camera3D
## Third-person chase camera with positional lag. Used for the ship view, the
## missile view and the turret view; the difference between them is entirely
## tuning values.
##
## Follow lag is the single most feel-critical value in the file and therefore
## lives in tuning.cfg like everything else. The camera reads its own numbers
## through a key prefix so one class can serve every view.

var subject: Node3D
var tuning_prefix: String = "camera/ship"

## Optional tuning key holding how much of the subject's *pitch* the camera boom
## follows: 1 keeps the boom rigidly on the subject's own axes, 0 keeps it level
## with the horizon and lets the subject pitch inside the frame.
##
## It exists for the turret. A gun that elevates 60 degrees would swing a rigid
## boom down and behind it — through the hull it is mounted on — and the shot
## would be aimed from inside the ship. Levelling the boom while still *looking*
## along the true aim keeps the muzzle low in frame, which is what a turret looks
## like anyway. Empty means the boom is rigid, which is the behaviour every other
## view has always had; that is not a feel constant, it is the absence of this.
var pitch_share_key: String = ""
## Multiplies the boom's length, height and look-ahead. The camera is tuned against
## one hull size; a roster that swaps a 48 m gunboat for a 13 m fighter at the same
## boom puts the player a hull-length behind a speck. Scaling the boom with the hull
## keeps the ship the same size on screen whatever class it is, so what the player
## is comparing is how it flies rather than how far away it looks.
var boom_scale: float = 1.0

## A direction to frame the shot along instead of the subject's own nose. Zero means
## the subject decides, which is every view except the road.
##
## On the highway the camera is fixed to the ROAD's direction and the ship yaws
## inside the frame within `cruise_turn_clamp_deg` of it (ADR 0057). That is what
## makes lane position legible: with the camera on the nose, steering left and the
## road curving left look identical, and the player has nothing to hold a line
## against.
var heading_override: Vector3 = Vector3.ZERO

## Optional tuning key for this view's own field of view. Empty means the shared
## `camera/fov_base`. The turret uses it: a narrow FOV is a zoom, and it is the
## difference between a distant missile being a few pixels and being a target.
var _fov_key: String = ""

var _initialised: bool = false


func _ready() -> void:
	_apply_fov()
	Tuning.reloaded.connect(_apply_fov)


## Give this camera its own field of view. Applied immediately, because it is set
## after the node is already in the tree.
func set_fov_key(key: String) -> void:
	_fov_key = key
	_apply_fov()


func _apply_fov() -> void:
	fov = Tuning.num(_fov_key if not _fov_key.is_empty() else "camera/fov_base")
	# THE FAR PLANE IS A GAMEPLAY VALUE HERE, not a default to leave alone. Godot's
	# 4 km default is shorter than the deep field is deep, and the failure it produces
	# is not "distant things are missing" — it is a body being SLICED by the plane as
	# the player turns toward it, because the far plane is measured along the view
	# axis: a body 6 km away sits inside it at the edge of the screen and outside it in
	# the middle. It looks exactly like a moon going through phases, and it was
	# reported as one.
	near = Tuning.num("camera/near_plane")
	far = Tuning.num("camera/far_plane")


## Jump straight to the ideal pose. Called on a view change so the cut is a cut,
## not a swoop (ADR: hard cut is the default; PiP is POC step 9).
func snap() -> void:
	_initialised = false


func _process(delta: float) -> void:
	if subject == null or not is_instance_valid(subject):
		return

	var subject_basis := subject.global_transform.basis
	if heading_override.length_squared() > 0.000001:
		subject_basis = FlightGeometry.basis_from_forward(
			heading_override.normalized())
	var back := subject_basis.z
	var up := subject_basis.y
	if not pitch_share_key.is_empty():
		var share := clampf(Tuning.num(pitch_share_key), 0.0, 1.0)
		var level_back := Vector3(back.x, 0.0, back.z)
		# Aimed straight up or straight down there is no horizontal bearing to
		# level against, so keep the rigid boom for that frame.
		if level_back.length_squared() > 0.000001:
			back = FlightGeometry.turn_towards(
				back, level_back, back.angle_to(level_back) * (1.0 - share))
			up = FlightGeometry.turn_towards(
				Vector3.UP, up, Vector3.UP.angle_to(up) * share)

	# Blended rather than applied outright, so "does hull size change the boom or the
	# apparent size of the world" stays the human's dial (camera/boom_hull_scale_influence).
	var boom := maxf(lerpf(1.0, boom_scale,
		clampf(Tuning.num("camera/boom_hull_scale_influence"), 0.0, 1.0)), 0.05)
	var ideal := subject.global_position \
		+ back * Tuning.num(tuning_prefix + "_follow_distance") * boom \
		+ up * Tuning.num(tuning_prefix + "_follow_height") * boom

	if _initialised:
		var lag := Tuning.num(tuning_prefix + "_follow_lag")
		global_position = global_position.lerp(ideal, clampf(lag * delta, 0.0, 1.0))
	else:
		global_position = ideal
		_initialised = true

	# The look point always uses the subject's true forward, even when the boom
	# has been levelled: the camera may sit level, but it must never aim somewhere
	# other than where the thing it is following is pointed. The roll reference
	# stays the subject's own up for the same reason `up` above cannot be used —
	# a levelled up goes parallel to the view axis as the aim approaches vertical,
	# and `look_at` has no answer for that.
	var look_point := subject.global_position \
		- subject_basis.z * Tuning.num(tuning_prefix + "_look_ahead") * boom
	look_at(look_point, subject_basis.y)
