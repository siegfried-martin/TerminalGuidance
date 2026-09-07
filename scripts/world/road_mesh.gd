class_name RoadMesh
extends RefCounted
## Builds the visible structure of one `Road`, in chunks.
##
## A regular beat of rings sweeps floor, roof, glass walls, median, corner beams and
## rib collars along the path. **Every quad passes through one clip rule: it is dropped
## wherever it lies inside the volume of a tube belonging to another road.** The ship's
## collision uses the very same rule (`RoadCollider._open_at`) to decide where a wall
## is open, so what is visible and what holds the ship cannot disagree (ADR 0096).
##
## **Chunked, because the clip is what costs.** Subdividing walls down to a few metres
## where another tube passes through them is most of a junction's build time, and a
## whole map of junctions built up front is a minute of black screen. So a road is a
## list of chunks — `plan()` — each built on its own (`build_chunk()`, safe on a worker
## thread: it touches no node and reads no autoload) and committed to the tree when it
## is wanted (`commit()`). `RoadNetwork` streams them in around the ship. `build_far()`
## is the cheap unclipped version of the whole road that stands in for a chunk that is
## not loaded, so distant road is still there to look at.

## Tolerance for "strictly inside" in the clip rule. THE SAME NUMBER the collider uses.
const EPS := RoadCollider.OPEN_EPS
## Finest subdivision at a clipped edge, as a share of the section's height: the
## edge of an opening is ragged at this scale and exact at the collider's, and this is
## what keeps a junction's triangle count sane.
const MIN_CLIP_SHARE := 0.05
## Quads larger than half the section's smaller side are split before testing: a slot
## through a quad that size must cover one of the five test points; a larger quad
## could hide one.
const MAX_UNTESTED_SHARE := 0.5
## Rings per chunk, and metres per ring. Infrastructure.
const CHUNK_RINGS := 40
const RING_METRES := 40.0
## Ring spacing of the far version. Coarse, but a 2.5 km bend is still 8° per ring.
const FAR_RING_METRES := 200.0
## Where a marking puts a vertex down. Infrastructure.
const MARKING_METRES := 120.0
const MARKING_COUNT := 5
const MARKING_INSET := 0.82
const MARKING_LIFT := 0.02

const MAT_FLOOR := 0
const MAT_GLASS := 1
const MAT_METAL := 2

static var _materials: Array = []
## The far version's materials: the same look, with the distance compression in the
## vertex stage. Kept apart so the detailed chunks stay exact.
static var _far_materials: Array = []
static var _marking_shader: Shader = null

## The section, copied out of tuning ONCE per build so a worker thread never reads an
## autoload.
var _road: Road
var _floor_thickness: float = 10.0
var _beam: float = 8.0
var _want_faces: bool = false
var _min_clip: float = 3.0
var _max_untested: float = 30.0
var _active: Array[Tube] = []
var _verts: Array[PackedVector3Array] = []
var _norms: Array[PackedVector3Array] = []
## Per vertex, the centre of the ring it belongs to — only kept for the far version,
## whose shader shrinks each vertex toward it with distance (`FarLayer`).
var _want_centres: bool = false
var _centres: Array[PackedFloat32Array] = []
var _c0: Vector3 = Vector3.ZERO
var _c1: Vector3 = Vector3.ZERO
var _faces := PackedVector3Array()


## The chunks of a road: `{index, t0, t1, centre, reach}`. `reach` is a radius from
## the centre that covers the whole chunk, for the streamer's distance test.
static func plan(road: Road) -> Array[Dictionary]:
	var chunks: Array[Dictionary] = []
	var n := ring_count(road)
	var ring := road.path.length / n
	var index := 0
	var i := 0
	while i < n:
		var last := mini(i + CHUNK_RINGS, n)
		var t0 := i * ring
		var t1 := last * ring
		var centre := road.path.point_at((t0 + t1) * 0.5)
		var reach := 0.0
		var t := t0
		while t <= t1:
			reach = maxf(reach, centre.distance_to(road.path.point_at(t)))
			t += ring
		chunks.append({"index": index, "t0": t0, "t1": t1, "centre": centre,
			"reach": reach + road.half_width + road.half_height + 100.0})
		index += 1
		i = last
	return chunks


static func ring_count(road: Road) -> int:
	return maxi(int(ceil(road.path.length / RING_METRES)), 1)


