@tool
class_name SpriteAtlasExporter
extends RefCounted

const AtlasPacker = preload("res://addons/godot_atlas_maker/atlas_packer.gd")


static func export_atlas(
	items: Array[Dictionary],
	atlas_size: Vector2i,
	output_path: String,
	options: Dictionary = {}
) -> Dictionary:
	if atlas_size.x <= 0 or atlas_size.y <= 0:
		return _error_result(ERR_INVALID_PARAMETER, "Atlas size must be positive.")

	if items.is_empty():
		return _error_result(ERR_INVALID_PARAMETER, "No items to export.")

	var formats := _resolve_export_formats(options)
	if not _has_selected_format(formats):
		return _error_result(ERR_INVALID_PARAMETER, "Select at least one export format.")

	var build_result := _build_atlas_image_and_regions(items, atlas_size)
	if build_result.get("error", FAILED) != OK:
		return _error_result(build_result.get("error", FAILED), build_result.get("message", "Failed to build atlas."))

	var atlas_image: Image = build_result["atlas_image"]
	var regions: Dictionary = build_result["regions"]
	var output_folder_name := _safe_relative_dir_path(str(options.get("output_folder_name", "atlas_textures")))
	var output_dir := output_path.get_base_dir().path_join(output_folder_name)
	var atlas_output_path := output_dir.path_join(output_path.get_file())
	if _has_selected_format(formats):
		var mkdir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
		if mkdir_error != OK:
			return _error_result(mkdir_error, "Failed to create atlas output directory: %s." % output_dir)

	var atlas_path := ""
	if formats.get("export_png", false):
		var png_error: Error = atlas_image.save_png(atlas_output_path)
		if png_error != OK:
			return _error_result(png_error, "Failed to save atlas PNG: %s." % atlas_output_path)
		atlas_path = atlas_output_path

	var atlas_texture_resource_path := ""
	var atlas_texture_paths: Dictionary = {}
	if formats.get("export_tres", false) or formats.get("export_res", false):
		var atlas_texture_resource_name: String = str(options.get("atlas_texture_resource_name", output_path.get_file().get_basename()))
		var resource_result := _save_godot_resources(
			atlas_image,
			atlas_output_path,
			output_dir,
			atlas_texture_resource_name,
			regions,
			formats
		)
		if resource_result.get("error", FAILED) != OK:
			return _error_result(resource_result.get("error", FAILED), resource_result.get("message", "Failed to save Godot resources."))
		atlas_texture_resource_path = resource_result.get("atlas_texture_resource_path", "")
		atlas_texture_paths = resource_result.get("atlas_texture_paths", {})

	var mapping_path := ""
	if formats.get("export_mapping", false):
		var mapping_file_name := str(options.get("mapping_file_name", output_path.get_file().get_basename() + "_map"))
		var mapping_result := _save_mapping_file(
			output_dir,
			mapping_file_name,
			output_path.get_file().get_basename(),
			atlas_size,
			[
				_build_mapping_page(0, atlas_output_path.get_file(), regions),
			]
		)
		if mapping_result.get("error", FAILED) != OK:
			return _error_result(mapping_result.get("error", FAILED), mapping_result.get("message", "Failed to save mapping data."))
		mapping_path = mapping_result.get("mapping_path", "")

	if Engine.is_editor_hint() and EditorInterface.get_resource_filesystem():
		EditorInterface.get_resource_filesystem().scan()

	return {
		"error": OK,
		"message": "",
		"atlas_path": atlas_path,
		"atlas_texture_resource_path": atlas_texture_resource_path,
		"atlas_texture_paths": atlas_texture_paths,
		"mapping_path": mapping_path,
		"regions": regions,
		"output_dir": output_dir,
	}


static func _build_atlas_image_and_regions(items: Array[Dictionary], atlas_size: Vector2i) -> Dictionary:
	var atlas_image := Image.create(atlas_size.x, atlas_size.y, false, Image.FORMAT_RGBA8)
	atlas_image.fill(Color(0, 0, 0, 0))

	var regions: Dictionary = {}

	for item: Dictionary in items:
		var item_name: String = str(item.get("name", "item"))
		var rect: Rect2i = _to_rect2i(item.get("rect", Rect2i()))
		var source_image: Image = _get_item_image(item)

		if source_image == null:
			return _error_result(ERR_INVALID_DATA, "Item '%s' has no valid image or texture." % item_name)

		if rect.size.x <= 0 or rect.size.y <= 0:
			return _error_result(ERR_INVALID_DATA, "Item '%s' has an invalid region: %s." % [item_name, rect])

		if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > atlas_size.x or rect.end.y > atlas_size.y:
			return _error_result(ERR_INVALID_DATA, "Item '%s' is outside the atlas: %s." % [item_name, rect])

		if source_image.get_format() != Image.FORMAT_RGBA8:
			source_image = source_image.duplicate()
			source_image.convert(Image.FORMAT_RGBA8)

		atlas_image.blit_rect(
			source_image,
			Rect2i(Vector2i.ZERO, source_image.get_size()),
			rect.position
		)

		regions[item_name] = Rect2(rect)

	return {
		"error": OK,
		"message": "",
		"atlas_image": atlas_image,
		"regions": regions,
	}


