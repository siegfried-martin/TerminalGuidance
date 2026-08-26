extends Node
## Capture harness: loads the arena and opens the tuning panel, so `make shot`
## can photograph the panel without a human pressing F2.
##
## One section is expanded and the rest left folded, because that is the state the
## panel is actually used in and the one worth checking a change against: the
## sections have to stay legible as a list while one of them is open.

const OPEN_SECTION := "ship"


func _ready() -> void:
	add_child((load("res://scenes/arena.tscn") as PackedScene).instantiate())
	await get_tree().process_frame
	DebugPanel.set_open(true)
	DebugPanel.set_section_open(OPEN_SECTION, true)
