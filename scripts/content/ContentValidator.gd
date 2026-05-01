class_name ContentValidator
extends RefCounted

const LAYERS := ["back", "upperLimbs", "body", "legs", "head", "frontLimbs", "front"]
const COLOR_PATTERN := "^#[0-9a-fA-F]{6}$"


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


static func _validate_unique_ids(records: Array, label: String) -> Array[String]:
	var errors: Array[String] = []
	var seen := {}
	for record in records:
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
	for variant in ["female", "male"]:
		var parts: Array = body_rig.get(variant, {}).get("parts", [])
		var ids := {}
		for part in parts:
			var id = String(part.get("id", ""))
			if id == "":
				errors.append("%s body rig contains a part with a missing id" % variant)
			elif ids.has(id):
				errors.append("%s body rig contains duplicate part id \"%s\"" % [variant, id])
			else:
				ids[id] = true
		for part in parts:
			var label = "%s body part \"%s\"" % [variant, String(part.get("id", ""))]
			var layer = String(part.get("layer", ""))
			if not LAYERS.has(layer):
				errors.append("%s has invalid layer \"%s\"" % [label, layer])
			var parent_id = String(part.get("parentId", ""))
			if parent_id != "" and not ids.has(parent_id) and not DollSvgBuilder.BASE_PIVOTS.has(parent_id):
				errors.append("%s references missing parent \"%s\"" % [label, parent_id])
			var pivot = part.get("pivot", {})
			if not pivot is Dictionary or not _finite_number(pivot.get("x")) or not _finite_number(pivot.get("y")):
				errors.append("%s must have finite pivot x/y values" % label)
			if not SvgSafety.is_safe_markup(String(part.get("svgMarkup", ""))):
				errors.append("%s contains unsafe SVG markup" % label)
			for variation_id in part.get("variations", {}).keys():
				if not SvgSafety.is_safe_markup(String(part["variations"][variation_id])):
					errors.append("%s variation \"%s\" contains unsafe SVG markup" % [label, variation_id])
			for lattice_id in part.get("latticeVariations", {}).keys():
				for error in Lattice.validate_variation_shape(part["latticeVariations"][lattice_id]):
					errors.append("%s lattice variation \"%s\" %s" % [label, lattice_id, error])
	return errors


static func _validate_equipment_assets(assets: Array) -> Array[String]:
	var errors: Array[String] = []
	for asset in assets:
		var label = "Equipment asset \"%s\"" % String(asset.get("id", ""))
		if asset.get("source", "") == "cta":
			for variant in asset.get("variants", {}).keys():
				var variant_data = asset["variants"][variant]
				if not SvgSafety.is_safe_markup(String(variant_data.get("svgMarkup", ""))):
					errors.append("%s %s variant contains unsafe SVG markup" % [label, variant])
		elif not SvgSafety.is_safe_markup(String(asset.get("svgMarkup", ""))):
			errors.append("%s contains unsafe SVG markup" % label)
	return errors


static func _validate_equipment_visuals(visuals: Array, repo: ContentRepository) -> Array[String]:
	var errors: Array[String] = []
	var allowed_targets = repo.known_rig_target_ids()
	for visual in visuals:
		var label = "Equipment visual \"%s\"" % String(visual.get("id", ""))
		var pieces: Array = visual.get("pieces", [])
		if pieces.is_empty():
			errors.append("%s must have at least one piece" % label)
		for index in range(pieces.size()):
			var piece: Dictionary = pieces[index]
			var target = String(piece.get("target", ""))
			var layer = String(piece.get("layer", ""))
			var asset_id = String(piece.get("assetId", ""))
			if not allowed_targets.has(target):
				errors.append("%s piece %d has invalid target \"%s\"" % [label, index, target])
			if not LAYERS.has(layer):
				errors.append("%s piece %d has invalid layer \"%s\"" % [label, index, layer])
			if repo.equipment_asset(asset_id).is_empty():
				errors.append("%s piece %d references missing asset \"%s\"" % [label, index, asset_id])
			for key in piece.get("transform", {}).keys():
				if not ["x", "y", "rotate", "scaleX", "scaleY"].has(String(key)) or not _finite_number(piece["transform"][key]):
					errors.append("%s piece %d has invalid transform \"%s\"" % [label, index, key])
	return errors


static func _validate_wardrobe(wardrobe: Array, repo: ContentRepository) -> Array[String]:
	var errors: Array[String] = []
	var color_regex := RegEx.new()
	color_regex.compile(COLOR_PATTERN)
	for item in wardrobe:
		var label = "Wardrobe \"%s\"" % String(item.get("id", ""))
		var visual_id = String(item.get("visualId", ""))
		if repo.equipment_visual(visual_id).is_empty():
			errors.append("%s references missing equipment visual \"%s\"" % [label, visual_id])
		for key in ["color", "accentColor"]:
			if item.has(key) and color_regex.search(String(item[key])) == null:
				errors.append("%s has invalid %s" % [label, key])
	return errors


static func _validate_poses(poses: Array, repo: ContentRepository) -> Array[String]:
	var errors: Array[String] = []
	var allowed_targets = repo.known_rig_target_ids()
	for pose in poses:
		var label = "Pose \"%s\"" % String(pose.get("id", ""))
		for part_id in pose.get("parts", {}).keys():
			if not allowed_targets.has(String(part_id)):
				errors.append("%s has invalid part \"%s\"" % [label, part_id])
			for key in pose["parts"][part_id].keys():
				if not ["rotate", "x", "y", "scaleX", "scaleY", "bend"].has(String(key)) or not _finite_number(pose["parts"][part_id][key]):
					errors.append("%s part \"%s\" has invalid transform \"%s\"" % [label, part_id, key])
	return errors


static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
