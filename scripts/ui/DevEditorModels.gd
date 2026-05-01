class_name DevEditorModels
extends RefCounted

const WARDROBE_SLOTS := ["top", "bottom", "shoes", "hairAccessory", "faceAccessory", "earAccessory", "horns", "tail"]
const WARDROBE_PIECE_TARGETS := ["torso", "hip", "leftArm", "leftForearm", "rightArm", "rightForearm", "leftThigh", "leftShank", "rightThigh", "rightShank", "leftFoot", "leftToe", "rightFoot", "rightToe"]
const COLOR_GROUPS := ["", "Clothing.Top.Base", "Clothing.Top.Sleeves", "Clothing.Bottom.Hip", "Clothing.Bottom.Legs", "Clothing.Shoes.Base", "Clothing.Shoes.Sole"]
const HAND_SPRITES := ["", "relaxed", "open", "fist", "point"]
const FOOT_SPRITES := ["", "front", "inward", "outward"]
const FACE_SPRITE_PARTS := ["mouth", "leftEye", "rightEye", "nose"]


static func unique_id(base_id: String, records: Variant) -> String:
	var ids := {}
	if records is Array:
		for record in records:
			ids[String(record.get("id", ""))] = true
	elif records is Dictionary:
		for id in records.keys():
			ids[String(id)] = true
	var candidate = _slug(base_id)
	if candidate == "":
		candidate = "new-record"
	if not ids.has(candidate):
		return candidate
	var counter := 2
	while ids.has("%s-%d" % [candidate, counter]):
		counter += 1
	return "%s-%d" % [candidate, counter]


static func create_wardrobe_item(existing: Array) -> Dictionary:
	var id = unique_id("new-wardrobe-item", existing)
	return {
		"id": id,
		"name": "New Wardrobe Item",
		"slot": "top",
		"description": "",
		"visualId": "%s-visual" % id,
		"color": "#ffffff",
		"pieces": [],
	}


static func create_equipment_visual(id: String = "", existing: Array = []) -> Dictionary:
	var visual_id = id if id != "" else unique_id("new-equipment-visual", existing)
	return {
		"id": visual_id,
		"name": "New Equipment Visual",
		"slot": "top",
		"pieces": [],
	}


static func create_equipment_asset(existing: Array) -> Dictionary:
	var id = unique_id("custom-equipment-asset", existing)
	return {
		"id": id,
		"name": "Custom Equipment Asset",
		"source": "custom",
		"actorSpace": false,
		"svgMarkup": "<g><path d=\"M-40 -40 L40 -40 L40 40 L-40 40 Z\" fill=\"var(--equip-base)\"/></g>",
	}


static func create_body_part(existing_parts: Array) -> Dictionary:
	var id = unique_id("newBodyPart", existing_parts)
	return {
		"id": id,
		"parentId": "body",
		"layer": "front",
		"pivot": {"x": 1200.0, "y": 1200.0},
		"svgMarkup": "<g><path d=\"M-40 -40 L40 -40 L40 40 L-40 40 Z\" fill=\"var(--doll-skin)\"/></g>",
		"variations": {},
		"latticeVariations": {},
	}


static func create_pose(existing: Array) -> Dictionary:
	var id = unique_id("new-pose", existing)
	return {"id": id, "name": "New Pose", "parts": {}, "sprites": {}}


static func create_animation(existing: Array) -> Dictionary:
	var id = unique_id("new-animation", existing)
	return {
		"id": id,
		"name": "New Animation",
		"frameCount": 48,
		"fps": 24.0,
		"loop": true,
		"visibleInPlayer": true,
		"keyframes": [{"frame": 0, "poseId": "idle"}],
	}


static func create_lattice_variation(part: Dictionary, id: String = "") -> Dictionary:
	var next_id = id if id != "" else unique_id("customLattice", _variation_id_records(part))
	var bounds = bounds_for_markup(String(part.get("svgMarkup", "")))
	return {
		"id": next_id,
		"sourceVariationId": "",
		"rows": 3,
		"columns": 3,
		"bounds": bounds,
		"points": Lattice.create_identity_points(bounds, 3, 3),
	}


