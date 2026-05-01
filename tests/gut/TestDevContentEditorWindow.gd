extends GutTest

const PoseKinematicsScript := preload("res://scripts/doll/PoseKinematics.gd")

class FakeRepository:
	extends ContentRepository

	func save_collection(collection_name: String, value: Variant, validation_repo: ContentRepository = null) -> Dictionary:
		var validation_source = validation_repo if validation_repo != null else self
		var validation = ContentValidator.validate_collection(validation_source, collection_name, value)
		if not validation.get("ok", false):
			return validation
		set_collection(collection_name, value.duplicate(true))
		return {"ok": true, "errors": []}


func test_close_request_hides_dev_editor_window() -> void:
	var editor = load("res://scenes/ui/DevContentEditor.tscn").instantiate()
	add_child_autoqfree(editor)
	await get_tree().process_frame
	var repo := ContentRepository.new()
	var validation = repo.load_all()
	assert_true(validation.get("ok", false), "; ".join(validation.get("errors", [])))
	editor.configure(repo, SvgTextureCache.new())

	editor.visible = true
	editor._on_close_requested()

	assert_false(editor.visible)


func test_dirty_close_request_prompts_instead_of_hiding() -> void:
	var editor = load("res://scenes/ui/DevContentEditor.tscn").instantiate()
	add_child_autoqfree(editor)
	await get_tree().process_frame
	var repo := ContentRepository.new()
	var validation = repo.load_all()
	assert_true(validation.get("ok", false), "; ".join(validation.get("errors", [])))
	editor.configure(repo, SvgTextureCache.new())
	editor._draft.wardrobe[0]["name"] = "Dirty Name"

	editor.visible = true
	editor._on_close_requested()

	assert_true(editor.visible)
	assert_true(editor._discard_dialog.visible)


func test_pose_form_selection_does_not_create_missing_transform() -> void:
	var editor = load("res://scenes/ui/DevContentEditor.tscn").instantiate()
	add_child_autoqfree(editor)
	await get_tree().process_frame
	var repo := ContentRepository.new()
	var validation = repo.load_all()
	assert_true(validation.get("ok", false), "; ".join(validation.get("errors", [])))
	editor.configure(repo, SvgTextureCache.new())
	editor._section = "poses"
	editor._selected_id = String(editor._draft.poses[0]["id"])
	editor._selected_pose_part = "headNub"
	editor._draft.mark_clean()

	editor._render_form()

	assert_false(editor._draft.poses[0]["parts"].has("headNub"))
	assert_false(editor._draft.is_dirty())


func test_pose_canvas_selection_does_not_dirty_draft() -> void:
	var editor = load("res://scenes/ui/DevContentEditor.tscn").instantiate()
	add_child_autoqfree(editor)
	await get_tree().process_frame
	var repo := ContentRepository.new()
	var validation = repo.load_all()
	assert_true(validation.get("ok", false), "; ".join(validation.get("errors", [])))
	editor.configure(repo, SvgTextureCache.new())
	editor._section = "poses"
	editor._selected_id = String(editor._draft.poses[0]["id"])
	editor._draft.mark_clean()

	editor._on_pose_canvas_part_selected("leftHand")

	assert_eq(editor._selected_pose_part, "leftHand")
	assert_false(editor._draft.is_dirty())


func test_body_rig_canvas_selection_updates_record_without_dirtying_draft() -> void:
	var editor = load("res://scenes/ui/DevContentEditor.tscn").instantiate()
	add_child_autoqfree(editor)
	await get_tree().process_frame
	var repo := ContentRepository.new()
	var validation = repo.load_all()
	assert_true(validation.get("ok", false), "; ".join(validation.get("errors", [])))
	editor.configure(repo, SvgTextureCache.new())
	editor._section = "body_rig"
	editor._selected_variant = "female"
	var target_part = String(repo.body_parts_for_variant("female")[1].get("id", ""))
	editor._draft.mark_clean()

	editor._on_body_rig_canvas_part_selected(target_part)

	assert_eq(editor._selected_id, target_part)
	assert_false(editor._draft.is_dirty())


