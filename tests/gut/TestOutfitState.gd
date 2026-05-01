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
