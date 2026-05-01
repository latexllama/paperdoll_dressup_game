class_name PoseKinematics
extends RefCounted

const DEFAULT_TRANSFORM := {
	"rotate": 0.0,
	"x": 0.0,
	"y": 0.0,
	"scaleX": 1.0,
	"scaleY": 1.0,
	"bend": 0.0,
}
const ARM_CHAINS := {
	"left": {"upper": "leftArm", "middle": "leftForearm", "end": "leftHand"},
	"right": {"upper": "rightArm", "middle": "rightForearm", "end": "rightHand"},
}
const LIMB_CHAINS := {
	"leftArm": {"upper": "leftArm", "middle": "leftForearm", "end": "leftHand", "side": "left"},
	"rightArm": {"upper": "rightArm", "middle": "rightForearm", "end": "rightHand", "side": "right"},
	"leftLeg": {"upper": "leftThigh", "middle": "leftShank", "end": "leftFoot", "side": "left"},
	"rightLeg": {"upper": "rightThigh", "middle": "rightShank", "end": "rightFoot", "side": "right"},
}


static func pivot_for(repo: ContentRepository, variant: String, part_id: String) -> Vector2:
	var part = repo.body_part(variant, part_id)
	var pivot = part.get("pivot", DollSvgBuilder.BASE_PIVOTS.get(part_id, {"x": 0.0, "y": 0.0}))
	return Vector2(float(pivot.get("x", 0.0)), float(pivot.get("y", 0.0)))


static func transform_for(pose: Dictionary, part_id: String) -> Dictionary:
	var transform = pose.get("parts", {}).get(part_id, {})
	var result := DEFAULT_TRANSFORM.duplicate()
	if transform is Dictionary:
		for key in transform.keys():
			if result.has(String(key)):
				result[String(key)] = float(transform[key])
	return result


static func pivot_position(repo: ContentRepository, variant: String, pose: Dictionary, part_id: String) -> Vector2:
	var point = pivot_for(repo, variant, part_id)
	for chain_id in chain_for_target(repo, variant, part_id):
		point = apply_transform_to_point(point, transform_for(pose, chain_id), pivot_for(repo, variant, chain_id))
	return point


static func pivot_positions(repo: ContentRepository, variant: String, pose: Dictionary, part_ids: Array[String]) -> Dictionary:
	var result := {}
	for part_id in part_ids:
		result[part_id] = pivot_position(repo, variant, pose, part_id)
	return result


static func apply_transform_to_point(point: Vector2, transform: Dictionary, pivot: Vector2) -> Vector2:
	var moved = point + Vector2(float(transform.get("x", 0.0)), float(transform.get("y", 0.0)))
	var rotated = pivot + (moved - pivot).rotated(deg_to_rad(float(transform.get("rotate", 0.0))))
	var scale_x = float(transform.get("scaleX", 1.0))
	var scale_y = float(transform.get("scaleY", 1.0))
	return pivot + Vector2((rotated.x - pivot.x) * scale_x, (rotated.y - pivot.y) * scale_y)


static func solve_arm_ik(repo: ContentRepository, variant: String, pose: Dictionary, side: String, target: Vector2) -> Dictionary:
	if not ARM_CHAINS.has(side):
		return {"ok": false, "errors": ["Unknown IK arm side \"%s\"." % side], "updates": {}}
	var chain_id = "%sArm" % side
	return solve_limb_ik(repo, variant, pose, chain_id, target)


