class_name SaveManager
extends RefCounted
## 存檔 I/O 與格式驗證（save format v1）。
##
## 格式（docs/architecture/SAVE_FORMAT.md）：
## {
##   "save_version": 1,
##   "game_version": "0.1.0",
##   "content_version": "0.1.0",
##   "map_id": "map_start_village",
##   "player": {"grid": [x,y], "facing": "down"},
##   "flags": {"flag_key": true},
##   "inventory": {"item_id": 2},
##   "completed_event_ids": ["event_chest_herb_001"],
##   "updated_at": "2026-11-16T00:00:00Z"
## }
##
## - 玩家進度與內容版本分離：讀檔不要求 content_version 相同，由 GameSession 警告。
## - 不支援的 save_version → 回傳錯誤且不覆寫任何資料。

const SAVE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://save_01.json"
const MAX_SAVE_BYTES := 1024 * 1024
const MAX_FLAGS := 512
const MAX_INVENTORY_ENTRIES := 128
const MAX_COMPLETED_EVENTS := 512


## 建立存檔資料（純資料，不寫檔）。
func build_save_data(state: GameState, content_version: String, game_version: String = "0.1.0") -> Dictionary:
	var data: Dictionary = state.to_dict()
	data["save_version"] = SAVE_VERSION
	data["game_version"] = game_version
	data["content_version"] = content_version
	data["updated_at"] = _utc_timestamp()
	return data


## 寫入存檔（先寫 .tmp 再更名，降低半寫入風險）。
## 回傳 {ok, error, path, bytes}。
func save_state(state: GameState, content_version: String, path: String = DEFAULT_SAVE_PATH) -> Dictionary:
	if state == null or state.current_map_id.is_empty():
		return {"ok": false, "error": "E_SAVE_STATE 沒有可儲存的地圖狀態"}
	if state.player_grid.x < 0 or state.player_grid.y < 0:
		return {"ok": false, "error": "E_SAVE_STATE 玩家座標無效"}
	var data: Dictionary = build_save_data(state, content_version)
	var text: String = JSON.stringify(data, "\t")
	var tmp_path: String = path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "E_SAVE_OPEN 無法寫入暫存檔（錯誤碼 %d）" % FileAccess.get_open_error()}
	file.store_string(text)
	file.flush()
	file.close()

	var rename_error: int = DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp_path), ProjectSettings.globalize_path(path))
	if rename_error != OK:
		# 部分平台（Windows）無法直接覆蓋既有檔名：先刪除再更名。
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		rename_error = DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp_path), ProjectSettings.globalize_path(path))
	if rename_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
		return {"ok": false, "error": "E_SAVE_RENAME 無法更名存檔（錯誤碼 %d）" % rename_error}
	return {"ok": true, "path": path, "bytes": text.to_utf8_buffer().size()}


## 讀取存檔並驗證格式。回傳 {ok, error, errors, data}。
func load_save(path: String = DEFAULT_SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "E_SAVE_NOT_FOUND 找不到存檔：%s" % path, "errors": ["找不到存檔：" + path]}
	var size: int = _file_size(path)
	if size < 0:
		return {"ok": false, "error": "E_SAVE_READ 無法讀取存檔", "errors": ["無法讀取存檔：" + path]}
	if size > MAX_SAVE_BYTES:
		return {"ok": false, "error": "E_SAVE_TOO_LARGE 存檔超過大小上限", "errors": ["存檔超過大小上限 %d bytes" % MAX_SAVE_BYTES]}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "E_SAVE_READ 無法讀取存檔", "errors": ["無法讀取存檔：" + path]}
	var text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	var parse_error: int = json.parse(text)
	if parse_error != OK:
		return {
			"ok": false,
			"error": "E_SAVE_JSON 存檔不是合法 JSON（第 %d 行：%s）" % [json.get_error_line(), json.get_error_message()],
			"errors": ["存檔不是合法 JSON（第 %d 行：%s）" % [json.get_error_line(), json.get_error_message()]],
		}
	if not json.data is Dictionary:
		return {"ok": false, "error": "E_SAVE_TYPE 存檔頂層必須是物件", "errors": ["存檔頂層必須是物件"]}
	var data: Dictionary = json.data
	var validation_errors: Array[String] = validate_save_data(data)
	if not validation_errors.is_empty():
		return {"ok": false, "error": validation_errors[0], "errors": validation_errors, "data": data}
	return {"ok": true, "errors": [] as Array[String], "data": data}


