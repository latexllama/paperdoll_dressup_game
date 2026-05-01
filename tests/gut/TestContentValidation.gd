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


func test_content_validation_rejects_obsolete_wardrobe_fields() -> void:
	var obsolete_keys := [
		"modifiers",
		"requiredSkillLevels",
		"setId",
		"styleTags",
		"styleRatings",
		"price",
		"hiddenUntilOwned",
	]
	for key in obsolete_keys:
		var repo = _valid_repo()
		repo.wardrobe[0][key] = [] if key == "modifiers" or key == "styleTags" else "obsolete"
		var result = ContentValidator.validate_repository(repo)
		assert_false(result.get("ok", true), "Expected obsolete field to fail validation: %s" % key)


func test_content_validation_rejects_unknown_fields_and_bad_starting_outfit_refs() -> void:
	var repo = _valid_repo()
	repo.wardrobe[0]["unexpected"] = true
	repo.starting_outfit = {
		"variant": "missing",
		"poseId": "missing",
		"skinTone": "not-a-color",
		"equippedItemIds": ["missing-item"],
	}

	var result = ContentValidator.validate_repository(repo)

	assert_false(result.get("ok", true))
	assert_string_contains("; ".join(result.get("errors", [])), "unknown field")
	assert_string_contains("; ".join(result.get("errors", [])), "missing variant")
	assert_string_contains("; ".join(result.get("errors", [])), "missing pose")
	assert_string_contains("; ".join(result.get("errors", [])), "missing wardrobe item")


func test_content_validation_rejects_invalid_body_variation_references() -> void:
	var repo = _valid_repo()
	var part: Dictionary = repo.body_rig["female"]["parts"][0]
	part["variations"]["shape"] = "<g/>"
	part["latticeVariations"]["shape"] = _valid_lattice("missing-source")
	var result = ContentValidator.validate_repository(repo)

	assert_false(result.get("ok", true))
	assert_string_contains("; ".join(result.get("errors", [])), "both SVG and lattice")
	assert_string_contains("; ".join(result.get("errors", [])), "missing source variation")


func test_content_validation_rejects_invalid_pose_sprite_overrides() -> void:
	var repo = _valid_repo()
	repo.poses[0]["sprites"] = {
		"leftHand": "not-a-hand-sprite",
		"body": "missing-variation",
	}

	var result = ContentValidator.validate_repository(repo)

	assert_false(result.get("ok", true))
	assert_string_contains("; ".join(result.get("errors", [])), "invalid hand sprite")
	assert_string_contains("; ".join(result.get("errors", [])), "missing variation")


func _valid_repo() -> ContentRepository:
	var body_part = {
		"id": "body",
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
		{"id": "asset", "name": "Asset", "source": "custom", "actorSpace": false, "svgMarkup": "<g><path d=\"M0 0 L4 4\"/></g>"},
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


func _valid_lattice(source_variation_id: String) -> Dictionary:
	var bounds := {"x": 0.0, "y": 0.0, "width": 10.0, "height": 10.0}
	return {
		"sourceVariationId": source_variation_id,
		"rows": 3,
		"columns": 3,
		"bounds": bounds,
		"points": Lattice.create_identity_points(bounds, 3, 3),
	}
