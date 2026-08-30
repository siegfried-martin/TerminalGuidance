extends Node
## Capture harness: loads the exploration scene and flies the ship down into the
## planet's approach envelope, so `make shot` photographs the sequence and the
## docking screen without a human at the desk.
##
## The checkpoint step 4 is asking is *"does approach feel like arriving somewhere,
## or like a menu with a runway?"* — which is a human's verdict, not mine. What this
## harness is for is the part underneath it that a test cannot see: whether the
## envelope is actually visible from outside before it is entered, and whether the
## docked screen renders at all.

var _scene: ExplorationScene


func _ready() -> void:
	_scene = (load("res://scenes/exploration.tscn") as PackedScene).instantiate() \
		as ExplorationScene
	add_child(_scene)
	# Placed just outside the envelope, aimed down at the planet, rather than flown
	# in: a taxi covers the 900 m at 15.5 m/s in a minute, and this needs one frame.
	var planet: Node3D = _scene.map().planets()[0]
	var envelope: ApproachEnvelope = _scene.map().approaches()[0]
	_scene.ship().position = planet.position \
		+ Vector3(0.0, envelope.radius() * 1.06, 0.0)
	_scene.ship().look_at_from_position(_scene.ship().position, planet.position,
		Vector3.FORWARD)
