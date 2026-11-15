class_name GameState
extends RefCounted
## 玩家的可持久化狀態（與內容版本分離）。
##
## 只保存「玩家進度」，不保存內容定義：
## - flags：劇情旗標（String -> bool）
## - inventory：物品數量（item_id -> int）
## - current_map_id / player_grid / facing：所在位置
## - content_version：存檔時使用的內容版本（僅供比對，不影響存檔格式）
##
## 本類別不做 I/O，序列化由 SaveManager 負責。

const FACING_NAMES: Array[String] = ["up", "down", "left", "right"]

var flags: Dictionary = {}
var inventory: Dictionary = {}
var current_map_id: String = ""
var player_grid: Vector2i = Vector2i.ZERO
var facing: Vector2i = Vector2i.DOWN
var content_version: String = ""
## 已完成（repeatable == false）的事件 id；存檔持久化，讀檔缺少時視為空。
var completed_event_ids: Array[String] = []


## 將方向向量轉為存檔用的名稱；非單位方向回傳 "down"。
static func facing_to_name(dir: Vector2i) -> String:
	if dir == Vector2i.UP:
		return "up"
	if dir == Vector2i.LEFT:
		return "left"
	if dir == Vector2i.RIGHT:
		return "right"
	return "down"


## 將存檔名稱轉為方向向量；未知名稱回傳 Vector2i.DOWN。
static func name_to_facing(value: String) -> Vector2i:
	match value:
		"up":
			return Vector2i.UP
		"left":
			return Vector2i.LEFT
		"right":
			return Vector2i.RIGHT
		_:
			return Vector2i.DOWN


func set_flag(flag: String, value: bool) -> void:
	flags[flag] = value


func get_flag(flag: String, default_value: bool = false) -> bool:
	var value: Variant = flags.get(flag, default_value)
	return value is bool and value


## 增加物品數量；qty 必須為正整數，否則忽略並回傳 false。
func add_item(item_id: String, qty: int) -> bool:
	if item_id.is_empty() or qty <= 0:
		return false
	inventory[item_id] = item_count(item_id) + qty
	return true


func item_count(item_id: String) -> int:
	return int(inventory.get(item_id, 0))


## 回傳可直接寫入存檔的資料（不含 save_version 等外層欄位）。
func to_dict() -> Dictionary:
	return {
		"map_id": current_map_id,
		"player": {
			"grid": [player_grid.x, player_grid.y],
			"facing": facing_to_name(facing),
		},
		"flags": flags.duplicate(true),
		"inventory": inventory.duplicate(true),
		"completed_event_ids": completed_event_ids.duplicate(),
	}


## 從已驗證的存檔資料還原狀態。
## 呼叫端（GameSession）負責 map_id 與 grid 的內容層級驗證。
func apply_dict(data: Dictionary) -> void:
	flags = {}
	inventory = {}
	completed_event_ids = []
	var raw_flags: Variant = data.get("flags", {})
	if raw_flags is Dictionary:
		for key: Variant in raw_flags:
			flags[String(key)] = bool(raw_flags[key])
	var raw_inventory: Variant = data.get("inventory", {})
	if raw_inventory is Dictionary:
		for key: Variant in raw_inventory:
			inventory[String(key)] = int(raw_inventory[key])
	var raw_completed: Variant = data.get("completed_event_ids", [])
	if raw_completed is Array:
		for event_id: Variant in raw_completed:
			var text: String = String(event_id)
			if not text.is_empty() and not completed_event_ids.has(text):
				completed_event_ids.append(text)
	current_map_id = String(data.get("map_id", ""))
	var player: Variant = data.get("player", {})
	if player is Dictionary:
		var raw_grid: Variant = player.get("grid", [])
		if raw_grid is Array and raw_grid.size() == 2:
			player_grid = Vector2i(int(raw_grid[0]), int(raw_grid[1]))
		facing = name_to_facing(String(player.get("facing", "down")))


## 記錄一個已完成且不可重複的事件（repeatable == false）。
func mark_event_completed(event_id: String) -> void:
	if event_id.is_empty() or completed_event_ids.has(event_id):
		return
	completed_event_ids.append(event_id)


func has_completed_event(event_id: String) -> bool:
	return completed_event_ids.has(event_id)
