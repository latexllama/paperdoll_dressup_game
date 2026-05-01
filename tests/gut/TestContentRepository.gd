extends GutTest

const TEST_DIR := "user://content_repository_test"


class WritableRepository:
	extends ContentRepository

	func can_write_source_content() -> bool:
		return true


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	_write_valid_content(TEST_DIR)


func after_each() -> void:
	for file_name in ["body_rig.json", "equipment_assets.json", "equipment_visuals.json", "wardrobe.json", "poses.json", "sample_meta.json", "starting_outfit.json", "wardrobe.json.tmp", "wardrobe.json.bak"]:
		var path = "%s/%s" % [TEST_DIR, file_name]
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_load_all_reports_wrong_root_type() -> void:
	_write_json("%s/wardrobe.json" % TEST_DIR, {})
	var repo := ContentRepository.new()
	repo.content_dir = TEST_DIR

	var result = repo.load_all()

	assert_false(result.get("ok", true))
	assert_string_contains("; ".join(result.get("load_errors", [])), "wrong root type")


func test_load_all_normalizes_required_body_rig_nodes() -> void:
	var repo := ContentRepository.new()
	repo.content_dir = TEST_DIR

	var result = repo.load_all()

	assert_true(result.get("ok", false), "; ".join(result.get("errors", [])))
	for variant in ["female", "male"]:
		for part_id in ["tail", "horns", "leftToe", "rightToe", "neck", "head", "headNub"]:
			var part = repo.body_part(variant, part_id)
			assert_false(part.is_empty(), "%s missing normalized body rig part %s" % [variant, part_id])
			assert_true(part.get("variations", null) is Dictionary)
			assert_true(part.get("latticeVariations", null) is Dictionary)
	assert_eq(repo.body_part("female", "tail").get("parentId"), "hip")
	assert_eq(repo.body_part("female", "tail").get("layer"), "back")
	assert_eq(repo.body_part("female", "tail").get("svgMarkup"), "<g/>")


func test_invalid_save_does_not_replace_existing_collection_file() -> void:
	var repo := WritableRepository.new()
	repo.content_dir = TEST_DIR
	var load_result = repo.load_all()
	assert_true(load_result.get("ok", false), "; ".join(load_result.get("errors", [])))
	var before = FileAccess.get_file_as_string("%s/wardrobe.json" % TEST_DIR)
	var invalid_wardrobe = repo.wardrobe.duplicate(true)
	invalid_wardrobe[0]["visualId"] = "missing"

	var save_result = repo.save_collection("wardrobe", invalid_wardrobe)

	assert_false(save_result.get("ok", true))
	assert_eq(FileAccess.get_file_as_string("%s/wardrobe.json" % TEST_DIR), before)


func _write_valid_content(base_dir: String) -> void:
	var body_part = {
		"id": "body",
		"layer": "body",
		"parentId": "",
		"pivot": {"x": 1200.0, "y": 1620.0},
		"svgMarkup": "<g><path d=\"M0 0 L10 0 L10 10 Z\" fill=\"var(--doll-skin)\"/></g>",
		"variations": {},
		"latticeVariations": {},
	}
	_write_json("%s/body_rig.json" % base_dir, {
		"female": {"parts": [body_part]},
		"male": {"parts": [body_part.duplicate(true)]},
	})
	_write_json("%s/equipment_assets.json" % base_dir, [
		{"id": "asset", "name": "Asset", "source": "custom", "actorSpace": false, "svgMarkup": "<g><path d=\"M0 0 L4 4\"/></g>"},
	])
	_write_json("%s/equipment_visuals.json" % base_dir, [
		{"id": "visual", "name": "Visual", "slot": "top", "pieces": [{"target": "body", "layer": "body", "assetId": "asset", "transform": {}}]},
	])
	_write_json("%s/wardrobe.json" % base_dir, [
		{"id": "item", "name": "Item", "slot": "top", "visualId": "visual", "color": "#ffffff"},
	])
	_write_json("%s/poses.json" % base_dir, [
		{"id": "idle", "name": "Idle", "parts": {"body": {"rotate": 0.0}}, "sprites": {}},
	])
	_write_json("%s/sample_meta.json" % base_dir, {"variants": {"female": {"baseScale": 1.0}, "male": {"baseScale": 1.0}}})
	_write_json("%s/starting_outfit.json" % base_dir, {
		"variant": "female",
		"poseId": "idle",
		"skinTone": "#d28062",
		"skinLine": "#8f4b38",
		"hairColor": "#221a16",
		"eyeColor": "#222222",
		"equippedItemIds": ["item"],
	})


func _write_json(path: String, value: Variant) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "  ") + "\n")
	file.close()
