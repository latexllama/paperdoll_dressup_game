class_name SvgSafety
extends RefCounted

const UNSAFE_CONTAINS := [
	"<script",
	"<foreignobject",
	"<iframe",
	"<object",
	"<embed",
	"<image",
	"javascript:",
	"data:",
	"file:",
	"xlink:href=\"http",
	"xlink:href='http",
	"href=\"http",
	"href='http",
	"href=\"//",
	"href='//",
]


static func is_safe_markup(markup: String) -> bool:
	var lower = markup.to_lower()
	for needle in UNSAFE_CONTAINS:
		if lower.contains(needle):
			return false
	var unsafe_element := RegEx.new()
	unsafe_element.compile("<\\s*(script|foreignobject|iframe|object|embed|image)\\b")
	if unsafe_element.search(lower) != null:
		return false
	var event_handler := RegEx.new()
	event_handler.compile("\\son[a-z]+\\s*=")
	if event_handler.search(lower) != null:
		return false
	var reference_attr := RegEx.new()
	reference_attr.compile("(xlink:href|href|src)\\s*=\\s*([\"'])\\s*([^\"']+)\\2")
	for match in reference_attr.search_all(lower):
		if _is_unsafe_reference(match.get_string(3)):
			return false
	var css_url := RegEx.new()
	css_url.compile("url\\s*\\(\\s*([\"']?)\\s*([^\"'\\)]+)")
	for match in css_url.search_all(lower):
		if _is_unsafe_reference(match.get_string(2)):
			return false
	return true


static func first_error(markup: String) -> String:
	if is_safe_markup(markup):
		return ""
	return "SVG markup contains scripts, external references, embedded images, event handlers, or unsafe protocols."


static func _is_unsafe_reference(value: String) -> bool:
	var normalized = value.strip_edges().to_lower()
	return normalized.begins_with("http:") \
		or normalized.begins_with("https:") \
		or normalized.begins_with("//") \
		or normalized.begins_with("data:") \
		or normalized.begins_with("javascript:") \
		or normalized.begins_with("file:")
