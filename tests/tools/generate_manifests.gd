extends SceneTree
## 開發工具：為 tests/fixtures/* 產生 manifest.json。
##
## 注意：res://content 是 APK 內建建置快照，由 tools/sync_content_bundle.mjs 產生，
## 本工具不再改寫它（避免把 content_id 蓋成非權威值）。
##
## 這不是測試的一部分（測試不會自動改寫 fixture），手動執行：
##   $G --headless --path <proj> --script res://tests/tools/generate_manifests.gd
##
## 功能：
## - 掃描目錄下所有 .json（排除 manifest.json），依 path 排序，寫入 sha256 與 size。
## - tampered_content：刻意破壞第一個檔案的 sha256 與第二個檔案的 size（測試雜湊驗證）。
## - unsafe_paths：額外注入 ../outside.json 不安全路徑（測試路徑驗證）。
## - missing_manifest 不產生 manifest（測試「找不到內容」）。

const CONTENT_ID_BY_DIR: Dictionary = {
	"res://tests/fixtures/valid_content": "fixture_valid",
	"res://tests/fixtures/tampered_content": "fixture_tampered",
	"res://tests/fixtures/unknown_effect": "fixture_unknown_effect",
	"res://tests/fixtures/broken_refs": "fixture_broken_refs",
	"res://tests/fixtures/invalid_map": "fixture_invalid_map",
	"res://tests/fixtures/unsafe_paths": "fixture_unsafe_paths",
}


func _initialize() -> void:
	var failures: int = 0
	for dir_path: String in CONTENT_ID_BY_DIR:
		if not DirAccess.dir_exists_absolute(dir_path) and not DirAccess.open(dir_path) is DirAccess:
			print("[gen] 略過不存在的目錄：", dir_path)
			continue
		if not _generate(dir_path, String(CONTENT_ID_BY_DIR[dir_path])):
			failures += 1
	print("[gen] 完成，失敗 %d 個目錄" % failures)
	quit(0 if failures == 0 else 1)


func _generate(dir_path: String, content_id: String) -> bool:
	var files: Array[String] = []
	_collect(dir_path, "", files)
	files.sort()
	var entries: Array = []
	for relative_path: String in files:
		var full_path: String = dir_path + "/" + relative_path
		var sha: String = _sha256_of_file(full_path)
		if sha.is_empty():
			print("[gen] 無法讀取：", full_path)
			return false
		entries.append({
			"path": relative_path,
			"sha256": sha,
			"size": _file_size(full_path),
		})
	if entries.is_empty():
		print("[gen] 目錄沒有資料檔，略過：", dir_path)
		return true

	if dir_path == "res://tests/fixtures/tampered_content":
		entries = _tamper(entries)
	elif dir_path == "res://tests/fixtures/unsafe_paths":
		entries.append({
			"path": "../outside.json",
			"sha256": "0000000000000000000000000000000000000000000000000000000000000000",
			"size": 0,
		})

	var manifest: Dictionary = {
		"manifest_schema": 1,
		"content_id": content_id,
		"content_version": "0.1.0",
		"schema_version": 1,
		"min_game_version": "0.1.0",
		"dependencies": [],
		"files": entries,
	}
	var manifest_path: String = dir_path + "/manifest.json"
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null:
		print("[gen] 無法寫入：", manifest_path)
		return false
	file.store_string(JSON.stringify(manifest, "  ") + "\n")
	file.close()
	print("[gen] 已寫入 %s（%d 個檔案）" % [manifest_path, entries.size()])
	return true


## 刻意讓 manifest 與實際檔案不一致：
## - 第一個檔案：sha256 翻轉一個字元（雜湊不符）
## - 第二個檔案：size +7（大小不符）
func _tamper(entries: Array) -> Array:
	if entries.size() < 1:
		return entries
	var first: Dictionary = entries[0]
	var sha: String = String(first.get("sha256", ""))
	var flipped: String = ("1" if sha.begins_with("0") else "0") + sha.substr(1)
	first["sha256"] = flipped
	if entries.size() >= 2:
		var second: Dictionary = entries[1]
		second["size"] = int(second.get("size", 0)) + 7
	return entries


func _collect(dir_path: String, prefix: String, found: Array[String]) -> void:
	var full_dir: String = dir_path + "/" + prefix if not prefix.is_empty() else dir_path
	var dir := DirAccess.open(full_dir)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		if file_name.ends_with(".json") and file_name != "manifest.json":
			found.append(prefix + "/" + file_name if not prefix.is_empty() else file_name)
	for sub_dir: String in dir.get_directories():
		_collect(dir_path, prefix + "/" + sub_dir if not prefix.is_empty() else sub_dir, found)


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
