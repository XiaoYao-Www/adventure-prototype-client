class_name GameSession
extends RefCounted
## 遊戲流程控制器（純邏輯，不直接建立畫面節點）。
##
## 負責把 ContentRepository（內容）、GameState（玩家進度）、MapGrid（格子）
## 串成可測試的探索流程：逐格移動、互動、對話、effects、portal 切換、存讀檔還原。
## 畫面（WorldView / PlayerController / UI）由 main.gd 依本類別的訊號更新。
##
## 互動語義（v0.1，已寫入 docs/architecture/CONTENT_CONTRACT.md）：
## - 互動目標 = 玩家「面向格」（最後移動方向 + 1 格）上的實體。
## - 面向格沒有實體時，不顯示互動提示；不做相鄰格自動搜尋。

signal map_changed(map_id: String, grid: Vector2i)
signal player_moved(from_cell: Vector2i, to_cell: Vector2i)
signal dialogue_line_changed(speaker: String, text: String, line_index: int, total_lines: int)
signal dialogue_choices_ready(choice_texts: Array[String])
signal dialogue_finished
signal notice(text: String)

const UNKNOWN_CELL := Vector2i(-1, -1)
const ALLOWED_MOVE_DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var content: ContentRepository
var state: GameState
var grid: MapGrid
## 進行中的對話；空字典代表沒有對話。
var dialogue: Dictionary = {}
## 還原存檔時記錄的內容版本（僅供比對）。
var content_version: String = ""

# 抵達抑制：切換地圖後，玩家站在此格時不觸發 portal；離開後解除。
var _arrival_suppressed_cell: Vector2i = UNKNOWN_CELL
var _pending_move_target: Vector2i = UNKNOWN_CELL


## 初始化 session。state.current_map_id/player_grid 有值時視為讀檔還原，
## 否則從起始地圖的 spawn 開始。
func setup(content_repository: ContentRepository, game_state: GameState) -> bool:
	content = content_repository
	state = game_state
	dialogue = {}
	if content == null or state == null or not content.is_ok():
		return false
	var map_id: String = state.current_map_id
	var restoring: bool = not map_id.is_empty() and not content.get_map(map_id).is_empty()
	if not restoring:
		map_id = content.get_start_map_id()
		if map_id.is_empty():
			return false
		state.current_map_id = map_id
		var start_map: Dictionary = content.get_map(map_id)
		var spawn_cell: Vector2i = _cell_from_map(start_map, "spawn")
		state.player_grid = spawn_cell
		state.facing = Vector2i.DOWN
		enter_map(map_id, spawn_cell, true)
	else:
		var start_map: Dictionary = content.get_map(map_id)
		var target: Vector2i = state.player_grid
		var width: int = int(start_map.get("size", {}).get("width", 0))
		var height: int = int(start_map.get("size", {}).get("height", 0))
		if target.x < 0 or target.y < 0 or target.x >= width or target.y >= height:
			emit_signal("notice", "存檔位置無效，改用起始點")
			target = _cell_from_map(start_map, "spawn")
		enter_map(map_id, target, true)
	return grid != null


func is_ready() -> bool:
	return grid != null


func is_in_dialogue() -> bool:
	return not dialogue.is_empty()


# ---------------------------------------------------------------------------
# 移動
# ---------------------------------------------------------------------------

## 檢查並開始一次逐格移動；回傳 {moved, reason, target, target_world}。
## 實際狀態在 PlayerController 動畫結束後由 complete_move() 提交。
func try_move(direction: Vector2i) -> Dictionary:
	if not is_ready():
		return {"moved": false, "reason": "not_ready"}
	if is_in_dialogue():
		return {"moved": false, "reason": "in_dialogue"}
	if not ALLOWED_MOVE_DIRECTIONS.has(direction):
		return {"moved": false, "reason": "invalid_direction"}
	state.facing = direction
	var target: Vector2i = state.player_grid + direction
	if not grid.in_bounds(target):
		return {"moved": false, "reason": "out_of_bounds", "target": target}
	if not grid.is_walkable(target):
		return {"moved": false, "reason": "blocked_terrain", "target": target}
	if grid.has_entity(target):
		return {"moved": false, "reason": "blocked_entity", "target": target}
	_pending_move_target = target
	return {
		"moved": true,
		"from": state.player_grid,
		"target": target,
		"target_world": grid.cell_center_world(target),
	}


