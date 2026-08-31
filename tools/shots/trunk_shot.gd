extends Node
## Capture harness: on the trunk mainline, mid-leg, in cruise, looking down the road.
##
## POC step 8's whole claim is that the trunk leg CURVES and RISES, and neither is
## visible from anywhere else: an interchange photographs the ramps, and a shot near a
## system photographs the system. A test can assert the tightest bend in degrees per
## second; only a frame can say whether a road bending that much reads as driving.
##
## Lives in tools/ rather than in the scene, because the game should not carry a code
## path that exists for screenshots.

## How far into the trunk leg to stand. A quarter in, so the weave ahead is inside the
## frame rather than behind the camera.
const ALONG_FRACTION := 0.25
## Beside the road and above it, rather than in the lane. A chase camera two hundred
## metres behind a ship that is IN a 240 m lane photographs the inside of the lane and
## nothing else; the shape of the road only reads from off it.
const SIDE_METRES := 560.0
const UP_METRES := 280.0
## How far down the road to look. Far enough that a weave with a six-kilometre period
## has somewhere to bend inside the frame.
const LOOK_AHEAD_METRES := 4500.0

var _scene: ExplorationScene


func _ready() -> void:
	_scene = (load("res://scenes/exploration.tscn") as PackedScene).instantiate() \
		as ExplorationScene
	add_child(_scene)


func _process(_delta: float) -> void:
	if _scene == null or _scene.map().road() == null:
		return
	var main := _scene.map().road().get_node_or_null("MainlineUpper") as RoadDeck
	if main == null or _scene.map().links().size() < 2:
		return
	var trunk := _scene.map().links()[1]
	var entry: float = main.path().closest(trunk.region().from())[0]
	var along := entry + trunk.length() * ALONG_FRACTION
	var here: Vector3 = main.path().point_at(along)
	var heading: Vector3 = main.path().tangent_at(along)
	var frame := CruiseLane.frame_for(heading)
	_scene.ship().position = here + frame[0] * SIDE_METRES + Vector3.UP * UP_METRES
	_scene.ship().look_at(
		main.path().point_at(along + LOOK_AHEAD_METRES), Vector3.UP)