static func _save_godot_resources(
	atlas_image: Image,
	output_path: String,
	output_dir: String,
	atlas_texture_resource_name: String,
	regions: Dictionary,
	formats: Dictionary
) -> Dictionary:
	var atlas_texture_result := _create_atlas_texture_reference(
		atlas_image,
		output_path,
		output_dir,
		atlas_texture_resource_name,
		formats
	)
	if atlas_texture_result.get("error", FAILED) != OK:
		return atlas_texture_result

	var atlas_texture := atlas_texture_result.get("texture") as Texture2D
	var atlas_texture_resource_path: String = atlas_texture_result.get("resource_path", "")
	var saved_paths: Dictionary = {}
	var used_file_names: Dictionary = {}
	if formats.get("export_tres", false):
		for item_name: String in regions:
			var safe_file_name := _unique_safe_file_name(item_name, used_file_names)
			var save_path := output_dir.path_join(safe_file_name + ".tres")
			var atlas := AtlasTexture.new()
			atlas.atlas = atlas_texture
			atlas.region = regions[item_name]

			var save_error := ResourceSaver.save(atlas, save_path, ResourceSaver.FLAG_RELATIVE_PATHS)
			if save_error != OK:
				return _error_result(save_error, "Failed to save AtlasTexture: %s." % save_path)

			saved_paths[item_name] = save_path

	return {
		"error": OK,
		"message": "",
		"atlas_texture_resource_path": atlas_texture_resource_path,
		"atlas_texture_paths": saved_paths,
	}


static func _create_atlas_texture_reference(
	atlas_image: Image,
	output_path: String,
	output_dir: String,
	atlas_texture_resource_name: String,
	formats: Dictionary
) -> Dictionary:
	var atlas_texture := ImageTexture.create_from_image(atlas_image)
	atlas_texture.resource_name = output_path.get_file().get_basename()

	if formats.get("export_png", false) and not formats.get("export_res", false):
		atlas_texture.resource_path = output_path
		return {
			"error": OK,
			"message": "",
			"texture": atlas_texture,
			"resource_path": "",
		}

	if not formats.get("export_res", false):
		return {
			"error": OK,
			"message": "",
			"texture": atlas_texture,
			"resource_path": "",
		}

	var atlas_texture_file_name := _safe_file_name(atlas_texture_resource_name)
	if atlas_texture_resource_name.begins_with("_") and not atlas_texture_file_name.begins_with("_"):
		atlas_texture_file_name = "_" + atlas_texture_file_name
	var atlas_texture_resource_path := output_dir.path_join(atlas_texture_file_name + ".res")
	var texture_save_error := ResourceSaver.save(atlas_texture, atlas_texture_resource_path)
	if texture_save_error != OK:
		return {
			"error": texture_save_error,
			"message": "Failed to save generated atlas texture resource: %s." % atlas_texture_resource_path,
			"texture": null,
			"resource_path": "",
		}

	atlas_texture.resource_path = atlas_texture_resource_path
	return {
		"error": OK,
		"message": "",
		"texture": atlas_texture,
		"resource_path": atlas_texture_resource_path,
	}


static func export_multiple_atlases(
	items: Array[Dictionary],
	atlas_size: Vector2i,
	padding: int,
	output_path: String,
	options: Dictionary = {}
) -> Dictionary:
	var item_sizes: Array[Vector2i] = []
	for item: Dictionary in items:
		var source_image: Image = _get_item_image(item)
		if source_image == null:
			return _error_result(ERR_INVALID_DATA, "Item '%s' has no valid image or texture." % str(item.get("name", "item")))
		item_sizes.append(source_image.get_size())

	var pack_result: Dictionary = AtlasPacker.pack_multiple(item_sizes, atlas_size, padding)
	var pages: Array = pack_result.get("pages", [])
	var unplaced_indices: Array = pack_result.get("unplaced_indices", [])

	if pages.is_empty():
		var message := "No atlas pages could be created."
		if not unplaced_indices.is_empty():
			message = "Some items are larger than the atlas and cannot be exported: %s." % str(unplaced_indices)
		return _error_result(ERR_CANT_CREATE, message)

	var export_result := export_atlas_pages(items, pages, atlas_size, output_path, options)
	export_result["unplaced_indices"] = unplaced_indices
	return export_result


