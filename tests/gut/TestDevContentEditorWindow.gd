extends GutTest


func test_close_request_hides_dev_editor_window() -> void:
	var editor = load("res://scenes/ui/DevContentEditor.tscn").instantiate()

	editor.visible = true
	editor._on_close_requested()

	assert_false(editor.visible)
	editor.free()
