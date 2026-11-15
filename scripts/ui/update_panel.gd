class_name UpdatePanel
extends Control
## 更新狀態提示（右上角小面板）：顯示「檢查更新／下載中／安裝」。
## 不擋主要操作；沒有訊息時隱藏。Android 上自動安裝失敗時提供重試按鈕。

signal install_requested(path: String)

var _panel: PanelContainer
var _label: Label
var _button: Button
var _install_path: String = ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	hide_panel()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.name = "UpdatePanelBox"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_left = -420.0
	_panel.offset_right = -12.0
	_panel.offset_top = 12.0
	_panel.offset_bottom = 64.0
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_label)

	_button = Button.new()
	_button.text = "安裝更新"
	_button.add_theme_font_size_override("font_size", 14)
	_button.visible = false
	_button.pressed.connect(_on_install_pressed)
	row.add_child(_button)


func show_status(text: String) -> void:
	_label.text = text
	_button.visible = false
	_install_path = ""
	visible = not text.is_empty()


## 已下載、等待使用者按「安裝更新」（例如自動安裝被系統擋下）。
func show_install_button(path: String, text: String = "更新已下載，點此安裝") -> void:
	_label.text = text
	_install_path = path
	_button.visible = true
	visible = true


func hide_panel() -> void:
	visible = false
	_label.text = ""
	_button.visible = false
	_install_path = ""


func has_install_action() -> bool:
	return _button != null and _button.visible


func _on_install_pressed() -> void:
	if not _install_path.is_empty():
		install_requested.emit(_install_path)
