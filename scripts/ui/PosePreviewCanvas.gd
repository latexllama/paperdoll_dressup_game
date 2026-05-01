class_name PosePreviewCanvas
extends Control

signal part_selected(part_id: String)
signal ik_chain_changed(side: String, transform_patches: Dictionary)
signal edit_finished
signal status_changed(message: String)

const PoseKinematicsScript := preload("res://scripts/doll/PoseKinematics.gd")
const ACTOR_SIZE := Vector2(DollSvgBuilder.ACTOR_WIDTH, DollSvgBuilder.ACTOR_HEIGHT)
const HANDLE_RADIUS := 10.0
const HIT_RADIUS := 20.0
const LIMB_GUIDES := [
	["leftArm", "leftForearm", "leftHand"],
	["rightArm", "rightForearm", "rightHand"],
	["leftThigh", "leftShank", "leftFoot"],
	["rightThigh", "rightShank", "rightFoot"],
]
const IK_HANDLES := {
	"leftHand": "leftArm",
	"rightHand": "rightArm",
	"leftFoot": "leftLeg",
	"rightFoot": "rightLeg",
}

var repo: ContentRepository
var pose: Dictionary = {}
var variant := "female"
var selected_part := "body"
var pose_texture: Texture2D
var show_pivots := true
var show_guides := true
var show_rest_ghost := true
var position_snap := 1.0

var _drag_chain := ""
var _drag_start_actor := Vector2.ZERO
var _drag_last_actor := Vector2.ZERO


func configure(next_repo: ContentRepository, next_pose: Dictionary, next_variant: String, next_selected_part: String, next_texture: Texture2D, options: Dictionary = {}) -> void:
	repo = next_repo
	pose = next_pose
	variant = next_variant
	selected_part = next_selected_part
	pose_texture = next_texture
	show_pivots = bool(options.get("show_pivots", show_pivots))
	show_guides = bool(options.get("show_guides", show_guides))
	show_rest_ghost = bool(options.get("show_rest_ghost", show_rest_ghost))
	position_snap = maxf(1.0, float(options.get("position_snap", position_snap)))
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if repo == null or pose.is_empty():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_end_drag()
	elif event is InputEventMouseMotion and _drag_chain != "":
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			_end_drag()
			return
		_update_drag(event.position)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.88, 0.94, 0.89, 1.0), true)
	if repo == null:
		return
	var actor_rect = _actor_rect()
	if show_rest_ghost:
		_draw_rest_ghost(actor_rect)
	if pose_texture != null:
		draw_texture_rect(pose_texture, actor_rect, false, Color(1, 1, 1, 1))
	if show_guides:
		_draw_guides()
	if show_pivots:
		_draw_handles()
	_draw_selected_label()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _begin_drag(screen_position: Vector2) -> void:
	var hit = _nearest_part(screen_position)
	if hit == "":
		return
	selected_part = hit
	part_selected.emit(hit)
	if not IK_HANDLES.has(hit):
		_drag_chain = ""
		status_changed.emit("Selected %s. Drag hand or foot handles to pose IK chains." % hit)
		accept_event()
		queue_redraw()
		return
	_drag_start_actor = _screen_to_actor(screen_position)
	_drag_last_actor = _drag_start_actor
	_drag_chain = String(IK_HANDLES[hit])
	status_changed.emit("Dragging %s IK handle." % hit)
	accept_event()
	queue_redraw()


func _update_drag(screen_position: Vector2) -> void:
	var actor_position = _snap_actor_position(_screen_to_actor(screen_position))
	var result = PoseKinematicsScript.solve_limb_ik(repo, variant, pose, _drag_chain, actor_position)
	if result.get("ok", false):
		ik_chain_changed.emit(_drag_chain, result.get("updates", {}))
		status_changed.emit("IK %s to %.0f, %.0f." % [_drag_chain, actor_position.x, actor_position.y])
	else:
		status_changed.emit("; ".join(result.get("errors", [])))
	_drag_last_actor = actor_position
	accept_event()
	queue_redraw()


func _end_drag() -> void:
	if _drag_chain == "":
		return
	_drag_chain = ""
	edit_finished.emit()
	accept_event()
	queue_redraw()


