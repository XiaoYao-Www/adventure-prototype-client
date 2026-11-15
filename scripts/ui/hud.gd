class_name Hud
extends Control
## 探索 HUD：狀態列（地圖/座標/旗標/物品）、互動提示、短暫通知。
## 以程式建立子節點；不直接修改遊戲狀態。

var _status_label: Label
var _prompt_label: Label
var _notice_label: Label
var _notice_timer: float = 0.0


func _ready() -> void:
	_build()


func _process(delta: float) -> void:
	if _notice_timer <= 0.0:
		return
	_notice_timer -= delta
	if _notice_timer <= 0.0:
		_notice_label.text = ""
		_notice_label.visible = false


func _build() -> void:
	name = "HUD"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_status_label = _new_label("StatusLabel", 14)
	_status_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_status_label.offset_left = 8.0
	_status_label.offset_top = 8.0
	_status_label.offset_right = 700.0
	_status_label.offset_bottom = 28.0
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status_label)

	_prompt_label = _new_label("PromptLabel", 18)
	_prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.offset_left = -260.0
	_prompt_label.offset_right = 260.0
	_prompt_label.offset_top = -56.0
	_prompt_label.offset_bottom = -28.0
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt_label)

	_notice_label = _new_label("NoticeLabel", 15)
	_notice_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.offset_left = -300.0
	_notice_label.offset_right = 300.0
	_notice_label.offset_top = -88.0
	_notice_label.offset_bottom = -64.0
	_notice_label.modulate = Color(1.0, 0.95, 0.6)
	_notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notice_label)
	_notice_label.visible = false


func _new_label(label_name: String, font_size: int) -> Label:
	var label := Label.new()
	label.name = label_name
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func set_status(text: String) -> void:
	_status_label.text = text


func set_prompt(text: String) -> void:
	_prompt_label.text = text


func show_notice(text: String, seconds: float = 3.0) -> void:
	_notice_label.text = text
	_notice_label.visible = true
	_notice_timer = seconds


## 測試/除錯用：目前狀態列文字。
func status_text() -> String:
	return _status_label.text if _status_label != null else ""
