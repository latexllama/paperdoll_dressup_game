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
		"price": 0,
		"hiddenUntilOwned": false,
		"pieces": [],
		"requiredSkillLevels": {},
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
	var view_box = _extract_view_box(markup)
	if not view_box.is_empty():
		return view_box
	var path_bounds = _extract_numeric_bounds(markup)
	return path_bounds if not path_bounds.is_empty() else _default_bounds()


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


static func _extract_numeric_bounds(markup: String) -> Dictionary:
	var regex := RegEx.new()
	regex.compile("[-+]?(?:(?:\\d*\\.\\d+)|(?:\\d+\\.?))(?:[eE][-+]?\\d+)?")
	var numbers: Array[float] = []
	for match in regex.search_all(markup):
		numbers.append(float(match.get_string()))
	if numbers.size() < 4:
		return {}
	var min_x = numbers[0]
	var max_x = numbers[0]
	var min_y = numbers[1]
	var max_y = numbers[1]
	for index in range(0, numbers.size() - 1, 2):
		min_x = minf(min_x, numbers[index])
		max_x = maxf(max_x, numbers[index])
		min_y = minf(min_y, numbers[index + 1])
		max_y = maxf(max_y, numbers[index + 1])
	return {
		"x": min_x,
		"y": min_y,
		"width": maxf(1.0, max_x - min_x),
		"height": maxf(1.0, max_y - min_y),
	}


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
