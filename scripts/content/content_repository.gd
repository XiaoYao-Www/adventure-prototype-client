class_name ContentRepository
extends RefCounted
## 內容倉庫載入器（content contract v1）。
##
## 職責：
## 1. 解析內容目錄來源（CLI > ProjectSettings > res://content）。
## 2. 讀取 manifest.json，驗證每個檔案的 path / size / sha256。
## 3. 解析 region / map / npc / item / event，驗證 schema 與引用完整性。
## 4. 收集可讀錯誤與警告，任何單一檔案失敗都不會讓程式崩潰。
##
## 本類別不做畫面呈現；錯誤由 ErrorPanel 顯示。所有驗證通過前，呼叫端
## 不應開始遊戲（GameSession.setup() 會檢查 is_ok()）。
##
## 內容資料來源：game-content 倉庫（外部目錄），或 res://content 內建
## 建置快照。載入器只讀取資料，不執行內容中的任何程式碼。

const GAME_VERSION := "0.1.0"
const SUPPORTED_MANIFEST_SCHEMA := 1
const SUPPORTED_CONTENT_SCHEMA := 1
const MAX_FILE_BYTES := 4 * 1024 * 1024
const MAX_MANIFEST_FILES := 512
const MAX_MAP_DIMENSION := 256
const MAX_ENTITIES_PER_MAP := 256
const MAX_PORTALS_PER_MAP := 64
const MAX_DIALOGUE_LINES := 200
const MAX_CHOICES := 8
const MAX_FLAG_NAME_LENGTH := 64

const ALLOWED_EFFECT_TYPES: Array[String] = ["set_flag", "give_item"]
const ALLOWED_ENTITY_TYPES: Array[String] = ["npc", "object"]
const ALLOWED_EVENT_KINDS: Array[String] = ["dialogue"]

var content_dir: String = ""
var content_id: String = ""
var content_version: String = ""
var min_game_version: String = ""
var manifest: Dictionary = {}

var maps: Dictionary = {}
var regions: Dictionary = {}
var npcs: Dictionary = {}
var items: Dictionary = {}
var events: Dictionary = {}

var errors: Array[String] = []
var warnings: Array[String] = []
var loaded: bool = false


## 解析內容目錄來源，優先序：CLI 使用者參數 > ProjectSettings > res://content。
static func resolve_content_dir(user_args: PackedStringArray, project_setting: String) -> String:
	var cli_dir: String = content_dir_from_user_args(user_args)
	if not cli_dir.is_empty():
		return cli_dir
	if not project_setting.is_empty():
		return project_setting
	var installed: String = installed_content_dir()
	if not installed.is_empty():
		return installed
	return "res://content"


## 已透過自動更新安裝的內容（user://content_current.json）；沒有或損壞時回傳空字串。
static func installed_content_dir() -> String:
	const pointer_path := "user://content_current.json"
	if not FileAccess.file_exists(pointer_path):
		return ""
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(pointer_path))
	if not parsed is Dictionary:
		return ""
	var dir_path := String((parsed as Dictionary).get("dir", ""))
	if not dir_path.begins_with("user://"):
		return ""
	if not DirAccess.dir_exists_absolute(dir_path):
		return ""
	if not FileAccess.file_exists(dir_path.path_join("manifest.json")):
		return ""
	return dir_path


## 從 `--` 之後的使用者參數解析 `--content-dir=<abs path>`。
## 同時接受 `--content-dir <path>` 形式。找不到時回傳空字串。
static func content_dir_from_user_args(user_args: PackedStringArray) -> String:
	for i: int in user_args.size():
		var arg: String = user_args[i]
		if arg.begins_with("--content-dir="):
			return arg.substr("--content-dir=".length()).strip_edges()
		if arg == "--content-dir" and i + 1 < user_args.size():
			return user_args[i + 1].strip_edges()
	return ""


## 載入內容；回傳 true 代表無錯誤且至少有一張地圖可用。
## 失敗時 errors 內含可讀原因，warning 記錄非致命問題。
func load_content(dir_path: String) -> bool:
	_reset()
	content_dir = dir_path.strip_edges()
	if content_dir.is_empty():
		content_dir = "res://content"
	content_dir = content_dir.trim_suffix("/")

	var manifest_path: String = _join_path(content_dir, "manifest.json")
	if not FileAccess.file_exists(manifest_path):
		_error("E_NO_MANIFEST 找不到內容：%s 不存在（內容目錄：%s）" % [manifest_path, content_dir])
		return false

	var parsed: Variant = _read_json_file(manifest_path, "manifest")
	if not parsed is Dictionary:
		_error("E_MANIFEST_TYPE manifest.json 頂層必須是 JSON 物件")
		return false
	manifest = parsed as Dictionary

	var header_ok: bool = _validate_manifest_header()
	if not header_ok:
		# header 不可信時不再解析 files，避免產生誤導性錯誤。
		loaded = false
		return false

	var trusted_files: Array[Dictionary] = _validate_manifest_files()
	_parse_data_files(trusted_files)
	_validate_cross_references()
	_scan_unlisted_files()
	loaded = true
	return errors.is_empty() and not maps.is_empty()


# ---------------------------------------------------------------------------
# 公開查詢 API
# ---------------------------------------------------------------------------

func is_ok() -> bool:
	return loaded and errors.is_empty() and not maps.is_empty()


func get_map(map_id: String) -> Dictionary:
	return maps.get(map_id, {})


func get_region(region_id: String) -> Dictionary:
	return regions.get(region_id, {})


func get_npc(npc_id: String) -> Dictionary:
	return npcs.get(npc_id, {})


func get_item(item_id: String) -> Dictionary:
	return items.get(item_id, {})


func get_event(event_id: String) -> Dictionary:
	return events.get(event_id, {})


