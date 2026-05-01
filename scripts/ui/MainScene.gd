class_name MainScene
extends Control

const OutfitStateScript := preload("res://scripts/game/OutfitState.gd")
const OutfitHistoryScript := preload("res://scripts/game/OutfitHistory.gd")
const OutfitPersistenceScript := preload("res://scripts/game/OutfitPersistence.gd")
const SvgTextureCacheScript := preload("res://scripts/doll/SvgTextureCache.gd")

var _repo := ContentRepository.new()
var _texture_cache = SvgTextureCacheScript.new()
var _history = OutfitHistoryScript.new()
var _outfit = OutfitStateScript.new()
var _pending_doll_drag_snapshot: Dictionary = {}
var _pending_doll_drag_item_id := ""

@onready var _stage = %PaperDollStage
@onready var _wardrobe_panel = %WardrobePanel
@onready var _status_label: Label = %StatusLabel
@onready var _undo_button: Button = %UndoButton
@onready var _redo_button: Button = %RedoButton
@onready var _save_dialog: AcceptDialog = %SaveDialog
@onready var _save_name_edit: LineEdit = %SaveNameEdit
@onready var _load_dialog: AcceptDialog = %LoadDialog
@onready var _outfit_list: ItemList = %OutfitList
@onready var _settings_dialog: AcceptDialog = %SettingsDialog
@onready var _variant_option: OptionButton = %VariantOption
@onready var _pose_option: OptionButton = %PoseOption
@onready var _skin_picker: ColorPickerButton = %SkinPicker
@onready var _hair_picker: ColorPickerButton = %HairPicker
@onready var _eye_picker: ColorPickerButton = %EyePicker
@onready var _dev_editor = %DevContentEditor


func _ready() -> void:
	var validation = _repo.load_all()
	if not validation.get("ok", false):
		_set_status("Content validation failed: %s" % "; ".join(validation.get("errors", [])))
	_outfit = OutfitStateScript.new(_repo.starting_outfit_snapshot())
	_history.clear()
	_stage.configure(_repo, _outfit, _texture_cache)
	_wardrobe_panel.configure(_repo, _texture_cache)
	_dev_editor.configure(_repo, _texture_cache)
	_connect_signals()
	_populate_settings_options()
	_refresh_all()


func _connect_signals() -> void:
	_stage.doll_drop_requested.connect(_on_doll_drop_requested)
	_stage.equipped_drag_started.connect(_on_equipped_drag_started)
	_stage.equipped_drag_cancelled.connect(_on_equipped_drag_cancelled)
	_wardrobe_panel.equipped_item_returned.connect(_on_equipped_item_returned)
	_undo_button.pressed.connect(_on_undo_pressed)
	_redo_button.pressed.connect(_on_redo_pressed)
	%SaveButton.pressed.connect(_on_save_pressed)
	%LoadButton.pressed.connect(_on_load_pressed)
	%SettingsButton.pressed.connect(_on_settings_pressed)
	%DevEditorButton.pressed.connect(_on_dev_editor_pressed)
	%ResetButton.pressed.connect(_on_reset_pressed)
	_save_dialog.confirmed.connect(_on_save_confirmed)
	_load_dialog.confirmed.connect(_on_load_confirmed)
	_settings_dialog.confirmed.connect(_on_settings_confirmed)
	_dev_editor.content_saved.connect(_on_dev_content_saved)


func _refresh_all() -> void:
	_stage.set_outfit(_outfit)
	_wardrobe_panel.set_available_items(_repo.wardrobe_available_for(_outfit.equipped_item_ids))
	_undo_button.disabled = not _history.can_undo()
	_redo_button.disabled = not _history.can_redo()
	_set_status("Equipped: %d" % _outfit.equipped_item_ids.size())


func _on_doll_drop_requested(data: Dictionary) -> void:
	var kind = String(data.get("kind", ""))
	var item_id = String(data.get("item_id", ""))
	if item_id == "":
		return
	if kind == "wardrobe_item":
		_history.remember(_outfit.to_dictionary())
		_outfit.equip_item(item_id)
		_refresh_all()
	elif kind == "equipped_item":
		_outfit.equip_item(item_id)
		_clear_pending_doll_drag()
		_refresh_all()


func _on_equipped_drag_started(item_id: String) -> void:
	_pending_doll_drag_snapshot = _outfit.to_dictionary()
	_pending_doll_drag_item_id = item_id
	_outfit.remove_last_item(item_id)
	_stage.set_outfit(_outfit)


func _on_equipped_drag_cancelled(_item_id: String) -> void:
	if not _pending_doll_drag_snapshot.is_empty():
		_outfit = OutfitStateScript.new(_pending_doll_drag_snapshot)
		_clear_pending_doll_drag()
		_refresh_all()


