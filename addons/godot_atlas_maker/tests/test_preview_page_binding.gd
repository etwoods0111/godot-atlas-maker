extends SceneTree

const PreviewPageBinding = preload("res://addons/godot_atlas_maker/preview_page_binding.gd")


func _init() -> void:
	var failures: Array[String] = []
	_expect_equal(PreviewPageBinding.resolve_page_index(0, 2, false), 2, "single canvas should show the selected page", failures)
	_expect_equal(PreviewPageBinding.resolve_page_index(0, 2, true), 0, "first side-by-side canvas should show page one", failures)
	_expect_equal(PreviewPageBinding.resolve_page_index(2, 0, true), 2, "side-by-side canvas should show its bound page", failures)

	if failures.is_empty():
		print("PreviewPageBinding tests passed")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _expect_equal(actual: Variant, expected: Variant, message: String, failures: Array[String]) -> void:
	if actual != expected:
		failures.append("%s. Expected %s, got %s" % [message, expected, actual])
