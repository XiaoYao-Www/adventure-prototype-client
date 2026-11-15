extends SceneTree
## Headless 測試入口。
##
## 執行：
##   $G --headless --path <proj> --script res://tests/run_tests.gd \
##       -- --content-dir=/abs/path/to/game-content [--fixtures-dir=res://tests/fixtures]
##
## 輸出最後一行為 `TESTS OK n/n` 或 `TESTS FAILED ...`，exit code 0/1。
## 未執行的檢查以 [SKIP] 標記並在結尾列出原因。

const FIXTURES_DEFAULT := "res://tests/fixtures"
# 與 touch_controls.gd 的常數一致（測試按住連走的時間點）
const HOLD_DELAY_TEST := 0.28
const REPEAT_INTERVAL_TEST := 0.14
const VALID_FIXTURE := "valid_content"
const SAVE_TEST_PATH := "user://test_save_roundtrip.json"
const SAVE_BAD_VERSION_PATH := "user://test_save_bad_version.json"
const SAVE_CORRUPT_PATH := "user://test_save_corrupt.json"
const SAVE_LEGACY_PATH := "user://test_save_legacy.json"
const SAVE_MISSING_PATH := "user://test_save_missing_never_written.json"

var th: TestHelper
var fixtures_root: String = FIXTURES_DEFAULT
var real_content_dir: String = ""


func _initialize() -> void:
	th = TestHelper.new()
	_parse_args()
	print("== Godot headless tests ==")
	print("fixtures: ", fixtures_root)
	print("real content: ", real_content_dir if not real_content_dir.is_empty() else "（未提供，將 SKIP）")
	await _run_all()
	_finish()


func _parse_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	real_content_dir = ContentRepository.content_dir_from_user_args(args)
	for index: int in args.size():
		var arg: String = args[index]
		if arg.begins_with("--fixtures-dir="):
			fixtures_root = arg.substr("--fixtures-dir=".length()).strip_edges()
		elif arg == "--fixtures-dir" and index + 1 < args.size():
			fixtures_root = args[index + 1].strip_edges()
	if fixtures_root.ends_with("/"):
		fixtures_root = fixtures_root.trim_suffix("/")


func _finish() -> void:
	print("")
	print(th.summary())
	if th.failed > 0:
		print("失敗項目：")
		for failure: String in th.failures:
			print("  - ", failure)
	if th.skipped > 0:
		print("SKIPPED %d 項：" % th.skipped)
		for note: String in th.skip_notes:
			print("  - ", note)
	quit(0 if th.failed == 0 else 1)


func _run_all() -> void:
	_test_content_dir_resolution()
	_test_grid()
	_test_content_valid()
	_test_content_bootstrap()
	_test_content_tampered()
	_test_content_missing_manifest()
	_test_content_unknown_effect()
	_test_content_broken_refs()
	_test_content_invalid_map()
	_test_content_unsafe_paths()
	_test_content_bad_manifest_header()
	_test_effects()
	_test_movement()
	_test_dialogue()
	_test_non_repeatable_event()
	_test_portal_and_arrival_suppression()
	_test_save_roundtrip()
	_test_save_error_handling()
	_test_input_map_and_project_settings()
	_test_touch_controls()
	await _test_world_view_atlas()
	await _test_player_controller()
	await _test_main_scene()
	_test_real_content()


# ---------------------------------------------------------------------------
# 工具
# ---------------------------------------------------------------------------

func _fixture_path(name: String) -> String:
	return fixtures_root + "/" + name


func _load_repo(dir_path: String) -> ContentRepository:
	var repo := ContentRepository.new()
	repo.load_content(dir_path)
	return repo


func _print_repo(repo: ContentRepository, label: String) -> void:
	print("  [%s] ok=%s errors=%d warnings=%d" % [label, str(repo.is_ok()), repo.errors.size(), repo.warnings.size()])
	for error_text: String in repo.errors:
		print("    error: ", error_text)
	for warning_text: String in repo.warnings:
		print("    warning: ", warning_text)


func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _remove_file_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _make_session(content_dir: String) -> Dictionary:
	var repo: ContentRepository = _load_repo(content_dir)
	var state := GameState.new()
	var session := GameSession.new()
	var ok: bool = session.setup(repo, state)
	return {"repo": repo, "state": state, "session": session, "ok": ok}


# ---------------------------------------------------------------------------
# 內容目錄解析
# ---------------------------------------------------------------------------

func _test_content_dir_resolution() -> void:
	th.section("內容目錄解析（CLI > ProjectSettings > res://content）")
	th.check_eq(
		ContentRepository.content_dir_from_user_args(PackedStringArray(["--content-dir=/tmp/x", "--other"])),
		"/tmp/x",
		"解析 --content-dir=<path>"
	)
	th.check_eq(
		ContentRepository.content_dir_from_user_args(PackedStringArray(["--content-dir", "/tmp/y"])),
		"/tmp/y",
		"解析 --content-dir <path>"
	)
	th.check_eq(ContentRepository.content_dir_from_user_args(PackedStringArray([])), "", "沒有參數時回傳空字串")
	th.check_eq(
		ContentRepository.resolve_content_dir(PackedStringArray(["--content-dir=/cli"]), "/project"),
		"/cli",
		"CLI 優先於 ProjectSettings"
	)
	th.check_eq(
		ContentRepository.resolve_content_dir(PackedStringArray([]), "/project"),
		"/project",
		"ProjectSettings 優先於 res://content"
	)
	th.check_eq(ContentRepository.resolve_content_dir(PackedStringArray([]), ""), "res://content", "fallback 為 res://content")


# ---------------------------------------------------------------------------
# 格子
# ---------------------------------------------------------------------------

