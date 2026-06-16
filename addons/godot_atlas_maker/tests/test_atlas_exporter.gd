extends SceneTree

const AtlasExporter = preload("res://addons/godot_atlas_maker/atlas_exporter.gd")

const TEST_DIR := "res://.tmp_sprite_atlas_export_test"


func _init() -> void:
	var failures: Array[String] = []
	_prepare_test_dir()

	_test_exports_png_atlas_textures_and_mapping_without_res(failures)
	_test_exports_runtime_resources_without_png_to_custom_names(failures)
	_test_exports_mapping_without_png_or_godot_resources(failures)
	_test_rejects_empty_export_format_selection(failures)
	_test_exports_multiple_atlas_pages_when_needed(failures)
	_test_exports_explicit_preview_pages(failures)

	_cleanup_test_dir()

	if failures.is_empty():
		print("AtlasExporter tests passed")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _test_exports_png_atlas_textures_and_mapping_without_res(failures: Array[String]) -> void:
	var red_image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	red_image.fill(Color.RED)
	var blue_image := Image.create(4, 6, false, Image.FORMAT_RGBA8)
	blue_image.fill(Color.BLUE)

	var items: Array[Dictionary] = [
		{
			"name": "red block",
			"image": red_image,
			"rect": Rect2i(0, 0, 8, 8),
		},
		{
			"name": "blue/block",
			"image": blue_image,
			"rect": Rect2i(10, 2, 4, 6),
		},
	]

	var output_path := TEST_DIR + "/test_atlas.png"
	var result: Dictionary = AtlasExporter.export_atlas(
		items,
		Vector2i(32, 32),
		output_path,
		{
			"export_png": true,
			"export_tres": true,
			"export_res": false,
			"export_mapping": true,
			"output_folder_name": "test_atlas",
			"mapping_file_name": "test_atlas_map",
		}
	)

	var atlas_png_path := TEST_DIR + "/test_atlas/test_atlas.png"
	_expect_equal(result.get("error", FAILED), OK, "export should succeed", failures)
	_expect_true(not FileAccess.file_exists(output_path), "atlas PNG should not be written outside the named output folder", failures)
	_expect_true(FileAccess.file_exists(atlas_png_path), "atlas PNG should be written inside the named output folder", failures)
	_expect_true(not FileAccess.file_exists(TEST_DIR + "/test_atlas/test_atlas.res"), "PNG+AtlasTexture export should not create a .res texture when .res export is disabled", failures)
	_expect_true(FileAccess.file_exists(TEST_DIR + "/test_atlas/red_block.tres"), "first AtlasTexture should be saved", failures)
	_expect_true(FileAccess.file_exists(TEST_DIR + "/test_atlas/blue_block.tres"), "second AtlasTexture should use a sanitized file name", failures)
	_expect_true(FileAccess.file_exists(TEST_DIR + "/test_atlas/test_atlas_map.json"), "mapping JSON should be written", failures)

	var red_atlas_text := FileAccess.get_file_as_string(TEST_DIR + "/test_atlas/red_block.tres")
	var blue_atlas_text := FileAccess.get_file_as_string(TEST_DIR + "/test_atlas/blue_block.tres")
	_expect_true(atlas_png_path in red_atlas_text, "first AtlasTexture should reference the folder-local PNG atlas directly", failures)
	_expect_true(atlas_png_path in blue_atlas_text, "second AtlasTexture should reference the folder-local PNG atlas directly", failures)
	_expect_true("region = Rect2(0, 0, 8, 8)" in red_atlas_text, "first AtlasTexture region should match source rect", failures)
	_expect_true("region = Rect2(10, 2, 4, 6)" in blue_atlas_text, "second AtlasTexture region should match source rect", failures)

	var mapping := _read_json(TEST_DIR + "/test_atlas/test_atlas_map.json")
	var pages: Array = mapping.get("pages", [])
	_expect_equal(mapping.get("atlas_name", ""), "test_atlas", "mapping atlas name should match the output name", failures)
	_expect_equal(pages.size(), 1, "single atlas mapping should contain one page", failures)
	if pages.size() == 1:
		var page: Dictionary = pages[0]
		var mapped_items: Dictionary = page.get("items", {})
		_expect_equal(page.get("image", ""), "test_atlas.png", "mapping should point at the PNG atlas file", failures)
		_expect_equal(mapped_items.get("red block", {}).get("x", -1), 0, "first mapped x should match source rect", failures)
		_expect_equal(mapped_items.get("red block", {}).get("w", -1), 8, "first mapped width should match source rect", failures)
		_expect_equal(mapped_items.get("blue/block", {}).get("y", -1), 2, "second mapped y should match source rect", failures)
		_expect_equal(mapped_items.get("blue/block", {}).get("h", -1), 6, "second mapped height should match source rect", failures)