static func solve_limb_ik(repo: ContentRepository, variant: String, pose: Dictionary, chain_id: String, target: Vector2) -> Dictionary:
	if not LIMB_CHAINS.has(chain_id):
		return {"ok": false, "errors": ["Unknown IK chain \"%s\"." % chain_id], "updates": {}}
	var chain: Dictionary = LIMB_CHAINS[chain_id]
	var upper_id = String(chain["upper"])
	var middle_id = String(chain["middle"])
	var end_id = String(chain["end"])
	var shoulder_rest = pivot_for(repo, variant, upper_id)
	var elbow_rest = pivot_for(repo, variant, middle_id)
	var hand_rest = pivot_for(repo, variant, end_id)
	var upper_length = shoulder_rest.distance_to(elbow_rest)
	var lower_length = elbow_rest.distance_to(hand_rest)
	if upper_length <= 0.001 or lower_length <= 0.001:
		return {"ok": false, "errors": ["IK chain \"%s\" has invalid segment lengths." % chain_id], "updates": {}}

	var shoulder = pivot_position(repo, variant, pose, upper_id)
	var target_vector = target - shoulder
	var requested_distance = target_vector.length()
	if requested_distance <= 0.001:
		target_vector = (hand_rest - shoulder_rest).normalized()
		requested_distance = 0.001
	var max_reach = upper_length + lower_length - 0.001
	var min_reach = absf(upper_length - lower_length) + 0.001
	var distance = clampf(requested_distance, min_reach, max_reach)
	var clamped_target = shoulder + target_vector.normalized() * distance
	var base_angle = (clamped_target - shoulder).angle()
	var shoulder_cos = clampf((upper_length * upper_length + distance * distance - lower_length * lower_length) / (2.0 * upper_length * distance), -1.0, 1.0)
	var shoulder_offset = acos(shoulder_cos)
	var bend_sign = _preferred_bend_sign(shoulder, clamped_target, pivot_position(repo, variant, pose, middle_id), String(chain["side"]))
	var upper_abs = base_angle + shoulder_offset * bend_sign
	var elbow = shoulder + Vector2.from_angle(upper_abs) * upper_length
	var lower_abs = (clamped_target - elbow).angle()
	var rest_upper_abs = (elbow_rest - shoulder_rest).angle()
	var rest_lower_abs = (hand_rest - elbow_rest).angle()
	var upper_delta = _angle_delta_degrees(upper_abs, rest_upper_abs)
	var forearm_delta = _angle_delta_degrees(lower_abs, rest_lower_abs + deg_to_rad(upper_delta))
	var upper_transform = transform_for(pose, upper_id)
	var middle_transform = transform_for(pose, middle_id)
	upper_transform["rotate"] = upper_delta
	middle_transform["rotate"] = forearm_delta
	return {
		"ok": true,
		"errors": [],
		"updates": {
			upper_id: cleaned_transform(upper_transform),
			middle_id: cleaned_transform(middle_transform),
		},
		"target": clamped_target,
		"elbow": elbow,
	}


static func cleaned_transform(transform: Dictionary) -> Dictionary:
	var result := {}
	for key in DEFAULT_TRANSFORM.keys():
		var value = float(transform.get(key, DEFAULT_TRANSFORM[key]))
		var default_value = float(DEFAULT_TRANSFORM[key])
		if not is_equal_approx(value, default_value):
			result[key] = value
	return result


static func chain_for_target(repo: ContentRepository, variant: String, target: String, seen: Dictionary = {}) -> Array[String]:
	match target:
		"leftForearm":
			return ["leftArm", "leftForearm"]
		"leftHand":
			return ["leftArm", "leftForearm", "leftHand"]
		"rightForearm":
			return ["rightArm", "rightForearm"]
		"rightHand":
			return ["rightArm", "rightForearm", "rightHand"]
		"leftShank":
			return ["leftThigh", "leftShank"]
		"leftFoot":
			return ["leftThigh", "leftShank", "leftFoot"]
		"leftToe":
			return ["leftThigh", "leftShank", "leftFoot", "leftToe"]
		"rightShank":
			return ["rightThigh", "rightShank"]
		"rightFoot":
			return ["rightThigh", "rightShank", "rightFoot"]
		"rightToe":
			return ["rightThigh", "rightShank", "rightFoot", "rightToe"]
		"backHair", "frontHair", "face", "leftEye", "rightEye", "leftBrow", "rightBrow", "mouth", "nose", "leftEar", "rightEar", "horns":
			return ["head", target]
		"tail", "body", "hip", "head", "headNub", "torso", "neck", "leftArm", "rightArm", "leftThigh", "rightThigh":
			return [target]
	if seen.has(target):
		return [target]
	seen[target] = true
	var part = repo.body_part(variant, target)
	var parent_id = String(part.get("parentId", ""))
	if parent_id != "":
		var chain = chain_for_target(repo, variant, parent_id, seen)
		chain.append(target)
		return chain
	return [target]


static func _preferred_bend_sign(shoulder: Vector2, target: Vector2, current_elbow: Vector2, side: String) -> float:
	var cross = (target - shoulder).cross(current_elbow - shoulder)
	if absf(cross) > 0.001:
		return 1.0 if cross > 0.0 else -1.0
	return 1.0 if side == "left" else -1.0


static func _angle_delta_degrees(angle: float, base: float) -> float:
	return rad_to_deg(wrapf(angle - base, -PI, PI))
