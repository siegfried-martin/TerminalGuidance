class_name RoadLamps
extends Node3D
## The road's own light. Between systems it is dark on purpose (STATUS.md, the star),
## so the light out there is something the road carries: a lamp bar on every rib,
## above the glass roof of each carriageway, and a pool of real lights that follows
## the ship along whichever road it is on or nearest to.
##
## Two parts, because a 60 km road has hundreds of ribs and a scene cannot carry a
## light per rib. The FIXTURES are geometry — one instanced bar per rib per
## carriageway, built into each detailed chunk with the chunk and gone with it — and
## are the thing you see as a string of lights down the road. The LIGHTS are a small
## pool of omni lights, re-placed every frame onto the fixtures within
## `track_light_reach` of the ship, so the pool of light under each rib is real where
## the ship is and implied everywhere else. The pool is positioned from the road
## every frame, so the floating origin never has a stale light to move.
##
## Everything you would nudge is under `;;; Lights` in tuning.cfg.

## The pool never grows past this, whatever the reach and the rib spacing ask for;
## Forward+ is happy with far more, but a reach that asks for more than this is a
## reach that is doing a far chunk's job.
const MAX_LIGHTS := 64
## How far outside the glass the bar hangs, so it sits in the rib's collar rather
## than in the flyable section: what you see inside the tube is what you can hit.
const ABOVE_GLASS := 0.3
## The bar's length along the road, as a share of the rib it is fitted to.
const ALONG_SHARE := 0.6

static var _fixture_mesh: BoxMesh = null
static var _fixture_material: StandardMaterial3D = null

var _pool: Array[OmniLight3D] = []
var _live: int = 0
var _tube_name: String = ""


func _ready() -> void:
	name = "Lamps"
	retune()
	Tuning.reloaded.connect(retune)


## Re-read the tuning: the fixtures' glow and every pooled light's colour and reach.
func retune() -> void:
	_fixture_style()
	for light in _pool:
		_style(light)


static func _fixture_style() -> void:
	if _fixture_mesh == null:
		_fixture_mesh = BoxMesh.new()
		_fixture_mesh.size = Vector3.ONE
	if _fixture_material == null:
		_fixture_material = StandardMaterial3D.new()
		_fixture_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_fixture_material.emission_enabled = true
	var color := Tuning.color("exploration/track_light_color")
	_fixture_material.albedo_color = color
	_fixture_material.emission = color
	_fixture_material.emission_energy_multiplier = Tuning.num("exploration/track_lamp_glow")


static func _style(light: OmniLight3D) -> void:
	light.light_color = Tuning.color("exploration/track_light_color")
	light.light_energy = Tuning.num("exploration/track_light_energy")
	light.omni_range = Tuning.num("exploration/track_light_range")
	light.omni_attenuation = Tuning.num("exploration/track_light_attenuation")
	light.shadow_enabled = false


## Where a rib's lamp bar sits on one carriageway: in the collar above the glass roof.
static func fixture_frame(road: Road, tube: Tube, t: float) -> Transform3D:
	var f := road.path.frame(t)
	var right: Vector3 = f["right"]
	var up: Vector3 = f["up"]
	var thickness := Tuning.num("exploration/track_lamp_thickness")
	var origin: Vector3 = f["pos"] + right * tube.u0 \
		+ up * (road.half_height + ABOVE_GLASS + thickness * 0.5)
	return Transform3D(Basis(right, up, right.cross(up)), origin)


## The lamp bars for one chunk's stretch of a road: one per rib per carriageway,
## instanced. Built on the main thread at commit, because it is a few transforms.
static func fixtures(road: Road, chunk: Dictionary) -> MultiMeshInstance3D:
	_fixture_style()
	var t0 := float(chunk["t0"])
	var t1 := float(chunk["t1"])
	var size := Vector3(Tuning.num("exploration/track_lamp_metres"),
		Tuning.num("exploration/track_lamp_thickness"), road.rib_thickness * ALONG_SHARE)
	var frames: Array[Transform3D] = []
	for tr in road.rib_positions():
		if tr < t0 or tr >= t1:
			continue
		for tube in road.tubes:
			frames.append(fixture_frame(road, tube, tr))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _fixture_mesh
	mm.instance_count = frames.size()
	for i in frames.size():
		var f := frames[i]
		mm.set_instance_transform(i, Transform3D(f.basis.scaled_local(size), f.origin))
	var mi := MultiMeshInstance3D.new()
	mi.name = "Lamps"
	mi.multimesh = mm
	mi.material_override = _fixture_material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Put the pool's lights on the fixtures within reach of `here`, along the tube the
## ship is riding or, off the road, the nearest one. Called every frame by the map.
func follow(here: Vector3, riding: Tube, tubes: Array[Tube]) -> void:
	var reach := Tuning.num("exploration/track_light_reach")
	var tube := riding if riding != null else _nearest(here, tubes, reach)
	if tube == null or not Tuning.flag("exploration/track_lights_enabled"):
		_show(0)
		_tube_name = ""
		return
	_tube_name = tube.name
	var road := tube.road
	var t: float = tube.local(here)["t"]
	var length: float = road.path.length
	var wanted: Array[Transform3D] = []
	for tr in road.rib_positions():
		var d := absf(tr - t)
		if road.path.closed:
			d = minf(d, length - d)
		if d > reach:
			continue
		for each in road.tubes:
			if wanted.size() >= MAX_LIGHTS:
				break
			wanted.append(fixture_frame(road, each, tr))
	while _pool.size() < wanted.size():
		var light := OmniLight3D.new()
		light.name = "Lamp %d" % _pool.size()
		_style(light)
		add_child(light)
		_pool.append(light)
	for i in wanted.size():
		_pool[i].position = wanted[i].origin
	_show(wanted.size())


func _show(count: int) -> void:
	_live = count
	for i in _pool.size():
		_pool[i].visible = i < count


## The tube whose lamps are lit and how many lights are live, for the HUD.
func status() -> String:
	if _live == 0:
		return "no track lights"
	return "%d track lights on %s" % [_live, _tube_name]


func live_count() -> int:
	return _live


static func _nearest(here: Vector3, tubes: Array[Tube], reach: float) -> Tube:
	var best: Tube = null
	var best_d := reach
	for tube in tubes:
		if not tube.bounds.grow(reach).has_point(here):
			continue
		var d := float(tube.local(here)["dist"])
		if d < best_d:
			best_d = d
			best = tube
	return best
