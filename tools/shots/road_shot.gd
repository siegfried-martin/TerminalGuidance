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
	# The window this renders into is a real one: without this a hand on the mouse
	# flies the ship and breaks approach locks mid-run (ADR 0031 wants a frame that is
	# the same every time it is asked for).
	_scene.set_reads_input(false)


func _process(_delta: float) -> void:
	if _scene == null or _scene.map().road() == null:
		return
	var deck := _scene.map().road().get_node_or_null("A377BRampOnAForward") as RoadDeck
	if deck == null:
		return
	var gate := deck.start_portal()
	var travel := deck.path().tangent_at(0.0)
	if not _armed:
		# Two frames either side of the portal, because engaging is a swept crossing
		# — teleporting straight onto the road would never touch the aperture.
		_scene.ship().position = gate.position - travel * 20.0
		_armed = true
		return
	if _scene.ship().cruise == null:
		_scene.ship().position = gate.position + travel * 20.0
		return
	# Up the ramp and out onto the mainline, which is where the road actually reads.
	var main := _scene.map().road().get_node_or_null("A377BMainlineForward") as RoadDeck
	var along: float = main.path().closest(deck.path().finish())[0] + ALONG_METRES
	var here: Vector3 = main.path().point_at(along)
	var heading: Vector3 = main.path().tangent_at(along)
	var frame := CruiseLane.frame_for(heading)
	_scene.ship().position = here + frame[0] * OFF_CENTRE_METRES
	_scene.ship().look_at(_scene.ship().position + heading, Vector3.UP)
