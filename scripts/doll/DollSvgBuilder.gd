class_name DollSvgBuilder
extends RefCounted

const ACTOR_WIDTH := 2400.0
const ACTOR_HEIGHT := 3100.0
const CENTER_X := 1200.0
const LAYER_ORDER := ["back", "upperLimbs", "body", "legs", "head", "frontLimbs", "front"]
const HAIR_COLOR_FILLS := {
	"#183f7b": "var(--doll-hair-shadow)",
	"#1f4a8c": "var(--doll-hair)",
	"#30518a": "var(--doll-hair-shadow)",
	"#3861a6": "var(--doll-hair)",
	"#49454e": "var(--doll-hair)",
	"#9a633f": "var(--doll-hair-shadow)",
	"#b6754a": "var(--doll-hair)",
	"#d08a5b": "var(--doll-hair-shadow)",
	"#e09a6b": "var(--doll-hair)",
}
const IRIS_COLOR_FILLS := {
	"#3a5bd7": "var(--doll-eye)",
	"#828180": "var(--doll-eye)",
}

const BASE_PIVOTS := {
	"body": {"x": 1200.0, "y": 1620.0},
	"hip": {"x": 1200.0, "y": 1760.0},
	"torso": {"x": 1200.0, "y": 980.0},
	"neck": {"x": 1200.0, "y": 850.0},
	"head": {"x": 1200.0, "y": 555.0},
	"headNub": {"x": 1200.0, "y": 555.0},
	"leftArm": {"x": 1000.0, "y": 993.0},
	"leftForearm": {"x": 667.0, "y": 999.0},
	"leftHand": {"x": 349.0, "y": 1000.0},
	"rightArm": {"x": 1401.0, "y": 994.0},
	"rightForearm": {"x": 1733.0, "y": 999.0},
	"rightHand": {"x": 2051.0, "y": 1000.0},
	"leftThigh": {"x": 1096.0, "y": 1645.0},
	"leftShank": {"x": 1104.0, "y": 2115.0},
	"leftFoot": {"x": 1125.0, "y": 2645.0},
	"leftToe": {"x": 1127.0, "y": 2779.0},
	"rightThigh": {"x": 1301.0, "y": 1645.0},
	"rightShank": {"x": 1293.0, "y": 2115.0},
	"rightFoot": {"x": 1271.0, "y": 2645.0},
	"rightToe": {"x": 1271.0, "y": 2779.0},
	"backHair": {"x": 1200.0, "y": 500.0},
	"frontHair": {"x": 1200.0, "y": 500.0},
	"face": {"x": 1200.0, "y": 630.0},
	"leftEye": {"x": 1090.0, "y": 570.0},
	"rightEye": {"x": 1310.0, "y": 570.0},
	"leftBrow": {"x": 1090.0, "y": 485.0},
	"rightBrow": {"x": 1310.0, "y": 485.0},
	"mouth": {"x": 1200.0, "y": 725.0},
	"nose": {"x": 1200.0, "y": 645.0},
	"leftEar": {"x": 955.0, "y": 600.0},
	"rightEar": {"x": 1445.0, "y": 600.0},
	"horns": {"x": 1200.0, "y": 310.0},
	"tail": {"x": 1445.0, "y": 1810.0},
}


static func build_svg(repo: ContentRepository, outfit: Variant, options: Dictionary = {}) -> String:
	var variant = outfit.variant
	var pose = options.get("poseOverride", repo.pose(outfit.pose_id))
	var layers := {}
	for layer in LAYER_ORDER:
		layers[layer] = []

	var tokens = _doll_tokens(outfit)
	var hidden_targets = _hidden_targets(repo, outfit)
	for part in repo.body_parts_for_variant(variant):
		var part_id = String(part.get("id", ""))
		if hidden_targets.has(part_id):
			continue
		var layer = String(part.get("layer", "body"))
		if not layers.has(layer):
			layer = "body"
		layers[layer].append(_body_part_svg(repo, outfit, pose, part, tokens))

	for item_id in outfit.equipped_item_ids:
		var item = repo.wardrobe_item(String(item_id))
		var visual = repo.equipment_visual(String(item.get("visualId", "")))
		if item.is_empty() or visual.is_empty():
			continue
		for piece in visual.get("pieces", []):
			var layer = String(piece.get("layer", "front"))
			if layers.has(layer):
				layers[layer].append(_equipment_piece_svg(repo, outfit, pose, item, piece))

	var layer_markup := ""
	for layer in LAYER_ORDER:
		layer_markup += "<g class=\"doll-layer doll-layer-%s\" data-layer=\"%s\">%s</g>\n" % [
			layer,
			layer,
			"".join(layers[layer]),
		]

	var body_transform = _transform_for(pose, "body", BASE_PIVOTS["body"])
	var overlays = ""
	if options.get("showPivots", false):
		overlays += _pivot_overlay(repo, variant)
	if options.get("showLayerOrder", false):
		overlays += _layer_overlay()

	return "\n".join([
		"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"2400\" height=\"3100\" viewBox=\"0 0 2400 3100\">",
		"<rect width=\"2400\" height=\"3100\" fill=\"none\"/>",
		"<ellipse cx=\"1200\" cy=\"2950\" rx=\"480\" ry=\"88\" fill=\"#1c2830\" opacity=\"0.18\"/>",
		"<g class=\"paper-doll-figure\" transform=\"%s\">" % body_transform,
		layer_markup,
		overlays,
		"</g>",
		"</svg>",
	])