func _test_exports_runtime_resources_without_png_to_custom_names(failures: Array[String]) -> void:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.GREEN)

	var items: Array[Dictionary] = [
		{
			"name": "runtime item",
			"image": image,
			"rect": Rect2i(2, 3, 8, 8),
		},
	]
	var output_path := TEST_DIR + "/runtime_only.png"
	var result: Dictionary = AtlasExporter.export_atlas(
		items,
		Vector2i(16, 16),
		output_path,
		{
			"export_png": false,
			"export_tres": true,
			"export_res": true,
			"export_mapping": false,
			"output_folder_name": "skin_runtime",
			"atlas_texture_resource_name": "student_idle",
		}
	)

	_expect_equal(result.get("error", FAILED), OK, "runtime-only export should succeed", failures)
	_expect_true(not FileAccess.file_exists(output_path), "runtime-only export should not write the PNG atlas", failures)
	_expect_true(FileAccess.file_exists(TEST_DIR + "/skin_runtime/student_idle.res"), "custom shared texture resource name should be used", failures)
	_expect_true(FileAccess.file_exists(TEST_DIR + "/skin_runtime/runtime_item.tres"), "AtlasTexture should be saved in the custom folder", failures)

	var atlas := ResourceLoader.load(TEST_DIR + "/skin_runtime/runtime_item.tres", "AtlasTexture", ResourceLoader.CACHE_MODE_IGNORE) as AtlasTexture
	_expect_true(atlas != null, "runtime-only AtlasTexture should load immediately", failures)
	if atlas:
		_expect_equal(atlas.region, Rect2(2, 3, 8, 8), "runtime-only region should match source rect", failures)
		_expect_true(atlas.atlas != null, "runtime-only AtlasTexture should have an embedded generated atlas", failures)
	_expect_true(not FileAccess.file_exists(TEST_DIR + "/skin_runtime/student_idle_map.json"), "runtime-only export should not write mapping JSON when disabled", failures)


func _test_exports_mapping_without_png_or_godot_resources(failures: Array[String]) -> void:
	var image := Image.create(5, 7, false, Image.FORMAT_RGBA8)
	image.fill(Color.ORANGE)

	var items: Array[Dictionary] = [
		{
			"name": "only mapping",
			"image": image,
			"rect": Rect2i(4, 6, 5, 7),
		},
	]
	var output_path := TEST_DIR + "/mapping_only.png"
	var result: Dictionary = AtlasExporter.export_atlas(
		items,
		Vector2i(16, 16),
		output_path,
		{
			"export_png": false,
			"export_tres": false,
			"export_res": false,
			"export_mapping": true,
			"output_folder_name": "mapping_only",
			"mapping_file_name": "mapping_only_map",
		}
	)

	_expect_equal(result.get("error", FAILED), OK, "mapping-only export should succeed", failures)
	_expect_true(not FileAccess.file_exists(output_path), "mapping-only export should not write PNG", failures)
	_expect_true(not FileAccess.file_exists(TEST_DIR + "/mapping_only/mapping_only.res"), "mapping-only export should not write .res", failures)
	_expect_true(not FileAccess.file_exists(TEST_DIR + "/mapping_only/only_mapping.tres"), "mapping-only export should not write AtlasTexture resources", failures)
	_expect_true(FileAccess.file_exists(TEST_DIR + "/mapping_only/mapping_only_map.json"), "mapping-only export should write JSON", failures)

	var mapping := _read_json(TEST_DIR + "/mapping_only/mapping_only_map.json")
	var pages: Array = mapping.get("pages", [])
	if pages.size() == 1:
		var mapped_items: Dictionary = pages[0].get("items", {})
		_expect_equal(mapped_items.get("only mapping", {}).get("x", -1), 4, "mapping-only x should match source rect", failures)
		_expect_equal(mapped_items.get("only mapping", {}).get("h", -1), 7, "mapping-only height should match source rect", failures)


