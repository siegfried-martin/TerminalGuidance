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

var _initialised: bool = false


func _ready() -> void:
	fov = Tuning.num("camera/fov_base")
	Tuning.reloaded.connect(func() -> void: fov = Tuning.num("camera/fov_base"))


## Jump straight to the ideal pose. Called on a view change so the cut is a cut,
## not a swoop (ADR: hard cut is the default; PiP is POC step 9).
func snap() -> void:
	_initialised = false


func _process(delta: float) -> void:
	if subject == null or not is_instance_valid(subject):
		return

	var subject_basis := subject.global_transform.basis
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

	var ideal := subject.global_position \
		+ back * Tuning.num(tuning_prefix + "_follow_distance") \
		+ up * Tuning.num(tuning_prefix + "_follow_height")

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
		- subject_basis.z * Tuning.num(tuning_prefix + "_look_ahead")
	look_at(look_point, subject_basis.y)
