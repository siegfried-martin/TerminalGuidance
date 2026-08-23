extends Node
## Capture harness: loads the arena and fires once, so `make shot` can photograph
## the missile view without a human holding the controls.
##
## Lives in tools/ rather than in the arena, because the game should not carry a
## code path that exists for screenshots. Frame budget is generous enough for the
## camera lag to settle.

const FIRE_AFTER_SECONDS := 0.4
## A steady pull on the stick after launch, so the reticle sits ahead of the nose
## and the lag between them is visible in the captured frame.
const STEER_PIXELS_PER_FRAME := Vector2(-60.0, -14.0)

var _arena: Node
var _elapsed: float = 0.0
var _fired: bool = false


func _ready() -> void:
	_arena = (load("res://scenes/arena.tscn") as PackedScene).instantiate()
	add_child(_arena)


func _process(delta: float) -> void:
	_elapsed += delta
	if not _fired and _elapsed >= FIRE_AFTER_SECONDS:
		_fired = true
		_arena.call("fire")
	if _fired:
		var views: ViewController = _arena.call("views")
		var missile: Missile = views.piloted_missile()
		if missile != null:
			missile.add_mouse_steer(STEER_PIXELS_PER_FRAME)
