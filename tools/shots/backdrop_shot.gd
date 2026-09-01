extends Node
## Capture harness: stands inside a system, out near the rim, looking straight at the
## boundary — the exact frame the human reported as *"just a blue wall, impossible to
## tell that I'm moving"*.
##
## What has to be legible here is not the wall. It is everything that is NOT the wall:
## the ruled grid on it, the dust a few hundred metres past it, the bodies kilometres
## beyond that, and the stars behind them. If the frame is one flat colour again, the
## deep field is not doing its job and no test will ever say so.
##
## Lives in tools/ rather than in the scene, because the game should not carry a code
## path that exists for screenshots.

## Out toward the rim, but short of the warning band — the frame should photograph the
## backdrop, not the boundary alarm going off.
const OUT_FRACTION := 0.72
const UP_METRES := 60.0

var _scene: ExplorationScene


func _ready() -> void:
	_scene = (load("res://scenes/exploration.tscn") as PackedScene).instantiate() \
		as ExplorationScene
	add_child(_scene)
	# The window this renders into is a real one: without this a hand on the mouse
	# flies the ship and breaks approach locks mid-run (ADR 0031 wants a frame that is
	# the same every time it is asked for).
	_scene.set_reads_input(false)


func _process(_delta: float) -> void:
	if _scene == null or _scene.map().systems().is_empty():
		return
	var disc := _scene.map().systems()[0]
	# Square across the map's bearing, so the rim being looked at is a closed stretch
	# of wall rather than the aperture the road leaves through.
	var bearing := SystemDisc.bearing_to_direction(
		Tuning.num("exploration/aperture_bearing_deg"))
	var outward := bearing.cross(Vector3.UP).normalized()
	_scene.ship().position = disc.position \
		+ outward * disc.radius() * OUT_FRACTION + Vector3.UP * UP_METRES
	_scene.ship().look_at(_scene.ship().position + outward, Vector3.UP)
