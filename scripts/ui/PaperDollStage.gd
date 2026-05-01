class_name PaperDollStage
extends PanelContainer

signal doll_drop_requested(data: Dictionary)
signal equipped_drag_started(item_id: String)
signal equipped_drag_cancelled(item_id: String)

const DRAG_PREVIEW_SIZE := Vector2(132.0, 132.0)
const DRAG_PREVIEW_ICON_RECT := Rect2(10.0, 10.0, 112.0, 88.0)
const DRAG_PREVIEW_LABEL_RECT := Rect2(8.0, 100.0, 116.0, 24.0)

var repo: ContentRepository
var outfit: Variant
var texture_cache: Variant

var _pending_drag_item_id := ""

@onready var _doll_texture: TextureRect = %DollTexture
@onready var _hint_label: Label = %StageHint


func configure(next_repo: ContentRepository, next_outfit: Variant, next_texture_cache: Variant) -> void:
	repo = next_repo
	outfit = next_outfit
	texture_cache = next_texture_cache
	call_deferred("refresh")


func set_outfit(next_outfit: Variant) -> void:
	outfit = next_outfit
	refresh()


func refresh() -> void:
	if not is_inside_tree() or repo == null or outfit == null or texture_cache == null:
		return
	var available = _doll_texture.size
	if available.x <= 0.0 or available.y <= 0.0:
		available = size
	var scale = minf(available.x / DollSvgBuilder.ACTOR_WIDTH, available.y / DollSvgBuilder.ACTOR_HEIGHT)
	var svg = DollSvgBuilder.build_svg(repo, outfit)
	_doll_texture.texture = texture_cache.texture_from_svg(svg, scale)
	_hint_label.visible = outfit.equipped_item_ids.is_empty()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		refresh()
	elif what == NOTIFICATION_DRAG_END and _pending_drag_item_id != "":
		if not get_viewport().gui_is_drag_successful():
			equipped_drag_cancelled.emit(_pending_drag_item_id)
		_pending_drag_item_id = ""


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var kind = String(data.get("kind", ""))
	var item_id = String(data.get("item_id", ""))
	if item_id == "" or repo == null or not repo.has_wardrobe_item(item_id):
		return false
	match kind:
		"wardrobe_item":
			return outfit != null and not outfit.equipped_item_ids.has(item_id)
		"equipped_item":
			return _pending_drag_item_id != "" and _pending_drag_item_id == item_id
	return false


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(_at_position, data):
		doll_drop_requested.emit(data)


func _get_drag_data(at_position: Vector2) -> Variant:
	if repo == null or outfit == null or outfit.equipped_item_ids.is_empty() or not _point_inside_stage(at_position):
		return null
	var actor_position = _actor_position_from_stage_position(at_position)
	if not bool(actor_position.get("ok", false)):
		return null
	var item_id = DollSvgBuilder.top_visible_equipped_item_id_at(repo, outfit, actor_position["position"])
	if item_id == "":
		return null
	_pending_drag_item_id = item_id
	equipped_drag_started.emit(item_id)
	set_drag_preview(_make_drag_preview(item_id))
	return {"kind": "equipped_item", "item_id": item_id}


func _point_inside_stage(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(point)


func _actor_position_from_stage_position(point: Vector2) -> Dictionary:
	if _doll_texture == null:
		return {"ok": false}
	var global_point = get_global_transform_with_canvas() * point
	var texture_local: Vector2 = _doll_texture.get_global_transform_with_canvas().affine_inverse() * global_point
	var texture_size = _doll_texture.size
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return {"ok": false}
	var scale = minf(texture_size.x / DollSvgBuilder.ACTOR_WIDTH, texture_size.y / DollSvgBuilder.ACTOR_HEIGHT)
	if scale <= 0.0:
		return {"ok": false}
	var rendered_size = Vector2(DollSvgBuilder.ACTOR_WIDTH, DollSvgBuilder.ACTOR_HEIGHT) * scale
	var rendered_origin = (texture_size - rendered_size) * 0.5
	var rendered_rect := Rect2(rendered_origin, rendered_size)
	if not rendered_rect.has_point(texture_local):
		return {"ok": false}
	return {
		"ok": true,
		"position": (texture_local - rendered_origin) / scale,
	}


func _make_drag_preview(item_id: String) -> Control:
	var root := Control.new()
	root.custom_minimum_size = DRAG_PREVIEW_SIZE
	root.size = DRAG_PREVIEW_SIZE
	root.clip_contents = true
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.custom_minimum_size = DRAG_PREVIEW_SIZE
	panel.size = DRAG_PREVIEW_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texture := TextureRect.new()
	texture.position = DRAG_PREVIEW_ICON_RECT.position
	texture.size = DRAG_PREVIEW_ICON_RECT.size
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var item = repo.wardrobe_item(item_id) if repo != null else {}
	if texture_cache != null and not item.is_empty():
		texture.texture = texture_cache.texture_from_svg(DollSvgBuilder.build_item_icon_svg(repo, item), 1.0)
	var label := Label.new()
	label.position = DRAG_PREVIEW_LABEL_RECT.position
	label.size = DRAG_PREVIEW_LABEL_RECT.size
	label.text = String(item.get("name", item_id))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	root.add_child(texture)
	root.add_child(label)
	return root