static func build_item_icon_svg(_repo: ContentRepository, item: Dictionary) -> String:
	var color = String(item.get("color", "#d8d8d8"))
	var accent = String(item.get("accentColor", _adjust_color(color, -40)))
	var label = _escape_xml(String(item.get("name", item.get("id", "?"))).substr(0, 2).to_upper())
	return "\n".join([
		"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"256\" height=\"256\" viewBox=\"0 0 256 256\">",
		"<rect x=\"10\" y=\"10\" width=\"236\" height=\"236\" rx=\"18\" fill=\"#f7f2ea\" stroke=\"#d8d0c6\" stroke-width=\"4\"/>",
		"<circle cx=\"128\" cy=\"104\" r=\"58\" fill=\"%s\"/>" % color,
		"<path d=\"M72 168 C96 190 160 190 184 168\" fill=\"none\" stroke=\"%s\" stroke-width=\"14\" stroke-linecap=\"round\"/>" % accent,
		"<text x=\"128\" y=\"140\" text-anchor=\"middle\" font-family=\"Arial\" font-size=\"54\" font-weight=\"800\" fill=\"#27292d\">%s</text>" % label,
		"</svg>",
	])


static func top_visible_equipped_item_id(repo: ContentRepository, outfit: Variant) -> String:
	var top_item_id := ""
	for layer in LAYER_ORDER:
		for item_id in outfit.equipped_item_ids:
			var item = repo.wardrobe_item(String(item_id))
			if item.is_empty():
				continue
			var visual = repo.equipment_visual(String(item.get("visualId", "")))
			if visual.is_empty():
				continue
			for piece in visual.get("pieces", []):
				if String(piece.get("layer", "front")) != layer:
					continue
				if repo.equipment_asset(String(piece.get("assetId", ""))).is_empty():
					continue
				top_item_id = String(item_id)
	return top_item_id


static func top_visible_equipped_item_id_at(repo: ContentRepository, outfit: Variant, actor_position: Vector2, options: Dictionary = {}) -> String:
	var top_item_id := ""
	var pose = options.get("poseOverride", repo.pose(outfit.pose_id))
	for layer in LAYER_ORDER:
		for item_id in outfit.equipped_item_ids:
			var item = repo.wardrobe_item(String(item_id))
			if item.is_empty():
				continue
			var visual = repo.equipment_visual(String(item.get("visualId", "")))
			if visual.is_empty():
				continue
			for piece in visual.get("pieces", []):
				if String(piece.get("layer", "front")) != layer:
					continue
				var asset = repo.equipment_asset(String(piece.get("assetId", "")))
				if asset.is_empty():
					continue
				var bounds = _equipment_piece_actor_bounds(repo, outfit, pose, piece, asset)
				if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
					continue
				if bounds.has_point(actor_position):
					top_item_id = String(item_id)
	return top_item_id


