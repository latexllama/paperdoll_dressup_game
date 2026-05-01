extends GutTest

const WardrobePanelScene := preload("res://scenes/ui/WardrobePanel.tscn")


func test_active_wardrobe_drag_survives_available_item_refresh() -> void:
	var panel = _panel_with_items()

	panel._on_tile_drag_started("plain-tee")
	panel.set_available_items(panel.repo.wardrobe)

	assert_true(panel.is_active_wardrobe_drag("plain-tee"))


func test_active_wardrobe_drag_clears_when_item_is_no_longer_available() -> void:
	var panel = _panel_with_items()

	panel._on_tile_drag_started("plain-tee")
	panel.set_available_items([panel.repo.wardrobe_item("clean-sneakers")])

	assert_false(panel.is_active_wardrobe_drag("plain-tee"))


func test_cancel_active_wardrobe_drag_restores_hidden_tile() -> void:
	var panel = _panel_with_items()

	panel._on_tile_drag_started("plain-tee")
	panel.cancel_active_wardrobe_drag("plain-tee")

	assert_false(panel.is_active_wardrobe_drag("plain-tee"))
	assert_eq(panel._grid.get_child_count(), 2)


func _panel_with_items() -> WardrobePanel:
	var panel: WardrobePanel = WardrobePanelScene.instantiate()
	add_child_autofree(panel)
	var repo := ContentRepository.new()
	repo.wardrobe = [
		{"id": "plain-tee", "name": "Plain Tee", "slot": "top", "visualId": "plain-tee-visual", "color": "#ffffff"},
		{"id": "clean-sneakers", "name": "Clean Sneakers", "slot": "shoes", "visualId": "clean-sneakers-visual", "color": "#ffffff"},
	]
	repo.set_collection("wardrobe", repo.wardrobe)
	panel.configure(repo, null)
	panel.set_available_items(repo.wardrobe)
	return panel