func test_body_rig_pivot_sliders_update_selected_part() -> void:
	var editor = load("res://scenes/ui/DevContentEditor.tscn").instantiate()
	add_child_autoqfree(editor)
	await get_tree().process_frame
	var repo := ContentRepository.new()
	var validation = repo.load_all()
	assert_true(validation.get("ok", false), "; ".join(validation.get("errors", [])))
	editor.configure(repo, SvgTextureCache.new())
	editor._section = "body_rig"
	editor._selected_variant = "female"
	editor._selected_id = "tail"
	editor._render_form()
	var part = editor._selected_record()
	var pivot_x_slider = editor._form_content.find_child("PivotXSlider", true, false) as HSlider
	var pivot_x_spin = editor._form_content.find_child("PivotXSpinBox", true, false) as SpinBox
	assert_not_null(pivot_x_slider)
	assert_not_null(pivot_x_spin)
	editor._draft.mark_clean()

	pivot_x_slider.value = 1500.0

	assert_eq(float(part["pivot"]["x"]), 1500.0)
	assert_eq(pivot_x_spin.value, 1500.0)
	assert_true(editor._draft.is_dirty())


func test_body_rig_repair_notice_can_mark_generated_parts_for_save() -> void:
	var editor = await _configured_editor()
	editor.repo.generated_body_part_repairs = [{"variant": "female", "partId": "tail"}]
	editor._section = "body_rig"
	editor._selected_variant = "female"
	editor._selected_id = "tail"
	editor._render_form()
	editor._draft.mark_clean()

	_button_for_text(editor, "Repair/Save Generated Parts").pressed.emit()

	assert_true(editor._draft.is_dirty())
	assert_string_contains(editor._status.text, "ready to save")


func test_pose_canvas_ik_updates_upper_and_forearm_transforms() -> void:
	var editor = load("res://scenes/ui/DevContentEditor.tscn").instantiate()
	add_child_autoqfree(editor)
	await get_tree().process_frame
	var repo := ContentRepository.new()
	var validation = repo.load_all()
	assert_true(validation.get("ok", false), "; ".join(validation.get("errors", [])))
	editor.configure(repo, SvgTextureCache.new())
	editor._section = "poses"
	editor._selected_id = String(editor._draft.poses[0]["id"])
	var pose = editor._draft.poses[0]
	var shoulder = PoseKinematicsScript.pivot_for(repo, "female", "leftArm")
	var ik_result = PoseKinematicsScript.solve_arm_ik(repo, "female", pose, "left", shoulder + Vector2(-340.0, 220.0))
	assert_true(ik_result.get("ok", false), "; ".join(ik_result.get("errors", [])))
	editor._draft.mark_clean()

	editor._on_pose_canvas_ik_chain_changed("left", ik_result.get("updates", {}))

	assert_true(pose["parts"].has("leftArm"))
	assert_true(pose["parts"].has("leftForearm"))
	assert_true(editor._draft.is_dirty())


func test_pose_canvas_ik_updates_thigh_and_shank_transforms() -> void:
	var editor = load("res://scenes/ui/DevContentEditor.tscn").instantiate()
	add_child_autoqfree(editor)
	await get_tree().process_frame
	var repo := ContentRepository.new()
	var validation = repo.load_all()
	assert_true(validation.get("ok", false), "; ".join(validation.get("errors", [])))
	editor.configure(repo, SvgTextureCache.new())
	editor._section = "poses"
	editor._selected_id = String(editor._draft.poses[0]["id"])
	var pose = editor._draft.poses[0]
	var hip = PoseKinematicsScript.pivot_for(repo, "female", "leftThigh")
	var ik_result = PoseKinematicsScript.solve_limb_ik(repo, "female", pose, "leftLeg", hip + Vector2(-120.0, 720.0))
	assert_true(ik_result.get("ok", false), "; ".join(ik_result.get("errors", [])))
	editor._draft.mark_clean()

	editor._on_pose_canvas_ik_chain_changed("leftLeg", ik_result.get("updates", {}))

	assert_true(pose["parts"].has("leftThigh"))
	assert_true(pose["parts"].has("leftShank"))
	assert_true(editor._draft.is_dirty())


