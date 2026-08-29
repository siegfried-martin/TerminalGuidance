extends Node
## Capture harness: loads the exploration scene and flies the ship up into the
## ceiling, so `make shot` can photograph the boundary treatment without a human at
## the desk.
##
## This exists because the one thing ADR 0011 asks for that no test can check is
## *"the volume is visibly red"*. The logic is covered by `DiscBounds` and the
## wiring by the scene test; what neither can see is whether the red actually
## arrives on screen, in time, at a strength a player would notice.
##
## Lives in tools/ rather than in the scene, because the game should not carry a
## code path that exists for screenshots.

## Far enough past the face that damage has started and the strain is at full, so
## one frame shows the whole treatment rather than the first third of it.
const OVERSHOOT_METRES := 30.0

var _scene: ExplorationScene


func _ready() -> void:
	_scene = (load("res://scenes/exploration.tscn") as PackedScene).instantiate() \
		as ExplorationScene
	add_child(_scene)


func _process(_delta: float) -> void:
	if _scene == null or _scene.ship() == null:
		return
	# Parked rather than flown: the ceiling is 400 m up and a taxi does 15.5 m/s,
	# so flying there honestly would take 26 seconds of capture for one frame.
	# Held outbound so the strain and the damage timer both engage.
	_scene.ship().position.y = _scene.system().ceiling_height() + OVERSHOOT_METRES
	_scene.ship().rotation_degrees = Vector3(-35.0, 0.0, 0.0)
