extends GutTest

const OutfitStateScript := preload("res://scripts/game/OutfitState.gd")
const OutfitHistoryScript := preload("res://scripts/game/OutfitHistory.gd")


func test_equipping_keeps_stack_order_and_allows_same_slot_items() -> void:
	var outfit = OutfitStateScript.new()
	outfit.equip_item("plain-tee")
	outfit.equip_item("gym-hoodie")
	outfit.equip_item("office-blazer")

	assert_eq(outfit.equipped_item_ids, ["plain-tee", "gym-hoodie", "office-blazer"])
	assert_eq(outfit.top_visible_item_id(), "office-blazer")


func test_remove_top_visible_item_returns_last_equipped_item() -> void:
	var outfit = OutfitStateScript.new()
	outfit.equip_item("plain-tee")
	outfit.equip_item("gym-hoodie")

	assert_eq(outfit.remove_top_visible_item(), "gym-hoodie")
	assert_eq(outfit.equipped_item_ids, ["plain-tee"])


func test_top_visible_item_uses_render_layer_order_before_stack_order() -> void:
	var repo := ContentRepository.new()
	repo.equipment_assets = [
		{"id": "asset", "name": "Asset", "source": "custom", "actorSpace": false, "svgMarkup": "<g><path d=\"M0 0 L4 4\"/></g>"},
	]
	repo.equipment_visuals = [
		{"id": "frontVisual", "name": "Front", "slot": "top", "pieces": [{"target": "body", "layer": "front", "assetId": "asset"}]},
		{"id": "backVisual", "name": "Back", "slot": "top", "pieces": [{"target": "body", "layer": "back", "assetId": "asset"}]},
	]
	repo.wardrobe = [
		{"id": "front-item", "name": "Front Item", "slot": "top", "visualId": "frontVisual", "color": "#ffffff"},
		{"id": "back-item", "name": "Back Item", "slot": "top", "visualId": "backVisual", "color": "#ffffff"},
	]
	repo.set_collection("equipment_assets", repo.equipment_assets)
	var outfit = OutfitStateScript.new({"equippedItemIds": ["front-item", "back-item"]})

	assert_eq(DollSvgBuilder.top_visible_equipped_item_id(repo, outfit), "front-item")


func test_position_hit_selects_top_visible_item_under_cursor() -> void:
	var repo = _hit_test_repo()
	var outfit = OutfitStateScript.new({"equippedItemIds": ["front-item", "back-item"]})

	assert_eq(DollSvgBuilder.top_visible_equipped_item_id_at(repo, outfit, Vector2(150.0, 150.0)), "front-item")


func test_position_hit_ignores_items_outside_cursor_bounds() -> void:
	var repo = _hit_test_repo()
	var outfit = OutfitStateScript.new({"equippedItemIds": ["front-item", "back-item"]})

	assert_eq(DollSvgBuilder.top_visible_equipped_item_id_at(repo, outfit, Vector2(900.0, 900.0)), "")


func test_position_hit_uses_equip_order_within_same_layer() -> void:
	var repo = _hit_test_repo()
	var outfit = OutfitStateScript.new({"equippedItemIds": ["same-layer-a", "same-layer-b"]})

	assert_eq(DollSvgBuilder.top_visible_equipped_item_id_at(repo, outfit, Vector2(520.0, 520.0)), "same-layer-b")


func test_position_hit_uses_render_layer_before_equip_order() -> void:
	var repo = _hit_test_repo()
	var outfit = OutfitStateScript.new({"equippedItemIds": ["front-item", "back-item"]})

	assert_eq(DollSvgBuilder.top_visible_equipped_item_id_at(repo, outfit, Vector2(150.0, 150.0)), "front-item")


func test_outfit_history_undo_redo_restores_snapshots() -> void:
	var history = OutfitHistoryScript.new()
	var outfit = OutfitStateScript.new()
	outfit.equip_item("plain-tee")
	history.remember(outfit.to_dictionary())

	outfit.equip_item("gym-hoodie")
	var undo_snapshot = history.undo(outfit.to_dictionary())
	var undo_outfit = OutfitStateScript.new(undo_snapshot)
	assert_eq(undo_outfit.equipped_item_ids, ["plain-tee"])

	var redo_snapshot = history.redo(undo_outfit.to_dictionary())
	var redo_outfit = OutfitStateScript.new(redo_snapshot)
	assert_eq(redo_outfit.equipped_item_ids, ["plain-tee", "gym-hoodie"])


func _hit_test_repo() -> ContentRepository:
	var repo := ContentRepository.new()
	repo.equipment_assets = [
		{"id": "front-asset", "name": "Front", "source": "custom", "actorSpace": true, "svgMarkup": "<path d=\"M100 100 L200 100 L200 200 L100 200 Z\"/>"},
		{"id": "back-asset", "name": "Back", "source": "custom", "actorSpace": true, "svgMarkup": "<path d=\"M100 100 L200 100 L200 200 L100 200 Z\"/>"},
		{"id": "same-layer-a-asset", "name": "Same A", "source": "custom", "actorSpace": true, "svgMarkup": "<path d=\"M500 500 L600 500 L600 600 L500 600 Z\"/>"},
		{"id": "same-layer-b-asset", "name": "Same B", "source": "custom", "actorSpace": true, "svgMarkup": "<path d=\"M500 500 L600 500 L600 600 L500 600 Z\"/>"},
	]
	repo.equipment_visuals = [
		{"id": "front-visual", "name": "Front", "slot": "top", "pieces": [{"target": "body", "layer": "front", "assetId": "front-asset"}]},
		{"id": "back-visual", "name": "Back", "slot": "top", "pieces": [{"target": "body", "layer": "back", "assetId": "back-asset"}]},
		{"id": "same-layer-a-visual", "name": "Same A", "slot": "top", "pieces": [{"target": "body", "layer": "body", "assetId": "same-layer-a-asset"}]},
		{"id": "same-layer-b-visual", "name": "Same B", "slot": "top", "pieces": [{"target": "body", "layer": "body", "assetId": "same-layer-b-asset"}]},
	]
	repo.wardrobe = [
		{"id": "front-item", "name": "Front Item", "slot": "top", "visualId": "front-visual", "color": "#ffffff"},
		{"id": "back-item", "name": "Back Item", "slot": "top", "visualId": "back-visual", "color": "#ffffff"},
		{"id": "same-layer-a", "name": "Same A", "slot": "top", "visualId": "same-layer-a-visual", "color": "#ffffff"},
		{"id": "same-layer-b", "name": "Same B", "slot": "top", "visualId": "same-layer-b-visual", "color": "#ffffff"},
	]
	repo.set_collection("equipment_assets", repo.equipment_assets)
	repo.set_collection("equipment_visuals", repo.equipment_visuals)
	repo.set_collection("wardrobe", repo.wardrobe)
	return repo
