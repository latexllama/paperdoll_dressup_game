extends GutTest

const PoseKinematicsScript := preload("res://scripts/doll/PoseKinematics.gd")

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
