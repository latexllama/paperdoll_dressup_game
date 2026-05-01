class_name ContentRepository
extends RefCounted

const CONTENT_DIR := "res://content"
const REQUIRED_BODY_PART_IDS := [
	"body",
	"hip",
	"torso",
	"neck",
	"head",
	"headNub",
	"leftArm",
	"leftForearm",
	"leftHand",
	"rightArm",
	"rightForearm",
	"rightHand",
	"leftThigh",
	"leftShank",
	"leftFoot",
	"leftToe",
	"rightThigh",
	"rightShank",
	"rightFoot",
	"rightToe",
	"backHair",
	"frontHair",
	"face",
	"leftEye",
	"rightEye",
	"leftBrow",
	"rightBrow",
	"mouth",
	"nose",
	"leftEar",
	"rightEar",
	"horns",
	"tail",
]
const REQUIRED_BODY_PART_DEFAULTS := {
	"body": {"parentId": "", "layer": "body"},
	"hip": {"parentId": "body", "layer": "body"},
	"torso": {"parentId": "hip", "layer": "body"},
	"neck": {"parentId": "torso", "layer": "body"},
	"head": {"parentId": "neck", "layer": "head"},
	"headNub": {"parentId": "head", "layer": "head"},
	"leftArm": {"parentId": "torso", "layer": "upperLimbs"},
	"leftForearm": {"parentId": "leftArm", "layer": "frontLimbs"},
	"leftHand": {"parentId": "leftForearm", "layer": "frontLimbs"},
	"rightArm": {"parentId": "torso", "layer": "upperLimbs"},
	"rightForearm": {"parentId": "rightArm", "layer": "frontLimbs"},
	"rightHand": {"parentId": "rightForearm", "layer": "frontLimbs"},
	"leftThigh": {"parentId": "hip", "layer": "legs"},
	"leftShank": {"parentId": "leftThigh", "layer": "legs"},
	"leftFoot": {"parentId": "leftShank", "layer": "frontLimbs"},
	"leftToe": {"parentId": "leftFoot", "layer": "frontLimbs"},
	"rightThigh": {"parentId": "hip", "layer": "legs"},
	"rightShank": {"parentId": "rightThigh", "layer": "legs"},
	"rightFoot": {"parentId": "rightShank", "layer": "frontLimbs"},
	"rightToe": {"parentId": "rightFoot", "layer": "frontLimbs"},
	"backHair": {"parentId": "head", "layer": "back"},
	"frontHair": {"parentId": "head", "layer": "front"},
	"face": {"parentId": "head", "layer": "head"},
	"leftEye": {"parentId": "face", "layer": "head"},
	"rightEye": {"parentId": "face", "layer": "head"},
	"leftBrow": {"parentId": "face", "layer": "head"},
	"rightBrow": {"parentId": "face", "layer": "head"},
	"mouth": {"parentId": "face", "layer": "head"},
	"nose": {"parentId": "face", "layer": "head"},
	"leftEar": {"parentId": "head", "layer": "head"},
	"rightEar": {"parentId": "head", "layer": "head"},
	"horns": {"parentId": "head", "layer": "front"},
	"tail": {"parentId": "hip", "layer": "back"},
}

var content_dir := CONTENT_DIR
var body_rig: Dictionary = {}
var equipment_assets: Array = []
var equipment_visuals: Array = []
var wardrobe: Array = []
var poses: Array = []
var animations: Array = []
var sample_meta: Dictionary = {}
var starting_outfit: Dictionary = {}
var last_load_errors: Array[String] = []
var generated_body_part_repairs: Array[Dictionary] = []

var _asset_by_id: Dictionary = {}
var _visual_by_id: Dictionary = {}
var _wardrobe_by_id: Dictionary = {}
var _pose_by_id: Dictionary = {}
var _animation_by_id: Dictionary = {}
var _rig_part_by_variant: Dictionary = {}


func load_all() -> Dictionary:
	last_load_errors = []
	generated_body_part_repairs = []
	body_rig = _normalize_body_rig(_load_json("body_rig.json", {}, TYPE_DICTIONARY), true)
	equipment_assets = _load_json("equipment_assets.json", [], TYPE_ARRAY)
	equipment_visuals = _load_json("equipment_visuals.json", [], TYPE_ARRAY)
	wardrobe = _load_json("wardrobe.json", [], TYPE_ARRAY)
	poses = _load_json("poses.json", [], TYPE_ARRAY)
	animations = _load_json("animations.json", [], TYPE_ARRAY)
	sample_meta = _load_json("sample_meta.json", {}, TYPE_DICTIONARY)
	starting_outfit = _load_json("starting_outfit.json", {}, TYPE_DICTIONARY)
	_rebuild_indexes()
	var validation = ContentValidator.validate_repository(self)
	var errors: Array[String] = []
	errors.append_array(last_load_errors)
	errors.append_array(validation.get("errors", []))
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"load_errors": last_load_errors.duplicate(),
		"validation_errors": validation.get("errors", []),
		"generated_body_part_repairs": generated_body_part_repairs.duplicate(true),
	}