static func body_part_actor_bounds(repo: ContentRepository, variant: String, pose: Dictionary, part: Dictionary) -> Rect2:
	var part_id = String(part.get("id", ""))
	var pivot = _pivot_for(repo, variant, part_id)
	var source_bounds = _svg_markup_bounds(_resolve_body_part_markup(part, pose))
	if source_bounds.size.x > 0.0 and source_bounds.size.y > 0.0:
		source_bounds = _actor_space_rect(source_bounds, repo.sample_meta.get("variants", {}).get(variant, {}))
	else:
		source_bounds = Rect2(Vector2(float(pivot.get("x", 0.0)) - 64.0, float(pivot.get("y", 0.0)) - 64.0), Vector2(128.0, 128.0))
	source_bounds = source_bounds.grow(18.0)
	var transform := Transform2D.IDENTITY
	for chain_part_id in _transform_chain_for_target(repo, variant, part_id):
		transform = transform * _pose_transform_matrix(pose, chain_part_id, _pivot_for(repo, variant, chain_part_id))
	return _transformed_rect(source_bounds, transform)


static func _body_part_svg(repo: ContentRepository, outfit: Variant, pose: Dictionary, part: Dictionary, tokens: Dictionary) -> String:
	var part_id = String(part.get("id", ""))
	var markup = _resolve_body_part_markup(part, pose)
	markup = _normalize_body_part_color_tokens(markup, part_id)
	markup = _materialize_tokens(markup, tokens)
	var chain = _transform_chain_for_target(repo, outfit.variant, part_id)
	var transform = _transform_chain(repo, outfit.variant, pose, chain)
	var actor_transform = _actor_space_transform(repo.sample_meta.get("variants", {}).get(outfit.variant, {}))
	return "<g class=\"doll-segment sample-%s\" data-rig-part=\"%s\" transform=\"%s\"><g transform=\"%s\">%s</g></g>\n" % [
		part_id,
		part_id,
		transform,
		actor_transform,
		markup,
	]


static func _equipment_piece_svg(repo: ContentRepository, outfit: Variant, pose: Dictionary, item: Dictionary, piece: Dictionary) -> String:
	var asset_id = String(piece.get("assetId", ""))
	var asset = repo.equipment_asset(asset_id)
	if asset.is_empty():
		return ""
	var target = String(piece.get("target", "body"))
	var pivot = _pivot_for(repo, outfit.variant, target)
	var chain = _transform_chain_for_target(repo, outfit.variant, target)
	var transform = "%s %s" % [
		_transform_chain(repo, outfit.variant, pose, chain),
		_visual_transform(piece.get("transform", {}), pivot),
	]
	var paint = _equipment_tokens(item, piece)
	var markup := ""
	if String(asset.get("source", "")) == "cta":
		var variant_data = asset.get("variants", {}).get(outfit.variant, {})
		markup = _materialize_tokens(String(variant_data.get("svgMarkup", "")), paint)
		var actor_source = {
			"viewBox": variant_data.get("viewBox", {}),
			"baseScale": repo.sample_meta.get("variants", {}).get(outfit.variant, {}).get("baseScale", 1.58),
		}
		var actor_transform = _actor_space_transform(actor_source)
		markup = "<g transform=\"%s\">%s</g>" % [actor_transform, markup]
	else:
		markup = _materialize_tokens(String(asset.get("svgMarkup", "")), paint)
		if not bool(asset.get("actorSpace", false)):
			markup = "<g transform=\"translate(%s %s)\">%s</g>" % [_num(pivot["x"]), _num(pivot["y"]), markup]
	return "<g class=\"equipment-piece equipment-%s\" data-wardrobe-id=\"%s\" data-rig-part=\"%s\" transform=\"%s\">%s</g>\n" % [
		String(item.get("id", "")),
		String(item.get("id", "")),
		target,
		transform,
		markup,
	]


static func _resolve_body_part_markup(part: Dictionary, pose: Dictionary) -> String:
	var part_id = String(part.get("id", ""))
	var sprite_id = String(pose.get("sprites", {}).get(part_id, ""))
	if sprite_id == "":
		return String(part.get("svgMarkup", ""))
	if part.get("latticeVariations", {}).has(sprite_id):
		var lattice = part["latticeVariations"][sprite_id]
		var source_id = String(lattice.get("sourceVariationId", ""))
		var source = String(part.get("variations", {}).get(source_id, part.get("svgMarkup", "")))
		return Lattice.apply_lattice_to_svg_markup(source, lattice)
	return String(part.get("variations", {}).get(sprite_id, part.get("svgMarkup", "")))


static func _doll_tokens(outfit: Variant) -> Dictionary:
	return {
		"--doll-skin": outfit.skin_tone,
		"--doll-skin-shadow": _adjust_color(outfit.skin_tone, -34),
		"--doll-skin-contour": outfit.skin_line,
		"--doll-hair": outfit.hair_color,
		"--doll-hair-shadow": _adjust_color(outfit.hair_color, -34),
		"--doll-eye": outfit.eye_color,
	}


