extends GutTest

const OutfitStateScript := preload("res://scripts/game/OutfitState.gd")
const OBSOLETE_WARDROBE_KEYS := [
	"modifiers",
	"requiredSkillLevels",
	"setId",
	"styleTags",
	"styleRatings",
	"price",
	"hiddenUntilOwned",
]


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


func test_imported_wardrobe_contains_only_dressup_fields() -> void:
	var repo := ContentRepository.new()
	var result = repo.load_all()
	assert_true(result.get("ok", false), "; ".join(result.get("errors", [])))

	for item in repo.wardrobe:
		for key in OBSOLETE_WARDROBE_KEYS:
			assert_false(item.has(key), "Wardrobe item %s contains obsolete field %s" % [item.get("id", ""), key])


func test_imported_starting_outfit_can_render_svg() -> void:
	var repo := ContentRepository.new()
	var result = repo.load_all()
	assert_true(result.get("ok", false), "; ".join(result.get("errors", [])))

	var outfit = OutfitStateScript.new(repo.starting_outfit_snapshot())
	var svg = DollSvgBuilder.build_svg(repo, outfit)
	assert_true(svg.contains("paper-doll-figure"))
	assert_true(svg.contains("equipment-piece"))