func _grid_test_data() -> Dictionary:
	return {
		"id": "map_test",
		"name": "格子測試",
		"size": {"width": 10, "height": 7},
		"tile_size": 16,
		"tiles": [
			"##########",
			"#........#",
			"#..t.....#",
			"#...~~...#",
			"#....p...#",
			"#....p...#",
			"##########",
		],
		"legend": {
			"#": {"tile": "wall", "walkable": false},
			".": {"tile": "grass", "walkable": true},
			"t": {"tile": "tree", "walkable": false},
			"~": {"tile": "water", "walkable": false},
			"p": {"tile": "path", "walkable": true},
		},
		"spawn": {"grid": [1, 1]},
		"entities": [
			{
				"id": "npc_a",
				"type": "npc",
				"grid": [3, 3],
				"display_key": "npc_elder",
				"interaction": {"kind": "event", "event_id": "event_a"},
			}
		],
		"portals": [
			{"id": "portal_a", "grid": [8, 5], "target_map_id": "map_other", "target_grid": [1, 1]}
		],
	}


func _test_grid() -> void:
	th.section("格子座標 / 可通行 / 實體佔用 / portal")
	var grid := MapGrid.from_map_data(_grid_test_data())
	th.check_eq(grid.width, 10, "width")
	th.check_eq(grid.height, 7, "height")
	th.check_eq(grid.tile_size, 16, "tile_size")
	th.check_true(grid.in_bounds(Vector2i(0, 0)), "左上角在範圍內")
	th.check_true(grid.in_bounds(Vector2i(9, 6)), "右下角在範圍內")
	th.check_false(grid.in_bounds(Vector2i(-1, 0)), "x 越界")
	th.check_false(grid.in_bounds(Vector2i(0, -1)), "y 越界")
	th.check_false(grid.in_bounds(Vector2i(10, 0)), "x 超過 width")
	th.check_false(grid.in_bounds(Vector2i(0, 7)), "y 超過 height")
	th.check_eq(grid.tile_char_at(Vector2i(-1, 0)), "", "越界 tile 字元為空")
	th.check_true(grid.is_walkable(Vector2i(1, 1)), "草地可通行")
	th.check_true(grid.is_walkable(Vector2i(5, 4)), "路徑可通行")
	th.check_false(grid.is_walkable(Vector2i(0, 0)), "牆不可通行")
	th.check_false(grid.is_walkable(Vector2i(3, 2)), "樹不可通行")
	th.check_false(grid.is_walkable(Vector2i(4, 3)), "水不可通行")
	th.check_false(grid.is_walkable(Vector2i(-1, -1)), "越界不可通行")
	th.check_eq(grid.tile_type_at(Vector2i(5, 4)), "path", "tile_type_at 回傳 path")
	th.check_eq(grid.tile_type_at(Vector2i(3, 2)), "tree", "tile_type_at 回傳 tree")
	th.check_eq(grid.tile_type_at(Vector2i(4, 3)), "water", "tile_type_at 回傳 water")
	th.check_eq(String(grid.entity_at(Vector2i(3, 3)).get("id", "")), "npc_a", "entity_at 找到 NPC")
	th.check_true(grid.has_entity(Vector2i(3, 3)), "has_entity")
	th.check_false(grid.has_entity(Vector2i(1, 1)), "空地沒有實體")
	th.check_false(grid.can_enter(Vector2i(3, 3)), "實體格不可進入")
	th.check_true(grid.can_enter(Vector2i(1, 1)), "空地可進入")
	th.check_false(grid.can_enter(Vector2i(0, 0)), "牆不可進入")
	th.check_eq(String(grid.portal_at(Vector2i(8, 5)).get("target_map_id", "")), "map_other", "portal_at 回傳 target_map_id")
	th.check_true(grid.portal_at(Vector2i(1, 1)).is_empty(), "非 portal 格回傳空字典")
	th.check_eq(grid.cell_center_world(Vector2i(0, 0)), Vector2(8, 8), "格子中心 (0,0)")
	th.check_eq(grid.cell_center_world(Vector2i(3, 6)), Vector2(56, 104), "格子中心 (3,6)")
	th.check_eq(MapGrid.neighbour(Vector2i(2, 2), Vector2i.RIGHT), Vector2i(3, 2), "neighbour")


# ---------------------------------------------------------------------------
# 內容載入器
# ---------------------------------------------------------------------------

func _test_content_valid() -> void:
	th.section("內容載入：合法 fixture（manifest sha256/size 驗證成功）")
	var repo: ContentRepository = _load_repo(_fixture_path(VALID_FIXTURE))
	_print_repo(repo, "valid_content")
	th.check_true(repo.is_ok(), "合法內容 is_ok")
	th.check_eq(repo.errors.size(), 0, "合法內容沒有錯誤")
	th.check_eq(repo.warnings.size(), 0, "合法內容沒有警告")
	th.check_eq(repo.content_id, "fixture_valid", "content_id")
	th.check_eq(repo.content_version, "0.1.0", "content_version")
	th.check_eq(repo.maps.size(), 2, "2 張地圖")
	th.check_eq(repo.npcs.size(), 1, "1 個 NPC")
	th.check_eq(repo.items.size(), 1, "1 個道具")
	th.check_eq(repo.events.size(), 2, "2 個事件")
	th.check_eq(repo.regions.size(), 1, "1 個區域")
	th.check_eq(repo.get_start_map_id(), "map_test_village", "起始地圖來自第一個 region 的 map_ids[0]")
	th.check_false(repo.get_event("event_test_elder_001").is_empty(), "事件已解析")
	th.check_contains(repo.summary(), "fixture_valid", "summary 含 content_id")


func _test_content_bootstrap() -> void:
	th.section("內容載入：res://content 內建建置快照（來自 game-content）")
	var repo: ContentRepository = _load_repo("res://content")
	_print_repo(repo, "res://content")
	th.check_true(repo.is_ok(), "內建內容可載入")
	th.check_eq(repo.errors.size(), 0, "內建內容沒有錯誤")
	th.check_eq(repo.maps.size(), 2, "內建內容 2 張地圖")


func _test_content_tampered() -> void:
	th.section("內容載入：manifest 被篡改（hash / size 不符）")
	var repo: ContentRepository = _load_repo(_fixture_path("tampered_content"))
	_print_repo(repo, "tampered_content")
	var error_text: String = repo.errors_text()
	th.check_false(repo.is_ok(), "篡改內容 is_ok 為 false")
	th.check_contains(error_text, "E_HASH_MISMATCH", "偵測 sha256 不符")
	th.check_contains(error_text, "大小不符", "偵測 size 不符")
	th.check_eq(repo.maps.size(), 2, "地圖檔案雜湊正確仍被解析")
	th.check_eq(repo.npcs.size(), 0, "sha256 不符的 NPC 檔案不被解析")
	th.check_eq(repo.events.size(), 1, "size 不符的事件檔案不被解析")