## 起始地圖：第一個 region 的 map_ids[0]；沒有 region 時取 map id 排序第一個。
## v0.1 的暫定規則（contract v1 沒有 start_map 欄位），已記錄於 CONTENT_CONTRACT.md。
func get_start_map_id() -> String:
	var region_ids: Array = regions.keys()
	region_ids.sort()
	for region_id: Variant in region_ids:
		var region: Dictionary = regions[region_id]
		var map_ids: Variant = region.get("map_ids", [])
		if map_ids is Array and not map_ids.is_empty():
			var candidate: String = String(map_ids[0])
			if maps.has(candidate):
				return candidate
	var map_ids_sorted: Array = maps.keys()
	map_ids_sorted.sort()
	if not map_ids_sorted.is_empty():
		return String(map_ids_sorted[0])
	return ""


## 給 HUD 的一行摘要。
func summary() -> String:
	if not is_ok():
		return "內容載入失敗（%d 個錯誤）" % errors.size()
	return "content %s v%s｜%d 地圖 / %d NPC / %d 物品 / %d 事件" % [
		content_id, content_version, maps.size(), npcs.size(), items.size(), events.size()
	]


func errors_text() -> String:
	if errors.is_empty():
		return ""
	var lines: PackedStringArray = PackedStringArray()
	for error_line: String in errors:
		lines.append("• " + error_line)
	return "\n".join(lines)


# ---------------------------------------------------------------------------
# manifest
# ---------------------------------------------------------------------------

func _validate_manifest_header() -> bool:
	var before: int = errors.size()
	content_id = _require_string(manifest, "content_id", "manifest", 1, 128)
	content_version = _require_string(manifest, "content_version", "manifest", 1, 64)
	min_game_version = _require_string(manifest, "min_game_version", "manifest", 1, 64)
	if not _is_int_like(manifest.get("manifest_schema", null)) or int(manifest.get("manifest_schema", -1)) != SUPPORTED_MANIFEST_SCHEMA:
		_error("E_MANIFEST_SCHEMA manifest_schema 必須為 %d" % SUPPORTED_MANIFEST_SCHEMA)
	if not _is_int_like(manifest.get("schema_version", null)) or int(manifest.get("schema_version", -1)) != SUPPORTED_CONTENT_SCHEMA:
		_error("E_CONTENT_SCHEMA manifest.schema_version 必須為 %d" % SUPPORTED_CONTENT_SCHEMA)
	var dependencies: Variant = manifest.get("dependencies", [])
	if not dependencies is Array:
		_error("E_MANIFEST_DEPS manifest.dependencies 必須是陣列")
	elif not (dependencies as Array).is_empty():
		_warn("W_MANIFEST_DEPS dependencies 非空，v0.1 尚未支援內容相依解析，已忽略")
	if not min_game_version.is_empty() and _version_greater_than(min_game_version, GAME_VERSION):
		_error("E_CONTENT_TOO_NEW 內容需要遊戲版本 >= %s，目前為 %s" % [min_game_version, GAME_VERSION])
	var files: Variant = manifest.get("files", [])
	if not files is Array:
		_error("E_MANIFEST_FILES manifest.files 必須是陣列")
	elif (files as Array).is_empty():
		_error("E_MANIFEST_FILES manifest.files 不可為空")
	elif (files as Array).size() > MAX_MANIFEST_FILES:
		_error("E_MANIFEST_FILES manifest.files 超過上限 %d" % MAX_MANIFEST_FILES)
	return errors.size() == before


func _validate_manifest_files() -> Array[Dictionary]:
	var trusted: Array[Dictionary] = []
	var files_variant: Variant = manifest.get("files", [])
	if not files_variant is Array:
		return trusted
	var seen_paths: Dictionary = {}
	var previous_path: String = ""
	for index: int in (files_variant as Array).size():
		var entry: Variant = (files_variant as Array)[index]
		var context: String = "manifest.files[%d]" % index
		if not entry is Dictionary:
			_error("E_MANIFEST_ENTRY %s 必須是物件" % context)
			continue
		var data: Dictionary = entry
		var path: String = _require_string(data, "path", context, 1, 256)
		if path.is_empty():
			continue
		var path_problem: String = _path_problem(path)
		if not path_problem.is_empty():
			_error("E_MANIFEST_PATH %s path '%s' 不合法：%s" % [context, path, path_problem])
			continue
		if not path.ends_with(".json"):
			_error("E_MANIFEST_PATH %s path '%s' 必須是 .json" % [context, path])
			continue
		if seen_paths.has(path):
			_error("E_MANIFEST_DUP %s path 重複：%s" % [context, path])
			continue
		seen_paths[path] = true
		if path <= previous_path:
			_error("E_MANIFEST_UNSORTED manifest.files 必須依 path 遞增排序（'%s' 在 '%s' 之後）" % [path, previous_path])
		previous_path = path

		var sha256: String = ""
		var sha_variant: Variant = data.get("sha256", null)
		if not sha_variant is String or not _is_sha256_hex(sha_variant):
			_error("E_MANIFEST_SHA %s sha256 必須是 64 位小寫十六進位字串" % context)
		else:
			sha256 = sha_variant
		var size: int = -1
		var size_variant: Variant = data.get("size", null)
		if not _is_int_like(size_variant):
			_error("E_MANIFEST_SIZE %s size 必須是整數" % context)
		elif int(size_variant) < 0 or int(size_variant) > MAX_FILE_BYTES:
			_error("E_MANIFEST_SIZE %s size 必須介於 0 與 %d" % [context, MAX_FILE_BYTES])
		else:
			size = int(size_variant)

		var full_path: String = _join_path(content_dir, path)
		if not FileAccess.file_exists(full_path):
			_error("E_FILE_MISSING %s 檔案不存在：%s" % [context, path])
			continue
		var entry_ok: bool = true
		var actual_size: int = _file_size(full_path)
		if size < 0 or actual_size != size:
			entry_ok = false
			_error("E_SIZE_MISMATCH %s 大小不符：manifest=%d 實際=%d" % [path, size, actual_size])
		if not sha256.is_empty():
			var actual_sha: String = _sha256_of_file(full_path)
			if actual_sha.is_empty():
				entry_ok = false
				_error("E_FILE_UNREADABLE %s 無法讀取" % path)
			elif actual_sha != sha256:
				entry_ok = false
				_error("E_HASH_MISMATCH %s sha256 不符：manifest=%s 實際=%s" % [path, sha256, actual_sha])
		else:
			entry_ok = false
		# 只有通過 path / size / sha256 驗證的檔案才允許進入解析階段。
		if entry_ok:
			trusted.append({"path": path, "full_path": full_path})
	_trusted_files = trusted
	return trusted