## Build one chunk's geometry. Returns `{verts: [3 arrays], norms: [3 arrays], faces}`.
## Safe to call off the main thread: nothing here touches a node or an autoload.
static func build_chunk(road: Road, foreign: Array[Tube], chunk: Dictionary,
		floor_thickness: float, beam: float, want_faces: bool) -> Dictionary:
	var b := RoadMesh.new()
	b._road = road
	b._floor_thickness = floor_thickness
	b._beam = beam
	b._want_faces = want_faces
	b._size_clip(road)
	b._reset()
	var n := ring_count(road)
	var ring := road.path.length / n
	var first := int(round(float(chunk["t0"]) / ring))
	var last := int(round(float(chunk["t1"]) / ring))
	var road_diag := sqrt(road.half_width * road.half_width + road.half_height * road.half_height) \
		+ road.rib_protrusion + 20.0
	var ribs := road.rib_positions()
	for i in range(first, last):
		var f0 := road.path.frame(minf(i * ring, road.path.length))
		var f1 := road.path.frame(minf((i + 1) * ring, road.path.length))
		if road.path.closed and i + 1 == n:
			f1 = road.path.frame(0.0)
		b._select_foreign(foreign, road.path.at((i + 0.5) * ring, 0.0, 0.0), road_diag + ring)
		b._strip(f0, f1)
		for tr in ribs:
			if tr >= i * ring and tr < (i + 1) * ring:
				b._select_foreign(foreign, road.path.at(tr, 0.0, 0.0), road_diag + road.rib_thickness)
				b._rib(road.path.frame(tr - road.rib_thickness * 0.5),
					road.path.frame(tr + road.rib_thickness * 0.5))
	return {"verts": b._verts, "norms": b._norms, "faces": b._faces}


## One chunk's stretch of road, coarse and unclipped, for the distance. Main thread
## only. `from_t`..`to_t` bounds the stretch actually drawn: a ramp leaves its head and
## tail out, because unclipped they would stand inside the carriageway they join.
static func build_far(road: Road, chunk: Dictionary, from_t: float, to_t: float,
		floor_thickness: float, beam: float) -> Node3D:
	var b := RoadMesh.new()
	b._road = road
	b._floor_thickness = floor_thickness
	b._beam = beam
	b._want_centres = true
	b._reset()
	var t0 := maxf(float(chunk["t0"]), from_t)
	var t1 := minf(float(chunk["t1"]), to_t)
	if t1 > t0:
		var n := maxi(int(ceil((t1 - t0) / FAR_RING_METRES)), 1)
		var ring := (t1 - t0) / n
		for i in n:
			var f0 := road.path.frame(t0 + i * ring)
			var f1 := road.path.frame(minf(t0 + (i + 1) * ring, road.path.length))
			b._strip(f0, f1)
	var node := commit(road, int(chunk["index"]),
		{"verts": b._verts, "norms": b._norms, "centres": b._centres}, true)
	node.name = "Far %s chunk %d" % [road.name, chunk["index"]]
	return node


