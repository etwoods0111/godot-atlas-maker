@tool
class_name AtlasPreviewSnap
extends RefCounted

const DEFAULT_THRESHOLD := 8.0


static func snap_position(
	target_position: Vector2,
	rect_size: Vector2,
	atlas_size: Vector2,
	other_rects: Array,
	threshold: float = DEFAULT_THRESHOLD
) -> Vector2:
	var snapped := target_position
	snapped.x = _snap_axis(
		target_position.x,
		rect_size.x,
		atlas_size.x,
		_collect_axis_candidates(other_rects, true),
		threshold
	)
	snapped.y = _snap_axis(
		target_position.y,
		rect_size.y,
		atlas_size.y,
		_collect_axis_candidates(other_rects, false),
		threshold
	)
	return snapped.clamp(Vector2.ZERO, atlas_size - rect_size)


static func _snap_axis(
	position: float,
	size: float,
	atlas_extent: float,
	edge_candidates: Array[float],
	threshold: float
) -> float:
	var candidates: Array[float] = [0.0, atlas_extent - size]
	for edge: float in edge_candidates:
		candidates.append(edge)
		candidates.append(edge - size)

	var best_position := position
	var best_distance := threshold
	for candidate: float in candidates:
		var distance := absf(position - candidate)
		if distance <= best_distance:
			best_distance = distance
			best_position = candidate

	return clampf(best_position, 0.0, atlas_extent - size)


static func _collect_axis_candidates(rects: Array, use_x_axis: bool) -> Array[float]:
	var candidates: Array[float] = []
	for value: Variant in rects:
		var rect := Rect2(value)
		if use_x_axis:
			candidates.append(rect.position.x)
			candidates.append(rect.end.x)
		else:
			candidates.append(rect.position.y)
			candidates.append(rect.end.y)
	return candidates
