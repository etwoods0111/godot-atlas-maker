extends SceneTree

const AtlasPacker = preload("res://addons/godot_atlas_maker/atlas_packer.gd")


func _init() -> void:
	var failures: Array[String] = []
	_test_reuses_empty_space_between_rows(failures)
	_test_allows_item_that_fits_inside_border_padding(failures)
	_test_reports_items_that_cannot_fit(failures)
	_test_splits_overflow_into_multiple_pages(failures)

	if failures.is_empty():
		print("AtlasPacker tests passed")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _test_reuses_empty_space_between_rows(failures: Array[String]) -> void:
	var sizes: Array[Vector2i] = [
		Vector2i(60, 60),
		Vector2i(40, 30),
		Vector2i(40, 30),
		Vector2i(40, 30),
		Vector2i(40, 30),
	]
	var result: Dictionary = AtlasPacker.pack(sizes, Vector2i(100, 90), 0)
	var rects: Array = result.get("rects", [])

	_expect_equal(rects.size(), sizes.size(), "should place every rectangle in compact fixture", failures)
	_expect_equal(result.get("unplaced_indices", []).size(), 0, "should not report unplaced rectangles", failures)
	_expect_valid_layout(rects, Vector2i(100, 90), failures)


func _test_reports_items_that_cannot_fit(failures: Array[String]) -> void:
	var sizes: Array[Vector2i] = [
		Vector2i(80, 80),
		Vector2i(30, 30),
	]
	var result: Dictionary = AtlasPacker.pack(sizes, Vector2i(90, 90), 2)
	var unplaced: Array = result.get("unplaced_indices", [])

	_expect_equal(unplaced, [1], "should report indices that cannot be packed", failures)


func _test_allows_item_that_fits_inside_border_padding(failures: Array[String]) -> void:
	var sizes: Array[Vector2i] = [Vector2i(86, 86)]
	var result: Dictionary = AtlasPacker.pack(sizes, Vector2i(90, 90), 2)
	var rects: Array = result.get("rects", [])
	var unplaced: Array = result.get("unplaced_indices", [])

	_expect_equal(unplaced.size(), 0, "should allow an item that exactly fits after border padding", failures)
	_expect_equal(rects[0], Rect2i(2, 2, 86, 86), "should keep the configured border padding", failures)


func _test_splits_overflow_into_multiple_pages(failures: Array[String]) -> void:
	var sizes: Array[Vector2i] = [
		Vector2i(80, 80),
		Vector2i(80, 80),
		Vector2i(80, 80),
	]
	var result: Dictionary = AtlasPacker.pack_multiple(sizes, Vector2i(90, 90), 2)
	var pages: Array = result.get("pages", [])
	var unplaced: Array = result.get("unplaced_indices", [])

	_expect_equal(pages.size(), 3, "should split overflowing items into separate atlas pages", failures)
	_expect_equal(unplaced.size(), 0, "all page-sized items should be placeable across pages", failures)


func _expect_valid_layout(rects: Array, atlas_size: Vector2i, failures: Array[String]) -> void:
	for i: int in rects.size():
		var rect: Rect2i = rects[i]
		if rect.position.x < 0 or rect.position.y < 0:
			failures.append("rect %d starts outside the atlas: %s" % [i, rect])
		if rect.end.x > atlas_size.x or rect.end.y > atlas_size.y:
			failures.append("rect %d exceeds atlas bounds: %s" % [i, rect])

		for j: int in range(i + 1, rects.size()):
			if rect.intersects(rects[j]):
				failures.append("rect %d overlaps rect %d: %s vs %s" % [i, j, rect, rects[j]])


func _expect_equal(actual: Variant, expected: Variant, message: String, failures: Array[String]) -> void:
	if actual != expected:
		failures.append("%s. Expected %s, got %s" % [message, expected, actual])
