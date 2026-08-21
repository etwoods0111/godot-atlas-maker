@tool
extends Control

const AtlasPacker = preload("res://addons/godot_atlas_maker/atlas_packer.gd")
const AtlasExporter = preload("res://addons/godot_atlas_maker/atlas_exporter.gd")
const PreviewTransform = preload("res://addons/godot_atlas_maker/preview_transform.gd")
const AtlasLocalization = preload("res://addons/godot_atlas_maker/atlas_localization.gd")
const PreviewSnap = preload("res://addons/godot_atlas_maker/preview_snap.gd")
const PreviewPageBinding = preload("res://addons/godot_atlas_maker/preview_page_binding.gd")
const AtlasPageLayoutModel = preload("res://addons/godot_atlas_maker/atlas_page_layout.gd")
const AtlasScaleGeometry = preload("res://addons/godot_atlas_maker/atlas_scale_geometry.gd")

const ATLAS_NAME_DIALOG_SIZE_RATIO := Vector2(0.32, 0.24)
const ATLAS_NAME_DIALOG_MIN_SIZE := Vector2i(360, 190)
const ATLAS_NAME_DIALOG_MAX_SIZE := Vector2i(560, 260)
const FILE_DIALOG_SIZE_RATIO := Vector2(0.72, 0.72)
const FILE_DIALOG_MIN_SIZE := Vector2i(760, 520)
const FILE_DIALOG_MAX_SIZE := Vector2i(1280, 820)

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
var preview_scroll
var preview_canvas
var preview_canvas_row
var preview_page_bar
var preview_page_option
var preview_page_summary_label
var move_sprite_button
var preview_feedback_label
var preview_feedback_timer
var language_toggle_button
var snap_edges_check_box

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
var preview_zoom: float = 1.0
var current_locale: String = AtlasLocalization.DEFAULT_LOCALE
var snap_edges_enabled: bool = false
var hovered_sprite: Dictionary = {}
var preview_canvases: Dictionary = {}
var preview_multi_page_mode: bool = false
var atlas_page_layout = AtlasPageLayoutModel.new()
var selected_sprite: Dictionary = {}

# 拖拽相关
var dragging_sprite: Dictionary = {}
var drag_offset: Vector2 = Vector2.ZERO
var drag_handle: AtlasScaleGeometry.Handle = AtlasScaleGeometry.Handle.NONE
var drag_rejected: bool = false


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
	preview_scroll = $MarginContainer/VBoxContainer/MainHSplit/RightPanel/RightMargin/VBox/PreviewScroll
	preview_canvas = $MarginContainer/VBoxContainer/MainHSplit/RightPanel/RightMargin/VBox/PreviewScroll/PreviewCanvas
	_setup_preview_canvas_row()

	file_dialog = $FileDialog
	folder_dialog = $FolderDialog
	export_dialog = $ExportDialog
	_create_language_toggle()
	_create_export_settings_bar()
	atlas_name_dialog = _create_atlas_name_dialog()
	_create_preview_page_bar()
	_create_move_sprite_button()
	_create_preview_feedback_label()
	size_decision_dialog = _create_size_decision_dialog()

	# 等待父节点准备好
	await get_tree().process_frame

	# 确保对话框设置正确
	if file_dialog:
		file_dialog.visible = false
		file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		file_dialog.use_native_dialog = false
	if folder_dialog:
		folder_dialog.visible = false
		folder_dialog.access = FileDialog.ACCESS_FILESYSTEM
		folder_dialog.use_native_dialog = false
	if export_dialog:
		export_dialog.visible = false
		export_dialog.access = FileDialog.ACCESS_FILESYSTEM
		export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		export_dialog.use_native_dialog = false
	_create_source_hint_label()
	_apply_localization()

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
		_update_preview_canvas_size()
		preview_canvas.draw.connect(_on_preview_canvas_page_draw.bind(0))
		preview_canvas.gui_input.connect(_on_preview_canvas_page_input.bind(0))
		preview_canvas.mouse_exited.connect(_on_preview_canvas_mouse_exited)

	print("✓ 精灵图集制作工具已初始化")
	print("  - 已加载 UI 节点")
	print("  - 文件对话框已准备")


func _notification(what):
	if what == NOTIFICATION_RESIZED:
		# 窗口大小改变时自动调整
		_sync_preview_canvases()
		_update_preview_page_controls()
		_update_preview()


func _t(key: String, replacements: Variant = null) -> String:
	return AtlasLocalization.get_text(key, current_locale, replacements)


func _get_scaled_popup_size(ratio: Vector2, min_size: Vector2i, max_size: Vector2i) -> Vector2i:
	var available := get_viewport_rect().size
	var size := Vector2i(
		int(clampf(available.x * ratio.x, min_size.x, min(max_size.x, int(available.x * 0.92)))),
		int(clampf(available.y * ratio.y, min_size.y, min(max_size.y, int(available.y * 0.88))))
	)
	return size