static func duplicate_record(record: Dictionary, existing: Array) -> Dictionary:
	var clone: Dictionary = record.duplicate(true)
	clone["id"] = unique_id("%s-copy" % String(record.get("id", "record")), existing)
	clone["name"] = "%s Copy" % String(record.get("name", record.get("id", "Record")))
	return clone


static func record_index_by_id(records: Array, id: String) -> int:
	for index in range(records.size()):
		if String(records[index].get("id", "")) == id:
			return index
	return -1


static func record_by_id(records: Array, id: String) -> Dictionary:
	var index = record_index_by_id(records, id)
	return records[index] if index >= 0 else {}


static func rename_asset_references(visuals: Array, old_id: String, new_id: String) -> void:
	if old_id == "" or old_id == new_id:
		return
	for visual in visuals:
		for piece in visual.get("pieces", []):
			if String(piece.get("assetId", "")) == old_id:
				piece["assetId"] = new_id


static func rename_visual_references(wardrobe: Array, old_id: String, new_id: String) -> void:
	if old_id == "" or old_id == new_id:
		return
	for item in wardrobe:
		if String(item.get("visualId", "")) == old_id:
			item["visualId"] = new_id


static func rename_body_part_references(draft: Variant, old_id: String, new_id: String) -> void:
	if old_id == "" or old_id == new_id:
		return
	for variant in draft.body_rig.keys():
		for part in draft.body_rig[variant].get("parts", []):
			if String(part.get("parentId", "")) == old_id:
				part["parentId"] = new_id
	for visual in draft.equipment_visuals:
		for piece in visual.get("pieces", []):
			if String(piece.get("target", "")) == old_id:
				piece["target"] = new_id
	for pose in draft.poses:
		if pose.get("parts", {}).has(old_id):
			pose["parts"][new_id] = pose["parts"][old_id]
			pose["parts"].erase(old_id)
		if pose.get("sprites", {}).has(old_id):
			pose["sprites"][new_id] = pose["sprites"][old_id]
			pose["sprites"].erase(old_id)


static func rename_pose_references(animations: Array, old_id: String, new_id: String) -> void:
	if old_id == "" or old_id == new_id:
		return
	for animation in animations:
		for keyframe in animation.get("keyframes", []):
			if keyframe is Dictionary and String(keyframe.get("poseId", "")) == old_id:
				keyframe["poseId"] = new_id


static func sync_wardrobe_pieces_from_visual(item: Dictionary, visual: Dictionary) -> void:
	var pieces: Array = []
	for piece in visual.get("pieces", []):
		var target = String(piece.get("target", ""))
		if WARDROBE_PIECE_TARGETS.has(target):
			var next_piece := {"target": target}
			var color_group = String(piece.get("colorGroup", ""))
			if color_group != "":
				next_piece["colorGroup"] = color_group
			pieces.append(next_piece)
	if pieces.is_empty():
		item.erase("pieces")
	else:
		item["pieces"] = pieces


static func resize_lattice_variation(variation: Dictionary, rows: int, columns: int) -> Dictionary:
	var next = variation.duplicate(true)
	next["rows"] = clampi(rows, Lattice.MIN_DIVISIONS, Lattice.MAX_DIVISIONS)
	next["columns"] = clampi(columns, Lattice.MIN_DIVISIONS, Lattice.MAX_DIVISIONS)
	next["points"] = Lattice.create_identity_points(next.get("bounds", _default_bounds()), int(next["rows"]), int(next["columns"]))
	return next


static func reset_lattice_points(variation: Dictionary) -> void:
	variation["points"] = Lattice.create_identity_points(variation.get("bounds", _default_bounds()), int(variation.get("rows", 3)), int(variation.get("columns", 3)))


static func bounds_for_markup(markup: String) -> Dictionary:
	var geometry_bounds = _extract_geometry_bounds(markup)
	if not geometry_bounds.is_empty():
		return geometry_bounds
	var view_box = _extract_view_box(markup)
	return view_box if not view_box.is_empty() else _default_bounds()


static func variation_ids_for_part(part: Dictionary) -> Array[String]:
	var ids: Array[String] = [""]
	for id in part.get("variations", {}).keys():
		ids.append(String(id))
	for id in part.get("latticeVariations", {}).keys():
		ids.append(String(id))
	return ids


