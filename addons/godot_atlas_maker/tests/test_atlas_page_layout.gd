extends SceneTree

const AtlasPageLayout = preload("res://addons/godot_atlas_maker/atlas_page_layout.gd")


func _init() -> void:
	var failures: Array[String] = []
	_test_moves_item_between_pages_without_mutating_on_rejection(failures)
	_test_moves_item_to_first_available_target_position(failures)
	_test_removes_source_page_when_a_move_leaves_it_empty(failures)
	_test_arrange_preserves_page_membership(failures)
	_test_resize_rejects_overlap_without_mutating(failures)

	if failures.is_empty():
		print("AtlasPageLayout tests passed")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _test_moves_item_between_pages_without_mutating_on_rejection(failures: Array[String]) -> void:
	var layout = _create_two_page_layout()

	_expect_true(
		layout.move_item(0, 1, Rect2i(24, 0, 20, 20)).get("ok", false),
		"legal cross-page move should succeed",
		failures
	)
	_expect_equal(layout.get_item_page(0), 1, "moved item should belong to target page", failures)
	_expect_equal(layout.get_page_item_indices(0), [1], "source page should no longer contain moved item", failures)
	_expect_equal(layout.get_page_item_indices(1), [2, 0], "target page should append moved item", failures)

	var before = layout.to_pages()
	_expect_true(
		not layout.move_item(1, 1, Rect2i(0, 0, 20, 20)).get("ok", true),
		"overlapping target drop should be rejected",
		failures
	)
	_expect_equal(layout.to_pages(), before, "rejected move must not mutate page data", failures)


func _test_moves_item_to_first_available_target_position(failures: Array[String]) -> void:
	var layout = _create_two_page_layout()
	var result: Dictionary = layout.move_item_to_first_fit(0, 1)
	_expect_true(result.get("ok", false), "button move should find a free position in the target page", failures)
	_expect_equal(layout.get_item_page(0), 1, "button move should change page membership", failures)
	_expect_equal(layout.get_item_rect(0), Rect2i(20, 0, 20, 20), "button move should use the first free target position", failures)

	var full_layout = AtlasPageLayout.new()
	full_layout.configure(
		Vector2i(20, 20),
		0,
		[Vector2i(20, 20), Vector2i(20, 20)],
		[
			{"item_indices": [0], "rects_by_index": {0: Rect2i(0, 0, 20, 20)}},
			{"item_indices": [1], "rects_by_index": {1: Rect2i(0, 0, 20, 20)}},
		]
	)
	var before := full_layout.to_pages()
	_expect_true(not full_layout.move_item_to_first_fit(0, 1).get("ok", true), "button move should reject a full target page", failures)
	_expect_equal(full_layout.to_pages(), before, "rejected button move must not mutate page data", failures)


func _test_removes_source_page_when_a_move_leaves_it_empty(failures: Array[String]) -> void:
	var layout = AtlasPageLayout.new()
	layout.configure(
		Vector2i(64, 64),
		0,
		[Vector2i(20, 20), Vector2i(20, 20)],
		[
			{"item_indices": [0], "rects_by_index": {0: Rect2i(0, 0, 20, 20)}},
			{"item_indices": [1], "rects_by_index": {1: Rect2i(0, 0, 20, 20)}},
		]
	)

	var result: Dictionary = layout.move_item_to_first_fit(0, 1)
	_expect_true(result.get("ok", false), "move should succeed before removing an empty source page", failures)
	_expect_true(result.get("source_page_removed", false), "move should report that its empty source page was removed", failures)
	_expect_equal(result.get("target_page", -1), 0, "target page index should be adjusted after source page removal", failures)
	_expect_equal(layout.page_count(), 1, "an empty source page should be removed", failures)
	_expect_equal(layout.get_page_item_indices(0), [1, 0], "remaining page should retain both items", failures)


func _test_arrange_preserves_page_membership(failures: Array[String]) -> void:
	var layout = _create_two_page_layout()
	_expect_true(layout.move_item(0, 1, Rect2i(24, 0, 20, 20)).get("ok", false), "move fixture should succeed", failures)
	var page_one_members = layout.get_page_item_indices(0)
	var page_two_members = layout.get_page_item_indices(1)

	_expect_true(layout.arrange_pages().get("ok", false), "page-local arrangement should succeed", failures)
	_expect_equal(layout.get_page_item_indices(0), page_one_members, "page one membership should be retained", failures)
	_expect_equal(layout.get_page_item_indices(1), page_two_members, "page two membership should retain moved item", failures)


func _test_resize_rejects_overlap_without_mutating(failures: Array[String]) -> void:
	var layout = AtlasPageLayout.new()
	layout.configure(
		Vector2i(64, 64),
		0,
		[Vector2i(20, 10), Vector2i(20, 10)],
		[
			{
				"item_indices": [0, 1],
				"rects_by_index": {
					0: Rect2i(0, 0, 20, 10),
					1: Rect2i(40, 0, 20, 10),
				},
			},
		]
	)

	_expect_true(layout.resize_item(0, Rect2i(0, 0, 30, 15)).get("ok", false), "legal scaled rectangle should apply", failures)
	_expect_equal(layout.get_item_rect(0), Rect2i(0, 0, 30, 15), "layout must retain scaled rectangle", failures)
	var before = layout.to_pages()
	_expect_true(
		not layout.resize_item(0, Rect2i(0, 0, 60, 30)).get("ok", true),
		"overlapping resize should be rejected",
		failures
	)
	_expect_equal(layout.to_pages(), before, "rejected resize must not mutate page data", failures)


func _create_two_page_layout():
	var layout = AtlasPageLayout.new()
	layout.configure(
		Vector2i(64, 64),
		0,
		[Vector2i(20, 20), Vector2i(20, 20), Vector2i(20, 20)],
		[
			{
				"item_indices": [0, 1],
				"rects_by_index": {
					0: Rect2i(0, 0, 20, 20),
					1: Rect2i(24, 0, 20, 20),
				},
			},
			{
				"item_indices": [2],
				"rects_by_index": {
					2: Rect2i(0, 0, 20, 20),
				},
			},
		]
	)
	return layout


func _expect_true(value: bool, message: String, failures: Array[String]) -> void:
	if not value:
		failures.append(message)


func _expect_equal(actual: Variant, expected: Variant, message: String, failures: Array[String]) -> void:
	if actual != expected:
		failures.append("%s. Expected %s, got %s" % [message, expected, actual])
