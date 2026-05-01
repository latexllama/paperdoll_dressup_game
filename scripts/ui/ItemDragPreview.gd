class_name ItemDragPreview
extends RefCounted

const PREVIEW_SIZE := Vector2(132.0, 132.0)
const ICON_RECT := Rect2(10.0, 10.0, 112.0, 88.0)
const LABEL_RECT := Rect2(8.0, 100.0, 116.0, 24.0)


static func make(texture: Texture2D, item_name: String) -> Control:
	var root := Control.new()
	root.custom_minimum_size = PREVIEW_SIZE
	root.size = PREVIEW_SIZE
	root.clip_contents = true
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel := PanelContainer.new()
	panel.custom_minimum_size = PREVIEW_SIZE
	panel.size = PREVIEW_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)

	var icon := TextureRect.new()
	icon.position = ICON_RECT.position
	icon.size = ICON_RECT.size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = texture
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon)

	var label := Label.new()
	label.position = LABEL_RECT.position
	label.size = LABEL_RECT.size
	label.text = item_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)

	return root
