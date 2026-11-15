class_name ErrorPanel
extends PanelContainer
## 錯誤面板：顯示內容載入/存讀檔的可讀錯誤與警告，不讓遊戲崩潰。
## Esc 可關閉（由 main.gd 轉發 hide_panel()）。

var _title_label: Label
var _body_label: RichTextLabel
var _showing: bool = false


func _ready() -> void:
	_build()
	visible = false


func _build() -> void:
	name = "ErrorPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -340.0
	offset_right = 340.0
	offset_top = -200.0
	offset_bottom = 200.0
	z_index = 100

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	_title_label = Label.new()
	_title_label.name = "ErrorTitle"
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	column.add_child(_title_label)

	_body_label = RichTextLabel.new()
	_body_label.name = "ErrorBody"
	_body_label.bbcode_enabled = false
	_body_label.fit_content = true
	_body_label.scroll_active = true
	_body_label.add_theme_font_size_override("normal_font_size", 14)
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_body_label)


## 顯示錯誤（errors 必填，warnings 可空）。
func show_errors(errors: Array, warnings: Array = [], title: String = "發生錯誤") -> void:
	_title_label.text = title
	var lines: PackedStringArray = PackedStringArray()
	for error_text: Variant in errors:
		lines.append("• " + String(error_text))
	if not warnings.is_empty():
		lines.append("")
		lines.append("警告：")
		for warning_text: Variant in warnings:
			lines.append("• " + String(warning_text))
	_body_label.text = "\n".join(lines)
	visible = true
	_showing = true


func is_showing() -> bool:
	return _showing


func hide_panel() -> void:
	visible = false
	_showing = false


func body_text() -> String:
	return _body_label.text
