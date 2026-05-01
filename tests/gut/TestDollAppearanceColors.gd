extends GutTest

const OutfitStateScript := preload("res://scripts/game/OutfitState.gd")


func test_hair_and_eye_settings_recolor_imported_rig_parts() -> void:
	var repo := ContentRepository.new()
	var validation = repo.load_all()
	assert_true(validation.get("ok", false), "; ".join(validation.get("errors", [])))

	for variant in ["female", "male"]:
		var outfit = OutfitStateScript.new(repo.starting_outfit_snapshot())
		outfit.variant = variant
		outfit.hair_color = "#12aa34"
		outfit.eye_color = "#dd22aa"
		outfit.equipped_item_ids.clear()

		var svg = DollSvgBuilder.build_svg(repo, outfit)

		assert_string_contains(svg, "fill=\"#12aa34\"")
		assert_string_contains(svg, "fill=\"#dd22aa\"")
		assert_false(svg.contains("fill=\"#3a5bd7\""))
		assert_false(svg.contains("fill=\"#828180\""))
