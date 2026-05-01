class_name Lattice
extends RefCounted

const MIN_DIVISIONS := 2
const MAX_DIVISIONS := 6

static func create_identity_points(bounds: Dictionary, rows: int, columns: int) -> Array:
	var points: Array = []
	var safe_rows = maxi(MIN_DIVISIONS, rows)
	var safe_columns = maxi(MIN_DIVISIONS, columns)
	for row in range(safe_rows):
		var y = float(bounds.get("y", 0.0)) + (float(bounds.get("height", 1.0)) * row) / maxf(1.0, safe_rows - 1.0)
		for column in range(safe_columns):
			var x = float(bounds.get("x", 0.0)) + (float(bounds.get("width", 1.0)) * column) / maxf(1.0, safe_columns - 1.0)
			points.append({"x": x, "y": y})
	return points


static func validate_variation_shape(variation: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var rows = int(variation.get("rows", 0))
	var columns = int(variation.get("columns", 0))
	var bounds = variation.get("bounds", {})
	var points = variation.get("points", [])
	if rows < MIN_DIVISIONS or rows > MAX_DIVISIONS:
		errors.append("rows must be an integer from %d to %d" % [MIN_DIVISIONS, MAX_DIVISIONS])
	if columns < MIN_DIVISIONS or columns > MAX_DIVISIONS:
		errors.append("columns must be an integer from %d to %d" % [MIN_DIVISIONS, MAX_DIVISIONS])
	if not _is_valid_bounds(bounds):
		errors.append("bounds must have finite x/y/width/height and positive size")
	if not points is Array or points.size() != rows * columns:
		errors.append("points length must equal rows * columns")
	else:
		for index in range(points.size()):
			var point = points[index]
			if not _is_finite_number(point.get("x")) or not _is_finite_number(point.get("y")):
				errors.append("point %d must have finite x/y values" % index)
	return errors


static func apply_lattice_to_svg_markup(markup: String, variation: Dictionary) -> String:
	if validate_variation_shape(variation).size() > 0:
		return markup
	var path_regex := RegEx.new()
	path_regex.compile("<path\\b([^>]*)>")
	var attr_regex := RegEx.new()
	attr_regex.compile("([:\\w-]+)\\s*=\\s*([\"'])(.*?)\\2")
	var result := markup
	var offset := 0
	for path_match in path_regex.search_all(markup):
		var raw_attributes = path_match.get_string(1)
		var attrs = _read_attributes(raw_attributes, attr_regex)
		if not attrs.has("d"):
			continue
		var deformed = deform_path_data(String(attrs["d"]), variation)
		var next_attributes = _set_attribute(raw_attributes, "d", deformed)
		var replacement = "<path%s>" % next_attributes
		var start = path_match.get_start(0) + offset
		var end = path_match.get_end(0) + offset
		result = result.substr(0, start) + replacement + result.substr(end)
		offset += replacement.length() - (end - start)
	return result


static func deform_lattice_point(point: Dictionary, variation: Dictionary) -> Dictionary:
	var bounds: Dictionary = variation["bounds"]
	var u = (float(point["x"]) - float(bounds["x"])) / float(bounds["width"])
	var v = (float(point["y"]) - float(bounds["y"])) / float(bounds["height"])
	if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
		return {"x": float(point["x"]), "y": float(point["y"])}

	var columns = int(variation["columns"])
	var rows = int(variation["rows"])
	var controls: Array = variation["points"]
	var x := 0.0
	var y := 0.0
	for row in range(rows):
		var row_weight = _bernstein(row, rows - 1, v)
		for column in range(columns):
			var column_weight = _bernstein(column, columns - 1, u)
			var weight = row_weight * column_weight
			var control: Dictionary = controls[row * columns + column]
			x += float(control["x"]) * weight
			y += float(control["y"]) * weight
	return {"x": x, "y": y}


static func deform_path_data(path_data: String, variation: Dictionary) -> String:
	var tokens = _tokenize_path(path_data)
	var output: Array[String] = []
	var state := {"x": 0.0, "y": 0.0, "start_x": 0.0, "start_y": 0.0}
	var index := 0
	var command := ""
	while index < tokens.size():
		if _is_path_command(tokens[index]):
			command = tokens[index]
			index += 1
		if command == "":
			break
		var upper = command.to_upper()
		var relative = command != upper
		if upper == "M":
			var first := true
			while index < tokens.size() and not _is_path_command(tokens[index]):
				var point = _read_point(tokens, index, state, relative)
				index += 2
				var warped = deform_lattice_point(point, variation)
				output.append("%s%s" % ["M" if first else "L", _format_point(warped)])
				_set_current(state, point)
				if first:
					state["start_x"] = point["x"]
					state["start_y"] = point["y"]
				first = false
		elif upper == "L":
			while index < tokens.size() and not _is_path_command(tokens[index]):
				var point = _read_point(tokens, index, state, relative)
				index += 2
				output.append("L%s" % _format_point(deform_lattice_point(point, variation)))
				_set_current(state, point)
		elif upper == "H":
			while index < tokens.size() and not _is_path_command(tokens[index]):
				var next_x = float(tokens[index]) + (float(state["x"]) if relative else 0.0)
				index += 1
				var point = {"x": next_x, "y": float(state["y"])}
				output.append("L%s" % _format_point(deform_lattice_point(point, variation)))
				_set_current(state, point)
		elif upper == "V":
			while index < tokens.size() and not _is_path_command(tokens[index]):
				var next_y = float(tokens[index]) + (float(state["y"]) if relative else 0.0)
				index += 1
				var point = {"x": float(state["x"]), "y": next_y}
				output.append("L%s" % _format_point(deform_lattice_point(point, variation)))
				_set_current(state, point)
		elif upper == "C":
			while index < tokens.size() and not _is_path_command(tokens[index]):
				var c1 = _read_point(tokens, index, state, relative)
				var c2 = _read_point(tokens, index + 2, state, relative)
				var end = _read_point(tokens, index + 4, state, relative)
				index += 6
				output.append("C%s %s %s" % [
					_format_point(deform_lattice_point(c1, variation)),
					_format_point(deform_lattice_point(c2, variation)),
					_format_point(deform_lattice_point(end, variation)),
				])
				_set_current(state, end)
		elif upper == "Q" or upper == "S":
			while index < tokens.size() and not _is_path_command(tokens[index]):
				var c1 = _read_point(tokens, index, state, relative)
				var end = _read_point(tokens, index + 2, state, relative)
				index += 4
				output.append("%s%s %s" % [
					upper,
					_format_point(deform_lattice_point(c1, variation)),
					_format_point(deform_lattice_point(end, variation)),
				])
				_set_current(state, end)
		elif upper == "T":
			while index < tokens.size() and not _is_path_command(tokens[index]):
				var end = _read_point(tokens, index, state, relative)
				index += 2
				output.append("T%s" % _format_point(deform_lattice_point(end, variation)))
				_set_current(state, end)
		elif upper == "A":
			while index < tokens.size() and not _is_path_command(tokens[index]):
				index += 5
				var end = _read_point(tokens, index, state, relative)
				index += 2
				output.append("L%s" % _format_point(deform_lattice_point(end, variation)))
				_set_current(state, end)
		elif upper == "Z":
			output.append("Z")
			state["x"] = state["start_x"]
			state["y"] = state["start_y"]
		else:
			break
	return " ".join(output)


static func _tokenize_path(path_data: String) -> Array[String]:
	var regex := RegEx.new()
	regex.compile("[AaCcHhLlMmQqSsTtVvZz]|[-+]?(?:(?:\\d*\\.\\d+)|(?:\\d+\\.?))(?:[eE][-+]?\\d+)?")
	var tokens: Array[String] = []
	for match in regex.search_all(path_data):
		tokens.append(match.get_string())
	return tokens


static func _read_attributes(raw_attributes: String, attr_regex: RegEx) -> Dictionary:
	var attrs := {}
	for match in attr_regex.search_all(raw_attributes):
		attrs[match.get_string(1)] = match.get_string(3)
	return attrs


static func _set_attribute(raw_attributes: String, name: String, value: String) -> String:
	var regex := RegEx.new()
	regex.compile("\\s%s\\s*=\\s*([\"']).*?\\1" % name)
	if regex.search(raw_attributes):
		return regex.sub(raw_attributes, " %s=\"%s\"" % [name, value], false)
	return "%s %s=\"%s\"" % [raw_attributes, name, value]


static func _read_point(tokens: Array[String], index: int, state: Dictionary, relative: bool) -> Dictionary:
	return {
		"x": float(tokens[index]) + (float(state["x"]) if relative else 0.0),
		"y": float(tokens[index + 1]) + (float(state["y"]) if relative else 0.0),
	}


static func _set_current(state: Dictionary, point: Dictionary) -> void:
	state["x"] = point["x"]
	state["y"] = point["y"]


static func _format_point(point: Dictionary) -> String:
	return "%s %s" % [_format_number(float(point["x"])), _format_number(float(point["y"]))]


static func _format_number(value: float) -> String:
	if not is_finite(value):
		return "0"
	var text = "%.3f" % value
	while text.ends_with("0") and text.contains("."):
		text = text.substr(0, text.length() - 1)
	if text.ends_with("."):
		text = text.substr(0, text.length() - 1)
	return text


static func _is_path_command(token: String) -> bool:
	return token.length() == 1 and "AaCcHhLlMmQqSsTtVvZz".contains(token)


static func _is_valid_bounds(bounds: Variant) -> bool:
	return bounds is Dictionary and _is_finite_number(bounds.get("x")) and _is_finite_number(bounds.get("y")) and _is_finite_number(bounds.get("width")) and _is_finite_number(bounds.get("height")) and float(bounds["width"]) > 0.0 and float(bounds["height"]) > 0.0


static func _is_finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _binomial(n: int, k: int) -> float:
	if k < 0 or k > n:
		return 0.0
	var result := 1.0
	for index in range(1, k + 1):
		result = (result * float(n - index + 1)) / float(index)
	return result


static func _bernstein(index: int, degree: int, value: float) -> float:
	return _binomial(degree, index) * pow(value, index) * pow(1.0 - value, degree - index)
