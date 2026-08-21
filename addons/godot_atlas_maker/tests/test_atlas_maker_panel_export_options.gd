extends SceneTree

const PanelScene = preload("res://addons/godot_atlas_maker/atlas_maker_panel.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var panel = PanelScene.instantiate()
	root.add_child(panel)
	await process_frame
	await process_frame

	panel.pending_export_atlas_name = "student_idle"
	panel.pending_export_folder_name = "resources"
	var options: Dictionary = panel._build_export_options()

	_expect_true(panel.export_tres_check_box.button_pressed, "AtlasTexture export should be selected by default", failures)
	_expect_true(panel.export_res_check_box.button_pressed, ".res atlas export should be selected by default", failures)
	_expect_equal(options.get("output_folder_name", ""), "resources", "target folder name should be independent from atlas name", failures)
	_expect_equal(options.get("atlas_texture_resource_name", ""), "student_idle", "atlas texture resource should use the atlas name", failures)
	_expect_equal(options.get("mapping_file_name", ""), "student_idle_map", "mapping file should use the atlas name", failures)
	_expect_equal(panel.atlas_name_dialog.max_size.y, 220, "atlas naming dialog height should remain bounded", failures)

	panel.queue_free()
	if failures.is_empty():
		print("AtlasMakerPanel export option tests passed")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _expect_equal(actual: Variant, expected: Variant, message: String, failures: Array[String]) -> void:
	if actual != expected:
		failures.append("%s. Expected %s, got %s" % [message, expected, actual])


func _expect_true(value: bool, message: String, failures: Array[String]) -> void:
	if not value:
		failures.append(message)
