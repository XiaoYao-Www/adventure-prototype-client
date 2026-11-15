extends SceneTree
## 素材連絡表（contact sheet）產生器：把大量小圖排成一張大圖 + 對照索引。
##
## 目的：讓 AI／人類只需看少數幾張「總覽圖」就能分類素材，不必逐張開圖（節省 token）。
## 使用 Godot 的 Image API 做整數倍 nearest 縮放，保留像素邊緣。
##
## 用法（headless）：
##   "$G" --headless --path <game-client> --script res://tools/make_contact_sheets.gd -- \
##       --assets /workspace/自動遊戲開發/assets --out /workspace/自動遊戲開發/tools/asset_previews
##
## 輸出：
##   mini_world_sprites.png / .json
##   items16.png / .json
## 索引 JSON 的 files 陣列依「列優先」順序對應格子。

const TILE := 16

var assets_root := ""
var out_dir := ""


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in args.size():
		var arg: String = args[index]
		if arg.begins_with("--assets="):
			assets_root = arg.substr("--assets=".length())
		elif arg == "--assets" and index + 1 < args.size():
			assets_root = args[index + 1]
		elif arg.begins_with("--out="):
			out_dir = arg.substr("--out=".length())
		elif arg == "--out" and index + 1 < args.size():
			out_dir = args[index + 1]
	if assets_root.is_empty() or out_dir.is_empty():
		push_error("需要 --assets 與 --out")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	var failures := 0
	failures += _sheet_mini_world()
	failures += _sheet_items()
	print("[sheets] 完成，失敗 %d" % failures)
	quit(0 if failures == 0 else 1)


func _collect(prefix: String) -> Array[String]:
	var result: Array[String] = []
	_collect_dir(assets_root + "/" + prefix, prefix, result)
	result.sort()
	return result


func _collect_dir(full_dir: String, rel_prefix: String, out: Array[String]) -> void:
	var dir := DirAccess.open(full_dir)
	if dir == null:
		return
	for name: String in dir.get_files():
		if name.to_lower().ends_with(".png"):
			out.append(rel_prefix + "/" + name)
	for sub: String in dir.get_directories():
		_collect_dir(full_dir + "/" + sub, rel_prefix + "/" + sub, out)


func _sheet_mini_world() -> int:
	var files: Array[String] = []
	for sub: String in ["Animals", "Buildings", "Characters", "Ground", "Miscellaneous", "Nature", "Objects", "Templates", "User Interface"]:
		var found: Array[String] = []
		_collect_dir(assets_root + "/MiniWorldSprites/" + sub, "MiniWorldSprites/" + sub, found)
		files.append_array(found)
	var root_files: Array[String] = []
	_collect_dir(assets_root + "/MiniWorldSprites", "MiniWorldSprites", root_files)
	for file: String in root_files:
		if not files.has(file):
			files.append(file)
	files.sort()
	return _make_sheet(files, "mini_world_sprites", 16, 64)


func _sheet_items() -> int:
	var files: Array[String] = []
	_collect_dir(assets_root + "/items", "items", files)
	files.sort()
	return _make_sheet(files, "items16", 32, 32)


func _make_sheet(files: Array[String], sheet_name: String, columns: int, cell: int) -> int:
	if files.is_empty():
		print("[sheets] %s：沒有檔案" % sheet_name)
		return 1
	var rows := int(ceil(float(files.size()) / float(columns)))
	var canvas := Image.create_empty(columns * cell, rows * cell, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0.08, 0.08, 0.10, 1.0))
	var failures := 0
	for index: int in files.size():
		var rel: String = files[index]
		var bytes := FileAccess.get_file_as_bytes(assets_root + "/" + rel)
		if bytes.is_empty():
			failures += 1
			continue
		var image := Image.new()
		if image.load_png_from_buffer(bytes) != OK:
			failures += 1
			continue
		var factor := maxi(1, int(cell / maxi(image.get_width(), image.get_height())))
		# 大圖縮小、小圖整數放大，都使用 nearest 保持像素
		if image.get_width() > cell or image.get_height() > cell:
			var scale := float(cell) / float(maxi(image.get_width(), image.get_height()))
			image.resize(maxi(1, int(image.get_width() * scale)), maxi(1, int(image.get_height() * scale)), Image.INTERPOLATE_NEAREST)
		elif factor > 1:
			image.resize(image.get_width() * factor, image.get_height() * factor, Image.INTERPOLATE_NEAREST)
		var column := index % columns
		var row := index / columns
		var offset := Vector2i(column * cell + (cell - image.get_width()) / 2, row * cell + (cell - image.get_height()) / 2)
		canvas.blend_rect(image, Rect2i(0, 0, image.get_width(), image.get_height()), offset)
	# 格線，方便人工定位
	for column: int in range(columns + 1):
		canvas.fill_rect(Rect2i(column * cell, 0, 1, rows * cell), Color(1, 1, 1, 0.10))
	for row: int in range(rows + 1):
		canvas.fill_rect(Rect2i(0, row * cell, columns * cell, 1), Color(1, 1, 1, 0.10))

	var png_path := out_dir + "/" + sheet_name + ".png"
	var file := FileAccess.open(png_path, FileAccess.WRITE)
	if file == null:
		push_error("無法寫入 " + png_path)
		return 1
	file.store_buffer(canvas.save_png_to_buffer())
	file.close()
	var mapping := {
		"sheet": sheet_name,
		"columns": columns,
		"cell_px": cell,
		"rows": rows,
		"files": files,
		"generated_at": Time.get_datetime_string_from_system(true),
		"note": "列優先順序對應格子；索引 i = row * columns + column。",
	}
	var json_file := FileAccess.open(out_dir + "/" + sheet_name + ".json", FileAccess.WRITE)
	if json_file != null:
		json_file.store_string(JSON.stringify(mapping, "  ") + "\n")
		json_file.close()
	print("[sheets] %s：%d 張 → %s（%dx%d）" % [sheet_name, files.size(), png_path, columns * cell, rows * cell])
	return failures
