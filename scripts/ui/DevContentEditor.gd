class_name DevContentEditor
extends Window

signal content_saved

const OutfitStateScript := preload("res://scripts/game/OutfitState.gd")
const DevEditorDraftScript := preload("res://scripts/ui/DevEditorDraft.gd")
const PoseKinematicsScript := preload("res://scripts/doll/PoseKinematics.gd")
const Models := preload("res://scripts/ui/DevEditorModels.gd")

const SECTION_WARDROBE := "wardrobe"
const SECTION_VISUALS := "equipment_visuals"
const SECTION_ASSETS := "equipment_assets"
const SECTION_BODY_RIG := "body_rig"
const SECTION_POSES := "poses"

const SECTIONS := [
	{"id": SECTION_WARDROBE, "label": "Wardrobe"},
	{"id": SECTION_VISUALS, "label": "Visuals"},
	{"id": SECTION_ASSETS, "label": "SVG Assets"},
	{"id": SECTION_BODY_RIG, "label": "Body Rig"},
	{"id": SECTION_POSES, "label": "Poses"},
]

var repo: ContentRepository
var texture_cache: Variant

var _draft: RefCounted = DevEditorDraftScript.new()
var _section := SECTION_WARDROBE
var _selected_id := ""
var _selected_variant := "female"
var _selected_piece_index := 0
var _selected_svg_variation_id := ""
var _selected_lattice_id := ""
var _selected_pose_part := "body"
var _selected_asset_variant := "female"
var _asset_import_target_id := ""
var _pose_show_pivots := true
var _pose_show_guides := true
var _pose_show_rest_ghost := true
var _pose_position_snap := 1.0

@onready var _section_option: OptionButton = %SectionOption
@onready var _validate_button: Button = %ValidateButton
@onready var _save_all_button: Button = %SaveAllButton
@onready var _revert_button: Button = %RevertDraftButton
@onready var _dirty_label: Label = %DirtyLabel
@onready var _status: Label = %EditorStatus
@onready var _record_list: ItemList = %RecordList
@onready var _add_button: Button = %AddRecordButton
@onready var _duplicate_button: Button = %DuplicateRecordButton
@onready var _delete_button: Button = %DeleteRecordButton
@onready var _form_content: VBoxContainer = %FormContent
@onready var _preview: TextureRect = %PreviewTexture
@onready var _preview_status: Label = %PreviewStatus
@onready var _pose_canvas = %PosePreviewCanvas
@onready var _lattice_canvas: Control = %LatticeCanvas
@onready var _import_dialog: FileDialog = %SvgImportDialog
@onready var _discard_dialog: ConfirmationDialog = %DiscardDraftDialog


func _ready() -> void:
	close_requested.connect(_on_close_requested)
	_setup_section_selector()
	_section_option.item_selected.connect(_on_section_selected)
	_validate_button.pressed.connect(_on_validate_pressed)
	_save_all_button.pressed.connect(_on_save_all_pressed)
	_revert_button.pressed.connect(_on_revert_pressed)
	_record_list.item_selected.connect(_on_record_selected)
	_add_button.pressed.connect(_on_add_pressed)
	_duplicate_button.pressed.connect(_on_duplicate_pressed)
	_delete_button.pressed.connect(_on_delete_pressed)
	_lattice_canvas.point_moved.connect(_on_lattice_point_moved)
	_pose_canvas.part_selected.connect(_on_pose_canvas_part_selected)
	_pose_canvas.ik_chain_changed.connect(_on_pose_canvas_ik_chain_changed)
	_pose_canvas.edit_finished.connect(_on_pose_canvas_edit_finished)
	_pose_canvas.status_changed.connect(_set_status)
	_import_dialog.file_selected.connect(_on_svg_file_selected)
	_discard_dialog.confirmed.connect(_close_and_discard_draft)
	_lattice_canvas.visible = false
	_pose_canvas.visible = false


func _on_close_requested() -> void:
	if _draft.is_dirty():
		_discard_dialog.popup_centered(Vector2i(460, 180))
		return
	hide()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_close_requested()
		get_viewport().set_input_as_handled()


func _close_and_discard_draft() -> void:
	if repo != null:
		_draft.load_from_repository(repo)
	_update_dirty_label()
	hide()


func configure(next_repo: ContentRepository, next_texture_cache: Variant) -> void:
	repo = next_repo
	texture_cache = next_texture_cache
	_draft.load_from_repository(repo)
	if is_inside_tree():
		_refresh_all()


func _setup_section_selector() -> void:
	_section_option.clear()
	for section in SECTIONS:
		_section_option.add_item(String(section["label"]))
		_section_option.set_item_metadata(_section_option.item_count - 1, String(section["id"]))


func _on_section_selected(index: int) -> void:
	_section = String(_section_option.get_item_metadata(index))
	_selected_id = ""
	_selected_piece_index = 0
	_selected_svg_variation_id = ""
	_selected_lattice_id = ""
	_selected_pose_part = "body"
	_refresh_all()


func _refresh_all() -> void:
	_select_option_by_metadata(_section_option, _section)
	_populate_record_list()
	_render_form()
	_update_dirty_label()


func _populate_record_list() -> void:
	_record_list.clear()
	var records = _records_for_section()
	if _section == SECTION_BODY_RIG:
		var variant_parts = _parts_for_selected_variant()
		for part in variant_parts:
			_record_list.add_item("%s  %s" % [String(part.get("id", "")), String(part.get("layer", ""))])
			_record_list.set_item_metadata(_record_list.item_count - 1, String(part.get("id", "")))
	else:
		for record in records:
			_record_list.add_item("%s  %s" % [String(record.get("id", "")), String(record.get("name", ""))])
			_record_list.set_item_metadata(_record_list.item_count - 1, String(record.get("id", "")))
	if _record_list.item_count == 0:
		_selected_id = ""
		return
	var index = _index_for_selected_id()
	if index < 0:
		index = 0
		_selected_id = String(_record_list.get_item_metadata(0))
	_record_list.select(index)


func _index_for_selected_id() -> int:
	for index in range(_record_list.item_count):
		if String(_record_list.get_item_metadata(index)) == _selected_id:
			return index
	return -1


func _on_record_selected(index: int) -> void:
	_selected_id = String(_record_list.get_item_metadata(index))
	_selected_piece_index = 0
	_selected_svg_variation_id = ""
	_selected_lattice_id = ""
	_render_form()