func _test_content_missing_manifest() -> void:
	th.section("內容載入：缺少 manifest（可讀錯誤、不崩潰）")
	var repo: ContentRepository = _load_repo(_fixture_path("missing_manifest"))
	_print_repo(repo, "missing_manifest")
	th.check_false(repo.is_ok(), "缺少 manifest 不可用")
	th.check_contains(repo.errors_text(), "找不到內容", "錯誤訊息含「找不到內容」")
	th.check_contains(repo.errors_text(), "manifest.json", "錯誤訊息指出 manifest.json")
	th.check_true(repo.maps.is_empty(), "沒有地圖")


func _test_content_unknown_effect() -> void:
	th.section("內容載入：未知 effect / 參數錯誤 → 事件拒絕")
	var repo: ContentRepository = _load_repo(_fixture_path("unknown_effect"))
	_print_repo(repo, "unknown_effect")
	var error_text: String = repo.errors_text()
	th.check_false(repo.is_ok(), "含未知 effect 的內容不可用")
	th.check_contains(error_text, "未知 effect type", "偵測未知 effect type")
	th.check_contains(error_text, "qty 必須介於", "偵測錯誤參數（qty=0）")
	th.check_true(repo.events.is_empty(), "未知 effect 的事件不被載入")


func _test_content_broken_refs() -> void:
	th.section("內容載入：引用完整性（event/map/npc/item/trigger）")
	var repo: ContentRepository = _load_repo(_fixture_path("broken_refs"))
	_print_repo(repo, "broken_refs")
	var error_text: String = repo.errors_text()
	th.check_false(repo.is_ok(), "引用錯誤內容不可用")
	th.check_contains(error_text, "E_MISSING_EVENT_REF", "entity 引用不存在的 event_id")
	th.check_contains(error_text, "E_MISSING_MAP_REF", "portal/region/event 引用不存在的 map_id")
	th.check_contains(error_text, "E_MISSING_NPC_REF", "speaker_id 不存在")
	th.check_contains(error_text, "E_MISSING_ITEM_REF", "give_item 引用不存在的 item_id")
	th.check_contains(error_text, "E_EVENT_TRIGGER_MISMATCH", "entity 與 event trigger 雙向不一致")
	th.check_eq(repo.maps.size(), 1, "地圖本身解析成功（錯誤來自引用）")


func _test_content_invalid_map() -> void:
	th.section("內容載入：地圖幾何錯誤（tiles/legend/spawn/entity/portal）")
	var repo: ContentRepository = _load_repo(_fixture_path("invalid_map"))
	_print_repo(repo, "invalid_map")
	var error_text: String = repo.errors_text()
	th.check_false(repo.is_ok(), "幾何錯誤內容不可用")
	th.check_contains(error_text, "列數", "偵測 tiles 列數不符 height")
	th.check_contains(error_text, "長度", "偵測 tiles 列長不符 width")
	th.check_contains(error_text, "legend 缺少", "偵測 legend 未覆蓋字元")
	th.check_contains(error_text, "E_MAP_SPAWN", "偵測 spawn 越界")
	th.check_contains(error_text, "E_MAP_ENTITY", "偵測 entity 格不可通行")
	th.check_contains(error_text, "E_MAP_PORTAL", "偵測 portal 格不可通行")
	th.check_contains(error_text, "E_NO_MAPS", "地圖被拒絕後回報沒有地圖")


func _test_content_unsafe_paths() -> void:
	th.section("內容載入：manifest 不安全路徑")
	var repo: ContentRepository = _load_repo(_fixture_path("unsafe_paths"))
	_print_repo(repo, "unsafe_paths")
	var error_text: String = repo.errors_text()
	th.check_false(repo.is_ok(), "不安全路徑內容不可用")
	th.check_contains(error_text, "E_MANIFEST_PATH", "偵測不安全路徑")
	th.check_contains(error_text, "../outside.json", "錯誤訊息指出路徑")


func _test_content_bad_manifest_header() -> void:
	th.section("內容載入：manifest header 錯誤")
	var temp_dir: String = "user://test_content_bad_header"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temp_dir))
	_write_text(temp_dir + "/manifest.json", JSON.stringify({
		"manifest_schema": 2,
		"schema_version": 1,
		"files": [],
	}))
	var repo: ContentRepository = _load_repo(temp_dir)
	_print_repo(repo, "bad_header")
	th.check_false(repo.is_ok(), "錯誤 header 不可用")
	th.check_contains(repo.errors_text(), "manifest_schema", "偵測 manifest_schema 錯誤")
	th.check_contains(repo.errors_text(), "content_id", "偵測缺少 content_id")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_dir + "/manifest.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_dir))


# ---------------------------------------------------------------------------
# effects / 移動 / 對話 / portal
# ---------------------------------------------------------------------------

func _test_effects() -> void:
	th.section("Effects：set_flag / give_item / 未知 type 安全拒絕")
	var made: Dictionary = _make_session(_fixture_path(VALID_FIXTURE))
	var session: GameSession = made["session"]
	var state: GameState = made["state"]
	th.check_true(bool(made["ok"]), "session 初始化")

	var errors: Array[String] = session.apply_effects([
		{"type": "set_flag", "flag": "flag_test_a", "value": true},
		{"type": "give_item", "item_id": "item_test_herb_001", "qty": 3},
	])
	th.check_eq(errors.size(), 0, "合法 effects 沒有錯誤")
	th.check_true(state.get_flag("flag_test_a"), "set_flag 生效")
	th.check_eq(state.item_count("item_test_herb_001"), 3, "give_item 累加數量")

	var unknown_errors: Array[String] = session.apply_effects([{"type": "teleport_player", "grid": [1, 1]}])
	th.check_eq(unknown_errors.size(), 1, "未知 effect 回報 1 個錯誤")
	th.check_contains(unknown_errors[0], "未知 effect type", "未知 effect 錯誤訊息")
	th.check_false(state.get_flag("flag_never"), "未知 effect 不被執行")

	var bad_param_errors: Array[String] = session.apply_effects([
		{"type": "set_flag", "flag": "flag_bad", "value": "yes"},
		{"type": "give_item", "item_id": "item_test_herb_001", "qty": 0},
		{"type": "give_item", "item_id": "item_test_herb_001", "qty": -1},
	])
	th.check_eq(bad_param_errors.size(), 3, "錯誤參數各自回報")
	th.check_false(state.get_flag("flag_bad"), "錯誤 set_flag 不生效")
	th.check_eq(state.item_count("item_test_herb_001"), 3, "錯誤 qty 不改變物品數量")

	var not_array_errors: Array[String] = session.apply_effects("not an array")
	th.check_eq(not_array_errors.size(), 1, "effects 非陣列時回報錯誤")


