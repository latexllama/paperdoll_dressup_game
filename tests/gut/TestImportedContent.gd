extends GutTest

const OutfitStateScript := preload("res://scripts/game/OutfitState.gd")


func test_imported_content_loads_and_resolves_references() -> void:
	var repo := ContentRepository.new()
	var result = repo.load_all()

	assert_true(result.get("ok", false), "; ".join(result.get("errors", [])))
	assert_eq(repo.body_parts_for_variant("female").size(), 25)
	assert_eq(repo.body_parts_for_variant("male").size(), 25)
	assert_eq(repo.wardrobe.size(), 10)
	assert_eq(repo.equipment_visuals.size(), 10)
	assert_eq(repo.equipment_assets.size(), 23)
	assert_eq(repo.poses.size(), 4)


func test_imported_starting_outfit_can_render_svg() -> void:
	var repo := ContentRepository.new()
	var result = repo.load_all()
	assert_true(result.get("ok", false), "; ".join(result.get("errors", [])))

	var outfit = OutfitStateScript.new(repo.starting_outfit_snapshot())
	var svg = DollSvgBuilder.build_svg(repo, outfit)
	assert_true(svg.contains("paper-doll-figure"))
	assert_true(svg.contains("equipment-piece"))
