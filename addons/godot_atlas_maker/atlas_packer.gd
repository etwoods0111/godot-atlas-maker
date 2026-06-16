@tool
class_name SpriteAtlasPacker
extends RefCounted


static func pack(item_sizes: Array[Vector2i], atlas_size: Vector2i, padding: int) -> Dictionary:
	var safe_padding: int = max(padding, 0)
	var usable_origin := Vector2i(safe_padding, safe_padding)
	var usable_size := atlas_size - Vector2i(safe_padding, safe_padding)
	var rects: Array[Rect2i] = []
	var placed_indices: Array[int] = []
	var unplaced_indices: Array[int] = []

	rects.resize(item_sizes.size())

	if usable_size.x <= 0 or usable_size.y <= 0:
		for i: int in item_sizes.size():
			unplaced_indices.append(i)
		return {
			"rects": rects,
			"placed_indices": placed_indices,
			"unplaced_indices": unplaced_indices,
		}

	var entries: Array[Dictionary] = []
	for i: int in item_sizes.size():
		var size: Vector2i = item_sizes[i]
		if size.x <= 0 or size.y <= 0:
			unplaced_indices.append(i)
			continue
		entries.append({
			"index": i,
			"size": size,
		})

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_size: Vector2i = a["size"]
		var b_size: Vector2i = b["size"]
		var a_max_side: int = max(a_size.x, a_size.y)
		var b_max_side: int = max(b_size.x, b_size.y)
		if a_max_side != b_max_side:
			return a_max_side > b_max_side

		var a_area: int = a_size.x * a_size.y
		var b_area: int = b_size.x * b_size.y
		if a_area != b_area:
			return a_area > b_area

		return a_size.y > b_size.y
	)

	var free_rects: Array[Rect2i] = [Rect2i(usable_origin, usable_size)]

	for entry: Dictionary in entries:
		var item_index: int = entry["index"]
		var item_size: Vector2i = entry["size"]
		var placement: Dictionary = _find_best_placement(free_rects, item_size, safe_padding)

		if placement.is_empty():
			unplaced_indices.append(item_index)
			continue

		var rect := Rect2i(placement["position"], item_size)
		rects[item_index] = rect
		placed_indices.append(item_index)

		var occupied_rect := Rect2i(rect.position, item_size + Vector2i(safe_padding, safe_padding))
		_place_rect(free_rects, occupied_rect)

	return {
		"rects": rects,
		"placed_indices": placed_indices,
		"unplaced_indices": unplaced_indices,
	}


static func pack_multiple(item_sizes: Array[Vector2i], atlas_size: Vector2i, padding: int) -> Dictionary:
	var remaining_indices: Array[int] = []
	for i: int in item_sizes.size():
		remaining_indices.append(i)

	var pages: Array[Dictionary] = []
	var unplaced_indices: Array[int] = []

	while not remaining_indices.is_empty():
		var page_sizes: Array[Vector2i] = []
		for original_index: int in remaining_indices:
			page_sizes.append(item_sizes[original_index])

		var page_result: Dictionary = pack(page_sizes, atlas_size, padding)
		var placed_local_indices: Array = page_result.get("placed_indices", [])
		var unplaced_local_indices: Array = page_result.get("unplaced_indices", [])
		var page_rects: Array = page_result.get("rects", [])

		if placed_local_indices.is_empty():
			for local_index: int in unplaced_local_indices:
				unplaced_indices.append(remaining_indices[local_index])
			break

		var item_indices: Array[int] = []
		var rects_by_index: Dictionary = {}
		for local_index: int in placed_local_indices:
			var original_index: int = remaining_indices[local_index]
			item_indices.append(original_index)
			rects_by_index[original_index] = page_rects[local_index]

		pages.append({
			"item_indices": item_indices,
			"rects_by_index": rects_by_index,
		})

		var next_remaining_indices: Array[int] = []
		for local_index: int in unplaced_local_indices:
			next_remaining_indices.append(remaining_indices[local_index])
		remaining_indices = next_remaining_indices

	return {
		"pages": pages,
		"unplaced_indices": unplaced_indices,
	}


