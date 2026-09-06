extends Node
## Capture harness: the lattice road's VERTEX, from the seat and from outside.
##
## The vertex is the whole of step B and the one thing in it no test can answer. A
## gate can assert that the lane's curvature never exceeds what the ship can fly and
## that the two mitred boxes overlap; it cannot say whether a hard-cornered building
## with a filleted lane in it reads as a road bending or as a road with a kink in it
## (plan section 12.1). That is a frame, and then a human.
##
## **The frame has to be taken from the road**, and that is not a limitation of the
## harness. Off the road there is nothing playable — the corridor is on the combat
## plane and the highway rides 360 m above it, carrying only its own tube (ADR 0091) —
## so a camera swung out to admire the mitre from outside is 2 km past the boundary
## and the whole frame is the boundary's red. Which is the treatment working.
##
## `VERTEX_SHOT_VERTEX` picks which of the route's bends to look at and
## `VERTEX_SHOT_APPROACH` how far short of it to sit, so one harness serves the long
## approach and the close pass:
##
##     make shot SCENE=res://tools/shots/vertex_shot.tscn
##     VERTEX_SHOT_APPROACH=300 make shot SCENE=res://tools/shots/vertex_shot.tscn

## Which interior vertex of the trunk road to look at, counting from the west stub,
## and how far back down the road the seat sits so the bend is ahead rather than under.
const VERTEX := 7
const APPROACH_METRES := 1400.0

var _scene: ExplorationScene
var _frames: int = 0


func _ready() -> void:
	_scene = (load("res://scenes/lattice.tscn") as PackedScene).instantiate() \
		as ExplorationScene
	add_child(_scene)
	# The window this renders into is a real one: without this a hand on the mouse
	# flies the ship and the frame is not the same twice (ADR 0031).
	_scene.set_reads_input(false)
	# The debug HUD is two thirds of the frame and this shot is about geometry. It is
	# hidden rather than toggled so the frame is the same however the last run left it.
	var hud := _scene.get_node_or_null("DebugHud") as CanvasItem
	if hud != null:
		hud.visible = false


func _process(_delta: float) -> void:
	if _scene == null or _scene.map() == null or _scene.map().road() == null:
		return
	_frames += 1
	var decks := _scene.map().forward_mainlines()
	if decks.is_empty():
		return
	var deck := decks[0]
	var lattice := Routes.make_lattice()
	var spec := Routes.route("A-377B")
	if spec == null:
		return
	var world := spec.world_vertices(lattice)
	var at_vertex: Vector3 = world[clampi(int(_number("VERTEX_SHOT_VERTEX", VERTEX)),
		1, world.size() - 2)]
	var along: float = deck.path().closest(at_vertex)[0]

	# FROM THE SEAT, on the carriageway, short of the bend.
	var seat := maxf(along - _number("VERTEX_SHOT_APPROACH", APPROACH_METRES), 0.0)
	var here: Vector3 = deck.path().point_at(seat)
	var heading: Vector3 = deck.path().tangent_at(seat)
	_scene.ship().position = here
	_scene.ship().look_at(here + heading, Vector3.UP)


static func _number(variable: String, fallback: float) -> float:
	var set_to := OS.get_environment(variable)
	return fallback if set_to.is_empty() else float(set_to)
