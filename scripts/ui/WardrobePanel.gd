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
	var active_drag_item_id = _hidden_drag_item_id
	_available_items = items.duplicate(true)
	if active_drag_item_id != "" and _contains_available_item(active_drag_item_id):
		_hidden_drag_item_id = active_drag_item_id
	else:
		_hidden_drag_item_id = ""
	_refresh_items()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var item_id = String(data.get("item_id", ""))
	return String(data.get("kind", "")) == "equipped_item" and item_id != "" and repo != null and repo.has_wardrobe_item(item_id)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(_at_position, data):
		equipped_item_returned.emit(String(data.get("item_id", "")))


func is_active_wardrobe_drag(item_id: String = "") -> bool:
	if _hidden_drag_item_id == "":
		return false
	return item_id == "" or _hidden_drag_item_id == item_id


func finish_active_wardrobe_drag(item_id: String) -> void:
	if _hidden_drag_item_id == item_id:
		_hidden_drag_item_id = ""


func cancel_active_wardrobe_drag(item_id: String = "") -> void:
	if _hidden_drag_item_id == "":
		return
	if item_id != "" and _hidden_drag_item_id != item_id:
		return
	var cancelled_item_id = _hidden_drag_item_id
	_hidden_drag_item_id = ""
	_refresh_items()
	wardrobe_drag_cancelled.emit(cancelled_item_id)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _hidden_drag_item_id != "":
		if not get_viewport().gui_is_drag_successful():
			cancel_active_wardrobe_drag()


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
		_empty_label.text = "No wardrobe items available." if _active_slot == "all" else "No wardrobe items in %s." % _slot_label(_active_slot).to_lower()


func _on_category_pressed(slot: String, button: Button) -> void:
	_active_slot = slot
	for child in _category_bar.get_children():
		if child is Button:
			child.button_pressed = child == button
	_refresh_items()


func _on_tile_drag_started(item_id: String) -> void:
	if item_id == "" or not _contains_available_item(item_id):
		return
	_hidden_drag_item_id = item_id
	_refresh_items()
	wardrobe_drag_started.emit(item_id)


func _on_tile_drag_cancelled(item_id: String) -> void:
	cancel_active_wardrobe_drag(item_id)


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
		"hairAccessory":
			return "Hair"
		"faceAccessory":
			return "Face"
		"earAccessory":
			return "Ears"
		"horns":
			return "Horns"
		"tail":
			return "Tail"
	return slot.capitalize()


func _contains_available_item(item_id: String) -> bool:
	for item in _available_items:
		if String(item.get("id", "")) == item_id:
			return true
	return false
