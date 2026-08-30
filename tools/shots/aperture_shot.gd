extends Node
## Capture harness: parks the ship inside the system, out near the rim, looking
## along the aperture's bearing — so `make shot` can photograph the one hole in the
## boundary without a human flying 1750 m to find it.
##
## This exists because ADR 0062's funnel is a *guidance* claim: "wide at the rim,
## tapering to the corridor, so leaving is aimed rather than threaded". Tests can
## check that the mouth is wider than the corridor and that the mesh has a hole in
## it. Whether the hole reads as a way out from inside the volume is only visible in
## a frame.
##
## Since step 6 it also carries the portal site: two stacked apertures at the mouth,
## one per direction, whose colour is the whole of "may I use this?" (ADR 0060). That
## the blue reads from inside the system, before the trip toward it, is the other
## thing only a frame can answer.
##
## Lives in tools/ rather than in the scene, because the game should not carry a
## code path that exists for screenshots.

## Where to sit, relative to the mouth: back along the bearing, off to one side, and
## a little above the combat plane.
##
## Obliquely rather than down the axis on purpose. A funnel viewed along its own
## centre-line is invisible by construction — every wall is edge-on — and the frame
## shows a black circle with no way to tell a funnel from a hole. From the side, the
## taper is the thing being photographed.
const BACK_METRES := 1250.0
const SIDE_METRES := 800.0
const UP_METRES := 260.0

var _scene: ExplorationScene


func _ready() -> void:
	_scene = (load("res://scenes/exploration.tscn") as PackedScene).instantiate() \
		as ExplorationScene
	add_child(_scene)


func _process(_delta: float) -> void:
	if _scene == null or _scene.ship() == null or _scene.map().links().is_empty():
		return
	# Parked rather than flown: a taxi does 15.5 m/s and the mouth is most of a
	# kilometre away, so flying there honestly is a minute of capture for one frame.
	var home := _scene.map().systems()[0]
	var mouth := home.aperture_mouth(home.aperture_count() - 1)
	var bearing := (mouth - home.position).normalized()
	var side := bearing.cross(Vector3.UP).normalized()
	_scene.ship().position = mouth - bearing * BACK_METRES \
		+ side * SIDE_METRES + Vector3.UP * UP_METRES
	_scene.ship().look_at(mouth, Vector3.UP)