# ---------------------------------------------------------------------------
# 資料檔解析
# ---------------------------------------------------------------------------

func _parse_data_files(trusted_files: Array[Dictionary]) -> void:
	for entry: Dictionary in trusted_files:
		var path: String = String(entry.get("path", ""))
		var full_path: String = String(entry.get("full_path", ""))
		var data: Variant = _read_json_file(full_path, path)
		if not data is Dictionary:
			if data != null:
				_error("E_DATA_TYPE %s 頂層必須是 JSON 物件" % path)
			continue
		var json: Dictionary = data
		if not _is_int_like(json.get("schema_version", null)) or int(json.get("schema_version", -1)) != SUPPORTED_CONTENT_SCHEMA:
			_error("E_DATA_SCHEMA %s schema_version 必須為 %d" % [path, SUPPORTED_CONTENT_SCHEMA])
			continue

		if path.begins_with("world/maps/"):
			_parse_map(path, json)
		elif path.begins_with("world/regions/"):
			_parse_region(path, json)
		elif path.begins_with("characters/npcs/"):
			_parse_npc(path, json)
		elif path.begins_with("items/"):
			_parse_item(path, json)
		elif path.begins_with("events/"):
			_parse_event(path, json)
		else:
			_warn("W_UNKNOWN_FILE %s 不在已知目錄（world/maps、world/regions、characters/npcs、items、events），已忽略" % path)


func _parse_map(path: String, data: Dictionary) -> void:
	var before: int = errors.size()
	var map_data: Dictionary = {}
	map_data["id"] = _require_string(data, "id", path, 1, 128)
	map_data["name"] = _require_string(data, "name", path, 1, 128)
	var width: int = -1
	var height: int = -1
	var size_variant: Variant = data.get("size", null)
	if not size_variant is Dictionary:
		_error("E_MAP_SIZE %s size 必須是物件 {width,height}" % path)
	else:
		var size_data: Dictionary = size_variant
		width = _require_int(size_data, "width", path + ".size", 1, MAX_MAP_DIMENSION)
		height = _require_int(size_data, "height", path + ".size", 1, MAX_MAP_DIMENSION)
	var tile_size: int = _require_int(data, "tile_size", path, 1, 128)
	if tile_size < 0:
		tile_size = 0
	map_data["size"] = {"width": width, "height": height}
	map_data["tile_size"] = tile_size

	var tiles: Array = []
	var tiles_variant: Variant = data.get("tiles", null)
	if not tiles_variant is Array:
		_error("E_MAP_TILES %s tiles 必須是字串陣列" % path)
	else:
		tiles = tiles_variant
		if height >= 0 and tiles.size() != height:
			_error("E_MAP_TILES %s tiles 列數 %d 必須等於 height %d" % [path, tiles.size(), height])
		for row_index: int in tiles.size():
			if not tiles[row_index] is String:
				_error("E_MAP_TILES %s tiles[%d] 必須是字串" % [path, row_index])
				continue
			var row: String = tiles[row_index]
			if width >= 0 and row.length() != width:
				_error("E_MAP_TILES %s tiles[%d] 長度 %d 必須等於 width %d" % [path, row_index, row.length(), width])
	map_data["tiles"] = tiles

	var legend: Dictionary = {}
	var legend_variant: Variant = data.get("legend", null)
	if not legend_variant is Dictionary:
		_error("E_MAP_LEGEND %s legend 必須是物件" % path)
	else:
		for key: Variant in legend_variant:
			var tile_char: String = String(key)
			var context: String = "%s.legend['%s']" % [path, tile_char]
			if tile_char.length() != 1:
				_error("E_MAP_LEGEND %s key 必須是單一字元" % context)
				continue
			var entry: Variant = legend_variant[key]
			if not entry is Dictionary:
				_error("E_MAP_LEGEND %s 必須是物件 {tile,walkable}" % context)
				continue
			var entry_data: Dictionary = entry
			var tile_name: String = _require_string(entry_data, "tile", context, 1, 32)
			var walkable_ok: bool = (entry_data.get("walkable", null) is bool)
			if not walkable_ok:
				_error("E_MAP_LEGEND %s walkable 必須是布林值" % context)
			legend[tile_char] = {"tile": tile_name, "walkable": bool(entry_data.get("walkable", false))}
	map_data["legend"] = legend

	# legend 必須覆蓋所有用到的 tile 字元。
	var used_chars: Dictionary = {}
	for row: Variant in tiles:
		if not row is String:
			continue
		for char_index: int in (row as String).length():
			used_chars[(row as String)[char_index]] = true
	for tile_char: Variant in used_chars:
		if not legend.has(tile_char):
			_error("E_MAP_LEGEND %s legend 缺少 tiles 使用的字元 '%s'" % [path, tile_char])
	for legend_char: Variant in legend:
		if not used_chars.has(legend_char):
			_warn("W_MAP_LEGEND_UNUSED %s legend 字元 '%s' 未被 tiles 使用" % [path, legend_char])

	# spawn：必須在範圍內且可通行。
	var spawn_cell: Vector2i = Vector2i(-1, -1)
	var spawn_variant: Variant = data.get("spawn", null)
	if not spawn_variant is Dictionary:
		_error("E_MAP_SPAWN %s spawn 必須是物件 {grid:[x,y]}" % path)
	else:
		spawn_cell = _parse_cell(spawn_variant.get("grid", null), path + ".spawn", "grid")
		if not _cell_in_bounds(spawn_cell, width, height):
			_error("E_MAP_SPAWN %s spawn.grid %s 超出地圖範圍 %dx%d" % [path, str(spawn_cell), width, height])
		elif not _walkable_in(tiles, legend, spawn_cell):
			_error("E_MAP_SPAWN %s spawn.grid %s 必須是可通行格" % [path, str(spawn_cell)])
	map_data["spawn"] = {"grid": [spawn_cell.x, spawn_cell.y]}

	# entities
	var entities: Array = []
	var entities_variant: Variant = data.get("entities", [])
	if not entities_variant is Array:
		_error("E_MAP_ENTITIES %s entities 必須是陣列" % path)
	elif (entities_variant as Array).size() > MAX_ENTITIES_PER_MAP:
		_error("E_MAP_ENTITIES %s entities 超過上限 %d" % [path, MAX_ENTITIES_PER_MAP])
	else:
		var seen_entity_ids: Dictionary = {}
		for index: int in (entities_variant as Array).size():
			var context: String = "%s.entities[%d]" % [path, index]
			var raw_entity: Variant = (entities_variant as Array)[index]
			if not raw_entity is Dictionary:
				_error("E_MAP_ENTITY %s 必須是物件" % context)
				continue
			var entity_data: Dictionary = raw_entity
			var entity: Dictionary = _parse_entity(entity_data, context, tiles, legend, width, height)
			if entity.is_empty():
				continue
			var entity_id: String = String(entity.get("id", ""))
			if seen_entity_ids.has(entity_id):
				_error("E_MAP_ENTITY_DUP %s entity id 重複：%s" % [context, entity_id])
				continue
			seen_entity_ids[entity_id] = true
			entities.append(entity)
	map_data["entities"] = entities

	# portals
	var portals: Array = []
	var portals_variant: Variant = data.get("portals", [])
	if not portals_variant is Array:
		_error("E_MAP_PORTALS %s portals 必須是陣列" % path)
	elif (portals_variant as Array).size() > MAX_PORTALS_PER_MAP:
		_error("E_MAP_PORTALS %s portals 超過上限 %d" % [path, MAX_PORTALS_PER_MAP])
	else:
		var seen_portal_ids: Dictionary = {}
		for index: int in (portals_variant as Array).size():
			var context: String = "%s.portals[%d]" % [path, index]
			var raw_portal: Variant = (portals_variant as Array)[index]
			if not raw_portal is Dictionary:
				_error("E_MAP_PORTAL %s 必須是物件" % context)
				continue
			var portal_data: Dictionary = raw_portal
			var portal: Dictionary = _parse_portal(portal_data, context, tiles, legend, width, height)
			if portal.is_empty():
				continue
			var portal_id: String = String(portal.get("id", ""))
			if seen_portal_ids.has(portal_id):
				_error("E_MAP_PORTAL_DUP %s portal id 重複：%s" % [context, portal_id])
				continue
			seen_portal_ids[portal_id] = true
			portals.append(portal)
	map_data["portals"] = portals

	if errors.size() > before:
		return
	var map_id: String = String(map_data["id"])
	if maps.has(map_id):
		_error("E_DUP_MAP_ID %s 地圖 id 重複：%s" % [path, map_id])
		return
	maps[map_id] = map_data