func _on_add_pressed() -> void:
	match _section:
		SECTION_WARDROBE:
			var item = Models.create_wardrobe_item(_draft.wardrobe)
			var visual = Models.create_equipment_visual(String(item["visualId"]), _draft.equipment_visuals)
			var asset_id = _first_asset_id()
			if asset_id != "":
				visual["pieces"].append(_default_visual_piece(asset_id))
				Models.sync_wardrobe_pieces_from_visual(item, visual)
			_draft.equipment_visuals.append(visual)
			_draft.wardrobe.append(item)
			_selected_id = String(item["id"])
		SECTION_VISUALS:
			var visual = Models.create_equipment_visual("", _draft.equipment_visuals)
			var asset_id = _first_asset_id()
			if asset_id != "":
				visual["pieces"].append(_default_visual_piece(asset_id))
			_draft.equipment_visuals.append(visual)
			_selected_id = String(visual["id"])
		SECTION_ASSETS:
			var asset = Models.create_equipment_asset(_draft.equipment_assets)
			_draft.equipment_assets.append(asset)
			_selected_id = String(asset["id"])
		SECTION_BODY_RIG:
			var parts = _parts_for_selected_variant()
			var part = Models.create_body_part(parts)
			parts.append(part)
			_selected_id = String(part["id"])
		SECTION_POSES:
			var pose = Models.create_pose(_draft.poses)
			_draft.poses.append(pose)
			_selected_id = String(pose["id"])
	_after_collection_edit("Added record.")


func _on_duplicate_pressed() -> void:
	var record = _selected_record()
	if record.is_empty():
		_set_status("Select a record to duplicate.")
		return
	match _section:
		SECTION_WARDROBE:
			var item = Models.duplicate_record(record, _draft.wardrobe)
			var visual_id = String(record.get("visualId", ""))
			var visual = Models.record_by_id(_draft.equipment_visuals, visual_id)
			if not visual.is_empty():
				var visual_clone = Models.duplicate_record(visual, _draft.equipment_visuals)
				item["visualId"] = String(visual_clone["id"])
				_draft.equipment_visuals.append(visual_clone)
				Models.sync_wardrobe_pieces_from_visual(item, visual_clone)
			_draft.wardrobe.append(item)
			_selected_id = String(item["id"])
		SECTION_VISUALS:
			var visual_clone = Models.duplicate_record(record, _draft.equipment_visuals)
			_draft.equipment_visuals.append(visual_clone)
			_selected_id = String(visual_clone["id"])
		SECTION_ASSETS:
			var asset_clone = Models.duplicate_record(record, _draft.equipment_assets)
			_draft.equipment_assets.append(asset_clone)
			_selected_id = String(asset_clone["id"])
		SECTION_BODY_RIG:
			var parts = _parts_for_selected_variant()
			var part_clone = Models.duplicate_record(record, parts)
			parts.append(part_clone)
			_selected_id = String(part_clone["id"])
		SECTION_POSES:
			var pose_clone = Models.duplicate_record(record, _draft.poses)
			_draft.poses.append(pose_clone)
			_selected_id = String(pose_clone["id"])
	_after_collection_edit("Duplicated record.")


func _on_delete_pressed() -> void:
	if _selected_id == "":
		_set_status("Select a record to delete.")
		return
	match _section:
		SECTION_WARDROBE:
			_remove_record_by_id(_draft.wardrobe, _selected_id)
		SECTION_VISUALS:
			_remove_record_by_id(_draft.equipment_visuals, _selected_id)
		SECTION_ASSETS:
			_remove_record_by_id(_draft.equipment_assets, _selected_id)
		SECTION_BODY_RIG:
			_remove_record_by_id(_parts_for_selected_variant(), _selected_id)
		SECTION_POSES:
			_remove_record_by_id(_draft.poses, _selected_id)
	_selected_id = ""
	_after_collection_edit("Deleted record.")


func _after_collection_edit(message: String) -> void:
	_populate_record_list()
	_render_form()
	_update_dirty_label()
	_set_status(message)


func _render_form() -> void:
	_clear_children(_form_content)
	_preview.texture = null
	_preview.visible = true
	_preview_status.text = ""
	_lattice_canvas.visible = false
	_pose_canvas.visible = false
	if repo == null:
		_set_status("Content repository is not configured.")
		return
	match _section:
		SECTION_WARDROBE:
			_build_wardrobe_form()
		SECTION_VISUALS:
			_build_visual_form()
		SECTION_ASSETS:
			_build_asset_form()
		SECTION_BODY_RIG:
			_build_body_rig_form()
		SECTION_POSES:
			_build_pose_form()


func _build_wardrobe_form() -> void:
	var item = _selected_record()
	if item.is_empty():
		_add_note("No wardrobe item selected.")
		return
	_add_title("Wardrobe Item")
	_add_line_edit("ID", String(item.get("id", "")), func(value: String) -> void:
		var old_id = String(item.get("id", ""))
		item["id"] = value
		_selected_id = value
		_update_record_list_labels()
		_mark_changed("Updated wardrobe id from %s to %s." % [old_id, value], true)
	)
	_add_line_edit("Name", String(item.get("name", "")), func(value: String) -> void:
		item["name"] = value
		_update_record_list_labels()
		_mark_changed("Updated wardrobe name.")
	)
	_add_option("Slot", String(item.get("slot", "")), Models.WARDROBE_SLOTS, func(value: String) -> void:
		item["slot"] = value
		_mark_changed("Updated wardrobe slot.")
	)
	_add_option("Visual", String(item.get("visualId", "")), _ids_for(_draft.equipment_visuals), func(value: String) -> void:
		item["visualId"] = value
		var visual = Models.record_by_id(_draft.equipment_visuals, value)
		if not visual.is_empty():
			Models.sync_wardrobe_pieces_from_visual(item, visual)
		_mark_changed("Updated wardrobe visual.", true, true)
	)
	_add_text_edit("Description", String(item.get("description", "")), func(value: String) -> void:
		item["description"] = value
		_mark_changed("Updated description.")
	, 84.0)
	_add_color_picker("Base Color", String(item.get("color", "#ffffff")), func(value: String) -> void:
		item["color"] = value
		_mark_changed("Updated base color.")
	)
	_add_optional_color("Accent Color", item, "accentColor")
	var visual = Models.record_by_id(_draft.equipment_visuals, String(item.get("visualId", "")))
	_add_coverage_view(visual)
	_refresh_wardrobe_preview(item)