## Turn built arrays into nodes. Main thread only.
static func commit(road: Road, chunk_index: int, built: Dictionary, far: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = "%s chunk %d" % [road.name, chunk_index]
	var mats := far_materials() if far else materials()
	var verts: Array = built["verts"]
	var norms: Array = built["norms"]
	for m in range(3):
		var vs: PackedVector3Array = verts[m]
		if vs.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vs
		arrays[Mesh.ARRAY_NORMAL] = norms[m]
		var flags := 0
		if far:
			arrays[Mesh.ARRAY_CUSTOM0] = (built["centres"] as Array)[m]
			flags = Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		mesh.surface_set_material(0, mats[m])
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.name = "mat %d" % m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if m == MAT_GLASS \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(mi)
	return root


## The markings painted on one carriageway's floor: lines converging to the vanishing
## point, the strongest speed and direction cue there is. Repainted, never rebuilt,
## when the ridden tube changes (ADR 0096).
static func markings(tube: Tube) -> MeshInstance3D:
	var span: float = tube.path.length
	var stations := maxi(int(span / MARKING_METRES), 1)
	var runs: Array[PackedVector3Array] = []
	var centres: Array[PackedVector3Array] = []
	for r in MARKING_COUNT:
		runs.append(PackedVector3Array())
		centres.append(PackedVector3Array())
	for i in stations + 1:
		var t := span * float(i) / float(stations)
		var floor_point := tube.world(t, 0.0, -tube.hh * (1.0 - MARKING_LIFT))
		var centre := tube.path.point_at(t)
		var right: Vector3 = tube.path.frame(t)["right"]
		for r in MARKING_COUNT:
			var across := -1.0 + 2.0 * float(r) / float(MARKING_COUNT - 1)
			runs[r].append(floor_point + right * across * tube.hw * MARKING_INSET)
			centres[r].append(centre)
	var verts := PackedVector3Array()
	var custom := PackedFloat32Array()
	for r in runs.size():
		var run := runs[r]
		for i in run.size() - 1:
			for k in [i, i + 1]:
				verts.append(run[k])
				var c := centres[r][k]
				custom.append(c.x)
				custom.append(c.y)
				custom.append(c.z)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_CUSTOM0] = custom
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays, [], {},
		Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	var mi := MeshInstance3D.new()
	mi.name = "Markings " + tube.name
	mi.mesh = mesh
	# Paint, unshaded on purpose: a marking is a light source in its own right, and one
	# that dims with the system's light is one the player stops steering by. It
	# compresses with distance like the far mesh, or the lines would show the road's
	# true width where the tube is drawn narrower.
	if _marking_shader == null:
		_marking_shader = Shader.new()
		_marking_shader.code = MARKING_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _marking_shader
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func paint_markings(mi: MeshInstance3D, tube: Tube, active: bool) -> void:
	var shade := Tuning.num("exploration/lane_ramp_shade") if tube.is_ramp() else 1.0
	var color := Tuning.color("exploration/lane_active_color" if active
		else "exploration/lane_color")
	color.a = Tuning.num("exploration/lane_active_alpha" if active
		else "exploration/lane_line_alpha")
	color = color.darkened(1.0 - clampf(shade, 0.0, 1.0))
	var mat := mi.material_override as ShaderMaterial
	mat.set_shader_parameter("albedo", color)
	mat.set_shader_parameter("compress_start", Tuning.num("exploration/road_detail_radius"))
	mat.set_shader_parameter("compress_power", Tuning.num("exploration/far_compress_power"))


# --- materials ---------------------------------------------------------------

static func materials() -> Array:
	if _materials.is_empty():
		_materials = [_floor_material(), _glass_material(), _metal_material()]
		refresh_materials()
	return _materials


## Re-read the colours. Called on a tuning reload; the geometry is not rebuilt for a
## colour.
static func far_materials() -> Array:
	if _far_materials.is_empty():
		var opaque := Shader.new()
		opaque.code = FAR_OPAQUE_SHADER
		var glass := Shader.new()
		glass.code = FAR_GLASS_SHADER
		var floor_m := ShaderMaterial.new()
		floor_m.shader = opaque
		var glass_m := ShaderMaterial.new()
		glass_m.shader = glass
		var metal_m := ShaderMaterial.new()
		metal_m.shader = opaque
		_far_materials = [floor_m, glass_m, metal_m]
		refresh_materials()
	return _far_materials


static func refresh_materials() -> void:
	if not _far_materials.is_empty():
		var start := Tuning.num("exploration/road_detail_radius")
		var power := Tuning.num("exploration/far_compress_power")
		var metal := Tuning.color("exploration/structure_metal_color")
		for m: ShaderMaterial in _far_materials:
			m.set_shader_parameter("compress_start", start)
			m.set_shader_parameter("compress_power", power)
		(_far_materials[MAT_FLOOR] as ShaderMaterial).set_shader_parameter("albedo", metal.darkened(0.35))
		(_far_materials[MAT_METAL] as ShaderMaterial).set_shader_parameter("albedo", metal)
		var fg: ShaderMaterial = _far_materials[MAT_GLASS]
		fg.set_shader_parameter("tint", Tuning.color("exploration/structure_glass_color"))
		fg.set_shader_parameter("base_alpha", Tuning.num("exploration/structure_glass_alpha"))
		fg.set_shader_parameter("edge_alpha", Tuning.num("exploration/structure_glass_edge_alpha"))
		fg.set_shader_parameter("fresnel_power", Tuning.num("exploration/structure_glass_fresnel_power"))
		fg.set_shader_parameter("sheen", Tuning.num("exploration/structure_glass_sheen"))
	if _materials.is_empty():
		return
	var glass: ShaderMaterial = _materials[MAT_GLASS]
	glass.set_shader_parameter("tint", Tuning.color("exploration/structure_glass_color"))
	glass.set_shader_parameter("base_alpha", Tuning.num("exploration/structure_glass_alpha"))
	glass.set_shader_parameter("edge_alpha", Tuning.num("exploration/structure_glass_edge_alpha"))
	glass.set_shader_parameter("fresnel_power", Tuning.num("exploration/structure_glass_fresnel_power"))
	glass.set_shader_parameter("sheen", Tuning.num("exploration/structure_glass_sheen"))
	var metal := Tuning.color("exploration/structure_metal_color")
	(_materials[MAT_METAL] as StandardMaterial3D).albedo_color = metal
	(_materials[MAT_FLOOR] as StandardMaterial3D).albedo_color = metal.darkened(0.35)