func _test_rejects_empty_export_format_selection(failures: Array[String]) -> void:
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)

	var result: Dictionary = AtlasExporter.export_atlas(
		[
			{
				"name": "nothing",
				"image": image,
				"rect": Rect2i(0, 0, 4, 4),
			},
		],
		Vector2i(8, 8),
		TEST_DIR + "/nothing.png",
		{
			"export_png": false,
			"export_tres": false,
			"export_res": false,
			"export_mapping": false,
		}
	)

	_expect_equal(result.get("error", OK), ERR_INVALID_PARAMETER, "export with no selected formats should be rejected", failures)


func _test_exports_multiple_atlas_pages_when_needed(failures: Array[String]) -> void:
	var items: Array[Dictionary] = []
	for i: int in 3:
		var image := Image.create(80, 80, false, Image.FORMAT_RGBA8)
		image.fill(Color(0.2 * i, 0.4, 1.0, 1.0))
		items.append({
			"name": "page_item_%d" % i,
			"image": image,
		})

	var output_path := TEST_DIR + "/multi_atlas.png"
	var result: Dictionary = AtlasExporter.export_multiple_atlases(
		items,
		Vector2i(90, 90),
		2,
		output_path,
		{
			"export_png": true,
			"export_tres": true,
			"export_res": false,
			"export_mapping": true,
			"output_folder_name": "multi_atlas",
			"mapping_file_name": "multi_atlas_map",
		}
	)
	var pages: Array = result.get("pages", [])

	_expect_equal(result.get("error", FAILED), OK, "multi-atlas export should succeed", failures)
	_expect_equal(pages.size(), 3, "multi-atlas export should create one page per large item", failures)
	_expect_true(not FileAccess.file_exists(TEST_DIR + "/multi_atlas_01.png"), "first atlas page PNG should not be written outside the named output folder", failures)
	_expect_true(not FileAccess.file_exists(TEST_DIR + "/multi_atlas_02.png"), "second atlas page PNG should not be written outside the named output folder", failures)
	_expect_true(not FileAccess.file_exists(TEST_DIR + "/multi_atlas_03.png"), "third atlas page PNG should not be written outside the named output folder", failures)
	_expect_true(FileAccess.file_exists(TEST_DIR + "/multi_atlas/multi_atlas_01.png"), "first atlas page PNG should be written inside the named output folder", failures)
	_expect_true(FileAccess.file_exists(TEST_DIR + "/multi_atlas/multi_atlas_02.png"), "second atlas page PNG should be written inside the named output folder", failures)
	_expect_true(FileAccess.file_exists(TEST_DIR + "/multi_atlas/multi_atlas_03.png"), "third atlas page PNG should be written inside the named output folder", failures)
	_expect_true(not FileAccess.file_exists(TEST_DIR + "/multi_atlas/multi_atlas_01.res"), "first page should not create .res when .res export is disabled", failures)
	_expect_true(FileAccess.file_exists(TEST_DIR + "/multi_atlas/page_item_0.tres"), "first page should create AtlasTexture resources when .tres export is enabled", failures)
	_expect_true(FileAccess.file_exists(TEST_DIR + "/multi_atlas/multi_atlas_map.json"), "multi-page mapping JSON should be written once", failures)

	var first_page_text := FileAccess.get_file_as_string(TEST_DIR + "/multi_atlas/page_item_0.tres")
	var second_page_text := FileAccess.get_file_as_string(TEST_DIR + "/multi_atlas/page_item_1.tres")
	_expect_true(TEST_DIR + "/multi_atlas/multi_atlas_01.png" in first_page_text, "first page AtlasTexture should reference the first folder-local PNG page", failures)
	_expect_true(TEST_DIR + "/multi_atlas/multi_atlas_02.png" in second_page_text, "second page AtlasTexture should reference the second folder-local PNG page", failures)

	var mapping := _read_json(TEST_DIR + "/multi_atlas/multi_atlas_map.json")
	var mapping_pages: Array = mapping.get("pages", [])
	_expect_equal(mapping_pages.size(), 3, "multi-page mapping should include all pages", failures)
	if mapping_pages.size() == 3:
		_expect_equal(mapping_pages[0].get("image", ""), "multi_atlas_01.png", "first mapping page should reference first PNG page", failures)
		_expect_equal(mapping_pages[1].get("image", ""), "multi_atlas_02.png", "second mapping page should reference second PNG page", failures)


