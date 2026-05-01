class_name LatticeCanvas
extends Control

signal point_moved(index: int, point: Dictionary)

var variation: Dictionary = {}
var source_markup := ""
var texture_cache: Variant

var _drag_index := -1
var _source_texture: Texture2D


func configure(next_variation: Dictionary, next_source_markup: String, next_texture_cache: Variant) -> void:
	variation = next_variation
	source_markup = next_source_markup
	texture_cache = next_texture_cache
	_source_texture = _build_source_texture()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if variation.is_empty():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_index = _nearest_point(event.position)
			if _drag_index >= 0:
				accept_event()
		else:
			_drag_index = -1
			accept_event()
	elif event is InputEventMouseMotion and _drag_index >= 0:
		var point = _screen_to_lattice(event.position)
		variation["points"][_drag_index] = point
		point_moved.emit(_drag_index, point)
		queue_redraw()
		accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.92, 0.96, 0.93, 1.0), true)
	if variation.is_empty() or not variation.has("bounds"):
		return
	var draw_rect_area = _canvas_rect()
	if _source_texture != null:
		draw_texture_rect(_source_texture, draw_rect_area, false, Color(1, 1, 1, 0.78))
	_draw_grid()
	_draw_points()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw_grid() -> void:
	var points: Array = variation.get("points", [])
	var rows = int(variation.get("rows", 0))
	var columns = int(variation.get("columns", 0))
	if rows <= 0 or columns <= 0 or points.size() != rows * columns:
		return
	for row in range(rows):
		for column in range(columns - 1):
			draw_line(_lattice_to_screen(points[row * columns + column]), _lattice_to_screen(points[row * columns + column + 1]), Color(0.14, 0.28, 0.42, 0.55), 2.0)
	for column in range(columns):
		for row in range(rows - 1):
			draw_line(_lattice_to_screen(points[row * columns + column]), _lattice_to_screen(points[(row + 1) * columns + column]), Color(0.14, 0.28, 0.42, 0.55), 2.0)


func _draw_points() -> void:
	var points: Array = variation.get("points", [])
	for index in range(points.size()):
		var screen = _lattice_to_screen(points[index])
		var fill = Color(1.0, 0.57, 0.12, 1.0) if index == _drag_index else Color(1.0, 0.75, 0.28, 1.0)
		draw_circle(screen, 7.0, fill)
		draw_arc(screen, 7.0, 0.0, TAU, 24, Color(0.08, 0.09, 0.1, 1.0), 2.0)


func _nearest_point(screen_position: Vector2) -> int:
	var points: Array = variation.get("points", [])
	var best_index := -1
	var best_distance := 18.0
	for index in range(points.size()):
		var distance = screen_position.distance_to(_lattice_to_screen(points[index]))
		if distance < best_distance:
			best_distance = distance
			best_index = index
	return best_index


func _canvas_rect() -> Rect2:
	var bounds: Dictionary = variation.get("bounds", {"width": 1.0, "height": 1.0})
	var padding := 22.0
	var available = Rect2(Vector2(padding, padding), Vector2(maxf(1.0, size.x - padding * 2.0), maxf(1.0, size.y - padding * 2.0)))
	var aspect = float(bounds.get("width", 1.0)) / maxf(1.0, float(bounds.get("height", 1.0)))
	var rect_size = available.size
	if rect_size.x / maxf(1.0, rect_size.y) > aspect:
		rect_size.x = rect_size.y * aspect
	else:
		rect_size.y = rect_size.x / maxf(0.01, aspect)
	return Rect2(available.position + (available.size - rect_size) * 0.5, rect_size)


func _lattice_to_screen(point: Dictionary) -> Vector2:
	var bounds: Dictionary = variation.get("bounds", {"x": 0.0, "y": 0.0, "width": 1.0, "height": 1.0})
	var rect = _canvas_rect()
	var u = (float(point.get("x", 0.0)) - float(bounds.get("x", 0.0))) / maxf(1.0, float(bounds.get("width", 1.0)))
	var v = (float(point.get("y", 0.0)) - float(bounds.get("y", 0.0))) / maxf(1.0, float(bounds.get("height", 1.0)))
	return rect.position + Vector2(u * rect.size.x, v * rect.size.y)


func _screen_to_lattice(screen_position: Vector2) -> Dictionary:
	var bounds: Dictionary = variation.get("bounds", {"x": 0.0, "y": 0.0, "width": 1.0, "height": 1.0})
	var rect = _canvas_rect()
	var u = clampf((screen_position.x - rect.position.x) / maxf(1.0, rect.size.x), 0.0, 1.0)
	var v = clampf((screen_position.y - rect.position.y) / maxf(1.0, rect.size.y), 0.0, 1.0)
	return {
		"x": float(bounds.get("x", 0.0)) + u * float(bounds.get("width", 1.0)),
		"y": float(bounds.get("y", 0.0)) + v * float(bounds.get("height", 1.0)),
	}


func _build_source_texture() -> Texture2D:
	if texture_cache == null or source_markup == "":
		return null
	var bounds: Dictionary = variation.get("bounds", {"x": -100.0, "y": -100.0, "width": 200.0, "height": 200.0})
	var svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"%s %s %s %s\">%s</svg>" % [
		bounds.get("x", -100.0),
		bounds.get("y", -100.0),
		bounds.get("width", 200.0),
		bounds.get("height", 200.0),
		source_markup,
	]
	return texture_cache.texture_from_svg(svg, 1.0)
