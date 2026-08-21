extends SceneTree

const PanelScene = preload("res://addons/godot_atlas_maker/atlas_maker_panel.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var panel = PanelScene.instantiate()
	root.add_child(panel)
	await process_frame
	await process_frame

	var image := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var loaded_images: Array[Dictionary] = []
	loaded_images.append({"name": "source", "texture": texture, "rect": Rect2(0, 0, 20, 20)})
	loaded_images.append({"name": "target", "texture": texture, "rect": Rect2(0, 0, 20, 20)})
	panel.loaded_images = loaded_images
	panel.atlas_size = Vector2i(64, 64)
	var atlas_pages: Array[Dictionary] = []
	atlas_pages.append({"item_indices": [0], "rects_by_index": {0: Rect2i(0, 0, 20, 20)}})
	atlas_pages.append({"item_indices": [1], "rects_by_index": {1: Rect2i(0, 0, 20, 20)}})
	panel.atlas_pages = atlas_pages
	panel.preview_page_index = 0
	panel.selected_sprite = {"image_index": 0, "page_index": 0}
	panel._on_move_target_page_selected(1)

	_expect_equal(panel.atlas_pages.size(), 1, "moving the only item should remove its empty source page", failures)
	_expect_equal(panel.preview_page_index, 0, "panel should select the remaining target page", failures)
	_expect_equal(panel.selected_sprite.get("page_index", -1), 0, "moved item should remain selected on the remaining page", failures)
	_expect_equal(panel.atlas_pages[0].get("item_indices", []), [1, 0], "remaining page should include the moved item", failures)
	_test_shows_feedback_when_target_page_has_no_space(panel, texture, failures)

	panel.queue_free()
	if failures.is_empty():
		print("AtlasMakerPanel page move tests passed")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _expect_equal(actual: Variant, expected: Variant, message: String, failures: Array[String]) -> void:
	if actual != expected:
		failures.append("%s. Expected %s, got %s" % [message, expected, actual])


func _test_shows_feedback_when_target_page_has_no_space(panel, texture: Texture2D, failures: Array[String]) -> void:
	var loaded_images: Array[Dictionary] = []
	loaded_images.append({"name": "source", "texture": texture, "rect": Rect2(0, 0, 20, 20)})
	loaded_images.append({"name": "full", "texture": texture, "rect": Rect2(0, 0, 64, 64)})
	panel.loaded_images = loaded_images
	var atlas_pages: Array[Dictionary] = []
	atlas_pages.append({"item_indices": [0], "rects_by_index": {0: Rect2i(0, 0, 20, 20)}})
	atlas_pages.append({"item_indices": [1], "rects_by_index": {1: Rect2i(0, 0, 64, 64)}})
	panel.atlas_pages = atlas_pages
	panel.preview_page_index = 0
	panel.selected_sprite = {"image_index": 0, "page_index": 0}
	panel._on_move_target_page_selected(1)

	_expect_true(panel.preview_feedback_label.visible, "full target page should show visible feedback", failures)
	_expect_equal(panel.preview_feedback_label.text, "目标图集页没有足够空间，素材位置未改变。", "feedback should explain that the sprite was not moved", failures)
	_expect_equal(panel.atlas_pages.size(), 2, "failed move should retain both pages", failures)


func _expect_true(value: bool, message: String, failures: Array[String]) -> void:
	if not value:
		failures.append(message)