func _parse_entity(data: Dictionary, context: String, tiles: Array, legend: Dictionary, width: int, height: int) -> Dictionary:
	var out: Dictionary = {}
	out["id"] = _require_string(data, "id", context, 1, 128)
	out["type"] = _require_string(data, "type", context, 1, 16)
	if not (out["type"] as String).is_empty() and not ALLOWED_ENTITY_TYPES.has(out["type"]):
		_error("E_MAP_ENTITY %s type '%s' 不支援（允許：%s）" % [context, out["type"], str(ALLOWED_ENTITY_TYPES)])
	out["display_key"] = _require_string(data, "display_key", context, 1, 64)
	var cell: Vector2i = _parse_cell(data.get("grid", null), context, "grid")
	if not _cell_in_bounds(cell, width, height):
		_error("E_MAP_ENTITY %s grid %s 超出地圖範圍 %dx%d" % [context, str(cell), width, height])
	elif not _walkable_in(tiles, legend, cell):
		_error("E_MAP_ENTITY %s grid %s 必須是可通行格（實體站在可通行地形上）" % [context, str(cell)])
	out["grid"] = [cell.x, cell.y]
	var interaction: Variant = data.get("interaction", null)
	if not interaction is Dictionary:
		_error("E_MAP_ENTITY %s interaction 必須是物件" % context)
	else:
		var interaction_data: Dictionary = interaction
		var kind: String = _require_string(interaction_data, "kind", context + ".interaction", 1, 32)
		if not kind.is_empty() and kind != "event":
			_error("E_MAP_ENTITY %s interaction.kind '%s' 不支援（v0.1 僅 event）" % [context, kind])
		var event_id: String = _require_string(interaction_data, "event_id", context + ".interaction", 1, 128)
		out["interaction"] = {"kind": "event", "event_id": event_id}
	if out["id"].is_empty() or out["display_key"].is_empty():
		return {}
	return out


func _parse_portal(data: Dictionary, context: String, tiles: Array, legend: Dictionary, width: int, height: int) -> Dictionary:
	var out: Dictionary = {}
	out["id"] = _require_string(data, "id", context, 1, 128)
	var cell: Vector2i = _parse_cell(data.get("grid", null), context, "grid")
	if not _cell_in_bounds(cell, width, height):
		_error("E_MAP_PORTAL %s grid %s 超出地圖範圍 %dx%d" % [context, str(cell), width, height])
	elif not _walkable_in(tiles, legend, cell):
		_error("E_MAP_PORTAL %s grid %s 必須是可通行格" % [context, str(cell)])
	out["grid"] = [cell.x, cell.y]
	out["target_map_id"] = _require_string(data, "target_map_id", context, 1, 128)
	var target_cell: Vector2i = _parse_cell(data.get("target_grid", null), context, "target_grid")
	out["target_grid"] = [target_cell.x, target_cell.y]
	if out["id"].is_empty() or out["target_map_id"].is_empty():
		return {}
	return out