static func _equipment_tokens(item: Dictionary, piece: Dictionary) -> Dictionary:
	var base = String(item.get("color", "#888888"))
	var accent = String(item.get("accentColor", _adjust_color(base, -48)))
	var group = String(piece.get("colorGroup", ""))
	var group_base = base
	if group == "Clothing.Shoes.Sole":
		group_base = accent
	elif group == "Clothing.Top.Sleeves":
		group_base = String(item.get("accentColor", base))
	return {
		"--equip-base": group_base,
		"--equip-accent": accent,
		"--equip-shadow": _adjust_color(group_base, -34),
		"--equip-line": _adjust_color(group_base, -62),
	}


static func _materialize_tokens(markup: String, tokens: Dictionary) -> String:
	var result = markup
	for key in tokens.keys():
		result = result.replace("var(%s)" % key, String(tokens[key]))
	return result


static func _normalize_body_part_color_tokens(markup: String, part_id: String) -> String:
	match part_id:
		"backHair", "frontHair", "leftBrow", "rightBrow":
			return _replace_known_fills(markup, HAIR_COLOR_FILLS)
		"leftEye", "rightEye":
			return _replace_known_fills(markup, IRIS_COLOR_FILLS)
	return markup


static func _replace_known_fills(markup: String, fill_map: Dictionary) -> String:
	var result = markup
	for hex in fill_map.keys():
		result = result.replace("fill=\"%s\"" % hex, "fill=\"%s\"" % String(fill_map[hex]))
		result = result.replace("fill=\"%s\"" % String(hex).to_upper(), "fill=\"%s\"" % String(fill_map[hex]))
	return result


static func _actor_space_transform(source: Dictionary) -> String:
	var view_box = source.get("viewBox", source)
	var base_scale = float(source.get("baseScale", 1.58))
	var width = float(view_box.get("width", ACTOR_WIDTH))
	var x = float(view_box.get("x", 0.0))
	var y = float(view_box.get("y", 0.0))
	var scaled_width = width * base_scale
	var offset_x = (ACTOR_WIDTH - scaled_width) / 2.0 - x * base_scale
	var offset_y = 88.0 - y * base_scale
	return "translate(%s 0) scale(1 1) translate(%s 0) translate(%s %s) scale(%s)" % [
		_num(CENTER_X),
		_num(-CENTER_X),
		_num(offset_x),
		_num(offset_y),
		_num(base_scale),
	]


static func _transform_chain(repo: ContentRepository, variant: String, pose: Dictionary, chain: Array[String]) -> String:
	var transforms: Array[String] = []
	for part_id in chain:
		transforms.append(_transform_for(pose, part_id, _pivot_for(repo, variant, part_id)))
	return " ".join(transforms)


static func _transform_for(pose: Dictionary, part_id: String, pivot: Dictionary) -> String:
	var transform = pose.get("parts", {}).get(part_id, {})
	var x = float(transform.get("x", 0.0))
	var y = float(transform.get("y", 0.0))
	var rotate = float(transform.get("rotate", 0.0))
	var scale_x = float(transform.get("scaleX", 1.0))
	var scale_y = float(transform.get("scaleY", 1.0))
	var pivot_x = float(pivot["x"])
	var pivot_y = float(pivot["y"])
	var bend = float(transform.get("bend", 0.0))
	var bend_transform := ""
	if not is_equal_approx(bend, 0.0):
		bend_transform = " translate(%s %s) skewX(%s) translate(%s %s)" % [
			_num(pivot_x),
			_num(pivot_y),
			_num(bend),
			_num(-pivot_x),
			_num(-pivot_y),
		]
	return "translate(%s %s) rotate(%s %s %s)%s scale(%s %s)" % [
		_num(x),
		_num(y),
		_num(rotate),
		_num(pivot_x),
		_num(pivot_y),
		bend_transform,
		_num(scale_x),
		_num(scale_y),
	]


