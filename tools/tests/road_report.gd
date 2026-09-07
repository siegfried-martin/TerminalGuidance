extends Node
## `make roads`: build the map from `data/routes.json` headless and print every
## problem the network found, plus how long the whole structure takes to build. For
## authoring the map: save the file, run this, read the list, fix the one it names.

func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var network := RoadNetwork.new()
	add_child(network)
	network.build(Routes.data(), Routes.system_positions())
	var t1 := Time.get_ticks_msec()
	print("── roads: %d roads, %d tubes, %d ramps, %d chunks, laid out in %d ms ──" % [
		network.roads.size(), network.tubes.size(), network.ramps.size(),
		network.chunk_count(), t1 - t0])
	var floor_r := Tuning.num("exploration/cruise_speed") / (clampf(Tuning.num("exploration/road_turn_share"), 0.05, 1.0)
		* deg_to_rad(Tuning.num("exploration/cruise_turn_rate_deg_per_sec")))
	for road in network.roads:
		print("  %-40s %6.1f km  min bend %5.0f m  pitch %.1f deg" % [road.name,
			road.path.length / 1000.0, road.path.min_radius(), road.path.max_pitch_deg()])
		# Name the corner that is too tight, so the author knows which leg to lengthen.
		if road.path.min_radius() < floor_r:
			for c in road.path.corners:
				if float(c["radius"]) < floor_r:
					print("      corner at %s turns %.0f deg with r=%.0f (floor %.0f)" % [
						c["pos"], c["angle_deg"], c["radius"], floor_r])
	if OS.get_environment("ROAD_REPORT_MESH") == "1":
		var faces := network.build_all_now()
		var tris := 0
		for name: String in faces:
			tris += (faces[name] as PackedVector3Array).size() / 3
		print("  full mesh: %d triangles in %d ms" % [tris, Time.get_ticks_msec() - t1])
	if network.problems.is_empty():
		print("  no problems")
	for problem in network.problems:
		print("  PROBLEM  " + problem)
	var status := 0 if network.problems.is_empty() else 1
	network.free()
	get_tree().quit(status)
