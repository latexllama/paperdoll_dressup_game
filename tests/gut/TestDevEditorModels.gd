extends GutTest

const Models := preload("res://scripts/ui/DevEditorModels.gd")
const DevEditorDraftScript := preload("res://scripts/ui/DevEditorDraft.gd")
const OBSOLETE_WARDROBE_KEYS := [
	"modifiers",
	"requiredSkillLevels",
	"setId",
	"styleTags",
	"styleRatings",
	"price",
	"hiddenUntilOwned",
]


func test_unique_id_and_duplicate_record_keep_ids_distinct() -> void:
	var records = [{"id": "plain-tee", "name": "Plain Tee"}, {"id": "plain-tee-copy", "name": "Plain Tee Copy"}]

	var clone = Models.duplicate_record(records[0], records)

	assert_eq(clone["id"], "plain-tee-copy-2")
	assert_eq(clone["name"], "Plain Tee Copy")


func test_wardrobe_visual_piece_sync_and_asset_rename_updates_references() -> void:
	var item = Models.create_wardrobe_item([])
	var visual = {
		"id": "visual",
		"pieces": [
			{"target": "torso", "assetId": "oldAsset", "colorGroup": "Clothing.Top.Base"},
			{"target": "head", "assetId": "oldAsset"},
		],
	}
	var visuals = [visual]

	Models.sync_wardrobe_pieces_from_visual(item, visual)
	Models.rename_asset_references(visuals, "oldAsset", "newAsset")

	assert_eq(item["pieces"], [{"target": "torso", "colorGroup": "Clothing.Top.Base"}])
	assert_eq(visual["pieces"][0]["assetId"], "newAsset")
	assert_eq(visual["pieces"][1]["assetId"], "newAsset")


func test_new_wardrobe_item_omits_obsolete_rpg_fields() -> void:
	var item = Models.create_wardrobe_item([])

	for key in OBSOLETE_WARDROBE_KEYS:
		assert_false(item.has(key), "New wardrobe item contains obsolete field %s" % key)


func test_visual_rename_updates_wardrobe_references() -> void:
	var wardrobe = [{"id": "item", "visualId": "oldVisual"}]

	Models.rename_visual_references(wardrobe, "oldVisual", "newVisual")

	assert_eq(wardrobe[0]["visualId"], "newVisual")


func test_body_part_rename_updates_visuals_and_poses() -> void:
	var draft = DevEditorDraftScript.new()
	draft.body_rig = {"female": {"parts": [{"id": "oldPart", "parentId": ""}, {"id": "child", "parentId": "oldPart"}]}}
	draft.equipment_visuals = [{"id": "visual", "pieces": [{"target": "oldPart"}]}]
	draft.poses = [{"id": "pose", "parts": {"oldPart": {"rotate": 7.0}}, "sprites": {"oldPart": "custom"}}]

	Models.rename_body_part_references(draft, "oldPart", "newPart")

	assert_eq(draft.body_rig["female"]["parts"][1]["parentId"], "newPart")
	assert_eq(draft.equipment_visuals[0]["pieces"][0]["target"], "newPart")
	assert_true(draft.poses[0]["parts"].has("newPart"))
	assert_true(draft.poses[0]["sprites"].has("newPart"))


func test_svg_asset_safety_blocks_preview_eligibility() -> void:
	assert_true(SvgSafety.is_safe_markup("<g><path d=\"M0 0 L10 10\"/></g>"))
	assert_false(SvgSafety.is_safe_markup("<svg><image href=\"http://example.com/a.png\"/></svg>"))


func test_lattice_model_create_resize_drag_reset_delete_and_deform() -> void:
	var part = {"svgMarkup": "<g><path d=\"M0 0 L10 10\"/></g>", "variations": {}, "latticeVariations": {}}
	var variation = Models.create_lattice_variation(part, "wide")
	variation.erase("id")
	part["latticeVariations"]["wide"] = variation

	part["latticeVariations"]["wide"] = Models.resize_lattice_variation(variation, 4, 4)
	var resized: Dictionary = part["latticeVariations"]["wide"]
	assert_eq(resized["points"].size(), 16)

	resized["points"][5] = {"x": 4.0, "y": 8.0}
	assert_eq(resized["points"][5], {"x": 4.0, "y": 8.0})

	Models.reset_lattice_points(resized)
	assert_ne(resized["points"][5], {"x": 4.0, "y": 8.0})

	var deformed = Lattice.apply_lattice_to_svg_markup("<g><path d=\"M0 0 L10 10\"/></g>", resized)
	assert_string_contains(deformed, "<path")

	part["latticeVariations"].erase("wide")
	assert_false(part["latticeVariations"].has("wide"))


func test_lattice_bounds_focus_svg_geometry_not_wrapper_or_style_numbers() -> void:
	var markup = "<svg viewBox=\"0 0 2400 3100\"><g data-source-id=\"female-mouth-Normal-10000\"><path d=\"M655.96,405.35 C641.67,406.63 623.35,410.68 613.48,404.71 L612,430 L700,430 Z\" fill=\"#f37070\"/></g></svg>"

	var bounds = Models.bounds_for_markup(markup)

	assert_gt(float(bounds["x"]), 600.0)
	assert_lt(float(bounds["width"]), 100.0)
	assert_lt(float(bounds["height"]), 40.0)


func test_pose_edit_validation_accepts_valid_part_and_rejects_invalid_part() -> void:
	var repo := ContentRepository.new()
	var body_part = {
		"id": "body",
		"layer": "body",
		"parentId": "",
		"pivot": {"x": 1200.0, "y": 1620.0},
		"svgMarkup": "<g><path d=\"M0 0 L10 0 L10 10 Z\"/></g>",
		"variations": {},
		"latticeVariations": {},
	}
	repo.body_rig = {"female": {"parts": [body_part]}, "male": {"parts": [body_part.duplicate(true)]}}
	repo.equipment_assets = [{"id": "asset", "name": "Asset", "source": "custom", "actorSpace": false, "svgMarkup": "<g><path d=\"M0 0 L4 4\"/></g>"}]
	repo.equipment_visuals = [{"id": "visual", "name": "Visual", "slot": "top", "pieces": [{"target": "body", "layer": "body", "assetId": "asset"}]}]
	repo.wardrobe = [{"id": "item", "name": "Item", "slot": "top", "visualId": "visual", "color": "#ffffff"}]
	repo.poses = [{"id": "idle", "name": "Idle", "parts": {"body": {"rotate": 8.0, "x": 2.0}}, "sprites": {}}]
	repo.set_collection("equipment_assets", repo.equipment_assets)

	var valid = ContentValidator.validate_repository(repo)
	assert_true(valid.get("ok", false), "; ".join(valid.get("errors", [])))

	repo.poses[0]["parts"]["missingPart"] = {"rotate": 1.0}
	var invalid = ContentValidator.validate_repository(repo)
	assert_false(invalid.get("ok", true))
