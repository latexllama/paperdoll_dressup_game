extends GutTest


func test_part_export_uses_actor_canvas_and_selected_part_only() -> void:
	var repo := _repo_with_parts()
	var part := _body_part("leftArm", "body", "<g id=\"left-arm-base\"/>")

	var svg := BodyRigSvgExporter.build_part_template_svg(repo, "female", part, "base", String(part.get("svgMarkup", "")))

	assert_string_contains(svg, "width=\"2400\" height=\"3100\" viewBox=\"0 0 2400 3100\"")
	assert_string_contains(svg, "data-rig-part=\"leftArm\"")
	assert_string_contains(svg, "left-arm-base")
	assert_eq(svg.find("data-rig-part=\"rightArm\""), -1)


func test_selected_svg_variation_export_uses_variation_markup() -> void:
	var repo := _repo_with_parts()
	var part := _body_part("leftArm", "body", "<g id=\"left-arm-base\"/>")
	part["variations"] = {"wide": "<g id=\"left-arm-wide-variation\"/>"}

	var source := BodyRigSvgExporter.resolve_selected_source(part, "wide", "")
	var svg := BodyRigSvgExporter.build_part_template_svg(repo, "female", part, String(source.get("id", "")), String(source.get("markup", "")))

	assert_string_contains(svg, "data-source-id=\"variation-wide\"")
	assert_string_contains(svg, "left-arm-wide-variation")
	assert_eq(svg.find("left-arm-base"), -1)


func test_selected_lattice_variation_export_writes_deformed_markup() -> void:
	var repo := _repo_with_parts()
	var part := _body_part("leftArm", "body", "<g><path d=\"M 5 5 L 10 10\"/></g>")
	part["latticeVariations"] = {
		"wide": {
			"rows": 2,
			"columns": 2,
			"bounds": {"x": 0.0, "y": 0.0, "width": 10.0, "height": 10.0},
			"points": [
				{"x": 0.0, "y": 0.0},
				{"x": 20.0, "y": 0.0},
				{"x": 0.0, "y": 10.0},
				{"x": 20.0, "y": 10.0},
			],
		},
	}

	var source := BodyRigSvgExporter.resolve_selected_source(part, "", "wide")
	var svg := BodyRigSvgExporter.build_part_template_svg(repo, "female", part, String(source.get("id", "")), String(source.get("markup", "")))

	assert_string_contains(svg, "data-source-id=\"lattice-wide\"")
	assert_string_contains(svg, "M10 5 L20 10")


func test_variant_export_contains_all_parts_in_render_layer_order() -> void:
	var repo := _repo_with_parts()

	var svg := BodyRigSvgExporter.build_variant_template_svg(repo, "female", "", "", "")

	assert_string_contains(svg, "data-rig-part=\"backHair\"")
	assert_string_contains(svg, "data-rig-part=\"torso\"")
	assert_string_contains(svg, "data-rig-part=\"frontHand\"")
	assert_lt(svg.find("id=\"layer-back\""), svg.find("id=\"layer-body\""))
	assert_lt(svg.find("id=\"layer-body\""), svg.find("id=\"layer-front\""))


func test_write_svg_reports_invalid_path() -> void:
	var invalid_path := ProjectSettings.globalize_path("user://missing-export-dir-%s/body.svg" % Time.get_ticks_usec())

	var result := BodyRigSvgExporter.write_svg(invalid_path, "<svg/>")

	assert_false(result.get("ok", true))
	assert_gt(result.get("errors", []).size(), 0)


func _repo_with_parts() -> ContentRepository:
	var repo := ContentRepository.new()
	repo.body_rig = {
		"female": {
			"parts": [
				_body_part("backHair", "back", "<g id=\"back-hair\"/>"),
				_body_part("torso", "body", "<g id=\"torso\"/>"),
				_body_part("frontHand", "front", "<g id=\"front-hand\"/>"),
			],
		},
	}
	repo.sample_meta = {
		"variants": {
			"female": {
				"viewBox": {"x": 0.0, "y": 0.0, "width": 2400.0, "height": 3100.0},
				"baseScale": 1.0,
			},
		},
	}
	return repo


func _body_part(part_id: String, layer_id: String, markup: String) -> Dictionary:
	return {
		"id": part_id,
		"parentId": "",
		"layer": layer_id,
		"pivot": {"x": 0.0, "y": 0.0},
		"svgMarkup": markup,
		"variations": {},
		"latticeVariations": {},
	}