## 提交上一筆 try_move 成功的移動（動畫結束後呼叫）。
## 若目標格有 portal 且不處於抵達抑制，切換地圖。
func complete_move() -> Dictionary:
	if _pending_move_target == UNKNOWN_CELL:
		return {"moved": false, "reason": "no_pending_move"}
	var from_cell: Vector2i = state.player_grid
	var target: Vector2i = _pending_move_target
	_pending_move_target = UNKNOWN_CELL
	var suppressed: bool = target == _arrival_suppressed_cell
	if not suppressed:
		_arrival_suppressed_cell = UNKNOWN_CELL
	state.player_grid = target
	emit_signal("player_moved", from_cell, target)
	var result: Dictionary = {"moved": true, "from": from_cell, "target": target, "portal": false}
	if suppressed:
		return result
	var portal: Dictionary = grid.portal_at(target)
	if portal.is_empty():
		return result
	var transition: Dictionary = _transition_through_portal(portal)
	result["portal"] = true
	result["transition"] = transition
	return result


## 傳送門切換：重建目標地圖格子，把玩家放到 target_grid，並抑制抵達格 portal。
func _transition_through_portal(portal: Dictionary) -> Dictionary:
	var target_map_id: String = String(portal.get("target_map_id", ""))
	var target_map: Dictionary = content.get_map(target_map_id)
	if target_map.is_empty():
		# 理論上不會發生（載入器已驗證引用）；防禦性處理，不崩潰。
		emit_signal("notice", "傳送門目標地圖不存在：" + target_map_id)
		return {"ok": false, "reason": "missing_target_map"}
	var target_grid: Vector2i = _cell_from_portal_target(portal)
	var width: int = int(target_map.get("size", {}).get("width", 0))
	var height: int = int(target_map.get("size", {}).get("height", 0))
	if target_grid.x < 0 or target_grid.y < 0 or target_grid.x >= width or target_grid.y >= height:
		emit_signal("notice", "傳送門目標格無效，改用目標地圖起始點")
		target_grid = _cell_from_map(target_map, "spawn")
	enter_map(target_map_id, target_grid, true)
	return {"ok": true, "map_id": target_map_id, "grid": target_grid}


## 進入地圖。suppress_portal=true 時，玩家站在 target_grid 不會立刻觸發該格 portal。
func enter_map(map_id: String, target_grid: Vector2i, suppress_portal: bool) -> bool:
	var map_data: Dictionary = content.get_map(map_id)
	if map_data.is_empty():
		emit_signal("notice", "地圖不存在：" + map_id)
		return false
	grid = MapGrid.from_map_data(map_data)
	state.current_map_id = map_id
	if not grid.in_bounds(target_grid) or not grid.is_walkable(target_grid):
		var spawn: Vector2i = grid.spawn
		emit_signal("notice", "目標格不可通行，改用起始點")
		target_grid = spawn
	state.player_grid = target_grid
	_arrival_suppressed_cell = target_grid if suppress_portal else UNKNOWN_CELL
	_pending_move_target = UNKNOWN_CELL
	dialogue = {}
	emit_signal("map_changed", map_id, target_grid)
	return true


# ---------------------------------------------------------------------------
# 互動與對話
# ---------------------------------------------------------------------------

## 玩家面向格上的實體（沒有則空字典）。
func get_interaction_target() -> Dictionary:
	if not is_ready():
		return {}
	return grid.entity_at(state.player_grid + state.facing)


## 面向格是否有可互動事件。
func can_interact() -> bool:
	var entity: Dictionary = get_interaction_target()
	if entity.is_empty():
		return false
	var interaction: Dictionary = entity.get("interaction", {})
	var event_id: String = String(interaction.get("event_id", ""))
	var event: Dictionary = content.get_event(event_id)
	if event.is_empty():
		return false
	if not bool(event.get("repeatable", true)) and state.completed_event_ids.has(event_id):
		return false
	return true


