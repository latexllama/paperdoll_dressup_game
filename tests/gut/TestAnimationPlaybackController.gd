extends GutTest


func test_playback_always_outputs_idle_pose() -> void:
	var repo = _repo()
	var controller := AnimationPlaybackController.new()
	controller.configure(repo)

	var pose = controller.current_pose()

	assert_almost_eq(float(pose["parts"]["body"]["x"]), 10.0, 0.01)


func test_visible_player_animations_excludes_link_only_records() -> void:
	var repo = _repo()
	var controller := AnimationPlaybackController.new()
	controller.configure(repo)

	var visible = controller.visible_player_animations()

	assert_eq(visible.size(), 2)
	assert_eq(String(visible[0].get("id", "")), "idle")
	assert_eq(String(visible[1].get("id", "")), "wave")


func test_item_linked_animation_starts_when_item_is_equipped() -> void:
	var repo = _repo()
	var controller := AnimationPlaybackController.new()
	controller.configure(repo)

	controller.sync_item_animations(["shirt"])
	controller.update(0.5)
	var pose = controller.current_pose()

	assert_gt(float(pose["parts"]["body"]["x"]), 10.0)


func _repo() -> ContentRepository:
	var repo := ContentRepository.new()
	repo.poses = [
		{"id": "idle", "name": "Idle", "parts": {"body": {"x": 10.0}}, "sprites": {}},
		{"id": "wave", "name": "Wave", "parts": {"body": {"x": 110.0}}, "sprites": {}},
	]
	repo.animations = [
		{"id": "idle", "name": "Idle", "frameCount": 12, "fps": 12.0, "loop": true, "visibleInPlayer": true, "keyframes": [{"frame": 0, "poseId": "idle"}]},
		{"id": "wave", "name": "Wave", "frameCount": 12, "fps": 12.0, "loop": true, "visibleInPlayer": true, "keyframes": [{"frame": 0, "poseId": "wave"}]},
		{"id": "hidden-link", "name": "Hidden Link", "frameCount": 12, "fps": 12.0, "loop": true, "visibleInPlayer": false, "keyframes": [{"frame": 0, "poseId": "wave"}]},
	]
	repo.wardrobe = [{"id": "shirt", "name": "Shirt", "slot": "top", "visualId": "visual", "color": "#ffffff", "animationIds": ["hidden-link"]}]
	repo._rebuild_indexes()
	return repo