static func _visual_transform(transform: Dictionary, pivot: Dictionary) -> String:
	if transform.is_empty():
		return ""
	var x = float(transform.get("x", 0.0))
	var y = float(transform.get("y", 0.0))
	var rotate = float(transform.get("rotate", 0.0))
	var scale_x = float(transform.get("scaleX", 1.0))
	var scale_y = float(transform.get("scaleY", 1.0))
	return "translate(%s %s) translate(%s %s) rotate(%s) scale(%s %s) translate(%s %s)" % [
		_num(x),
		_num(y),
		_num(float(pivot["x"])),
		_num(float(pivot["y"])),
		_num(rotate),
		_num(scale_x),
		_num(scale_y),
		_num(-float(pivot["x"])),
		_num(-float(pivot["y"])),
	]


static func _equipment_piece_actor_bounds(repo: ContentRepository, outfit: Variant, pose: Dictionary, piece: Dictionary, asset: Dictionary) -> Rect2:
	var target = String(piece.get("target", "body"))
	var pivot = _pivot_for(repo, outfit.variant, target)
	var source_bounds := Rect2()
	if String(asset.get("source", "")) == "cta":
		var variant_data = asset.get("variants", {}).get(outfit.variant, {})
		source_bounds = _svg_markup_bounds(String(variant_data.get("svgMarkup", "")))
		if source_bounds.size.x > 0.0 and source_bounds.size.y > 0.0:
			source_bounds = _actor_space_rect(source_bounds, {
				"viewBox": variant_data.get("viewBox", {}),
				"baseScale": repo.sample_meta.get("variants", {}).get(outfit.variant, {}).get("baseScale", 1.58),
			})
	else:
		source_bounds = _svg_markup_bounds(String(asset.get("svgMarkup", "")))
		if source_bounds.size.x > 0.0 and source_bounds.size.y > 0.0 and not bool(asset.get("actorSpace", false)):
			source_bounds.position += Vector2(float(pivot["x"]), float(pivot["y"]))
	if source_bounds.size.x <= 0.0 or source_bounds.size.y <= 0.0:
		source_bounds = Rect2(Vector2(float(pivot["x"]) - 80.0, float(pivot["y"]) - 80.0), Vector2(160.0, 160.0))
	source_bounds = source_bounds.grow(32.0)
	var transform = _equipment_piece_actor_transform(repo, outfit.variant, pose, piece, pivot)
	return _transformed_rect(source_bounds, transform)


static func _equipment_piece_actor_transform(repo: ContentRepository, variant: String, pose: Dictionary, piece: Dictionary, pivot: Dictionary) -> Transform2D:
	var transform := Transform2D.IDENTITY
	var target = String(piece.get("target", "body"))
	for part_id in _transform_chain_for_target(repo, variant, target):
		transform = transform * _pose_transform_matrix(pose, part_id, _pivot_for(repo, variant, part_id))
	transform = transform * _visual_transform_matrix(piece.get("transform", {}), pivot)
	return transform


static func _pose_transform_matrix(pose: Dictionary, part_id: String, pivot: Dictionary) -> Transform2D:
	var authored = pose.get("parts", {}).get(part_id, {})
	var pivot_point = Vector2(float(pivot["x"]), float(pivot["y"]))
	var transform := Transform2D.IDENTITY
	transform = transform * _translation_matrix(Vector2(float(authored.get("x", 0.0)), float(authored.get("y", 0.0))))
	transform = transform * _around_point_matrix(pivot_point, _rotation_matrix(float(authored.get("rotate", 0.0))))
	var bend = float(authored.get("bend", 0.0))
	if not is_equal_approx(bend, 0.0):
		transform = transform * _around_point_matrix(pivot_point, _skew_x_matrix(bend))
	transform = transform * _scale_matrix(Vector2(float(authored.get("scaleX", 1.0)), float(authored.get("scaleY", 1.0))))
	return transform


static func _visual_transform_matrix(transform: Dictionary, pivot: Dictionary) -> Transform2D:
	if transform.is_empty():
		return Transform2D.IDENTITY
	var pivot_point = Vector2(float(pivot["x"]), float(pivot["y"]))
	var matrix := Transform2D.IDENTITY
	matrix = matrix * _translation_matrix(Vector2(float(transform.get("x", 0.0)), float(transform.get("y", 0.0))))
	matrix = matrix * _translation_matrix(pivot_point)
	matrix = matrix * _rotation_matrix(float(transform.get("rotate", 0.0)))
	matrix = matrix * _scale_matrix(Vector2(float(transform.get("scaleX", 1.0)), float(transform.get("scaleY", 1.0))))
	matrix = matrix * _translation_matrix(-pivot_point)
	return matrix


