class_name TouchControls
extends Control
## 觸控虛擬控制（Android 優先）：方向鍵、互動、存讀檔按鈕。
##
## 目的：Android 手機沒有實體鍵盤，沒有這層 UI 就無法移動或互動。
## 職責邊界：只把「按下」轉成訊號；不判斷遊戲規則、不改遊戲狀態。
## main.gd 負責連接訊號到 GameSession。
##
## 佈局以 960x540 基準解析度設計（canvas_items + expand 縮放），
## 按鈕尺寸遠大於 48px 觸控目標；錨點貼齊安全邊界（MARGIN）。
## 顯示條件：觸控螢幕或 Android/mobile 平台；桌機鍵盤環境自動隱藏。

signal move_pressed(direction: Vector2i)
signal interact_pressed
signal save_pressed
signal load_pressed

const BUTTON_SIZE := 88.0
const INTERACT_SIZE := 120.0
const SMALL_BUTTON_W := 76.0
const SMALL_BUTTON_H := 44.0
const MARGIN := 16.0

var _dpad: Dictionary = {}
var _interact_button: Button
var _save_button: Button
var _load_button: Button
var _built: bool = false

# 測試用：強制顯示狀態（null = 依平台自動判斷）
var _visibility_override: Variant = null


func _init() -> void:
	# 在 _init 建立子節點，讓測試與主場景不必等待 _ready。
	_build()


func _ready() -> void:
	_apply_visibility()


func _build() -> void:
	if _built:
		return
	_built = true
	name = "TouchControls"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_dpad()
	_build_interact_button()
	_build_save_load_buttons()


func _build_dpad() -> void:
	var anchor := Control.new()
	anchor.name = "DpadAnchor"
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	anchor.offset_left = MARGIN
	anchor.offset_top = -(MARGIN + BUTTON_SIZE * 3.0)
	anchor.offset_right = MARGIN + BUTTON_SIZE * 3.0
	anchor.offset_bottom = -MARGIN
	add_child(anchor)

	var grid := GridContainer.new()
	grid.name = "DpadGrid"
	grid.columns = 3
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(grid)

	for row: int in 3:
		for column: int in 3:
			var direction: Vector2i = _direction_for_cell(column, row)
			if direction == Vector2i.ZERO:
				var spacer := Control.new()
				spacer.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
				spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
				grid.add_child(spacer)
				continue
			var button := _new_button(_direction_glyph(direction), BUTTON_SIZE, BUTTON_SIZE, 26)
			button.name = "Move" + _direction_name(direction)
			button.pressed.connect(_on_direction_pressed.bind(direction))
			grid.add_child(button)
			_dpad[direction] = button


func _build_interact_button() -> void:
	_interact_button = _new_button("互動", INTERACT_SIZE, INTERACT_SIZE, 24)
	_interact_button.name = "InteractButton"
	_interact_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_interact_button.offset_left = -(MARGIN + INTERACT_SIZE)
	_interact_button.offset_top = -(MARGIN + INTERACT_SIZE)
	_interact_button.offset_right = -MARGIN
	_interact_button.offset_bottom = -MARGIN
	_interact_button.pressed.connect(_on_interact_pressed)
	add_child(_interact_button)


func _build_save_load_buttons() -> void:
	var row := HBoxContainer.new()
	row.name = "SaveLoadRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	row.offset_left = -(MARGIN + SMALL_BUTTON_W * 2.0 + 8.0)
	row.offset_top = MARGIN
	row.offset_right = -MARGIN
	row.offset_bottom = MARGIN + SMALL_BUTTON_H
	add_child(row)

	_save_button = _new_button("存檔", SMALL_BUTTON_W, SMALL_BUTTON_H, 14)
	_save_button.name = "SaveButton"
	_save_button.pressed.connect(_on_save_pressed)
	row.add_child(_save_button)

	_load_button = _new_button("讀檔", SMALL_BUTTON_W, SMALL_BUTTON_H, 14)
	_load_button.name = "LoadButton"
	_load_button.pressed.connect(_on_load_pressed)
	row.add_child(_load_button)


func _new_button(text: String, width: float, height: float, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, height)
	button.add_theme_font_size_override("font_size", font_size)
	button.focus_mode = Control.FOCUS_NONE
	button.modulate = Color(1.0, 1.0, 1.0, 0.82)
	return button


static func _direction_for_cell(column: int, row: int) -> Vector2i:
	if column == 1 and row == 0:
		return Vector2i.UP
	if column == 0 and row == 1:
		return Vector2i.LEFT
	if column == 2 and row == 1:
		return Vector2i.RIGHT
	if column == 1 and row == 2:
		return Vector2i.DOWN
	return Vector2i.ZERO


static func _direction_glyph(direction: Vector2i) -> String:
	if direction == Vector2i.UP:
		return "▲"
	if direction == Vector2i.DOWN:
		return "▼"
	if direction == Vector2i.LEFT:
		return "◀"
	if direction == Vector2i.RIGHT:
		return "▶"
	return "?"


static func _direction_name(direction: Vector2i) -> String:
	if direction == Vector2i.UP:
		return "Up"
	if direction == Vector2i.DOWN:
		return "Down"
	if direction == Vector2i.LEFT:
		return "Left"
	if direction == Vector2i.RIGHT:
		return "Right"
	return "None"


## 依平台決定是否顯示；桌機鍵盤環境隱藏，避免擋畫面。
func should_show() -> bool:
	if _visibility_override != null:
		return bool(_visibility_override)
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or OS.has_feature("android")


func _apply_visibility() -> void:
	visible = should_show()


## 測試用：強制顯示或隱藏（null 恢復平台判斷）。
func set_visibility_override(value: Variant) -> void:
	_visibility_override = value
	_apply_visibility()


func _on_direction_pressed(direction: Vector2i) -> void:
	emit_signal("move_pressed", direction)


func _on_interact_pressed() -> void:
	emit_signal("interact_pressed")


func _on_save_pressed() -> void:
	emit_signal("save_pressed")


func _on_load_pressed() -> void:
	emit_signal("load_pressed")


# ---------------------------------------------------------------------------
# 測試用存取器（不改變行為）
# ---------------------------------------------------------------------------

func direction_button(direction: Vector2i) -> Button:
	return _dpad.get(direction, null)


func dpad_button_count() -> int:
	return _dpad.size()


func interact_button() -> Button:
	return _interact_button


func save_button() -> Button:
	return _save_button


func load_button() -> Button:
	return _load_button
