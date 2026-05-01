class_name SvgTextureCache
extends RefCounted

var _textures: Dictionary = {}


func clear() -> void:
	_textures.clear()


func texture_from_svg(svg_markup: String, scale: float = 1.0) -> Texture2D:
	var safe_scale = maxf(0.05, scale)
	var cache_key = "%s:%s" % [svg_markup.md5_text(), snappedf(safe_scale, 0.001)]
	if _textures.has(cache_key):
		return _textures[cache_key]
	var image := Image.new()
	var error = image.load_svg_from_string(svg_markup, safe_scale)
	if error != OK:
		push_warning("Could not load SVG texture: %s" % error)
		return null
	var texture = ImageTexture.create_from_image(image)
	_textures[cache_key] = texture
	return texture