func _test_movement() -> void:
	th.section("移動：可通行 / 阻擋 / 越界 / 實體佔用 / 對話鎖定")
	var made: Dictionary = _make_session(_fixture_path(VALID_FIXTURE))
	var session: GameSession = made["session"]
	var state: GameState = made["state"]
	th.check_eq(state.player_grid, Vector2i(1, 1), "起始位置為 spawn")
	th.check_eq(state.current_map_id, "map_test_village", "起始地圖")

	var up_result: Dictionary = session.try_move(Vector2i.UP)
	th.check_false(bool(up_result["moved"]), "撞牆不可移動")
	th.check_eq(String(up_result["reason"]), "blocked_terrain", "牆阻擋原因")

	var out_result: Dictionary = session.try_move(Vector2i.LEFT)
	th.check_eq(String(out_result["reason"]), "blocked_terrain", "往牆移動被阻擋")

	var down_result: Dictionary = session.try_move(Vector2i.DOWN)
	th.check_true(bool(down_result["moved"]), "往空地可移動")
	th.check_eq(down_result["target"], Vector2i(1, 2), "目標格正確")
	var completed: Dictionary = session.complete_move()
	th.check_true(bool(completed["moved"]), "complete_move 提交")
	th.check_eq(state.player_grid, Vector2i(1, 2), "移動後座標更新")
	th.check_eq(GameState.facing_to_name(state.facing), "down", "面向更新")

	var stale: Dictionary = session.complete_move()
	th.check_false(bool(stale["moved"]), "沒有 pending 移動時 complete_move 不做事")

	var invalid_result: Dictionary = session.try_move(Vector2i(2, 0))
	th.check_eq(String(invalid_result["reason"]), "invalid_direction", "斜向移動被拒絕")

	# NPC 佔用格：從 (3,4) 往上看 NPC (3,3)
	state.player_grid = Vector2i(3, 4)
	state.facing = Vector2i.UP
	session.abort_pending_move()
	var entity_result: Dictionary = session.try_move(Vector2i.UP)
	th.check_false(bool(entity_result["moved"]), "實體佔用格不可移動")
	th.check_eq(String(entity_result["reason"]), "blocked_entity", "實體阻擋原因")

	# 對話中禁止移動
	state.player_grid = Vector2i(3, 4)
	state.facing = Vector2i.UP
	th.check_true(session.start_interaction(), "開始對話")
	var dialogue_move: Dictionary = session.try_move(Vector2i.DOWN)
	th.check_false(bool(dialogue_move["moved"]), "對話中不可移動")
	th.check_eq(String(dialogue_move["reason"]), "in_dialogue", "對話鎖定原因")
	session.close_dialogue()


func _test_dialogue() -> void:
	th.section("對話：逐句、選項、effects、關閉")
	var made: Dictionary = _make_session(_fixture_path(VALID_FIXTURE))
	var session: GameSession = made["session"]
	var state: GameState = made["state"]
	state.player_grid = Vector2i(3, 4)
	state.facing = Vector2i.UP

	th.check_true(session.can_interact(), "面向 NPC 可互動")
	th.check_eq(session.get_interaction_target().get("id", ""), "npc_test_elder_001", "互動目標為 NPC")
	th.check_eq(session.speaker_display_name("player"), "你", "player 顯示為「你」")
	th.check_eq(session.speaker_display_name("npc_test_elder_001"), "測試村長", "NPC 顯示名稱")

	th.check_true(session.start_interaction(), "互動開始")
	var line: Dictionary = session.current_line()
	th.check_eq(line["speaker"], "測試村長", "第一句說話者")
	th.check_eq(line["line_index"], 0, "第一句 index 0")
	th.check_eq(line["total_lines"], 3, "共 3 句")
	th.check_false(bool(line["is_last_line"]), "第一句不是最後一句")

	var step1: Dictionary = session.advance_dialogue()
	th.check_eq(String(step1["action"]), "line", "推進到第二句")
	th.check_eq(session.current_line()["speaker"], "你", "第二句說話者為玩家")

	var step2: Dictionary = session.advance_dialogue()
	th.check_eq(String(step2["action"]), "line", "推進到第三句")
	th.check_true(bool(session.current_line()["is_last_line"]), "第三句為最後一句")

	var step3: Dictionary = session.advance_dialogue()
	th.check_eq(String(step3["action"]), "choices", "最後一句後顯示選項")
	var expected_choices: Array[String] = ["我願意幫忙", "先不要"]
	th.check_eq(session.current_choices(), expected_choices, "選項文字")

	var bad_choice: Dictionary = session.choose(9)
	th.check_false(bool(bad_choice["ok"]), "無效選項被拒絕")
	th.check_true(session.is_in_dialogue(), "無效選項不關閉對話")

	var choice_result: Dictionary = session.choose(0)
	th.check_true(bool(choice_result["ok"]), "選項套用成功")
	th.check_true(state.get_flag("flag_met_elder"), "選項 effect set_flag 生效")
	th.check_false(session.is_in_dialogue(), "套用 effects 後關閉對話")
	th.check_true(state.completed_event_ids.is_empty(), "repeatable 事件不記入 completed_event_ids")


