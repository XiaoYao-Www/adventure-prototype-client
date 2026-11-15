class_name WorldView
extends Node2D
## 世界畫面：以 _draw 繪製格子與實體（v0.1 刻意不用 TileMapLayer）。
##
## v0.1 使用 16x16 placeholder atlas（橫向 8 格）：
## 0=grass, 1=path, 2=wall, 3=water, 4=tree, 5=npc, 6=chest, 7=player。
## atlas 或 placeholder_tiles.json 缺少時，退回色塊並記錄警告，不崩潰。
##
## 之後若要換成 TileMapLayer，只需替換本類別的绘制實作，不動遊戲邏輯。

const TILE_PIXELS := 16
const ATLAS_COLUMNS := 8
## atlas 不存在時的備援順序（與 placeholder 索引一致）。
const TILE_ORDER: Array[String] = ["grass", "path", "wall", "water", "tree", "npc", "chest", "player"]

const FALLBACK_COLORS: Dictionary = {
	"grass": Color(0.30, 0.62, 0.30),
	"path": Color(0.72, 0.64, 0.45),
	"wall": Color(0.35, 0.35, 0.40),
	"water": Color(0.20, 0.40, 0.75),
	"tree": Color(0.12, 0.40, 0.18),
	"npc": Color(0.90, 0.70, 0.20),
	"chest": Color(0.75, 0.45, 0.15),
	"player": Color(0.15, 0.85, 1.00),
}

var grid: MapGrid
var atlas_texture: Texture2D
var atlas_indices: Dictionary = {}
var atlas_tile_pixels: int = TILE_PIXELS
var warnings: Array[String] = []

var _missing_keys: Dictionary = {}


## 建立/重建世界畫面。atlas_meta 可為空字典（退回色塊）。
func build(map_grid: MapGrid, texture: Texture2D, atlas_meta: Dictionary) -> void:
	grid = map_grid
	atlas_texture = texture
	atlas_indices.clear()
	warnings.clear()
	_missing_keys.clear()
	atlas_tile_pixels = TILE_PIXELS
	if atlas_meta is Dictionary and not atlas_meta.is_empty():
		atlas_indices = extract_atlas_indices(atlas_meta)
		atlas_tile_pixels = int(atlas_meta.get("tile_size", TILE_PIXELS))
		if atlas_tile_pixels <= 0:
			atlas_tile_pixels = TILE_PIXELS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if atlas_texture == null:
		warnings.append("W_ATLAS_MISSING 找不到 placeholder atlas，改用色塊佔位")
	queue_redraw()


