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


func test_imported_body_feet_markup_matches_left_right_actor_side() -> void:
	var repo := ContentRepository.new()
	var result = repo.load_all()
	assert_true(result.get("ok", false), "; ".join(result.get("errors", [])))

	for variant in ["female", "male"]:
		var left_center = _markup_center_x(String(repo.body_part(variant, "leftFoot").get("svgMarkup", "")))
		var right_center = _markup_center_x(String(repo.body_part(variant, "rightFoot").get("svgMarkup", "")))
		assert_lt(left_center, right_center, "%s leftFoot SVG should be left of rightFoot SVG" % variant)


func _markup_center_x(markup: String) -> float:
	var regex := RegEx.new()
	regex.compile("\\bcx\\s*=\\s*['\\\"]\\s*([-+]?(?:(?:\\d*\\.\\d+)|(?:\\d+\\.?))(?:[eE][-+]?\\d+)?)")
	var cx_values: Array[float] = []
	for match in regex.search_all(markup):
		cx_values.append(float(match.get_string(1)))
	if not cx_values.is_empty():
		var total := 0.0
		for cx in cx_values:
			total += cx
		return total / cx_values.size()
	regex.compile("[-+]?(?:(?:\\d*\\.\\d+)|(?:\\d+\\.?))(?:[eE][-+]?\\d+)?")
	var xs: Array[float] = []
	var index := 0
	for match in regex.search_all(markup):
		if index % 2 == 0:
			xs.append(float(match.get_string()))
		index += 1
	var min_x = xs[0]
	var max_x = xs[0]
	for x in xs:
		min_x = minf(min_x, x)
		max_x = maxf(max_x, x)
	return (min_x + max_x) * 0.5