static func _floor_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.roughness = 0.7
	m.metallic = 0.3
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Glass reads as glass by its FRESNEL: clear where you look straight through it,
## bright and reflective at a grazing angle — which is exactly the angle the wall
## beside a ship at speed is seen at. One `pow` per pixel, no probes, no screen-space
## reflections, no refraction; the pane you look through stays clear (ADR 0057).
const GLASS_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;
uniform vec4 tint : source_color = vec4(0.13, 0.28, 0.36, 1.0);
uniform float base_alpha = 0.3;
uniform float edge_alpha = 0.75;
uniform float fresnel_power = 3.0;
uniform float sheen = 0.6;
void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float fresnel = pow(1.0 - clamp(facing, 0.0, 1.0), fresnel_power);
	ALBEDO = tint.rgb;
	ALPHA = clamp(mix(base_alpha, edge_alpha, fresnel), 0.0, 1.0);
	EMISSION = tint.rgb * sheen * fresnel;
	METALLIC = 0.4;
	ROUGHNESS = 0.08;
	SPECULAR = 0.6;
}
"""


## The far layer's vertex stage: each vertex shrinks toward its ring's centre by
## `FarLayer.factor` of the centre's distance from the camera — the same formula.
const COMPRESS_VERTEX := """
uniform float compress_start = 12000.0;
uniform float compress_power = 1.0;
void vertex() {
	vec3 c = CUSTOM0.xyz;
	float d = distance(CAMERA_POSITION_WORLD, c);
	float f = (d > compress_start && compress_start > 0.0) ? pow(compress_start / d, compress_power) : 1.0;
	VERTEX = c + (VERTEX - c) * f;
}
"""

const FAR_OPAQUE_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 albedo : source_color = vec4(0.5, 0.5, 0.55, 1.0);
""" + COMPRESS_VERTEX + """
void fragment() {
	ALBEDO = albedo.rgb;
	METALLIC = 0.6;
	ROUGHNESS = 0.6;
}
"""

const FAR_GLASS_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;
uniform vec4 tint : source_color = vec4(0.13, 0.28, 0.36, 1.0);
uniform float base_alpha = 0.3;
uniform float edge_alpha = 0.75;
uniform float fresnel_power = 3.0;
uniform float sheen = 0.6;
""" + COMPRESS_VERTEX + """
void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float fresnel = pow(1.0 - clamp(facing, 0.0, 1.0), fresnel_power);
	ALBEDO = tint.rgb;
	ALPHA = clamp(mix(base_alpha, edge_alpha, fresnel), 0.0, 1.0);
	EMISSION = tint.rgb * sheen * fresnel;
	METALLIC = 0.4;
	ROUGHNESS = 0.08;
	SPECULAR = 0.6;
}
"""

const MARKING_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;
uniform vec4 albedo : source_color = vec4(0.4, 0.7, 0.9, 0.7);
""" + COMPRESS_VERTEX + """
void fragment() {
	ALBEDO = albedo.rgb;
	ALPHA = albedo.a;
}
"""


static func _glass_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = GLASS_SHADER
	var m := ShaderMaterial.new()
	m.shader = shader
	return m


static func _metal_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.roughness = 0.55
	m.metallic = 0.8
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


# --- building ----------------------------------------------------------------

func _reset() -> void:
	_verts = [PackedVector3Array(), PackedVector3Array(), PackedVector3Array()]
	_norms = [PackedVector3Array(), PackedVector3Array(), PackedVector3Array()]
	_centres = [PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()]
	_faces = PackedVector3Array()


