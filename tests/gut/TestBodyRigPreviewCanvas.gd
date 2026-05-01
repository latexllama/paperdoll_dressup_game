extends GutTest

const OutfitStateScript := preload("res://scripts/game/OutfitState.gd")


func test_body_part_actor_bounds_use_actor_space_svg_bounds() -> void:
	var repo := _preview_repo()
	var part := repo.body_part("female", "basePart")

	var bounds := DollSvgBuilder.body_part_actor_bounds(repo, "female", _zero_pose(), part)

	assert_true(bounds.has_point(Vector2(150.0, 150.0)))
	assert_false(bounds.has_point(Vector2(400.0, 400.0)))


func test_canvas_hit_testing_uses_topmost_render_layer() -> void:
	var canvas := _configured_canvas()

	assert_eq(canvas._body_part_at_actor_position(Vector2(150.0, 150.0)), "frontPart")


func test_body_part_actor_bounds_falls_back_to_pivot_box() -> void:
	var repo := _preview_repo()
	var part := repo.body_part("female", "boundlessPart")

	var bounds := DollSvgBuilder.body_part_actor_bounds(repo, "female", _zero_pose(), part)

	assert_true(bounds.has_point(Vector2(520.0, 520.0)))
	assert_gt(bounds.size.x, 0.0)
	assert_gt(bounds.size.y, 0.0)


func test_canvas_left_click_selects_body_part() -> void:
	var canvas := _configured_canvas()
	var selected := {"part_id": ""}
	canvas.part_selected.connect(func(part_id: String) -> void:
		selected["part_id"] = part_id
	)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = canvas._actor_to_screen(Vector2(150.0, 150.0))

	canvas._gui_input(event)

	assert_eq(selected["part_id"], "frontPart")
	assert_eq(canvas.selected_part, "frontPart")


func test_canvas_zoom_keeps_actor_coordinate_under_anchor() -> void:
	var canvas := _configured_canvas()
	var actor_position := Vector2(500.0, 760.0)
	var screen_position := canvas._actor_to_screen(actor_position)

	canvas.set_zoom(2.0, screen_position)
	var actor_after_zoom := canvas._screen_to_actor(screen_position, false)

	assert_almost_eq(actor_after_zoom.x, actor_position.x, 0.01)
	assert_almost_eq(actor_after_zoom.y, actor_position.y, 0.01)


func test_canvas_reset_and_frame_selected_part_update_view() -> void:
	var canvas := _configured_canvas()
	canvas.set_zoom(2.0)
	canvas.pan = Vector2(20.0, -30.0)

	canvas.reset_view()

	assert_almost_eq(canvas.zoom, 1.0, 0.01)
	assert_eq(canvas.pan, Vector2.ZERO)

	canvas.frame_part("boundlessPart")
	var bounds := DollSvgBuilder.body_part_actor_bounds(canvas.repo, "female", canvas.pose, canvas.repo.body_part("female", "boundlessPart"))
	var framed_screen := canvas._actor_to_screen(bounds.get_center())

	assert_almost_eq(framed_screen.x, canvas.size.x * 0.5, 1.0)
	assert_almost_eq(framed_screen.y, canvas.size.y * 0.5, 1.0)


func test_canvas_pivot_label_modes_reduce_label_clutter() -> void:
	var canvas := _configured_canvas()

	canvas.pivot_label_mode = BodyRigPreviewCanvas.LABEL_NONE
	assert_false(canvas._should_draw_pivot_label("basePart"))

	canvas.pivot_label_mode = BodyRigPreviewCanvas.LABEL_SELECTED_HOVER
	canvas.selected_part = "basePart"
	assert_true(canvas._should_draw_pivot_label("basePart"))
	assert_false(canvas._should_draw_pivot_label("frontPart"))

	canvas.pivot_label_mode = BodyRigPreviewCanvas.LABEL_ALL
	assert_true(canvas._should_draw_pivot_label("frontPart"))


func test_body_rig_preview_svg_uses_zero_pose_and_empty_equipment_stack() -> void:
	var repo := _preview_repo()
	repo.poses = [{"id": "idle", "name": "Idle", "parts": {"basePart": {"rotate": 37.0}}, "sprites": {}}]
	repo.wardrobe = [{"id": "shirt", "name": "Shirt", "slot": "top", "visualId": "shirtVisual", "color": "#ffffff"}]
	repo.equipment_visuals = [{"id": "shirtVisual", "name": "Shirt Visual", "slot": "top", "pieces": [{"target": "basePart", "layer": "front", "assetId": "shirtAsset"}]}]
	repo.equipment_assets = [{"id": "shirtAsset", "name": "Shirt Asset", "source": "custom", "actorSpace": false, "svgMarkup": "<rect x=\"0\" y=\"0\" width=\"20\" height=\"20\"/>"}]
	repo._rebuild_indexes()
	var outfit = OutfitStateScript.new({"variant": "female", "poseId": "idle", "equippedItemIds": []})
	var svg := DollSvgBuilder.build_svg(repo, outfit, {"poseOverride": _zero_pose()})

	assert_eq(svg.find("equipment-piece"), -1)
	assert_eq(svg.find("rotate(37"), -1)


func _configured_canvas() -> BodyRigPreviewCanvas:
	var canvas = load("res://scenes/ui/BodyRigPreviewCanvas.tscn").instantiate()
	add_child_autoqfree(canvas)
	canvas.size = Vector2(420.0, 520.0)
	canvas.configure(_preview_repo(), "female", "basePart", null, {"pose": _zero_pose()})
	return canvas


func _preview_repo() -> ContentRepository:
	var repo := ContentRepository.new()
	repo.body_rig = {
		"female": {
			"parts": [
				_body_part("basePart", "body", "<rect x=\"100\" y=\"100\" width=\"100\" height=\"100\"/>", Vector2(150.0, 150.0)),
				_body_part("frontPart", "front", "<rect x=\"100\" y=\"100\" width=\"100\" height=\"100\"/>", Vector2(150.0, 150.0)),
				_body_part("boundlessPart", "body", "<g/>", Vector2(520.0, 520.0)),
			],
		},
	}
	repo.sample_meta = {
		"variants": {
			"female": {
				"viewBox": {"x": 0.0, "y": 88.0, "width": 2400.0, "height": 3100.0},
				"baseScale": 1.0,
			},
		},
	}
	repo._rebuild_indexes()
	return repo


func _body_part(part_id: String, layer_id: String, markup: String, pivot: Vector2) -> Dictionary:
	return {
		"id": part_id,
		"parentId": "",
		"layer": layer_id,
		"pivot": {"x": pivot.x, "y": pivot.y},
		"svgMarkup": markup,
		"variations": {},
		"latticeVariations": {},
	}


func _zero_pose() -> Dictionary:
	return {"id": "__zero__", "parts": {}, "sprites": {}}