func test_pose_canvas_non_endpoint_click_selects_without_starting_drag() -> void:
	var canvas = load("res://scenes/ui/PosePreviewCanvas.tscn").instantiate()
	add_child_autoqfree(canvas)
	await get_tree().process_frame
	var repo := ContentRepository.new()
	var validation = repo.load_all()
	assert_true(validation.get("ok", false), "; ".join(validation.get("errors", [])))
	var pose = repo.pose("idle").duplicate(true)
	canvas.size = Vector2(420.0, 520.0)
	canvas.configure(repo, pose, "female", "body", null)
	var position = canvas._actor_to_screen(PoseKinematicsScript.pivot_position(repo, "female", pose, "leftThigh"))

	canvas._begin_drag(position)

	assert_eq(canvas.selected_part, "leftThigh")
	assert_eq(canvas._drag_chain, "")


func test_existing_identity_fields_are_read_only() -> void:
	var editor = await _configured_editor()

	editor._section = "wardrobe"
	editor._selected_id = String(editor._draft.wardrobe[0]["id"])
	editor._render_form()
	assert_false(_line_edit_for_label(editor, "ID").editable)

	editor._section = "equipment_visuals"
	editor._selected_id = String(editor._draft.equipment_visuals[0]["id"])
	editor._render_form()
	assert_false(_line_edit_for_label(editor, "ID").editable)

	editor._section = "equipment_assets"
	editor._selected_id = String(editor._draft.equipment_assets[0]["id"])
	editor._render_form()
	assert_false(_line_edit_for_label(editor, "ID").editable)

	editor._section = "body_rig"
	editor._selected_variant = "female"
	var part: Dictionary = editor._parts_for_selected_variant()[0]
	editor._selected_id = String(part["id"])
	editor._render_form()
	assert_false(_line_edit_for_label(editor, "Part ID").editable)

	editor._section = "poses"
	editor._selected_id = String(editor._draft.poses[0]["id"])
	editor._render_form()
	assert_false(_line_edit_for_label(editor, "ID").editable)

	editor._section = "body_rig"
	editor._selected_id = String(part["id"])
	part["variations"]["existingVariationForTest"] = String(part.get("svgMarkup", ""))
	editor._selected_svg_variation_id = "existingVariationForTest"
	editor._render_form()
	assert_false(_line_edit_for_label(editor, "Variation ID").editable)

	var lattice = DevEditorModels.create_lattice_variation(part, "existingLatticeForTest")
	lattice.erase("id")
	part["latticeVariations"]["existingLatticeForTest"] = lattice
	editor._selected_lattice_id = "existingLatticeForTest"
	editor._render_form()
	assert_false(_line_edit_for_label(editor, "Lattice ID").editable)


func test_add_record_id_is_editable_until_record_selection_changes() -> void:
	var editor = await _configured_editor()
	editor._section = "wardrobe"
	editor._refresh_all()

	editor._on_add_pressed()

	var created_id := editor._selected_id
	assert_true(_line_edit_for_label(editor, "ID").editable)

	editor._on_record_selected(0)

	assert_ne(editor._selected_id, created_id)
	assert_false(_line_edit_for_label(editor, "ID").editable)


func test_save_and_revert_clear_creation_id_edit() -> void:
	var fake_repo := FakeRepository.new()
	var editor = await _configured_editor(fake_repo)

	editor._section = "wardrobe"
	editor._on_add_pressed()
	assert_false(editor._creation_id_edit.is_empty())

	editor._on_save_all_pressed()

	assert_true(editor._creation_id_edit.is_empty())

	editor._on_add_pressed()
	assert_false(editor._creation_id_edit.is_empty())

	editor._on_revert_pressed()

	assert_true(editor._creation_id_edit.is_empty())


