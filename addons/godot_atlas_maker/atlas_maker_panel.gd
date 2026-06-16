@tool
extends Control

const AtlasPacker = preload("res://addons/godot_atlas_maker/atlas_packer.gd")
const AtlasExporter = preload("res://addons/godot_atlas_maker/atlas_exporter.gd")

# UI 节点引用（延迟获取）
var add_images_button
var add_folder_button
var clear_button
var auto_arrange_button
var export_button

var atlas_size_option
var padding_spinbox
var image_count_label
var export_png_check_box
var export_tres_check_box
var export_res_check_box
var export_mapping_check_box

var image_list
var preview_canvas
var preview_page_bar
var preview_page_option
var preview_page_summary_label

var file_dialog
var folder_dialog
var export_dialog
var atlas_name_dialog
var atlas_name_line_edit
var size_decision_dialog

# 数据
var loaded_images: Array[Dictionary] = []  # {name: String, texture: Texture2D, rect: Rect2}
var atlas_size: Vector2i = Vector2i(1024, 1024)
var padding: int = 2
var unplaced_image_indices: Array[int] = []
var atlas_pages: Array[Dictionary] = []
var preview_page_index: int = 0
var pending_split_export_path: String = ""
var pending_export_atlas_name: String = ""
var export_button_idle_text: String = ""

# 拖拽相关
var dragging_sprite: Dictionary = {}
var drag_offset: Vector2 = Vector2.ZERO


func _ready():
	# 手动获取所有节点引用
	add_images_button = $MarginContainer/VBoxContainer/TopPanel/TopMargin/VBox/ButtonsHBox/AddImagesButton
	add_folder_button = $MarginContainer/VBoxContainer/TopPanel/TopMargin/VBox/ButtonsHBox/AddFolderButton
	clear_button = $MarginContainer/VBoxContainer/TopPanel/TopMargin/VBox/ButtonsHBox/ClearButton
	auto_arrange_button = $MarginContainer/VBoxContainer/TopPanel/TopMargin/VBox/ButtonsHBox/AutoArrangeButton
	export_button = $MarginContainer/VBoxContainer/TopPanel/TopMargin/VBox/ButtonsHBox/ExportButton
	if export_button:
		export_button_idle_text = str(export_button.text)

	atlas_size_option = $MarginContainer/VBoxContainer/TopPanel/TopMargin/VBox/SettingsHBox/AtlasSizeOption
	padding_spinbox = $MarginContainer/VBoxContainer/TopPanel/TopMargin/VBox/SettingsHBox/PaddingSpinBox
	image_count_label = $MarginContainer/VBoxContainer/TopPanel/TopMargin/VBox/SettingsHBox/ImageCountLabel

	image_list = $MarginContainer/VBoxContainer/MainHSplit/LeftPanel/LeftMargin/VBox/ImageListScroll/ImageList
	preview_canvas = $MarginContainer/VBoxContainer/MainHSplit/RightPanel/RightMargin/VBox/PreviewScroll/PreviewCanvas

	file_dialog = $FileDialog
	folder_dialog = $FolderDialog
	export_dialog = $ExportDialog
	_create_export_settings_bar()
	atlas_name_dialog = _create_atlas_name_dialog()
	_create_preview_page_bar()
	size_decision_dialog = _create_size_decision_dialog()

	# 等待父节点准备好
	await get_tree().process_frame

	# 确保对话框设置正确
	if file_dialog:
		file_dialog.visible = false
		file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		file_dialog.use_native_dialog = true
	if folder_dialog:
		folder_dialog.visible = false
		folder_dialog.access = FileDialog.ACCESS_FILESYSTEM
		folder_dialog.use_native_dialog = true
	if export_dialog:
		export_dialog.visible = false
		export_dialog.access = FileDialog.ACCESS_FILESYSTEM
		export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		export_dialog.use_native_dialog = false
	_create_source_hint_label()

	# 初始化图集尺寸选项
	if atlas_size_option:
		atlas_size_option.clear()
		atlas_size_option.add_item("512 x 512", 512)
		atlas_size_option.add_item("1024 x 1024", 1024)
		atlas_size_option.add_item("2048 x 2048", 2048)
		atlas_size_option.add_item("4096 x 4096", 4096)
		atlas_size_option.select(1)  # 默认选择 1024
		atlas_size_option.item_selected.connect(_on_atlas_size_changed)

	if padding_spinbox:
		padding_spinbox.value_changed.connect(_on_padding_changed)

	# 设置预览画布
	if preview_canvas:
		preview_canvas.custom_minimum_size = Vector2(atlas_size)
		preview_canvas.draw.connect(_on_preview_canvas_draw)
		preview_canvas.gui_input.connect(_on_preview_canvas_input)

	print("✓ 精灵图集制作工具已初始化")
	print("  - 已加载 UI 节点")
	print("  - 文件对话框已准备")


