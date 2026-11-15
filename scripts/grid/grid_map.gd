class_name MapGrid
extends RefCounted
## 格子地圖的執行期表示：座標、可通行、實體佔用與 portal 查找。
##
## 座標語義：Vector2i(x, y)，x 向右、y 向下，原點 (0,0) 為左上角。
## 一個格子對應 tile_size x tile_size 像素；cell_center_world() 回傳格子中心的世界座標。
## 本類別只處理已通過 ContentRepository 驗證的地圖資料，仍做防禦性邊界檢查。

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var map_id: String = ""
var display_name: String = ""
var width: int = 0
var height: int = 0
var tile_size: int = 16
var tiles: PackedStringArray = PackedStringArray()
var legend: Dictionary = {}
var spawn: Vector2i = Vector2i.ZERO
var entities: Array[Dictionary] = []
var portals: Array[Dictionary] = []


## 由 ContentRepository 驗證過的地圖資料建立執行期格子。
## 資料結構見 docs/architecture/CONTENT_CONTRACT.md。
static func from_map_data(data: Dictionary) -> MapGrid:
	var grid := MapGrid.new()
	grid.map_id = String(data.get("id", ""))
	grid.display_name = String(data.get("name", ""))
	var size_data: Variant = data.get("size", {})
	if size_data is Dictionary:
		grid.width = int(size_data.get("width", 0))
		grid.height = int(size_data.get("height", 0))
	grid.tile_size = maxi(1, int(data.get("tile_size", 16)))
	grid.tiles = PackedStringArray()
	var raw_tiles: Variant = data.get("tiles", [])
	if raw_tiles is Array:
		for row: Variant in raw_tiles:
			grid.tiles.append(String(row))
	grid.legend = {}
	var raw_legend: Variant = data.get("legend", {})
	if raw_legend is Dictionary:
		for key: Variant in raw_legend:
			grid.legend[String(key)] = raw_legend[key]
	var raw_spawn: Variant = data.get("spawn", {})
	if raw_spawn is Dictionary:
		var raw_grid: Variant = raw_spawn.get("grid", [])
		if raw_grid is Array and raw_grid.size() == 2:
			grid.spawn = Vector2i(int(raw_grid[0]), int(raw_grid[1]))
	grid.entities.clear()
	var raw_entities: Variant = data.get("entities", [])
	if raw_entities is Array:
		for entity: Variant in raw_entities:
			if entity is Dictionary:
				grid.entities.append(_normalise_entity(entity))
	grid.portals.clear()
	var raw_portals: Variant = data.get("portals", [])
	if raw_portals is Array:
		for portal: Variant in raw_portals:
			if portal is Dictionary:
				grid.portals.append(_normalise_portal(portal))
	return grid


static func _normalise_entity(data: Dictionary) -> Dictionary:
	var result: Dictionary = data.duplicate(true)
	var raw_grid: Variant = data.get("grid", [])
	result["grid"] = _to_cell(raw_grid)
	return result


static func _normalise_portal(data: Dictionary) -> Dictionary:
	var result: Dictionary = data.duplicate(true)
	result["grid"] = _to_cell(data.get("grid", []))
	result["target_grid"] = _to_cell(data.get("target_grid", []))
	return result


static func _to_cell(value: Variant) -> Vector2i:
	if value is Array and value.size() == 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


## 回傳格子的地圖字元；越界時回傳空字串。
func tile_char_at(cell: Vector2i) -> String:
	if not in_bounds(cell):
		return ""
	if cell.y >= tiles.size():
		return ""
	var row: String = tiles[cell.y]
	if cell.x >= row.length():
		return ""
	return row[cell.x]


## 回傳 legend 中定義的 tile 名稱（例如 grass / wall）；未知字元回傳空字串。
func tile_type_at(cell: Vector2i) -> String:
	var tile_char: String = tile_char_at(cell)
	var entry: Variant = legend.get(tile_char, null)
	if entry is Dictionary:
		return String(entry.get("tile", ""))
	return ""


## 地形是否可通行（只看地形，不看實體佔用）。
func is_walkable(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return false
	var tile_char: String = tile_char_at(cell)
	var entry: Variant = legend.get(tile_char, null)
	if entry is Dictionary:
		return bool(entry.get("walkable", false))
	return false


## 該格上的實體（NPC／物件）；沒有則回傳空字典。
func entity_at(cell: Vector2i) -> Dictionary:
	for entity: Dictionary in entities:
		if entity.get("grid", Vector2i(-999, -999)) == cell:
			return entity
	return {}


func has_entity(cell: Vector2i) -> bool:
	return not entity_at(cell).is_empty()


## 玩家是否可以進入該格：在範圍內、地形可通行、沒有實體佔用。
func can_enter(cell: Vector2i) -> bool:
	return is_walkable(cell) and not has_entity(cell)


func portal_at(cell: Vector2i) -> Dictionary:
	for portal: Dictionary in portals:
		if portal.get("grid", Vector2i(-999, -999)) == cell:
			return portal
	return {}


## 格子中心的世界座標（像素）。
func cell_center_world(cell: Vector2i) -> Vector2:
	return Vector2(
		(cell.x * tile_size) + (tile_size / 2.0),
		(cell.y * tile_size) + (tile_size / 2.0)
	)


## 回傳相鄰格；越界仍回傳座標（呼叫端用 in_bounds 檢查）。
static func neighbour(cell: Vector2i, direction: Vector2i) -> Vector2i:
	return cell + direction


## 回傳以 center 為中心、radius 格的方形範圍內可互動實體（v0.1 僅使用面向格）。
func entities_in_bounds(min_cell: Vector2i, max_cell: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entity: Dictionary in entities:
		var cell: Vector2i = entity.get("grid", Vector2i.ZERO)
		if cell.x >= min_cell.x and cell.y >= min_cell.y and cell.x <= max_cell.x and cell.y <= max_cell.y:
			result.append(entity)
	return result
