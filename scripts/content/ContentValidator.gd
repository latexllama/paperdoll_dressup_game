class_name ContentValidator
extends RefCounted

const LAYERS := ["back", "upperLimbs", "body", "legs", "head", "frontLimbs", "front"]
const WARDROBE_SLOTS := ["top", "bottom", "shoes", "hairAccessory", "faceAccessory", "earAccessory", "horns", "tail"]
const COLOR_PATTERN := "^#[0-9a-fA-F]{6}$"
const WARDROBE_KEYS := ["id", "name", "slot", "description", "visualId", "color", "accentColor", "pieces"]
const WARDROBE_PIECE_KEYS := ["target", "colorGroup"]
const VISUAL_KEYS := ["id", "name", "slot", "pieces"]
const VISUAL_PIECE_KEYS := ["target", "layer", "assetId", "colorGroup", "hideBodyPart", "transform"]
const TRANSFORM_KEYS := ["x", "y", "rotate", "scaleX", "scaleY"]
const POSE_TRANSFORM_KEYS := ["rotate", "x", "y", "scaleX", "scaleY", "bend"]
const ASSET_KEYS := ["id", "name", "source", "actorSpace", "svgMarkup", "variants"]
const ASSET_VARIANT_KEYS := ["viewBox", "svgMarkup"]
const BODY_VARIANT_KEYS := ["parts"]
const BODY_PART_KEYS := ["id", "layer", "parentId", "pivot", "svgMarkup", "variations", "latticeVariations"]
const POSE_KEYS := ["id", "name", "parts", "sprites"]
const STARTING_OUTFIT_KEYS := ["id", "name", "variant", "poseId", "skinTone", "skinLine", "hairColor", "eyeColor", "equippedItemIds"]
const HAND_SPRITES := ["", "relaxed", "open", "fist", "point"]
const FOOT_SPRITES := ["", "front", "inward", "outward"]
const OBSOLETE_WARDROBE_KEYS := [
	"modifiers",
	"requiredSkillLevels",
	"setId",
	"styleTags",
	"styleRatings",
	"price",
	"hiddenUntilOwned",
]


static func validate_repository(repo: ContentRepository) -> Dictionary:
	var errors: Array[String] = []
	errors.append_array(_validate_unique_ids(repo.wardrobe, "wardrobe"))
	errors.append_array(_validate_unique_ids(repo.equipment_visuals, "equipment_visuals"))
	errors.append_array(_validate_unique_ids(repo.equipment_assets, "equipment_assets"))
	errors.append_array(_validate_unique_ids(repo.poses, "poses"))
	errors.append_array(_validate_body_rig(repo.body_rig))
	errors.append_array(_validate_equipment_assets(repo.equipment_assets))
	errors.append_array(_validate_equipment_visuals(repo.equipment_visuals, repo))
	errors.append_array(_validate_wardrobe(repo.wardrobe, repo))
	errors.append_array(_validate_poses(repo.poses, repo))
	errors.append_array(_validate_starting_outfit(repo.starting_outfit, repo, "Starting outfit"))
	return {"ok": errors.is_empty(), "errors": errors}


static func validate_collection(repo: ContentRepository, collection_name: String, value: Variant) -> Dictionary:
	var clone = ContentRepository.new()
	clone.body_rig = repo.body_rig.duplicate(true)
	clone.equipment_assets = repo.equipment_assets.duplicate(true)
	clone.equipment_visuals = repo.equipment_visuals.duplicate(true)
	clone.wardrobe = repo.wardrobe.duplicate(true)
	clone.poses = repo.poses.duplicate(true)
	clone.sample_meta = repo.sample_meta.duplicate(true)
	clone.starting_outfit = repo.starting_outfit.duplicate(true)
	clone.set_collection(collection_name, value)
	return validate_repository(clone)


static func validate_outfit_data(repo: ContentRepository, data: Dictionary, label := "Outfit") -> Dictionary:
	var errors = _validate_starting_outfit(data, repo, label)
	return {"ok": errors.is_empty(), "errors": errors}


static func _validate_unique_ids(records: Array, label: String) -> Array[String]:
	var errors: Array[String] = []
	var seen := {}
	for index in range(records.size()):
		var record = records[index]
		if not (record is Dictionary):
			errors.append("%s record %d must be an object" % [label, index])
			continue
		var id = String(record.get("id", ""))
		if id == "":
			errors.append("%s contains a record with a missing id" % label)
		elif seen.has(id):
			errors.append("%s contains duplicate id \"%s\"" % [label, id])
		else:
			seen[id] = true
	return errors


