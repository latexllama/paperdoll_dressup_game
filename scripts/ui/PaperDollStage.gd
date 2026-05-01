class_name PaperDollStage
extends PanelContainer

signal doll_drop_requested(data: Dictionary)
signal equipped_drag_started(item_id: String)
signal equipped_drag_cancelled(item_id: String)

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
	return data is Dictionary and ["wardrobe_item", "equipped_item"].has(String(data.get("kind", "")))


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary:
		doll_drop_requested.emit(data)


func _get_drag_data(at_position: Vector2) -> Variant:
	if outfit == null or outfit.equipped_item_ids.is_empty() or not _point_inside_stage(at_position):
		return null
	var item_id = outfit.top_visible_item_id()
	if item_id == "":
		return null
	_pending_drag_item_id = item_id
	equipped_drag_started.emit(item_id)
	set_drag_preview(_make_drag_preview(item_id))
	return {"kind": "equipped_item", "item_id": item_id}


func _point_inside_stage(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(point)


func _make_drag_preview(item_id: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 48)
	var label := Label.new()
	label.text = item_id
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel
