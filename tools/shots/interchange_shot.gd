extends Node
## Capture harness: looks at a whole interchange from outside and above — the
## mainline running through the system, both ramps curving away from it, and the
## planet the ramps lead down to.
##
## This exists because ADR 0065 is a claim about a SHAPE. Tests can assert that the
## mainline passes through every system's centre, that the ramp mouths clear the
## approach envelope and that a ramp merges inside the steering cone. What none of
## them can answer is whether the thing on screen reads as one continuous highway
## with exits off it, which is the whole point of the reshape.
##
## Lives in tools/ rather than in the scene, because the game should not carry a code
## path that exists for screenshots.

## Back from the interchange, out to the side, and up — an aerial three-quarter view,
## which is the only angle a road junction is ever legible from.
##
## The height is kept well under `system_ceiling_height`: park the camera above the
## ceiling and the whole frame goes red, which photographs the boundary treatment
## working rather than the thing being looked at.
## Kept inside the disc on every axis, not just the vertical: back and side compose
## into a radius, and 2100 back plus 1500 across is 2581 from the centre of a 1750 m
## disc. Outside the rim the frame is red too, for the same reason and just as
## uselessly.
const BACK_METRES := 1200.0
const SIDE_METRES := 820.0
const UP_METRES := 180.0

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
	if _scene == null or _scene.map().systems().size() < 2:
		return
	# System B: the case the reshape is about, where the road passes straight through
	# rather than terminating.
	# At the ROAD'S height, not the combat plane's: the highway rides near the ceiling
	# now, and a camera aimed at the system's centre photographs the space under it.
	var centre := _scene.map().system_center(1) \
		+ Vector3.UP * Tuning.num("exploration/road_height")
	var road := _scene.map().road().get_node_or_null("A377BMainlineForward") as RoadDeck
	if road == null:
		return
	var along: float = road.path().closest(centre)[0]
	var heading: Vector3 = road.path().tangent_at(along)
	var side := heading.cross(Vector3.UP).normalized()
	_scene.ship().position = centre - heading * BACK_METRES + side * SIDE_METRES \
		+ Vector3.UP * UP_METRES
	_scene.ship().look_at(centre, Vector3.UP)