func _on_equipped_item_returned(item_id: String) -> void:
	if item_id == "":
		return
	if not _pending_doll_drag_snapshot.is_empty():
		_history.remember(_pending_doll_drag_snapshot)
	else:
		_history.remember(_outfit.to_dictionary())
		_outfit.remove_last_item(item_id)
	_clear_pending_doll_drag()
	_refresh_all()


func _on_undo_pressed() -> void:
	var snapshot = _history.undo(_outfit.to_dictionary())
	if snapshot.is_empty():
		return
	_outfit = OutfitStateScript.new(snapshot)
	_refresh_all()


func _on_redo_pressed() -> void:
	var snapshot = _history.redo(_outfit.to_dictionary())
	if snapshot.is_empty():
		return
	_outfit = OutfitStateScript.new(snapshot)
	_refresh_all()


func _on_save_pressed() -> void:
	_save_name_edit.text = "default"
	_save_dialog.popup_centered(Vector2i(420, 160))


func _on_save_confirmed() -> void:
	var result = OutfitPersistenceScript.save_outfit(_save_name_edit.text, _outfit)
	if result.get("ok", false):
		_set_status("Saved outfit: %s" % result.get("name", ""))
	else:
		_set_status("Save failed: %s" % "; ".join(result.get("errors", [])))


func _on_load_pressed() -> void:
	_outfit_list.clear()
	for outfit_name in OutfitPersistenceScript.list_outfits():
		_outfit_list.add_item(outfit_name)
	if _outfit_list.item_count > 0:
		_outfit_list.select(0)
	_load_dialog.popup_centered(Vector2i(440, 360))


func _on_load_confirmed() -> void:
	var selected = _outfit_list.get_selected_items()
	if selected.is_empty():
		_set_status("No outfit selected.")
		return
	var outfit_name = _outfit_list.get_item_text(selected[0])
	var result = OutfitPersistenceScript.load_outfit(outfit_name)
	if not result.get("ok", false):
		_set_status("Load failed: %s" % "; ".join(result.get("errors", [])))
		return
	_history.remember(_outfit.to_dictionary())
	_outfit = result["outfit"]
	_refresh_all()
	_set_status("Loaded outfit: %s" % outfit_name)


func _on_settings_pressed() -> void:
	_select_option_by_text(_variant_option, _outfit.variant)
	_select_option_by_text(_pose_option, _outfit.pose_id)
	_skin_picker.color = Color.html(_outfit.skin_tone)
	_hair_picker.color = Color.html(_outfit.hair_color)
	_eye_picker.color = Color.html(_outfit.eye_color)
	_settings_dialog.popup_centered(Vector2i(520, 360))


func _on_settings_confirmed() -> void:
	_history.remember(_outfit.to_dictionary())
	_outfit.variant = _variant_option.get_item_text(_variant_option.selected)
	_outfit.pose_id = _pose_option.get_item_text(_pose_option.selected)
	_outfit.skin_tone = "#%s" % _skin_picker.color.to_html(false)
	_outfit.skin_line = DollSvgBuilder._adjust_color(_outfit.skin_tone, -48)
	_outfit.hair_color = "#%s" % _hair_picker.color.to_html(false)
	_outfit.eye_color = "#%s" % _eye_picker.color.to_html(false)
	_refresh_all()


func _on_dev_editor_pressed() -> void:
	_dev_editor.popup_centered(Vector2i(1260, 820))


func _on_dev_content_saved() -> void:
	var validation = _repo.reload_after_external_save()
	if not validation.get("ok", false):
		_set_status("Reloaded content with errors: %s" % "; ".join(validation.get("errors", [])))
	else:
		_texture_cache.clear()
		_populate_settings_options()
		_refresh_all()
		_set_status("Content saved and reloaded.")


func _on_reset_pressed() -> void:
	_history.remember(_outfit.to_dictionary())
	_outfit = OutfitStateScript.new(_repo.starting_outfit_snapshot())
	_refresh_all()


func _populate_settings_options() -> void:
	_variant_option.clear()
	for variant in _repo.body_rig.keys():
		_variant_option.add_item(String(variant))
	_pose_option.clear()
	for pose in _repo.poses:
		_pose_option.add_item(String(pose.get("id", "")))


func _select_option_by_text(option: OptionButton, value: String) -> void:
	for index in range(option.item_count):
		if option.get_item_text(index) == value:
			option.select(index)
			return
	if option.item_count > 0:
		option.select(0)


func _clear_pending_doll_drag() -> void:
	_pending_doll_drag_snapshot = {}
	_pending_doll_drag_item_id = ""


func _set_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message
