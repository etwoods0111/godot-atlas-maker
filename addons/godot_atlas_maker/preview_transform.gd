@tool
class_name AtlasPreviewTransform
extends RefCounted

const MIN_ZOOM := 0.25
const MAX_ZOOM := 4.0
const ZOOM_STEP := 1.1


static func clamp_zoom(value: float) -> float:
	return clampf(value, MIN_ZOOM, MAX_ZOOM)


static func canvas_to_atlas(canvas_position: Vector2, zoom: float) -> Vector2:
	var safe_zoom := maxf(zoom, 0.001)
	return canvas_position / safe_zoom


static func atlas_to_canvas(atlas_position: Vector2, zoom: float) -> Vector2:
	return atlas_position * zoom


static func atlas_rect_to_canvas(rect: Rect2, zoom: float) -> Rect2:
	return Rect2(atlas_to_canvas(rect.position, zoom), rect.size * zoom)


static func zoom_scroll_offset(
	mouse_position: Vector2,
	scroll_offset: Vector2,
	current_zoom: float,
	next_zoom: float
) -> Vector2:
	var atlas_focus := canvas_to_atlas(scroll_offset + mouse_position, current_zoom)
	return atlas_to_canvas(atlas_focus, next_zoom) - mouse_position
