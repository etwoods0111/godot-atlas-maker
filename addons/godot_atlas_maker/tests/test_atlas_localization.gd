extends SceneTree

const AtlasLocalization = preload("res://addons/godot_atlas_maker/atlas_localization.gd")


func _init() -> void:
	var failures: Array[String] = []
	_test_normalizes_locales(failures)
	_test_toggles_between_chinese_and_english(failures)
	_test_returns_translated_text_and_formatted_values(failures)
	_test_falls_back_to_default_locale_and_key(failures)

	if failures.is_empty():
		print("AtlasLocalization tests passed")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _test_normalizes_locales(failures: Array[String]) -> void:
	_expect_equal(AtlasLocalization.normalize_locale("en_US"), AtlasLocalization.LOCALE_EN, "should normalize English locales", failures)
	_expect_equal(AtlasLocalization.normalize_locale("zh_CN"), AtlasLocalization.LOCALE_ZH, "should normalize Chinese locales", failures)
	_expect_equal(AtlasLocalization.normalize_locale("fr"), AtlasLocalization.LOCALE_ZH, "unsupported locales should fall back to Chinese", failures)


func _test_toggles_between_chinese_and_english(failures: Array[String]) -> void:
	_expect_equal(AtlasLocalization.toggle_locale(AtlasLocalization.LOCALE_ZH), AtlasLocalization.LOCALE_EN, "toggle should switch zh to en", failures)
	_expect_equal(AtlasLocalization.toggle_locale(AtlasLocalization.LOCALE_EN), AtlasLocalization.LOCALE_ZH, "toggle should switch en to zh", failures)


func _test_returns_translated_text_and_formatted_values(failures: Array[String]) -> void:
	_expect_equal(AtlasLocalization.get_text("title", AtlasLocalization.LOCALE_ZH), "精灵图集制作工具", "should return Chinese title", failures)
	_expect_equal(AtlasLocalization.get_text("title", AtlasLocalization.LOCALE_EN), "Sprite Atlas Maker", "should return English title", failures)
	_expect_equal(AtlasLocalization.get_text("label_image_count", AtlasLocalization.LOCALE_EN, [3]), "Loaded: 3 images", "should format English replacements", failures)
	_expect_equal(AtlasLocalization.get_text("label_image_count", AtlasLocalization.LOCALE_ZH, [5]), "已加载: 5 张图片", "should format Chinese replacements", failures)


func _test_falls_back_to_default_locale_and_key(failures: Array[String]) -> void:
	_expect_equal(AtlasLocalization.get_text("button_export", "fr"), "💾 导出图集", "unsupported locale should fall back to default locale", failures)
	_expect_equal(AtlasLocalization.get_text("unknown_key", AtlasLocalization.LOCALE_EN), "unknown_key", "unknown keys should fall back to the key itself", failures)


func _expect_equal(actual: Variant, expected: Variant, message: String, failures: Array[String]) -> void:
	if actual != expected:
		failures.append("%s. Expected %s, got %s" % [message, expected, actual])