## 開始互動：載入事件並顯示第一句。回傳是否成功開始。
func start_interaction() -> bool:
	if not is_ready() or is_in_dialogue():
		return false
	var entity: Dictionary = get_interaction_target()
	if entity.is_empty():
		return false
	var interaction: Dictionary = entity.get("interaction", {})
	var event_id: String = String(interaction.get("event_id", ""))
	var event: Dictionary = content.get_event(event_id)
	if event.is_empty():
		emit_signal("notice", "互動事件不存在：" + event_id)
		return false
	if not bool(event.get("repeatable", true)) and state.completed_event_ids.has(event_id):
		emit_signal("notice", "這個話題已經談過了")
		return false
	dialogue = {
		"event_id": event_id,
		"lines": event.get("lines", []),
		"choices": event.get("choices", []),
		"line_index": 0,
		"awaiting_choice": false,
		"repeatable": bool(event.get("repeatable", true)),
	}
	var lines: Array = dialogue["lines"]
	if lines.is_empty():
		# 載入器已禁止空 lines；防禦性關閉。
		_finish_dialogue()
		return false
	_emit_current_line()
	return true


## 推進對話：下一句 → 顯示選項 → 關閉。回傳 {action}。
func advance_dialogue() -> Dictionary:
	if dialogue.is_empty():
		return {"action": "none"}
	if bool(dialogue.get("awaiting_choice", false)):
		return {"action": "waiting_choice"}
	var lines: Array = dialogue.get("lines", [])
	var index: int = int(dialogue.get("line_index", 0))
	if index + 1 < lines.size():
		dialogue["line_index"] = index + 1
		_emit_current_line()
		return {"action": "line", "line_index": index + 1}
	var choices: Array = dialogue.get("choices", [])
	if not choices.is_empty():
		dialogue["awaiting_choice"] = true
		var texts: Array[String] = []
		for choice: Dictionary in choices:
			texts.append(String(choice.get("text", "")))
		emit_signal("dialogue_choices_ready", texts)
		return {"action": "choices", "choices": texts}
	if not bool(dialogue.get("repeatable", true)):
		state.mark_event_completed(String(dialogue.get("event_id", "")))
	_finish_dialogue()
	return {"action": "closed"}


## 選擇選項：套用 effects 後關閉對話。回傳 {ok, errors}。
func choose(choice_index: int) -> Dictionary:
	if dialogue.is_empty() or not bool(dialogue.get("awaiting_choice", false)):
		return {"ok": false, "errors": ["目前沒有可選擇的選項"] as Array[String]}
	var choices: Array = dialogue.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return {"ok": false, "errors": ["選項索引超出範圍"] as Array[String]}
	var choice: Dictionary = choices[choice_index]
	var effect_errors: Array[String] = apply_effects(choice.get("effects", []))
	var event_id: String = String(dialogue.get("event_id", ""))
	if not bool(dialogue.get("repeatable", true)):
		state.mark_event_completed(event_id)
	_finish_dialogue()
	return {"ok": effect_errors.is_empty(), "errors": effect_errors}


## 目前句子資料；沒有對話時回傳空字典。
func current_line() -> Dictionary:
	if dialogue.is_empty():
		return {}
	var lines: Array = dialogue.get("lines", [])
	var index: int = clampi(int(dialogue.get("line_index", 0)), 0, maxi(0, lines.size() - 1))
	if lines.is_empty():
		return {}
	var line: Dictionary = lines[index]
	return {
		"speaker": speaker_display_name(String(line.get("speaker_id", ""))),
		"text": String(line.get("text", "")),
		"line_index": index,
		"total_lines": lines.size(),
		"is_last_line": index == lines.size() - 1,
	}


func current_choices() -> Array[String]:
	var texts: Array[String] = []
	if dialogue.is_empty():
		return texts
	for choice: Dictionary in dialogue.get("choices", []):
		texts.append(String(choice.get("text", "")))
	return texts


## 說話者顯示名稱："player" → 「你」；NPC → 內容中的 name；找不到 → id 本身。
func speaker_display_name(speaker_id: String) -> String:
	if speaker_id == "player":
		return "你"
	var npc: Dictionary = content.get_npc(speaker_id)
	if not npc.is_empty():
		return String(npc.get("name", speaker_id))
	return speaker_id


func close_dialogue() -> void:
	if dialogue.is_empty():
		return
	_finish_dialogue()


func _emit_current_line() -> void:
	var line: Dictionary = current_line()
	if line.is_empty():
		return
	emit_signal("dialogue_line_changed", String(line["speaker"]), String(line["text"]), int(line["line_index"]), int(line["total_lines"]))