func _parse_region(path: String, data: Dictionary) -> void:
	var before: int = errors.size()
	var out: Dictionary = {}
	out["id"] = _require_string(data, "id", path, 1, 128)
	out["name"] = _require_string(data, "name", path, 1, 128)
	out["notes"] = _optional_string(data, "notes", path, 2048)
	var map_ids: Array[String] = []
	var raw_map_ids: Variant = data.get("map_ids", null)
	if not raw_map_ids is Array:
		_error("E_REGION %s map_ids 必須是陣列" % path)
	elif (raw_map_ids as Array).is_empty():
		_error("E_REGION %s map_ids 不可為空" % path)
	else:
		for index: int in (raw_map_ids as Array).size():
			var map_id: Variant = (raw_map_ids as Array)[index]
			if not map_id is String or (map_id as String).is_empty():
				_error("E_REGION %s map_ids[%d] 必須是非空字串" % [path, index])
				continue
			map_ids.append(map_id)
	out["map_ids"] = map_ids
	if errors.size() > before:
		return
	var region_id: String = String(out["id"])
	if regions.has(region_id):
		_error("E_DUP_REGION_ID %s region id 重複：%s" % [path, region_id])
		return
	regions[region_id] = out


func _parse_npc(path: String, data: Dictionary) -> void:
	var before: int = errors.size()
	var out: Dictionary = {}
	out["id"] = _require_string(data, "id", path, 1, 128)
	out["name"] = _require_string(data, "name", path, 1, 128)
	out["role"] = _optional_string(data, "role", path, 64)
	out["short_description"] = _optional_string(data, "short_description", path, 1024)
	out["speech_style"] = _optional_string(data, "speech_style", path, 512)
	var is_adult: Variant = data.get("is_adult", null)
	if not is_adult is bool:
		_warn("W_NPC_IS_ADULT %s 缺少 is_adult 布林值（成人內容模組需要此欄位）" % path)
	else:
		out["is_adult"] = is_adult
	if errors.size() > before:
		return
	var npc_id: String = String(out["id"])
	if npcs.has(npc_id):
		_error("E_DUP_NPC_ID %s npc id 重複：%s" % [path, npc_id])
		return
	npcs[npc_id] = out


func _parse_item(path: String, data: Dictionary) -> void:
	var before: int = errors.size()
	var out: Dictionary = {}
	out["id"] = _require_string(data, "id", path, 1, 128)
	out["name"] = _require_string(data, "name", path, 1, 128)
	out["category"] = _require_string(data, "category", path, 1, 64)
	out["description"] = _optional_string(data, "description", path, 2048)
	out["stack_limit"] = _require_int(data, "stack_limit", path, 1, 9999)
	if errors.size() > before:
		return
	var item_id: String = String(out["id"])
	if items.has(item_id):
		_error("E_DUP_ITEM_ID %s item id 重複：%s" % [path, item_id])
		return
	items[item_id] = out


func _parse_event(path: String, data: Dictionary) -> void:
	var before: int = errors.size()
	var out: Dictionary = {}
	out["id"] = _require_string(data, "id", path, 1, 128)
	var kind: String = _require_string(data, "kind", path, 1, 32)
	if not kind.is_empty() and not ALLOWED_EVENT_KINDS.has(kind):
		_error("E_EVENT_KIND %s kind '%s' 不支援（v0.1 僅 dialogue）" % [path, kind])
	out["kind"] = "dialogue"
	var repeatable: Variant = data.get("repeatable", null)
	if not repeatable is bool:
		_warn("W_EVENT_REPEATABLE %s 缺少 repeatable 布林值，預設 true" % path)
	out["repeatable"] = bool(repeatable) if repeatable is bool else true
	out["trigger"] = _parse_event_trigger(data.get("trigger", null), path)
	out["lines"] = _parse_event_lines(data.get("lines", null), path)
	out["choices"] = _parse_event_choices(data.get("choices", null), path)
	if errors.size() > before:
		return
	var event_id: String = String(out["id"])
	if events.has(event_id):
		_error("E_DUP_EVENT_ID %s event id 重複：%s" % [path, event_id])
		return
	events[event_id] = out


func _parse_event_trigger(value: Variant, path: String) -> Dictionary:
	var out: Dictionary = {"map_id": "", "entity_id": ""}
	if not value is Dictionary:
		_error("E_EVENT_TRIGGER %s trigger 必須是物件 {map_id,entity_id}" % path)
		return out
	var trigger_data: Dictionary = value
	out["map_id"] = _require_string(trigger_data, "map_id", path + ".trigger", 1, 128)
	out["entity_id"] = _require_string(trigger_data, "entity_id", path + ".trigger", 1, 128)
	return out


func _parse_event_lines(value: Variant, path: String) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	if not value is Array:
		_error("E_EVENT_LINES %s lines 必須是陣列" % path)
		return lines
	if (value as Array).is_empty():
		_error("E_EVENT_LINES %s lines 不可為空" % path)
		return lines
	if (value as Array).size() > MAX_DIALOGUE_LINES:
		_error("E_EVENT_LINES %s lines 超過上限 %d" % [path, MAX_DIALOGUE_LINES])
		return lines
	for index: int in (value as Array).size():
		var context: String = "%s.lines[%d]" % [path, index]
		var raw: Variant = (value as Array)[index]
		if not raw is Dictionary:
			_error("E_EVENT_LINE %s 必須是物件 {speaker_id,text}" % context)
			continue
		var line_data: Dictionary = raw
		var speaker_id: String = _require_string(line_data, "speaker_id", context, 1, 128)
		var text: String = _require_string(line_data, "text", context, 1, 500)
		if speaker_id.is_empty() or text.is_empty():
			continue
		lines.append({"speaker_id": speaker_id, "text": text})
	return lines


