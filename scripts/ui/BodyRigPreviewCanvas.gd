class_name BodyRigPreviewCanvas
extends Control

signal part_selected(part_id: String)
signal zoom_changed(value: float)
signal status_changed(message: String)

const PoseKinematicsScript := preload("res://scripts/doll/PoseKinematics.gd")
const ACTOR_SIZE := Vector2(DollSvgBuilder.ACTOR_WIDTH, DollSvgBuilder.ACTOR_HEIGHT)
const MIN_ZOOM := 0.25
const MAX_ZOOM := 4.0
const ZOOM_STEP := 1.1
const PIVOT_RADIUS := 5.0

var repo: ContentRepository
var variant := "female"
var selected_part := ""
var body_texture: Texture2D
var pose: Dictionary = {"id": "__body_rig_zero__", "parts": {}, "sprites": {}}
var zoom := 1.0
var pan := Vector2.ZERO

var _hovered_part := ""
var _is_panning := false
var _pan_start_mouse := Vector2.ZERO
var _pan_start_offset := Vector2.ZERO


func configure(next_repo: ContentRepository, next_variant: String, next_selected_part: String, next_texture: Texture2D, options: Dictionary = {}) -> void:
	var variant_changed := next_variant != variant
	repo = next_repo
	variant = next_variant
	selected_part = next_selected_part
	body_texture = next_texture
	pose = options.get("pose", {"id": "__body_rig_zero__", "parts": {}, "sprites": {}})
	if variant_changed:
		reset_view()
	queue_redraw()


func set_zoom(next_zoom: float, anchor_screen_position := Vector2(-1.0, -1.0)) -> void:
	var anchor := anchor_screen_position
	if anchor.x < 0.0 or anchor.y < 0.0:
		anchor = size * 0.5
	var actor_before := _screen_to_actor(anchor, false)
	var next_value := clampf(next_zoom, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(next_value, zoom):
		return
	zoom = next_value
	var screen_after := _actor_to_screen(actor_before)
	pan += anchor - screen_after
	zoom_changed.emit(zoom)
	queue_redraw()


func reset_view() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	zoom_changed.emit(zoom)
	queue_redraw()


func frame_part(part_id: String) -> void:
	if repo == null or part_id == "":
		return
	var part := repo.body_part(variant, part_id)
	if part.is_empty():
		return
	var bounds := DollSvgBuilder.body_part_actor_bounds(repo, variant, pose, part)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	var available := _available_rect()
	var padded_size := Vector2(maxf(1.0, available.size.x - 44.0), maxf(1.0, available.size.y - 44.0))
	var fit_rect := _fit_actor_rect()
	var fit_scale := fit_rect.size.x / ACTOR_SIZE.x
	var target_screen_scale := minf(padded_size.x / maxf(1.0, bounds.size.x), padded_size.y / maxf(1.0, bounds.size.y))
	zoom = clampf(target_screen_scale / maxf(0.001, fit_scale), MIN_ZOOM, MAX_ZOOM)
	pan = Vector2.ZERO
	pan = available.get_center() - _actor_to_screen(bounds.get_center())
	zoom_changed.emit(zoom)
	status_changed.emit("Framed %s." % part_id)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if repo == null:
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.88, 0.94, 0.89, 1.0), true)
	if repo == null:
		return
	var actor_rect := _actor_rect()
	draw_rect(actor_rect, Color(0.10, 0.14, 0.16, 0.08), false, 1.0)
	if body_texture != null:
		draw_texture_rect(body_texture, actor_rect, false, Color(1.0, 1.0, 1.0, 1.0))
	_draw_part_highlight(_hovered_part, Color(0.32, 0.78, 1.0, 0.22), Color(0.20, 0.68, 0.94, 0.95))
	_draw_part_highlight(selected_part, Color(1.0, 0.64, 0.18, 0.22), Color(1.0, 0.50, 0.12, 1.0))
	_draw_pivots()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		if _hovered_part != "":
			_hovered_part = ""
			queue_redraw()


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		set_zoom(zoom * ZOOM_STEP, event.position)
		accept_event()
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		set_zoom(zoom / ZOOM_STEP, event.position)
		accept_event()
	elif event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.pressed:
			_is_panning = true
			_pan_start_mouse = event.position
			_pan_start_offset = pan
		else:
			_is_panning = false
		accept_event()
	elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var hit_part := _body_part_at_screen_position(event.position)
		if hit_part != "":
			selected_part = hit_part
			part_selected.emit(hit_part)
			status_changed.emit("Selected %s." % hit_part)
			queue_redraw()
			accept_event()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _is_panning:
		if (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE) == 0:
			_is_panning = false
			return
		pan = _pan_start_offset + event.position - _pan_start_mouse
		queue_redraw()
		accept_event()
		return
	var hit_part := _body_part_at_screen_position(event.position)
	if hit_part != _hovered_part:
		_hovered_part = hit_part
		queue_redraw()


func _draw_part_highlight(part_id: String, fill_color: Color, outline_color: Color) -> void:
	if part_id == "" or repo == null:
		return
	var part := repo.body_part(variant, part_id)
	if part.is_empty():
		return
	var screen_bounds := _actor_rect_to_screen(DollSvgBuilder.body_part_actor_bounds(repo, variant, pose, part))
	if screen_bounds.size.x <= 0.0 or screen_bounds.size.y <= 0.0:
		return
	draw_rect(screen_bounds, fill_color, true)
	draw_rect(screen_bounds, outline_color, false, 2.0)


