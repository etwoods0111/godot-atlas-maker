@tool
class_name AtlasPageLayout
extends RefCounted

const AtlasPacker = preload("res://addons/godot_atlas_maker/atlas_packer.gd")

var _atlas_size: Vector2i
var _padding: int
var _source_sizes: Array[Vector2i] = []
var _pages: Array[Dictionary] = []


func configure(
	atlas_size: Vector2i,
	padding: int,
	source_sizes: Array[Vector2i],
	pages: Array
) -> void:
	_atlas_size = atlas_size
	_padding = max(0, padding)
	_source_sizes = source_sizes.duplicate()
	_pages = _copy_pages(pages)


func page_count() -> int:
	return _pages.size()


func to_pages() -> Array[Dictionary]:
	return _copy_pages(_pages)


func get_item_page(item_index: int) -> int:
	for page_index: int in _pages.size():
		var item_indices: Array = _pages[page_index].get("item_indices", [])
		if item_index in item_indices:
			return page_index
	return -1


func get_item_rect(item_index: int) -> Rect2i:
	var page_index := get_item_page(item_index)
	if page_index < 0:
		return Rect2i()
	var rects_by_index: Dictionary = _pages[page_index].get("rects_by_index", {})
	return Rect2i(rects_by_index.get(item_index, Rect2i()))


func get_page_item_indices(page_index: int) -> Array[int]:
	if page_index < 0 or page_index >= _pages.size():
		return []
	var result: Array[int] = []
	for item_index: int in _pages[page_index].get("item_indices", []):
		result.append(item_index)
	return result


func move_item(item_index: int, target_page: int, target_rect: Rect2i) -> Dictionary:
	var source_page := get_item_page(item_index)
	if source_page < 0 or not _is_legal_rect(target_page, item_index, target_rect):
		return {"ok": false, "reason": "no_space"}

	var next_pages := _copy_pages(_pages)
	_remove_from_page(next_pages[source_page], item_index)
	_insert_into_page(next_pages[target_page], item_index, target_rect)
	_pages = next_pages
	return {"ok": true}


func move_item_to_first_fit(item_index: int, target_page: int) -> Dictionary:
	var target_rect := find_first_fit(item_index, target_page)
	if target_rect.size.x <= 0 or target_rect.size.y <= 0:
		return {"ok": false, "reason": "no_space"}
	return move_item(item_index, target_page, target_rect)


func find_first_fit(item_index: int, target_page: int) -> Rect2i:
	var source_page := get_item_page(item_index)
	if source_page < 0 or target_page < 0 or target_page >= _pages.size():
		return Rect2i()

	var item_rect := get_item_rect(item_index)
	var candidates: Array[Vector2i] = []
	var seen_positions: Dictionary = {}
	_append_candidate(candidates, seen_positions, item_rect.position)
	_append_candidate(candidates, seen_positions, Vector2i.ZERO)

	var page: Dictionary = _pages[target_page]
	var rects_by_index: Dictionary = page.get("rects_by_index", {})
	for other_item_index: int in page.get("item_indices", []):
		if other_item_index == item_index:
			continue
		var other_rect := Rect2i(rects_by_index.get(other_item_index, Rect2i()))
		_append_candidate(candidates, seen_positions, Vector2i(other_rect.end.x, other_rect.position.y))
		_append_candidate(candidates, seen_positions, Vector2i(other_rect.position.x, other_rect.end.y))
		_append_candidate(candidates, seen_positions, other_rect.end)

	for position: Vector2i in candidates:
		var target_rect := Rect2i(position, item_rect.size)
		if _is_legal_rect(target_page, item_index, target_rect):
			return target_rect
	return Rect2i()


func resize_item(item_index: int, target_rect: Rect2i) -> Dictionary:
	var page_index := get_item_page(item_index)
	if page_index < 0 or not _is_legal_rect(page_index, item_index, target_rect):
		return {"ok": false, "reason": "no_space"}

	var next_pages := _copy_pages(_pages)
	_set_page_rect(next_pages[page_index], item_index, target_rect)
	_pages = next_pages
	return {"ok": true}


