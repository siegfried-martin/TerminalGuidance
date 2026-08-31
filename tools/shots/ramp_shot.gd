extends Node
## Capture harness: halfway down an on-ramp, in cruise, looking up it toward the merge.
##
## The ramp is where the road is at its most complicated — it curves in two axes, it
## flares from the portal's aperture out to full section, and it runs alongside the
## mainline it is about to join. It was reported as rendering strangely, and a ramp is
## the one part of the road that no other harness photographs.
##
## Lives in tools/ rather than in the scene, because the game should not carry a code
## path that exists for screenshots.

## How far up the ramp to sit, and how far ahead to look.
const ALONG_FRACTION := 0.45
const LOOK_AHEAD_METRES := 700.0

var _scene: ExplorationScene
var _armed: bool = false


func _ready() -> void:
	_scene = (load("res://scenes/exploration.tscn") as PackedScene).instantiate() \
		as ExplorationScene
	add_child(_scene)


func _process(_delta: float) -> void:
	if _scene == null or _scene.map().road() == null:
		return
	var deck := _scene.map().road().get_node_or_null("RampOnAUpper") as RoadDeck
	if deck == null:
		return
	var gate := deck.start_portal()
	var travel := deck.path().tangent_at(0.0)
	if not _armed:
		# Two frames either side of the portal: engaging is a swept crossing, and
		# teleporting onto the ramp would never touch the aperture.
		_scene.ship().position = gate.position - travel * 20.0
		_armed = true
		return
	if _scene.ship().cruise == null:
		_scene.ship().position = gate.position + travel * 20.0
		return
	var along := deck.length() * ALONG_FRACTION
	_scene.ship().position = deck.path().point_at(along)
	_scene.ship().look_at(deck.path().point_at(along + LOOK_AHEAD_METRES), Vector3.UP)