func _popup_scaled_centered(window: Window, ratio: Vector2, min_size: Vector2i, max_size: Vector2i) -> void:
	if window == null:
		return

	var popup_size := _get_scaled_popup_size(ratio, min_size, max_size)
	window.popup_centered(popup_size)


func _toggle_language() -> void:
	current_locale = AtlasLocalization.toggle_locale(current_locale)
	_apply_localization()


func _create_language_toggle() -> void:
	var buttons_hbox = $MarginContainer/VBoxContainer/TopPanel/TopMargin/VBox/ButtonsHBox
	if buttons_hbox == null or buttons_hbox.has_node("LanguageToggleButton"):
		return

	language_toggle_button = Button.new()
	language_toggle_button.name = "LanguageToggleButton"
	language_toggle_button.flat = true
	language_toggle_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	language_toggle_button.pressed.connect(_toggle_language)
	buttons_hbox.add_child(language_toggle_button)


func _apply_localization() -> void:
	_apply_static_localization()
	_apply_dialog_localization()
	_apply_export_localization()
	_update_image_list()
	_update_preview_page_controls()


func _apply_static_localization() -> void:
	var title_label: Label = $MarginContainer/VBoxContainer/TopPanel/TopMargin/VBox/TitleLabel
	var atlas_size_label: Label = $MarginContainer/VBoxContainer/TopPanel/TopMargin/VBox/SettingsHBox/AtlasSizeLabel
	var padding_label: Label = $MarginContainer/VBoxContainer/TopPanel/TopMargin/VBox/SettingsHBox/PaddingLabel
	var image_list_label: Label = $MarginContainer/VBoxContainer/MainHSplit/LeftPanel/LeftMargin/VBox/Label
	var preview_label: Label = $MarginContainer/VBoxContainer/MainHSplit/RightPanel/RightMargin/VBox/Label

	title_label.text = _t("title")
	add_images_button.text = _t("button_add_images")
	add_folder_button.text = _t("button_add_folder")
	clear_button.text = _t("button_clear")
	auto_arrange_button.text = _t("button_auto_arrange")
	export_button_idle_text = _t("button_export")
	if export_button and not export_button.disabled:
		export_button.text = export_button_idle_text
	atlas_size_label.text = _t("label_atlas_size")
	padding_label.text = _t("label_padding")
	image_list_label.text = _t("label_image_list")
	preview_label.text = _t("label_preview")

	if language_toggle_button:
		language_toggle_button.text = _t("button_language")
		language_toggle_button.tooltip_text = _t("button_language_tooltip")

	if file_dialog:
		file_dialog.title = _t("file_dialog_images_title")
		file_dialog.ok_button_text = _t("file_dialog_images_ok")
		file_dialog.filters = PackedStringArray([_t("file_dialog_image_filter")])
	if folder_dialog:
		folder_dialog.title = _t("file_dialog_folder_title")
		folder_dialog.ok_button_text = _t("file_dialog_folder_ok")
	if export_dialog:
		export_dialog.title = _t("file_dialog_export_title")
		export_dialog.ok_button_text = _t("file_dialog_export_ok")
		export_dialog.filters = PackedStringArray([_t("file_dialog_export_filter")])


func _apply_dialog_localization() -> void:
	if atlas_name_dialog:
		atlas_name_dialog.title = _t("dialog_atlas_name_title")
		atlas_name_dialog.ok_button_text = _t("dialog_atlas_name_ok")
		atlas_name_dialog.cancel_button_text = _t("dialog_cancel")
		var atlas_name_label := atlas_name_dialog.find_child("AtlasNameLabel", true, false) as Label
		if atlas_name_label:
			atlas_name_label.text = _t("dialog_atlas_name_label")
	if atlas_name_line_edit:
		atlas_name_line_edit.placeholder_text = _t("dialog_atlas_name_placeholder")

	if size_decision_dialog:
		size_decision_dialog.title = _t("dialog_size_title")
		size_decision_dialog.ok_button_text = _t("dialog_size_ok")
		size_decision_dialog.cancel_button_text = _t("dialog_cancel")
		var custom_button := size_decision_dialog.find_child("IncreaseSizeButton", true, false) as Button
		if custom_button:
			custom_button.text = _t("dialog_size_custom")


func _apply_export_localization() -> void:
	if export_png_check_box:
		export_png_check_box.text = _t("label_export_png")
		export_png_check_box.tooltip_text = _t("tooltip_export_png")
	if export_tres_check_box:
		export_tres_check_box.text = _t("label_export_tres")
		export_tres_check_box.tooltip_text = _t("tooltip_export_tres")
	if export_res_check_box:
		export_res_check_box.text = _t("label_export_res")
		export_res_check_box.tooltip_text = _t("tooltip_export_res")
	if export_mapping_check_box:
		export_mapping_check_box.text = _t("label_export_mapping")
		export_mapping_check_box.tooltip_text = _t("tooltip_export_mapping")

	var export_hint := find_child("ExportNamingHint", true, false) as Label
	if export_hint:
		export_hint.text = _t("label_export_hint")

	var source_hint := find_child("SourceHintLabel", true, false) as Label
	if source_hint:
		source_hint.text = _t("label_source_hint")

	var preview_page_label := find_child("PreviewPageLabel", true, false) as Label
	if preview_page_label:
		preview_page_label.text = _t("preview_page")
	if snap_edges_check_box:
		snap_edges_check_box.text = _t("snap_edges")
		snap_edges_check_box.tooltip_text = _t("snap_edges_tooltip")