func _notification(what):
	if what == NOTIFICATION_RESIZED:
		# 窗口大小改变时自动调整
		queue_redraw()


func _on_add_images_pressed():
	print("📁 点击了添加图片按钮")
	if file_dialog:
		file_dialog.popup_centered()
		print("  - 文件对话框已弹出")
	else:
		push_error("文件对话框未找到！")


func _on_add_folder_pressed():
	print("📂 点击了添加文件夹按钮")
	if folder_dialog:
		folder_dialog.popup_centered()
		print("  - 文件夹对话框已弹出")
	else:
		push_error("文件夹对话框未找到！")


func _on_clear_pressed():
	loaded_images.clear()
	_clear_layout_state()
	pending_split_export_path = ""
	pending_export_atlas_name = ""
	_update_image_list()
	_update_preview()


func _on_auto_arrange_pressed():
	if loaded_images.is_empty():
		push_warning("没有加载的图片")
		return

	_auto_arrange_images()
	_update_preview()


func _on_export_pressed():
	if loaded_images.is_empty():
		push_warning("没有可导出的图片")
		return

	if not _has_selected_export_format():
		push_warning("请至少勾选一种导出格式：PNG图集、Godot切图资源、Godot .res图集或JSON区域映射。")
		return

	_request_export_atlas_name()


func _request_export_atlas_name() -> void:
	if atlas_name_dialog == null or atlas_name_line_edit == null:
		pending_export_atlas_name = _default_atlas_name()
		_popup_export_dialog_for_atlas_name()
		return

	atlas_name_line_edit.text = _default_atlas_name()
	atlas_name_dialog.popup_centered(Vector2i(420, 170))
	atlas_name_line_edit.grab_focus()
	atlas_name_line_edit.select_all()


func _default_atlas_name() -> String:
	if not pending_export_atlas_name.is_empty():
		return pending_export_atlas_name
	if not loaded_images.is_empty():
		return _safe_export_name(str(loaded_images[0].get("name", "sprite_atlas")))
	return "sprite_atlas"


func _on_export_name_confirmed() -> void:
	var raw_name: String = atlas_name_line_edit.text if atlas_name_line_edit else ""
	var atlas_name := _safe_export_name(raw_name)
	if atlas_name.is_empty():
		push_warning("请输入图集名称")
		_request_export_atlas_name()
		return

	pending_export_atlas_name = atlas_name
	_popup_export_dialog_for_atlas_name()


func _on_export_name_submitted(_text: String) -> void:
	if atlas_name_dialog:
		atlas_name_dialog.hide()
	_on_export_name_confirmed()


func _on_export_name_canceled() -> void:
	pending_export_atlas_name = ""


func _popup_export_dialog_for_atlas_name() -> void:
	if export_dialog:
		export_dialog.access = FileDialog.ACCESS_FILESYSTEM
		export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		export_dialog.use_native_dialog = false
		export_dialog.current_file = pending_export_atlas_name + ".png"
		export_dialog.popup_centered()


func _on_files_selected(paths: PackedStringArray):
	for path in paths:
		_load_image(path)

	_update_image_list()
	_update_preview()


func _on_folder_selected(path: String):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()

		while file_name != "":
			if not dir.current_is_dir():
				var full_path = path + "/" + file_name
				if _is_image_file(file_name):
					_load_image(full_path)
			file_name = dir.get_next()

		dir.list_dir_end()

	_update_image_list()
	_update_preview()


func _on_export_file_selected(path: String) -> void:
	var named_output_path := _named_output_path(path)
	var normalized_output_path := _normalize_png_output_path(named_output_path)
	var export_options := _build_export_options()

	print("==================================================")
	print("开始导出图集")
	print("  - 用户选择路径: ", path)
	print("  - 实际输出基准: ", normalized_output_path)
	print("  - 图集名称: ", export_options.get("output_folder_name", pending_export_atlas_name))
	print("  - 导出 PNG: ", export_options.get("export_png", false))
	print("  - 导出 .tres: ", export_options.get("export_tres", false))
	print("  - 导出 .res: ", export_options.get("export_res", false))
	print("  - 导出 JSON: ", export_options.get("export_mapping", false))
	print("==================================================")

	_set_export_busy(true)
	await get_tree().process_frame
	_export_atlas(normalized_output_path)
	_set_export_busy(false)