func _select_foreign(foreign: Array[Tube], centre: Vector3, reach: float) -> void:
	_active.clear()
	for t in foreign:
		if not t.bounds.grow(reach).has_point(centre):
			continue
		var l := t.local(centre)
		var tube_diag := sqrt(t.hw * t.hw + t.hh * t.hh)
		if l["dist"] < reach + tube_diag + absf(t.u0) + absf(t.v0):
			_active.append(t)


static func _pt(f: Dictionary, u: float, v: float) -> Vector3:
	return f["pos"] + f["right"] * u + f["up"] * v


## One strip of structure between two ring frames.
func _strip(f0: Dictionary, f1: Dictionary) -> void:
	_c0 = f0["pos"]
	_c1 = f1["pos"]
	var road := _road
	var w := road.half_width
	var h := road.half_height
	var ft := _floor_thickness
	var b := _beam
	# The floor, top face, one panel per carriageway.
	for tube in road.tubes:
		var ua: float = tube.u0 - tube.hw
		var ub: float = tube.u0 + tube.hw
		_quad(MAT_FLOOR, _pt(f0, ua, -h), _pt(f0, ub, -h), _pt(f1, ub, -h), _pt(f1, ua, -h))
	# Floor slab underside and skirts.
	_quad(MAT_METAL, _pt(f0, -w, -h - ft), _pt(f1, -w, -h - ft), _pt(f1, w, -h - ft), _pt(f0, w, -h - ft))
	_quad(MAT_METAL, _pt(f0, w, -h - ft), _pt(f1, w, -h - ft), _pt(f1, w, -h), _pt(f0, w, -h))
	_quad(MAT_METAL, _pt(f0, -w, -h), _pt(f1, -w, -h), _pt(f1, -w, -h - ft), _pt(f0, -w, -h - ft))
	# Roof and outer walls, glazed.
	_quad(MAT_GLASS, _pt(f0, -w, h), _pt(f1, -w, h), _pt(f1, w, h), _pt(f0, w, h))
	_quad(MAT_GLASS, _pt(f0, w, -h), _pt(f1, w, -h), _pt(f1, w, h), _pt(f0, w, h))
	_quad(MAT_GLASS, _pt(f0, -w, h), _pt(f1, -w, h), _pt(f1, -w, -h), _pt(f0, -w, -h))
	# The median: the inner walls of a two-carriageway road, and its ridge beam.
	if road.tubes.size() == 2:
		var inner: float = road.separation * 0.5 - road.tubes[0].hw
		var panes: Array = [inner] if inner < 0.01 else [inner, -inner]
		for u: float in panes:
			_quad(MAT_GLASS, _pt(f0, u, -h), _pt(f1, u, -h), _pt(f1, u, h), _pt(f0, u, h))
		_box(MAT_METAL, f0, f1, -b * 0.5, b * 0.5, h, h + b)
	# Corner beams, outside the section so they never intrude on the flyable volume.
	_box(MAT_METAL, f0, f1, w, w + b, h, h + b)
	_box(MAT_METAL, f0, f1, -w - b, -w, h, h + b)
	_box(MAT_METAL, f0, f1, w, w + b, -h - ft, -h)
	_box(MAT_METAL, f0, f1, -w - b, -w, -h - ft, -h)


## A rib collar between two frames a rib-thickness apart.
func _rib(f0: Dictionary, f1: Dictionary) -> void:
	_c0 = f0["pos"]
	_c1 = f1["pos"]
	var road := _road
	var w := road.half_width + 0.3
	var h := road.half_height + 0.3
	var ft := _floor_thickness
	var pr := road.rib_protrusion
	_box(MAT_METAL, f0, f1, -w - pr, w + pr, h, h + pr)
	_box(MAT_METAL, f0, f1, -w - pr, w + pr, -h - ft - pr, -h - ft)
	_box(MAT_METAL, f0, f1, w, w + pr, -h - ft, h)
	_box(MAT_METAL, f0, f1, -w - pr, -w, -h - ft, h)


