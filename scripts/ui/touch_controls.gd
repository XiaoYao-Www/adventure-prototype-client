class_name TouchControls
extends Control
## 觸控虛擬控制（Android 優先）：方向鍵、互動、存讀檔、世界手勢。
##
## 設計原則：
## - 不依賴 Button 節點與 Control 佈局，改為「自己畫 + 自己命中測試」，
##   避免不同裝置／縮放／CanvasLayer 佈局造成按鈕消失或點不到。
## - 只發出訊號；不判斷遊戲規則。main.gd 連接訊號到 GameSession。
## - 方向鍵支援「按住連走」；世界區域支援滑動轉向與輕點互動。
## - 對話中由 main 設為 blocked，避免攔截對話框／選項的點擊。
##
## 座標：在 canvas_items + expand 拉伸下，輸入事件的 viewport 座標即為
## 設計基準座標（960x540 基準），本控制項自行量測 viewport 尺寸後排版。

signal move_pressed(direction: Vector2i)
signal interact_pressed
signal save_pressed
signal load_pressed

const MARGIN := 14.0
const HOLD_DELAY := 0.28
const REPEAT_INTERVAL := 0.14
const SWIPE_THRESHOLD := 44.0
const TAP_MAX_TIME := 0.4
const TAP_MAX_DISTANCE := 18.0

var _blocked: bool = false
var _visibility_override: Variant = null
var _font: Font = null

# 按住連走
var _held_direction: Vector2i = Vector2i.ZERO
var _held_touch_index: int = -1
var _hold_time: float = 0.0
var _repeat_timer: float = 0.0

# 世界手勢（非按鈕區域）
var _press_touch_index: int = -1
var _press_start: Vector2 = Vector2.ZERO
var _press_moved: bool = false
var _press_time: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = get_theme_font("font")
	var viewport := get_viewport()
	if viewport != null:
		viewport.size_changed.connect(_sync_size)
	_sync_size()
	_apply_visibility()
	queue_redraw()


func _sync_size() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_VISIBILITY_CHANGED:
		queue_redraw()


# ---------------------------------------------------------------------------
# 佈局（依目前 viewport 尺寸計算；所有位置都是本控制項的區域座標）
# ---------------------------------------------------------------------------

func _button_size() -> float:
	# 依較短邊縮放，手機／平板都能保持足夠觸控目標（>= 60px）
	return clampf(minf(size.x, size.y) * 0.16, 60.0, 110.0)


func _layout() -> Dictionary:
	var b := _button_size()
	var pad: float = b * 0.10
	var dpad_origin := Vector2(MARGIN, size.y - MARGIN - b * 3.0)
	var interact_size: float = clampf(minf(size.x, size.y) * 0.22, 84.0, 140.0)
	var small_w: float = b * 1.18
	var small_h: float = b * 0.72
	var rects := {
		"up": Rect2(dpad_origin + Vector2(b + pad, 0), Vector2(b, b)),
		"left": Rect2(dpad_origin + Vector2(0, b + pad), Vector2(b, b)),
		"right": Rect2(dpad_origin + Vector2((b + pad) * 2.0, b + pad), Vector2(b, b)),
		"down": Rect2(dpad_origin + Vector2(b + pad, (b + pad) * 2.0), Vector2(b, b)),
		"interact": Rect2(
			Vector2(size.x - MARGIN - interact_size, size.y - MARGIN - interact_size),
			Vector2(interact_size, interact_size)
		),
		"save": Rect2(Vector2(size.x - MARGIN - small_w * 2.0 - 8.0, MARGIN), Vector2(small_w, small_h)),
		"load": Rect2(Vector2(size.x - MARGIN - small_w, MARGIN), Vector2(small_w, small_h)),
	}
	return rects


## 對外可測試：目前各控制項的矩形。
func button_rects() -> Dictionary:
	return _layout()


func hit_test(point: Vector2) -> String:
	var rects := _layout()
	for key: String in ["up", "down", "left", "right", "interact", "save", "load"]:
		if (rects[key] as Rect2).has_point(point):
			return key
	return ""


# ---------------------------------------------------------------------------
# 輸入（只處理觸控平台；桌機鍵盤不受影響）
# ---------------------------------------------------------------------------

func _is_touch_platform() -> bool:
	return (
		DisplayServer.is_touchscreen_available()
		or OS.has_feature("mobile")
		or OS.has_feature("android")
	)


func _input(event: InputEvent) -> void:
	if not visible or _blocked:
		return
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_handle_press(touch_event.index, touch_event.position)
		else:
			_handle_release(touch_event.index)
		return
	if event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		_handle_drag(drag_event.index, drag_event.position)
		return
	# 桌機以滑鼠模擬（Android 會同時送 touch 與模擬 mouse，避免重複觸發）
	if event is InputEventMouseButton and not _is_touch_platform():
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_handle_press(-1, mouse_event.position)
			else:
				_handle_release(-1)