static func export_atlas_pages(
	items: Array[Dictionary],
	pages: Array,
	atlas_size: Vector2i,
	output_path: String,
	options: Dictionary = {}
) -> Dictionary:
	if pages.is_empty():
		return _error_result(ERR_INVALID_PARAMETER, "No atlas pages to export.")

	var formats := _resolve_export_formats(options)
	if not _has_selected_format(formats):
		return _error_result(ERR_INVALID_PARAMETER, "Select at least one export format.")

	var atlas_texture_resource_name: String = str(options.get("atlas_texture_resource_name", "_atlas_texture"))
	var page_results: Array[Dictionary] = []
	var mapping_pages: Array[Dictionary] = []
	for page_index: int in pages.size():
		var page: Dictionary = pages[page_index]
		var item_indices: Array = page.get("item_indices", [])
		var rects_by_index: Dictionary = page.get("rects_by_index", {})
		var page_items: Array[Dictionary] = []

		for item_index: int in item_indices:
			var item: Dictionary = items[item_index].duplicate()
			item["rect"] = rects_by_index[item_index]
			page_items.append(item)

		var page_output_path := _page_output_path(output_path, page_index, pages.size())
		var page_result: Dictionary = {}
		if formats.get("export_png", false) or formats.get("export_tres", false) or formats.get("export_res", false):
			var page_options := options.duplicate()
			page_options["atlas_texture_resource_name"] = _paged_resource_name(atlas_texture_resource_name, page_index, pages.size())
			page_options["export_mapping"] = false
			page_result = export_atlas(page_items, atlas_size, page_output_path, page_options)
			if page_result.get("error", FAILED) != OK:
				return page_result
		else:
			var build_result := _build_atlas_image_and_regions(page_items, atlas_size)
			if build_result.get("error", FAILED) != OK:
				return _error_result(build_result.get("error", FAILED), build_result.get("message", "Failed to build atlas page."))
			page_result = {
				"error": OK,
				"message": "",
				"atlas_path": "",
				"atlas_texture_resource_path": "",
				"atlas_texture_paths": {},
				"mapping_path": "",
				"regions": build_result.get("regions", {}),
				"output_dir": "",
			}

		mapping_pages.append(_build_mapping_page(page_index, page_output_path.get_file(), page_result.get("regions", {})))
		page_results.append(page_result)

	var output_folder_name := _safe_relative_dir_path(str(options.get("output_folder_name", "atlas_textures")))
	var output_dir := output_path.get_base_dir().path_join(output_folder_name)
	var mapping_path := ""
	if formats.get("export_mapping", false):
		var mkdir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
		if mkdir_error != OK:
			return _error_result(mkdir_error, "Failed to create atlas output directory: %s." % output_dir)

		var mapping_file_name := str(options.get("mapping_file_name", output_path.get_file().get_basename() + "_map"))
		var mapping_result := _save_mapping_file(
			output_dir,
			mapping_file_name,
			output_path.get_file().get_basename(),
			atlas_size,
			mapping_pages
		)
		if mapping_result.get("error", FAILED) != OK:
			return _error_result(mapping_result.get("error", FAILED), mapping_result.get("message", "Failed to save mapping data."))
		mapping_path = mapping_result.get("mapping_path", "")

	if Engine.is_editor_hint() and EditorInterface.get_resource_filesystem():
		EditorInterface.get_resource_filesystem().scan()

	return {
		"error": OK,
		"message": "",
		"pages": page_results,
		"mapping_path": mapping_path,
		"output_dir": output_dir,
		"unplaced_indices": [],
	}


static func _resolve_export_formats(options: Dictionary) -> Dictionary:
	if options.has("export_png") or options.has("export_tres") or options.has("export_res") or options.has("export_mapping"):
		return {
			"export_png": bool(options.get("export_png", false)),
			"export_tres": bool(options.get("export_tres", false)),
			"export_res": bool(options.get("export_res", false)),
			"export_mapping": bool(options.get("export_mapping", false)),
		}

	var save_png := bool(options.get("save_png", true))
	return {
		"export_png": save_png,
		"export_tres": true,
		"export_res": not save_png,
		"export_mapping": false,
	}


static func _has_selected_format(formats: Dictionary) -> bool:
	return (
		bool(formats.get("export_png", false))
		or bool(formats.get("export_tres", false))
		or bool(formats.get("export_res", false))
		or bool(formats.get("export_mapping", false))
	)


