extends GutTest


func test_content_validation_accepts_minimal_valid_repository() -> void:
	var repo = _valid_repo()
	var result = ContentValidator.validate_repository(repo)
	assert_true(result.get("ok", false), "; ".join(result.get("errors", [])))


func test_content_validation_rejects_duplicate_ids_missing_assets_and_unsafe_svg() -> void:
	var repo = _valid_repo()
	repo.wardrobe.append(repo.wardrobe[0].duplicate(true))
	repo.equipment_visuals[0]["pieces"][0]["assetId"] = "missing"
	repo.equipment_assets[0]["svgMarkup"] = "<svg><script>alert(1)</script></svg>"
	repo._rebuild_indexes()

	var result = ContentValidator.validate_repository(repo)
	assert_false(result.get("ok", true))
	assert_gt(result.get("errors", []).size(), 2)


func _valid_repo() -> ContentRepository:
	var body_part = {
		"id": "body",
		"name": "Body",
		"layer": "body",
		"parentId": "",
		"pivot": {"x": 1200.0, "y": 1620.0},
		"svgMarkup": "<g><path d=\"M0 0 L10 0 L10 10 Z\" fill=\"var(--doll-skin)\"/></g>",
		"variations": {},
		"latticeVariations": {},
	}
	var repo := ContentRepository.new()
	repo.body_rig = {
		"female": {"parts": [body_part.duplicate(true)]},
		"male": {"parts": [body_part.duplicate(true)]},
	}
	repo.equipment_assets = [
		{"id": "asset", "name": "Asset", "svgMarkup": "<g><path d=\"M0 0 L4 4\"/></g>"},
	]
	repo.equipment_visuals = [
		{
			"id": "visual",
			"name": "Visual",
			"slot": "top",
			"pieces": [{"target": "body", "layer": "body", "assetId": "asset", "transform": {}}],
		},
	]
	repo.wardrobe = [
		{"id": "item", "name": "Item", "slot": "top", "visualId": "visual", "color": "#ffffff"},
	]
	repo.poses = [{"id": "idle", "name": "Idle", "parts": {"body": {"rotate": 0}}, "sprites": {}}]
	repo.sample_meta = {"variants": {"female": {"baseScale": 1.0}, "male": {"baseScale": 1.0}}}
	repo.starting_outfit = {}
	repo._rebuild_indexes()
	return repo