func _parse_event_choices(value: Variant, path: String) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	if value == null:
		return choices
	if not value is Array:
		_error("E_EVENT_CHOICES %s choices 必須是陣列" % path)
		return choices
	if (value as Array).size() > MAX_CHOICES:
		_error("E_EVENT_CHOICES %s choices 超過上限 %d" % [path, MAX_CHOICES])
		return choices
	var seen_ids: Dictionary = {}
	for index: int in (value as Array).size():
		var context: String = "%s.choices[%d]" % [path, index]
		var raw: Variant = (value as Array)[index]
		if not raw is Dictionary:
			_error("E_EVENT_CHOICE %s 必須是物件 {id,text,effects}" % context)
			continue
		var choice_data: Dictionary = raw
		var choice_id: String = _require_string(choice_data, "id", context, 1, 64)
		var text: String = _require_string(choice_data, "text", context, 1, 200)
		if not choice_id.is_empty():
			if seen_ids.has(choice_id):
				_error("E_EVENT_CHOICE_DUP %s choice id 重複：%s" % [context, choice_id])
			seen_ids[choice_id] = true
		var effects: Array[Dictionary] = _parse_effects(choice_data.get("effects", []), context)
		if choice_id.is_empty() or text.is_empty():
			continue
		choices.append({"id": choice_id, "text": text, "effects": effects})
	return choices


## 驗證 effects 的結構與參數型別（不檢查 item 是否存在，那屬於跨檔引用階段）。
## 未知 type 或參數錯誤 → 該事件載入失敗（errors 增加，上層不儲存事件）。

func _parse_effects(value: Variant, context: String) -> Array[Dictionary]:
	var effects: Array[Dictionary] = []
	if not value is Array:
		_error("E_EFFECTS %s effects 必須是陣列" % context)
		return effects
	for index: int in (value as Array).size():
		var effect_context: String = "%s.effects[%d]" % [context, index]
		var raw: Variant = (value as Array)[index]
		if not raw is Dictionary:
			_error("E_EFFECT %s 必須是物件 {type,...}" % effect_context)
			continue
		var effect_data: Dictionary = raw
		var effect_type: String = _require_string(effect_data, "type", effect_context, 1, 32)
		if effect_type.is_empty():
			continue
		if not ALLOWED_EFFECT_TYPES.has(effect_type):
			_error("E_EFFECT_UNKNOWN %s 未知 effect type '%s'（v0.1 僅支援 %s）" % [effect_context, effect_type, str(ALLOWED_EFFECT_TYPES)])
			continue
		var allowed_keys: Array[String] = ["type"]
		if effect_type == "set_flag":
			allowed_keys.append_array(["flag", "value"])
			var flag: String = _require_string(effect_data, "flag", effect_context, 1, MAX_FLAG_NAME_LENGTH)
			if not flag.is_empty() and not _is_flag_name(flag):
				_error("E_EFFECT_PARAM %s flag '%s' 只能使用小寫字母、數字與底線" % [effect_context, flag])
			if not effect_data.get("value", null) is bool:
				_error("E_EFFECT_PARAM %s value 必須是布林值" % effect_context)
			if not flag.is_empty():
				effects.append({"type": "set_flag", "flag": flag, "value": bool(effect_data.get("value", false))})
		elif effect_type == "give_item":
			allowed_keys.append_array(["item_id", "qty"])
			var item_id: String = _require_string(effect_data, "item_id", effect_context, 1, 128)
			var qty: int = _require_int(effect_data, "qty", effect_context, 1, 9999)
			if not item_id.is_empty() and qty > 0:
				effects.append({"type": "give_item", "item_id": item_id, "qty": qty})
		for key: Variant in effect_data:
			if not allowed_keys.has(String(key)):
				_warn("W_EFFECT_EXTRA %s 未知欄位 '%s' 已忽略" % [effect_context, key])
	return effects