func test_new_record_id_edit_rejects_empty_and_duplicate_values() -> void:
	var editor = await _configured_editor()
	editor._section = "wardrobe"
	editor._refresh_all()
	var duplicate_id := String(editor._draft.wardrobe[0]["id"])

	editor._on_add_pressed()

	var created_id := editor._selected_id
	var id_edit := _line_edit_for_label(editor, "ID")
	id_edit.text_changed.emit("")
	assert_eq(editor._selected_id, created_id)
	id_edit.text_changed.emit(duplicate_id)
	assert_eq(editor._selected_id, created_id)

	id_edit.text_changed.emit("new-test-wardrobe-id")

	assert_eq(editor._selected_id, "new-test-wardrobe-id")
	assert_false(DevEditorModels.record_by_id(editor._draft.wardrobe, "new-test-wardrobe-id").is_empty())


func test_duplicate_prompts_for_id_and_creates_read_only_clone() -> void:
	var editor = await _configured_editor()
	editor._section = "wardrobe"
	editor._selected_id = String(editor._draft.wardrobe[0]["id"])
	editor._render_form()
	var duplicate_id := String(editor._draft.wardrobe[1]["id"])

	editor._on_duplicate_pressed()

	assert_true(editor._create_id_dialog.visible)
	editor._on_create_id_text_changed(duplicate_id)
	assert_true(editor._create_id_dialog.get_ok_button().disabled)

	editor._create_id_edit.text = "manual-wardrobe-copy"
	editor._on_create_id_text_changed("manual-wardrobe-copy")
	assert_false(editor._create_id_dialog.get_ok_button().disabled)
	editor._on_create_id_confirmed()

	assert_eq(editor._selected_id, "manual-wardrobe-copy")
	assert_false(DevEditorModels.record_by_id(editor._draft.wardrobe, "manual-wardrobe-copy").is_empty())
	assert_false(_line_edit_for_label(editor, "ID").editable)


func test_new_svg_and_lattice_variation_ids_are_editable_only_during_creation() -> void:
	var editor = await _configured_editor()
	editor._section = "body_rig"
	editor._selected_variant = "female"
	var part: Dictionary = editor._parts_for_selected_variant()[0]
	editor._selected_id = String(part["id"])
	editor._render_form()

	_button_for_text(editor, "Add SVG Variation").pressed.emit()

	assert_true(_line_edit_for_label(editor, "Variation ID").editable)
	editor._clear_creation_id_edit()
	editor._render_form()
	assert_false(_line_edit_for_label(editor, "Variation ID").editable)

	_button_for_text(editor, "Create Lattice").pressed.emit()

	assert_true(_line_edit_for_label(editor, "Lattice ID").editable)
	editor._clear_creation_id_edit()
	editor._render_form()
	assert_false(_line_edit_for_label(editor, "Lattice ID").editable)


func _configured_editor(repository: ContentRepository = null) -> DevContentEditor:
	var editor = load("res://scenes/ui/DevContentEditor.tscn").instantiate()
	add_child_autoqfree(editor)
	await get_tree().process_frame
	var next_repo = repository if repository != null else ContentRepository.new()
	var validation = next_repo.load_all()
	assert_true(validation.get("ok", false), "; ".join(validation.get("errors", [])))
	editor.configure(next_repo, SvgTextureCache.new())
	return editor


func _line_edit_for_label(editor: DevContentEditor, label: String) -> LineEdit:
	for row in editor._form_content.get_children():
		if not (row is HBoxContainer) or row.get_child_count() < 2:
			continue
		var label_node = row.get_child(0) as Label
		if label_node != null and label_node.text == label:
			return row.get_child(1) as LineEdit
	return null


func _button_for_text(editor: DevContentEditor, text: String) -> Button:
	return _find_button_for_text(editor._form_content, text)


func _find_button_for_text(root: Node, text: String) -> Button:
	for child in root.get_children():
		var button = child as Button
		if button != null and button.text == text:
			return button
		var nested := _find_button_for_text(child, text)
		if nested != null:
			return nested
	return null
