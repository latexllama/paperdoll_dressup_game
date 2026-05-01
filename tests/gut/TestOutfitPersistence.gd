extends GutTest

const OutfitStateScript := preload("res://scripts/game/OutfitState.gd")
const OutfitPersistenceScript := preload("res://scripts/game/OutfitPersistence.gd")
const TEST_OUTFIT_NAME := "gut_test_outfit"
const INVALID_OUTFIT_NAME := "gut_invalid_outfit"


func after_all() -> void:
	var path = ProjectSettings.globalize_path("user://outfits/%s.json" % TEST_OUTFIT_NAME)
	if FileAccess.file_exists("user://outfits/%s.json" % TEST_OUTFIT_NAME):
		DirAccess.remove_absolute(path)
	var invalid_path = ProjectSettings.globalize_path("user://outfits/%s.json" % INVALID_OUTFIT_NAME)
	if FileAccess.file_exists("user://outfits/%s.json" % INVALID_OUTFIT_NAME):
		DirAccess.remove_absolute(invalid_path)


func test_outfit_save_and_load_round_trip() -> void:
	var outfit = OutfitStateScript.new()
	outfit.variant = "male"
	outfit.pose_id = "wave"
	outfit.equip_item("plain-tee")
	outfit.equip_item("clean-sneakers")

	var save_result = OutfitPersistenceScript.save_outfit(TEST_OUTFIT_NAME, outfit)
	assert_true(save_result.get("ok", false), "; ".join(save_result.get("errors", [])))

	var load_result = OutfitPersistenceScript.load_outfit(TEST_OUTFIT_NAME)
	assert_true(load_result.get("ok", false), "; ".join(load_result.get("errors", [])))
	var loaded = load_result["outfit"]
	assert_eq(loaded.variant, "male")
	assert_eq(loaded.pose_id, "wave")
	assert_eq(loaded.equipped_item_ids, ["plain-tee", "clean-sneakers"])


func test_outfit_load_rejects_missing_repository_references() -> void:
	var repo := ContentRepository.new()
	var validation = repo.load_all()
	assert_true(validation.get("ok", false), "; ".join(validation.get("errors", [])))
	var directory_path = ProjectSettings.globalize_path("user://outfits")
	DirAccess.make_dir_recursive_absolute(directory_path)
	var file = FileAccess.open("user://outfits/%s.json" % INVALID_OUTFIT_NAME, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"variant": "female",
		"poseId": "missing-pose",
		"skinTone": "#d28062",
		"skinLine": "#8f4b38",
		"hairColor": "#221a16",
		"eyeColor": "#222222",
		"equippedItemIds": ["missing-item"],
	}, "  "))
	file.close()

	var result = OutfitPersistenceScript.load_outfit(INVALID_OUTFIT_NAME, repo)

	assert_false(result.get("ok", true))
	assert_string_contains("; ".join(result.get("errors", [])), "missing pose")
	assert_string_contains("; ".join(result.get("errors", [])), "missing wardrobe item")
