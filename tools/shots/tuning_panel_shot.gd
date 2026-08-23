extends Node
## Capture harness: loads the arena and opens the tuning panel, so `make shot`
## can photograph the panel without a human pressing F2.

func _ready() -> void:
	add_child((load("res://scenes/arena.tscn") as PackedScene).instantiate())
	await get_tree().process_frame
	DebugPanel.set_open(true)
