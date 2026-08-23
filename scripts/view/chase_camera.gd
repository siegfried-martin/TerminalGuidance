class_name ChaseCamera
extends Camera3D
## Third-person chase camera with positional lag. Used for both the ship view and
## the missile view; the difference between them is entirely tuning values.
##
## Follow lag is the single most feel-critical value in the file and therefore
## lives in tuning.cfg like everything else. The camera reads its own numbers
## through a key prefix so one class can serve both views.

var subject: Node3D
var tuning_prefix: String = "camera/ship"

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
	var ideal := subject.global_position \
		+ subject_basis.z * Tuning.num(tuning_prefix + "_follow_distance") \
		+ subject_basis.y * Tuning.num(tuning_prefix + "_follow_height")

	if _initialised:
		var lag := Tuning.num(tuning_prefix + "_follow_lag")
		global_position = global_position.lerp(ideal, clampf(lag * delta, 0.0, 1.0))
	else:
		global_position = ideal
		_initialised = true

	var look_point := subject.global_position \
		- subject_basis.z * Tuning.num(tuning_prefix + "_look_ahead")
	look_at(look_point, subject_basis.y)