func _on_add_images_pressed():
	print("📁 点击了添加图片按钮")
	if file_dialog:
		_popup_scaled_centered(file_dialog, FILE_DIALOG_SIZE_RATIO, FILE_DIALOG_MIN_SIZE, FILE_DIALOG_MAX_SIZE)
		print("  - 文件对话框已弹出")
	else:
		push_error(_t("error_file_dialog_missing"))


func _on_add_folder_pressed():
	print("📂 点击了添加文件夹按钮")
	if folder_dialog:
		_popup_scaled_centered(folder_dialog, FILE_DIALOG_SIZE_RATIO, FILE_DIALOG_MIN_SIZE, FILE_DIALOG_MAX_SIZE)
		print("  - 文件夹对话框已弹出")
	else:
		push_error(_t("error_folder_dialog_missing"))


func _on_clear_pressed():
	loaded_images.clear()
	_clear_layout_state()
	pending_split_export_path = ""
	pending_export_atlas_name = ""
	_reset_preview_zoom()
	_update_image_list()
	_update_preview()


func _on_auto_arrange_pressed():
	if loaded_images.is_empty():
		push_warning(_t("warning_no_loaded_images"))
		return

	_auto_arrange_images()
	_update_preview()


func _on_export_pressed():
	if loaded_images.is_empty():
		push_warning(_t("warning_no_export_images"))
		return

	if not _has_selected_export_format():
		push_warning(_t("warning_no_export_format"))
		return

	_request_export_atlas_name()


func _request_export_atlas_name() -> void:
	if atlas_name_dialog == null or atlas_name_line_edit == null:
		pending_export_atlas_name = _default_atlas_name()
		_popup_export_dialog_for_atlas_name()
		return

	atlas_name_line_edit.text = _default_atlas_name()
	_popup_scaled_centered(atlas_name_dialog, ATLAS_NAME_DIALOG_SIZE_RATIO, ATLAS_NAME_DIALOG_MIN_SIZE, ATLAS_NAME_DIALOG_MAX_SIZE)
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
		push_warning(_t("warning_enter_atlas_name"))
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
		_popup_scaled_centered(export_dialog, FILE_DIALOG_SIZE_RATIO, FILE_DIALOG_MIN_SIZE, FILE_DIALOG_MAX_SIZE)


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
		export_button.text = _t("button_export_busy")
	else:
		export_button.text = export_button_idle_text if not export_button_idle_text.is_empty() else _t("button_export")


func _on_atlas_size_changed(index: int):
	var size = atlas_size_option.get_item_id(index)
	atlas_size = Vector2i(size, size)
	_clear_layout_state()
	_update_preview_canvas_size()
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
		push_warning(_t("warning_load_image_failed", [path]))


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
	image_count_label.text = _t("label_image_count", [loaded_images.size()])


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
	export_png_check_box.name = "ExportPngCheckBox"
	export_png_check_box.text = "PNG图集"
	export_png_check_box.button_pressed = true
	export_png_check_box.tooltip_text = "生成合并后的 PNG 图集。默认会保存到同名导出文件夹内，适合 Web 发布。"
	export_settings_hbox.add_child(export_png_check_box)

	export_tres_check_box = CheckBox.new()
	export_tres_check_box.name = "ExportTresCheckBox"
	export_tres_check_box.text = "Godot切图资源(.tres)"
	export_tres_check_box.button_pressed = true
	export_tres_check_box.tooltip_text = "为每个素材生成 AtlasTexture .tres，直接引用 PNG 图集中的对应区域，可在 Godot 里直接拖用。"
	export_settings_hbox.add_child(export_tres_check_box)

	export_res_check_box = CheckBox.new()
	export_res_check_box.name = "ExportResCheckBox"
	export_res_check_box.text = "Godot .res图集"
	export_res_check_box.button_pressed = false
	export_res_check_box.tooltip_text = "额外生成二进制 .res 图集纹理。会增加文件体积，通常只在确实需要纯 Godot 资源链路时启用。"
	export_settings_hbox.add_child(export_res_check_box)

	export_mapping_check_box = CheckBox.new()
	export_mapping_check_box.name = "ExportMappingCheckBox"
	export_mapping_check_box.text = "JSON区域映射"
	export_mapping_check_box.button_pressed = false
	export_mapping_check_box.tooltip_text = "额外生成 JSON，记录每个素材在图集中的 x/y/w/h 区域和多页信息，适合自定义运行时代码或外部工具读取。"
	export_settings_hbox.add_child(export_mapping_check_box)

	var naming_hint := Label.new()
	naming_hint.name = "ExportNamingHint"
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
	margin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	dialog.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var label := Label.new()
	label.name = "AtlasNameLabel"
	label.text = "该名称会用于导出文件夹、PNG 文件、.res 文件和 JSON 映射文件。"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(label)

	atlas_name_line_edit = LineEdit.new()
	atlas_name_line_edit.placeholder_text = "例如 male_default_idle"
	atlas_name_line_edit.custom_minimum_size = Vector2(320, 32)
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


