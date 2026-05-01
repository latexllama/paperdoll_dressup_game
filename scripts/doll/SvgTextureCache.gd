class_name SvgTextureCache
extends RefCounted

const MAX_TEXTURES := 160

var _textures: Dictionary = {}
var _order: Array[String] = []
var last_error := OK
var last_error_message := ""


func clear() -> void:
	_textures.clear()
	_order.clear()
	last_error = OK
	last_error_message = ""


func texture_from_svg(svg_markup: String, scale: float = 1.0) -> Texture2D:
	last_error = OK
	last_error_message = ""
	if not _is_valid_svg_document(svg_markup):
		last_error = ERR_INVALID_DATA
		last_error_message = "SVG texture source is not a complete SVG document."
		return null
	var safe_scale = maxf(0.05, scale)
	var cache_key = "%s:%s" % [svg_markup.md5_text(), snappedf(safe_scale, 0.001)]
	if _textures.has(cache_key):
		_touch(cache_key)
		return _textures[cache_key]
	var image := Image.new()
	var error = image.load_svg_from_string(svg_markup, safe_scale)
	if error != OK:
		last_error = error
		last_error_message = "Could not load SVG texture: %s" % error
		return null
	var texture = ImageTexture.create_from_image(image)
	_textures[cache_key] = texture
	_touch(cache_key)
	_evict_oldest()
	return texture


func _touch(cache_key: String) -> void:
	var index = _order.find(cache_key)
	if index >= 0:
		_order.remove_at(index)
	_order.append(cache_key)


func _evict_oldest() -> void:
	while _order.size() > MAX_TEXTURES:
		var oldest = _order.pop_front()
		_textures.erase(oldest)


func _is_valid_svg_document(svg_markup: String) -> bool:
	var trimmed = svg_markup.strip_edges()
	var lower = trimmed.to_lower()
	if lower.begins_with("<?xml"):
		var declaration_end = lower.find("?>")
		if declaration_end < 0:
			return false
		lower = lower.substr(declaration_end + 2).strip_edges()
	if not lower.begins_with("<svg") or not lower.ends_with("</svg>"):
		return false
	var parser := XMLParser.new()
	if parser.open_buffer(svg_markup.to_utf8_buffer()) != OK:
		return false
	var depth := 0
	var saw_root := false
	while true:
		var read_error = parser.read()
		if read_error == ERR_FILE_EOF:
			return saw_root and depth == 0
		if read_error != OK:
			return false
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				if not saw_root:
					if parser.get_node_name().to_lower() != "svg":
						return false
					saw_root = true
				if not parser.is_empty():
					depth += 1
			XMLParser.NODE_ELEMENT_END:
				depth -= 1
				if depth < 0:
					return false
	return false
