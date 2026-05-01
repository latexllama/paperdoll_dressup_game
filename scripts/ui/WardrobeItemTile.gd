class_name WardrobeItemTile
extends Button

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
	return data is Dictionary and String(data.get("kind", "")) == "equipped_item"


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary:
		equipped_item_returned.emit(String(data.get("item_id", "")))


func _make_drag_preview() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(132, 132)
	var texture := TextureRect.new()
	texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.texture = _icon.texture
	panel.add_child(texture)
	return panel