static func _actor_space_rect(rect: Rect2, source: Dictionary) -> Rect2:
	var view_box = source.get("viewBox", source)
	var base_scale = float(source.get("baseScale", 1.58))
	var width = float(view_box.get("width", ACTOR_WIDTH))
	var x = float(view_box.get("x", 0.0))
	var y = float(view_box.get("y", 0.0))
	var scaled_width = width * base_scale
	var offset = Vector2((ACTOR_WIDTH - scaled_width) / 2.0 - x * base_scale, 88.0 - y * base_scale)
	return Rect2(offset + rect.position * base_scale, rect.size * base_scale)


static func _svg_markup_bounds(markup: String) -> Rect2:
	var points: Array[Vector2] = []
	_append_path_points(markup, points)
	_append_rect_points(markup, points)
	_append_circle_points(markup, points)
	_append_ellipse_points(markup, points)
	_append_line_points(markup, points)
	if points.is_empty():
		return Rect2()
	var min_point = points[0]
	var max_point = points[0]
	for point in points:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	return Rect2(min_point, max_point - min_point)


static func _append_path_points(markup: String, points: Array[Vector2]) -> void:
	var regex := RegEx.new()
	regex.compile("\\bd\\s*=\\s*['\\\"]([^'\\\"]+)['\\\"]")
	for match_result in regex.search_all(markup):
		_append_path_command_points(match_result.get_string(1), points)


static func _append_path_command_points(path_data: String, points: Array[Vector2]) -> void:
	var tokens = _path_tokens(path_data)
	var index := 0
	var command := ""
	var current := Vector2.ZERO
	var subpath_start := Vector2.ZERO
	while index < tokens.size():
		var token = String(tokens[index])
		if _is_path_command(token):
			command = token
			index += 1
		elif command == "":
			index += 1
			continue
		var upper = command.to_upper()
		var relative = command != upper
		match upper:
			"M":
				if index + 1 >= tokens.size():
					return
				current = _path_point(tokens, index, relative, current)
				points.append(current)
				subpath_start = current
				index += 2
				command = "l" if relative else "L"
			"L":
				if index + 1 >= tokens.size():
					return
				current = _path_point(tokens, index, relative, current)
				points.append(current)
				index += 2
			"H":
				if index >= tokens.size():
					return
				var x = float(tokens[index])
				current.x = current.x + x if relative else x
				points.append(current)
				index += 1
			"V":
				if index >= tokens.size():
					return
				var y = float(tokens[index])
				current.y = current.y + y if relative else y
				points.append(current)
				index += 1
			"C":
				if index + 5 >= tokens.size():
					return
				var control_1 = _path_point(tokens, index, relative, current)
				var control_2 = _path_point(tokens, index + 2, relative, current)
				current = _path_point(tokens, index + 4, relative, current)
				points.append(control_1)
				points.append(control_2)
				points.append(current)
				index += 6
			"S":
				if index + 3 >= tokens.size():
					return
				var control = _path_point(tokens, index, relative, current)
				current = _path_point(tokens, index + 2, relative, current)
				points.append(control)
				points.append(current)
				index += 4
			"Q":
				if index + 3 >= tokens.size():
					return
				var control = _path_point(tokens, index, relative, current)
				current = _path_point(tokens, index + 2, relative, current)
				points.append(control)
				points.append(current)
				index += 4
			"T":
				if index + 1 >= tokens.size():
					return
				current = _path_point(tokens, index, relative, current)
				points.append(current)
				index += 2
			"A":
				if index + 6 >= tokens.size():
					return
				var radius = Vector2(absf(float(tokens[index])), absf(float(tokens[index + 1])))
				var end_point = _path_point(tokens, index + 5, relative, current)
				points.append(current - radius)
				points.append(current + radius)
				points.append(end_point - radius)
				points.append(end_point + radius)
				current = end_point
				index += 7
			"Z":
				current = subpath_start
				points.append(current)
				command = ""
			_:
				index += 1


static func _append_rect_points(markup: String, points: Array[Vector2]) -> void:
	for tag in _shape_tags(markup, "rect"):
		var x = _svg_attr_float(tag, "x", 0.0)
		var y = _svg_attr_float(tag, "y", 0.0)
		var width = _svg_attr_float(tag, "width", 0.0)
		var height = _svg_attr_float(tag, "height", 0.0)
		points.append(Vector2(x, y))
		points.append(Vector2(x + width, y + height))