func _build_visual_form() -> void:
	var visual = _selected_record()
	if visual.is_empty():
		_add_note("No equipment visual selected.")
		return
	_add_title("Equipment Visual")
	_add_line_edit("ID", String(visual.get("id", "")), func(value: String) -> void:
		var old_id = String(visual.get("id", ""))
		visual["id"] = value
		_selected_id = value
		Models.rename_visual_references(_draft.wardrobe, old_id, value)
		_update_record_list_labels()
		_mark_changed("Updated visual id.", true)
	)
	_add_line_edit("Name", String(visual.get("name", "")), func(value: String) -> void:
		visual["name"] = value
		_update_record_list_labels()
		_mark_changed("Updated visual name.")
	)
	_add_option("Slot", String(visual.get("slot", "")), Models.WARDROBE_SLOTS, func(value: String) -> void:
		visual["slot"] = value
		_mark_changed("Updated visual slot.")
	)
	_add_title("Visual Pieces")
	var pieces: Array = visual.get("pieces", []) if visual.get("pieces", []) is Array else []
	var piece_labels: Array[String] = []
	for index in range(pieces.size()):
		var piece = pieces[index]
		piece_labels.append("%d. %s -> %s" % [index + 1, String(piece.get("target", "")), String(piece.get("assetId", ""))])
	if piece_labels.is_empty():
		piece_labels.append("No pieces")
	_selected_piece_index = clampi(_selected_piece_index, 0, maxi(0, pieces.size() - 1))
	_add_option("Selected Piece", piece_labels[_selected_piece_index] if pieces.size() > 0 else "No pieces", piece_labels, func(value: String) -> void:
		_selected_piece_index = maxi(0, piece_labels.find(value))
		_render_form()
	)
	var row = _add_button_row()
	row.add_child(_button("Add Piece", func() -> void:
		var asset_id = _first_asset_id()
		pieces.append(_default_visual_piece(asset_id))
		_selected_piece_index = pieces.size() - 1
		_mark_changed("Added visual piece.", true, true)
	))
	row.add_child(_button("Remove Piece", func() -> void:
		if pieces.size() > 0:
			pieces.remove_at(_selected_piece_index)
			_selected_piece_index = clampi(_selected_piece_index, 0, maxi(0, pieces.size() - 1))
			_mark_changed("Removed visual piece.", true, true)
	))
	if pieces.size() > 0:
		_build_visual_piece_form(pieces[_selected_piece_index])
	_refresh_visual_preview(visual)


func _build_visual_piece_form(piece: Dictionary) -> void:
	var draft_repo = _draft.repository_clone()
	_add_option("Target Rig Part", String(piece.get("target", "body")), Models.all_rig_targets(draft_repo), func(value: String) -> void:
		piece["target"] = value
		_mark_changed("Updated visual piece target.")
	)
	_add_option("Layer", String(piece.get("layer", "front")), ContentValidator.LAYERS, func(value: String) -> void:
		piece["layer"] = value
		_mark_changed("Updated visual piece layer.")
	)
	_add_option("SVG Asset", String(piece.get("assetId", "")), _ids_for(_draft.equipment_assets), func(value: String) -> void:
		piece["assetId"] = value
		_mark_changed("Updated visual piece asset.")
	)
	_add_option("Color Group", String(piece.get("colorGroup", "")), Models.COLOR_GROUPS, func(value: String) -> void:
		_set_optional_string(piece, "colorGroup", value)
		_mark_changed("Updated visual piece color group.")
	)
	_add_check_box("Hide Body Part", bool(piece.get("hideBodyPart", false)), func(value: bool) -> void:
		if value:
			piece["hideBodyPart"] = true
		else:
			piece.erase("hideBodyPart")
		_mark_changed("Updated body-part visibility.")
	)
	if not piece.has("transform"):
		_add_note("No transform is authored for this piece.")
		_add_button_row().add_child(_button("Add Piece Transform", func() -> void:
			piece["transform"] = {}
			_mark_changed("Added visual piece transform.", true, true)
		))
		return
	elif not piece["transform"] is Dictionary:
		_add_note("Piece transform is invalid and must be fixed before editing.")
		return
	_add_transform_editor("Piece Transform", piece["transform"], ["x", "y", "rotate", "scaleX", "scaleY"], {
		"x": [-600.0, 600.0, 1.0],
		"y": [-600.0, 600.0, 1.0],
		"rotate": [-180.0, 180.0, 1.0],
		"scaleX": [0.1, 3.0, 0.05],
		"scaleY": [0.1, 3.0, 0.05],
	})


func _build_asset_form() -> void:
	var asset = _selected_record()
	if asset.is_empty():
		_add_note("No SVG asset selected.")
		return
	_add_title("SVG Asset")
	_add_line_edit("ID", String(asset.get("id", "")), func(value: String) -> void:
		var old_id = String(asset.get("id", ""))
		asset["id"] = value
		_selected_id = value
		Models.rename_asset_references(_draft.equipment_visuals, old_id, value)
		_update_record_list_labels()
		_mark_changed("Updated asset id.", true)
	)
	_add_line_edit("Name", String(asset.get("name", "")), func(value: String) -> void:
		asset["name"] = value
		_update_record_list_labels()
		_mark_changed("Updated asset name.")
	)
	_add_option("Source Type", String(asset.get("source", "custom")), ["custom", "imported", "original", "cta"], func(value: String) -> void:
		asset["source"] = value
		_mark_changed("Updated source type.", true, true)
	)
	_add_check_box("Actor Space", bool(asset.get("actorSpace", false)), func(value: bool) -> void:
		asset["actorSpace"] = value
		_mark_changed("Updated actor-space flag.")
	)
	var row = _add_button_row()
	row.add_child(_button("Import SVG", func() -> void:
		_asset_import_target_id = String(asset.get("id", ""))
		_import_dialog.popup_centered(Vector2i(980, 680))
	))
	row.add_child(_button("Validate SVG", func() -> void:
		var markup = _asset_markup_for_preview(asset)
		var result = _svg_safety_result(markup)
		_set_status("SVG is safe." if result.get("ok", false) else "Unsafe SVG: %s" % "; ".join(result.get("errors", [])))
	))
	if asset.has("variants"):
		_build_asset_variant_form(asset)
	else:
		_add_text_edit("SVG Markup", String(asset.get("svgMarkup", "")), func(value: String) -> void:
			asset["svgMarkup"] = value
			_mark_changed("Updated SVG markup.")
		, 220.0)
	_refresh_asset_preview(asset)


