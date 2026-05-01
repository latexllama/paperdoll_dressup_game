extends GutTest


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