func reload_after_external_save() -> Dictionary:
	return load_all()


func save_collection(collection_name: String, value: Variant, validation_repo: ContentRepository = null) -> Dictionary:
	if not can_write_source_content():
		return {"ok": false, "errors": ["Source content can only be saved from the Godot editor runtime."]}
	var file_name = _file_name_for_collection(collection_name)
	if file_name == "":
		return {"ok": false, "errors": ["Unknown content collection: %s" % collection_name]}
	var value_to_save = _normalized_collection_value(collection_name, value)
	var validation_source = validation_repo if validation_repo != null else self
	var validation = ContentValidator.validate_collection(validation_source, collection_name, value_to_save)
	if not validation.get("ok", false):
		return validation
	var path = "%s/%s" % [content_dir, file_name]
	var temp_path = "%s.tmp" % path
	var file = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "errors": ["Could not open temporary %s for writing." % file_name]}
	file.store_string(JSON.stringify(value_to_save, "  ") + "\n")
	file.close()
	var replace_result = _replace_file_with_temp(temp_path, path)
	if not replace_result.get("ok", false):
		return replace_result
	set_collection(collection_name, value_to_save)
	_rebuild_indexes()
	return {"ok": true, "errors": []}


func can_write_source_content() -> bool:
	return OS.has_feature("editor")


func set_collection(collection_name: String, value: Variant) -> void:
	match collection_name:
		"body_rig":
			body_rig = _normalize_body_rig(value)
			generated_body_part_repairs = []
		"equipment_assets":
			equipment_assets = value
		"equipment_visuals":
			equipment_visuals = value
		"wardrobe":
			wardrobe = value
		"poses":
			poses = value
		"animations":
			animations = value
		"starting_outfit":
			starting_outfit = value
	_rebuild_indexes()


func wardrobe_item(item_id: String) -> Dictionary:
	return _wardrobe_by_id.get(item_id, {})


func equipment_visual(visual_id: String) -> Dictionary:
	return _visual_by_id.get(visual_id, {})


func equipment_asset(asset_id: String) -> Dictionary:
	return _asset_by_id.get(asset_id, {})


func pose(pose_id: String) -> Dictionary:
	return _pose_by_id.get(pose_id, poses[0] if poses.size() > 0 else {"id": "idle", "parts": {}})


func has_pose(pose_id: String) -> bool:
	return _pose_by_id.has(pose_id)


func animation(animation_id: String) -> Dictionary:
	return _animation_by_id.get(animation_id, {})


func has_animation(animation_id: String) -> bool:
	return _animation_by_id.has(animation_id)


func has_wardrobe_item(item_id: String) -> bool:
	return _wardrobe_by_id.has(item_id)


func body_parts_for_variant(variant: String) -> Array:
	return body_rig.get(variant, {}).get("parts", [])


func body_part(variant: String, part_id: String) -> Dictionary:
	return _rig_part_by_variant.get(variant, {}).get(part_id, {})


func known_rig_target_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in DollSvgBuilder.BASE_PIVOTS.keys():
		ids.append(id)
	for variant in body_rig.keys():
		for part in body_parts_for_variant(variant):
			var part_id = String(part.get("id", ""))
			if part_id != "" and not ids.has(part_id):
				ids.append(part_id)
	return ids


func starting_outfit_snapshot() -> Dictionary:
	return {
		"variant": starting_outfit.get("variant", "female"),
		"poseId": starting_outfit.get("poseId", "idle"),
		"skinTone": starting_outfit.get("skinTone", "#d28062"),
		"skinLine": starting_outfit.get("skinLine", "#8f4b38"),
		"hairColor": starting_outfit.get("hairColor", "#221a16"),
		"eyeColor": starting_outfit.get("eyeColor", "#222222"),
		"equippedItemIds": starting_outfit.get("equippedItemIds", []).duplicate(true),
	}


func wardrobe_available_for(equipped_item_ids: Array) -> Array:
	var equipped := {}
	for item_id in equipped_item_ids:
		equipped[String(item_id)] = true
	var available: Array = []
	for item in wardrobe:
		if not equipped.has(String(item.get("id", ""))):
			available.append(item)
	return available


func _load_json(file_name: String, fallback: Variant, expected_type: int) -> Variant:
	var path = "%s/%s" % [content_dir, file_name]
	if not FileAccess.file_exists(path):
		last_load_errors.append("Missing content file: %s" % path)
		return fallback
	var text = FileAccess.get_file_as_string(path)
	var parser := JSON.new()
	var parse_error = parser.parse(text)
	if parse_error != OK:
		last_load_errors.append("Invalid JSON content file %s: %s at line %d" % [
			path,
			parser.get_error_message(),
			parser.get_error_line(),
		])
		return fallback
	var parsed = parser.get_data()
	if typeof(parsed) != expected_type:
		last_load_errors.append("Content file %s has wrong root type. Expected %s, got %s." % [
			path,
			type_string(expected_type),
			type_string(typeof(parsed)),
		])
		return fallback
	return parsed


