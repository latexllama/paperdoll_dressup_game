class_name AnimationPlaybackController
extends RefCounted

const AnimationSamplerScript := preload("res://scripts/doll/AnimationSampler.gd")

var repo: ContentRepository
var idle_animation_id := "idle"

var _tracks: Array[Dictionary] = []
var _equipped_item_ids: Array[String] = []
var _player_loop_key := ""
var _sequence := 0
var _idle_elapsed := 0.0


func configure(next_repo: ContentRepository) -> void:
	repo = next_repo
	reset()


func reset() -> void:
	_tracks.clear()
	_equipped_item_ids.clear()
	_player_loop_key = ""
	_sequence = 0
	_idle_elapsed = 0.0


func update(delta_seconds: float) -> bool:
	var changed := false
	_idle_elapsed += maxf(0.0, delta_seconds)
	for track in _tracks:
		track["elapsed"] = float(track.get("elapsed", 0.0)) + maxf(0.0, delta_seconds)
	var kept: Array[Dictionary] = []
	for track in _tracks:
		var animation = _animation_for_track(track)
		if animation.is_empty():
			changed = true
			continue
		if not bool(animation.get("loop", false)) and float(track.get("elapsed", 0.0)) >= _duration_seconds(animation):
			changed = true
			continue
		kept.append(track)
	if kept.size() != _tracks.size():
		_tracks = kept
	return changed or not _tracks.is_empty() or (repo != null and repo.has_animation(idle_animation_id))


func current_pose() -> Dictionary:
	if repo == null:
		return {"id": "__no_repo_animation_pose__", "parts": {}, "sprites": {}}
	var idle_animation := repo.animation(idle_animation_id)
	var base_pose := {}
	if idle_animation.is_empty():
		base_pose = repo.pose("idle").duplicate(true)
	else:
		base_pose = AnimationSamplerScript.sample_at_time(repo, idle_animation, _idle_elapsed)
	var active_samples: Array = []
	for track in _tracks:
		var animation = _animation_for_track(track)
		if animation.is_empty():
			continue
		active_samples.append({
			"pose": AnimationSamplerScript.sample_at_time(repo, animation, float(track.get("elapsed", 0.0))),
			"weight": float(track.get("weight", 1.0)),
		})
	if active_samples.is_empty():
		return base_pose
	return _merge_pose_overlay(base_pose, AnimationSamplerScript.blend_pose_samples(active_samples))


func play_player_animation(animation_id: String) -> Dictionary:
	if repo == null or not repo.has_animation(animation_id):
		return {"ok": false, "errors": ["Unknown animation: %s" % animation_id]}
	var animation := repo.animation(animation_id)
	if bool(animation.get("loop", false)):
		if _player_loop_key != "":
			_remove_track(_player_loop_key)
		_player_loop_key = _start_track("player", animation_id, "player:%s" % animation_id)
	else:
		_start_track("player", animation_id, "player:%s:%d" % [animation_id, _next_sequence()])
	return {"ok": true, "errors": []}


func sync_item_animations(equipped_item_ids: Array[String]) -> void:
	if repo == null:
		return
	var previous := {}
	for item_id in _equipped_item_ids:
		previous[item_id] = true
	var current := {}
	for item_id in equipped_item_ids:
		current[item_id] = true
	for item_id in previous.keys():
		if not current.has(item_id):
			_stop_item_tracks(String(item_id))
	for item_id in equipped_item_ids:
		if not previous.has(item_id):
			_start_item_tracks(item_id)
	_equipped_item_ids = equipped_item_ids.duplicate()


func visible_player_animations() -> Array:
	var result: Array = []
	if repo == null:
		return result
	for animation in repo.animations:
		if bool(animation.get("visibleInPlayer", false)):
			result.append(animation)
	return result


func _start_item_tracks(item_id: String) -> void:
	var item := repo.wardrobe_item(item_id)
	for animation_id in item.get("animationIds", []):
		var id := String(animation_id)
		if id == "" or not repo.has_animation(id):
			continue
		var animation := repo.animation(id)
		var key := "item:%s:%s" % [item_id, id]
		if bool(animation.get("loop", false)):
			_start_track("item:%s" % item_id, id, key)
		else:
			_start_track("item:%s" % item_id, id, "%s:%d" % [key, _next_sequence()])


func _stop_item_tracks(item_id: String) -> void:
	var kept: Array[Dictionary] = []
	var prefix := "item:%s" % item_id
	for track in _tracks:
		if String(track.get("source", "")) != prefix:
			kept.append(track)
	_tracks = kept


func _start_track(source: String, animation_id: String, key: String) -> String:
	_remove_track(key)
	_tracks.append({
		"key": key,
		"source": source,
		"animationId": animation_id,
		"elapsed": 0.0,
		"weight": 1.0,
		"order": _next_sequence(),
	})
	return key


func _remove_track(key: String) -> void:
	var kept: Array[Dictionary] = []
	for track in _tracks:
		if String(track.get("key", "")) != key:
			kept.append(track)
	_tracks = kept


func _animation_for_track(track: Dictionary) -> Dictionary:
	if repo == null:
		return {}
	return repo.animation(String(track.get("animationId", "")))


func _duration_seconds(animation: Dictionary) -> float:
	return maxf(0.001, float(animation.get("frameCount", 1)) / maxf(0.001, float(animation.get("fps", 24.0))))


func _merge_pose_overlay(base_pose: Dictionary, overlay_pose: Dictionary) -> Dictionary:
	var result = base_pose.duplicate(true)
	if not result.has("parts") or not (result["parts"] is Dictionary):
		result["parts"] = {}
	if not result.has("sprites") or not (result["sprites"] is Dictionary):
		result["sprites"] = {}
	for part_id in overlay_pose.get("parts", {}).keys():
		var target_transform: Dictionary = result["parts"].get(part_id, {})
		for key in overlay_pose["parts"][part_id].keys():
			target_transform[key] = overlay_pose["parts"][part_id][key]
		result["parts"][part_id] = target_transform
	for part_id in overlay_pose.get("sprites", {}).keys():
		result["sprites"][part_id] = overlay_pose["sprites"][part_id]
	return result


func _next_sequence() -> int:
	_sequence += 1
	return _sequence
