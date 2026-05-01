class_name AnimationSampler
extends RefCounted

const TRANSFORM_KEYS := ["rotate", "x", "y", "scaleX", "scaleY", "bend"]
const DEFAULT_TRANSFORM := {
	"rotate": 0.0,
	"x": 0.0,
	"y": 0.0,
	"scaleX": 1.0,
	"scaleY": 1.0,
	"bend": 0.0,
}


static func sample_at_time(repo: ContentRepository, animation: Dictionary, elapsed_seconds: float) -> Dictionary:
	var fps := maxf(0.001, float(animation.get("fps", 24.0)))
	return sample_at_frame(repo, animation, elapsed_seconds * fps)


static func sample_at_frame(repo: ContentRepository, animation: Dictionary, requested_frame: float) -> Dictionary:
	var keyframes := _sorted_keyframes(animation.get("keyframes", []))
	if keyframes.is_empty():
		return {"id": "__empty_animation_sample__", "name": "Empty Animation Sample", "parts": {}, "sprites": {}}
	var frame_count := maxf(1.0, float(animation.get("frameCount", 1)))
	var frame := requested_frame
	if bool(animation.get("loop", false)):
		frame = fposmod(frame, frame_count)
	else:
		frame = clampf(frame, 0.0, frame_count - 1.0)
	var pair := _keyframe_pair(keyframes, frame, bool(animation.get("loop", false)), frame_count)
	var previous: Dictionary = pair.get("previous", keyframes[0])
	var next: Dictionary = pair.get("next", previous)
	var previous_frame := float(pair.get("previous_frame", previous.get("frame", 0)))
	var next_frame := float(pair.get("next_frame", next.get("frame", previous_frame)))
	var span := next_frame - previous_frame
	var amount := 0.0 if is_zero_approx(span) else clampf((frame - previous_frame) / span, 0.0, 1.0)
	var previous_pose := repo.pose(String(previous.get("poseId", "")))
	var next_pose := repo.pose(String(next.get("poseId", "")))
	return interpolate_poses(previous_pose, next_pose, amount)


static func interpolate_poses(previous_pose: Dictionary, next_pose: Dictionary, amount: float) -> Dictionary:
	var pose := {
		"id": "__animation_sample__",
		"name": "Animation Sample",
		"parts": {},
		"sprites": previous_pose.get("sprites", {}).duplicate(true) if previous_pose.get("sprites", {}) is Dictionary else {},
	}
	var part_ids := {}
	for part_id in previous_pose.get("parts", {}).keys():
		part_ids[String(part_id)] = true
	for part_id in next_pose.get("parts", {}).keys():
		part_ids[String(part_id)] = true
	for part_id in part_ids.keys():
		var previous_transform: Dictionary = previous_pose.get("parts", {}).get(part_id, {})
		var next_transform: Dictionary = next_pose.get("parts", {}).get(part_id, {})
		var blended := {}
		for key in TRANSFORM_KEYS:
			var previous_value := float(previous_transform.get(key, DEFAULT_TRANSFORM[key]))
			var next_value := float(next_transform.get(key, DEFAULT_TRANSFORM[key]))
			var value := _lerp_angle_degrees(previous_value, next_value, amount) if key == "rotate" else lerpf(previous_value, next_value, amount)
			if not is_equal_approx(value, float(DEFAULT_TRANSFORM[key])):
				blended[key] = value
		if not blended.is_empty():
			pose["parts"][part_id] = blended
	return pose


static func blend_pose_samples(samples: Array) -> Dictionary:
	var result := {
		"id": "__animation_blend__",
		"name": "Animation Blend",
		"parts": {},
		"sprites": {},
	}
	var total_weight := 0.0
	var part_ids := {}
	for sample in samples:
		if not (sample is Dictionary):
			continue
		var weight := maxf(0.0, float(sample.get("weight", 1.0)))
		if weight <= 0.0:
			continue
		total_weight += weight
		var pose: Dictionary = sample.get("pose", {})
		for part_id in pose.get("parts", {}).keys():
			part_ids[String(part_id)] = true
	if total_weight <= 0.0:
		return result
	for part_id in part_ids.keys():
		var blended := {}
		for key in TRANSFORM_KEYS:
			var accumulated := 0.0
			var has_value := false
			for sample in samples:
				if not (sample is Dictionary):
					continue
				var weight := maxf(0.0, float(sample.get("weight", 1.0)))
				if weight <= 0.0:
					continue
				var pose: Dictionary = sample.get("pose", {})
				var transform: Dictionary = pose.get("parts", {}).get(part_id, {})
				if transform.has(key):
					has_value = true
				accumulated += float(transform.get(key, DEFAULT_TRANSFORM[key])) * weight
			var value := accumulated / total_weight
			if has_value and not is_equal_approx(value, float(DEFAULT_TRANSFORM[key])):
				blended[key] = value
		if not blended.is_empty():
			result["parts"][part_id] = blended
	for sample in samples:
		if not (sample is Dictionary):
			continue
		var pose: Dictionary = sample.get("pose", {})
		for part_id in pose.get("sprites", {}).keys():
			var sprite_id := String(pose["sprites"][part_id])
			if sprite_id != "":
				result["sprites"][String(part_id)] = sprite_id
	return result


static func _sorted_keyframes(raw_keyframes: Variant) -> Array:
	var result: Array = []
	if not (raw_keyframes is Array):
		return result
	for keyframe in raw_keyframes:
		if keyframe is Dictionary:
			result.append(keyframe)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("frame", 0)) < int(b.get("frame", 0))
	)
	return result


static func _keyframe_pair(keyframes: Array, frame: float, loop: bool, frame_count: float) -> Dictionary:
	var previous: Dictionary = keyframes[0]
	var next: Dictionary = keyframes[0]
	for keyframe in keyframes:
		if float(keyframe.get("frame", 0)) <= frame:
			previous = keyframe
		if float(keyframe.get("frame", 0)) >= frame:
			next = keyframe
			break
	if float(next.get("frame", 0)) < frame:
		if loop:
			next = keyframes[0]
			return {
				"previous": previous,
				"next": next,
				"previous_frame": float(previous.get("frame", 0)),
				"next_frame": float(next.get("frame", 0)) + frame_count,
			}
		return {"previous": previous, "next": previous}
	if float(previous.get("frame", 0)) > frame:
		if loop:
			previous = keyframes[keyframes.size() - 1]
			return {
				"previous": previous,
				"next": next,
				"previous_frame": float(previous.get("frame", 0)) - frame_count,
				"next_frame": float(next.get("frame", 0)),
			}
		return {"previous": next, "next": next}
	return {"previous": previous, "next": next}


static func _lerp_angle_degrees(from_degrees: float, to_degrees: float, amount: float) -> float:
	var delta := fposmod(to_degrees - from_degrees + 180.0, 360.0) - 180.0
	return from_degrees + delta * amount
