class_name WardrobePanel
extends PanelContainer

signal wardrobe_drag_started(item_id: String)
signal wardrobe_drag_cancelled(item_id: String)
signal equipped_item_returned(item_id: String)

@export var tile_scene: PackedScene

var repo: ContentRepository
var texture_cache: Variant
var _available_items: Array = []
var _active_slot := "all"
var _hidden_drag_item_id := ""

@onready var _category_bar: HBoxContainer = %CategoryBar
@onready var _grid: GridContainer = %ItemGrid
@onready var _empty_label: Label = %EmptyLabel


func configure(next_repo: ContentRepository, next_texture_cache: Variant) -> void:
	repo = next_repo
	texture_cache = next_texture_cache
	_build_categories()
	_refresh_items()


func set_available_items(items: Array) -> void:
	_available_items = items.duplicate(true)
	_hidden_drag_item_id = ""
	_refresh_items()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and String(data.get("kind", "")) == "equipped_item"


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary:
		equipped_item_returned.emit(String(data.get("item_id", "")))


func _build_categories() -> void:
	for child in _category_bar.get_children():
		child.queue_free()
	var slots: Array[String] = ["all"]
	for item in repo.wardrobe:
		var slot = String(item.get("slot", "misc"))
		if not slots.has(slot):
			slots.append(slot)
	for slot in slots:
		var button := Button.new()
		button.text = _slot_label(slot)
		button.toggle_mode = true
		button.button_pressed = slot == _active_slot
		button.custom_minimum_size = Vector2(112, 54)
		button.pressed.connect(_on_category_pressed.bind(slot, button))
		_category_bar.add_child(button)


func _refresh_items() -> void:
	if _grid == null or tile_scene == null:
		return
	for child in _grid.get_children():
		child.queue_free()
	var visible_count := 0
	for item in _available_items:
		var item_slot = String(item.get("slot", "misc"))
		var item_id = String(item.get("id", ""))
		if _active_slot != "all" and item_slot != _active_slot:
			continue
		if item_id == _hidden_drag_item_id:
			continue
		var tile = tile_scene.instantiate()
		_grid.add_child(tile)
		tile.configure(repo, texture_cache, item)
		tile.wardrobe_drag_started.connect(_on_tile_drag_started)
		tile.wardrobe_drag_cancelled.connect(_on_tile_drag_cancelled)
		tile.equipped_item_returned.connect(_on_equipped_item_returned)
		visible_count += 1
	if _empty_label != null:
		_empty_label.visible = visible_count == 0


func _on_category_pressed(slot: String, button: Button) -> void:
	_active_slot = slot
	for child in _category_bar.get_children():
		if child is Button:
			child.button_pressed = child == button
	_refresh_items()


func _on_tile_drag_started(item_id: String) -> void:
	_hidden_drag_item_id = item_id
	wardrobe_drag_started.emit(item_id)


func _on_tile_drag_cancelled(item_id: String) -> void:
	if _hidden_drag_item_id == item_id:
		_hidden_drag_item_id = ""
	_refresh_items()
	wardrobe_drag_cancelled.emit(item_id)


func _on_equipped_item_returned(item_id: String) -> void:
	equipped_item_returned.emit(item_id)


func _slot_label(slot: String) -> String:
	match slot:
		"all":
			return "All"
		"top":
			return "Tops"
		"bottom":
			return "Bottoms"
		"shoes":
			return "Footwear"
		"faceAccessory":
			return "Face"
		"earAccessory":
			return "Accessories"
		"horns":
			return "Horns"
		"tail":
			return "Tail"
	return slot.capitalize()
