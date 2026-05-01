class_name OutfitPersistence
extends RefCounted

const OUTFIT_DIR := "user://outfits"
const OutfitStateScript := preload("res://scripts/game/OutfitState.gd")


static func save_outfit(name: String, outfit: Variant) -> Dictionary:
	var safe_name = _safe_file_name(name)
	if safe_name == "":
		return {"ok": false, "errors": ["Outfit name is required."]}
	var directory_path = ProjectSettings.globalize_path(OUTFIT_DIR)
	var directory_error = DirAccess.make_dir_recursive_absolute(directory_path)
	if directory_error != OK:
		return {"ok": false, "errors": ["Could not create outfit directory."]}
	var file = FileAccess.open("%s/%s.json" % [OUTFIT_DIR, safe_name], FileAccess.WRITE)
	if file == null:
		return {"ok": false, "errors": ["Could not open outfit file for writing."]}
	file.store_string(JSON.stringify(outfit.to_dictionary(), "  ") + "\n")
	file.close()
	return {"ok": true, "errors": [], "name": safe_name}


static func load_outfit(name: String) -> Dictionary:
	var safe_name = _safe_file_name(name)
	if safe_name == "":
		return {"ok": false, "errors": ["Outfit name is required."]}
	var path = "%s/%s.json" % [OUTFIT_DIR, safe_name]
	if not FileAccess.file_exists(path):
		return {"ok": false, "errors": ["Outfit file was not found."]}
	var text = FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {"ok": false, "errors": ["Outfit file is not valid JSON."]}
	return {"ok": true, "errors": [], "outfit": OutfitStateScript.new(parsed)}


static func list_outfits() -> Array[String]:
	var names: Array[String] = []
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(OUTFIT_DIR)):
		return names
	var directory = DirAccess.open(OUTFIT_DIR)
	if directory == null:
		return names
	directory.list_dir_begin()
	var file_name = directory.get_next()
	while file_name != "":
		if not directory.current_is_dir() and file_name.ends_with(".json"):
			names.append(file_name.trim_suffix(".json"))
		file_name = directory.get_next()
	directory.list_dir_end()
	names.sort()
	return names


static func _safe_file_name(name: String) -> String:
	var trimmed = name.strip_edges()
	var result := ""
	for index in range(trimmed.length()):
		var character = trimmed[index]
		var code = character.unicode_at(0)
		var is_letter = (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		var is_digit = code >= 48 and code <= 57
		if is_letter or is_digit or character == "_" or character == "-" or character == " ":
			result += character
	result = result.replace(" ", "_")
	return result.substr(0, 64)
