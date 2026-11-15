class_name DialoguePanel
extends PanelContainer
## 對話框 UI：說話者名稱、逐句文字、選項按鈕。
##
## 只負責呈現與輸入轉發；對話流程（推進/套用 effects/關閉）由 GameSession 決定。
## 點擊面板或按互動鍵 = 下一句；有選項時點按鈕或按數字鍵（由 main.gd 轉發）。
## 以程式建立子節點，避免手寫複雜 .tscn。

signal advance_requested
signal choice_selected(choice_index: int)

var _speaker_label: Label
var _text_label: Label
var _hint_label: Label
var _choices_box: VBoxContainer
var _choice_buttons: Array[Button] = []
var _has_choices: bool = false


func _ready() -> void:
	_build()
	hide_panel()


func _build() -> void:
	name = "DialoguePanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -380.0
	offset_right = 380.0
	offset_top = -190.0
	offset_bottom = -24.0

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	_speaker_label = Label.new()
	_speaker_label.name = "SpeakerLabel"
	_speaker_label.add_theme_font_size_override("font_size", 18)
	column.add_child(_speaker_label)

	_text_label = Label.new()
	_text_label.name = "TextLabel"
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_font_size_override("font_size", 16)
	_text_label.custom_minimum_size = Vector2(0, 48)
	column.add_child(_text_label)

	_choices_box = VBoxContainer.new()
	_choices_box.name = "ChoicesBox"
	_choices_box.add_theme_constant_override("separation", 4)
	column.add_child(_choices_box)

	_hint_label = Label.new()
	_hint_label.name = "HintLabel"
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.modulate = Color(1, 1, 1, 0.7)
	column.add_child(_hint_label)

	gui_input.connect(_on_gui_input)


## 顯示一句台詞。
func show_line(speaker: String, text: String, line_index: int, total_lines: int) -> void:
	_clear_choices()
	_has_choices = false
	_speaker_label.text = speaker
	_text_label.text = text
	_hint_label.text = "第 %d/%d 句｜E / Space / Enter 繼續" % [line_index + 1, total_lines]
	visible = true


## 顯示選項按鈕（滑鼠點擊或數字鍵 1..N）。
func show_choices(choice_texts: Array[String]) -> void:
	_clear_choices()
	_has_choices = true
	for index: int in choice_texts.size():
		var button := Button.new()
		button.name = "Choice%d" % (index + 1)
		button.text = "%d. %s" % [index + 1, choice_texts[index]]
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(_on_choice_button_pressed.bind(index))
		_choices_box.add_child(button)
		_choice_buttons.append(button)
	_hint_label.text = "選擇：點擊按鈕或按數字鍵"
	visible = true


func hide_panel() -> void:
	visible = false
	_has_choices = false
	_clear_choices()


func has_choices() -> bool:
	return _has_choices


func choice_count() -> int:
	return _choice_buttons.size()


## 由 main.gd 在按下數字鍵時呼叫。
func press_choice(index: int) -> void:
	if not _has_choices or index < 0 or index >= _choice_buttons.size():
		return
	emit_signal("choice_selected", index)


func _clear_choices() -> void:
	for button: Button in _choice_buttons:
		if is_instance_valid(button):
			button.queue_free()
	_choice_buttons.clear()


func _on_choice_button_pressed(index: int) -> void:
	emit_signal("choice_selected", index)


func _on_gui_input(event: InputEvent) -> void:
	if _has_choices:
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			emit_signal("advance_requested")
