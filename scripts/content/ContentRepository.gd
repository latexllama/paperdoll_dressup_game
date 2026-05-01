class_name ContentRepository
extends RefCounted

const CONTENT_DIR := "res://content"

var body_rig: Dictionary = {}
var equipment_assets: Array = []
var equipment_visuals: Array = []
var wardrobe: Array = []
var poses: Array = []
var sample_meta: Dictionary = {}
var starting_outfit: Dictionary = {}

var _asset_by_id: Dictionary = {}
var _visual_by_id: Dictionary = {}
var _wardrobe_by_id: Dictionary = {}
var _pose_by_id: Dictionary = {}
var _rig_part_by_variant: Dictionary = {}


func load_all() -> Dictionary:
	body_rig = _load_json("body_rig.json", {})
	equipment_assets = _load_json("equipment_assets.json", [])
	equipment_visuals = _load_json("equipment_visuals.json", [])
	wardrobe = _load_json("wardrobe.json", [])
	poses = _load_json("poses.json", [])
	sample_meta = _load_json("sample_meta.json", {})
	starting_outfit = _load_json("starting_outfit.json", {})
	_rebuild_indexes()
	var validation = ContentValidator.validate_repository(self)
	return validation


func reload_after_external_save() -> Dictionary:
	return load_all()


func save_collection(collection_name: String, value: Variant) -> Dictionary:
	if not can_write_source_content():
		return {"ok": false, "errors": ["Source content can only be saved from the Godot editor runtime."]}
	var file_name = _file_name_for_collection(collection_name)
	if file_name == "":
		return {"ok": false, "errors": ["Unknown content collection: %s" % collection_name]}
	var validation = ContentValidator.validate_collection(self, collection_name, value)
	if not validation.get("ok", false):
		return validation
	var file = FileAccess.open("%s/%s" % [CONTENT_DIR, file_name], FileAccess.WRITE)
	if file == null:
		return {"ok": false, "errors": ["Could not open %s for writing." % file_name]}
	file.store_string(JSON.stringify(value, "  ") + "\n")
	file.close()
	set_collection(collection_name, value)
	_rebuild_indexes()
	return {"ok": true, "errors": []}


func can_write_source_content() -> bool:
	return OS.has_feature("editor")


func set_collection(collection_name: String, value: Variant) -> void:
	match collection_name:
		"body_rig":
			body_rig = value
		"equipment_assets":
			equipment_assets = value
		"equipment_visuals":
			equipment_visuals = value
		"wardrobe":
			wardrobe = value
		"poses":
			poses = value
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


func _load_json(file_name: String, fallback: Variant) -> Variant:
	var path = "%s/%s" % [CONTENT_DIR, file_name]
	if not FileAccess.file_exists(path):
		push_warning("Missing content file: %s" % path)
		return fallback
	var text = FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed == null:
		push_warning("Invalid JSON content file: %s" % path)
		return fallback
	return parsed


func _rebuild_indexes() -> void:
	_asset_by_id = _index_by_id(equipment_assets)
	_visual_by_id = _index_by_id(equipment_visuals)
	_wardrobe_by_id = _index_by_id(wardrobe)
	_pose_by_id = _index_by_id(poses)
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
		"starting_outfit":
			return "starting_outfit.json"
	return ""