static func source_markup_for_lattice(part: Dictionary, lattice_variation: Dictionary) -> String:
	var source_id = String(lattice_variation.get("sourceVariationId", ""))
	if source_id != "":
		return String(part.get("variations", {}).get(source_id, part.get("svgMarkup", "")))
	return String(part.get("svgMarkup", ""))


static func all_rig_targets(repo: ContentRepository) -> Array[String]:
	var targets = repo.known_rig_target_ids()
	targets.sort()
	return targets


static func _variation_id_records(part: Dictionary) -> Array:
	var records: Array = []
	for id in part.get("variations", {}).keys():
		records.append({"id": id})
	for id in part.get("latticeVariations", {}).keys():
		records.append({"id": id})
	return records


static func _extract_view_box(markup: String) -> Dictionary:
	var regex := RegEx.new()
	regex.compile("viewBox\\s*=\\s*['\\\"]\\s*([-+\\d\\.]+)\\s+([-+\\d\\.]+)\\s+([-+\\d\\.]+)\\s+([-+\\d\\.]+)")
	var match = regex.search(markup)
	if match == null:
		return {}
	return {
		"x": float(match.get_string(1)),
		"y": float(match.get_string(2)),
		"width": maxf(1.0, float(match.get_string(3))),
		"height": maxf(1.0, float(match.get_string(4))),
	}


static func _extract_geometry_bounds(markup: String) -> Dictionary:
	var points: Array = []
	_append_path_points(markup, points)
	_append_rect_points(markup, points)
	_append_circle_points(markup, points)
	_append_ellipse_points(markup, points)
	_append_line_points(markup, points)
	_append_poly_points(markup, "polygon", points)
	_append_poly_points(markup, "polyline", points)
	return _bounds_from_points(points)


static func _append_path_points(markup: String, points: Array) -> void:
	for attributes in _element_attributes(markup, "path"):
		if _is_hidden_shape(attributes) or not attributes.has("d"):
			continue
		_append_path_data_points(String(attributes["d"]), points)


static func _append_rect_points(markup: String, points: Array) -> void:
	for attributes in _element_attributes(markup, "rect"):
		if _is_hidden_shape(attributes):
			continue
		var rect_x = _attribute_float(attributes, "x", 0.0)
		var rect_y = _attribute_float(attributes, "y", 0.0)
		var rect_width = _attribute_float(attributes, "width", 0.0)
		var rect_height = _attribute_float(attributes, "height", 0.0)
		if rect_width <= 0.0 or rect_height <= 0.0:
			continue
		_append_rect_bounds(points, rect_x, rect_y, rect_width, rect_height)


static func _append_circle_points(markup: String, points: Array) -> void:
	for attributes in _element_attributes(markup, "circle"):
		if _is_hidden_shape(attributes):
			continue
		var center_x = _attribute_float(attributes, "cx", 0.0)
		var center_y = _attribute_float(attributes, "cy", 0.0)
		var radius = maxf(0.0, _attribute_float(attributes, "r", 0.0))
		if radius <= 0.0:
			continue
		_append_rect_bounds(points, center_x - radius, center_y - radius, radius * 2.0, radius * 2.0)


static func _append_ellipse_points(markup: String, points: Array) -> void:
	for attributes in _element_attributes(markup, "ellipse"):
		if _is_hidden_shape(attributes):
			continue
		var center_x = _attribute_float(attributes, "cx", 0.0)
		var center_y = _attribute_float(attributes, "cy", 0.0)
		var radius_x = maxf(0.0, _attribute_float(attributes, "rx", 0.0))
		var radius_y = maxf(0.0, _attribute_float(attributes, "ry", 0.0))
		if radius_x <= 0.0 or radius_y <= 0.0:
			continue
		_append_rect_bounds(points, center_x - radius_x, center_y - radius_y, radius_x * 2.0, radius_y * 2.0)