func _test_non_repeatable_event() -> void:
	th.section("repeatable=false：完成後不再互動、記入存檔欄位")
	var made: Dictionary = _make_session(_fixture_path(VALID_FIXTURE))
	var session: GameSession = made["session"]
	var state: GameState = made["state"]
	th.check_true(session.enter_map("map_test_forest", Vector2i(5, 2), true), "進入森林")
	state.facing = Vector2i.UP  # 寶箱在 (5,1)
	th.check_true(session.can_interact(), "面向寶箱可互動")
	th.check_true(session.start_interaction(), "寶箱事件開始")
	session.advance_dialogue()
	var choices: Dictionary = session.advance_dialogue()
	th.check_eq(String(choices["action"]), "choices", "寶箱事件有選項")
	var result: Dictionary = session.choose(0)
	th.check_true(bool(result["ok"]), "寶箱選項成功")
	th.check_eq(state.item_count("item_test_herb_001"), 2, "give_item qty=2 生效")
	th.check_true(state.has_completed_event("event_test_chest_001"), "非重複事件記入 completed_event_ids")
	th.check_false(session.can_interact(), "完成後不再顯示互動提示")
	th.check_false(session.start_interaction(), "完成後不再觸發事件")


func _test_portal_and_arrival_suppression() -> void:
	th.section("Portal：切換地圖、target_grid、抵達抑制")
	var made: Dictionary = _make_session(_fixture_path(VALID_FIXTURE))
	var session: GameSession = made["session"]
	var state: GameState = made["state"]
	state.player_grid = Vector2i(7, 5)
	state.facing = Vector2i.RIGHT
	var move_result: Dictionary = session.try_move(Vector2i.RIGHT)
	th.check_true(bool(move_result["moved"]), "移動到 portal 格")
	var completed: Dictionary = session.complete_move()
	th.check_true(bool(completed["portal"]), "踏上 portal 觸發切換")
	th.check_eq(session.grid.map_id, "map_test_forest", "切換到森林")
	th.check_eq(state.player_grid, Vector2i(1, 4), "玩家放到 target_grid")
	th.check_eq(session.grid.map_id, "map_test_forest", "抵達後不立刻反向觸發同一 portal（抵達抑制）")

	# 離開抵達格後解除抑制
	session.try_move(Vector2i.UP)
	var off_result: Dictionary = session.complete_move()
	th.check_false(bool(off_result["portal"]), "離開抵達格不觸發 portal")
	th.check_eq(state.player_grid, Vector2i(1, 3), "離開抵達格")

	# 回到 portal 格 → 觸發回程
	session.try_move(Vector2i.DOWN)
	var back_result: Dictionary = session.complete_move()
	th.check_true(bool(back_result["portal"]), "回到 portal 格觸發回程")
	th.check_eq(session.grid.map_id, "map_test_village", "回到村落")
	th.check_eq(state.player_grid, Vector2i(8, 5), "回程放到 target_grid")
	th.check_eq(session.grid.map_id, "map_test_village", "回程抵達格也受抵達抑制")

	# 再一次離開並回到村莊 portal → 應再次切換
	session.try_move(Vector2i.LEFT)
	session.complete_move()
	session.try_move(Vector2i.RIGHT)
	var again: Dictionary = session.complete_move()
	th.check_true(bool(again["portal"]), "解除抑制後可再次觸發")
	th.check_eq(session.grid.map_id, "map_test_forest", "再次切換到森林")


# ---------------------------------------------------------------------------
# 存檔
# ---------------------------------------------------------------------------

func _test_save_roundtrip() -> void:
	th.section("存檔：寫入→讀取往返、內容版本分離、legacy 相容")
	_remove_file_if_exists(SAVE_TEST_PATH)
	var state := GameState.new()
	state.current_map_id = "map_test_village"
	state.player_grid = Vector2i(3, 4)
	state.facing = Vector2i.UP
	state.set_flag("flag_met_elder", true)
	state.add_item("item_test_herb_001", 2)
	state.mark_event_completed("event_test_chest_001")

	var manager := SaveManager.new()
	var saved: Dictionary = manager.save_state(state, "0.1.0", SAVE_TEST_PATH)
	th.check_true(bool(saved["ok"]), "存檔成功")
	th.check_true(FileAccess.file_exists(SAVE_TEST_PATH), "存檔檔案存在")

	var loaded: Dictionary = manager.load_save(SAVE_TEST_PATH)
	th.check_true(bool(loaded["ok"]), "讀檔成功")
	var data: Dictionary = loaded["data"]
	th.check_eq(int(data.get("save_version", -1)), 1, "save_version == 1")
	th.check_eq(String(data.get("content_version", "")), "0.1.0", "content_version 寫入")
	th.check_eq(String(data.get("map_id", "")), "map_test_village", "map_id")
	th.check_eq(int(data["player"]["grid"][0]), 3, "player.grid x")
	th.check_eq(int(data["player"]["grid"][1]), 4, "player.grid y")
	th.check_eq(String(data["player"]["facing"]), "up", "player.facing")
	th.check_true(bool(data["flags"]["flag_met_elder"]), "flags 寫入")
	th.check_eq(int(data["inventory"]["item_test_herb_001"]), 2, "inventory 寫入")
	th.check_array_contains(data["completed_event_ids"], "event_test_chest_001", "completed_event_ids 寫入")
	var updated_at: String = String(data.get("updated_at", ""))
	th.check_contains(updated_at, "T", "updated_at 為 ISO8601")
	th.check_true(updated_at.ends_with("Z"), "updated_at 為 UTC")

	var restored := GameState.new()
	restored.apply_dict(data)
	th.check_eq(restored.player_grid, Vector2i(3, 4), "還原座標")
	th.check_eq(restored.facing, Vector2i.UP, "還原面向")
	th.check_true(restored.get_flag("flag_met_elder"), "還原 flags")
	th.check_eq(restored.item_count("item_test_herb_001"), 2, "還原 inventory")
	th.check_true(restored.has_completed_event("event_test_chest_001"), "還原 completed_event_ids")

	# session 整合：還原後位置/地圖正確
	var repo: ContentRepository = _load_repo(_fixture_path(VALID_FIXTURE))
	var state2 := GameState.new()
	var session2 := GameSession.new()
	th.check_true(session2.setup(repo, state2), "新 session 初始化")
	var restore_result: Dictionary = session2.restore_from_save(data)
	th.check_true(bool(restore_result["ok"]), "session 還原成功")
	th.check_eq(session2.state.current_map_id, "map_test_village", "還原地圖")
	th.check_eq(session2.state.player_grid, Vector2i(3, 4), "還原位置")
	th.check_true(session2.state.get_flag("flag_met_elder"), "還原旗標")

	# 內容版本不同 → 可讀取，但回報警告（存檔與內容版本分離）
	var state3 := GameState.new()
	state3.current_map_id = "map_test_village"
	state3.player_grid = Vector2i(1, 1)
	var newer: Dictionary = manager.save_state(state3, "9.9.9", SAVE_TEST_PATH)
	th.check_true(bool(newer["ok"]), "不同 content_version 可存檔")
	var loaded_newer: Dictionary = manager.load_save(SAVE_TEST_PATH)
	th.check_true(bool(loaded_newer["ok"]), "不同 content_version 可讀檔")
	var state4 := GameState.new()
	var session4 := GameSession.new()
	session4.setup(repo, state4)
	var restore_newer: Dictionary = session4.restore_from_save(loaded_newer["data"])
	th.check_true(bool(restore_newer["ok"]), "內容版本不同仍可還原")
	th.check_false((restore_newer["warnings"] as Array).is_empty(), "內容版本不同產生警告")

	# legacy 存檔：缺少 completed_event_ids 仍可讀取
	var legacy_data: Dictionary = manager.build_save_data(state, "0.1.0")
	legacy_data.erase("completed_event_ids")
	_write_text(SAVE_LEGACY_PATH, JSON.stringify(legacy_data))
	var legacy_loaded: Dictionary = manager.load_save(SAVE_LEGACY_PATH)
	th.check_true(bool(legacy_loaded["ok"]), "缺少 completed_event_ids 仍可讀取")
	var legacy_state := GameState.new()
	legacy_state.apply_dict(legacy_loaded["data"])
	th.check_true(legacy_state.completed_event_ids.is_empty(), "缺少欄位視為空陣列")

	_remove_file_if_exists(SAVE_TEST_PATH)
	_remove_file_if_exists(SAVE_LEGACY_PATH)