static func _append_circle_points(markup: String, points: Array[Vector2]) -> void:
	for tag in _shape_tags(markup, "circle"):
		var cx = _svg_attr_float(tag, "cx", 0.0)
		var cy = _svg_attr_float(tag, "cy", 0.0)
		var radius = _svg_attr_float(tag, "r", 0.0)
		points.append(Vector2(cx - radius, cy - radius))
		points.append(Vector2(cx + radius, cy + radius))


static func _append_ellipse_points(markup: String, points: Array[Vector2]) -> void:
	for tag in _shape_tags(markup, "ellipse"):
		var cx = _svg_attr_float(tag, "cx", 0.0)
		var cy = _svg_attr_float(tag, "cy", 0.0)
		var rx = _svg_attr_float(tag, "rx", 0.0)
		var ry = _svg_attr_float(tag, "ry", 0.0)
		points.append(Vector2(cx - rx, cy - ry))
		points.append(Vector2(cx + rx, cy + ry))


static func _append_line_points(markup: String, points: Array[Vector2]) -> void:
	for tag in _shape_tags(markup, "line"):
		points.append(Vector2(_svg_attr_float(tag, "x1", 0.0), _svg_attr_float(tag, "y1", 0.0)))
		points.append(Vector2(_svg_attr_float(tag, "x2", 0.0), _svg_attr_float(tag, "y2", 0.0)))


static func _shape_tags(markup: String, tag_name: String) -> Array[String]:
	var tags: Array[String] = []
	var regex := RegEx.new()
	regex.compile("<\\s*%s\\b[^>]*>" % tag_name)
	for match_result in regex.search_all(markup):
		tags.append(match_result.get_string(0))
	return tags


static func _svg_attr_float(tag: String, attribute: String, fallback: float) -> float:
	var regex := RegEx.new()
	regex.compile("\\b%s\\s*=\\s*['\\\"]([^'\\\"]+)['\\\"]" % attribute)
	var match_result = regex.search(tag)
	if match_result == null:
		return fallback
	return float(match_result.get_string(1))


static func _number_values(text: String) -> Array[float]:
	var values: Array[float] = []
	var regex := RegEx.new()
	regex.compile("[-+]?\\d*\\.?\\d+(?:[eE][-+]?\\d+)?")
	for match_result in regex.search_all(text):
		values.append(float(match_result.get_string(0)))
	return values


static func _path_tokens(path_data: String) -> Array[String]:
	var tokens: Array[String] = []
	var regex := RegEx.new()
	regex.compile("[AaCcHhLlMmQqSsTtVvZz]|[-+]?\\d*\\.?\\d+(?:[eE][-+]?\\d+)?")
	for match_result in regex.search_all(path_data):
		tokens.append(match_result.get_string(0))
	return tokens


static func _is_path_command(token: String) -> bool:
	return token.length() == 1 and "AaCcHhLlMmQqSsTtVvZz".contains(token)


static func _path_point(tokens: Array[String], index: int, relative: bool, current: Vector2) -> Vector2:
	var point = Vector2(float(tokens[index]), float(tokens[index + 1]))
	return current + point if relative else point


static func _transformed_rect(rect: Rect2, transform: Transform2D) -> Rect2:
	var corners = [
		rect.position,
		Vector2(rect.position.x + rect.size.x, rect.position.y),
		rect.position + rect.size,
		Vector2(rect.position.x, rect.position.y + rect.size.y),
	]
	var first_point: Vector2 = transform * corners[0]
	var min_point := first_point
	var max_point := first_point
	for corner in corners:
		var point: Vector2 = transform * corner
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	return Rect2(min_point, max_point - min_point)


static func _around_point_matrix(point: Vector2, matrix: Transform2D) -> Transform2D:
	return _translation_matrix(point) * matrix * _translation_matrix(-point)


static func _translation_matrix(offset: Vector2) -> Transform2D:
	return Transform2D(Vector2(1.0, 0.0), Vector2(0.0, 1.0), offset)


static func _rotation_matrix(degrees: float) -> Transform2D:
	return Transform2D(deg_to_rad(degrees), Vector2.ZERO)


static func _scale_matrix(scale: Vector2) -> Transform2D:
	return Transform2D(Vector2(scale.x, 0.0), Vector2(0.0, scale.y), Vector2.ZERO)