static func _validate_body_rig(body_rig: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for required_variant in ["female", "male"]:
		if not body_rig.has(required_variant):
			errors.append("Body rig is missing required variant \"%s\"" % required_variant)
	for variant in body_rig.keys():
		var variant_data = body_rig[variant]
		if not (variant_data is Dictionary):
			errors.append("Body rig variant \"%s\" must be an object" % String(variant))
			continue
		errors.append_array(_unknown_keys(variant_data, BODY_VARIANT_KEYS, "Body rig variant \"%s\"" % String(variant)))
		var parts_value = variant_data.get("parts", [])
		if not (parts_value is Array):
			errors.append("Body rig variant \"%s\" parts must be an array" % String(variant))
			continue
		var parts: Array = parts_value
		var ids := {}
		for index in range(parts.size()):
			var part = parts[index]
			if not (part is Dictionary):
				errors.append("%s body rig part %d must be an object" % [String(variant), index])
				continue
			var id = String(part.get("id", ""))
			if id == "":
				errors.append("%s body rig contains a part with a missing id" % String(variant))
			elif ids.has(id):
				errors.append("%s body rig contains duplicate part id \"%s\"" % [String(variant), id])
			else:
				ids[id] = true
		for part in parts:
			if not (part is Dictionary):
				continue
			var label = "%s body part \"%s\"" % [variant, String(part.get("id", ""))]
			errors.append_array(_unknown_keys(part, BODY_PART_KEYS, label))
			errors.append_array(_require_string_fields(part, ["id", "layer", "svgMarkup"], label))
			errors.append_array(_optional_string_fields(part, ["parentId"], label))
			var layer = String(part.get("layer", ""))
			if not LAYERS.has(layer):
				errors.append("%s has invalid layer \"%s\"" % [label, layer])
			var parent_id = String(part.get("parentId", ""))
			if parent_id != "" and not ids.has(parent_id) and not DollSvgBuilder.BASE_PIVOTS.has(parent_id):
				errors.append("%s references missing parent \"%s\"" % [label, parent_id])
			var pivot = part.get("pivot", {})
			if not (pivot is Dictionary) or not _finite_number(pivot.get("x")) or not _finite_number(pivot.get("y")):
				errors.append("%s must have finite pivot x/y values" % label)
			if not SvgSafety.is_safe_markup(String(part.get("svgMarkup", ""))):
				errors.append("%s contains unsafe SVG markup" % label)
			if not (part.get("variations", {}) is Dictionary):
				errors.append("%s variations must be an object" % label)
				continue
			var variation_ids := {}
			for variation_id in part.get("variations", {}).keys():
				var variation_key := String(variation_id)
				if variation_key == "":
					errors.append("%s contains a variation with an empty id" % label)
				variation_ids[variation_key] = true
				if not (part["variations"][variation_id] is String):
					errors.append("%s variation \"%s\" must be SVG markup text" % [label, variation_id])
				elif not SvgSafety.is_safe_markup(String(part["variations"][variation_id])):
					errors.append("%s variation \"%s\" contains unsafe SVG markup" % [label, variation_id])
			if not (part.get("latticeVariations", {}) is Dictionary):
				errors.append("%s latticeVariations must be an object" % label)
				continue
			for lattice_id in part.get("latticeVariations", {}).keys():
				var lattice_key := String(lattice_id)
				if lattice_key == "":
					errors.append("%s contains a lattice variation with an empty id" % label)
				if variation_ids.has(lattice_key):
					errors.append("%s uses variation id \"%s\" for both SVG and lattice variations" % [label, lattice_key])
				if not (part["latticeVariations"][lattice_id] is Dictionary):
					errors.append("%s lattice variation \"%s\" must be an object" % [label, lattice_id])
					continue
				var source_variation_id := String(part["latticeVariations"][lattice_id].get("sourceVariationId", ""))
				if source_variation_id != "" and not variation_ids.has(source_variation_id):
					errors.append("%s lattice variation \"%s\" references missing source variation \"%s\"" % [label, lattice_id, source_variation_id])
				for error in Lattice.validate_variation_shape(part["latticeVariations"][lattice_id]):
					errors.append("%s lattice variation \"%s\" %s" % [label, lattice_id, error])
	return errors


static func _validate_equipment_assets(assets: Array) -> Array[String]:
	var errors: Array[String] = []
	for asset in assets:
		if not (asset is Dictionary):
			errors.append("Equipment asset record must be an object")
			continue
		var label = "Equipment asset \"%s\"" % String(asset.get("id", ""))
		errors.append_array(_unknown_keys(asset, ASSET_KEYS, label))
		errors.append_array(_require_string_fields(asset, ["id", "name", "source"], label))
		errors.append_array(_require_bool_fields(asset, ["actorSpace"], label))
		var source = String(asset.get("source", ""))
		if not ["custom", "imported", "original", "cta"].has(source):
			errors.append("%s has invalid source \"%s\"" % [label, source])
		if source == "cta":
			if asset.has("svgMarkup"):
				errors.append("%s cta asset must not define top-level svgMarkup" % label)
			if not (asset.get("variants", {}) is Dictionary):
				errors.append("%s variants must be an object" % label)
				continue
			for variant in asset.get("variants", {}).keys():
				if String(variant) == "":
					errors.append("%s contains an asset variant with an empty id" % label)
				var variant_data = asset["variants"][variant]
				if not (variant_data is Dictionary):
					errors.append("%s %s variant must be an object" % [label, variant])
					continue
				errors.append_array(_unknown_keys(variant_data, ASSET_VARIANT_KEYS, "%s %s variant" % [label, variant]))
				errors.append_array(_require_string_fields(variant_data, ["svgMarkup"], "%s %s variant" % [label, variant]))
				if not _is_valid_bounds(variant_data.get("viewBox", {})):
					errors.append("%s %s variant must have finite positive viewBox x/y/width/height" % [label, variant])
				if not SvgSafety.is_safe_markup(String(variant_data.get("svgMarkup", ""))):
					errors.append("%s %s variant contains unsafe SVG markup" % [label, variant])
		else:
			if asset.has("variants"):
				errors.append("%s non-cta asset must not define variants" % label)
			errors.append_array(_require_string_fields(asset, ["svgMarkup"], label))
			if not SvgSafety.is_safe_markup(String(asset.get("svgMarkup", ""))):
				errors.append("%s contains unsafe SVG markup" % label)
	return errors


static func _validate_equipment_visuals(visuals: Array, repo: ContentRepository) -> Array[String]:
	var errors: Array[String] = []
	var allowed_targets = repo.known_rig_target_ids()
	for visual in visuals:
		if not (visual is Dictionary):
			errors.append("Equipment visual record must be an object")
			continue
		var label = "Equipment visual \"%s\"" % String(visual.get("id", ""))
		errors.append_array(_unknown_keys(visual, VISUAL_KEYS, label))
		errors.append_array(_require_string_fields(visual, ["id", "name", "slot"], label))
		if not WARDROBE_SLOTS.has(String(visual.get("slot", ""))):
			errors.append("%s has invalid slot \"%s\"" % [label, String(visual.get("slot", ""))])
		if not (visual.get("pieces", []) is Array):
			errors.append("%s pieces must be an array" % label)
			continue
		var pieces: Array = visual.get("pieces", [])
		if pieces.is_empty():
			errors.append("%s must have at least one piece" % label)
		for index in range(pieces.size()):
			var piece = pieces[index]
			if not (piece is Dictionary):
				errors.append("%s piece %d must be an object" % [label, index])
				continue
			errors.append_array(_unknown_keys(piece, VISUAL_PIECE_KEYS, "%s piece %d" % [label, index]))
			errors.append_array(_require_string_fields(piece, ["target", "layer", "assetId"], "%s piece %d" % [label, index]))
			errors.append_array(_optional_string_fields(piece, ["colorGroup"], "%s piece %d" % [label, index]))
			errors.append_array(_optional_bool_fields(piece, ["hideBodyPart"], "%s piece %d" % [label, index]))
			var target = String(piece.get("target", ""))
			var layer = String(piece.get("layer", ""))
			var asset_id = String(piece.get("assetId", ""))
			if not allowed_targets.has(target):
				errors.append("%s piece %d has invalid target \"%s\"" % [label, index, target])
			if not LAYERS.has(layer):
				errors.append("%s piece %d has invalid layer \"%s\"" % [label, index, layer])
			if repo.equipment_asset(asset_id).is_empty():
				errors.append("%s piece %d references missing asset \"%s\"" % [label, index, asset_id])
			if piece.has("transform") and not (piece["transform"] is Dictionary):
				errors.append("%s piece %d transform must be an object" % [label, index])
			for key in piece.get("transform", {}).keys():
				if not TRANSFORM_KEYS.has(String(key)) or not _finite_number(piece["transform"][key]):
					errors.append("%s piece %d has invalid transform \"%s\"" % [label, index, key])
	return errors


static func _validate_wardrobe(wardrobe: Array, repo: ContentRepository) -> Array[String]:
	var errors: Array[String] = []
	var color_regex := RegEx.new()
	color_regex.compile(COLOR_PATTERN)
	for item in wardrobe:
		if not (item is Dictionary):
			errors.append("Wardrobe record must be an object")
			continue
		var label = "Wardrobe \"%s\"" % String(item.get("id", ""))
		errors.append_array(_unknown_keys(item, WARDROBE_KEYS, label))
		errors.append_array(_require_string_fields(item, ["id", "name", "slot", "visualId", "color"], label))
		errors.append_array(_optional_string_fields(item, ["description", "accentColor"], label))
		for key in OBSOLETE_WARDROBE_KEYS:
			if item.has(key):
				errors.append("%s contains obsolete RPG/economy field \"%s\"" % [label, key])
		if not WARDROBE_SLOTS.has(String(item.get("slot", ""))):
			errors.append("%s has invalid slot \"%s\"" % [label, String(item.get("slot", ""))])
		var visual_id = String(item.get("visualId", ""))
		if repo.equipment_visual(visual_id).is_empty():
			errors.append("%s references missing equipment visual \"%s\"" % [label, visual_id])
		for key in ["color", "accentColor"]:
			if item.has(key) and color_regex.search(String(item[key])) == null:
				errors.append("%s has invalid %s" % [label, key])
		if item.has("pieces"):
			if not (item["pieces"] is Array):
				errors.append("%s pieces must be an array" % label)
			else:
				for index in range(item["pieces"].size()):
					var piece = item["pieces"][index]
					if not (piece is Dictionary):
						errors.append("%s piece %d must be an object" % [label, index])
						continue
					errors.append_array(_unknown_keys(piece, WARDROBE_PIECE_KEYS, "%s piece %d" % [label, index]))
					errors.append_array(_require_string_fields(piece, ["target"], "%s piece %d" % [label, index]))
					errors.append_array(_optional_string_fields(piece, ["colorGroup"], "%s piece %d" % [label, index]))
	return errors


static func _validate_poses(poses: Array, repo: ContentRepository) -> Array[String]:
	var errors: Array[String] = []
	var allowed_targets = repo.known_rig_target_ids()
	for pose in poses:
		if not (pose is Dictionary):
			errors.append("Pose record must be an object")
			continue
		var label = "Pose \"%s\"" % String(pose.get("id", ""))
		errors.append_array(_unknown_keys(pose, POSE_KEYS, label))
		errors.append_array(_require_string_fields(pose, ["id", "name"], label))
		if not (pose.get("parts", {}) is Dictionary):
			errors.append("%s parts must be an object" % label)
			continue
		if pose.has("sprites") and not (pose["sprites"] is Dictionary):
			errors.append("%s sprites must be an object" % label)
		for part_id in pose.get("parts", {}).keys():
			if not allowed_targets.has(String(part_id)):
				errors.append("%s has invalid part \"%s\"" % [label, part_id])
			if not (pose["parts"][part_id] is Dictionary):
				errors.append("%s part \"%s\" transform must be an object" % [label, part_id])
				continue
			for key in pose["parts"][part_id].keys():
				if not POSE_TRANSFORM_KEYS.has(String(key)) or not _finite_number(pose["parts"][part_id][key]):
					errors.append("%s part \"%s\" has invalid transform \"%s\"" % [label, part_id, key])
		for part_id in pose.get("sprites", {}).keys():
			if not allowed_targets.has(String(part_id)):
				errors.append("%s has invalid sprite override part \"%s\"" % [label, part_id])
			if not (pose["sprites"][part_id] is String):
				errors.append("%s sprite override \"%s\" must be a string" % [label, part_id])
				continue
			var sprite_value := String(pose["sprites"][part_id])
			var sprite_part := String(part_id)
			if sprite_part == "leftHand" or sprite_part == "rightHand":
				if not HAND_SPRITES.has(sprite_value):
					errors.append("%s sprite override \"%s\" has invalid hand sprite \"%s\"" % [label, part_id, sprite_value])
			elif sprite_part == "leftFoot" or sprite_part == "rightFoot":
				if not FOOT_SPRITES.has(sprite_value):
					errors.append("%s sprite override \"%s\" has invalid foot sprite \"%s\"" % [label, part_id, sprite_value])
			elif sprite_value != "":
				var variation_ids := _variation_ids_for_part(repo, sprite_part)
				if variation_ids.is_empty() or not variation_ids.has(sprite_value):
					errors.append("%s sprite override \"%s\" references missing variation \"%s\"" % [label, part_id, sprite_value])
	return errors


static func _validate_starting_outfit(outfit: Dictionary, repo: ContentRepository, label: String) -> Array[String]:
	var errors: Array[String] = []
	errors.append_array(_unknown_keys(outfit, STARTING_OUTFIT_KEYS, label))
	errors.append_array(_optional_string_fields(outfit, ["id", "name", "variant", "poseId", "skinTone", "skinLine", "hairColor", "eyeColor"], label))
	var color_regex := RegEx.new()
	color_regex.compile(COLOR_PATTERN)
	for key in ["skinTone", "skinLine", "hairColor", "eyeColor"]:
		if outfit.has(key) and color_regex.search(String(outfit[key])) == null:
			errors.append("%s has invalid %s" % [label, key])
	var variant = String(outfit.get("variant", "female"))
	if repo != null and not repo.body_rig.has(variant):
		errors.append("%s references missing variant \"%s\"" % [label, variant])
	var pose_id = String(outfit.get("poseId", "idle"))
	if repo != null and not repo.has_pose(pose_id):
		errors.append("%s references missing pose \"%s\"" % [label, pose_id])
	if outfit.has("equippedItemIds") and not (outfit["equippedItemIds"] is Array):
		errors.append("%s equippedItemIds must be an array" % label)
	else:
		for item_id in outfit.get("equippedItemIds", []):
			if not (item_id is String):
				errors.append("%s equipped item ids must be strings" % label)
			elif repo != null and not repo.has_wardrobe_item(String(item_id)):
				errors.append("%s references missing wardrobe item \"%s\"" % [label, String(item_id)])
	return errors


static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _unknown_keys(record: Dictionary, allowed: Array, label: String) -> Array[String]:
	var errors: Array[String] = []
	for key in record.keys():
		if not allowed.has(String(key)):
			errors.append("%s contains unknown field \"%s\"" % [label, String(key)])
	return errors


static func _require_string_fields(record: Dictionary, fields: Array, label: String) -> Array[String]:
	var errors: Array[String] = []
	for field in fields:
		var key = String(field)
		if not record.has(key):
			errors.append("%s is missing required field \"%s\"" % [label, key])
		elif not (record[key] is String):
			errors.append("%s field \"%s\" must be a string" % [label, key])
	return errors


static func _optional_string_fields(record: Dictionary, fields: Array, label: String) -> Array[String]:
	var errors: Array[String] = []
	for field in fields:
		var key = String(field)
		if record.has(key) and not (record[key] is String):
			errors.append("%s field \"%s\" must be a string" % [label, key])
	return errors


static func _require_bool_fields(record: Dictionary, fields: Array, label: String) -> Array[String]:
	var errors: Array[String] = []
	for field in fields:
		var key = String(field)
		if not record.has(key):
			errors.append("%s is missing required field \"%s\"" % [label, key])
		elif not (record[key] is bool):
			errors.append("%s field \"%s\" must be a boolean" % [label, key])
	return errors


static func _optional_bool_fields(record: Dictionary, fields: Array, label: String) -> Array[String]:
	var errors: Array[String] = []
	for field in fields:
		var key = String(field)
		if record.has(key) and not (record[key] is bool):
			errors.append("%s field \"%s\" must be a boolean" % [label, key])
	return errors


static func _is_valid_bounds(bounds: Variant) -> bool:
	return bounds is Dictionary and _finite_number(bounds.get("x")) and _finite_number(bounds.get("y")) and _finite_number(bounds.get("width")) and _finite_number(bounds.get("height")) and float(bounds["width"]) > 0.0 and float(bounds["height"]) > 0.0


static func _variation_ids_for_part(repo: ContentRepository, part_id: String) -> Array[String]:
	var ids: Array[String] = []
	if repo == null:
		return ids
	for variant in repo.body_rig.keys():
		var part = repo.body_part(String(variant), part_id)
		if part.is_empty():
			continue
		for id in part.get("variations", {}).keys():
			var variation_id := String(id)
			if variation_id != "" and not ids.has(variation_id):
				ids.append(variation_id)
		for id in part.get("latticeVariations", {}).keys():
			var variation_id := String(id)
			if variation_id != "" and not ids.has(variation_id):
				ids.append(variation_id)
	return ids
