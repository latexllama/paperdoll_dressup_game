class_name DevEditorDraft
extends RefCounted

const SAVE_ORDER := ["equipment_assets", "equipment_visuals", "wardrobe", "body_rig", "poses"]

var wardrobe: Array = []
var equipment_visuals: Array = []
var equipment_assets: Array = []
var body_rig: Dictionary = {}
var poses: Array = []
var sample_meta: Dictionary = {}
var starting_outfit: Dictionary = {}

var _baseline_signature := ""


func load_from_repository(repo: ContentRepository) -> void:
	wardrobe = repo.wardrobe.duplicate(true)
	equipment_visuals = repo.equipment_visuals.duplicate(true)
	equipment_assets = repo.equipment_assets.duplicate(true)
	body_rig = repo.body_rig.duplicate(true)
	poses = repo.poses.duplicate(true)
	sample_meta = repo.sample_meta.duplicate(true)
	starting_outfit = repo.starting_outfit.duplicate(true)
	_baseline_signature = signature()


func repository_clone() -> ContentRepository:
	var clone := ContentRepository.new()
	clone.wardrobe = wardrobe.duplicate(true)
	clone.equipment_visuals = equipment_visuals.duplicate(true)
	clone.equipment_assets = equipment_assets.duplicate(true)
	clone.body_rig = body_rig.duplicate(true)
	clone.poses = poses.duplicate(true)
	clone.sample_meta = sample_meta.duplicate(true)
	clone.starting_outfit = starting_outfit.duplicate(true)
	clone.set_collection("equipment_assets", clone.equipment_assets)
	return clone


func collection(collection_name: String) -> Variant:
	match collection_name:
		"wardrobe":
			return wardrobe
		"equipment_visuals":
			return equipment_visuals
		"equipment_assets":
			return equipment_assets
		"body_rig":
			return body_rig
		"poses":
			return poses
	return []


func set_collection(collection_name: String, value: Variant) -> void:
	match collection_name:
		"wardrobe":
			wardrobe = value
		"equipment_visuals":
			equipment_visuals = value
		"equipment_assets":
			equipment_assets = value
		"body_rig":
			body_rig = value
		"poses":
			poses = value


func validate() -> Dictionary:
	return ContentValidator.validate_repository(repository_clone())


func is_dirty() -> bool:
	return signature() != _baseline_signature


func mark_clean() -> void:
	_baseline_signature = signature()


func signature() -> String:
	return JSON.stringify({
		"wardrobe": wardrobe,
		"equipment_visuals": equipment_visuals,
		"equipment_assets": equipment_assets,
		"body_rig": body_rig,
		"poses": poses,
	})


func save_all(repo: ContentRepository) -> Dictionary:
	var validation = validate()
	if not validation.get("ok", false):
		return validation
	if not repo.can_write_source_content():
		return {"ok": false, "errors": ["Source content can only be saved from the Godot editor runtime."]}
	for collection_name in SAVE_ORDER:
		repo.set_collection(collection_name, collection(collection_name).duplicate(true))
	for collection_name in SAVE_ORDER:
		var result = repo.save_collection(collection_name, collection(collection_name))
		if not result.get("ok", false):
			return result
	mark_clean()
	return {"ok": true, "errors": []}
