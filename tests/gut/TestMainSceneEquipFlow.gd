extends GutTest

const MainSceneScene := preload("res://scenes/main/Main.tscn")
const OutfitStateScript := preload("res://scripts/game/OutfitState.gd")


func test_cancelled_doll_drag_restores_original_outfit() -> void:
	var main = await _ready_main_scene()
	main._outfit = OutfitStateScript.new({"equippedItemIds": ["plain-tee", "clean-sneakers"]})
	main._refresh_all()

	main._on_equipped_drag_started("plain-tee")
	assert_eq(main._outfit.equipped_item_ids, ["clean-sneakers"])

	main._on_equipped_drag_cancelled("plain-tee")
	assert_eq(main._outfit.equipped_item_ids, ["plain-tee", "clean-sneakers"])


func test_dropping_picked_item_back_on_doll_records_reorder() -> void:
	var main = await _ready_main_scene()
	main._outfit = OutfitStateScript.new({"equippedItemIds": ["plain-tee", "clean-sneakers"]})
	main._refresh_all()

	main._on_equipped_drag_started("plain-tee")
	main._on_doll_drop_requested({"kind": "equipped_item", "item_id": "plain-tee"})

	assert_eq(main._outfit.equipped_item_ids, ["clean-sneakers", "plain-tee"])
	assert_eq(main._history.undo_count(), 1)


func test_stale_equipped_drop_restores_active_doll_drag() -> void:
	var main = await _ready_main_scene()
	main._outfit = OutfitStateScript.new({"equippedItemIds": ["plain-tee", "clean-sneakers"]})
	main._refresh_all()

	main._on_equipped_drag_started("plain-tee")
	main._on_doll_drop_requested({"kind": "equipped_item", "item_id": "clean-sneakers"})

	assert_eq(main._outfit.equipped_item_ids, ["plain-tee", "clean-sneakers"])


func test_wardrobe_drop_rejects_item_that_is_already_equipped() -> void:
	var main = await _ready_main_scene()
	main._outfit = OutfitStateScript.new({"equippedItemIds": ["plain-tee"]})
	main._refresh_all()

	main._wardrobe_panel._on_tile_drag_started("plain-tee")
	main._on_doll_drop_requested({"kind": "wardrobe_item", "item_id": "plain-tee"})

	assert_eq(main._outfit.equipped_item_ids, ["plain-tee"])


func _ready_main_scene() -> MainScene:
	var main: MainScene = MainSceneScene.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	return main
