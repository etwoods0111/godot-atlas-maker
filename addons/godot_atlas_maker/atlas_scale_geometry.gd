@tool
class_name AtlasScaleGeometry
extends RefCounted

enum Handle {
	NONE,
	TOP_LEFT,
	TOP_RIGHT,
	BOTTOM_LEFT,
	BOTTOM_RIGHT,
}


static func hit_handle(rect: Rect2, pointer: Vector2, radius: float) -> Handle:
	var handle_radius := maxf(0.0, radius)
	if pointer.distance_to(rect.position) <= handle_radius:
		return Handle.TOP_LEFT
	if pointer.distance_to(Vector2(rect.end.x, rect.position.y)) <= handle_radius:
		return Handle.TOP_RIGHT
	if pointer.distance_to(Vector2(rect.position.x, rect.end.y)) <= handle_radius:
		return Handle.BOTTOM_LEFT
	if pointer.distance_to(rect.end) <= handle_radius:
		return Handle.BOTTOM_RIGHT
	return Handle.NONE


static func resize_from_handle(
	rect: Rect2i,
	source_size: Vector2i,
	handle: Handle,
	pointer: Vector2,
	atlas_size: Vector2i
) -> Rect2i:
	if handle == Handle.NONE or atlas_size.x <= 0 or atlas_size.y <= 0:
		return rect

	var aspect_ratio := _aspect_ratio(source_size, rect.size)
	var fixed_corner := _opposite_corner(rect, handle)
	var desired_size := _desired_size(fixed_corner, handle, pointer, aspect_ratio)
	var max_size := _max_size(fixed_corner, handle, atlas_size, aspect_ratio)
	var size := _clamp_size(desired_size, max_size, aspect_ratio)
	return _rect_from_fixed_corner(fixed_corner, handle, size)


static func _aspect_ratio(source_size: Vector2i, fallback_size: Vector2i) -> float:
	if source_size.x > 0 and source_size.y > 0:
		return float(source_size.x) / float(source_size.y)
	if fallback_size.x > 0 and fallback_size.y > 0:
		return float(fallback_size.x) / float(fallback_size.y)
	return 1.0


static func _opposite_corner(rect: Rect2i, handle: Handle) -> Vector2i:
	match handle:
		Handle.TOP_LEFT:
			return rect.end
		Handle.TOP_RIGHT:
			return Vector2i(rect.position.x, rect.end.y)
		Handle.BOTTOM_LEFT:
			return Vector2i(rect.end.x, rect.position.y)
		Handle.BOTTOM_RIGHT:
			return rect.position
	return rect.position


static func _desired_size(fixed_corner: Vector2i, handle: Handle, pointer: Vector2, aspect_ratio: float) -> Vector2i:
	var horizontal_distance: float
	var vertical_distance: float
	match handle:
		Handle.TOP_LEFT:
			horizontal_distance = float(fixed_corner.x) - pointer.x
			vertical_distance = float(fixed_corner.y) - pointer.y
		Handle.TOP_RIGHT:
			horizontal_distance = pointer.x - float(fixed_corner.x)
			vertical_distance = float(fixed_corner.y) - pointer.y
		Handle.BOTTOM_LEFT:
			horizontal_distance = float(fixed_corner.x) - pointer.x
			vertical_distance = pointer.y - float(fixed_corner.y)
		Handle.BOTTOM_RIGHT:
			horizontal_distance = pointer.x - float(fixed_corner.x)
			vertical_distance = pointer.y - float(fixed_corner.y)
		_:
			return Vector2i.ONE

	var desired_height := maxf(
		1.0,
		maxf(horizontal_distance / aspect_ratio, vertical_distance)
	)
	return Vector2i(maxi(1, roundi(desired_height * aspect_ratio)), maxi(1, roundi(desired_height)))


static func _max_size(fixed_corner: Vector2i, handle: Handle, atlas_size: Vector2i, aspect_ratio: float) -> Vector2i:
	var max_width: int
	var max_height: int
	match handle:
		Handle.TOP_LEFT:
			max_width = fixed_corner.x
			max_height = fixed_corner.y
		Handle.TOP_RIGHT:
			max_width = atlas_size.x - fixed_corner.x
			max_height = fixed_corner.y
		Handle.BOTTOM_LEFT:
			max_width = fixed_corner.x
			max_height = atlas_size.y - fixed_corner.y
		Handle.BOTTOM_RIGHT:
			max_width = atlas_size.x - fixed_corner.x
			max_height = atlas_size.y - fixed_corner.y
		_:
			return Vector2i.ZERO

	max_width = max(0, max_width)
	max_height = max(0, max_height)
	var aspect_limited_width := floori(float(max_height) * aspect_ratio)
	return Vector2i(min(max_width, aspect_limited_width), max_height)


static func _clamp_size(desired_size: Vector2i, max_size: Vector2i, aspect_ratio: float) -> Vector2i:
	if max_size.x < 1 or max_size.y < 1:
		return Vector2i.ZERO

	var maximum_height := minf(float(max_size.y), float(max_size.x) / aspect_ratio)
	var height := clampi(desired_size.y, 1, maxi(1, floori(maximum_height)))
	var width := maxi(1, roundi(float(height) * aspect_ratio))
	if width > max_size.x:
		width = max_size.x
		height = maxi(1, roundi(float(width) / aspect_ratio))
	return Vector2i(width, height)


static func _rect_from_fixed_corner(fixed_corner: Vector2i, handle: Handle, size: Vector2i) -> Rect2i:
	match handle:
		Handle.TOP_LEFT:
			return Rect2i(fixed_corner - size, size)
		Handle.TOP_RIGHT:
			return Rect2i(Vector2i(fixed_corner.x, fixed_corner.y - size.y), size)
		Handle.BOTTOM_LEFT:
			return Rect2i(Vector2i(fixed_corner.x - size.x, fixed_corner.y), size)
		Handle.BOTTOM_RIGHT:
			return Rect2i(fixed_corner, size)
	return Rect2i()
