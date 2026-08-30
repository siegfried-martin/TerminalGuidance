extends Node
## Capture harness: parks the ship on the road, a little way in, with the cruise
## drive running.
##
## Two things ADR 0057 asks a review to check are only visible in a frame. *"The lane
## is visually open — the system and the space around it are visible from inside"*:
## ribs read as a road or they read as a tunnel, and no test can tell the difference.
## And *"the camera is fixed to the road's direction"*: with the camera on the nose,
## steering left and the road curving left look identical.
##
## Lives in tools/ rather than in the scene, because the game should not carry a code
## path that exists for screenshots.

## Far enough in that the flare is behind the camera and the lane is at full section.
const ALONG_METRES := 700.0
## Off the centre-line, so lane position is legible rather than centred and invisible.
const OFF_CENTRE_METRES := 30.0

var _scene: ExplorationScene
var _armed: bool = false


func _ready() -> void:
	_scene = (load("res://scenes/exploration.tscn") as PackedScene).instantiate() \
		as ExplorationScene
	add_child(_scene)


func _process(_delta: float) -> void:
	if _scene == null or _scene.map().links().is_empty():
		return
	var deck := _scene.map().links()[0].decks()[0]
	var gate := deck.start_portal()
	var travel := deck.axis()
	if not _armed:
		# Two frames either side of the portal, because engaging is a swept crossing
		# — teleporting straight onto the road would never touch the aperture.
		_scene.ship().position = gate.position - travel * 20.0
		_armed = true
		return
	if _scene.ship().cruise == null:
		_scene.ship().position = gate.position + travel * 20.0
		return
	var frame := CruiseLane.frame_for(travel)
	_scene.ship().position = gate.position + travel * ALONG_METRES \
		+ frame[0] * OFF_CENTRE_METRES
	_scene.ship().look_at(_scene.ship().position + travel, Vector3.UP)