func arrange_pages() -> Dictionary:
	var next_pages := _copy_pages(_pages)
	for page_index: int in next_pages.size():
		var page: Dictionary = next_pages[page_index]
		var pack_result: Dictionary = AtlasPacker.pack(_page_sizes(page), _atlas_size, _padding)
		var unplaced_indices: Array = pack_result.get("unplaced_indices", [])
		if not unplaced_indices.is_empty():
			return {
				"ok": false,
				"page_index": page_index,
				"unplaced_indices": unplaced_indices,
			}
		_apply_packed_rects(page, pack_result.get("rects", []))
		next_pages[page_index] = page

	_pages = next_pages
	return {"ok": true}


func _is_legal_rect(page_index: int, ignored_item_index: int, target_rect: Rect2i) -> bool:
	if page_index < 0 or page_index >= _pages.size():
		return false
	if target_rect.size.x <= 0 or target_rect.size.y <= 0:
		return false
	if target_rect.position.x < 0 or target_rect.position.y < 0:
		return false
	if target_rect.end.x > _atlas_size.x or target_rect.end.y > _atlas_size.y:
		return false

	var page: Dictionary = _pages[page_index]
	var rects_by_index: Dictionary = page.get("rects_by_index", {})
	for item_index: int in page.get("item_indices", []):
		if item_index == ignored_item_index:
			continue
		var other_rect := Rect2i(rects_by_index.get(item_index, Rect2i()))
		if target_rect.intersects(other_rect):
			return false
	return true


func _page_sizes(page: Dictionary) -> Array[Vector2i]:
	var sizes: Array[Vector2i] = []
	var rects_by_index: Dictionary = page.get("rects_by_index", {})
	for item_index: int in page.get("item_indices", []):
		sizes.append(Rect2i(rects_by_index.get(item_index, Rect2i())).size)
	return sizes


func _apply_packed_rects(page: Dictionary, packed_rects: Array) -> void:
	var item_indices: Array = page.get("item_indices", [])
	var rects_by_index: Dictionary = page.get("rects_by_index", {})
	for local_index: int in item_indices.size():
		rects_by_index[item_indices[local_index]] = Rect2i(packed_rects[local_index])
	page["rects_by_index"] = rects_by_index


static func _copy_pages(source_pages: Array) -> Array[Dictionary]:
	var copied_pages: Array[Dictionary] = []
	for source_page: Dictionary in source_pages:
		var copied_indices: Array[int] = []
		for item_index: int in source_page.get("item_indices", []):
			copied_indices.append(item_index)
		var copied_rects: Dictionary = {}
		for item_index: int in source_page.get("rects_by_index", {}):
			copied_rects[item_index] = Rect2i(source_page["rects_by_index"][item_index])
		copied_pages.append({
			"item_indices": copied_indices,
			"rects_by_index": copied_rects,
		})
	return copied_pages


static func _append_candidate(candidates: Array[Vector2i], seen_positions: Dictionary, position: Vector2i) -> void:
	if seen_positions.has(position):
		return
	seen_positions[position] = true
	candidates.append(position)


static func _remove_from_page(page: Dictionary, item_index: int) -> void:
	var item_indices: Array = page.get("item_indices", [])
	item_indices.erase(item_index)
	page["item_indices"] = item_indices
	var rects_by_index: Dictionary = page.get("rects_by_index", {})
	rects_by_index.erase(item_index)
	page["rects_by_index"] = rects_by_index


static func _insert_into_page(page: Dictionary, item_index: int, rect: Rect2i) -> void:
	var item_indices: Array = page.get("item_indices", [])
	item_indices.append(item_index)
	page["item_indices"] = item_indices
	_set_page_rect(page, item_index, rect)


static func _set_page_rect(page: Dictionary, item_index: int, rect: Rect2i) -> void:
	var rects_by_index: Dictionary = page.get("rects_by_index", {})
	rects_by_index[item_index] = rect
	page["rects_by_index"] = rects_by_index