func _set_export_busy(is_busy: bool) -> void:
	if export_button == null:
		return

	export_button.disabled = is_busy
	if is_busy:
		export_button.text = "导出中..."
	else:
		export_button.text = export_button_idle_text if not export_button_idle_text.is_empty() else "导出"


func _on_atlas_size_changed(index: int):
	var size = atlas_size_option.get_item_id(index)
	atlas_size = Vector2i(size, size)
	_clear_layout_state()
	preview_canvas.custom_minimum_size = Vector2(atlas_size)
	preview_canvas.queue_redraw()


func _on_padding_changed(value: float):
	padding = int(value)
	_clear_layout_state()


func _load_image(path: String):
	var texture := _load_texture_from_path(path)
	if texture:
		var img_data = {
			"name": path.get_file().get_basename(),
			"path": path,
			"texture": texture,
			"rect": Rect2(0, 0, texture.get_width(), texture.get_height())
		}
		loaded_images.append(img_data)
		_clear_layout_state()
		print("✓ 已加载: ", path)
	else:
		push_warning("无法加载图片：%s" % path)


func _load_texture_from_path(path: String) -> Texture2D:
	if path.begins_with("res://") or path.begins_with("uid://"):
		var resource_texture := load(path) as Texture2D
		if resource_texture:
			return resource_texture

	var image := Image.new()
	var error := image.load(path)
	if error != OK:
		return null

	return ImageTexture.create_from_image(image)


func _is_image_file(filename: String) -> bool:
	var ext = filename.get_extension().to_lower()
	return ext in ["png", "jpg", "jpeg", "webp", "bmp"]


func _update_image_list():
	# 清空列表
	for child in image_list.get_children():
		child.queue_free()

	# 添加图片项
	for i in loaded_images.size():
		var img_data = loaded_images[i]
		var item = _create_image_list_item(img_data, i)
		image_list.add_child(item)

	# 更新计数
	image_count_label.text = "已加载: %d 张图片" % loaded_images.size()


func _create_image_list_item(img_data: Dictionary, index: int) -> Control:
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 50)

	# 缩略图
	var thumbnail = TextureRect.new()
	thumbnail.texture = img_data.texture
	thumbnail.custom_minimum_size = Vector2(40, 40)
	thumbnail.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(thumbnail)

	# 名称和信息
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label = Label.new()
	name_label.text = img_data.name
	name_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(name_label)

	var size_label = Label.new()
	var size = img_data.texture.get_size()
	size_label.text = "%d x %d" % [size.x, size.y]
	size_label.add_theme_font_size_override("font_size", 10)
	size_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(size_label)

	hbox.add_child(vbox)

	# 删除按钮
	var delete_btn = Button.new()
	delete_btn.text = "×"
	delete_btn.custom_minimum_size = Vector2(30, 0)
	delete_btn.pressed.connect(func(): _remove_image(index))
	hbox.add_child(delete_btn)

	return hbox


func _create_export_settings_bar() -> void:
	var top_vbox := $MarginContainer/VBoxContainer/TopPanel/TopMargin/VBox

	var export_settings_hbox := HBoxContainer.new()
	export_settings_hbox.name = "ExportSettingsHBox"
	export_settings_hbox.add_theme_constant_override("separation", 10)
	export_settings_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	export_png_check_box = CheckBox.new()
	export_png_check_box.text = "PNG图集"
	export_png_check_box.button_pressed = true
	export_png_check_box.tooltip_text = "生成合并后的 PNG 图集。默认会保存到同名导出文件夹内，适合 Web 发布。"
	export_settings_hbox.add_child(export_png_check_box)

	export_tres_check_box = CheckBox.new()
	export_tres_check_box.text = "Godot切图资源(.tres)"
	export_tres_check_box.button_pressed = true
	export_tres_check_box.tooltip_text = "为每个素材生成 AtlasTexture .tres，直接引用 PNG 图集中的对应区域，可在 Godot 里直接拖用。"
	export_settings_hbox.add_child(export_tres_check_box)

	export_res_check_box = CheckBox.new()
	export_res_check_box.text = "Godot .res图集"
	export_res_check_box.button_pressed = false
	export_res_check_box.tooltip_text = "额外生成二进制 .res 图集纹理。会增加文件体积，通常只在确实需要纯 Godot 资源链路时启用。"
	export_settings_hbox.add_child(export_res_check_box)

	export_mapping_check_box = CheckBox.new()
	export_mapping_check_box.text = "JSON区域映射"
	export_mapping_check_box.button_pressed = false
	export_mapping_check_box.tooltip_text = "额外生成 JSON，记录每个素材在图集中的 x/y/w/h 区域和多页信息，适合自定义运行时代码或外部工具读取。"
	export_settings_hbox.add_child(export_mapping_check_box)

	var naming_hint := Label.new()
	naming_hint.text = "导出时输入图集名称；PNG、.tres、.res 和 JSON 都会保存到同名文件夹内。"
	naming_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	naming_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	naming_hint.add_theme_font_size_override("font_size", 11)
	naming_hint.add_theme_color_override("font_color", Color(0.72, 0.78, 0.84))
	export_settings_hbox.add_child(naming_hint)

	top_vbox.add_child(export_settings_hbox)
	top_vbox.move_child(export_settings_hbox, 5)