func _build_asset_variant_form(asset: Dictionary) -> void:
	var variants: Dictionary = asset.get("variants", {})
	var variant_ids: Array[String] = []
	for variant in variants.keys():
		variant_ids.append(String(variant))
	if variant_ids.is_empty():
		_add_note("This asset has no variants.")
		return
	if not variant_ids.has(_selected_asset_variant):
		_selected_asset_variant = variant_ids[0]
	_add_option("Asset Variant", _selected_asset_variant, variant_ids, func(value: String) -> void:
		_selected_asset_variant = value
		_render_form()
	)
	var data: Dictionary = variants.get(_selected_asset_variant, {})
	if not data.has("viewBox"):
		_add_note("Selected asset variant is missing a valid viewBox.")
		return
	var view_box: Dictionary = data["viewBox"]
	for key in ["x", "y", "width", "height"]:
		_add_number("ViewBox %s" % key, float(view_box.get(key, 0.0 if key == "x" or key == "y" else 1.0)), -10000.0, 10000.0, 1.0, func(value: float, next_key: String = key) -> void:
			view_box[next_key] = value
			_mark_changed("Updated asset viewBox.")
		)
	_add_text_edit("%s SVG Markup" % _selected_asset_variant.capitalize(), String(data.get("svgMarkup", "")), func(value: String) -> void:
		data["svgMarkup"] = value
		_mark_changed("Updated variant SVG markup.")
	, 220.0)


func _build_body_rig_form() -> void:
	_add_title("Body Rig")
	var variants := _body_variant_ids()
	_add_option("Variant", _selected_variant, variants, func(value: String) -> void:
		_selected_variant = value
		_selected_id = ""
		_refresh_all()
	)
	var part = _selected_record()
	if part.is_empty():
		_add_note("No body part selected.")
		return
	_add_line_edit("Part ID", String(part.get("id", "")), func(value: String) -> void:
		var old_id = String(part.get("id", ""))
		part["id"] = value
		_selected_id = value
		Models.rename_body_part_references(_draft, old_id, value)
		_update_record_list_labels()
		_mark_changed("Updated body part id.", true)
	)
	var parent_options: Array[String] = [""]
	parent_options.append_array(DollSvgBuilder.BASE_PIVOTS.keys())
	for sibling in _parts_for_selected_variant():
		var sibling_id = String(sibling.get("id", ""))
		if sibling_id != String(part.get("id", "")) and not parent_options.has(sibling_id):
			parent_options.append(sibling_id)
	_add_option("Parent", String(part.get("parentId", "")), parent_options, func(value: String) -> void:
		_set_optional_string(part, "parentId", value)
		_mark_changed("Updated parent.")
	)
	_add_option("Layer", String(part.get("layer", "body")), ContentValidator.LAYERS, func(value: String) -> void:
		part["layer"] = value
		_mark_changed("Updated layer.")
	)
	if not part.has("pivot") or not part["pivot"] is Dictionary:
		_add_note("Selected body part is missing a valid pivot.")
		return
	var pivot: Dictionary = part["pivot"]
	_add_number("Pivot X", float(pivot.get("x", 0.0)), -2000.0, 4000.0, 1.0, func(value: float) -> void:
		pivot["x"] = value
		_mark_changed("Updated pivot x.")
	)
	_add_number("Pivot Y", float(pivot.get("y", 0.0)), -2000.0, 5000.0, 1.0, func(value: float) -> void:
		pivot["y"] = value
		_mark_changed("Updated pivot y.")
	)
	_add_text_edit("Base SVG Markup", String(part.get("svgMarkup", "")), func(value: String) -> void:
		part["svgMarkup"] = value
		_mark_changed("Updated body part SVG.", true, true)
	, 160.0)
	_build_body_svg_variations(part)
	_build_lattice_variations(part)
	_refresh_body_preview()


func _build_body_svg_variations(part: Dictionary) -> void:
	if not part.has("variations") or not part["variations"] is Dictionary:
		_add_note("Selected body part is missing a valid SVG variations map.")
		return
	var variations: Dictionary = part["variations"]
	_add_title("SVG Variations")
	var ids: Array[String] = [""]
	for id in variations.keys():
		ids.append(String(id))
	if not ids.has(_selected_svg_variation_id):
		_selected_svg_variation_id = ""
	_add_option("Variation", _selected_svg_variation_id, ids, func(value: String) -> void:
		_selected_svg_variation_id = value
		_render_form()
	)
	var row = _add_button_row()
	row.add_child(_button("Add SVG Variation", func() -> void:
		var next_id = Models.unique_id("customVariation", Models._variation_id_records(part))
		variations[next_id] = String(part.get("svgMarkup", ""))
		_selected_svg_variation_id = next_id
		_mark_changed("Added SVG variation.", true, true)
	))
	row.add_child(_button("Remove SVG Variation", func() -> void:
		if _selected_svg_variation_id != "":
			variations.erase(_selected_svg_variation_id)
			_selected_svg_variation_id = ""
			_mark_changed("Removed SVG variation.", true, true)
	))
	if _selected_svg_variation_id != "":
		_add_line_edit("Variation ID", _selected_svg_variation_id, func(value: String) -> void:
			if value == "" or value == _selected_svg_variation_id:
				return
			var markup = variations[_selected_svg_variation_id]
			variations.erase(_selected_svg_variation_id)
			variations[value] = markup
			_selected_svg_variation_id = value
			_mark_changed("Renamed SVG variation.", true, true)
		)
		_add_text_edit("Variation SVG Markup", String(variations.get(_selected_svg_variation_id, "")), func(value: String) -> void:
			variations[_selected_svg_variation_id] = value
			_mark_changed("Updated SVG variation.")
		, 130.0)


