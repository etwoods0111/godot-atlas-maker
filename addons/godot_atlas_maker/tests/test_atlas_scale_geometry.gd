extends SceneTree

const AtlasScaleGeometry = preload("res://addons/godot_atlas_maker/atlas_scale_geometry.gd")


func _init() -> void:
	var failures: Array[String] = []
	_test_hits_four_corner_handles(failures)
	_test_keeps_aspect_ratio_and_opposite_corner_fixed(failures)
	_test_clamps_scaled_rect_inside_atlas(failures)

	if failures.is_empty():
		print("AtlasScaleGeometry tests passed")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _test_hits_four_corner_handles(failures: Array[String]) -> void:
	var rect := Rect2(Vector2(40, 30), Vector2(80, 40))
	_expect_equal(
		AtlasScaleGeometry.hit_handle(rect, Vector2(40, 30), 8.0),
		AtlasScaleGeometry.Handle.TOP_LEFT,
		"top-left handle should be hit",
		failures
	)
	_expect_equal(
		AtlasScaleGeometry.hit_handle(rect, Vector2(120, 30), 8.0),
		AtlasScaleGeometry.Handle.TOP_RIGHT,
		"top-right handle should be hit",
		failures
	)
	_expect_equal(
		AtlasScaleGeometry.hit_handle(rect, Vector2(40, 70), 8.0),
		AtlasScaleGeometry.Handle.BOTTOM_LEFT,
		"bottom-left handle should be hit",
		failures
	)
	_expect_equal(
		AtlasScaleGeometry.hit_handle(rect, Vector2(120, 70), 8.0),
		AtlasScaleGeometry.Handle.BOTTOM_RIGHT,
		"bottom-right handle should be hit",
		failures
	)
	_expect_equal(
		AtlasScaleGeometry.hit_handle(rect, Vector2(80, 50), 8.0),
		AtlasScaleGeometry.Handle.NONE,
		"center should not hit a scale handle",
		failures
	)


func _test_keeps_aspect_ratio_and_opposite_corner_fixed(failures: Array[String]) -> void:
	var resized := AtlasScaleGeometry.resize_from_handle(
		Rect2i(40, 30, 80, 40),
		Vector2i(160, 80),
		AtlasScaleGeometry.Handle.BOTTOM_RIGHT,
		Vector2(200, 110),
		Vector2i(256, 256)
	)
	_expect_equal(resized, Rect2i(40, 30, 160, 80), "resize should preserve 2:1 ratio and top-left anchor", failures)


func _test_clamps_scaled_rect_inside_atlas(failures: Array[String]) -> void:
	var resized := AtlasScaleGeometry.resize_from_handle(
		Rect2i(20, 20, 40, 20),
		Vector2i(40, 20),
		AtlasScaleGeometry.Handle.TOP_LEFT,
		Vector2(-100, -100),
		Vector2i(100, 80)
	)
	_expect_equal(resized, Rect2i(0, 10, 60, 30), "top-left resize should clamp against atlas bounds while keeping the opposite corner fixed", failures)


func _expect_equal(actual: Variant, expected: Variant, message: String, failures: Array[String]) -> void:
	if actual != expected:
		failures.append("%s. Expected %s, got %s" % [message, expected, actual])
