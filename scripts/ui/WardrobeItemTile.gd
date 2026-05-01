class_name WardrobeItemTile
extends Button

const ItemDragPreviewScript := preload("res://scripts/ui/ItemDragPreview.gd")

signal wardrobe_drag_started(item_id: String)
signal wardrobe_drag_cancelled(item_id: String)
signal equipped_item_returned(item_id: String)

var item: Dictionary = {}
var repo: ContentRepository
var texture_cache: Variant
var _pending_drag := false

@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel


func configure(next_repo: ContentRepository, next_texture_cache: Variant, next_item: Dictionary) -> void:
	repo = next_repo
	texture_cache = next_texture_cache
	item = next_item
	text = ""
	tooltip_text = "%s\n%s" % [String(item.get("name", item.get("id", ""))), String(item.get("slot", ""))]
	_name_label.text = String(item.get("name", item.get("id", "")))
	if texture_cache != null:
		var svg = DollSvgBuilder.build_item_icon_svg(repo, item)
		_icon.texture = texture_cache.texture_from_svg(svg, 1.0)


func item_id() -> String:
	return String(item.get("id", ""))


func _get_drag_data(_at_position: Vector2) -> Variant:
	if item_id() == "":
		return null
	_pending_drag = true
	visible = false
	wardrobe_drag_started.emit(item_id())
	set_drag_preview(_make_drag_preview())
	return {"kind": "wardrobe_item", "item_id": item_id()}


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _pending_drag:
		if not get_viewport().gui_is_drag_successful():
			visible = true
			wardrobe_drag_cancelled.emit(item_id())
		_pending_drag = false


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var dropped_item_id = String(data.get("item_id", ""))
	return String(data.get("kind", "")) == "equipped_item" and dropped_item_id != "" and repo != null and repo.has_wardrobe_item(dropped_item_id)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary:
		equipped_item_returned.emit(String(data.get("item_id", "")))


func _make_drag_preview() -> Control:
	return ItemDragPreviewScript.make(_icon.texture, String(item.get("name", item_id())))
