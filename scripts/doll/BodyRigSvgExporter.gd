class_name BodyRigSvgExporter
extends RefCounted

const ACTOR_WIDTH := 2400.0
const ACTOR_HEIGHT := 3100.0
const DEFAULT_BASE_SCALE := 1.58
const DEFAULT_ACTOR_OFFSET_Y := 88.0
const SOURCE_BASE := "base"
const SOURCE_VARIATION_PREFIX := "variation-"
const SOURCE_LATTICE_PREFIX := "lattice-"

const TEMPLATE_COLOR_TOKENS := {
	"--doll-skin": "#d28062",
	"--doll-skin-shadow": "#b8664b",
	"--doll-skin-contour": "#9f543f",
	"--doll-line": "#6a332a",
	"--doll-hair": "#111111",
	"--doll-hair-shadow": "#050505",
	"--doll-eye": "#222222",
}


static func build_part_template_svg(repo: ContentRepository, variant_id: String, part: Dictionary, source_id: String, source_markup: String) -> String:
	var part_markup := _part_group_svg(repo, variant_id, part, source_id, source_markup)
	return _document_svg(variant_id, part_markup)


static func build_variant_template_svg(repo: ContentRepository, variant_id: String, selected_part_id: String, selected_source_id: String, selected_source_markup: String) -> String:
	var parts_by_layer := {}
	for layer_id in DollSvgBuilder.LAYER_ORDER:
		parts_by_layer[layer_id] = []
	if repo == null:
		return _document_svg(variant_id, "")
	for part in repo.body_parts_for_variant(variant_id):
		if not part is Dictionary:
			continue
		var part_id := String(part.get("id", ""))
		var source_id := SOURCE_BASE
		var source_markup := String(part.get("svgMarkup", ""))
		if part_id == selected_part_id:
			source_id = _normalized_source_id(selected_source_id)
			source_markup = selected_source_markup
		var layer_id := String(part.get("layer", "body"))
		if not parts_by_layer.has(layer_id):
			layer_id = "body"
		parts_by_layer[layer_id].append(_part_group_svg(repo, variant_id, part, source_id, source_markup))
	var layer_markup := PackedStringArray()
	for layer_id in DollSvgBuilder.LAYER_ORDER:
		var part_groups: Array = parts_by_layer.get(layer_id, [])
		if part_groups.is_empty():
			continue
		layer_markup.append(
			"<g id=\"%s\" data-layer=\"%s\">\n%s</g>"
			% [
				_escape_attr("layer-%s" % layer_id),
				_escape_attr(layer_id),
				"\n".join(part_groups),
			]
		)
	return _document_svg(variant_id, "\n".join(layer_markup))


static func resolve_selected_source(part: Dictionary, selected_svg_variation_id: String, selected_lattice_id: String) -> Dictionary:
	var lattice_variations := _dictionary_or_empty(part.get("latticeVariations", {}))
	if selected_lattice_id != "" and lattice_variations.has(selected_lattice_id):
		var lattice_variation := _dictionary_or_empty(lattice_variations.get(selected_lattice_id, {}))
		var lattice_source := _source_markup_for_lattice(part, lattice_variation)
		return {
			"id": "%s%s" % [SOURCE_LATTICE_PREFIX, selected_lattice_id],
			"markup": Lattice.apply_lattice_to_svg_markup(lattice_source, lattice_variation),
		}
	var svg_variations := _dictionary_or_empty(part.get("variations", {}))
	if selected_svg_variation_id != "" and svg_variations.has(selected_svg_variation_id):
		return {
			"id": "%s%s" % [SOURCE_VARIATION_PREFIX, selected_svg_variation_id],
			"markup": String(svg_variations.get(selected_svg_variation_id, "")),
		}
	return {
		"id": SOURCE_BASE,
		"markup": String(part.get("svgMarkup", "")),
	}


static func write_svg(file_path: String, svg_markup: String) -> Dictionary:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return {
			"ok": false,
			"errors": ["Could not open SVG export file '%s': %s" % [file_path, error_string(FileAccess.get_open_error())]],
		}
	file.store_string(svg_markup)
	file.close()
	return {"ok": true, "errors": []}


static func default_part_file_name(variant_id: String, part_id: String, source_id: String) -> String:
	return "%s_%s_%s.svg" % [
		_safe_file_token(variant_id),
		_safe_file_token(part_id),
		_safe_file_token(_normalized_source_id(source_id)),
	]


static func default_variant_file_name(variant_id: String) -> String:
	return "%s_body_rig_template.svg" % _safe_file_token(variant_id)