func _create_atlas_name_dialog() -> ConfirmationDialog:
	var dialog := ConfirmationDialog.new()
	dialog.name = "AtlasNameDialog"
	dialog.title = "输入图集名称"
	dialog.ok_button_text = "下一步"
	dialog.cancel_button_text = "取消"
	dialog.confirmed.connect(_on_export_name_confirmed)
	dialog.canceled.connect(_on_export_name_canceled)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	dialog.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var label := Label.new()
	label.text = "该名称会用于导出文件夹、PNG 文件、.res 文件和 JSON 映射文件。"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(label)

	atlas_name_line_edit = LineEdit.new()
	atlas_name_line_edit.placeholder_text = "例如 male_default_idle"
	atlas_name_line_edit.custom_minimum_size = Vector2(320, 0)
	atlas_name_line_edit.text_submitted.connect(_on_export_name_submitted)
	vbox.add_child(atlas_name_line_edit)

	add_child(dialog)
	return dialog


func _create_source_hint_label() -> void:
	var top_vbox := $MarginContainer/VBoxContainer/TopPanel/TopMargin/VBox
	if top_vbox.has_node("SourceHintLabel"):
		return

	var hint_label := Label.new()
	hint_label.name = "SourceHintLabel"
	hint_label.text = "图片来源：支持项目内 res:// 和项目外文件；项目外图片会读取到内存，导出资源仍保存到所选输出路径。"
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_font_size_override("font_size", 11)
	hint_label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.84))
	top_vbox.add_child(hint_label)
	top_vbox.move_child(hint_label, 6)


func _remove_image(index: int):
	if index >= 0 and index < loaded_images.size():
		loaded_images.remove_at(index)
		_clear_layout_state()
		_update_image_list()
		_update_preview()


func _create_preview_page_bar() -> void:
	var right_vbox := $MarginContainer/VBoxContainer/MainHSplit/RightPanel/RightMargin/VBox

	preview_page_bar = HBoxContainer.new()
	preview_page_bar.name = "PreviewPageBar"
	preview_page_bar.visible = false
	preview_page_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_page_bar.add_theme_constant_override("separation", 8)

	var page_label := Label.new()
	page_label.text = "图集页:"
	preview_page_bar.add_child(page_label)

	preview_page_option = OptionButton.new()
	preview_page_option.custom_minimum_size = Vector2(140, 0)
	preview_page_option.item_selected.connect(_on_preview_page_selected)
	preview_page_bar.add_child(preview_page_option)

	preview_page_summary_label = Label.new()
	preview_page_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_page_bar.add_child(preview_page_summary_label)

	right_vbox.add_child(preview_page_bar)
	right_vbox.move_child(preview_page_bar, 2)


func _create_size_decision_dialog() -> ConfirmationDialog:
	var dialog := ConfirmationDialog.new()
	dialog.name = "AtlasSizeDecisionDialog"
	dialog.title = "图集尺寸不足"
	dialog.ok_button_text = "拆分为多图"
	dialog.cancel_button_text = "取消"
	dialog.dialog_text = ""
	dialog.confirmed.connect(_on_use_multiple_pages_confirmed)
	dialog.custom_action.connect(_on_size_decision_custom_action)
	dialog.add_button("改用更大尺寸", false, "increase_size")
	add_child(dialog)
	return dialog


func _clear_layout_state() -> void:
	unplaced_image_indices.clear()
	atlas_pages.clear()
	preview_page_index = 0
	dragging_sprite = {}
	_update_preview_page_controls()


