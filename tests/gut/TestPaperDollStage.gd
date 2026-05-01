extends GutTest

const PaperDollStageScene := preload("res://scenes/ui/PaperDollStage.tscn")
const SvgTextureCacheScript := preload("res://scripts/doll/SvgTextureCache.gd")


func test_equipped_item_drag_preview_keeps_fixed_tile_size() -> void:
	var stage: PaperDollStage = PaperDollStageScene.instantiate()
	add_child_autofree(stage)
	var repo := ContentRepository.new()
	var validation = repo.load_all()
	assert_true(validation.get("ok", false), "; ".join(validation.get("errors", [])))
	stage.repo = repo
	stage.texture_cache = SvgTextureCacheScript.new()

	var preview = stage._make_drag_preview("plain-tee")

	assert_eq(preview.custom_minimum_size, Vector2(132.0, 132.0))
	assert_eq(preview.size, Vector2(132.0, 132.0))
	assert_true(preview.clip_contents)
	preview.free()
