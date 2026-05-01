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
	var payload: Dictionary = outfit.to_dictionary()
	var validation = ContentValidator.validate_outfit_data(null, payload)
	if not validation.get("ok", false):
		return validation
	var path = "%s/%s.json" % [OUTFIT_DIR, safe_name]
	var temp_path = "%s.tmp" % path
	var file = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "errors": ["Could not open temporary outfit file for writing."]}
	file.store_string(JSON.stringify(payload, "  ") + "\n")
	file.close()
	var replace_result = _replace_file_with_temp(temp_path, path)
	if not replace_result.get("ok", false):
		return replace_result
	return {"ok": true, "errors": [], "name": safe_name}


static func load_outfit(name: String, repo: ContentRepository = null) -> Dictionary:
	var safe_name = _safe_file_name(name)
	if safe_name == "":
		return {"ok": false, "errors": ["Outfit name is required."]}
	var path = "%s/%s.json" % [OUTFIT_DIR, safe_name]
	if not FileAccess.file_exists(path):
		return {"ok": false, "errors": ["Outfit file was not found."]}
	var text = FileAccess.get_file_as_string(path)
	var parser := JSON.new()
	var parse_error = parser.parse(text)
	if parse_error != OK:
		return {"ok": false, "errors": ["Outfit file is not valid JSON: %s at line %d" % [parser.get_error_message(), parser.get_error_line()]]}
	var parsed = parser.get_data()
	if not (parsed is Dictionary):
		return {"ok": false, "errors": ["Outfit file is not valid JSON."]}
	var validation = ContentValidator.validate_outfit_data(repo, parsed)
	if not validation.get("ok", false):
		return validation
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


static func outfit_exists(name: String) -> bool:
	var safe_name = _safe_file_name(name)
	if safe_name == "":
		return false
	return FileAccess.file_exists("%s/%s.json" % [OUTFIT_DIR, safe_name])


static func delete_outfit(name: String) -> Dictionary:
	var safe_name = _safe_file_name(name)
	if safe_name == "":
		return {"ok": false, "errors": ["Outfit name is required."]}
	var path = "%s/%s.json" % [OUTFIT_DIR, safe_name]
	if not FileAccess.file_exists(path):
		return {"ok": false, "errors": ["Outfit file was not found."]}
	var remove_error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if remove_error != OK:
		return {"ok": false, "errors": ["Could not delete outfit file: %s" % remove_error]}
	return {"ok": true, "errors": [], "name": safe_name}


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


static func _replace_file_with_temp(temp_path: String, final_path: String) -> Dictionary:
	var temp_abs = ProjectSettings.globalize_path(temp_path)
	var final_abs = ProjectSettings.globalize_path(final_path)
	var backup_abs = "%s.bak" % final_abs
	if FileAccess.file_exists(backup_abs):
		var remove_backup_error = DirAccess.remove_absolute(backup_abs)
		if remove_backup_error != OK:
			return {"ok": false, "errors": ["Could not remove old outfit backup: %s" % remove_backup_error]}
	if FileAccess.file_exists(final_path):
		var backup_error = DirAccess.rename_absolute(final_abs, backup_abs)
		if backup_error != OK:
			DirAccess.remove_absolute(temp_abs)
			return {"ok": false, "errors": ["Could not create outfit backup: %s" % backup_error]}
	var replace_error = DirAccess.rename_absolute(temp_abs, final_abs)
	if replace_error != OK:
		if FileAccess.file_exists(backup_abs):
			DirAccess.rename_absolute(backup_abs, final_abs)
		DirAccess.remove_absolute(temp_abs)
		return {"ok": false, "errors": ["Could not replace outfit file: %s" % replace_error]}
	if FileAccess.file_exists(backup_abs):
		DirAccess.remove_absolute(backup_abs)
	return {"ok": true, "errors": []}
