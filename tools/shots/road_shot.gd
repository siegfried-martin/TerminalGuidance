extends Node
## Capture harness: drops the ship on the road at one of the network's spots, drive
## running, and holds it there for the frames `make shot` records.
##
## Two things ADR 0057 asks a review to check are only visible in a frame: that the
## lane is visually open, and that the camera holds the road's direction. And the one
## thing ADR 0096 asks: that the structure around a junction is there, with the wall
## open exactly where the ramp is.
##
## `ROAD_SHOT_SPOT` picks the spot by label prefix ("Exit", "Merge", "Bend 1", "Mouth");
## the default is the first exit. "Spawn" leaves the ship where a run starts, engine
## off, which is what a new player sees first. Lives in tools/ rather than in the scene, because
## the game should not carry a code path that exists for screenshots.

var _scene: ExplorationScene
var _armed: bool = false


func _ready() -> void:
	_scene = (load("res://scenes/exploration.tscn") as PackedScene).instantiate() \
		as ExplorationScene
	add_child(_scene)
	_scene.set_reads_input(false)


func _process(_delta: float) -> void:
	if _armed or _scene == null or _scene.map() == null:
		return
	var wanted := OS.get_environment("ROAD_SHOT_SPOT")
	if wanted.is_empty():
		wanted = "Exit"
	if wanted.to_lower() == "spawn":
		_scene.camera().snap()
		_armed = true
		print("[shot] spawn")
		return
	# "Planet": beside system A's planet on the combat plane, looking at it, with the
	# highway passing under it — the arrangement ADR 0097 asks a frame to show.
	if wanted.to_lower() == "planet":
		var planet: Node3D = _scene.map().planets()[0]
		var stand := planet.global_position + Vector3(-2000.0, 0.0, 1500.0)
		_scene.ship().global_position = stand
		_scene.ship().look_at(planet.global_position, Vector3.UP)
		_scene.ship().reset_reticle()
		_scene.camera().snap()
		_armed = true
		print("[shot] planet")
		return
	for spot in _scene.map().spots():
		if String(spot["label"]).to_lower().begins_with(wanted.to_lower()):
			_scene.map().drop_on_road(_scene.ship(), spot["tube"], float(spot["t"]))
			_scene.ship().input_throttle = 1.0
			_scene.camera().snap()
			_armed = true
			print("[shot] %s" % spot["label"])
			return
	push_error("no road spot begins with '%s'" % wanted)
	_armed = true