func _test_save_error_handling() -> void:
	th.section("存檔：不支援版本 / 損壞 JSON / 不存在")
	var manager := SaveManager.new()

	var state := GameState.new()
	state.current_map_id = "map_test_village"
	state.player_grid = Vector2i(1, 1)
	var base_data: Dictionary = manager.build_save_data(state, "0.1.0")
	base_data["save_version"] = 2
	var bad_version_text: String = JSON.stringify(base_data)
	_write_text(SAVE_BAD_VERSION_PATH, bad_version_text)
	var bad_version_result: Dictionary = manager.load_save(SAVE_BAD_VERSION_PATH)
	th.check_false(bool(bad_version_result["ok"]), "不支援的 save_version 讀取失敗")
	th.check_contains(String(bad_version_result["error"]), "save_version", "錯誤訊息含 save_version")
	th.check_eq(_read_text(SAVE_BAD_VERSION_PATH), bad_version_text, "讀檔失敗不覆寫存檔")

	_write_text(SAVE_CORRUPT_PATH, "{ 這不是合法 JSON")
	var corrupt_result: Dictionary = manager.load_save(SAVE_CORRUPT_PATH)
	th.check_false(bool(corrupt_result["ok"]), "損壞 JSON 讀取失敗")
	th.check_contains(String(corrupt_result["error"]), "JSON", "錯誤訊息指出 JSON")

	_remove_file_if_exists(SAVE_MISSING_PATH)
	var missing_result: Dictionary = manager.load_save(SAVE_MISSING_PATH)
	th.check_false(bool(missing_result["ok"]), "不存在的存檔讀取失敗")
	th.check_contains(String(missing_result["error"]), "找不到存檔", "錯誤訊息含「找不到存檔」")

	_remove_file_if_exists(SAVE_BAD_VERSION_PATH)
	_remove_file_if_exists(SAVE_CORRUPT_PATH)


# ---------------------------------------------------------------------------
# 專案設定 / 輸入
# ---------------------------------------------------------------------------