func _build_lattice_variations(part: Dictionary) -> void:
	if not part.has("latticeVariations") or not part["latticeVariations"] is Dictionary:
		_add_note("Selected body part is missing a valid lattice variations map.")
		return
	var lattice_map: Dictionary = part["latticeVariations"]
	_add_title("Lattice Variations")
	var ids: Array[String] = [""]
	for id in lattice_map.keys():
		ids.append(String(id))
	if not ids.has(_selected_lattice_id):
		_selected_lattice_id = ""
	_add_option("Lattice Variation", _selected_lattice_id, ids, func(value: String) -> void:
		_selected_lattice_id = value
		_render_form()
	)
	var row = _add_button_row()
	row.add_child(_button("Create Lattice", func() -> void:
		var variation = Models.create_lattice_variation(part)
		var variation_id = String(variation.get("id", Models.unique_id("customLattice", Models._variation_id_records(part))))
		variation.erase("id")
		lattice_map[variation_id] = variation
		_selected_lattice_id = variation_id
		_mark_changed("Created lattice variation.", true, true)
	))
	row.add_child(_button("Delete Lattice", func() -> void:
		if _selected_lattice_id != "":
			lattice_map.erase(_selected_lattice_id)
			_selected_lattice_id = ""
			_mark_changed("Deleted lattice variation.", true, true)
	))
	if _selected_lattice_id == "":
		return
	var variation: Dictionary = lattice_map[_selected_lattice_id]
	_add_line_edit("Lattice ID", _selected_lattice_id, func(value: String) -> void:
		if value == "" or value == _selected_lattice_id:
			return
		var copy = lattice_map[_selected_lattice_id]
		lattice_map.erase(_selected_lattice_id)
		lattice_map[value] = copy
		_selected_lattice_id = value
		_mark_changed("Renamed lattice variation.", true, true)
	)
	_add_option("Source Variation", String(variation.get("sourceVariationId", "")), _variation_source_ids(part), func(value: String) -> void:
		_set_optional_string(variation, "sourceVariationId", value)
		_mark_changed("Updated lattice source.", true, true)
	)
	_add_number("Rows", float(variation.get("rows", 3)), Lattice.MIN_DIVISIONS, Lattice.MAX_DIVISIONS, 1.0, func(value: float) -> void:
		lattice_map[_selected_lattice_id] = Models.resize_lattice_variation(variation, int(value), int(variation.get("columns", 3)))
		_mark_changed("Updated lattice rows.", true, true)
	)
	_add_number("Columns", float(variation.get("columns", 3)), Lattice.MIN_DIVISIONS, Lattice.MAX_DIVISIONS, 1.0, func(value: float) -> void:
		lattice_map[_selected_lattice_id] = Models.resize_lattice_variation(variation, int(variation.get("rows", 3)), int(value))
		_mark_changed("Updated lattice columns.", true, true)
	)
	if not variation.has("bounds") or not variation["bounds"] is Dictionary:
		_add_note("Selected lattice variation is missing valid bounds.")
		return
	var bounds: Dictionary = variation["bounds"]
	for key in ["x", "y", "width", "height"]:
		_add_number("Bounds %s" % key, float(bounds.get(key, 0.0 if key == "x" or key == "y" else 1.0)), -10000.0, 10000.0, 1.0, func(value: float, next_key: String = key) -> void:
			bounds[next_key] = maxf(1.0, value) if next_key == "width" or next_key == "height" else value
			Models.reset_lattice_points(variation)
			_mark_changed("Updated lattice bounds.", true, true)
		)
	var tool_row = _add_button_row()
	tool_row.add_child(_button("Reset Points", func() -> void:
		Models.reset_lattice_points(variation)
		_mark_changed("Reset lattice points.", true, true)
	))
	tool_row.add_child(_button("Fit Bounds From SVG", func() -> void:
		variation["bounds"] = Models.bounds_for_markup(Models.source_markup_for_lattice(part, variation))
		Models.reset_lattice_points(variation)
		_mark_changed("Fit lattice bounds.", true, true)
	))
	_lattice_canvas.visible = true
	_lattice_canvas.configure(variation, Models.source_markup_for_lattice(part, variation), texture_cache)


func _build_pose_form() -> void:
	var pose = _selected_record()
	if pose.is_empty():
		_add_note("No pose selected.")
		return
	_add_title("Pose")
	_add_line_edit("ID", String(pose.get("id", "")), func(value: String) -> void:
		pose["id"] = value
		_selected_id = value
		_update_record_list_labels()
		_mark_changed("Updated pose id.", true)
	)
	_add_line_edit("Name", String(pose.get("name", "")), func(value: String) -> void:
		pose["name"] = value
		_update_record_list_labels()
		_mark_changed("Updated pose name.")
	)
	if not pose.has("parts") or not pose["parts"] is Dictionary:
		_add_note("Selected pose is missing a valid parts map.")
		return
	if not pose.has("sprites") or not pose["sprites"] is Dictionary:
		_add_note("Selected pose is missing a valid sprites map.")
		return
	var draft_repo = _draft.repository_clone()
	var targets = Models.all_rig_targets(draft_repo)
	if not targets.has(_selected_pose_part):
		_selected_pose_part = targets[0] if targets.size() > 0 else "body"
	_add_option("Part", _selected_pose_part, targets, func(value: String) -> void:
		_selected_pose_part = value
		_render_form()
	)
	_build_pose_canvas_tools(pose)
	var parts: Dictionary = pose["parts"]
	if not parts.has(_selected_pose_part):
		_add_note("No transform is authored for this part.")
		_add_button_row().add_child(_button("Add Part Transform", func() -> void:
			parts[_selected_pose_part] = {"rotate": 0.0, "x": 0.0, "y": 0.0, "scaleX": 1.0, "scaleY": 1.0, "bend": 0.0}
			_mark_changed("Added part transform.", true, true)
		))
		_add_title("Sprite Overrides")
		_build_sprite_override_controls(pose)
		_refresh_pose_preview(pose)
		return
	var transform: Dictionary = parts[_selected_pose_part]
	_add_transform_editor("Part Transform", transform, ["rotate", "x", "y", "scaleX", "scaleY", "bend"], {
		"rotate": [-180.0, 180.0, 1.0],
		"x": [-900.0, 900.0, 1.0],
		"y": [-900.0, 900.0, 1.0],
		"scaleX": [0.1, 3.0, 0.05],
		"scaleY": [0.1, 3.0, 0.05],
		"bend": [-180.0, 180.0, 1.0],
	})
	_add_button_row().add_child(_button("Remove Part Transform", func() -> void:
		parts.erase(_selected_pose_part)
		_mark_changed("Removed part transform.", true, true)
	))
	_add_title("Sprite Overrides")
	_build_sprite_override_controls(pose)
	_refresh_pose_preview(pose)


func _build_pose_canvas_tools(pose: Dictionary) -> void:
	_add_title("Interactive Preview")
	var toggle_row = _add_row()
	var pivots := CheckBox.new()
	pivots.text = "Pivots"
	pivots.button_pressed = _pose_show_pivots
	toggle_row.add_child(pivots)
	pivots.toggled.connect(func(value: bool) -> void:
		_pose_show_pivots = value
		_refresh_pose_preview(pose)
	)
	var guides := CheckBox.new()
	guides.text = "Guides"
	guides.button_pressed = _pose_show_guides
	toggle_row.add_child(guides)
	guides.toggled.connect(func(value: bool) -> void:
		_pose_show_guides = value
		_refresh_pose_preview(pose)
	)
	var ghost := CheckBox.new()
	ghost.text = "Rest ghost"
	ghost.button_pressed = _pose_show_rest_ghost
	toggle_row.add_child(ghost)
	ghost.toggled.connect(func(value: bool) -> void:
		_pose_show_rest_ghost = value
		_refresh_pose_preview(pose)
	)
	_add_number("Drag Snap", _pose_position_snap, 1.0, 100.0, 1.0, func(value: float) -> void:
		_pose_position_snap = value
		_refresh_pose_preview(pose)
	, true)
	var action_row = _add_button_row()
	action_row.add_child(_button("Reset Selected Part", func() -> void:
		if pose.get("parts", {}).has(_selected_pose_part):
			pose["parts"].erase(_selected_pose_part)
			_mark_changed("Reset selected pose part.", true, true)
		else:
			_set_status("Selected part has no authored transform.")
	))
	action_row.add_child(_button("Reset Full Pose", func() -> void:
		pose["parts"] = {}
		_mark_changed("Reset pose transforms.", true, true)
	))
	action_row.add_child(_button("Mirror Selected Left/Right", func() -> void:
		if _mirror_selected_pose_part(pose):
			_mark_changed("Mirrored selected pose part.", true, true)
		else:
			_set_status("Select a left/right part with an authored transform to mirror.")
	))