static func _save_mapping_file(
	output_dir: String,
	mapping_file_name: String,
	atlas_name: String,
	atlas_size: Vector2i,
	pages: Array[Dictionary]
) -> Dictionary:
	var safe_mapping_name := _safe_file_name(mapping_file_name)
	var mapping_path := output_dir.path_join(safe_mapping_name + ".json")
	var mapping_data := {
		"atlas_name": atlas_name,
		"atlas_size": {
			"w": atlas_size.x,
			"h": atlas_size.y,
		},
		"pages": pages,
	}

	var file := FileAccess.open(mapping_path, FileAccess.WRITE)
	if file == null:
		return {
			"error": FileAccess.get_open_error(),
			"message": "Failed to open mapping file for writing: %s." % mapping_path,
			"mapping_path": "",
		}

	file.store_string(JSON.stringify(mapping_data, "\t"))
	file.close()
	return {
		"error": OK,
		"message": "",
		"mapping_path": mapping_path,
	}


static func _build_mapping_page(page_index: int, image_file_name: String, regions: Dictionary) -> Dictionary:
	var mapped_items: Dictionary = {}
	for item_name: String in regions:
		var rect: Rect2 = regions[item_name]
		mapped_items[item_name] = {
			"x": int(roundi(rect.position.x)),
			"y": int(roundi(rect.position.y)),
			"w": int(roundi(rect.size.x)),
			"h": int(roundi(rect.size.y)),
		}

	return {
		"index": page_index,
		"image": image_file_name,
		"items": mapped_items,
	}


static func _get_item_image(item: Dictionary) -> Image:
	if item.has("image") and item["image"] is Image:
		return item["image"]

	if item.has("texture") and item["texture"] is Texture2D:
		var texture: Texture2D = item["texture"]
		return texture.get_image()

	return null


static func _to_rect2i(value: Variant) -> Rect2i:
	if value is Rect2i:
		return value

	if value is Rect2:
		var rect: Rect2 = value
		return Rect2i(
			Vector2i(roundi(rect.position.x), roundi(rect.position.y)),
			Vector2i(roundi(rect.size.x), roundi(rect.size.y))
		)

	return Rect2i()


static func _unique_safe_file_name(raw_name: String, used_file_names: Dictionary) -> String:
	var base_name := _safe_file_name(raw_name)
	var file_name := base_name
	var suffix := 2

	while used_file_names.has(file_name):
		file_name = "%s_%d" % [base_name, suffix]
		suffix += 1

	used_file_names[file_name] = true
	return file_name


static func _safe_file_name(raw_name: String) -> String:
	var name := raw_name.strip_edges().replace(" ", "_")
	var invalid_chars := ["<", ">", ":", "\"", "/", "\\", "|", "?", "*"]
	for invalid_char: String in invalid_chars:
		name = name.replace(invalid_char, "_")

	while "__" in name:
		name = name.replace("__", "_")

	name = name.trim_prefix("_").trim_suffix("_")
	if name.is_empty():
		return "item"

	return name


static func _safe_relative_dir_path(raw_path: String) -> String:
	var path := raw_path.strip_edges().replace("\\", "/")
	if path.is_empty():
		return "atlas_textures"

	var segments: PackedStringArray = path.split("/", false)
	var safe_segments: Array[String] = []
	for segment: String in segments:
		if segment == "." or segment == "..":
			continue
		var safe_segment := _safe_file_name(segment)
		if not safe_segment.is_empty():
			safe_segments.append(safe_segment)

	if safe_segments.is_empty():
		return "atlas_textures"

	return "/".join(safe_segments)


static func _paged_resource_name(base_name: String, page_index: int, page_count: int) -> String:
	if page_count <= 1:
		return base_name

	var safe_base_name := base_name if not base_name.strip_edges().is_empty() else "_atlas_texture"
	return "%s_%02d" % [safe_base_name, page_index + 1]


static func _page_output_path(output_path: String, page_index: int, page_count: int) -> String:
	if page_count <= 1:
		return output_path

	var extension := output_path.get_extension()
	var base_path := output_path.substr(0, output_path.length() - extension.length() - 1)
	return "%s_%02d.%s" % [base_path, page_index + 1, extension]


static func _error_result(error: Error, message: String) -> Dictionary:
	return {
		"error": error,
		"message": message,
		"atlas_path": "",
		"atlas_texture_resource_path": "",
		"atlas_texture_paths": {},
		"regions": {},
		"output_dir": "",
		"pages": [],
		"unplaced_indices": [],
	}
