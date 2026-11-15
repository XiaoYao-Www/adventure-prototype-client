class_name PlayerController
extends Node2D
## 玩家角色：負責逐格移動的視覺插值（Tween）與格子座標同步。
##
## 移動規則（阻擋、越界、對話中禁止移動）由 GameSession 判斷；本節點只負責
## 「把已核准的移動演出來」，動畫結束後發出 move_finished，由 main.gd 呼叫
## GameSession.complete_move() 提交狀態（含 portal 判定）。
##
## 移動中不接受新移動（step_to() 回傳 false），由呼叫端保證一次一格。

signal move_started(from_cell: Vector2i, to_cell: Vector2i)
signal move_finished(to_cell: Vector2i)

## 每格移動動畫秒數；可在測試中調小。
@export var move_duration: float = 0.09

var grid_pos: Vector2i = Vector2i.ZERO
var facing: Vector2i = Vector2i.DOWN
var is_moving: bool = false
var tile_size: int = 16

var _sprite: Sprite2D
var _fallback_rect: ColorRect
var _tween: Tween
var _atlas_indices: Dictionary = {}


## 設定格子像素尺寸（必須先於 place_at 呼叫）。
func configure(tile_pixels: int) -> void:
	tile_size = maxi(1, tile_pixels)


## 立即把玩家放到指定格（不做動畫）；若有進行中的動畫會中止。
func place_at(cell: Vector2i) -> void:
	if is_moving and _tween != null and _tween.is_valid():
		_tween.kill()
	is_moving = false
	grid_pos = cell
	position = cell_center(cell)


## 開始移動到相鄰格；回傳 false 代表正在移動中，呼叫端應忽略本次輸入。
func step_to(target_cell: Vector2i) -> bool:
	if is_moving:
		return false
	is_moving = true
	var from_cell: Vector2i = grid_pos
	facing = _direction_to(from_cell, target_cell)
	emit_signal("move_started", from_cell, target_cell)
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_LINEAR)
	_tween.tween_property(self, "position", cell_center(target_cell), move_duration)
	_tween.finished.connect(_on_tween_finished.bind(target_cell))
	return true


func set_facing(direction: Vector2i) -> void:
	if direction != Vector2i.ZERO:
		facing = direction


func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(
		(cell.x * tile_size) + (tile_size / 2.0),
		(cell.y * tile_size) + (tile_size / 2.0)
	)


## 建立角色外觀：有 atlas 時使用 region 7（player），否則用 ColorRect 佔位。
func set_atlas(texture: Texture2D, atlas_indices: Dictionary) -> void:
	_atlas_indices = atlas_indices.duplicate()
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.queue_free()
		_sprite = null
	if _fallback_rect != null and is_instance_valid(_fallback_rect):
		_fallback_rect.queue_free()
		_fallback_rect = null
	if texture != null:
		var index: int = int(_atlas_indices.get("player", 7))
		var sprite := Sprite2D.new()
		sprite.name = "Sprite"
		sprite.texture = texture
		sprite.region_enabled = true
		sprite.region_rect = Rect2(index * 16.0, 0.0, 16.0, 16.0)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
		_sprite = sprite
	else:
		var rect := ColorRect.new()
		rect.name = "Placeholder"
		rect.color = Color(0.15, 0.85, 1.0)
		rect.size = Vector2(tile_size - 2, tile_size - 2)
		rect.position = Vector2(-(tile_size - 2) / 2.0, -(tile_size - 2) / 2.0)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)
		_fallback_rect = rect


func _on_tween_finished(target_cell: Vector2i) -> void:
	grid_pos = target_cell
	position = cell_center(target_cell)
	is_moving = false
	emit_signal("move_finished", target_cell)


static func _direction_to(from_cell: Vector2i, to_cell: Vector2i) -> Vector2i:
	var delta: Vector2i = to_cell - from_cell
	if absi(delta.x) > absi(delta.y):
		return Vector2i(signi(delta.x), 0)
	return Vector2i(0, signi(delta.y))