static func _append_line_points(markup: String, points: Array) -> void:
	for attributes in _element_attributes(markup, "line"):
		if _is_hidden_shape(attributes):
			continue
		points.append(Vector2(_attribute_float(attributes, "x1", 0.0), _attribute_float(attributes, "y1", 0.0)))
		points.append(Vector2(_attribute_float(attributes, "x2", 0.0), _attribute_float(attributes, "y2", 0.0)))


static func _append_poly_points(markup: String, tag_name: String, points: Array) -> void:
	for attributes in _element_attributes(markup, tag_name):
		if _is_hidden_shape(attributes) or not attributes.has("points"):
			continue
		var numbers = _numbers_from_text(String(attributes["points"]))
		for index in range(0, numbers.size() - 1, 2):
			points.append(Vector2(numbers[index], numbers[index + 1]))


static func _append_path_data_points(path_data: String, points: Array) -> void:
	var tokens = _tokenize_path_data(path_data)
	var current := Vector2.ZERO
	var start := Vector2.ZERO
	var index := 0
	var command := ""
	while index < tokens.size():
		if _is_svg_path_command(tokens[index]):
			command = tokens[index]
			index += 1
		if command == "":
			break
		var upper = command.to_upper()
		var relative = command != upper
		if upper == "M":
			var first := true
			while index < tokens.size() and not _is_svg_path_command(tokens[index]):
				if not _path_has_numbers(tokens, index, 2):
					return
				var next_point = _read_path_point(tokens, index, current, relative)
				index += 2
				points.append(next_point)
				current = next_point
				if first:
					start = next_point
				first = false
		elif upper == "L" or upper == "T":
			while index < tokens.size() and not _is_svg_path_command(tokens[index]):
				if not _path_has_numbers(tokens, index, 2):
					return
				var next_point = _read_path_point(tokens, index, current, relative)
				index += 2
				points.append(next_point)
				current = next_point
		elif upper == "H":
			while index < tokens.size() and not _is_svg_path_command(tokens[index]):
				if not _path_has_numbers(tokens, index, 1):
					return
				var next_x = float(tokens[index]) + (current.x if relative else 0.0)
				index += 1
				current = Vector2(next_x, current.y)
				points.append(current)
		elif upper == "V":
			while index < tokens.size() and not _is_svg_path_command(tokens[index]):
				if not _path_has_numbers(tokens, index, 1):
					return
				var next_y = float(tokens[index]) + (current.y if relative else 0.0)
				index += 1
				current = Vector2(current.x, next_y)
				points.append(current)
		elif upper == "C":
			while index < tokens.size() and not _is_svg_path_command(tokens[index]):
				if not _path_has_numbers(tokens, index, 6):
					return
				var control_a = _read_path_point(tokens, index, current, relative)
				var control_b = _read_path_point(tokens, index + 2, current, relative)
				var next_point = _read_path_point(tokens, index + 4, current, relative)
				index += 6
				points.append(control_a)
				points.append(control_b)
				points.append(next_point)
				current = next_point
		elif upper == "Q" or upper == "S":
			while index < tokens.size() and not _is_svg_path_command(tokens[index]):
				if not _path_has_numbers(tokens, index, 4):
					return
				var control = _read_path_point(tokens, index, current, relative)
				var next_point = _read_path_point(tokens, index + 2, current, relative)
				index += 4
				points.append(control)
				points.append(next_point)
				current = next_point
		elif upper == "A":
			while index < tokens.size() and not _is_svg_path_command(tokens[index]):
				if not _path_has_numbers(tokens, index, 7):
					return
				var radius_x = absf(float(tokens[index]))
				var radius_y = absf(float(tokens[index + 1]))
				index += 5
				var next_point = _read_path_point(tokens, index, current, relative)
				index += 2
				_append_rect_bounds(points, current.x - radius_x, current.y - radius_y, radius_x * 2.0, radius_y * 2.0)
				_append_rect_bounds(points, next_point.x - radius_x, next_point.y - radius_y, radius_x * 2.0, radius_y * 2.0)
				points.append(next_point)
				current = next_point
		elif upper == "Z":
			current = start
			points.append(current)
		else:
			return