func _test_input_map_and_project_settings() -> void:
	th.section("專案設定與輸入 map")
	var actions: Array[String] = ["move_up", "move_down", "move_left", "move_right", "interact", "save_game", "load_game"]
	for action_name: String in actions:
		th.check_true(InputMap.has_action(action_name), "InputMap 有 " + action_name)
		th.check_true(InputMap.action_get_events(action_name).size() > 0, action_name + " 有綁定按鍵")
	th.check_eq(InputMap.action_get_events("move_up").size(), 2, "move_up 綁定 W 與 ↑")
	th.check_eq(InputMap.action_get_events("move_down").size(), 2, "move_down 綁定 S 與 ↓")
	th.check_eq(InputMap.action_get_events("move_left").size(), 2, "move_left 綁定 A 與 ←")
	th.check_eq(InputMap.action_get_events("move_right").size(), 2, "move_right 綁定 D 與 →")
	th.check_eq(InputMap.action_get_events("interact").size(), 3, "interact 綁定 E、Space、Enter")
	th.check_eq(InputMap.action_get_events("save_game").size(), 1, "save_game 綁定 F5")
	th.check_eq(InputMap.action_get_events("load_game").size(), 1, "load_game 綁定 F9")
	th.check_eq(ProjectSettings.get_setting("display/window/size/viewport_width", 0), 960, "viewport width 960")
	th.check_eq(ProjectSettings.get_setting("display/window/size/viewport_height", 0), 540, "viewport height 540")
	th.check_eq(String(ProjectSettings.get_setting("display/window/stretch/mode", "")), "canvas_items", "stretch mode canvas_items")
	th.check_eq(String(ProjectSettings.get_setting("display/window/stretch/aspect", "")), "expand", "stretch aspect expand")
	th.check_eq(String(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")), "gl_compatibility", "渲染方式 gl_compatibility")
	th.check_eq(String(ProjectSettings.get_setting("application/config/version", "")), "0.1.0", "遊戲版本 0.1.0")
	th.check_eq(String(ProjectSettings.get_setting("application/run/main_scene", "")), "res://scenes/main.tscn", "主場景")

	# CJK 字型：APK 內建 Noto Sans TC（OFL），避免中文顯示成方塊或空白
	var font_path: String = "res://assets/fonts/NotoSansTC-VF.ttf"
	th.check_true(ResourceLoader.exists(font_path), "內建 CJK 字型存在")
	var font_resource: Resource = load(font_path)
	th.check_true(font_resource is Font, "字型可載入為 Font")
	if font_resource is Font:
		var font: Font = font_resource
		th.check_true(font.has_char("中".unicode_at(0)), "字型含「中」字形")
		th.check_true(font.has_char("旅".unicode_at(0)), "字型含「旅」字形")
		th.check_true(font.has_char("互動".unicode_at(0)), "字型含「互」字形")
	th.check_eq(String(ProjectSettings.get_setting("gui/theme/custom_font", "")), font_path, "專案預設字型指向內建 CJK 字型")


# ---------------------------------------------------------------------------
# 畫面節點（headless 只驗證建立與資料，視覺外觀未驗證）
# ---------------------------------------------------------------------------

func _test_world_view_atlas() -> void:
	th.section("WorldView：atlas 對應與缺圖佔位")
	var repo: ContentRepository = _load_repo(_fixture_path(VALID_FIXTURE))
	var grid := MapGrid.from_map_data(repo.get_map("map_test_village"))
	th.check_eq(grid.entities.size(), 1, "地圖有 1 個實體")

	var view := WorldView.new()
	view.build(grid, null, {})
	th.check_true(view.warnings.size() >= 1, "沒有 atlas 時記錄警告")
	th.check_contains(String(view.warnings[0]) if view.warnings.size() > 0 else "", "W_ATLAS_MISSING", "警告代碼 W_ATLAS_MISSING")

	var atlas_path: String = "res://assets/generated/placeholder_tiles.png"
	var meta_path: String = "res://assets/generated/placeholder_tiles.json"
	if ResourceLoader.exists(atlas_path) and FileAccess.file_exists(meta_path):
		var texture: Resource = load(atlas_path)
		var meta: Dictionary = {}
		var file := FileAccess.open(meta_path, FileAccess.READ)
		if file != null:
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
				meta = json.data
			file.close()
		th.check_true(texture is Texture2D, "atlas 可載入為 Texture2D")
		view.build(grid, texture as Texture2D, meta)
		th.check_eq(view.warnings.size(), 0, "有 atlas 時沒有警告")
		var indices: Dictionary = WorldView.extract_atlas_indices(meta)
		th.check_eq(int(indices.get("grass", -1)), 0, "atlas grass = 0")
		th.check_eq(int(indices.get("wall", -1)), 2, "atlas wall = 2")
		th.check_eq(int(indices.get("player", -1)), 7, "atlas player = 7")
	else:
		th.skip("atlas 中繼資料", "找不到 assets/generated/placeholder_tiles.png 或 .json")

	root.add_child(view)
	await process_frame
	view.queue_free()
	await process_frame
	th.check_true(true, "WorldView 加入場景樹並繪製一帧不崩潰（視覺外觀未驗證）")


func _test_player_controller() -> void:
	th.section("PlayerController：逐格移動 Tween 與移動鎖")
	var player := PlayerController.new()
	player.configure(16)
	player.move_duration = 0.02
	root.add_child(player)
	player.place_at(Vector2i(2, 3))
	th.check_eq(player.position, Vector2(40, 56), "place_at 定位到格子中心")
	th.check_true(player.step_to(Vector2i(3, 3)), "step_to 開始移動")
	th.check_true(player.is_moving, "移動中 is_moving 為 true")
	th.check_false(player.step_to(Vector2i(4, 3)), "移動中不接受新移動")

	var frames: int = 0
	while player.is_moving and frames < 300:
		await process_frame
		frames += 1
	th.check_false(player.is_moving, "動畫結束後解除移動鎖")
	th.check_eq(player.grid_pos, Vector2i(3, 3), "動畫結束後格子座標更新")
	th.check_eq(player.position, Vector2(56, 56), "動畫結束後位置對齊格子中心")
	player.queue_free()
	await process_frame


func _test_main_scene() -> void:
	th.section("主場景：headless 載入 main.tscn")
	var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
	th.check_true(packed != null, "main.tscn 可載入")
	if packed == null:
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	th.check_true(instance.get("content") != null, "main 建立了 ContentRepository")
	var main_content: ContentRepository = instance.get("content")
	th.check_true(main_content != null, "content 不為 null")
	if main_content != null:
		th.check_false(main_content.content_dir.is_empty(), "有解析出的 content_dir")
	var content_ok: bool = main_content != null and main_content.is_ok()
	if content_ok:
		th.check_true(bool(instance.get("gameplay_ready")), "內容可用時遊戲就緒")
		var main_session: GameSession = instance.get("session")
		th.check_true(main_session != null, "session 建立")
		th.check_true(main_session.grid != null, "目前地圖格子建立")
		var error_panel: ErrorPanel = instance.get("error_panel")
		th.check_false(error_panel.is_showing(), "內容正常時不顯示 ErrorPanel")
		var hud: Hud = instance.get("hud")
		th.check_false(hud.status_text().is_empty(), "HUD 狀態列有內容")
	else:
		var error_panel: ErrorPanel = instance.get("error_panel")
		th.check_true(error_panel.is_showing(), "內容不可用時顯示 ErrorPanel（不崩潰）")
	instance.queue_free()
	await process_frame


# ---------------------------------------------------------------------------
# 真實內容（game-content）
# ---------------------------------------------------------------------------

func _test_touch_controls() -> void:
	th.section("觸控控制（Android 無鍵盤可操作性）")
	var controls := TouchControls.new()
	root.add_child(controls)
	controls.set_visibility_override(true)
	controls.size = Vector2(960, 540)
	var rects: Dictionary = controls.button_rects()
	for key: String in ["up", "down", "left", "right", "interact", "save", "load"]:
		th.check_true(rects.has(key), "有觸控區域：" + key)
		if rects.has(key):
			var rect: Rect2 = rects[key]
			th.check_true(rect.size.x >= 48.0 and rect.size.y >= 48.0, key + " 觸控區域 >= 48px")
	th.check_eq(controls.hit_test(rects["up"].get_center()), "up", "命中測試（上）")
	th.check_eq(controls.hit_test(Vector2(480, 300)), "", "世界區域不命中按鈕")

	var seen: Array = []
	controls.move_pressed.connect(func(direction: Vector2i) -> void: seen.append(direction))
	controls._input(_touch_event(rects["up"].get_center(), true))
	th.check_eq(seen.size(), 1, "按下方向鍵發出 move_pressed")
	th.check_eq(seen[0], Vector2i.UP, "方向正確（上）")
	controls._input(_touch_event(rects["up"].get_center(), false))
	th.check_eq(seen.size(), 1, "放開不重複觸發")

	# 按住連走
	seen.clear()
	controls._input(_touch_event(rects["right"].get_center(), true))
	var after_press: int = seen.size()
	controls._process(HOLD_DELAY_TEST + 0.001)
	controls._process(REPEAT_INTERVAL_TEST)
	th.check_true(seen.size() > after_press, "按住方向鍵會連走")
	if seen.size() > 0:
		th.check_eq(seen[seen.size() - 1], Vector2i.RIGHT, "連走方向正確")
	controls._input(_touch_event(rects["right"].get_center(), false))

	# 動作按鈕
	var counts: Dictionary = {"interact": 0, "save": 0, "load": 0}
	controls.interact_pressed.connect(func() -> void: counts["interact"] += 1)
	controls.save_pressed.connect(func() -> void: counts["save"] += 1)
	controls.load_pressed.connect(func() -> void: counts["load"] += 1)
	for key: String in ["interact", "save", "load"]:
		controls._input(_touch_event((rects[key] as Rect2).get_center(), true))
		controls._input(_touch_event((rects[key] as Rect2).get_center(), false))
	th.check_eq(counts["interact"], 1, "互動鍵發出 interact_pressed")
	th.check_eq(counts["save"], 1, "存檔鍵發出 save_pressed")
	th.check_eq(counts["load"], 1, "讀檔鍵發出 load_pressed")

	# 世界輕點 = 互動
	counts["interact"] = 0
	var world_point := Vector2(480, 300)
	controls._input(_touch_event(world_point, true))
	controls._input(_touch_event(world_point, false))
	th.check_eq(counts["interact"], 1, "世界輕點發出 interact_pressed")

	# 世界滑動 = 移動
	seen.clear()
	controls._input(_touch_event(world_point, true))
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = world_point + Vector2(90, 10)
	controls._input(drag)
	controls._input(_touch_event(world_point + Vector2(90, 10), false))
	th.check_true(seen.size() >= 1, "世界滑動會發出 move_pressed")
	if seen.size() >= 1:
		th.check_eq(seen[0], Vector2i.RIGHT, "滑動方向正確（右）")

	# 對話中不攔截
	controls.set_input_blocked(true)
	seen.clear()
	controls._input(_touch_event(rects["down"].get_center(), true))
	th.check_eq(seen.size(), 0, "對話中觸控控制不移動")
	controls.set_input_blocked(false)

	# 隱藏時不處理輸入
	controls.set_visibility_override(false)
	seen.clear()
	controls._input(_touch_event(rects["down"].get_center(), true))
	th.check_eq(seen.size(), 0, "隱藏時不處理觸控")
	controls.set_visibility_override(true)
	controls.queue_free()


func _touch_event(point: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = point
	event.pressed = pressed
	return event


func _test_real_content() -> void:
	th.section("真實內容：game-content（app_data_git）")
	if real_content_dir.is_empty():
		th.skip("真實內容載入", "未提供 --content-dir")
		return
	if not FileAccess.file_exists(real_content_dir + "/manifest.json"):
		th.skip("真實內容載入", "game-content 尚無 manifest.json：" + real_content_dir)
		return
	var repo: ContentRepository = _load_repo(real_content_dir)
	_print_repo(repo, "game-content")
	th.check_true(repo.is_ok(), "真實內容載入無錯誤")
	if not repo.is_ok():
		return
	th.check_eq(repo.content_id, "base_world", "content_id base_world")
	th.check_eq(repo.content_version, "0.1.0", "content_version 0.1.0")
	th.check_eq(repo.maps.size(), 2, "真實內容 2 張地圖")
	th.check_eq(repo.npcs.size(), 1, "真實內容 1 個 NPC")
	th.check_eq(repo.items.size(), 1, "真實內容 1 個道具")
	th.check_eq(repo.events.size(), 2, "真實內容 2 個事件")
	th.check_eq(repo.get_start_map_id(), "map_start_village", "真實內容起始地圖")
	var village: Dictionary = repo.get_map("map_start_village")
	th.check_eq(village.size(), 9, "地圖資料欄位數")
	var village_grid := MapGrid.from_map_data(village)
	th.check_eq(village_grid.width, 12, "起始村落 width 12")
	th.check_eq(village_grid.height, 9, "起始村落 height 9")
	th.check_eq(village_grid.spawn, Vector2i(3, 6), "起始村落 spawn")
	th.check_true(village_grid.can_enter(village_grid.spawn), "spawn 可進入")
	th.check_false(village_grid.portal_at(Vector2i(10, 7)).is_empty(), "起始村落 portal 在 (10,7)")
	th.check_eq(String(village_grid.portal_at(Vector2i(10, 7)).get("target_map_id", "")), "map_forest_edge", "portal 目標森林")
	var chest_event: Dictionary = repo.get_event("event_chest_herb_001")
	th.check_false(chest_event.is_empty(), "寶箱事件存在")
	th.check_false(bool(chest_event.get("repeatable", true)), "寶箱事件 repeatable=false")


# Hud 測試用存取器（避免測試直接碰私有欄位）
func _dummy_hud_reference() -> void:
	pass
