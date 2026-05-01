extends GutTest

const PoseKinematicsScript := preload("res://scripts/doll/PoseKinematics.gd")

var repo: ContentRepository


func before_each() -> void:
	repo = ContentRepository.new()
	var result = repo.load_all()
	assert_true(result.get("ok", false), "; ".join(result.get("errors", [])))


func test_rest_hand_target_keeps_left_arm_near_rest_rotation() -> void:
	var pose := {"parts": {}, "sprites": {}}
	var result = PoseKinematicsScript.solve_arm_ik(repo, "female", pose, "left", PoseKinematicsScript.pivot_for(repo, "female", "leftHand"))

	assert_true(result.get("ok", false), "; ".join(result.get("errors", [])))
	assert_almost_eq(float(result["updates"]["leftArm"].get("rotate", 0.0)), 0.0, 0.1)
	assert_almost_eq(float(result["updates"]["leftForearm"].get("rotate", 0.0)), 0.0, 0.1)


func test_reachable_hand_target_updates_upper_and_forearm() -> void:
	var pose := {"parts": {}, "sprites": {}}
	var shoulder = PoseKinematicsScript.pivot_for(repo, "female", "leftArm")
	var result = PoseKinematicsScript.solve_arm_ik(repo, "female", pose, "left", shoulder + Vector2(-360.0, 280.0))

	assert_true(result.get("ok", false), "; ".join(result.get("errors", [])))
	assert_true(result["updates"].has("leftArm"))
	assert_true(result["updates"].has("leftForearm"))
	assert_false(is_equal_approx(float(result["updates"]["leftArm"].get("rotate", 0.0)), 0.0))


func test_unreachable_hand_target_is_clamped_to_arm_reach() -> void:
	var pose := {"parts": {}, "sprites": {}}
	var shoulder = PoseKinematicsScript.pivot_for(repo, "female", "rightArm")
	var result = PoseKinematicsScript.solve_arm_ik(repo, "female", pose, "right", shoulder + Vector2(5000.0, 0.0))
	var upper_length = PoseKinematicsScript.pivot_for(repo, "female", "rightArm").distance_to(PoseKinematicsScript.pivot_for(repo, "female", "rightForearm"))
	var lower_length = PoseKinematicsScript.pivot_for(repo, "female", "rightForearm").distance_to(PoseKinematicsScript.pivot_for(repo, "female", "rightHand"))

	assert_true(result.get("ok", false), "; ".join(result.get("errors", [])))
	assert_true(shoulder.distance_to(result["target"]) <= upper_length + lower_length)


func test_mirrored_arm_targets_produce_opposing_upper_rotation() -> void:
	var pose := {"parts": {}, "sprites": {}}
	var left_result = PoseKinematicsScript.solve_arm_ik(repo, "female", pose, "left", Vector2(720.0, 1300.0))
	var right_result = PoseKinematicsScript.solve_arm_ik(repo, "female", pose, "right", Vector2(1680.0, 1300.0))

	assert_true(left_result.get("ok", false), "; ".join(left_result.get("errors", [])))
	assert_true(right_result.get("ok", false), "; ".join(right_result.get("errors", [])))
	assert_almost_eq(
		float(left_result["updates"]["leftArm"].get("rotate", 0.0)),
		-float(right_result["updates"]["rightArm"].get("rotate", 0.0)),
		20.0
	)


func test_invalid_ik_side_is_rejected() -> void:
	var result = PoseKinematicsScript.solve_arm_ik(repo, "female", {"parts": {}, "sprites": {}}, "middle", Vector2.ZERO)

	assert_false(result.get("ok", true))


func test_leg_ik_updates_thigh_and_shank() -> void:
	var pose := {"parts": {}, "sprites": {}}
	var hip = PoseKinematicsScript.pivot_for(repo, "female", "leftThigh")
	var result = PoseKinematicsScript.solve_limb_ik(repo, "female", pose, "leftLeg", hip + Vector2(-140.0, 760.0))

	assert_true(result.get("ok", false), "; ".join(result.get("errors", [])))
	assert_true(result["updates"].has("leftThigh"))
	assert_true(result["updates"].has("leftShank"))


func test_pose_bend_emits_visible_svg_transform() -> void:
	var pose = {"id": "bend-test", "name": "Bend Test", "parts": {"leftArm": {"bend": 12.0}}, "sprites": {}}
	repo.poses.append(pose)
	repo.set_collection("poses", repo.poses)
	var outfit = OutfitState.new(repo.starting_outfit_snapshot())
	outfit.pose_id = "bend-test"

	var svg = DollSvgBuilder.build_svg(repo, outfit)

	assert_true(svg.contains("skewX(12"))