static func _element_attributes(markup: String, tag_name: String) -> Array:
	var element_regex := RegEx.new()
	element_regex.compile("<%s\\b([^>]*)>" % tag_name)
	var attribute_regex := RegEx.new()
	attribute_regex.compile("([:\\w-]+)\\s*=\\s*([\"'])(.*?)\\2")
	var results: Array = []
	for element_match in element_regex.search_all(markup):
		var attributes := {}
		for attribute_match in attribute_regex.search_all(element_match.get_string(1)):
			attributes[attribute_match.get_string(1)] = attribute_match.get_string(3)
		results.append(attributes)
	return results


static func _is_hidden_shape(attributes: Dictionary) -> bool:
	if String(attributes.get("display", "")).strip_edges().to_lower() == "none":
		return true
	if String(attributes.get("visibility", "")).strip_edges().to_lower() == "hidden":
		return true
	if _attribute_float(attributes, "opacity", 1.0) <= 0.0:
		return true
	var fill = String(attributes.get("fill", "")).strip_edges().to_lower()
	var stroke = String(attributes.get("stroke", "")).strip_edges().to_lower()
	return fill == "none" and (stroke == "" or stroke == "none")


static func _attribute_float(attributes: Dictionary, key: String, fallback: float) -> float:
	if not attributes.has(key):
		return fallback
	return String(attributes[key]).to_float()


static func _append_rect_bounds(points: Array, rect_x: float, rect_y: float, rect_width: float, rect_height: float) -> void:
	points.append(Vector2(rect_x, rect_y))
	points.append(Vector2(rect_x + rect_width, rect_y + rect_height))


static func _bounds_from_points(points: Array) -> Dictionary:
	if points.is_empty():
		return {}
	var first_point: Vector2 = points[0]
	var min_x = first_point.x
	var max_x = first_point.x
	var min_y = first_point.y
	var max_y = first_point.y
	for point_value in points:
		var point: Vector2 = point_value
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_y = minf(min_y, point.y)
		max_y = maxf(max_y, point.y)
	return {
		"x": min_x,
		"y": min_y,
		"width": maxf(1.0, max_x - min_x),
		"height": maxf(1.0, max_y - min_y),
	}


static func _numbers_from_text(text: String) -> Array[float]:
	var regex := RegEx.new()
	regex.compile("[-+]?(?:(?:\\d*\\.\\d+)|(?:\\d+\\.?))(?:[eE][-+]?\\d+)?")
	var numbers: Array[float] = []
	for match in regex.search_all(text):
		numbers.append(float(match.get_string()))
	return numbers


static func _tokenize_path_data(path_data: String) -> Array[String]:
	var regex := RegEx.new()
	regex.compile("[AaCcHhLlMmQqSsTtVvZz]|[-+]?(?:(?:\\d*\\.\\d+)|(?:\\d+\\.?))(?:[eE][-+]?\\d+)?")
	var tokens: Array[String] = []
	for match in regex.search_all(path_data):
		tokens.append(match.get_string())
	return tokens


static func _read_path_point(tokens: Array[String], token_index: int, current: Vector2, relative: bool) -> Vector2:
	return Vector2(
		float(tokens[token_index]) + (current.x if relative else 0.0),
		float(tokens[token_index + 1]) + (current.y if relative else 0.0)
	)


static func _is_svg_path_command(token: String) -> bool:
	return token.length() == 1 and "AaCcHhLlMmQqSsTtVvZz".contains(token)


static func _path_has_numbers(tokens: Array[String], token_index: int, count: int) -> bool:
	if token_index + count > tokens.size():
		return false
	for number_index in range(count):
		if _is_svg_path_command(tokens[token_index + number_index]):
			return false
	return true


static func _default_bounds() -> Dictionary:
	return {"x": -100.0, "y": -100.0, "width": 200.0, "height": 200.0}


static func _slug(value: String) -> String:
	var result := ""
	var previous_dash := false
	for index in range(value.length()):
		var character = value[index].to_lower()
		var code = character.unicode_at(0)
		var allowed = (code >= 97 and code <= 122) or (code >= 48 and code <= 57)
		if allowed:
			result += character
			previous_dash = false
		elif not previous_dash:
			result += "-"
			previous_dash = true
	return result.strip_edges().trim_prefix("-").trim_suffix("-")
