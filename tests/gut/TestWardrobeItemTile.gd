extends GutTest

const WardrobeItemTileScene := preload("res://scenes/ui/WardrobeItemTile.tscn")
const ItemDragPreviewScript := preload("res://scripts/ui/ItemDragPreview.gd")
const SvgTextureCacheScript := preload("res://scripts/doll/SvgTextureCache.gd")


func test_wardrobe_item_drag_preview_matches_shared_tile_size() -> void:
	var tile: WardrobeItemTile = WardrobeItemTileScene.instantiate()
	add_child_autofree(tile)
	await get_tree().process_frame
	var repo := ContentRepository.new()
	var validation = repo.load_all()
	assert_true(validation.get("ok", false), "; ".join(validation.get("errors", [])))
	tile.configure(repo, SvgTextureCacheScript.new(), repo.wardrobe_item("plain-tee"))

	var preview = tile._make_drag_preview()

	assert_eq(preview.custom_minimum_size, ItemDragPreviewScript.PREVIEW_SIZE)
	assert_eq(preview.size, ItemDragPreviewScript.PREVIEW_SIZE)
	assert_true(preview.clip_contents)
	assert_eq(preview.get_child_count(), 3)
	preview.free()
