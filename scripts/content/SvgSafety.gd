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
	var event_handler := RegEx.new()
	event_handler.compile("\\son[a-z]+\\s*=")
	return event_handler.search(lower) == null


static func first_error(markup: String) -> String:
	if is_safe_markup(markup):
		return ""
	return "SVG markup contains scripts, external references, embedded images, event handlers, or unsafe protocols."