static func _skew_x_matrix(degrees: float) -> Transform2D:
	return Transform2D(Vector2(1.0, 0.0), Vector2(tan(deg_to_rad(degrees)), 1.0), Vector2.ZERO)


static func _transform_chain_for_target(repo: ContentRepository, variant: String, target: String, seen: Dictionary = {}) -> Array[String]:
	match target:
		"leftForearm":
			return ["leftArm", "leftForearm"]
		"leftHand":
			return ["leftArm", "leftForearm", "leftHand"]
		"rightForearm":
			return ["rightArm", "rightForearm"]
		"rightHand":
			return ["rightArm", "rightForearm", "rightHand"]
		"leftShank":
			return ["leftThigh", "leftShank"]
		"leftFoot":
			return ["leftThigh", "leftShank", "leftFoot"]
		"leftToe":
			return ["leftThigh", "leftShank", "leftFoot", "leftToe"]
		"rightShank":
			return ["rightThigh", "rightShank"]
		"rightFoot":
			return ["rightThigh", "rightShank", "rightFoot"]
		"rightToe":
			return ["rightThigh", "rightShank", "rightFoot", "rightToe"]
		"backHair", "frontHair", "face", "leftEye", "rightEye", "leftBrow", "rightBrow", "mouth", "nose", "leftEar", "rightEar", "horns":
			return ["head", target]
		"tail", "body", "hip", "head", "headNub", "torso", "neck", "leftArm", "rightArm", "leftThigh", "rightThigh":
			return [target]
	if seen.has(target):
		return [target]
	seen[target] = true
	var part = repo.body_part(variant, target)
	var parent_id = String(part.get("parentId", ""))
	if parent_id != "":
		var chain = _transform_chain_for_target(repo, variant, parent_id, seen)
		chain.append(target)
		return chain
	return [target]


static func _pivot_for(repo: ContentRepository, variant: String, part_id: String) -> Dictionary:
	var part = repo.body_part(variant, part_id)
	if not part.is_empty() and part.has("pivot"):
		return part["pivot"]
	return BASE_PIVOTS.get(part_id, {"x": 0.0, "y": 0.0})


static func _hidden_targets(repo: ContentRepository, outfit: Variant) -> Dictionary:
	var hidden := {}
	for item_id in outfit.equipped_item_ids:
		var item = repo.wardrobe_item(String(item_id))
		var visual = repo.equipment_visual(String(item.get("visualId", "")))
		for piece in visual.get("pieces", []):
			if bool(piece.get("hideBodyPart", false)):
				hidden[String(piece.get("target", ""))] = true
	return hidden


static func _pivot_overlay(repo: ContentRepository, variant: String) -> String:
	var markup := "<g class=\"rig-pivot-overlay\">"
	var ids := BASE_PIVOTS.keys()
	for part in repo.body_parts_for_variant(variant):
		var id = String(part.get("id", ""))
		if not ids.has(id):
			ids.append(id)
	for id in ids:
		var pivot = _pivot_for(repo, variant, id)
		markup += "<circle cx=\"%s\" cy=\"%s\" r=\"20\" fill=\"#ffad3b\" stroke=\"#17191c\" stroke-width=\"7\" opacity=\"0.82\"/>" % [_num(pivot["x"]), _num(pivot["y"])]
	return markup + "</g>"


static func _layer_overlay() -> String:
	var markup := "<g class=\"rig-layer-overlay\">"
	for index in range(LAYER_ORDER.size()):
		markup += "<text x=\"70\" y=\"%d\" fill=\"#17191c\" font-size=\"48\" font-weight=\"900\">%d. %s</text>" % [110 + index * 62, index + 1, LAYER_ORDER[index]]
	return markup + "</g>"


static func _adjust_color(value: String, delta: int) -> String:
	var color := Color.html(value)
	var red = clampi(int(round(color.r * 255.0)) + delta, 0, 255)
	var green = clampi(int(round(color.g * 255.0)) + delta, 0, 255)
	var blue = clampi(int(round(color.b * 255.0)) + delta, 0, 255)
	return "#%02x%02x%02x" % [red, green, blue]


static func _num(value: float) -> String:
	var text = "%.3f" % value
	while text.ends_with("0") and text.contains("."):
		text = text.substr(0, text.length() - 1)
	if text.ends_with("."):
		text = text.substr(0, text.length() - 1)
	return text


static func _escape_xml(value: String) -> String:
	return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")
