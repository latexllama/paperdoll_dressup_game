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
