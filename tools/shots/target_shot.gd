extends Node
## Capture harness: parks a camera close to the target ship so its hull and its
## components can be photographed, and puts one hit on each component so the
## intact, damaged and destroyed states are all in the same frame.
##
## The arena's own ship camera sits at standoff range, where the target is a few
## pixels across and none of this is legible. Lives in tools/ rather than in the
## arena, because the game should not carry a code path that exists for
## screenshots.

const CAMERA_OFFSET := Vector3(15.0, 5.5, -20.0)
const DAMAGE_AFTER_SECONDS := 0.3

var _target: TargetShip
var _camera: Camera3D
var _elapsed: float = 0.0
var _damaged: bool = false


func _ready() -> void:
	var arena := (load("res://scenes/arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	_target = arena.call("target")

	_camera = Camera3D.new()
	_camera.name = "TargetShotCamera"
	_camera.far = 20000.0
	add_child(_camera)
	_camera.current = true


func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	_camera.global_position = _target.global_position + CAMERA_OFFSET
	_camera.look_at(_target.global_position, Vector3.UP)

	_elapsed += delta
	if _damaged or _elapsed < DAMAGE_AFTER_SECONDS:
		return
	_damaged = true
	# Component 0 destroyed, component 1 damaged, the rest untouched — every state
	# the player will see, in one photograph.
	var pool := _target.component_hit_points()
	_target.damage_component(0, pool)
	_target.damage_component(1, pool * 0.5)