func _test_exports_explicit_preview_pages(failures: Array[String]) -> void:
	var green_image := Image.create(12, 10, false, Image.FORMAT_RGBA8)
	green_image.fill(Color.GREEN)
	var yellow_image := Image.create(6, 8, false, Image.FORMAT_RGBA8)
	yellow_image.fill(Color.YELLOW)

	var items: Array[Dictionary] = [
		{
			"name": "green",
			"image": green_image,
		},
		{
			"name": "yellow",
			"image": yellow_image,
		},
	]
	var pages: Array[Dictionary] = [
		{
			"item_indices": [0],
			"rects_by_index": {
				0: Rect2i(3, 4, 12, 10),
			},
		},
		{
			"item_indices": [1],
			"rects_by_index": {
				1: Rect2i(20, 5, 6, 8),
			},
		},
	]

	var output_path := TEST_DIR + "/explicit_pages.png"
	var result: Dictionary = AtlasExporter.export_atlas_pages(
		items,
		pages,
		Vector2i(32, 32),
		output_path,
		{
			"export_png": false,
			"export_tres": true,
			"export_res": true,
			"export_mapping": false,
			"output_folder_name": "explicit_pages",
			"atlas_texture_resource_name": "explicit_pages",
		}
	)
	var page_results: Array = result.get("pages", [])

	_expect_equal(result.get("error", FAILED), OK, "explicit page export should succeed", failures)
	_expect_equal(page_results.size(), 2, "explicit page export should keep the supplied page count", failures)
	_expect_true(not FileAccess.file_exists(TEST_DIR + "/explicit_pages_01.png"), "first explicit page PNG should not be written when PNG export is disabled", failures)
	_expect_true(not FileAccess.file_exists(TEST_DIR + "/explicit_pages_02.png"), "second explicit page PNG should not be written when PNG export is disabled", failures)

	var green_atlas := ResourceLoader.load(TEST_DIR + "/explicit_pages/green.tres", "AtlasTexture", ResourceLoader.CACHE_MODE_IGNORE) as AtlasTexture
	var yellow_atlas := ResourceLoader.load(TEST_DIR + "/explicit_pages/yellow.tres", "AtlasTexture", ResourceLoader.CACHE_MODE_IGNORE) as AtlasTexture

	_expect_true(green_atlas != null, "first explicit page AtlasTexture should load immediately", failures)
	_expect_true(yellow_atlas != null, "second explicit page AtlasTexture should load immediately", failures)
	if green_atlas:
		_expect_equal(green_atlas.region, Rect2(3, 4, 12, 10), "first explicit page should use the supplied region", failures)
	if yellow_atlas:
		_expect_equal(yellow_atlas.region, Rect2(20, 5, 6, 8), "second explicit page should use the supplied region", failures)


func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	return {}


func _prepare_test_dir() -> void:
	_cleanup_test_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))


func _cleanup_test_dir() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(TEST_DIR)):
		return

	_delete_dir_recursive(ProjectSettings.globalize_path(TEST_DIR))


func _delete_dir_recursive(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var child_path := path.path_join(entry)
			if dir.current_is_dir():
				_delete_dir_recursive(child_path)
			else:
				DirAccess.remove_absolute(child_path)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


func _expect_true(value: bool, message: String, failures: Array[String]) -> void:
	if not value:
		failures.append(message)


func _expect_equal(actual: Variant, expected: Variant, message: String, failures: Array[String]) -> void:
	if actual != expected:
		failures.append("%s. Expected %s, got %s" % [message, expected, actual])