func _build_sprite_override_controls(pose: Dictionary) -> void:
	var sprites: Dictionary = pose["sprites"]
	_add_option("Left Hand", String(sprites.get("leftHand", "")), Models.HAND_SPRITES, func(value: String) -> void:
		_set_optional_string(sprites, "leftHand", value)
		_mark_changed("Updated left hand sprite.")
	)
	_add_option("Right Hand", String(sprites.get("rightHand", "")), Models.HAND_SPRITES, func(value: String) -> void:
		_set_optional_string(sprites, "rightHand", value)
		_mark_changed("Updated right hand sprite.")
	)
	_add_option("Left Foot", String(sprites.get("leftFoot", "")), Models.FOOT_SPRITES, func(value: String) -> void:
		_set_optional_string(sprites, "leftFoot", value)
		_mark_changed("Updated left foot sprite.")
	)
	_add_option("Right Foot", String(sprites.get("rightFoot", "")), Models.FOOT_SPRITES, func(value: String) -> void:
		_set_optional_string(sprites, "rightFoot", value)
		_mark_changed("Updated right foot sprite.")
	)
	for part in _parts_for_selected_variant():
		var variation_ids = Models.variation_ids_for_part(part)
		if variation_ids.size() > 1:
			var part_id = String(part.get("id", ""))
			_add_option("%s Variation" % part_id, String(sprites.get(part_id, "")), variation_ids, func(value: String, next_id: String = part_id) -> void:
				_set_optional_string(sprites, next_id, value)
				_mark_changed("Updated sprite override.")
			)


func _add_transform_editor(title: String, transform: Dictionary, keys: Array, ranges: Dictionary) -> void:
	_add_title(title)
	for key in keys:
		var range: Array = ranges.get(key, [-100.0, 100.0, 1.0])
		var default_value = 1.0 if String(key).begins_with("scale") else 0.0
		_add_number(String(key).capitalize(), float(transform.get(key, default_value)), float(range[0]), float(range[1]), float(range[2]), func(value: float, next_key: String = String(key), next_default: float = default_value) -> void:
			if is_equal_approx(value, next_default):
				transform.erase(next_key)
			else:
				transform[next_key] = value
			_mark_changed("Updated transform.")
		, true)


func _add_coverage_view(visual: Dictionary) -> void:
	_add_title("Coverage From Visual")
	if visual.is_empty():
		_add_note("No visual assigned.")
		return
	for piece in visual.get("pieces", []):
		_add_note("%s (%s)" % [String(piece.get("target", "")), String(piece.get("colorGroup", ""))])


func _refresh_wardrobe_preview(item: Dictionary) -> void:
	if texture_cache == null:
		return
	_preview.visible = true
	_pose_canvas.visible = false
	var draft_repo = _draft.repository_clone()
	var outfit = OutfitStateScript.new(draft_repo.starting_outfit_snapshot())
	outfit.equipped_item_ids.clear()
	outfit.equipped_item_ids.append(String(item.get("id", "")))
	_preview.texture = texture_cache.texture_from_svg(DollSvgBuilder.build_svg(draft_repo, outfit), 0.18)
	_preview_status.text = "Previewing selected wardrobe item on the doll."


func _refresh_visual_preview(visual: Dictionary) -> void:
	if texture_cache == null:
		return
	_preview.visible = true
	_pose_canvas.visible = false
	var draft_repo = _draft.repository_clone()
	var preview_item := {
		"id": "__preview_visual__",
		"name": "Preview Visual",
		"slot": visual.get("slot", "top"),
		"visualId": visual.get("id", ""),
		"color": "#d9d2c3",
		"accentColor": "#63728a",
	}
	draft_repo.wardrobe.append(preview_item)
	draft_repo.set_collection("wardrobe", draft_repo.wardrobe)
	var outfit = OutfitStateScript.new(draft_repo.starting_outfit_snapshot())
	outfit.equipped_item_ids.clear()
	outfit.equipped_item_ids.append("__preview_visual__")
	_preview.texture = texture_cache.texture_from_svg(DollSvgBuilder.build_svg(draft_repo, outfit), 0.18)
	_preview_status.text = "Previewing selected visual on the doll."


func _refresh_asset_preview(asset: Dictionary) -> void:
	if texture_cache == null:
		return
	_preview.visible = true
	_pose_canvas.visible = false
	var markup = _asset_markup_for_preview(asset)
	var safety = _svg_safety_result(markup)
	if not safety.get("ok", false):
		_preview_status.text = "Unsafe SVG: %s" % "; ".join(safety.get("errors", []))
		_preview.texture = null
		return
	var bounds = Models.bounds_for_markup(markup)
	var svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"%s %s %s %s\"><rect width=\"100%%\" height=\"100%%\" fill=\"#f8f2e8\"/>%s</svg>" % [
		bounds.get("x", -100.0),
		bounds.get("y", -100.0),
		bounds.get("width", 200.0),
		bounds.get("height", 200.0),
		markup,
	]
	_preview.texture = texture_cache.texture_from_svg(svg, 1.0)
	_preview_status.text = "SVG asset preview."


func _refresh_body_preview() -> void:
	if texture_cache == null:
		return
	_preview.visible = true
	_pose_canvas.visible = false
	var draft_repo = _draft.repository_clone()
	var outfit = OutfitStateScript.new(draft_repo.starting_outfit_snapshot())
	outfit.variant = _selected_variant
	_preview.texture = texture_cache.texture_from_svg(DollSvgBuilder.build_svg(draft_repo, outfit, {"showPivots": true}), 0.18)
	_preview_status.text = "Body rig preview with pivots."


