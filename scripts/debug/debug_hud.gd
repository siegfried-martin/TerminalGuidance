class_name DebugHud
extends CanvasLayer
## The instrument panel. Built before gameplay on purpose — everything else is
## played through it (see the build order in COMBAT_POC_IMPLEMENTATION.md).
##
## Rows are registered as callables returning a string, so a system can expose a
## readout without the HUD knowing anything about that system:
##     hud.add_row("fuse", func() -> String: return "%.1fs" % missile.fuse_left)
##
## The tuning block at the bottom is permanent: it shows the reload counter, any
## parse error, and every tuning key that has been asked for and was missing.
## A missing feel parameter must never be quietly survivable.

const _ROW_FONT_SIZE := 14
const _MISSING_COLOR := Color(1.0, 0.36, 0.36)
const _OK_COLOR := Color(0.62, 0.98, 0.72)

var _rows: Array[Dictionary] = []
var _row_box: VBoxContainer
var _status: Label
var _panel: PanelContainer


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	add_child(margin)

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.05, 0.72)
	style.set_content_margin_all(10)
	style.set_corner_radius_all(4)
	_panel.add_theme_stylebox_override("panel", style)
	margin.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	_panel.add_child(column)

	_row_box = VBoxContainer.new()
	_row_box.add_theme_constant_override("separation", 2)
	column.add_child(_row_box)

	var sep := HSeparator.new()
	column.add_child(sep)

	_status = _make_label()
	column.add_child(_status)


func _make_label() -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", _ROW_FONT_SIZE)
	return label


## Register a readout. `getter` is called once per frame and returns its value.
func add_row(title: String, getter: Callable) -> void:
	var label := _make_label()
	_row_box.add_child(label)
	_rows.append({"title": title, "getter": getter, "label": label})


func _process(_delta: float) -> void:
	if not visible:
		return
	for row in _rows:
		var getter := row["getter"] as Callable
		var label := row["label"] as Label
		label.text = "%-13s %s" % [row["title"] + ":", str(getter.call())]
	_update_status()


func _update_status() -> void:
	var err := Tuning.load_error()
	var missing := Tuning.missing_keys()
	if not err.is_empty():
		_status.text = "tuning: ERROR — " + err
		_status.add_theme_color_override("font_color", _MISSING_COLOR)
	elif missing.size() > 0:
		_status.text = "tuning: MISSING KEYS — " + ", ".join(missing)
		_status.add_theme_color_override("font_color", _MISSING_COLOR)
	else:
		_status.text = "tuning: ok (%d loads) — edit tuning.cfg and save to hot-reload" % Tuning.reload_count()
		_status.add_theme_color_override("font_color", _OK_COLOR)


func toggle() -> void:
	visible = not visible
