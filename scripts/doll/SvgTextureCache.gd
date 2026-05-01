class_name SvgTextureCache
extends RefCounted

const MAX_TEXTURES := 160

var _textures: Dictionary = {}
var _order: Array[String] = []


func clear() -> void:
	_textures.clear()
	_order.clear()


func texture_from_svg(svg_markup: String, scale: float = 1.0) -> Texture2D:
	var safe_scale = maxf(0.05, scale)
	var cache_key = "%s:%s" % [svg_markup.md5_text(), snappedf(safe_scale, 0.001)]
	if _textures.has(cache_key):
		_touch(cache_key)
		return _textures[cache_key]
	var image := Image.new()
	var error = image.load_svg_from_string(svg_markup, safe_scale)
	if error != OK:
		push_warning("Could not load SVG texture: %s" % error)
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
