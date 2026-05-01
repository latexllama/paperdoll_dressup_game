class_name OutfitState
extends RefCounted

var variant := "female"
var pose_id := "idle"
var skin_tone := "#d28062"
var skin_line := "#8f4b38"
var hair_color := "#221a16"
var eye_color := "#222222"
var equipped_item_ids: Array[String] = []


func _init(data: Dictionary = {}) -> void:
	if not data.is_empty():
		apply_dictionary(data)


func apply_dictionary(data: Dictionary) -> void:
	variant = String(data.get("variant", "female"))
	pose_id = String(data.get("poseId", "idle"))
	skin_tone = String(data.get("skinTone", "#d28062"))
	skin_line = String(data.get("skinLine", "#8f4b38"))
	hair_color = String(data.get("hairColor", "#221a16"))
	eye_color = String(data.get("eyeColor", "#222222"))
	equipped_item_ids = []
	for item_id in data.get("equippedItemIds", []):
		equipped_item_ids.append(String(item_id))


func to_dictionary() -> Dictionary:
	return {
		"variant": variant,
		"poseId": pose_id,
		"skinTone": skin_tone,
		"skinLine": skin_line,
		"hairColor": hair_color,
		"eyeColor": eye_color,
		"equippedItemIds": equipped_item_ids.duplicate(),
	}


func duplicate_state() -> Variant:
	return get_script().new(to_dictionary())


func equip_item(item_id: String) -> void:
	if item_id == "":
		return
	equipped_item_ids.append(item_id)


func remove_first_item(item_id: String) -> bool:
	var index = equipped_item_ids.find(item_id)
	if index < 0:
		return false
	equipped_item_ids.remove_at(index)
	return true


func remove_last_item(item_id: String) -> bool:
	for index in range(equipped_item_ids.size() - 1, -1, -1):
		if equipped_item_ids[index] == item_id:
			equipped_item_ids.remove_at(index)
			return true
	return false


func remove_top_visible_item() -> String:
	if equipped_item_ids.is_empty():
		return ""
	return equipped_item_ids.pop_back()


func top_visible_item_id() -> String:
	if equipped_item_ids.is_empty():
		return ""
	return equipped_item_ids[equipped_item_ids.size() - 1]
