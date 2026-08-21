@tool
class_name PreviewPageBinding
extends RefCounted


static func resolve_page_index(canvas_page_index: int, selected_page_index: int, side_by_side: bool) -> int:
	return canvas_page_index if side_by_side else selected_page_index
