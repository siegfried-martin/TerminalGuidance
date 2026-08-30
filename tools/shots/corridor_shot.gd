extends Node
## Capture harness: parks the ship in the middle of the local leg, looking down it
## toward system B.
##
## This exists because POC step 5's whole question is what four kilometres of
## hand-flown corridor is like, and the first way that can fail is *there is nothing
## on screen*. A tube with no reference geometry in it renders as a still image at
## 15.5 m/s no matter how fast the ship is actually going, and the leg being long is
## the thing under test. Whether the markers and the walls give motion something to
## be measured against is only visible in a frame.
##
## Lives in tools/ rather than in the scene, because the game should not carry a code
## path that exists for screenshots.

var _scene: ExplorationScene


func _ready() -> void:
	_scene = (load("res://scenes/exploration.tscn") as PackedScene).instantiate() \
		as ExplorationScene
	add_child(_scene)


func _process(_delta: float) -> void:
	if _scene == null or _scene.ship() == null or _scene.map().links().is_empty():
		return
	# Parked rather than flown: a taxi takes four and a half minutes to get here.
	var link := _scene.map().links()[0]
	var here := link.region().path.point_at(link.region().length() * 0.5)
	_scene.ship().position = here
	_scene.ship().look_at(link.region().to(), Vector3.UP)
