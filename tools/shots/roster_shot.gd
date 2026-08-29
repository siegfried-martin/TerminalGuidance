extends Node
## Capture harness: loads the exploration scene and steps through the hull roster,
## so `make shot` photographs each class without a human at the desk.
##
## The frame this exists to produce is the one no test can check: whether the three
## classes are *visibly* three ships. A roster whose hulls look identical fails at
## the one thing it is for, and the numbers being different in the HUD is not the
## same as being able to see which one you are in.
##
## Frames are spent on each class in turn, so `.shots/` ends up holding one run of
## every hull rather than one hull.

const SECONDS_PER_CLASS := 2.0

var _scene: ExplorationScene
var _elapsed: float = 0.0
var _shown: int = 0


func _ready() -> void:
	_scene = (load("res://scenes/exploration.tscn") as PackedScene).instantiate() \
		as ExplorationScene
	add_child(_scene)


func _process(delta: float) -> void:
	if _scene == null or _scene.ship() == null:
		return
	_elapsed += delta
	# Driven through the real Input action, which works headlessly, so the harness
	# exercises the same path a hand on the keyboard does — including each class's
	# own throttle travel, which is half of why a capital feels heavy.
	Input.action_press("throttle_up")
	if _elapsed >= SECONDS_PER_CLASS * float(_shown + 1) \
			and _shown + 1 < HullClass.all().size():
		_shown += 1
		_scene.cycle_hull()
