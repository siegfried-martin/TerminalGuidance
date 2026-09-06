extends Node
## Capture harness: loads the arena, mans the guns and aims at the target, so
## `make shot` can photograph the turret view without a human at the desk.
##
## Lives in tools/ rather than in the arena, because the game should not carry a
## code path that exists for screenshots. The frame budget is generous enough for
## the camera boom to settle after the cut.
##
## The gun is pointed at the target rather than left on the hull's nose, and both
## triggers are held: what the frame has to show is the crosshair sitting on
## something, tracers in flight, the beam drawn, the heat bar filling, and the
## turret's own HUD rows.

const MAN_GUNS_AFTER_SECONDS := 0.35
const OPEN_FIRE_AFTER_SECONDS := 0.7

var _arena: Node
var _elapsed: float = 0.0
var _manned: bool = false
var _firing: bool = false


func _ready() -> void:
	_arena = (load("res://scenes/arena.tscn") as PackedScene).instantiate()
	add_child(_arena)


func _process(delta: float) -> void:
	_elapsed += delta
	if not _manned and _elapsed >= MAN_GUNS_AFTER_SECONDS:
		_manned = true
		var views: ViewController = _arena.call("views")
		views.enter_turret_view()

	if not _manned:
		return
	# Track the target by hand rather than adding a lead-the-target behaviour to
	# the turret: the station is a manual instrument (ADR 0013's bound applies to
	# anything that would decide for the player), and a harness must not be the
	# place a decision like that first appears.
	var turret: Turret = _arena.call("turret")
	var target: Node3D = _arena.call("target")
	if turret != null and target != null:
		turret.set_aim_direction(target.position - turret.position)

	# Both triggers held, so one frame shows the autocannon and the beam at once.
	# The beam overheats after a few seconds of this, which is also worth seeing.
	if _elapsed >= OPEN_FIRE_AFTER_SECONDS and not _firing:
		_firing = true
		Input.action_press("fire_primary")
		Input.action_press("fire_secondary")