func _setup_preview_canvas_row() -> void:
	if preview_scroll == null or preview_canvas == null:
		return
	if preview_canvas_row != null:
		return

	preview_canvas_row = HBoxContainer.new()
	preview_canvas_row.name = "PreviewCanvasRow"
	preview_canvas_row.add_theme_constant_override("separation", 12)
	preview_canvas_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_canvas_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_scroll.remove_child(preview_canvas)
	preview_scroll.add_child(preview_canvas_row)
	preview_canvas_row.add_child(preview_canvas)
	preview_canvases[0] = preview_canvas


func _should_show_preview_pages_side_by_side() -> bool:
	if atlas_pages.size() <= 1 or preview_scroll == null:
		return false

	var available_width := maxf(preview_scroll.size.x, preview_scroll.get_viewport_rect().size.x * 0.5)
	var required_width: float = (float(atlas_size.x) * preview_zoom * atlas_pages.size()) + (12.0 * max(0, atlas_pages.size() - 1))
	return required_width <= available_width


func _sync_preview_canvases() -> void:
	if preview_canvas_row == null or preview_canvas == null:
		return

	preview_multi_page_mode = _should_show_preview_pages_side_by_side()
	var required_count := atlas_pages.size() if preview_multi_page_mode else 1
	required_count = maxi(required_count, 1)

	for page_index: int in required_count:
		if preview_canvases.has(page_index):
			continue
		var canvas := Control.new()
		canvas.name = "PreviewCanvasPage%d" % (page_index + 1)
		canvas.mouse_filter = Control.MOUSE_FILTER_STOP
		canvas.draw.connect(_on_preview_canvas_page_draw.bind(page_index))
		canvas.gui_input.connect(_on_preview_canvas_page_input.bind(page_index))
		canvas.mouse_exited.connect(_on_preview_canvas_mouse_exited)
		preview_canvas_row.add_child(canvas)
		preview_canvases[page_index] = canvas

	for page_index: int in preview_canvases.keys():
		var canvas := preview_canvases[page_index] as Control
		canvas.visible = page_index < required_count
		canvas.custom_minimum_size = Vector2(atlas_size) * preview_zoom
		canvas.queue_redraw()

	preview_page_index = clampi(preview_page_index, 0, max(0, atlas_pages.size() - 1))


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
	preview_page_bar.visible = true
	preview_page_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_page_bar.add_theme_constant_override("separation", 8)

	snap_edges_check_box = CheckBox.new()
	snap_edges_check_box.name = "SnapEdgesCheckBox"
	snap_edges_check_box.button_pressed = snap_edges_enabled
	snap_edges_check_box.toggled.connect(_on_snap_edges_toggled)
	preview_page_bar.add_child(snap_edges_check_box)

	var page_label := Label.new()
	page_label.name = "PreviewPageLabel"
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


func _on_snap_edges_toggled(enabled: bool) -> void:
	snap_edges_enabled = enabled


func _create_move_sprite_button() -> void:
	if preview_canvas == null or move_sprite_button != null:
		return

	move_sprite_button = MenuButton.new()
	move_sprite_button.name = "MoveSpriteButton"
	move_sprite_button.custom_minimum_size = Vector2(76, 26)
	move_sprite_button.size = Vector2(76, 26)
	move_sprite_button.z_index = 10
	move_sprite_button.visible = false
	move_sprite_button.add_theme_font_size_override("font_size", 11)
	move_sprite_button.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0))
	move_sprite_button.add_theme_color_override("font_hover_color", Color.WHITE)
	move_sprite_button.add_theme_stylebox_override("normal", _make_move_button_style(Color(0.04, 0.1, 0.14, 0.78), Color(0.68, 0.92, 1.0, 1.0)))
	move_sprite_button.add_theme_stylebox_override("hover", _make_move_button_style(Color(0.08, 0.24, 0.32, 0.9), Color(0.9, 0.98, 1.0, 1.0)))
	move_sprite_button.add_theme_stylebox_override("pressed", _make_move_button_style(Color(0.03, 0.08, 0.12, 0.86), Color(0.56, 0.86, 1.0, 1.0)))
	move_sprite_button.get_popup().id_pressed.connect(_on_move_target_page_selected)
	preview_canvas.add_child(move_sprite_button)