static func _find_best_placement(free_rects: Array[Rect2i], item_size: Vector2i, padding: int) -> Dictionary:
	var footprint_size := item_size + Vector2i(padding, padding)
	var best_free_index: int = -1
	var best_short_side: int = 2147483647
	var best_long_side: int = 2147483647
	var best_area_fit: int = 2147483647
	var best_position := Vector2i.ZERO

	for i: int in free_rects.size():
		var free_rect: Rect2i = free_rects[i]
		if footprint_size.x > free_rect.size.x or footprint_size.y > free_rect.size.y:
			continue

		var leftover_horizontal: int = free_rect.size.x - footprint_size.x
		var leftover_vertical: int = free_rect.size.y - footprint_size.y
		var short_side_fit: int = min(leftover_horizontal, leftover_vertical)
		var long_side_fit: int = max(leftover_horizontal, leftover_vertical)
		var area_fit: int = free_rect.size.x * free_rect.size.y - footprint_size.x * footprint_size.y

		if (
			short_side_fit < best_short_side
			or (short_side_fit == best_short_side and long_side_fit < best_long_side)
			or (short_side_fit == best_short_side and long_side_fit == best_long_side and area_fit < best_area_fit)
		):
			best_free_index = i
			best_short_side = short_side_fit
			best_long_side = long_side_fit
			best_area_fit = area_fit
			best_position = free_rect.position

	if best_free_index == -1:
		return {}

	return {
		"free_index": best_free_index,
		"position": best_position,
	}


static func _place_rect(free_rects: Array[Rect2i], occupied_rect: Rect2i) -> void:
	var i: int = 0
	while i < free_rects.size():
		var free_rect: Rect2i = free_rects[i]
		if _split_free_rect(free_rects, free_rect, occupied_rect):
			free_rects.remove_at(i)
		else:
			i += 1

	_prune_free_rects(free_rects)


static func _split_free_rect(free_rects: Array[Rect2i], free_rect: Rect2i, occupied_rect: Rect2i) -> bool:
	if not free_rect.intersects(occupied_rect):
		return false

	if occupied_rect.position.x < free_rect.end.x and occupied_rect.end.x > free_rect.position.x:
		if occupied_rect.position.y > free_rect.position.y and occupied_rect.position.y < free_rect.end.y:
			_add_free_rect(
				free_rects,
				Rect2i(
					free_rect.position,
					Vector2i(free_rect.size.x, occupied_rect.position.y - free_rect.position.y)
				)
			)

		if occupied_rect.end.y < free_rect.end.y:
			_add_free_rect(
				free_rects,
				Rect2i(
					Vector2i(free_rect.position.x, occupied_rect.end.y),
					Vector2i(free_rect.size.x, free_rect.end.y - occupied_rect.end.y)
				)
			)

	if occupied_rect.position.y < free_rect.end.y and occupied_rect.end.y > free_rect.position.y:
		if occupied_rect.position.x > free_rect.position.x and occupied_rect.position.x < free_rect.end.x:
			_add_free_rect(
				free_rects,
				Rect2i(
					free_rect.position,
					Vector2i(occupied_rect.position.x - free_rect.position.x, free_rect.size.y)
				)
			)

		if occupied_rect.end.x < free_rect.end.x:
			_add_free_rect(
				free_rects,
				Rect2i(
					Vector2i(occupied_rect.end.x, free_rect.position.y),
					Vector2i(free_rect.end.x - occupied_rect.end.x, free_rect.size.y)
				)
			)

	return true


static func _add_free_rect(free_rects: Array[Rect2i], rect: Rect2i) -> void:
	if rect.size.x > 0 and rect.size.y > 0:
		free_rects.append(rect)


static func _prune_free_rects(free_rects: Array[Rect2i]) -> void:
	var i: int = 0
	while i < free_rects.size():
		var j: int = i + 1
		var removed_i := false

		while j < free_rects.size():
			if _contains_rect(free_rects[i], free_rects[j]):
				free_rects.remove_at(j)
			elif _contains_rect(free_rects[j], free_rects[i]):
				free_rects.remove_at(i)
				removed_i = true
				break
			else:
				j += 1

		if not removed_i:
			i += 1


static func _contains_rect(outer: Rect2i, inner: Rect2i) -> bool:
	return (
		inner.position.x >= outer.position.x
		and inner.position.y >= outer.position.y
		and inner.end.x <= outer.end.x
		and inner.end.y <= outer.end.y
	)