func _normalized_collection_value(collection_name: String, raw_value: Variant) -> Variant:
	if collection_name == "body_rig":
		return _normalize_body_rig(raw_value)
	return raw_value


func _normalize_body_rig(raw_body_rig: Variant, track_repairs := false) -> Dictionary:
	if not (raw_body_rig is Dictionary):
		return {}
	var normalized: Dictionary = raw_body_rig.duplicate(true)
	for variant in normalized.keys():
		var variant_data = normalized[variant]
		if not (variant_data is Dictionary):
			continue
		var parts_value = variant_data.get("parts", [])
		if not (parts_value is Array):
			continue
		var parts: Array = parts_value
		var ids := {}
		for part in parts:
			if not (part is Dictionary):
				continue
			var part_id = String(part.get("id", ""))
			if part_id != "":
				ids[part_id] = true
			if not part.has("variations") or not (part["variations"] is Dictionary):
				part["variations"] = {}
			if not part.has("latticeVariations") or not (part["latticeVariations"] is Dictionary):
				part["latticeVariations"] = {}
		for required_id in REQUIRED_BODY_PART_IDS:
			if not ids.has(required_id):
				parts.append(_default_body_part(required_id))
				ids[required_id] = true
				if track_repairs:
					generated_body_part_repairs.append({
						"variant": String(variant),
						"partId": required_id,
					})
	return normalized


func _default_body_part(part_id: String) -> Dictionary:
	var defaults = REQUIRED_BODY_PART_DEFAULTS.get(part_id, {"parentId": "", "layer": "body"})
	var pivot = DollSvgBuilder.BASE_PIVOTS.get(part_id, {"x": 0.0, "y": 0.0})
	return {
		"id": part_id,
		"layer": String(defaults.get("layer", "body")),
		"parentId": String(defaults.get("parentId", "")),
		"pivot": {
			"x": float(pivot.get("x", 0.0)),
			"y": float(pivot.get("y", 0.0)),
		},
		"svgMarkup": "<g/>",
		"variations": {},
		"latticeVariations": {},
	}


func _replace_file_with_temp(temp_path: String, final_path: String) -> Dictionary:
	var temp_abs = ProjectSettings.globalize_path(temp_path)
	var final_abs = ProjectSettings.globalize_path(final_path)
	var backup_abs = "%s.bak" % final_abs
	if FileAccess.file_exists(backup_abs):
		var remove_backup_error = DirAccess.remove_absolute(backup_abs)
		if remove_backup_error != OK:
			return {"ok": false, "errors": ["Could not remove old backup for %s: %s" % [final_path, remove_backup_error]]}
	if FileAccess.file_exists(final_path):
		var backup_error = DirAccess.rename_absolute(final_abs, backup_abs)
		if backup_error != OK:
			DirAccess.remove_absolute(temp_abs)
			return {"ok": false, "errors": ["Could not create backup for %s: %s" % [final_path, backup_error]]}
	var replace_error = DirAccess.rename_absolute(temp_abs, final_abs)
	if replace_error != OK:
		if FileAccess.file_exists(backup_abs):
			DirAccess.rename_absolute(backup_abs, final_abs)
		DirAccess.remove_absolute(temp_abs)
		return {"ok": false, "errors": ["Could not replace %s: %s" % [final_path, replace_error]]}
	if FileAccess.file_exists(backup_abs):
		DirAccess.remove_absolute(backup_abs)
	return {"ok": true, "errors": []}


func _rebuild_indexes() -> void:
	_asset_by_id = _index_by_id(equipment_assets)
	_visual_by_id = _index_by_id(equipment_visuals)
	_wardrobe_by_id = _index_by_id(wardrobe)
	_pose_by_id = _index_by_id(poses)
	_animation_by_id = _index_by_id(animations)
	_rig_part_by_variant = {}
	for variant in body_rig.keys():
		_rig_part_by_variant[variant] = _index_by_id(body_parts_for_variant(variant))


func _index_by_id(records: Array) -> Dictionary:
	var result := {}
	for record in records:
		if record is Dictionary:
			var id = String(record.get("id", ""))
			if id != "":
				result[id] = record
	return result


func _file_name_for_collection(collection_name: String) -> String:
	match collection_name:
		"body_rig":
			return "body_rig.json"
		"equipment_assets":
			return "equipment_assets.json"
		"equipment_visuals":
			return "equipment_visuals.json"
		"wardrobe":
			return "wardrobe.json"
		"poses":
			return "poses.json"
		"animations":
			return "animations.json"
		"starting_outfit":
			return "starting_outfit.json"
	return ""