static func _document_svg(variant_id: String, body_markup: String) -> String:
	return "\n".join([
		"<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
		"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\">" % [
			int(ACTOR_WIDTH),
			int(ACTOR_HEIGHT),
			int(ACTOR_WIDTH),
			int(ACTOR_HEIGHT),
		],
		"<rect x=\"0\" y=\"0\" width=\"%d\" height=\"%d\" fill=\"none\"/>" % [int(ACTOR_WIDTH), int(ACTOR_HEIGHT)],
		"<g id=\"%s\" data-variant=\"%s\" data-template=\"body-rig\">"
		% [
			_escape_attr("body-rig-template-%s" % variant_id),
			_escape_attr(variant_id),
		],
		body_markup,
		"</g>",
		"</svg>",
		"",
	])


static func _part_group_svg(repo: ContentRepository, variant_id: String, part: Dictionary, source_id: String, source_markup: String) -> String:
	var part_id := String(part.get("id", ""))
	var layer_id := String(part.get("layer", "body"))
	var source_key := _normalized_source_id(source_id)
	var markup := _materialize_template_tokens(source_markup)
	return "<g id=\"%s\" data-variant=\"%s\" data-rig-part=\"%s\" data-layer=\"%s\" data-source-id=\"%s\" transform=\"%s\">\n%s\n</g>" % [
		_escape_attr("%s-%s-%s" % [variant_id, part_id, source_key]),
		_escape_attr(variant_id),
		_escape_attr(part_id),
		_escape_attr(layer_id),
		_escape_attr(source_key),
		_escape_attr(_actor_space_transform(repo, variant_id)),
		markup,
	]


static func _actor_space_transform(repo: ContentRepository, variant_id: String) -> String:
	var source := {}
	if repo != null:
		source = _dictionary_or_empty(_dictionary_or_empty(repo.sample_meta.get("variants", {})).get(variant_id, {}))
	var view_box := _dictionary_or_empty(source.get("viewBox", source))
	var base_scale := float(source.get("baseScale", DEFAULT_BASE_SCALE))
	var width := float(view_box.get("width", ACTOR_WIDTH))
	var x := float(view_box.get("x", 0.0))
	var y := float(view_box.get("y", 0.0))
	var scaled_width := width * base_scale
	var offset_x := (ACTOR_WIDTH - scaled_width) / 2.0 - x * base_scale
	var offset_y := DEFAULT_ACTOR_OFFSET_Y - y * base_scale
	return "translate(%s 0) scale(1 1) translate(%s 0) translate(%s %s) scale(%s)" % [
		_num(ACTOR_WIDTH),
		_num(-ACTOR_WIDTH),
		_num(offset_x),
		_num(offset_y),
		_num(base_scale),
	]


static func _source_markup_for_lattice(part: Dictionary, lattice_variation: Dictionary) -> String:
	var source_variation_id := String(lattice_variation.get("sourceVariationId", ""))
	if source_variation_id == "":
		return String(part.get("svgMarkup", ""))
	var variations := _dictionary_or_empty(part.get("variations", {}))
	return String(variations.get(source_variation_id, part.get("svgMarkup", "")))


static func _materialize_template_tokens(markup: String) -> String:
	var rendered := markup
	for token in TEMPLATE_COLOR_TOKENS.keys():
		rendered = rendered.replace("var(%s)" % token, String(TEMPLATE_COLOR_TOKENS[token]))
	return rendered


static func _normalized_source_id(source_id: String) -> String:
	var value := source_id.strip_edges()
	if value == "":
		return SOURCE_BASE
	return value


static func _dictionary_or_empty(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


static func _safe_file_token(value: String) -> String:
	var token := PackedStringArray()
	for index in value.length():
		var character := value.substr(index, 1)
		if character.is_valid_identifier() or character.is_valid_int() or character == "-" or character == "_":
			token.append(character)
		else:
			token.append("_")
	var joined := "".join(token).strip_edges()
	if joined == "":
		return "export"
	return joined


static func _escape_attr(value: String) -> String:
	return value.replace("&", "&amp;").replace("\"", "&quot;").replace("<", "&lt;").replace(">", "&gt;")


static func _num(value: float) -> String:
	if abs(value - roundf(value)) < 0.001:
		return str(int(roundf(value)))
	var text := "%.3f" % value
	while text.ends_with("0"):
		text = text.substr(0, text.length() - 1)
	if text.ends_with("."):
		text = text.substr(0, text.length() - 1)
	return text