func _handle_press(touch_index: int, point: Vector2) -> void:
	_press_touch_index = touch_index
	_press_start = point
	_press_moved = false
	_press_time = 0.0
	var hit := hit_test(point)
	match hit:
		"up":
			_start_hold(Vector2i.UP, touch_index)
		"down":
			_start_hold(Vector2i.DOWN, touch_index)
		"left":
			_start_hold(Vector2i.LEFT, touch_index)
		"right":
			_start_hold(Vector2i.RIGHT, touch_index)
		"interact":
			emit_signal("interact_pressed")
			_press_touch_index = -1
			accept_event()
		"save":
			emit_signal("save_pressed")
			_press_touch_index = -1
			accept_event()
		"load":
			emit_signal("load_pressed")
			_press_touch_index = -1
			accept_event()
		_:
			# 世界區域：先記錄，放開時判斷輕點或滑動
			pass
	if not hit.is_empty():
		accept_event()


func _start_hold(direction: Vector2i, touch_index: int) -> void:
	_held_direction = direction
	_held_touch_index = touch_index
	_hold_time = 0.0
	_repeat_timer = 0.0
	emit_signal("move_pressed", direction)
	_press_touch_index = -1
	accept_event()


func _handle_drag(touch_index: int, point: Vector2) -> void:
	if _held_direction != Vector2i.ZERO:
		return
	if _press_touch_index != touch_index:
		return
	var delta: Vector2 = point - _press_start
	if delta.length() < SWIPE_THRESHOLD:
		return
	_press_moved = true
	var direction: Vector2i = Vector2i.ZERO
	if absf(delta.x) >= absf(delta.y):
		direction = Vector2i.RIGHT if delta.x > 0.0 else Vector2i.LEFT
	else:
		direction = Vector2i.DOWN if delta.y > 0.0 else Vector2i.UP
	emit_signal("move_pressed", direction)
	# 允許一次拖曳連續轉向：以目前位置為新起點
	_press_start = point
	accept_event()


func _handle_release(touch_index: int) -> void:
	if _held_touch_index == touch_index:
		_held_direction = Vector2i.ZERO
		_held_touch_index = -1
		_hold_time = 0.0
		_repeat_timer = 0.0
	if _press_touch_index == touch_index:
		var was_tap := not _press_moved and _press_time <= TAP_MAX_TIME
		_press_touch_index = -1
		if was_tap:
			# 世界區域輕點 = 互動（與鍵盤 E 相同行為）
			emit_signal("interact_pressed")
		accept_event()


func _process(delta: float) -> void:
	_press_time += delta
	if _held_direction == Vector2i.ZERO:
		return
	_hold_time += delta
	if _hold_time < HOLD_DELAY:
		return
	_repeat_timer += delta
	while _repeat_timer >= REPEAT_INTERVAL:
		_repeat_timer -= REPEAT_INTERVAL
		emit_signal("move_pressed", _held_direction)


# ---------------------------------------------------------------------------
# 繪製（不依賴主題按鈕，確保任何解析度都看得到）
# ---------------------------------------------------------------------------

func _draw() -> void:
	if not visible:
		return
	var rects := _layout()
	var labels := {
		"up": "▲", "down": "▼", "left": "◀", "right": "▶",
		"interact": "互動", "save": "存檔", "load": "讀檔",
	}
	for key: String in rects:
		var rect: Rect2 = rects[key]
		_draw_rounded_rect(rect, minf(rect.size.x, rect.size.y) * 0.18, Color(0.06, 0.08, 0.12, 0.55), Color(1, 1, 1, 0.35))
		_draw_text_in_rect(labels[key], rect, int(clampf(rect.size.y * 0.42, 12.0, 30.0)), Color(1, 1, 1, 0.92))
	if not _blocked:
		_draw_text_in_rect(
			"滑動移動｜輕點互動",
			Rect2(Vector2(0, size.y - 30.0), Vector2(size.x, 24.0)),
			14,
			Color(1, 1, 1, 0.45)
		)


func _draw_rounded_rect(rect: Rect2, radius: float, fill: Color, border: Color) -> void:
	# 用多個矩形近似圓角，避免依賴 StyleBox 資源。
	var r := clampf(radius, 0.0, minf(rect.size.x, rect.size.y) * 0.5)
	draw_rect(rect.grow(-r), fill, true)
	draw_rect(Rect2(rect.position + Vector2(r, 0), Vector2(rect.size.x - r * 2.0, rect.size.y)), fill, true)
	draw_rect(Rect2(rect.position + Vector2(0, r), Vector2(rect.size.x, rect.size.y - r * 2.0)), fill, true)
	draw_rect(rect, border, false, 2.0)


func _draw_text_in_rect(text: String, rect: Rect2, font_size: int, color: Color) -> void:
	if _font == null:
		return
	var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := rect.position + Vector2(
		(rect.size.x - text_size.x) * 0.5,
		(rect.size.y + text_size.y) * 0.5 - 2.0
	)
	draw_string(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


# ---------------------------------------------------------------------------
# 狀態控制
# ---------------------------------------------------------------------------

func should_show() -> bool:
	if _visibility_override != null:
		return bool(_visibility_override)
	return _is_touch_platform()


func _apply_visibility() -> void:
	visible = should_show()
	queue_redraw()


func set_visibility_override(value: Variant) -> void:
	_visibility_override = value
	_apply_visibility()


## 對話／選項開啟時設為 true，避免攔截對話框點擊；同時清除按住狀態。
func set_input_blocked(blocked: bool) -> void:
	_blocked = blocked
	if blocked:
		_held_direction = Vector2i.ZERO
		_held_touch_index = -1
		_press_touch_index = -1
	queue_redraw()


func is_input_blocked() -> bool:
	return _blocked
