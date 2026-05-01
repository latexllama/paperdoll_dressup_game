class_name AnimationTimelineEditor
extends VBoxContainer

signal frame_changed(frame: float)
signal set_keyframe_requested(frame: int, pose_id: String)
signal create_pose_requested(frame: int)
signal delete_keyframe_requested(frame: int)

var animation: Dictionary = {}
var poses: Array = []
var current_frame := 0.0

var _playing := false
var _syncing := false

@onready var _first_button: Button = %FirstFrameButton
@onready var _previous_button: Button = %PreviousFrameButton
@onready var _play_button: Button = %PlayPauseButton
@onready var _next_button: Button = %NextFrameButton
@onready var _last_button: Button = %LastFrameButton
@onready var _frame_spin: SpinBox = %FrameSpin
@onready var _frame_slider: HSlider = %FrameSlider
@onready var _pose_option: OptionButton = %PoseOption
@onready var _keyframe_list: ItemList = %KeyframeList
@onready var _set_keyframe_button: Button = %SetKeyframeButton
@onready var _create_pose_button: Button = %CreatePoseButton
@onready var _delete_keyframe_button: Button = %DeleteKeyframeButton


func _ready() -> void:
	_first_button.pressed.connect(_seek_to_first)
	_previous_button.pressed.connect(_seek_previous)
	_play_button.pressed.connect(_toggle_playing)
	_next_button.pressed.connect(_seek_next)
	_last_button.pressed.connect(_seek_to_last)
	_frame_spin.value_changed.connect(_on_frame_value_changed)
	_frame_slider.value_changed.connect(_on_frame_value_changed)
	_keyframe_list.item_selected.connect(_on_keyframe_selected)
	_set_keyframe_button.pressed.connect(_on_set_keyframe_pressed)
	_create_pose_button.pressed.connect(_on_create_pose_pressed)
	_delete_keyframe_button.pressed.connect(_on_delete_keyframe_pressed)
	set_process(false)


func configure(next_animation: Dictionary, next_poses: Array, next_frame := 0.0) -> void:
	animation = next_animation
	poses = next_poses
	current_frame = clampf(next_frame, 0.0, _last_frame())
	_playing = false
	set_process(false)
	_refresh_controls()


func set_current_frame(next_frame: float) -> void:
	current_frame = clampf(next_frame, 0.0, _last_frame())
	_sync_frame_controls()


func _process(delta: float) -> void:
	if animation.is_empty() or not _playing:
		return
	var fps := maxf(0.001, float(animation.get("fps", 24.0)))
	var next_frame := current_frame + delta * fps
	if next_frame > _last_frame():
		if bool(animation.get("loop", false)):
			next_frame = fposmod(next_frame, _last_frame() + 1.0)
		else:
			next_frame = _last_frame()
			_playing = false
			set_process(false)
			_play_button.text = "Play"
	current_frame = next_frame
	_sync_frame_controls()
	frame_changed.emit(current_frame)


func _refresh_controls() -> void:
	_syncing = true
	_frame_spin.min_value = 0.0
	_frame_spin.max_value = _last_frame()
	_frame_spin.step = 1.0
	_frame_slider.min_value = 0.0
	_frame_slider.max_value = _last_frame()
	_frame_slider.step = 1.0
	_pose_option.clear()
	for pose in poses:
		_pose_option.add_item("%s  %s" % [String(pose.get("id", "")), String(pose.get("name", ""))])
		_pose_option.set_item_metadata(_pose_option.item_count - 1, String(pose.get("id", "")))
	_keyframe_list.clear()
	for keyframe in _sorted_keyframes():
		var pose_id := String(keyframe.get("poseId", ""))
		_keyframe_list.add_item("Frame %d  %s" % [int(keyframe.get("frame", 0)), pose_id])
		_keyframe_list.set_item_metadata(_keyframe_list.item_count - 1, int(keyframe.get("frame", 0)))
	_syncing = false
	_select_pose_for_current_keyframe()
	_sync_frame_controls()
	_play_button.text = "Pause" if _playing else "Play"


func _sync_frame_controls() -> void:
	if _syncing:
		return
	_syncing = true
	_frame_spin.value = roundi(current_frame)
	_frame_slider.value = current_frame
	_syncing = false


func _select_pose_for_current_keyframe() -> void:
	var pose_id := _pose_id_at_frame(roundi(current_frame))
	if pose_id == "":
		pose_id = String(poses[0].get("id", "")) if poses.size() > 0 else ""
	for index in range(_pose_option.item_count):
		if String(_pose_option.get_item_metadata(index)) == pose_id:
			_pose_option.select(index)
			return
	if _pose_option.item_count > 0:
		_pose_option.select(0)


func _on_frame_value_changed(value: float) -> void:
	if _syncing:
		return
	current_frame = clampf(value, 0.0, _last_frame())
	_sync_frame_controls()
	_select_pose_for_current_keyframe()
	frame_changed.emit(current_frame)


func _on_keyframe_selected(index: int) -> void:
	if index < 0:
		return
	current_frame = float(_keyframe_list.get_item_metadata(index))
	_sync_frame_controls()
	_select_pose_for_current_keyframe()
	frame_changed.emit(current_frame)


func _on_set_keyframe_pressed() -> void:
	if _pose_option.item_count == 0:
		return
	set_keyframe_requested.emit(roundi(current_frame), String(_pose_option.get_item_metadata(_pose_option.selected)))


func _on_create_pose_pressed() -> void:
	create_pose_requested.emit(roundi(current_frame))


func _on_delete_keyframe_pressed() -> void:
	delete_keyframe_requested.emit(roundi(current_frame))


func _seek_to_first() -> void:
	_on_frame_value_changed(0.0)


func _seek_previous() -> void:
	_on_frame_value_changed(current_frame - 1.0)


func _seek_next() -> void:
	_on_frame_value_changed(current_frame + 1.0)


func _seek_to_last() -> void:
	_on_frame_value_changed(_last_frame())


func _toggle_playing() -> void:
	_playing = not _playing
	_play_button.text = "Pause" if _playing else "Play"
	set_process(_playing)


func _last_frame() -> float:
	return maxf(0.0, float(animation.get("frameCount", 1)) - 1.0)


func _pose_id_at_frame(frame: int) -> String:
	for keyframe in animation.get("keyframes", []):
		if keyframe is Dictionary and int(keyframe.get("frame", -1)) == frame:
			return String(keyframe.get("poseId", ""))
	return ""


func _sorted_keyframes() -> Array:
	var result: Array = []
	for keyframe in animation.get("keyframes", []):
		if keyframe is Dictionary:
			result.append(keyframe)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("frame", 0)) < int(b.get("frame", 0))
	)
	return result
