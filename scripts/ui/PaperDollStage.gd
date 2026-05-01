class_name PaperDollStage
extends PanelContainer

const ItemDragPreviewScript := preload("res://scripts/ui/ItemDragPreview.gd")

signal doll_drop_requested(data: Dictionary)
signal equipped_drag_started(item_id: String)
signal equipped_drag_cancelled(item_id: String)

var repo: ContentRepository
var outfit: Variant
var texture_cache: Variant

var _pending_drag_item_id := ""
var _pose_override: Dictionary = {}

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


func set_pose_override(pose: Dictionary) -> void:
	_pose_override = pose.duplicate(true)
	refresh()


func refresh() -> void:
	if not is_inside_tree() or repo == null or outfit == null or texture_cache == null:
		return
	var available = _doll_texture.size
	if available.x <= 0.0 or available.y <= 0.0:
		available = size
	var render_scale = minf(available.x / DollSvgBuilder.ACTOR_WIDTH, available.y / DollSvgBuilder.ACTOR_HEIGHT)
	var options := {}
	if not _pose_override.is_empty():
		options["poseOverride"] = _pose_override
	var svg = DollSvgBuilder.build_svg(repo, outfit, options)
	_doll_texture.texture = texture_cache.texture_from_svg(svg, render_scale)
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
	var options := {}
	if not _pose_override.is_empty():
		options["poseOverride"] = _pose_override
	var item_id = DollSvgBuilder.top_visible_equipped_item_id_at(repo, outfit, actor_position["position"], options)
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
	var render_scale = minf(texture_size.x / DollSvgBuilder.ACTOR_WIDTH, texture_size.y / DollSvgBuilder.ACTOR_HEIGHT)
	if render_scale <= 0.0:
		return {"ok": false}
	var rendered_size = Vector2(DollSvgBuilder.ACTOR_WIDTH, DollSvgBuilder.ACTOR_HEIGHT) * render_scale
	var rendered_origin = (texture_size - rendered_size) * 0.5
	var rendered_rect := Rect2(rendered_origin, rendered_size)
	if not rendered_rect.has_point(texture_local):
		return {"ok": false}
	return {
		"ok": true,
		"position": (texture_local - rendered_origin) / render_scale,
	}


func _make_drag_preview(item_id: String) -> Control:
	var item = repo.wardrobe_item(item_id) if repo != null else {}
	var texture: Texture2D = null
	if texture_cache != null and not item.is_empty():
		texture = texture_cache.texture_from_svg(DollSvgBuilder.build_item_icon_svg(repo, item), 1.0)
	return ItemDragPreviewScript.make(texture, String(item.get("name", item_id)))
