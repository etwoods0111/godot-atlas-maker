extends SceneTree

const PreviewTransform = preload("res://addons/godot_atlas_maker/preview_transform.gd")


func _init() -> void:
	var failures: Array[String] = []
	_test_converts_canvas_coordinates_back_to_atlas_space(failures)
	_test_preserves_cursor_focus_when_zooming(failures)
	_test_clamps_zoom_to_supported_range(failures)

	if failures.is_empty():
		print("PreviewTransform tests passed")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _test_converts_canvas_coordinates_back_to_atlas_space(failures: Array[String]) -> void:
	var atlas_position := PreviewTransform.canvas_to_atlas(Vector2(150, 90), 1.5)
	_expect_equal(atlas_position, Vector2(100, 60), "canvas coordinates should scale back into atlas space", failures)


func _test_preserves_cursor_focus_when_zooming(failures: Array[String]) -> void:
	var scroll := PreviewTransform.zoom_scroll_offset(Vector2(160, 120), Vector2(80, 50), 1.0, 1.5)
	_expect_equal(scroll, Vector2(200, 135), "zoom should keep the hovered atlas point under the cursor", failures)


func _test_clamps_zoom_to_supported_range(failures: Array[String]) -> void:
	_expect_equal(PreviewTransform.clamp_zoom(0.05), 0.25, "zoom should clamp to minimum value", failures)
	_expect_equal(PreviewTransform.clamp_zoom(5.5), 4.0, "zoom should clamp to maximum value", failures)


func _expect_equal(actual: Variant, expected: Variant, message: String, failures: Array[String]) -> void:
	if actual != expected:
		failures.append("%s. Expected %s, got %s" % [message, expected, actual])