func _validate_cross_references() -> void:
	if maps.is_empty():
		_error("E_NO_MAPS 內容沒有任何地圖（world/maps/*.json）")
	# 地圖 portal 目標與 entity -> event 引用
	for map_id: Variant in maps:
		var map: Dictionary = maps[map_id]
		var width: int = int(map.get("size", {}).get("width", 0))
		var height: int = int(map.get("size", {}).get("height", 0))
		for entity: Dictionary in map.get("entities", []):
			var interaction: Dictionary = entity.get("interaction", {})
			var event_id: String = String(interaction.get("event_id", ""))
			if not event_id.is_empty() and not events.has(event_id):
				_error("E_MISSING_EVENT_REF map %s entity %s 引用不存在的 event_id：%s" % [map_id, entity.get("id", "?"), event_id])
			if String(entity.get("type", "")) == "npc" and not npcs.has(String(entity.get("id", ""))):
				_warn("W_NPC_ENTITY_NO_RECORD map %s 的 NPC 實體 %s 在 characters/npcs/ 沒有對應檔案" % [map_id, entity.get("id", "?")])
		for portal: Dictionary in map.get("portals", []):
			var target_map_id: String = String(portal.get("target_map_id", ""))
			if not maps.has(target_map_id):
				_error("E_MISSING_MAP_REF map %s portal %s 引用不存在的 target_map_id：%s" % [map_id, portal.get("id", "?"), target_map_id])
				continue
			var target_map: Dictionary = maps[target_map_id]
			var target_width: int = int(target_map.get("size", {}).get("width", 0))
			var target_height: int = int(target_map.get("size", {}).get("height", 0))
			var target_cell: Vector2i = _cell_from_raw(portal.get("target_grid", []))
			if not _cell_in_bounds(target_cell, target_width, target_height):
				_error("E_MAP_PORTAL_TARGET map %s portal %s target_grid %s 超出目標地圖 %s 範圍 %dx%d" % [
					map_id, portal.get("id", "?"), str(target_cell), target_map_id, target_width, target_height
				])
			elif not _walkable_in(target_map.get("tiles", []), target_map.get("legend", {}), target_cell):
				_error("E_MAP_PORTAL_TARGET map %s portal %s target_grid %s 在目標地圖 %s 不是可通行格" % [
					map_id, portal.get("id", "?"), str(target_cell), target_map_id
				])
	# region -> map 引用
	for region_id: Variant in regions:
		var region: Dictionary = regions[region_id]
		for map_id: Variant in region.get("map_ids", []):
			if not maps.has(String(map_id)):
				_error("E_MISSING_MAP_REF region %s 引用不存在的 map_id：%s" % [region_id, map_id])
	# event -> map / entity / npc / item 引用
	for event_id: Variant in events:
		var event: Dictionary = events[event_id]
		var trigger: Dictionary = event.get("trigger", {})
		var trigger_map_id: String = String(trigger.get("map_id", ""))
		var trigger_entity_id: String = String(trigger.get("entity_id", ""))
		if not maps.has(trigger_map_id):
			_error("E_MISSING_MAP_REF event %s trigger 引用不存在的 map_id：%s" % [event_id, trigger_map_id])
		else:
			var entity: Dictionary = _find_entity(maps[trigger_map_id], trigger_entity_id)
			if entity.is_empty():
				_error("E_MISSING_ENTITY_REF event %s trigger 引用不存在的 entity_id：%s（地圖 %s）" % [event_id, trigger_entity_id, trigger_map_id])
			else:
				var linked_event_id: String = String(entity.get("interaction", {}).get("event_id", ""))
				if linked_event_id != String(event_id):
					_error("E_EVENT_TRIGGER_MISMATCH event %s 的 trigger 指向 entity %s，但該 entity 的 interaction.event_id 是 '%s'" % [
						event_id, trigger_entity_id, linked_event_id
					])
		for line: Dictionary in event.get("lines", []):
			var speaker_id: String = String(line.get("speaker_id", ""))
			if speaker_id != "player" and not npcs.has(speaker_id):
				_error("E_MISSING_NPC_REF event %s 的 speaker_id 不存在：%s（允許 NPC id 或 \"player\"）" % [event_id, speaker_id])
		for choice: Dictionary in event.get("choices", []):
			for effect: Dictionary in choice.get("effects", []):
				if String(effect.get("type", "")) == "give_item":
					var item_id: String = String(effect.get("item_id", ""))
					if not items.has(item_id):
						_error("E_MISSING_ITEM_REF event %s choice %s 引用不存在的 item_id：%s" % [
							event_id, choice.get("id", "?"), item_id
						])


func _find_entity(map: Dictionary, entity_id: String) -> Dictionary:
	for entity: Dictionary in map.get("entities", []):
		if String(entity.get("id", "")) == entity_id:
			return entity
	return {}


# ---------------------------------------------------------------------------
# 未列於 manifest 的檔案掃描（僅警告）
# ---------------------------------------------------------------------------

func _scan_unlisted_files() -> void:
	var listed: Dictionary = {}
	for entry: Dictionary in _trusted_files:
		listed[String(entry.get("path", ""))] = true
	var found: Array[String] = []
	_collect_json_files(content_dir, "", found, 0)
	for relative_path: String in found:
		if listed.has(relative_path):
			continue
		if relative_path == "manifest.json":
			continue
		# 建置快照的來源中繼資料（tools/sync_content_bundle.mjs 產生），不是內容檔。
		if relative_path == "BUNDLE_SOURCE.json":
			continue
		_warn("W_UNLISTED_FILE %s 未列於 manifest.files，已忽略" % relative_path)


func _collect_json_files(base_dir: String, prefix: String, found: Array[String], depth: int) -> void:
	if depth > 8:
		return
	var dir_path: String = _join_path(base_dir, prefix) if not prefix.is_empty() else base_dir
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		if file_name.ends_with(".json"):
			found.append(_join_path(prefix, file_name) if not prefix.is_empty() else file_name)
	for sub_dir: String in dir.get_directories():
		if sub_dir.begins_with(".") or sub_dir in ["schemas", "docs"]:
			continue
		var new_prefix: String = _join_path(prefix, sub_dir) if not prefix.is_empty() else sub_dir
		_collect_json_files(base_dir, new_prefix, found, depth + 1)


# ---------------------------------------------------------------------------
# 檔案 / JSON / 雜湊工具
# ---------------------------------------------------------------------------

## 要求欄位存在且為字串；失敗記錯誤並回傳空字串。
func _require_string(data: Dictionary, key: String, context: String, min_length: int, max_length: int) -> String:
	var value: Variant = data.get(key, null)
	if not value is String:
		_error("E_FIELD %s.%s 必須是字串" % [context, key])
		return ""
	var text: String = value
	if text.length() < min_length or text.length() > max_length:
		_error("E_FIELD %s.%s 長度必須介於 %d 與 %d" % [context, key, min_length, max_length])
		return ""
	return text


## 要求欄位存在且為整數（JSON 可能給 float）；失敗回傳 -1。
func _require_int(data: Dictionary, key: String, context: String, min_value: int, max_value: int) -> int:
	var value: Variant = data.get(key, null)
	if not _is_int_like(value):
		_error("E_FIELD %s.%s 必須是整數" % [context, key])
		return -1
	var number: int = int(value)
	if number < min_value or number > max_value:
		_error("E_FIELD %s.%s 必須介於 %d 與 %d" % [context, key, min_value, max_value])
		return -1
	return number


