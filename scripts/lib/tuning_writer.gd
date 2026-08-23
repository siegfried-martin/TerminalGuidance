class_name TuningWriter
extends RefCounted
## Writes changed values back into tuning.cfg **without touching anything else**.
##
## ADR 0033 forbids `ConfigFile.save()` on the tuning file: it serialises values
## only, so it would silently delete every comment — which is where all the
## documentation lives. This rewrites the value text of matching lines in place
## and leaves every other byte alone, including comments, blank lines, banner
## art, key order and section order.
##
## Pure and static: takes text in, returns text out. No file access, so the
## round-trip is testable without writing over the real file.

## `changes` maps "section/key" to the new value. Unknown paths are ignored.
static func apply(source: String, changes: Dictionary) -> String:
	if changes.is_empty():
		return source

	var lines := source.split("\n")
	var section := ""
	var out: PackedStringArray = []

	for raw in lines:
		var trimmed := raw.strip_edges()
		if trimmed.begins_with("[") and trimmed.ends_with("]"):
			section = trimmed.substr(1, trimmed.length() - 2).strip_edges()
			out.append(raw)
			continue

		var equals := raw.find("=")
		if equals < 0 or trimmed.begins_with(";"):
			out.append(raw)
			continue

		var key := raw.substr(0, equals).strip_edges()
		var path := "%s/%s" % [section, key]
		if not changes.has(path):
			out.append(raw)
			continue

		out.append(_rewrite(raw, equals, changes[path]))

	return "\n".join(out)


## Rebuild one line with a new value, preserving indentation, key text, the
## comment, and — where it still fits — the column the comment sat in.
static func _rewrite(raw: String, equals: int, value: Variant) -> String:
	var head := raw.substr(0, equals + 1)          # "  base_speed ="
	var rest := raw.substr(equals + 1)
	var comment_at := TuningSchema.comment_start(rest)

	var formatted := format_value(value)
	if comment_at < 0:
		return "%s %s" % [head, formatted]

	var comment := rest.substr(comment_at)          # "; [10..400] m/s. ..."
	var original_value := rest.substr(0, comment_at)
	# Keep the comment in its original column when the new value is no longer.
	var padding := original_value.length() - 1 - formatted.length()
	var spacer := " ".repeat(padding) if padding > 0 else " "
	return "%s %s%s%s" % [head, formatted, spacer, comment]


## Godot-literal text for a value, matching how tuning.cfg is written by hand.
static func format_value(value: Variant) -> String:
	match typeof(value):
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_INT:
			return str(value)
		TYPE_FLOAT:
			return format_float(float(value))
		TYPE_STRING, TYPE_STRING_NAME:
			return "\"%s\"" % String(value)
		TYPE_VECTOR3:
			var v := value as Vector3
			return "Vector3(%s, %s, %s)" % [format_float(v.x), format_float(v.y), format_float(v.z)]
		TYPE_COLOR:
			var c := value as Color
			return "\"#%s\"" % c.to_html(false)
	return str(value)


## Trim trailing zeros but always keep a decimal point, so a float stays a float
## when the file is read back — `90` would parse as an int and change the type.
static func format_float(value: float) -> String:
	var text := "%.4f" % value
	while text.ends_with("0") and not text.ends_with(".0"):
		text = text.substr(0, text.length() - 1)
	return text
