class_name TitleScreen
extends Control
## 主頁面（標題畫面）：開始遊戲／繼續遊戲／檢查更新／版本資訊。
##
## 以程式建立 UI，不依賴 .tscn。開場顯示；按下「開始」或「繼續」後才進入世界。
## 只發訊號，不直接改遊戲狀態。

signal start_game
signal continue_game
signal check_updates

var _continue_button: Button
var _version_label: Label
var _status_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.045, 0.07, 0.94)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.custom_minimum_size = Vector2(360, 0)
	center.add_child(column)

	var title := Label.new()
	title.text = "Adventure Prototype"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.94, 0.78))
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "冒險原型（世界觀與名稱暫定）"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.modulate = Color(1, 1, 1, 0.75)
	column.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	column.add_child(spacer)

	var start_button := _menu_button("開始遊戲")
	start_button.pressed.connect(func() -> void: start_game.emit())
	column.add_child(start_button)

	_continue_button = _menu_button("繼續遊戲")
	_continue_button.pressed.connect(func() -> void: continue_game.emit())
	column.add_child(_continue_button)

	var update_button := _menu_button("檢查更新")
	update_button.pressed.connect(func() -> void: check_updates.emit())
	column.add_child(update_button)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.modulate = Color(1, 1, 1, 0.8)
	_status_label.text = ""
	column.add_child(_status_label)

	var hint := Label.new()
	hint.text = "橫向遊玩｜方向鍵移動｜互動鍵對話／調查｜存檔／讀檔"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(1, 1, 1, 0.55)
	column.add_child(hint)

	var version_spacer := Control.new()
	version_spacer.custom_minimum_size = Vector2(0, 6)
	column.add_child(version_spacer)

	_version_label = Label.new()
	_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_version_label.add_theme_font_size_override("font_size", 12)
	_version_label.modulate = Color(1, 1, 1, 0.5)
	_version_label.text = "v0.0.0"
	column.add_child(_version_label)


func _menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 52)
	button.add_theme_font_size_override("font_size", 20)
	button.focus_mode = Control.FOCUS_NONE
	return button


func set_version(version: String) -> void:
	if _version_label != null:
		_version_label.text = "v%s" % version


func set_continue_available(available: bool) -> void:
	if _continue_button != null:
		_continue_button.disabled = not available
		_continue_button.text = "繼續遊戲" if available else "繼續遊戲（尚無存檔）"


func set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


func open() -> void:
	visible = true


func close() -> void:
	visible = false