func _update_preview():
	preview_canvas.queue_redraw()


func _on_preview_canvas_draw():
	var canvas = preview_canvas

	# 绘制背景网格
	_draw_grid(canvas)

	# 绘制边框
	canvas.draw_rect(Rect2(Vector2.ZERO, atlas_size), Color.WHITE, false, 2.0)

	# 绘制当前图集页的图片
	for preview_item: Dictionary in _get_current_preview_items():
		var rect: Rect2 = preview_item["rect"]
		var texture: Texture2D = preview_item["texture"]

		# 绘制图片
		canvas.draw_texture_rect(texture, rect, false)

		# 绘制边框
		canvas.draw_rect(rect, Color(0, 1, 1, 0.5), false, 1.0)

		# 绘制名称
		var font = canvas.get_theme_default_font()
		var font_size = 12
		canvas.draw_string(font, rect.position + Vector2(2, 15), preview_item["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _draw_grid(canvas: Control):
	var grid_size = 64
	var grid_color = Color(0.3, 0.3, 0.3, 0.3)

	# 垂直线
	for x in range(0, atlas_size.x, grid_size):
		canvas.draw_line(Vector2(x, 0), Vector2(x, atlas_size.y), grid_color, 1.0)

	# 水平线
	for y in range(0, atlas_size.y, grid_size):
		canvas.draw_line(Vector2(0, y), Vector2(atlas_size.x, y), grid_color, 1.0)


func _on_preview_canvas_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# 开始拖拽
				var mouse_pos = event.position
				for preview_item: Dictionary in _get_current_preview_items():
					var rect: Rect2 = preview_item["rect"]
					if rect.has_point(mouse_pos):
						dragging_sprite = {
							"image_index": preview_item["index"],
							"page_index": preview_page_index,
						}
						drag_offset = mouse_pos - rect.position
						break
			else:
				# 结束拖拽
				dragging_sprite = {}

	elif event is InputEventMouseMotion:
		if not dragging_sprite.is_empty():
			# 拖动图片
			var image_index: int = dragging_sprite.get("image_index", -1)
			if image_index < 0 or image_index >= loaded_images.size():
				return

			var current_rect := _get_preview_rect_for_image(image_index)
			var new_pos: Vector2 = event.position - drag_offset
			var clamped_pos: Vector2 = new_pos.clamp(Vector2.ZERO, Vector2(atlas_size) - current_rect.size)
			_set_preview_rect_for_image(image_index, Rect2(clamped_pos, current_rect.size))
			_update_preview()


func _auto_arrange_images():
	var image_sizes := _get_image_sizes()

	var pack_result: Dictionary = AtlasPacker.pack(image_sizes, atlas_size, padding)
	var rects: Array = pack_result.get("rects", [])
	var placed_indices: Array = pack_result.get("placed_indices", [])
	var unplaced_indices: Array = pack_result.get("unplaced_indices", [])
	_clear_layout_state()

	for index: int in placed_indices:
		var packed_rect: Rect2i = rects[index]
		loaded_images[index].rect = Rect2(
			Vector2(packed_rect.position.x, packed_rect.position.y),
			Vector2(packed_rect.size.x, packed_rect.size.y)
		)

	if not unplaced_indices.is_empty():
		for index: int in unplaced_indices:
			unplaced_image_indices.append(index)
		push_warning("图集尺寸不够，%d 张图片未能放入：%s。" % [unplaced_indices.size(), str(unplaced_indices)])
		_request_size_decision()

	print("✓ 自动排列完成（MaxRects：已放置 %d/%d）" % [placed_indices.size(), loaded_images.size()])


func _export_atlas(output_path: String):
	if loaded_images.is_empty():
		return

	var normalized_output_path := _normalize_png_output_path(output_path)
	if not atlas_pages.is_empty():
		_export_preview_pages(normalized_output_path)
		return

	var current_unplaced_indices := _find_unplaced_indices_for_current_size()
	if not current_unplaced_indices.is_empty():
		unplaced_image_indices.assign(current_unplaced_indices)
		_request_size_decision(normalized_output_path)
		return

	var export_items := _build_export_items(true)

	var result: Dictionary = AtlasExporter.export_atlas(export_items, atlas_size, normalized_output_path, _build_export_options())
	if result.get("error", FAILED) != OK:
		push_error("❌ 导出失败: %s" % result.get("message", "未知错误"))
		return

	_print_single_export_success(result, normalized_output_path)


func _get_image_sizes() -> Array[Vector2i]:
	var image_sizes: Array[Vector2i] = []
	for img_data in loaded_images:
		image_sizes.append(Vector2i(img_data.texture.get_width(), img_data.texture.get_height()))

	return image_sizes


func _find_unplaced_indices_for_current_size() -> Array[int]:
	var pack_result: Dictionary = AtlasPacker.pack(_get_image_sizes(), atlas_size, padding)
	var unplaced_indices: Array = pack_result.get("unplaced_indices", [])
	var typed_unplaced_indices: Array[int] = []
	for index: int in unplaced_indices:
		typed_unplaced_indices.append(index)

	return typed_unplaced_indices


func _request_size_decision(output_path: String = "") -> void:
	pending_split_export_path = _normalize_png_output_path(output_path) if not output_path.is_empty() else ""

	if size_decision_dialog == null:
		_apply_multiple_page_layout()
		_export_pending_path_if_needed()
		return

	var multi_page_result := AtlasPacker.pack_multiple(_get_image_sizes(), atlas_size, padding)
	var page_count: int = multi_page_result.get("pages", []).size()
	var next_size := _find_next_fitting_atlas_size()
	var size_text := "%d x %d" % [next_size, next_size] if next_size > 0 else "没有可用的更大预设尺寸"

	size_decision_dialog.dialog_text = (
		"当前 %d x %d 图集无法容纳全部图片，仍有 %d 张未放入。\n\n"
		+ "可以按当前尺寸拆分为 %d 个图集页，或改用更大尺寸：%s。"
	) % [atlas_size.x, atlas_size.y, unplaced_image_indices.size(), page_count, size_text]
	size_decision_dialog.popup_centered(Vector2i(520, 220))


func _on_use_multiple_pages_confirmed() -> void:
	if not _apply_multiple_page_layout():
		pending_split_export_path = ""
		return

	_export_pending_path_if_needed()


func _on_size_decision_custom_action(action: StringName) -> void:
	if action != &"increase_size":
		return

	if size_decision_dialog:
		size_decision_dialog.hide()

	if not _apply_next_fitting_atlas_size():
		pending_split_export_path = ""
		return

	_export_pending_path_if_needed()


func _export_pending_path_if_needed() -> void:
	if pending_split_export_path.is_empty():
		return

	var output_path := pending_split_export_path
	pending_split_export_path = ""
	_export_atlas(output_path)


func _apply_multiple_page_layout() -> bool:
	var pack_result: Dictionary = AtlasPacker.pack_multiple(_get_image_sizes(), atlas_size, padding)
	var pages: Array = pack_result.get("pages", [])
	var unplaced_indices: Array = pack_result.get("unplaced_indices", [])
	unplaced_image_indices.clear()

	for index: int in unplaced_indices:
		unplaced_image_indices.append(index)

	if not unplaced_indices.is_empty():
		push_error("当前图集尺寸下仍有图片单张过大，无法拆分放入。请改用更大尺寸。未放入索引：%s" % str(unplaced_indices))
		return false

	if pages.is_empty():
		push_error("无法生成多图集布局。")
		return false

	atlas_pages.clear()
	for page: Dictionary in pages:
		atlas_pages.append(page.duplicate(true))

	preview_page_index = 0
	_apply_page_rects_to_loaded_images(preview_page_index)
	_update_preview_page_controls()
	_update_preview()
	print("✓ 已按当前尺寸拆分为 %d 个图集页" % atlas_pages.size())
	return true


func _apply_next_fitting_atlas_size() -> bool:
	var next_size := _find_next_fitting_atlas_size()
	if next_size <= 0:
		push_error("没有找到能容纳全部图片的更大预设尺寸，请减少图片或手动拆分素材。")
		return false

	_set_atlas_size(next_size)
	_auto_arrange_images()
	return true


func _find_next_fitting_atlas_size() -> int:
	var candidate_sizes: Array[int] = []
	for i: int in atlas_size_option.get_item_count():
		var candidate_size: int = atlas_size_option.get_item_id(i)
		if candidate_size > atlas_size.x:
			candidate_sizes.append(candidate_size)
	candidate_sizes.sort()

	var image_sizes := _get_image_sizes()
	for candidate_size: int in candidate_sizes:
		var pack_result: Dictionary = AtlasPacker.pack(image_sizes, Vector2i(candidate_size, candidate_size), padding)
		var unplaced_indices: Array = pack_result.get("unplaced_indices", [])
		if unplaced_indices.is_empty():
			return candidate_size

	return 0


func _set_atlas_size(size: int) -> void:
	atlas_size = Vector2i(size, size)
	if atlas_size_option:
		for i: int in atlas_size_option.get_item_count():
			if atlas_size_option.get_item_id(i) == size:
				atlas_size_option.select(i)
				break
	if preview_canvas:
		preview_canvas.custom_minimum_size = Vector2(atlas_size)


func _export_preview_pages(output_path: String) -> void:
	var export_items := _build_export_items(false)
	var result: Dictionary = AtlasExporter.export_atlas_pages(export_items, atlas_pages, atlas_size, output_path, _build_export_options())
	if result.get("error", FAILED) != OK:
		push_error("❌ 拆分导出失败: %s" % result.get("message", "未知错误"))
		return

	_print_multi_export_success(result)


func _update_preview_page_controls() -> void:
	if preview_page_bar == null or preview_page_option == null or preview_page_summary_label == null:
		return

	preview_page_bar.visible = atlas_pages.size() > 1
	preview_page_option.clear()
	for page_index: int in atlas_pages.size():
		var page: Dictionary = atlas_pages[page_index]
		var item_indices: Array = page.get("item_indices", [])
		preview_page_option.add_item("第 %d 页 (%d 张)" % [page_index + 1, item_indices.size()], page_index)

	if not atlas_pages.is_empty():
		preview_page_index = clampi(preview_page_index, 0, atlas_pages.size() - 1)
		preview_page_option.select(preview_page_index)
		preview_page_summary_label.text = "共 %d 页，当前尺寸 %d x %d" % [atlas_pages.size(), atlas_size.x, atlas_size.y]
	else:
		preview_page_index = 0
		preview_page_summary_label.text = ""


func _on_preview_page_selected(index: int) -> void:
	preview_page_index = index
	_apply_page_rects_to_loaded_images(preview_page_index)
	_update_preview()


func _apply_page_rects_to_loaded_images(page_index: int) -> void:
	if page_index < 0 or page_index >= atlas_pages.size():
		return

	var page: Dictionary = atlas_pages[page_index]
	var item_indices: Array = page.get("item_indices", [])
	var rects_by_index: Dictionary = page.get("rects_by_index", {})
	for image_index: int in item_indices:
		if image_index < 0 or image_index >= loaded_images.size():
			continue
		var rect: Rect2i = rects_by_index.get(image_index, Rect2i())
		loaded_images[image_index].rect = Rect2(
			Vector2(rect.position.x, rect.position.y),
			Vector2(rect.size.x, rect.size.y)
		)


func _get_current_preview_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []

	if atlas_pages.is_empty():
		for image_index: int in loaded_images.size():
			var img_data: Dictionary = loaded_images[image_index]
			items.append({
				"index": image_index,
				"name": img_data.name,
				"texture": img_data.texture,
				"rect": img_data.rect,
			})
		return items

	if preview_page_index < 0 or preview_page_index >= atlas_pages.size():
		return items

	var page: Dictionary = atlas_pages[preview_page_index]
	var item_indices: Array = page.get("item_indices", [])
	var rects_by_index: Dictionary = page.get("rects_by_index", {})
	for image_index: int in item_indices:
		if image_index < 0 or image_index >= loaded_images.size():
			continue
		var img_data: Dictionary = loaded_images[image_index]
		var rect: Rect2i = rects_by_index.get(image_index, Rect2i())
		items.append({
			"index": image_index,
			"name": img_data.name,
			"texture": img_data.texture,
			"rect": Rect2(Vector2(rect.position.x, rect.position.y), Vector2(rect.size.x, rect.size.y)),
		})

	return items


func _get_preview_rect_for_image(image_index: int) -> Rect2:
	if atlas_pages.is_empty():
		return loaded_images[image_index].rect

	if preview_page_index < 0 or preview_page_index >= atlas_pages.size():
		return Rect2()

	var page: Dictionary = atlas_pages[preview_page_index]
	var rects_by_index: Dictionary = page.get("rects_by_index", {})
	var rect: Rect2i = rects_by_index.get(image_index, Rect2i())
	return Rect2(Vector2(rect.position.x, rect.position.y), Vector2(rect.size.x, rect.size.y))


func _set_preview_rect_for_image(image_index: int, rect: Rect2) -> void:
	loaded_images[image_index].rect = rect

	if atlas_pages.is_empty():
		return

	if preview_page_index < 0 or preview_page_index >= atlas_pages.size():
		return

	var page: Dictionary = atlas_pages[preview_page_index]
	var rects_by_index: Dictionary = page.get("rects_by_index", {})
	rects_by_index[image_index] = Rect2i(
		Vector2i(roundi(rect.position.x), roundi(rect.position.y)),
		Vector2i(roundi(rect.size.x), roundi(rect.size.y))
	)
	page["rects_by_index"] = rects_by_index
	atlas_pages[preview_page_index] = page


func _build_export_items(include_rects: bool) -> Array[Dictionary]:
	var export_items: Array[Dictionary] = []
	for img_data in loaded_images:
		var item := {
			"name": img_data.name,
			"texture": img_data.texture,
		}
		if include_rects:
			item["rect"] = img_data.rect
		export_items.append(item)

	return export_items


func _build_export_options() -> Dictionary:
	var atlas_name := _safe_export_name(pending_export_atlas_name)
	if atlas_name.is_empty():
		atlas_name = "sprite_atlas"

	return {
		"export_png": export_png_check_box == null or export_png_check_box.button_pressed,
		"export_tres": export_tres_check_box == null or export_tres_check_box.button_pressed,
		"export_res": export_res_check_box != null and export_res_check_box.button_pressed,
		"export_mapping": export_mapping_check_box != null and export_mapping_check_box.button_pressed,
		"output_folder_name": atlas_name,
		"atlas_texture_resource_name": atlas_name,
		"mapping_file_name": atlas_name + "_map",
	}


func _has_selected_export_format() -> bool:
	return (
		(export_png_check_box != null and export_png_check_box.button_pressed)
		or (export_tres_check_box != null and export_tres_check_box.button_pressed)
		or (export_res_check_box != null and export_res_check_box.button_pressed)
		or (export_mapping_check_box != null and export_mapping_check_box.button_pressed)
	)


func _named_output_path(path: String) -> String:
	var atlas_name := _safe_export_name(pending_export_atlas_name)
	if atlas_name.is_empty():
		atlas_name = _safe_export_name(path.get_file().get_basename())
	if atlas_name.is_empty():
		atlas_name = "sprite_atlas"

	return path.get_base_dir().path_join(atlas_name + ".png")


func _normalize_png_output_path(output_path: String) -> String:
	if output_path.get_extension().is_empty():
		return output_path + ".png"
	if output_path.get_extension().to_lower() != "png":
		return output_path.get_basename() + ".png"
	return output_path


func _safe_export_name(raw_name: String) -> String:
	var name := raw_name.strip_edges().replace(" ", "_")
	var invalid_chars := ["<", ">", ":", "\"", "/", "\\", "|", "?", "*"]
	for invalid_char: String in invalid_chars:
		name = name.replace(invalid_char, "_")

	while "__" in name:
		name = name.replace("__", "_")

	return name.trim_prefix("_").trim_suffix("_")


func _print_single_export_success(result: Dictionary, output_path: String) -> void:
	var atlas_texture_paths: Dictionary = result.get("atlas_texture_paths", {})
	var mapping_path := str(result.get("mapping_path", ""))

	print("==================================================")
	print("✅ 导出成功！")
	if str(result.get("atlas_path", "")).is_empty():
		print("  - 图集图片: 未导出")
	else:
		print("  - 图集图片: ", result.get("atlas_path", output_path))
	print("  - 图集纹理资源: ", result.get("atlas_texture_resource_path", ""))
	print("  - AtlasTexture 数量: %d" % atlas_texture_paths.size())
	print("  - 区域映射数据: ", "未导出" if mapping_path.is_empty() else mapping_path)
	print("  - 保存位置: ", result.get("output_dir", ""))
	print("==================================================")


func _print_multi_export_success(result: Dictionary) -> void:
	var pages: Array = result.get("pages", [])
	var mapping_path := str(result.get("mapping_path", ""))

	print("==================================================")
	print("✅ 拆分导出成功！")
	print("  - 图集页数: %d" % pages.size())
	print("  - 区域映射数据: ", "未导出" if mapping_path.is_empty() else mapping_path)
	for page_index: int in pages.size():
		var page_result: Dictionary = pages[page_index]
		var atlas_texture_paths: Dictionary = page_result.get("atlas_texture_paths", {})
		var atlas_path := str(page_result.get("atlas_path", ""))
		if atlas_path.is_empty():
			atlas_path = "未导出PNG"
		print("  - 第 %d 页: %s（AtlasTexture: %d）" % [
			page_index + 1,
			atlas_path,
			atlas_texture_paths.size(),
		])
	print("==================================================")
