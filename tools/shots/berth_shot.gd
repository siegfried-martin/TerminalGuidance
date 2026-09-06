extends Node
## Capture harness: puts the ship in a berth on the roadway, settled and moving.
##
## What only a frame can answer here is whether a berth reads as *the road is under
## me* rather than as *I am flying lower than usual*. The whole claim of ADR 0082 is
## that this is docking — the ship attached to something larger that is going
## somewhere — and that is a picture, not a number. The gate can check that the ship
## converges onto the rail and is carried below cruise speed; it cannot check that the
## roadway fills the lower half of the view.
##
## Lives in tools/ rather than in the scene, because the game should not carry a code
## path that exists for screenshots.

## Far enough along the mainline that the flare and the interchange are behind, and
## the road ahead is plain roadway running to a vanishing point.
const ALONG_METRES := 2600.0
## How many frames to let the berth settle before the shot is worth taking. The pull
## is deliberately gradual, so a frame taken on engagement shows the approach rather
## than the berth.
const SETTLE_FRAMES := 150

var _scene: ExplorationScene
var _frames: int = 0
var _entered: bool = false
var _lowered: bool = false


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
	var ramp := _scene.map().road().get_node_or_null("A377BRampOnAForward") as RoadDeck
	var main := _scene.map().road().get_node_or_null("A377BMainlineForward") as RoadDeck
	if ramp == null or main == null:
		return
	_frames += 1
	# THROUGH THE PORTAL, not teleported past it. Engaging cruise is a swept crossing,
	# and a ship put straight onto the mainline is never on the road at all — which is
	# what the first version of this harness did, and the frame it produced showed a
	# ship parked on a roadway with the berth reading "—".
	var gate := ramp.start_portal()
	var travel := ramp.path().tangent_at(0.0)
	if not _entered:
		if _frames == 1:
			_scene.ship().position = gate.position - travel * 20.0
			return
		if _scene.ship().cruise == null:
			_scene.ship().position = gate.position + travel * 20.0
			return
		_entered = true
		return
	if not _lowered:
		# Out onto the mainline, low in the section and off the centre-line, so the
		# frames that follow show the ship SLIDING onto the rail rather than starting
		# on it. Riding the road already, so this is a move along it, not onto it.
		var along: float = main.path().closest(ramp.path().finish())[0] + ALONG_METRES
		var here: Vector3 = main.path().point_at(along)
		var heading: Vector3 = main.path().tangent_at(along)
		var frame := CruiseLane.frame_for(heading)
		var drop := Tuning.num("exploration/lane_height") * 0.5 \
			- Tuning.num("exploration/berth_ride_height")
		_scene.ship().position = here + frame[0] * 40.0 - frame[1] * drop
		_scene.ship().look_at(_scene.ship().position + heading, Vector3.UP)
		_lowered = true
		return
	if not _scene.map().berth().is_berthed():
		_scene.map().berth().engage(_scene.ship(), _scene.map().riding())
		return
	# Take the next exit the STRIP is offering, which is the other thing only a frame
	# can answer: whether the bottom strip reads as a nav bar from the roadway or as a
	# row of text in the way. Asked of the map rather than picked here — the harness
	# picking its own nearest-ahead is what once produced a frame of the ship taking an
	# exit off the oncoming carriageway, and a harness should not be able to reproduce
	# a defect the game cannot have (ADR 0091).
	var ahead := _scene.map().upcoming_exits(_scene.ship().position)
	if not ahead.is_empty() and _scene.map().berth().taking() == null:
		_scene.map().take_exit(ahead[0][0] as RoadDeck)
