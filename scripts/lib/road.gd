class_name Road
extends RefCounted
## A built structure along one `RoadPath` carrying one or two carriageways (`Tube`s).
## A highway has two carriageways under one roof with a glass median; a ramp has one.
## Rendering and rib layout are per road; collision is per tube. Pure apart from the
## tuning it is sized from.

var name: String = ""
## "highway" or "ramp".
var kind: String = "highway"
var path: RoadPath
var tubes: Array[Tube] = []
var carriageway_w: float = 240.0
var carriageway_h: float = 150.0
## Centre-to-centre distance of the two carriageways.
var separation: float = 240.0
var rib_spacing: float = 400.0
var rib_thickness: float = 60.0
var rib_protrusion: float = 24.0
## t of the first rib. Lets a ramp continue the mainline's beat rather than restart it,
## because the beat is the road's strongest speed cue.
var rib_phase: float = 0.0
## Half extents of the whole section.
var half_width: float = 0.0
var half_height: float = 0.0
## Open ends into space: `{t, label}`.
var mouths: Array[Dictionary] = []
var bounds: AABB


static func make(road_name: String, road_kind: String, road_path: RoadPath,
		lanes: int, inset: float) -> Road:
	var r := Road.new()
	r.name = road_name
	r.kind = road_kind
	r.path = road_path
	r.carriageway_w = Tuning.num("exploration/lane_width") - 2.0 * inset
	r.carriageway_h = Tuning.num("exploration/lane_height") - 2.0 * inset
	r.separation = Tuning.num("exploration/deck_separation")
	r.rib_spacing = Tuning.num("exploration/structure_module_length")
	r.rib_thickness = Tuning.num("exploration/structure_rib_thickness")
	r.rib_protrusion = Tuning.num("exploration/structure_rib_protrusion")
	if road_path.closed:
		# Keep the beat continuous across the seam of a loop.
		r.rib_spacing = road_path.length / maxf(1.0, roundf(road_path.length / r.rib_spacing))
	var hw := r.carriageway_w * 0.5
	var hh := r.carriageway_h * 0.5
	if lanes == 2:
		# Traffic on the right: the +1 carriageway sits to the path's right, the -1 one
		# to its left, which is ITS right as its own traffic travels (ADR 0077).
		for side: int in [1, -1]:
			var t := Tube.new()
			t.name = road_name + (" R" if side == 1 else " L")
			t.road = r
			t.path = road_path
			t.u0 = side * r.separation * 0.5
			t.hw = hw
			t.hh = hh
			t.direction = side
			t.route_name = road_name
			t.compute_bounds()
			r.tubes.append(t)
		r.half_width = r.separation * 0.5 + hw
	else:
		var t := Tube.new()
		t.name = road_name
		t.road = r
		t.path = road_path
		t.hw = hw
		t.hh = hh
		t.direction = 1
		t.compute_bounds()
		r.tubes.append(t)
		r.half_width = hw
	r.half_height = hh
	r.bounds = road_path.aabb(0.0)
	return r


## Rib collar t-positions along the path.
func rib_positions() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var t := fposmod(rib_phase, rib_spacing)
	var end := path.length - (0.0 if path.closed else rib_thickness * 0.5)
	while t <= end:
		if path.closed or t >= rib_thickness * 0.5:
			out.append(t)
		t += rib_spacing
	return out


## How far the built structure stands out from the glass at t: the rib's protrusion
## inside a collar, nothing between them. The outside collision reads this.
func rib_margin_at(t: float) -> float:
	var local := fposmod(t - rib_phase, rib_spacing)
	if local < rib_thickness * 0.5 or local > rib_spacing - rib_thickness * 0.5:
		return rib_protrusion
	return 0.0