func _refresh_pose_preview(pose: Dictionary) -> void:
	if texture_cache == null:
		return
	_preview.texture = null
	_preview.visible = false
	_pose_canvas.visible = true
	var draft_repo = _draft.repository_clone()
	var outfit = OutfitStateScript.new(draft_repo.starting_outfit_snapshot())
	outfit.variant = _selected_variant
	outfit.pose_id = String(pose.get("id", outfit.pose_id))
	var texture = texture_cache.texture_from_svg(DollSvgBuilder.build_svg(draft_repo, outfit), 0.18)
	_pose_canvas.configure(draft_repo, pose, outfit.variant, _selected_pose_part, texture, {
		"show_pivots": _pose_show_pivots,
		"show_guides": _pose_show_guides,
		"show_rest_ghost": _pose_show_rest_ghost,
		"position_snap": _pose_position_snap,
	})
	_preview_status.text = "Pose preview: click handles to select parts; drag hands or feet for IK posing."


func _on_validate_pressed() -> void:
	var result = _draft.validate()
	_report_result("Content is valid.", result)


func _on_save_all_pressed() -> void:
	if repo == null:
		_set_status("Content repository is not configured.")
		return
	var result = _draft.save_all(repo)
	_report_result("Saved all content.", result)
	if result.get("ok", false):
		content_saved.emit()
		_draft.load_from_repository(repo)
		_refresh_all()


func _on_revert_pressed() -> void:
	if repo == null:
		return
	_draft.load_from_repository(repo)
	_selected_id = ""
	_selected_piece_index = 0
	_selected_lattice_id = ""
	_selected_svg_variation_id = ""
	_refresh_all()
	_set_status("Reverted draft changes.")


func _on_svg_file_selected(path: String) -> void:
	var asset = Models.record_by_id(_draft.equipment_assets, _asset_import_target_id)
	if asset.is_empty():
		_set_status("Import target asset no longer exists.")
		return
	var markup = FileAccess.get_file_as_string(path)
	var result = _svg_safety_result(markup)
	if not result.get("ok", false):
		_set_status("Import blocked: %s" % "; ".join(result.get("errors", [])))
		return
	asset["source"] = "imported"
	asset.erase("variants")
	asset["svgMarkup"] = markup
	_selected_id = _asset_import_target_id
	_mark_changed("Imported SVG asset.", true, true)


func _on_lattice_point_moved(_index: int, _point: Dictionary) -> void:
	_mark_changed("Moved lattice point.", false, false)


func _on_pose_canvas_part_selected(part_id: String) -> void:
	if _section != SECTION_POSES:
		return
	_selected_pose_part = part_id
	_render_form()


func _on_pose_canvas_ik_chain_changed(_side: String, transform_patches: Dictionary) -> void:
	var pose = _selected_record()
	if pose.is_empty():
		return
	for part_id in transform_patches.keys():
		_set_pose_part_transform(pose, String(part_id), transform_patches[part_id])
	_mark_changed("Updated arm IK.", false, false)


func _on_pose_canvas_edit_finished() -> void:
	if _section == SECTION_POSES:
		_render_form()


func _report_result(success_message: String, result: Dictionary) -> void:
	if result.get("ok", false):
		_set_status(success_message)
	else:
		_set_status("Validation blocked: %s" % "; ".join(result.get("errors", [])))
	_update_dirty_label()


func _mark_changed(message: String, rebuild_list := false, rebuild_form := false, refresh_preview := true) -> void:
	if rebuild_list:
		_populate_record_list()
	if rebuild_form:
		_render_form()
	elif refresh_preview:
		_refresh_current_preview_only()
	_update_dirty_label()
	_set_status(message)


func _refresh_current_preview_only() -> void:
	match _section:
		SECTION_WARDROBE:
			_refresh_wardrobe_preview(_selected_record())
		SECTION_VISUALS:
			_refresh_visual_preview(_selected_record())
		SECTION_ASSETS:
			_refresh_asset_preview(_selected_record())
		SECTION_BODY_RIG:
			_refresh_body_preview()
		SECTION_POSES:
			_refresh_pose_preview(_selected_record())


func _update_dirty_label() -> void:
	_dirty_label.text = "Unsaved changes" if _draft.is_dirty() else "Clean"
	_save_all_button.disabled = not _draft.is_dirty()


func _set_status(message: String) -> void:
	_status.text = message


func _records_for_section() -> Array:
	match _section:
		SECTION_WARDROBE:
			return _draft.wardrobe
		SECTION_VISUALS:
			return _draft.equipment_visuals
		SECTION_ASSETS:
			return _draft.equipment_assets
		SECTION_POSES:
			return _draft.poses
	return []


func _selected_record() -> Dictionary:
	if _section == SECTION_BODY_RIG:
		return Models.record_by_id(_parts_for_selected_variant(), _selected_id)
	return Models.record_by_id(_records_for_section(), _selected_id)


func _parts_for_selected_variant() -> Array:
	if not _draft.body_rig.has(_selected_variant):
		return []
	return _draft.body_rig[_selected_variant].get("parts", [])


func _body_variant_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _draft.body_rig.keys():
		ids.append(String(id))
	if ids.is_empty():
		ids = ["female", "male"]
	if not ids.has(_selected_variant):
		_selected_variant = ids[0]
	return ids


func _remove_record_by_id(records: Array, id: String) -> void:
	var index = Models.record_index_by_id(records, id)
	if index >= 0:
		records.remove_at(index)


func _update_record_list_labels() -> void:
	_populate_record_list()


func _ids_for(records: Array) -> Array[String]:
	var ids: Array[String] = []
	for record in records:
		ids.append(String(record.get("id", "")))
	return ids


func _variation_source_ids(part: Dictionary) -> Array[String]:
	var ids: Array[String] = [""]
	for id in part.get("variations", {}).keys():
		ids.append(String(id))
	return ids


func _first_asset_id() -> String:
	return String(_draft.equipment_assets[0].get("id", "")) if _draft.equipment_assets.size() > 0 else ""


func _default_visual_piece(asset_id: String) -> Dictionary:
	return {
		"target": "torso",
		"layer": "front",
		"assetId": asset_id,
		"colorGroup": "Clothing.Top.Base",
		"transform": {},
	}


func _asset_markup_for_preview(asset: Dictionary) -> String:
	if asset.has("variants"):
		var variants: Dictionary = asset.get("variants", {})
		var variant_data: Dictionary = variants.get(_selected_asset_variant, variants.values()[0] if variants.size() > 0 else {})
		return String(variant_data.get("svgMarkup", ""))
	return String(asset.get("svgMarkup", ""))


func _set_optional_string(owner: Dictionary, key: String, value: String) -> void:
	if value.strip_edges() == "":
		owner.erase(key)
	else:
		owner[key] = value


