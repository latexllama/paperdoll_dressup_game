extends GutTest

const DevEditorDraftScript := preload("res://scripts/ui/DevEditorDraft.gd")


class FakeRepository:
	extends ContentRepository

	var saved_order: Array[String] = []

	func can_write_source_content() -> bool:
		return true

	func save_collection(collection_name: String, value: Variant, validation_repo: ContentRepository = null) -> Dictionary:
		var validation_source = validation_repo if validation_repo != null else self
		var validation = ContentValidator.validate_collection(validation_source, collection_name, value)
		if not validation.get("ok", false):
			return validation
		saved_order.append(collection_name)
		set_collection(collection_name, value)
		return {"ok": true, "errors": []}


func test_draft_tracks_dirty_and_revert_from_repository() -> void:
	var repo = _valid_repo()
	var draft = DevEditorDraftScript.new()
	draft.load_from_repository(repo)

	assert_false(draft.is_dirty())
	draft.wardrobe[0]["name"] = "Changed"
	assert_true(draft.is_dirty())

	draft.load_from_repository(repo)
	assert_false(draft.is_dirty())
	assert_eq(draft.wardrobe[0]["name"], "Item")


func test_save_all_uses_dependency_order() -> void:
	var repo = _valid_repo()
	var draft = DevEditorDraftScript.new()
	draft.load_from_repository(repo)
	draft.wardrobe[0]["name"] = "Changed"

	var result = draft.save_all(repo)

	assert_true(result.get("ok", false), "; ".join(result.get("errors", [])))
	assert_eq(repo.saved_order, ["equipment_assets", "equipment_visuals", "body_rig", "poses", "animations", "wardrobe"])
	assert_false(draft.is_dirty())


func test_save_all_blocks_unsafe_svg_before_writing() -> void:
	var repo = _valid_repo()
	var draft = DevEditorDraftScript.new()
	draft.load_from_repository(repo)
	draft.equipment_assets[0]["svgMarkup"] = "<svg><script>alert(1)</script></svg>"

	var result = draft.save_all(repo)

	assert_false(result.get("ok", true))
	assert_eq(repo.saved_order, [])


func test_save_all_validates_each_write_against_full_draft_state() -> void:
	var repo = _valid_repo()
	var draft = DevEditorDraftScript.new()
	draft.load_from_repository(repo)
	draft.body_rig["female"]["parts"].append({
		"id": "newSleeveAnchor",
		"layer": "body",
		"parentId": "body",
		"pivot": {"x": 1000.0, "y": 1000.0},
		"svgMarkup": "<g><path d=\"M0 0 L8 0 L8 8 Z\"/></g>",
		"variations": {},
		"latticeVariations": {},
	})
	draft.equipment_visuals[0]["pieces"][0]["target"] = "newSleeveAnchor"

	var result = draft.save_all(repo)

	assert_true(result.get("ok", false), "; ".join(result.get("errors", [])))
	assert_eq(repo.equipment_visuals[0]["pieces"][0]["target"], "newSleeveAnchor")


func _valid_repo() -> FakeRepository:
	var body_part = {
		"id": "body",
		"layer": "body",
		"parentId": "",
		"pivot": {"x": 1200.0, "y": 1620.0},
		"svgMarkup": "<g><path d=\"M0 0 L10 0 L10 10 Z\" fill=\"var(--doll-skin)\"/></g>",
		"variations": {},
		"latticeVariations": {},
	}
	var repo := FakeRepository.new()
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
	repo.poses = [{"id": "idle", "name": "Idle", "parts": {"body": {"rotate": 0.0}}, "sprites": {}}]
	repo.animations = [{"id": "idle", "name": "Idle", "frameCount": 48, "fps": 24.0, "loop": true, "visibleInPlayer": true, "keyframes": [{"frame": 0, "poseId": "idle"}]}]
	repo.sample_meta = {"variants": {"female": {"baseScale": 1.0}, "male": {"baseScale": 1.0}}}
	repo.starting_outfit = {}
	repo.set_collection("equipment_assets", repo.equipment_assets)
	return repo