func _finish_dialogue() -> void:
	dialogue = {}
	emit_signal("dialogue_finished")


# ---------------------------------------------------------------------------
# Effects（v0.1 僅 set_flag / give_item）
# ---------------------------------------------------------------------------

## 套用 effects；未知 type 或參數錯誤 → 記錄錯誤、不執行、不崩潰。
## 回傳錯誤訊息陣列（空陣列代表全部成功）。
func apply_effects(effects: Variant) -> Array[String]:
	var effect_errors: Array[String] = []
	if not effects is Array:
		effect_errors.append("E_EFFECTS 必須是陣列")
		return effect_errors
	for raw_effect: Variant in effects:
		if not raw_effect is Dictionary:
			effect_errors.append("E_EFFECT 必須是物件")
			continue
		var effect: Dictionary = raw_effect
		var effect_type: String = String(effect.get("type", ""))
		match effect_type:
			"set_flag":
				var flag: Variant = effect.get("flag", null)
				var value: Variant = effect.get("value", null)
				if not flag is String or (flag as String).is_empty():
					effect_errors.append("E_EFFECT_PARAM set_flag 缺少有效 flag")
					continue
				if not value is bool:
					effect_errors.append("E_EFFECT_PARAM set_flag 的 value 必須是布林值")
					continue
				state.set_flag(flag, value)
			"give_item":
				var item_id: Variant = effect.get("item_id", null)
				var qty: Variant = effect.get("qty", null)
				if not item_id is String or (item_id as String).is_empty():
					effect_errors.append("E_EFFECT_PARAM give_item 缺少有效 item_id")
					continue
				if not qty is int or int(qty) <= 0:
					effect_errors.append("E_EFFECT_PARAM give_item 的 qty 必須是正整數")
					continue
				state.add_item(item_id, int(qty))
			_:
				effect_errors.append("E_EFFECT_UNKNOWN 未知 effect type：%s" % effect_type)
	return effect_errors


# ---------------------------------------------------------------------------
# 存讀檔還原
# ---------------------------------------------------------------------------

## 以已驗證的存檔資料還原；回傳 {ok, warnings, errors}。
func restore_from_save(data: Dictionary) -> Dictionary:
	var save_errors: Array[String] = []
	var save_warnings: Array[String] = []
	var map_id: String = String(data.get("map_id", ""))
	if content.get_map(map_id).is_empty():
		save_errors.append("存檔引用的地圖不存在：%s" % map_id)
		return {"ok": false, "errors": save_errors, "warnings": save_warnings}
	state.apply_dict(data)
	content_version = String(data.get("content_version", ""))
	if content_version != content.content_version:
		save_warnings.append("存檔內容版本 %s 與目前內容版本 %s 不同" % [content_version, content.content_version])
	var target: Vector2i = state.player_grid
	var map_data: Dictionary = content.get_map(map_id)
	var width: int = int(map_data.get("size", {}).get("width", 0))
	var height: int = int(map_data.get("size", {}).get("height", 0))
	if target.x < 0 or target.y < 0 or target.x >= width or target.y >= height:
		save_warnings.append("存檔位置超出地圖範圍，改用起始點")
		target = _cell_from_map(map_data, "spawn")
	enter_map(map_id, target, true)
	return {"ok": true, "errors": save_errors, "warnings": save_warnings}


# ---------------------------------------------------------------------------
# 小工具
# ---------------------------------------------------------------------------

func _cell_from_map(map_data: Dictionary, key: String) -> Vector2i:
	var value: Variant = map_data.get(key, {})
	if value is Dictionary:
		var raw: Variant = (value as Dictionary).get("grid", [])
		if raw is Vector2i:
			return raw
		if raw is Array and (raw as Array).size() == 2:
			return Vector2i(int((raw as Array)[0]), int((raw as Array)[1]))
	return Vector2i.ZERO


func _cell_from_portal_target(portal: Dictionary) -> Vector2i:
	var raw: Variant = portal.get("target_grid", [])
	if raw is Vector2i:
		return raw
	if raw is Array and (raw as Array).size() == 2:
		return Vector2i(int((raw as Array)[0]), int((raw as Array)[1]))
	return Vector2i.ZERO


## 取消尚未提交的移動（例如畫面端因移動中而拒絕演出）。
func abort_pending_move() -> void:
	_pending_move_target = UNKNOWN_CELL