## 選填字串欄位；缺少或 null 時回傳空字串，型別錯誤記錯誤。
func _optional_string(data: Dictionary, key: String, context: String, max_length: int) -> String:
	var value: Variant = data.get(key, null)
	if value == null:
		return ""
	if not value is String:
		_error("E_FIELD %s.%s 必須是字串" % [context, key])
		return ""
	var text: String = value
	if text.length() > max_length:
		_error("E_FIELD %s.%s 長度不可超過 %d" % [context, key, max_length])
		return ""
	return text


## 讀取並解析 JSON；失敗時記錯誤並回傳 null。
func _read_json_file(path: String, display_path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_error("E_FILE_UNREADABLE 無法讀取 %s（Godot 錯誤碼 %d）" % [display_path, FileAccess.get_open_error()])
		return null
	var text: String = file.get_as_text()
	file.close()
	if text.strip_edges().is_empty():
		_error("E_JSON_EMPTY %s 是空檔案" % display_path)
		return null
	var json := JSON.new()
	var parse_error: int = json.parse(text)
	if parse_error != OK:
		_error("E_JSON_PARSE %s 第 %d 行：%s" % [display_path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


func _sha256_of_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		file.close()
		return ""
	while not file.eof_reached():
		var chunk: PackedByteArray = file.get_buffer(65536)
		if chunk.is_empty():
			break
		context.update(chunk)
	file.close()
	return context.finish().hex_encode()


func _file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var size: int = file.get_length()
	file.close()
	return size


## 檢查 manifest 內的相對路徑是否安全（禁止絕對路徑與 ..）。
func _path_problem(path: String) -> String:
	if path.is_empty():
		return "空路徑"
	if path.begins_with("/") or path.begins_with("\\"):
		return "不可為絕對路徑"
	if path.contains("\\"):
		return "路徑分隔必須使用 '/'"
	if path.contains(":"):
		return "不可包含磁碟機代號或冒號"
	for segment: String in path.split("/"):
		if segment == "..":
			return "不可包含 '..'"
		if segment == ".":
			return "不可包含 '.' 路徑段"
		if segment.is_empty():
			return "不可包含空路徑段"
	return ""


static func _join_path(base: String, relative: String) -> String:
	if base.ends_with("/"):
		return base + relative
	return base + "/" + relative


static func _is_sha256_hex(value: Variant) -> bool:
	if not value is String:
		return false
	var text: String = value
	if text.length() != 64:
		return false
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		var is_digit: bool = code >= 48 and code <= 57
		var is_lower_hex: bool = code >= 97 and code <= 102
		if not is_digit and not is_lower_hex:
			return false
	return true


static func _is_flag_name(value: String) -> bool:
	if value.is_empty() or value.length() > MAX_FLAG_NAME_LENGTH:
		return false
	for index: int in value.length():
		var code: int = value.unicode_at(index)
		var is_lower: bool = code >= 97 and code <= 122
		var is_digit: bool = code >= 48 and code <= 57
		if not is_lower and not is_digit and code != 95:
			return false
	return true


## JSON 數字可能被解析為 int 或 float；兩者都接受，但值必須是整數。
static func _is_int_like(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		return is_equal_approx(value, floorf(value))
	return false


static func _cell_from_raw(value: Variant) -> Vector2i:
	if value is Array and (value as Array).size() == 2:
		return Vector2i(int((value as Array)[0]), int((value as Array)[1]))
	return Vector2i(-1, -1)


func _parse_cell(value: Variant, context: String, field_name: String) -> Vector2i:
	if not value is Array or (value as Array).size() != 2:
		_error("E_CELL %s %s 必須是 [x,y] 兩個整數" % [context, field_name])
		return Vector2i(-1, -1)
	var raw: Array = value
	if not _is_int_like(raw[0]) or not _is_int_like(raw[1]):
		_error("E_CELL %s %s 的 x,y 必須是整數" % [context, field_name])
		return Vector2i(-1, -1)
	return Vector2i(int(raw[0]), int(raw[1]))


static func _cell_in_bounds(cell: Vector2i, width: int, height: int) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


## 依 tiles + legend 判斷某格是否可通行（不依賴 MapGrid）。
static func _walkable_in(tiles: Array, legend: Dictionary, cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= tiles.size():
		return false
	var row: Variant = tiles[cell.y]
	if not row is String:
		return false
	var text: String = row
	if cell.x < 0 or cell.x >= text.length():
		return false
	var tile_char: String = text[cell.x]
	var entry: Variant = legend.get(tile_char, null)
	if not entry is Dictionary:
		return false
	return bool((entry as Dictionary).get("walkable", false))


# ---------------------------------------------------------------------------
# 版本比較
# ---------------------------------------------------------------------------

## a 是否比 b 新（以 major.minor.patch 比較，忽略 prerelease）。
static func _version_greater_than(a: String, b: String) -> bool:
	var left: PackedInt32Array = _version_parts(a)
	var right: PackedInt32Array = _version_parts(b)
	for index: int in 3:
		if left[index] != right[index]:
			return left[index] > right[index]
	return false


static func _version_parts(value: String) -> PackedInt32Array:
	var parts: PackedInt32Array = PackedInt32Array([0, 0, 0])
	var core: String = value.split("-")[0]
	var pieces: PackedStringArray = core.split(".")
	for index: int in mini(3, pieces.size()):
		parts[index] = int(pieces[index])
	return parts


# ---------------------------------------------------------------------------
# 訊息 / 狀態
# ---------------------------------------------------------------------------

func _error(message: String) -> void:
	errors.append(message)


func _warn(message: String) -> void:
	warnings.append(message)


func _reset() -> void:
	content_dir = ""
	content_id = ""
	content_version = ""
	min_game_version = ""
	manifest = {}
	_trusted_files = []
	maps = {}
	regions = {}
	npcs = {}
	items = {}
	events = {}
	errors = []
	warnings = []
	loaded = false


# 通過 path / size / sha256 驗證的檔案（供未列檔掃描比對）。
var _trusted_files: Array[Dictionary] = []
