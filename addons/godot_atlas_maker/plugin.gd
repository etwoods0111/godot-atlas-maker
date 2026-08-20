@tool
extends EditorPlugin

var main_panel_instance


func _enter_tree() -> void:
	var main_panel_scene := preload("res://addons/godot_atlas_maker/atlas_maker_panel.tscn")
	main_panel_instance = main_panel_scene.instantiate()
	main_panel_instance.name = "GodotAtlasMaker"
	main_panel_instance.clip_contents = true
	main_panel_instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_panel_instance.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	EditorInterface.get_editor_main_screen().add_child(main_panel_instance)
	main_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_panel_instance.hide()


func _exit_tree() -> void:
	if main_panel_instance:
		var parent: Node = main_panel_instance.get_parent()
		if parent:
			parent.remove_child(main_panel_instance)
		main_panel_instance.queue_free()
		main_panel_instance = null


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if main_panel_instance:
		if visible:
			main_panel_instance.show()
		else:
			main_panel_instance.hide()


func _get_plugin_name() -> String:
	return "Atlas Maker"


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("Image", "EditorIcons")