func _set_pose_part_transform(pose: Dictionary, part_id: String, transform: Dictionary) -> void:
	if not pose.has("parts") or not (pose["parts"] is Dictionary):
		return
	var cleaned = PoseKinematicsScript.cleaned_transform(transform)
	if cleaned.is_empty():
		pose["parts"].erase(part_id)
	else:
		pose["parts"][part_id] = cleaned


func _mirror_selected_pose_part(pose: Dictionary) -> bool:
	if not pose.has("parts") or not (pose["parts"] is Dictionary):
		return false
	var counterpart = _counterpart_part_id(_selected_pose_part)
	if counterpart == "" or not pose["parts"].has(_selected_pose_part):
		return false
	var transform = PoseKinematicsScript.transform_for(pose, _selected_pose_part)
	transform["x"] = -float(transform.get("x", 0.0))
	transform["rotate"] = -float(transform.get("rotate", 0.0))
	transform["bend"] = -float(transform.get("bend", 0.0))
	pose["parts"][counterpart] = PoseKinematicsScript.cleaned_transform(transform)
	_selected_pose_part = counterpart
	return true


func _counterpart_part_id(part_id: String) -> String:
	if part_id.begins_with("left"):
		return "right%s" % part_id.substr(4)
	if part_id.begins_with("right"):
		return "left%s" % part_id.substr(5)
	return ""


func _svg_safety_result(markup: String) -> Dictionary:
	if SvgSafety.is_safe_markup(markup):
		return {"ok": true, "errors": []}
	return {"ok": false, "errors": [SvgSafety.first_error(markup)]}


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _add_title(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.12, 0.13, 0.14))
	_form_content.add_child(label)


func _add_note(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form_content.add_child(label)


func _add_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	_form_content.add_child(row)
	return row


func _add_button_row() -> HBoxContainer:
	return _add_row()


func _add_field(label_text: String, control: Control) -> void:
	var row = _add_row()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 170.0
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)


func _add_line_edit(label: String, value: String, on_change: Callable, readonly := false) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = value
	edit.editable = not readonly
	edit.text_changed.connect(func(next_value: String) -> void:
		on_change.call(next_value)
	)
	_add_field(label, edit)
	return edit


func _add_text_edit(label: String, value: String, on_change: Callable, height := 120.0) -> TextEdit:
	var edit := TextEdit.new()
	edit.text = value
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.custom_minimum_size.y = height
	edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(func() -> void:
		on_change.call(edit.text)
	)
	_add_field(label, edit)
	return edit


func _add_option(label: String, value: String, options: Array, on_change: Callable) -> OptionButton:
	var option = _option_control(value, options, on_change)
	_add_field(label, option)
	return option


func _option_control(value: String, options: Array, on_change: Callable) -> OptionButton:
	var option := OptionButton.new()
	var normalized: Array[String] = []
	for raw in options:
		normalized.append(String(raw))
	if normalized.is_empty():
		normalized.append("")
	for entry in normalized:
		option.add_item(_option_label(entry))
		option.set_item_metadata(option.item_count - 1, entry)
	_select_option_by_metadata(option, value)
	option.item_selected.connect(func(index: int) -> void:
		on_change.call(String(option.get_item_metadata(index)))
	)
	return option


func _select_option_by_metadata(option: OptionButton, value: String) -> void:
	for index in range(option.item_count):
		if String(option.get_item_metadata(index)) == value:
			option.select(index)
			return
	if option.item_count > 0:
		option.select(0)


func _option_label(value: String) -> String:
	return "None" if value == "" else value


func _add_check_box(label: String, value: bool, on_change: Callable) -> CheckBox:
	var check := CheckBox.new()
	check.text = label
	check.button_pressed = value
	check.toggled.connect(func(next_value: bool) -> void:
		on_change.call(next_value)
	)
	_form_content.add_child(check)
	return check


func _add_color_picker(label: String, value: String, on_change: Callable) -> ColorPickerButton:
	var picker := ColorPickerButton.new()
	picker.color = Color.html(value)
	picker.color_changed.connect(func(color: Color) -> void:
		on_change.call("#%02x%02x%02x" % [
			clampi(int(round(color.r * 255.0)), 0, 255),
			clampi(int(round(color.g * 255.0)), 0, 255),
			clampi(int(round(color.b * 255.0)), 0, 255),
		])
	)
	_add_field(label, picker)
	return picker


func _add_optional_color(label: String, owner: Dictionary, key: String) -> void:
	var row = _add_row()
	var check := CheckBox.new()
	check.text = label
	check.button_pressed = owner.has(key)
	row.add_child(check)
	var picker := ColorPickerButton.new()
	picker.color = Color.html(String(owner.get(key, "#ffffff")))
	picker.disabled = not owner.has(key)
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(picker)
	check.toggled.connect(func(value: bool) -> void:
		picker.disabled = not value
		if value:
			owner[key] = "#ffffff" if not owner.has(key) else owner[key]
		else:
			owner.erase(key)
		_mark_changed("Updated optional color.", true, true)
	)
	picker.color_changed.connect(func(color: Color) -> void:
		owner[key] = "#%02x%02x%02x" % [
			clampi(int(round(color.r * 255.0)), 0, 255),
			clampi(int(round(color.g * 255.0)), 0, 255),
			clampi(int(round(color.b * 255.0)), 0, 255),
		]
		_mark_changed("Updated optional color.")
	)


func _add_number(label: String, value: float, min_value: float, max_value: float, step: float, on_change: Callable, slider := false) -> void:
	var row = _add_row()
	var label_node := Label.new()
	label_node.text = label
	label_node.custom_minimum_size.x = 170.0
	label_node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label_node)
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.value = clampf(value, min_value, max_value)
	spin.custom_minimum_size.x = 120.0
	row.add_child(spin)
	if slider:
		var range := HSlider.new()
		range.min_value = min_value
		range.max_value = max_value
		range.step = step
		range.value = spin.value
		range.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(range)
		var sync := {"active": false}
		spin.value_changed.connect(func(next_value: float) -> void:
			if bool(sync["active"]):
				return
			sync["active"] = true
			if not is_equal_approx(range.value, next_value):
				range.value = next_value
			sync["active"] = false
			on_change.call(next_value)
		)
		range.value_changed.connect(func(next_value: float) -> void:
			if bool(sync["active"]):
				return
			sync["active"] = true
			if not is_equal_approx(spin.value, next_value):
				spin.value = next_value
			sync["active"] = false
			on_change.call(next_value)
		)
	else:
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.value_changed.connect(func(next_value: float) -> void:
			on_change.call(next_value)
		)


func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(func() -> void:
		on_pressed.call()
	)
	return button

