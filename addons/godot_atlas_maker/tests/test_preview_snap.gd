extends SceneTree

const PreviewSnap = preload("res://addons/godot_atlas_maker/preview_snap.gd")


func _init() -> void:
	var failures: Array[String] = []
	_test_snaps_to_atlas_edges(failures)
	_test_snaps_to_neighbor_edges(failures)
	_test_keeps_position_when_outside_threshold(failures)

	if failures.is_empty():
		print("PreviewSnap tests passed")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _test_snaps_to_atlas_edges(failures: Array[String]) -> void:
	var snapped := PreviewSnap.snap_position(Vector2(5, 93), Vector2(20, 20), Vector2(120, 120), [], 8.0)
	_expect_equal(snapped, Vector2(0, 100), "dragged rect should snap to atlas left and bottom edges", failures)


func _test_snaps_to_neighbor_edges(failures: Array[String]) -> void:
	var other_rects: Array = [Rect2(40, 20, 20, 30)]
	var snapped := PreviewSnap.snap_position(Vector2(62, 18), Vector2(15, 15), Vector2(120, 120), other_rects, 8.0)
	_expect_equal(snapped, Vector2(60, 20), "dragged rect should snap to neighbor right and top edges", failures)


func _test_keeps_position_when_outside_threshold(failures: Array[String]) -> void:
	var other_rects: Array = [Rect2(40, 20, 20, 30)]
	var snapped := PreviewSnap.snap_position(Vector2(75, 60), Vector2(15, 15), Vector2(120, 120), other_rects, 8.0)
	_expect_equal(snapped, Vector2(75, 60), "dragged rect should not snap outside the threshold", failures)


func _expect_equal(actual: Variant, expected: Variant, message: String, failures: Array[String]) -> void:
	if actual != expected:
		failures.append("%s. Expected %s, got %s" % [message, expected, actual])
