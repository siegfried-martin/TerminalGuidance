class_name TuningSchema
extends RefCounted
## Reads the *comments* out of tuning.cfg.
##
## ConfigFile parses values and throws the comments away, but the comments are
## where the documentation lives — and the debug panel needs them for its labels,
## tooltips and slider ranges. So the file is scanned a second time, as text.
##
## Annotation format:
##
##     ;;; The speed ladder
##     ;; Long-form description. One or more lines. Shown as the tooltip.
##     ;; Wraps as many lines as it needs.
##     base_speed = 90.0        ; [10..400] m/s. Short label, shown beside the row
##
## The `[min..max]` marker is optional. With it a numeric value gets a slider;
## without it, a plain number box. Everything after it is the short label.
##
## A `;;;` line opens a **group**, and every key after it belongs to that group until
## the next one or the next `[section]`. Groups exist because `[exploration]` grew past
## a hundred keys and a flat list of a hundred sliders is a list nobody can find
## anything in. They are a *presentation* device on purpose: a key's path is still
## `section/key`, so grouping one costs no rename, no ADR and no call site.
##
## Pure and static: no scene tree, no file access, so it is directly testable.

## Entry keys: section, group, key, path, short, long, min, max, has_range, line
static func parse(text: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var section := ""
	var group := ""
	var pending_long: PackedStringArray = []
	var lines := text.split("\n")

	for index in lines.size():
		var raw := lines[index]
		var trimmed := raw.strip_edges()

		if trimmed.is_empty():
			pending_long.clear()
			continue

		# Tested BEFORE `;;`, which it also starts with.
		if trimmed.begins_with(";;;"):
			group = trimmed.substr(3).strip_edges()
			pending_long.clear()
			continue

		if trimmed.begins_with(";;"):
			pending_long.append(trimmed.substr(2).strip_edges())
			continue

		if trimmed.begins_with(";"):
			# An ordinary banner comment. Not documentation for the next key.
			pending_long.clear()
			continue

		if trimmed.begins_with("[") and trimmed.ends_with("]"):
			section = trimmed.substr(1, trimmed.length() - 2).strip_edges()
			group = ""
			pending_long.clear()
			continue

		var equals := raw.find("=")
		if equals < 0:
			pending_long.clear()
			continue

		var key := raw.substr(0, equals).strip_edges()
		var comment := comment_of(raw.substr(equals + 1))
		var range_and_short := _split_range(comment)

		entries.append({
			"section": section,
			"group": group,
			"key": key,
			"path": "%s/%s" % [section, key],
			"short": String(range_and_short["short"]),
			"long": "\n".join(pending_long),
			"min": float(range_and_short["min"]),
			"max": float(range_and_short["max"]),
			"has_range": bool(range_and_short["has_range"]),
			"line": index,
		})
		pending_long.clear()

	return entries


## The value text of a `key = value ; comment` right-hand side, comment removed.
static func value_of(right_hand_side: String) -> String:
	return right_hand_side.substr(0, comment_start(right_hand_side)).strip_edges() \
		if comment_start(right_hand_side) >= 0 else right_hand_side.strip_edges()


## The comment text of a right-hand side, leading ';' removed.
static func comment_of(right_hand_side: String) -> String:
	var at := comment_start(right_hand_side)
	if at < 0:
		return ""
	return right_hand_side.substr(at + 1).strip_edges()


## Index of the ';' that starts the comment, ignoring semicolons inside quotes.
static func comment_start(text: String) -> int:
	var in_quotes := false
	for i in text.length():
		var character := text[i]
		if character == "\"":
			in_quotes = not in_quotes
		elif character == ";" and not in_quotes:
			return i
	return -1


static func _split_range(comment: String) -> Dictionary:
	var result := {"min": 0.0, "max": 0.0, "has_range": false, "short": comment}
	if not comment.begins_with("["):
		return result
	var close := comment.find("]")
	if close < 0:
		return result
	var inside := comment.substr(1, close - 1)
	var parts := inside.split("..", false)
	if parts.size() != 2:
		return result
	if not (parts[0].strip_edges().is_valid_float() and parts[1].strip_edges().is_valid_float()):
		return result
	result["min"] = parts[0].strip_edges().to_float()
	result["max"] = parts[1].strip_edges().to_float()
	result["has_range"] = true
	result["short"] = comment.substr(close + 1).strip_edges()
	return result