## 從 placeholder_tiles.json 解析 key → atlas index。
## 支援三種常見寫法（由 Captain 的產生器決定實際格式）：
##   {"indices": {"grass": 0, ...}}
##   {"tiles": {"grass": 0, ...}} 或 {"tiles": {"grass": {"index": 0}}}
##   {"tiles": [{"key": "grass", "index": 0}, ...]} 或 {"tile_order": ["grass", ...]}
static func extract_atlas_indices(meta: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var raw_indices: Variant = meta.get("indices", null)
	if raw_indices is Dictionary:
		for key: Variant in raw_indices:
			if _is_int(raw_indices[key]):
				result[String(key)] = int(raw_indices[key])
	var raw_tiles: Variant = meta.get("tiles", null)
	if raw_tiles is Dictionary:
		for key: Variant in raw_tiles:
			var value: Variant = raw_tiles[key]
			if _is_int(value):
				result[String(key)] = int(value)
			elif value is Dictionary and _is_int((value as Dictionary).get("index", null)):
				result[String(key)] = int((value as Dictionary).get("index"))
	elif raw_tiles is Array:
		for index: int in (raw_tiles as Array).size():
			var item: Variant = (raw_tiles as Array)[index]
			if item is Dictionary:
				var item_data: Dictionary = item
				var name: String = String(item_data.get("key", item_data.get("name", "")))
				if not name.is_empty():
					result[name] = int(item_data.get("index", index)) if _is_int(item_data.get("index", index)) else index
			elif item is String:
				result[String(item)] = index
	var raw_order: Variant = meta.get("tile_order", null)
	if raw_order is Array:
		for index: int in (raw_order as Array).size():
			result[String((raw_order as Array)[index])] = index
	return result


func _draw() -> void:
	if grid == null:
		return
	var tile_pixels: int = grid.tile_size
	if tile_pixels <= 0:
		tile_pixels = TILE_PIXELS
	for y: int in grid.height:
		for x: int in grid.width:
			var cell := Vector2i(x, y)
			var tile_name: String = grid.tile_type_at(cell)
			_draw_tile(cell, tile_name, tile_pixels)
	for entity: Dictionary in grid.entities:
		var cell: Vector2i = entity.get("grid", Vector2i.ZERO)
		var index: int = _entity_atlas_index(entity)
		if atlas_texture != null:
			_draw_atlas_region(cell, index, tile_pixels)
		else:
			_draw_fallback_entity(cell, entity, tile_pixels)


func _draw_tile(cell: Vector2i, tile_name: String, tile_pixels: int) -> void:
	if tile_name.is_empty():
		return
	var index: int = _tile_atlas_index(tile_name)
	if atlas_texture != null:
		_draw_atlas_region(cell, index, tile_pixels)
	else:
		var color: Color = FALLBACK_COLORS.get(tile_name, Color(1, 0, 1))
		draw_rect(Rect2(cell.x * tile_pixels, cell.y * tile_pixels, tile_pixels, tile_pixels), color)


func _draw_atlas_region(cell: Vector2i, index: int, tile_pixels: int) -> void:
	if index < 0:
		return
	var source: Rect2 = Rect2(index * atlas_tile_pixels, 0, atlas_tile_pixels, atlas_tile_pixels)
	var destination: Rect2 = Rect2(cell.x * tile_pixels, cell.y * tile_pixels, tile_pixels, tile_pixels)
	draw_texture_rect_region(atlas_texture, destination, source)


func _draw_fallback_entity(cell: Vector2i, entity: Dictionary, tile_pixels: int) -> void:
	var key: String = String(entity.get("display_key", ""))
	var color: Color = FALLBACK_COLORS.get("npc", Color(0.9, 0.7, 0.2))
	if key.contains("chest"):
		color = FALLBACK_COLORS["chest"]
	elif String(entity.get("type", "")) == "npc":
		color = FALLBACK_COLORS["npc"]
	var inner: float = maxf(2.0, tile_pixels - 4.0)
	draw_rect(Rect2(cell.x * tile_pixels + 2.0, cell.y * tile_pixels + 2.0, inner, inner), color)


func _tile_atlas_index(tile_name: String) -> int:
	if atlas_indices.has(tile_name):
		return int(atlas_indices[tile_name])
	if TILE_ORDER.has(tile_name):
		_warn_missing_key(tile_name)
		return TILE_ORDER.find(tile_name)
	_warn_missing_key(tile_name)
	return -1


func _entity_atlas_index(entity: Dictionary) -> int:
	var display_key: String = String(entity.get("display_key", ""))
	if atlas_indices.has(display_key):
		return int(atlas_indices[display_key])
	var entity_type: String = String(entity.get("type", ""))
	var candidate: String = "npc" if entity_type == "npc" else "chest"
	if atlas_indices.has(candidate):
		return int(atlas_indices[candidate])
	_warn_missing_key(display_key if not display_key.is_empty() else candidate)
	return TILE_ORDER.find(candidate)


func _warn_missing_key(key: String) -> void:
	if _missing_keys.has(key):
		return
	_missing_keys[key] = true
	warnings.append("W_ATLAS_KEY atlas metadata 缺少鍵 '%s'，使用內建索引" % key)
	print_verbose("[WorldView] atlas key missing: " + key)


static func _is_int(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		return is_equal_approx(value, floorf(value))
	return false