func _draw_pivots() -> void:
	var font := get_theme_default_font()
	var font_size := maxi(10, get_theme_default_font_size() - 2)
	for part_id in _pivot_ids():
		var actor_position := PoseKinematicsScript.pivot_for(repo, variant, part_id)
		var screen_position := _actor_to_screen(actor_position)
		var is_selected := part_id == selected_part
		var fill := Color(1.0, 0.58, 0.12, 1.0) if is_selected else Color(1.0, 0.86, 0.34, 0.95)
		draw_circle(screen_position, PIVOT_RADIUS + (2.0 if is_selected else 0.0), fill)
		draw_arc(screen_position, PIVOT_RADIUS + (2.0 if is_selected else 0.0), 0.0, TAU, 18, Color(0.08, 0.09, 0.10, 0.95), 1.5)
		var label_position := screen_position + Vector2(8.0, -7.0)
		draw_string(font, label_position + Vector2(1.0, 1.0), part_id, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.02, 0.03, 0.04, 0.88))
		draw_string(font, label_position, part_id, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 1.0, 1.0, 0.95))


func _body_part_at_screen_position(screen_position: Vector2) -> String:
	var actor_position := _screen_to_actor(screen_position, false)
	if actor_position.x < 0.0 or actor_position.y < 0.0 or actor_position.x > ACTOR_SIZE.x or actor_position.y > ACTOR_SIZE.y:
		return ""
	return _body_part_at_actor_position(actor_position)


func _body_part_at_actor_position(actor_position: Vector2) -> String:
	var parts_by_layer := _body_parts_by_layer()
	for layer_offset in range(DollSvgBuilder.LAYER_ORDER.size()):
		var layer_id = DollSvgBuilder.LAYER_ORDER[DollSvgBuilder.LAYER_ORDER.size() - 1 - layer_offset]
		var parts: Array = parts_by_layer.get(layer_id, [])
		for part_offset in range(parts.size()):
			var part: Dictionary = parts[parts.size() - 1 - part_offset]
			if DollSvgBuilder.body_part_actor_bounds(repo, variant, pose, part).has_point(actor_position):
				return String(part.get("id", ""))
	return ""


func _body_parts_by_layer() -> Dictionary:
	var parts_by_layer := {}
	for layer_id in DollSvgBuilder.LAYER_ORDER:
		parts_by_layer[layer_id] = []
	if repo == null:
		return parts_by_layer
	for part in repo.body_parts_for_variant(variant):
		if not part is Dictionary:
			continue
		var layer_id := String(part.get("layer", "body"))
		if not parts_by_layer.has(layer_id):
			layer_id = "body"
		parts_by_layer[layer_id].append(part)
	return parts_by_layer


func _pivot_ids() -> Array[String]:
	var ids: Array[String] = []
	if repo == null:
		return ids
	for part in repo.body_parts_for_variant(variant):
		var part_id := String(part.get("id", ""))
		if part_id != "" and not ids.has(part_id):
			ids.append(part_id)
	for base_id in DollSvgBuilder.BASE_PIVOTS.keys():
		var part_id := String(base_id)
		if part_id != "" and not ids.has(part_id):
			ids.append(part_id)
	return ids


func _available_rect() -> Rect2:
	var padding := 16.0
	return Rect2(Vector2(padding, padding), Vector2(maxf(1.0, size.x - padding * 2.0), maxf(1.0, size.y - padding * 2.0)))


func _fit_actor_rect() -> Rect2:
	var available := _available_rect()
	var aspect := ACTOR_SIZE.x / ACTOR_SIZE.y
	var rect_size := available.size
	if rect_size.x / maxf(1.0, rect_size.y) > aspect:
		rect_size.x = rect_size.y * aspect
	else:
		rect_size.y = rect_size.x / aspect
	return Rect2(available.position + (available.size - rect_size) * 0.5, rect_size)


func _actor_rect() -> Rect2:
	var fit_rect := _fit_actor_rect()
	var rect_size := fit_rect.size * zoom
	return Rect2(fit_rect.get_center() + pan - rect_size * 0.5, rect_size)


func _actor_to_screen(actor_position: Vector2) -> Vector2:
	var rect := _actor_rect()
	return rect.position + Vector2(actor_position.x / ACTOR_SIZE.x * rect.size.x, actor_position.y / ACTOR_SIZE.y * rect.size.y)


func _screen_to_actor(screen_position: Vector2, clamp_to_actor := true) -> Vector2:
	var rect := _actor_rect()
	var u := (screen_position.x - rect.position.x) / maxf(1.0, rect.size.x)
	var v := (screen_position.y - rect.position.y) / maxf(1.0, rect.size.y)
	if clamp_to_actor:
		u = clampf(u, 0.0, 1.0)
		v = clampf(v, 0.0, 1.0)
	return Vector2(u * ACTOR_SIZE.x, v * ACTOR_SIZE.y)


func _actor_rect_to_screen(actor_bounds: Rect2) -> Rect2:
	var top_left := _actor_to_screen(actor_bounds.position)
	var bottom_right := _actor_to_screen(actor_bounds.position + actor_bounds.size)
	var min_point := Vector2(minf(top_left.x, bottom_right.x), minf(top_left.y, bottom_right.y))
	var max_point := Vector2(maxf(top_left.x, bottom_right.x), maxf(top_left.y, bottom_right.y))
	return Rect2(min_point, max_point - min_point)
