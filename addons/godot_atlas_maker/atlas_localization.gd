@tool
class_name AtlasLocalization
extends RefCounted

const LOCALE_ZH := "zh"
const LOCALE_EN := "en"
const DEFAULT_LOCALE := LOCALE_ZH

const STRINGS := {
	LOCALE_ZH: {
		"title": "精灵图集制作工具",
		"button_add_images": "📁 添加图片",
		"button_add_folder": "📂 添加文件夹",
		"button_clear": "🗑️ 清空",
		"button_auto_arrange": "✨ 自动排列",
		"button_export": "💾 导出图集",
		"button_export_busy": "导出中...",
		"button_language": "中 / EN",
		"button_language_tooltip": "当前：中文，点击切换到 English",
		"label_atlas_size": "图集尺寸:",
		"label_padding": "边距:",
		"label_image_count": "已加载: %d 张图片",
		"label_image_list": "图片列表",
		"label_preview": "预览区域（可拖动图片调整位置，滚轮缩放）",
		"label_source_hint": "图片来源：支持项目内 res:// 和项目外文件；项目外图片会读取到内存，导出资源仍保存到所选输出路径。",
		"label_export_png": "PNG图集",
		"tooltip_export_png": "生成合并后的 PNG 图集。默认会保存到同名导出文件夹内，适合 Web 发布。",
		"label_export_tres": "Godot切图资源(.tres)",
		"tooltip_export_tres": "为每个素材生成 AtlasTexture .tres，直接引用 PNG 图集中的对应区域，可在 Godot 里直接拖用。",
		"label_export_res": "Godot .res图集",
		"tooltip_export_res": "额外生成二进制 .res 图集纹理。会增加文件体积，通常只在确实需要纯 Godot 资源链路时启用。",
		"label_export_mapping": "JSON区域映射",
		"tooltip_export_mapping": "额外生成 JSON，记录每个素材在图集中的 x/y/w/h 区域和多页信息，适合自定义运行时代码或外部工具读取。",
		"label_export_hint": "导出时分别设置图集名称与目标资源文件夹；生成文件统一保存到该文件夹内。",
		"dialog_atlas_name_title": "输入图集名称",
		"dialog_atlas_name_ok": "下一步",
		"dialog_cancel": "取消",
		"dialog_atlas_name_label": "图集名称：PNG、.res 与 JSON 文件名。",
		"dialog_atlas_name_placeholder": "例如 male_default_idle",
		"dialog_atlas_folder_label": "目标资源文件夹：保存所有导出文件。",
		"dialog_atlas_folder_placeholder": "例如 resources",
		"dialog_size_title": "图集尺寸不足",
		"dialog_size_ok": "拆分为多图",
		"dialog_size_custom": "改用更大尺寸",
		"dialog_size_text": "当前 %d x %d 图集无法容纳全部图片，仍有 %d 张未放入。\n\n可以按当前尺寸拆分为 %d 个图集页，或改用更大尺寸：%s。",
		"dialog_size_unavailable": "没有可用的更大预设尺寸",
		"preview_page": "图集页:",
		"snap_edges": "对齐",
		"snap_edges_tooltip": "开启后，拖动切图时会自动吸附到图集边缘和其他切图边缘。",
		"button_move": "移动到",
		"move_to_page": "移动到第 %d 页",
		"preview_page_item": "第 %d 页 (%d 张)",
		"preview_page_summary": "共 %d 页，当前尺寸 %d x %d",
		"file_dialog_images_title": "选择图片",
		"file_dialog_images_ok": "打开",
		"file_dialog_folder_title": "选择文件夹",
		"file_dialog_folder_ok": "选择",
		"file_dialog_export_title": "导出图集",
		"file_dialog_export_ok": "导出",
		"file_dialog_image_filter": "*.png, *.jpg, *.jpeg, *.webp ; 图片文件",
		"file_dialog_export_filter": "*.png ; PNG 图片",
		"warning_no_loaded_images": "没有加载的图片",
		"warning_no_export_images": "没有可导出的图片",
		"warning_no_export_format": "请至少勾选一种导出格式：PNG图集、Godot切图资源、Godot .res图集或JSON区域映射。",
		"warning_enter_atlas_name": "请输入图集名称",
		"warning_enter_atlas_folder": "请输入目标资源文件夹名称",
		"warning_load_image_failed": "无法加载图片：%s",
		"warning_unplaced_images": "图集尺寸不够，%d 张图片未能放入：%s。",
		"warning_page_move_no_space": "目标图集页没有足够空间，素材位置未改变。",
		"warning_page_arrange_failed": "第 %d 页当前尺寸无法完成自动排列，已保留原布局。",
		"error_file_dialog_missing": "文件对话框未找到！",
		"error_folder_dialog_missing": "文件夹对话框未找到！",
		"error_export_failed": "❌ 导出失败: %s",
		"error_split_export_failed": "❌ 拆分导出失败: %s",
		"error_page_item_too_large": "当前图集尺寸下仍有图片单张过大，无法拆分放入。请改用更大尺寸。未放入索引：%s",
		"error_page_layout_failed": "无法生成多图集布局。",
		"error_no_larger_size": "没有找到能容纳全部图片的更大预设尺寸，请减少图片或手动拆分素材。",
	},
	LOCALE_EN: {
		"title": "Sprite Atlas Maker",
		"button_add_images": "📁 Add Images",
		"button_add_folder": "📂 Add Folder",
		"button_clear": "🗑️ Clear",
		"button_auto_arrange": "✨ Auto Arrange",
		"button_export": "💾 Export Atlas",
		"button_export_busy": "Exporting...",
		"button_language": "中 / EN",
		"button_language_tooltip": "Current: English, click to switch to 中文",
		"label_atlas_size": "Atlas Size:",
		"label_padding": "Padding:",
		"label_image_count": "Loaded: %d images",
		"label_image_list": "Image List",
		"label_preview": "Preview Area (drag to move sprites, wheel to zoom)",
		"label_source_hint": "Image sources support both project res:// files and external files. External images are loaded into memory, while exported resources still go to the chosen output path.",
		"label_export_png": "PNG Atlas",
		"tooltip_export_png": "Generate the merged PNG atlas. It is saved into a same-named export folder by default and works well for web builds.",
		"label_export_tres": "Godot AtlasTexture (.tres)",
		"tooltip_export_tres": "Create one AtlasTexture .tres per sprite, each pointing to its region inside the PNG atlas, ready to use directly in Godot.",
		"label_export_res": "Godot .res Atlas",
		"tooltip_export_res": "Also generate a binary .res atlas texture. This increases file size and is usually only needed for a pure Godot resource pipeline.",
		"label_export_mapping": "JSON Region Map",
		"tooltip_export_mapping": "Also generate JSON with x/y/w/h regions and multi-page data for each sprite, useful for custom runtime code or external tools.",
		"label_export_hint": "Set the atlas name and target resource folder separately. Generated files are saved inside the target folder.",
		"dialog_atlas_name_title": "Enter Atlas Name",
		"dialog_atlas_name_ok": "Next",
		"dialog_cancel": "Cancel",
		"dialog_atlas_name_label": "Atlas name: PNG, .res, and JSON file names.",
		"dialog_atlas_name_placeholder": "For example: male_default_idle",
		"dialog_atlas_folder_label": "Target resource folder: stores all exported files.",
		"dialog_atlas_folder_placeholder": "For example: resources",
		"dialog_size_title": "Atlas Size Too Small",
		"dialog_size_ok": "Split Into Multiple Atlases",
		"dialog_size_custom": "Use Larger Size",
		"dialog_size_text": "The current %d x %d atlas cannot fit all images, and %d images are still unplaced.\n\nYou can split them into %d atlas pages at the current size, or switch to a larger preset size: %s.",
		"dialog_size_unavailable": "No larger preset size available",
		"preview_page": "Atlas Page:",
		"snap_edges": "Snap",
		"snap_edges_tooltip": "When enabled, dragged sprites snap to atlas edges and neighboring sprite edges.",
		"button_move": "Move to",
		"move_to_page": "Move to Page %d",
		"preview_page_item": "Page %d (%d items)",
		"preview_page_summary": "%d pages total, current size %d x %d",
		"file_dialog_images_title": "Select Images",
		"file_dialog_images_ok": "Open",
		"file_dialog_folder_title": "Select Folder",
		"file_dialog_folder_ok": "Select",
		"file_dialog_export_title": "Export Atlas",
		"file_dialog_export_ok": "Export",
		"file_dialog_image_filter": "*.png, *.jpg, *.jpeg, *.webp ; Image Files",
		"file_dialog_export_filter": "*.png ; PNG Image",
		"warning_no_loaded_images": "No images loaded.",
		"warning_no_export_images": "No images available for export.",
		"warning_no_export_format": "Select at least one export format: PNG atlas, Godot AtlasTexture resources, Godot .res atlas, or JSON region mapping.",
		"warning_enter_atlas_name": "Please enter an atlas name.",
		"warning_enter_atlas_folder": "Please enter a target resource folder name.",
		"warning_load_image_failed": "Failed to load image: %s",
		"warning_unplaced_images": "Atlas size is not enough. %d images could not be placed: %s.",
		"warning_page_move_no_space": "The target atlas page has no space for this sprite; its position was unchanged.",
		"warning_page_arrange_failed": "Page %d cannot be auto-arranged at its current size; its existing layout was kept.",
		"error_file_dialog_missing": "Image file dialog not found!",
		"error_folder_dialog_missing": "Folder dialog not found!",
		"error_export_failed": "❌ Export failed: %s",
		"error_split_export_failed": "❌ Split export failed: %s",
		"error_page_item_too_large": "Some individual images are still too large for the current atlas size and cannot be split across pages. Please use a larger size. Unplaced indices: %s",
		"error_page_layout_failed": "Failed to generate a multi-atlas layout.",
		"error_no_larger_size": "No larger preset size can fit all images. Reduce the image set or split the source assets manually.",
	},
}


static func normalize_locale(locale: String) -> String:
	if locale.begins_with(LOCALE_EN):
		return LOCALE_EN
	return LOCALE_ZH


static func toggle_locale(locale: String) -> String:
	if normalize_locale(locale) == LOCALE_ZH:
		return LOCALE_EN
	return LOCALE_ZH


static func get_text(key: String, locale: String = DEFAULT_LOCALE, replacements: Variant = null) -> String:
	var normalized_locale := normalize_locale(locale)
	var locale_strings: Dictionary = STRINGS.get(normalized_locale, {})
	var fallback_strings: Dictionary = STRINGS.get(DEFAULT_LOCALE, {})
	var text := str(locale_strings.get(key, fallback_strings.get(key, key)))
	if replacements == null:
		return text
	return text % replacements
