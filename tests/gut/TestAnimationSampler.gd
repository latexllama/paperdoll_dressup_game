extends GutTest


func test_sampler_interpolates_pose_transforms_and_shortest_rotation() -> void:
	var repo = _repo_with_poses()
	var animation := {
		"id": "turn",
		"name": "Turn",
		"frameCount": 11,
		"fps": 10.0,
		"loop": false,
		"visibleInPlayer": true,
		"keyframes": [{"frame": 0, "poseId": "a"}, {"frame": 10, "poseId": "b"}],
	}

	var sample = AnimationSampler.sample_at_frame(repo, animation, 5.0)

	assert_almost_eq(float(sample["parts"]["body"]["x"]), 50.0, 0.01)
	assert_almost_eq(float(sample["parts"]["body"]["rotate"]), 180.0, 0.01)
	assert_eq(sample["sprites"].get("leftHand", ""), "open")


func test_sampler_wraps_looping_animation() -> void:
	var repo = _repo_with_poses()
	var animation := {
		"id": "loop",
		"name": "Loop",
		"frameCount": 10,
		"fps": 10.0,
		"loop": true,
		"visibleInPlayer": true,
		"keyframes": [{"frame": 0, "poseId": "a"}, {"frame": 5, "poseId": "b"}],
	}

	var sample = AnimationSampler.sample_at_frame(repo, animation, 12.5)

	assert_gt(float(sample["parts"]["body"]["x"]), 0.0)
	assert_lt(float(sample["parts"]["body"]["x"]), 100.0)


func test_blend_pose_samples_uses_weighted_numeric_values_and_latest_sprite() -> void:
	var pose_a := {"parts": {"body": {"x": 0.0}}, "sprites": {"leftHand": "open"}}
	var pose_b := {"parts": {"body": {"x": 100.0}}, "sprites": {"leftHand": "fist"}}

	var blended = AnimationSampler.blend_pose_samples([
		{"pose": pose_a, "weight": 1.0},
		{"pose": pose_b, "weight": 3.0},
	])

	assert_almost_eq(float(blended["parts"]["body"]["x"]), 75.0, 0.01)
	assert_eq(blended["sprites"]["leftHand"], "fist")


func _repo_with_poses() -> ContentRepository:
	var repo := ContentRepository.new()
	repo.poses = [
		{"id": "a", "name": "A", "parts": {"body": {"x": 0.0, "rotate": 170.0}}, "sprites": {"leftHand": "open"}},
		{"id": "b", "name": "B", "parts": {"body": {"x": 100.0, "rotate": -170.0}}, "sprites": {"leftHand": "fist"}},
	]
	repo._rebuild_indexes()
	return repo
