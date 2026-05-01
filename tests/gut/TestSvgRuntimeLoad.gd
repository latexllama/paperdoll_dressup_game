extends GutTest


var repo: ContentRepository


func before_each() -> void:
	repo = ContentRepository.new()
	var result = repo.load_all()
	assert_true(result.get("ok", false), "; ".join(result.get("errors", [])))


func test_authored_pose_svgs_load_in_godot_svg_runtime() -> void:
	for pose in repo.poses:
		var outfit = OutfitState.new(repo.starting_outfit_snapshot())
		outfit.pose_id = String(pose.get("id", ""))
		var error = _load_svg(DollSvgBuilder.build_svg(repo, outfit), 0.18)
		assert_eq(error, OK, "Pose SVG should load: %s" % outfit.pose_id)


func test_wardrobe_icon_svgs_load_in_godot_svg_runtime() -> void:
	for item in repo.wardrobe:
		var item_id = String(item.get("id", ""))
		var error = _load_svg(DollSvgBuilder.build_item_icon_svg(repo, item), 1.0)
		assert_eq(error, OK, "Wardrobe icon SVG should load: %s" % item_id)


func test_body_part_sprite_variation_svgs_load_in_godot_svg_runtime() -> void:
	for variant in repo.body_rig.keys():
		for part in repo.body_parts_for_variant(String(variant)):
			var part_id = String(part.get("id", ""))
			var variation_ids: Array[String] = []
			for variation_id in part.get("variations", {}).keys():
				variation_ids.append(String(variation_id))
			for variation_id in part.get("latticeVariations", {}).keys():
				variation_ids.append(String(variation_id))
			for variation_id in variation_ids:
				var pose = {"id": "variation-load-test", "name": "Variation Load Test", "parts": {}, "sprites": {part_id: variation_id}}
				repo.set_collection("poses", [pose])
				var outfit = OutfitState.new(repo.starting_outfit_snapshot())
				outfit.variant = String(variant)
				outfit.pose_id = "variation-load-test"
				var error = _load_svg(DollSvgBuilder.build_svg(repo, outfit), 0.18)
				assert_eq(error, OK, "Body sprite SVG should load: %s/%s/%s" % [variant, part_id, variation_id])


func test_texture_cache_records_invalid_svg_without_debugger_warning() -> void:
	var cache := SvgTextureCache.new()
	var texture = cache.texture_from_svg("not an svg document", 1.0)

	assert_null(texture)
	assert_ne(cache.last_error, OK)
	assert_false(cache.last_error_message.is_empty())


func test_texture_cache_rejects_malformed_svg_before_runtime_loader() -> void:
	var cache := SvgTextureCache.new()
	var texture = cache.texture_from_svg("<svg><g></svg>", 1.0)

	assert_null(texture)
	assert_ne(cache.last_error, OK)
	assert_false(cache.last_error_message.is_empty())


func _load_svg(svg_markup: String, scale: float) -> int:
	var image := Image.new()
	return image.load_svg_from_string(svg_markup, scale)