func _make_move_button_style(background_color: Color, outline_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = outline_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


func _create_preview_feedback_label() -> void:
	if preview_canvas == null or preview_feedback_label != null:
		return

	preview_feedback_label = Label.new()
	preview_feedback_label.name = "PreviewFeedbackLabel"
	preview_feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_feedback_label.custom_minimum_size = Vector2(300, 40)
	preview_feedback_label.size = Vector2(300, 40)
	preview_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_feedback_label.add_theme_font_size_override("font_size", 12)
	preview_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.82, 1.0))
	preview_feedback_label.add_theme_stylebox_override("normal", _make_preview_feedback_style())
	preview_feedback_label.z_index = 20
	preview_feedback_label.visible = false
	preview_canvas.add_child(preview_feedback_label)

	preview_feedback_timer = Timer.new()
	preview_feedback_timer.one_shot = true
	preview_feedback_timer.wait_time = 4.0
	preview_feedback_timer.timeout.connect(_hide_preview_feedback)
	add_child(preview_feedback_timer)


func _make_preview_feedback_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.09, 0.03, 0.86)
	style.border_color = Color(1.0, 0.64, 0.2, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _show_preview_feedback(message: String) -> void:
	if preview_feedback_label == null:
		return

	var selected_page: int = selected_sprite.get("page_index", preview_page_index)
	var canvas_page_index := selected_page if preview_multi_page_mode else 0
	var target_canvas := preview_canvases.get(canvas_page_index) as Control
	if target_canvas == null:
		return
	if preview_feedback_label.get_parent() != target_canvas:
		preview_feedback_label.reparent(target_canvas)
	preview_feedback_label.position = Vector2(maxf(8.0, (target_canvas.size.x - preview_feedback_label.size.x) * 0.5), 10.0)
	preview_feedback_label.text = message
	preview_feedback_label.visible = true
	preview_feedback_timer.start()


func _hide_preview_feedback() -> void:
	if preview_feedback_label:
		preview_feedback_label.visible = false


func _create_size_decision_dialog() -> ConfirmationDialog:
	var dialog := ConfirmationDialog.new()
	dialog.name = "AtlasSizeDecisionDialog"
	dialog.title = "图集尺寸不足"
	dialog.ok_button_text = "拆分为多图"
	dialog.cancel_button_text = "取消"
	dialog.dialog_text = ""
	dialog.confirmed.connect(_on_use_multiple_pages_confirmed)
	dialog.custom_action.connect(_on_size_decision_custom_action)
	var custom_button := dialog.add_button("改用更大尺寸", false, "increase_size")
	if custom_button:
		custom_button.name = "IncreaseSizeButton"
	add_child(dialog)
	return dialog


func _clear_layout_state() -> void:
	unplaced_image_indices.clear()
	atlas_pages.clear()
	atlas_page_layout = AtlasPageLayoutModel.new()
	preview_page_index = 0
	dragging_sprite = {}
	drag_handle = AtlasScaleGeometry.Handle.NONE
	drag_rejected = false
	hovered_sprite = {}
	selected_sprite = {}
	_update_preview_page_controls()


func _update_preview():
	for canvas: Control in preview_canvases.values():
		canvas.queue_redraw()


func _update_preview_canvas_size() -> void:
	if preview_canvas == null:
		return

	_sync_preview_canvases()
	_update_move_sprite_menu()


func _reset_preview_zoom() -> void:
	preview_zoom = 1.0
	_update_preview_canvas_size()
	if preview_scroll:
		preview_scroll.scroll_horizontal = 0
		preview_scroll.scroll_vertical = 0


func _canvas_to_atlas(position: Vector2) -> Vector2:
	return PreviewTransform.canvas_to_atlas(position, preview_zoom)


func _atlas_rect_to_canvas(rect: Rect2) -> Rect2:
	return PreviewTransform.atlas_rect_to_canvas(rect, preview_zoom)


func _apply_preview_zoom(mouse_position: Vector2, requested_zoom: float) -> void:
	if preview_scroll == null:
		return

	var next_zoom := PreviewTransform.clamp_zoom(requested_zoom)
	if is_equal_approx(next_zoom, preview_zoom):
		return

	var scroll_offset := Vector2(preview_scroll.scroll_horizontal, preview_scroll.scroll_vertical)
	var next_scroll := PreviewTransform.zoom_scroll_offset(mouse_position, scroll_offset, preview_zoom, next_zoom)
	preview_zoom = next_zoom
	_update_preview_canvas_size()
	await get_tree().process_frame
	preview_scroll.scroll_horizontal = maxi(0, int(round(next_scroll.x)))
	preview_scroll.scroll_vertical = maxi(0, int(round(next_scroll.y)))
	_update_preview()


func _on_preview_canvas_draw():
	_draw_preview_page(preview_canvas, preview_page_index)


func _on_preview_canvas_page_draw(page_index: int) -> void:
	var canvas := preview_canvases.get(page_index) as Control
	var resolved_page_index := PreviewPageBinding.resolve_page_index(page_index, preview_page_index, preview_multi_page_mode)
	_draw_preview_page(canvas, resolved_page_index)


func _draw_preview_page(canvas: Control, page_index: int) -> void:
	if canvas == null:
		return

	_draw_grid(canvas)
	canvas.draw_rect(_atlas_rect_to_canvas(Rect2(Vector2.ZERO, atlas_size)), Color.WHITE, false, 2.0)

	for preview_item: Dictionary in _get_preview_items_for_page(page_index):
		var rect: Rect2 = _atlas_rect_to_canvas(preview_item["rect"])
		var texture: Texture2D = preview_item["texture"]
		canvas.draw_texture_rect(texture, rect, false)

		var is_hovered := (
			not hovered_sprite.is_empty()
			and int(hovered_sprite.get("image_index", -1)) == int(preview_item["index"])
			and int(hovered_sprite.get("page_index", -1)) == page_index
		)
		var is_selected := (
			not selected_sprite.is_empty()
			and int(selected_sprite.get("image_index", -1)) == int(preview_item["index"])
			and int(selected_sprite.get("page_index", -1)) == page_index
		)
		var border_color := Color(0.3, 1.0, 0.45, 1.0) if is_selected else (Color(1.0, 0.78, 0.18, 1.0) if is_hovered else Color(0, 1, 1, 0.5))
		var border_width := 3.0 if is_hovered or is_selected else 1.0
		if is_selected:
			canvas.draw_rect(rect, Color(0.3, 1.0, 0.45, 0.14), true)
		if is_hovered:
			canvas.draw_rect(rect, Color(1.0, 0.78, 0.18, 0.18), true)
		canvas.draw_rect(rect, border_color, false, border_width)
		if is_hovered:
			_draw_scale_handles(canvas, rect)

		var font = canvas.get_theme_default_font()
		var font_size = maxi(10, int(round(12.0 * preview_zoom)))
		canvas.draw_string(font, rect.position + Vector2(2, 15), preview_item["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _draw_scale_handles(canvas: Control, rect: Rect2) -> void:
	var radius := maxf(3.0, 5.0 * preview_zoom)
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]:
		canvas.draw_circle(corner, radius, Color(1.0, 0.78, 0.18, 1.0))


func _draw_grid(canvas: Control):
	var grid_size = 64
	var grid_color = Color(0.3, 0.3, 0.3, 0.3)

	# 垂直线
	for x in range(0, atlas_size.x, grid_size):
		var canvas_x := PreviewTransform.atlas_to_canvas(Vector2(x, 0), preview_zoom).x
		var canvas_height := float(atlas_size.y) * preview_zoom
		canvas.draw_line(Vector2(canvas_x, 0), Vector2(canvas_x, canvas_height), grid_color, 1.0)

	# 水平线
	for y in range(0, atlas_size.y, grid_size):
		var canvas_y := PreviewTransform.atlas_to_canvas(Vector2(0, y), preview_zoom).y
		var canvas_width := float(atlas_size.x) * preview_zoom
		canvas.draw_line(Vector2(0, canvas_y), Vector2(canvas_width, canvas_y), grid_color, 1.0)


func _on_preview_canvas_input(event: InputEvent):
	_handle_preview_canvas_input(event, preview_page_index)


func _on_preview_canvas_page_input(event: InputEvent, page_index: int) -> void:
	var resolved_page_index := PreviewPageBinding.resolve_page_index(page_index, preview_page_index, preview_multi_page_mode)
	_handle_preview_canvas_input(event, resolved_page_index)


func _handle_preview_canvas_input(event: InputEvent, page_index: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_apply_preview_zoom(event.position, preview_zoom * PreviewTransform.ZOOM_STEP)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_apply_preview_zoom(event.position, preview_zoom / PreviewTransform.ZOOM_STEP)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				preview_page_index = clampi(page_index, 0, max(0, atlas_pages.size() - 1))
				_apply_page_rects_to_loaded_images(preview_page_index)
				var mouse_pos := _canvas_to_atlas(event.position)
				for preview_item: Dictionary in _get_preview_items_for_page(preview_page_index):
					var rect: Rect2 = preview_item["rect"]
					if rect.has_point(mouse_pos):
						selected_sprite = {
							"image_index": preview_item["index"],
							"page_index": preview_page_index,
						}
						drag_handle = AtlasScaleGeometry.hit_handle(rect, mouse_pos, 7.0 / preview_zoom)
						dragging_sprite = {
							"image_index": preview_item["index"],
							"page_index": preview_page_index,
						}
						drag_offset = mouse_pos - rect.position
						drag_rejected = false
						_update_preview_page_controls()
						_update_preview()
						break
			else:
				if drag_rejected:
					push_warning(_t("warning_page_move_no_space"))
				dragging_sprite = {}
				drag_handle = AtlasScaleGeometry.Handle.NONE
				drag_rejected = false

	elif event is InputEventMouseMotion:
		_update_hovered_sprite(event.position, page_index)
		if not dragging_sprite.is_empty():
			var image_index: int = dragging_sprite.get("image_index", -1)
			if image_index < 0 or image_index >= loaded_images.size():
				return

			if atlas_pages.is_empty():
				_update_single_page_drag(image_index, event.position)
			else:
				var source_page_index: int = dragging_sprite.get("page_index", -1)
				if page_index == source_page_index:
					_update_paged_drag(image_index, source_page_index, event.position)
			_update_preview()


func _update_single_page_drag(image_index: int, canvas_position: Vector2) -> void:
	var current_rect := _get_preview_rect_for_image(image_index)
	var new_pos: Vector2 = _canvas_to_atlas(canvas_position) - drag_offset
	var clamped_pos: Vector2 = new_pos.clamp(Vector2.ZERO, Vector2(atlas_size) - current_rect.size)
	if snap_edges_enabled:
		clamped_pos = _snap_preview_position(image_index, clamped_pos, current_rect.size)
	_set_preview_rect_for_image(image_index, Rect2(clamped_pos, current_rect.size))


func _update_paged_drag(image_index: int, target_page_index: int, canvas_position: Vector2) -> void:
	_configure_page_layout()
	var pointer := _canvas_to_atlas(canvas_position)
	var result: Dictionary
	if drag_handle != AtlasScaleGeometry.Handle.NONE:
		var source_size := _source_size_for_image(image_index)
		var current_rect := atlas_page_layout.get_item_rect(image_index)
		var resized_rect := AtlasScaleGeometry.resize_from_handle(
			current_rect,
			source_size,
			drag_handle,
			pointer,
			atlas_size
		)
		result = atlas_page_layout.resize_item(image_index, resized_rect)
	else:
		var current_rect := atlas_page_layout.get_item_rect(image_index)
		var position := pointer - drag_offset
		var target_rect := Rect2i(
			Vector2i(roundi(position.x), roundi(position.y)).clamp(Vector2i.ZERO, atlas_size - current_rect.size),
			current_rect.size
		)
		result = atlas_page_layout.move_item(image_index, target_page_index, target_rect)

	if result.get("ok", false):
		drag_rejected = false
		_sync_pages_from_layout()
	else:
		drag_rejected = true



func _source_size_for_image(image_index: int) -> Vector2i:
	if image_index < 0 or image_index >= loaded_images.size():
		return Vector2i.ONE
	var texture: Texture2D = loaded_images[image_index].texture
	return Vector2i(texture.get_width(), texture.get_height())


func _configure_page_layout() -> void:
	var source_sizes: Array[Vector2i] = []
	for image_index: int in loaded_images.size():
		source_sizes.append(_source_size_for_image(image_index))
	atlas_page_layout.configure(atlas_size, padding, source_sizes, atlas_pages)


func _sync_pages_from_layout() -> void:
	atlas_pages = atlas_page_layout.to_pages()
	_apply_page_rects_to_loaded_images(preview_page_index)
	_update_preview_page_controls()


func _on_preview_canvas_mouse_exited() -> void:
	if hovered_sprite.is_empty():
		return
	hovered_sprite = {}
	_update_preview()


func _update_hovered_sprite(canvas_position: Vector2, page_index: int) -> void:
	var atlas_position := _canvas_to_atlas(canvas_position)
	var next_hover := _find_topmost_preview_item_at(atlas_position, page_index)
	if next_hover == hovered_sprite:
		return
	hovered_sprite = next_hover
	_update_preview()


func _find_topmost_preview_item_at(atlas_position: Vector2, page_index: int) -> Dictionary:
	var items := _get_preview_items_for_page(page_index)
	for i: int in range(items.size() - 1, -1, -1):
		var item: Dictionary = items[i]
		var rect: Rect2 = item["rect"]
		if rect.has_point(atlas_position):
			return {
				"image_index": item["index"],
				"page_index": page_index,
			}
	return {}


func _snap_preview_position(image_index: int, position: Vector2, rect_size: Vector2) -> Vector2:
	var other_rects: Array = []
	for item: Dictionary in _get_preview_items_for_page(preview_page_index):
		if int(item["index"]) != image_index:
			other_rects.append(item["rect"])
	return PreviewSnap.snap_position(position, rect_size, Vector2(atlas_size), other_rects)


func _auto_arrange_images():
	if not atlas_pages.is_empty():
		_configure_page_layout()
		var arranged_pages_result: Dictionary = atlas_page_layout.arrange_pages()
		if not arranged_pages_result.get("ok", false):
			push_warning(_t("warning_page_arrange_failed", [arranged_pages_result.get("page_index", 0) + 1]))
			return
		_sync_pages_from_layout()
		print("✓ 已按当前页分别自动排列 %d 个图集页" % atlas_pages.size())
		return

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
		push_warning(_t("warning_unplaced_images", [unplaced_indices.size(), str(unplaced_indices)]))
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
		push_error(_t("error_export_failed", [result.get("message", "Unknown error")]))
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
	var size_text := "%d x %d" % [next_size, next_size] if next_size > 0 else _t("dialog_size_unavailable")

	size_decision_dialog.dialog_text = _t(
		"dialog_size_text",
		[atlas_size.x, atlas_size.y, unplaced_image_indices.size(), page_count, size_text]
	)
	_popup_scaled_centered(size_decision_dialog, Vector2(0.42, 0.28), Vector2i(480, 220), Vector2i(720, 340))


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
		push_error(_t("error_page_item_too_large", [str(unplaced_indices)]))
		return false

	if pages.is_empty():
		push_error(_t("error_page_layout_failed"))
		return false

	atlas_pages.clear()
	for page: Dictionary in pages:
		atlas_pages.append(page.duplicate(true))

	_configure_page_layout()
	preview_page_index = 0
	_apply_page_rects_to_loaded_images(preview_page_index)
	_update_preview_page_controls()
	_update_preview()
	print("✓ 已按当前尺寸拆分为 %d 个图集页" % atlas_pages.size())
	return true


func _apply_next_fitting_atlas_size() -> bool:
	var next_size := _find_next_fitting_atlas_size()
	if next_size <= 0:
		push_error(_t("error_no_larger_size"))
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
		_update_preview_canvas_size()


func _export_preview_pages(output_path: String) -> void:
	var export_items := _build_export_items(false)
	var result: Dictionary = AtlasExporter.export_atlas_pages(export_items, atlas_pages, atlas_size, output_path, _build_export_options())
	if result.get("error", FAILED) != OK:
		push_error(_t("error_split_export_failed", [result.get("message", "Unknown error")]))
		return

	_print_multi_export_success(result)


func _update_preview_page_controls() -> void:
	if preview_page_bar == null or preview_page_option == null or preview_page_summary_label == null:
		return

	_sync_preview_canvases()
	preview_page_bar.visible = true
	var show_page_picker := atlas_pages.size() > 1 and not preview_multi_page_mode
	var preview_page_label := find_child("PreviewPageLabel", true, false) as Label
	if preview_page_label:
		preview_page_label.visible = show_page_picker
	preview_page_option.visible = show_page_picker
	preview_page_summary_label.visible = show_page_picker
	preview_page_option.clear()
	for page_index: int in atlas_pages.size():
		var page: Dictionary = atlas_pages[page_index]
		var item_indices: Array = page.get("item_indices", [])
		preview_page_option.add_item(_t("preview_page_item", [page_index + 1, item_indices.size()]), page_index)

	if not atlas_pages.is_empty():
		preview_page_index = clampi(preview_page_index, 0, atlas_pages.size() - 1)
		preview_page_option.select(preview_page_index)
		preview_page_summary_label.text = _t("preview_page_summary", [atlas_pages.size(), atlas_size.x, atlas_size.y])
	else:
		preview_page_index = 0
		preview_page_summary_label.text = ""

	_update_move_sprite_menu()


func _update_move_sprite_menu() -> void:
	if move_sprite_button == null:
		return

	move_sprite_button.text = _t("button_move")
	move_sprite_button.disabled = selected_sprite.is_empty() or atlas_pages.size() <= 1
	var popup: PopupMenu = move_sprite_button.get_popup()
	popup.clear()
	if selected_sprite.is_empty():
		move_sprite_button.visible = false
		return

	var selected_page: int = selected_sprite.get("page_index", -1)
	var image_index: int = selected_sprite.get("image_index", -1)
	move_sprite_button.visible = atlas_pages.size() > 1 and (preview_multi_page_mode or selected_page == preview_page_index)
	if not move_sprite_button.visible:
		return
	var canvas_page_index := selected_page if preview_multi_page_mode else 0
	var target_canvas := preview_canvases.get(canvas_page_index) as Control
	if target_canvas == null or image_index < 0 or image_index >= loaded_images.size():
		move_sprite_button.visible = false
		return
	if move_sprite_button.get_parent() != target_canvas:
		move_sprite_button.reparent(target_canvas)
	var selected_rect := _atlas_rect_to_canvas(_get_preview_rect_for_image(image_index))
	move_sprite_button.position = Vector2(
		maxf(selected_rect.position.x + 3.0, selected_rect.end.x - move_sprite_button.size.x - 3.0),
		maxf(selected_rect.position.y + 3.0, selected_rect.end.y - move_sprite_button.size.y - 3.0)
	)
	for page_index: int in atlas_pages.size():
		if page_index == selected_page:
			continue
		popup.add_item(_t("move_to_page", [page_index + 1]), page_index)


func _on_move_target_page_selected(target_page_index: int) -> void:
	if selected_sprite.is_empty():
		return
	var image_index: int = selected_sprite.get("image_index", -1)
	if image_index < 0 or image_index >= loaded_images.size():
		return

	_configure_page_layout()
	var result := atlas_page_layout.move_item_to_first_fit(image_index, target_page_index)
	if not result.get("ok", false):
		var warning_text := _t("warning_page_move_no_space")
		push_warning(warning_text)
		_show_preview_feedback(warning_text)
		return

	var resolved_target_page := atlas_page_layout.get_item_page(image_index)
	if resolved_target_page < 0:
		push_error("Atlas move succeeded without a resolved target page.")
		return
	preview_page_index = resolved_target_page
	selected_sprite["page_index"] = resolved_target_page
	_sync_pages_from_layout()
	_apply_page_rects_to_loaded_images(preview_page_index)
	_update_preview()


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
	return _get_preview_items_for_page(preview_page_index)


func _get_preview_items_for_page(page_index: int) -> Array[Dictionary]:
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

	if page_index < 0 or page_index >= atlas_pages.size():
		return items

	var page: Dictionary = atlas_pages[page_index]
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