## An axis-aligned box in the road frame, spanning two frames along the path.
func _box(mat: int, f0: Dictionary, f1: Dictionary, ua: float, ub: float, va: float, vb: float) -> void:
	var a0 := _pt(f0, ua, va)
	var b0 := _pt(f0, ub, va)
	var c0 := _pt(f0, ub, vb)
	var d0 := _pt(f0, ua, vb)
	var a1 := _pt(f1, ua, va)
	var b1 := _pt(f1, ub, va)
	var c1 := _pt(f1, ub, vb)
	var d1 := _pt(f1, ua, vb)
	_quad(mat, a0, a1, b1, b0)
	_quad(mat, d0, c0, c1, d1)
	_quad(mat, b0, b1, c1, c0)
	_quad(mat, a0, d0, d1, a1)
	_quad(mat, a0, b0, c0, d0)
	_quad(mat, a1, d1, c1, b1)


# --- clipping ----------------------------------------------------------------

func _quad(mat: int, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	if _active.is_empty():
		_emit(mat, a, b, c, d)
		return
	_clip(mat, a, b, c, d, _active, 0)


## The tubes among `near` whose volume can reach a quad of this size around `centre`.
## One closest-point query per tube per quad, so a quad a tube passes nowhere near is
## emitted whole instead of being split and point-tested — which is where a map full
## of junctions spent its minutes.
func _reaching(near: Array[Tube], centre: Vector3, half_size: float) -> Array[Tube]:
	var out: Array[Tube] = []
	for t in near:
		var q := t.path.closest_tuvw(centre)
		var du := q.y - t.u0
		var dv := q.z - t.v0
		var off := sqrt(du * du + dv * dv + q.w * q.w)
		if off < sqrt(t.hw * t.hw + t.hh * t.hh) + half_size + 1.0:
			out.append(t)
	return out


func _clip(mat: int, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		near: Array[Tube], depth: int) -> void:
	var centre := (a + b + c + d) * 0.25
	var size := maxf(a.distance_to(b), b.distance_to(c))
	var reaching := _reaching(near, centre, size * 0.71)
	if reaching.is_empty():
		_emit(mat, a, b, c, d)
		return
	var n := 0
	for p: Vector3 in [a, b, c, d, centre]:
		if _inside_any(reaching, p):
			n += 1
	if n == 5:
		return
	if n == 0 and size <= _max_untested:
		_emit(mat, a, b, c, d)
		return
	if size <= _min_clip or depth >= 14:
		if not _inside_any(reaching, centre):
			_emit(mat, a, b, c, d)
		return
	var ab := (a + b) * 0.5
	var bc := (b + c) * 0.5
	var cd := (c + d) * 0.5
	var da := (d + a) * 0.5
	_clip(mat, a, ab, centre, da, reaching, depth + 1)
	_clip(mat, ab, b, bc, centre, reaching, depth + 1)
	_clip(mat, centre, bc, c, cd, reaching, depth + 1)
	_clip(mat, da, centre, cd, d, reaching, depth + 1)


## The clip's resolution follows the section: the smallest tube on the road decides
## what a quad can hide, and the section's height what an edge may be ragged by.
func _size_clip(road: Road) -> void:
	var smallest := INF
	var height := road.carriageway_h
	for t in road.tubes:
		smallest = minf(smallest, minf(t.hw, t.hh) * 2.0)
	_max_untested = maxf(smallest * MAX_UNTESTED_SHARE, 4.0)
	_min_clip = maxf(height * MIN_CLIP_SHARE, 1.0)


static func _inside_any(near: Array[Tube], p: Vector3) -> bool:
	for t in near:
		if t.contains(p, EPS):
			return true
	return false


func _emit(mat: int, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var n := (b - a).cross(d - a)
	if n.length_squared() < 1e-9:
		n = (c - a).cross(d - b)
	n = n.normalized()
	var vs := _verts[mat]
	var ns := _norms[mat]
	vs.append(a)
	vs.append(b)
	vs.append(c)
	vs.append(a)
	vs.append(c)
	vs.append(d)
	for k in range(6):
		ns.append(n)
	if _want_centres:
		var cs := _centres[mat]
		for p: Vector3 in [a, b, c, a, c, d]:
			var centre := _c0 if p.distance_squared_to(_c0) <= p.distance_squared_to(_c1) else _c1
			cs.append(centre.x)
			cs.append(centre.y)
			cs.append(centre.z)
	if _want_faces:
		_faces.append(a)
		_faces.append(b)
		_faces.append(c)
		_faces.append(a)
		_faces.append(c)
		_faces.append(d)