func _draw_rest_ghost(actor_rect: Rect2) -> void:
	for guide in LIMB_GUIDES:
		for index in range(guide.size() - 1):
			var from = _actor_to_screen(PoseKinematicsScript.pivot_for(repo, variant, guide[index]))
			var to = _actor_to_screen(PoseKinematicsScript.pivot_for(repo, variant, guide[index + 1]))
			draw_line(from, to, Color(0.16, 0.20, 0.22, 0.18), 3.0)
	draw_rect(actor_rect, Color(0.10, 0.14, 0.16, 0.08), false, 1.0)


func _draw_guides() -> void:
	for guide in LIMB_GUIDES:
		for index in range(guide.size() - 1):
			var from = _actor_to_screen(PoseKinematicsScript.pivot_position(repo, variant, pose, guide[index]))
			var to = _actor_to_screen(PoseKinematicsScript.pivot_position(repo, variant, pose, guide[index + 1]))
			draw_line(from, to, Color(0.09, 0.31, 0.56, 0.72), 4.0)


func _draw_handles() -> void:
	for part_id in _visible_part_ids():
		var screen = _actor_to_screen(PoseKinematicsScript.pivot_position(repo, variant, pose, part_id))
		var is_selected = part_id == selected_part
		var is_ik = IK_HANDLES.has(part_id)
		var fill = Color(1.0, 0.58, 0.12, 1.0) if is_selected else Color(1.0, 0.88, 0.34, 1.0)
		if is_ik:
			fill = Color(0.30, 0.78, 1.0, 1.0) if not is_selected else Color(1.0, 0.58, 0.12, 1.0)
		draw_circle(screen, HANDLE_RADIUS, fill)
		draw_arc(screen, HANDLE_RADIUS, 0.0, TAU, 24, Color(0.08, 0.09, 0.10, 1.0), 2.0)


func _draw_selected_label() -> void:
	var font = get_theme_default_font()
	var font_size = get_theme_default_font_size()
	var text = "Selected: %s" % selected_part
	draw_string(font, Vector2(14, size.y - 16), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.08, 0.09, 0.10, 0.92))


func _nearest_part(screen_position: Vector2) -> String:
	var best_part := ""
	var best_distance := HIT_RADIUS
	for part_id in _visible_part_ids():
		var distance = screen_position.distance_to(_actor_to_screen(PoseKinematicsScript.pivot_position(repo, variant, pose, part_id)))
		if distance <= best_distance:
			best_distance = distance
			best_part = part_id
	return best_part


func _visible_part_ids() -> Array[String]:
	var ids: Array[String] = []
	if repo == null:
		return ids
	for id in repo.known_rig_target_ids():
		var part_id = String(id)
		if not ids.has(part_id):
			ids.append(part_id)
	for required in ["leftArm", "leftForearm", "leftHand", "rightArm", "rightForearm", "rightHand", "leftThigh", "leftShank", "leftFoot", "rightThigh", "rightShank", "rightFoot"]:
		if not ids.has(required):
			ids.append(required)
	return ids


func _actor_rect() -> Rect2:
	var padding := 16.0
	var available = Rect2(Vector2(padding, padding), Vector2(maxf(1.0, size.x - padding * 2.0), maxf(1.0, size.y - padding * 2.0)))
	var aspect = ACTOR_SIZE.x / ACTOR_SIZE.y
	var rect_size = available.size
	if rect_size.x / maxf(1.0, rect_size.y) > aspect:
		rect_size.x = rect_size.y * aspect
	else:
		rect_size.y = rect_size.x / aspect
	return Rect2(available.position + (available.size - rect_size) * 0.5, rect_size)


func _actor_to_screen(actor_position: Vector2) -> Vector2:
	var rect = _actor_rect()
	return rect.position + Vector2(actor_position.x / ACTOR_SIZE.x * rect.size.x, actor_position.y / ACTOR_SIZE.y * rect.size.y)


func _screen_to_actor(screen_position: Vector2) -> Vector2:
	var rect = _actor_rect()
	var u = clampf((screen_position.x - rect.position.x) / maxf(1.0, rect.size.x), 0.0, 1.0)
	var v = clampf((screen_position.y - rect.position.y) / maxf(1.0, rect.size.y), 0.0, 1.0)
	return Vector2(u * ACTOR_SIZE.x, v * ACTOR_SIZE.y)


func _snap_actor_position(actor_position: Vector2) -> Vector2:
	if position_snap <= 1.0:
		return actor_position
	return Vector2(round(actor_position.x / position_snap) * position_snap, round(actor_position.y / position_snap) * position_snap)