## 驗證存檔資料（不修改資料、不讀寫其他檔案）。回傳錯誤訊息陣列。
func validate_save_data(data: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var version: Variant = data.get("save_version", null)
	if not _is_int(version):
		problems.append("E_SAVE_VERSION 缺少整數 save_version")
	elif int(version) != SAVE_VERSION:
		problems.append("E_SAVE_VERSION 不支援的存檔版本 save_version=%d（支援 %d）" % [int(version), SAVE_VERSION])
	var content_version: Variant = data.get("content_version", null)
	if not content_version is String or (content_version as String).is_empty():
		problems.append("E_SAVE_FIELD content_version 必須是非空字串")
	if not data.get("game_version", "0.1.0") is String:
		problems.append("E_SAVE_FIELD game_version 必須是字串")
	var map_id: Variant = data.get("map_id", null)
	if not map_id is String or (map_id as String).is_empty():
		problems.append("E_SAVE_FIELD map_id 必須是非空字串")
	var player: Variant = data.get("player", null)
	if not player is Dictionary:
		problems.append("E_SAVE_FIELD player 必須是物件")
	else:
		var player_data: Dictionary = player
		var grid: Variant = player_data.get("grid", null)
		if not grid is Array or (grid as Array).size() != 2 or not _is_int((grid as Array)[0]) or not _is_int((grid as Array)[1]):
			problems.append("E_SAVE_FIELD player.grid 必須是 [x,y] 兩個整數")
		else:
			if int((grid as Array)[0]) < 0 or int((grid as Array)[1]) < 0:
				problems.append("E_SAVE_FIELD player.grid 不可為負數")
		var facing: Variant = player_data.get("facing", "down")
		if not facing is String or not GameState.FACING_NAMES.has(facing):
			problems.append("E_SAVE_FIELD player.facing 必須是 up/down/left/right")
	var flags: Variant = data.get("flags", {})
	if not flags is Dictionary:
		problems.append("E_SAVE_FIELD flags 必須是物件")
	elif (flags as Dictionary).size() > MAX_FLAGS:
		problems.append("E_SAVE_FIELD flags 超過上限 %d" % MAX_FLAGS)
	else:
		for key: Variant in flags:
			if String(key).is_empty() or not flags[key] is bool:
				problems.append("E_SAVE_FIELD flags 的鍵必須非空、值必須是布林")
				break
	var inventory: Variant = data.get("inventory", {})
	if not inventory is Dictionary:
		problems.append("E_SAVE_FIELD inventory 必須是物件")
	elif (inventory as Dictionary).size() > MAX_INVENTORY_ENTRIES:
		problems.append("E_SAVE_FIELD inventory 超過上限 %d" % MAX_INVENTORY_ENTRIES)
	else:
		for key: Variant in inventory:
			if String(key).is_empty() or not _is_int(inventory[key]) or int(inventory[key]) <= 0:
				problems.append("E_SAVE_FIELD inventory 的鍵必須非空、值必須是正整數")
				break
	var completed: Variant = data.get("completed_event_ids", [])
	if not completed is Array:
		problems.append("E_SAVE_FIELD completed_event_ids 必須是陣列")
	elif (completed as Array).size() > MAX_COMPLETED_EVENTS:
		problems.append("E_SAVE_FIELD completed_event_ids 超過上限 %d" % MAX_COMPLETED_EVENTS)
	else:
		for event_id: Variant in completed:
			if not event_id is String or (event_id as String).is_empty():
				problems.append("E_SAVE_FIELD completed_event_ids 的元素必須是非空字串")
				break
	var updated_at: Variant = data.get("updated_at", null)
	if not updated_at is String or (updated_at as String).is_empty():
		problems.append("E_SAVE_FIELD updated_at 必須是非空字串（ISO8601 UTC）")
	return problems


static func _utc_timestamp() -> String:
	return Time.get_datetime_string_from_system(true, false) + "Z"


static func _is_int(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		return is_equal_approx(value, floorf(value))
	return false


func _file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var size: int = file.get_length()
	file.close()
	return size
