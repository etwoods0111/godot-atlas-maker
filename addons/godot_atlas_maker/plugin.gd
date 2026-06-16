@tool
extends EditorPlugin

var main_panel_instance


func _enter_tree():
	# 加载主界面场景
	var main_panel_scene = preload("res://addons/godot_atlas_maker/atlas_maker_panel.tscn")
	main_panel_instance = main_panel_scene.instantiate()

	# 设置面板名称和主屏幕布局
	main_panel_instance.name = "AtlasMaker"
	main_panel_instance.clip_contents = true
	main_panel_instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_panel_instance.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 将主面板添加到编辑器主屏幕
	EditorInterface.get_editor_main_screen().add_child(main_panel_instance)
	main_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 初始隐藏
	main_panel_instance.hide()


func _exit_tree():
	if main_panel_instance:
		var parent = main_panel_instance.get_parent()
		if parent:
			parent.remove_child(main_panel_instance)
		main_panel_instance.queue_free()
		main_panel_instance = null


func _has_main_screen():
	return true


func _make_visible(visible):
	if main_panel_instance:
		if visible:
			main_panel_instance.show()
		else:
			main_panel_instance.hide()


func _get_plugin_name():
	return "Atlas Maker"


func _get_plugin_icon():
	# 返回编辑器内置图标
	return EditorInterface.get_editor_theme().get_icon("Image", "EditorIcons")
