extends Node
## 主場景根節點：組裝內容載入器、遊戲流程、世界畫面與 UI。
##
## 職責邊界：
## - ContentRepository：載入與驗證外部內容（game-content 或 res://content）。
## - GameSession：純遊戲邏輯（移動、互動、對話、effects、portal、存讀檔還原）。
## - 本節點：把輸入、畫面、UI 與上述邏輯連接起來；不做規則判斷。
##
## 內容目錄解析順序：CLI `--content-dir=` > ProjectSettings `game/content_dir`
## > res://content。缺少內容時顯示 ErrorPanel，不崩潰、不進入遊戲。

const GAME_VERSION := "0.3.1"
const ATLAS_TEXTURE_PATH := "res://assets/generated/placeholder_tiles.png"
const ATLAS_META_PATH := "res://assets/generated/placeholder_tiles.json"
const CAMERA_ZOOM := 3

var content: ContentRepository
var state: GameState
var session: GameSession
var save_manager: SaveManager

var world_view: WorldView
var player: PlayerController
var camera: Camera2D
var hud: Hud
var dialogue_panel: DialoguePanel
var error_panel: ErrorPanel
var touch_controls: TouchControls
var update_panel: UpdatePanel
var update_checker: UpdateChecker
var title_screen: TitleScreen
var ui_layer: CanvasLayer

var atlas_texture: Texture2D
var atlas_meta: Dictionary = {}
var content_dir_used: String = ""
var gameplay_ready: bool = false
var _pending_update_apk: String = ""


func _ready() -> void:
	print("[main] game v%s｜Godot %s" % [GAME_VERSION, Engine.get_version_info().get("string", "?")])
	content = ContentRepository.new()
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	var project_content_dir: String = String(ProjectSettings.get_setting("game/content_dir", ""))
	content_dir_used = ContentRepository.resolve_content_dir(user_args, project_content_dir)
	print("[main] content_dir=", content_dir_used)
	content.load_content(content_dir_used)
	print("[main] content: ", content.summary())
	for error_text: String in content.errors:
		print("[content-error] ", error_text)
	for warning_text: String in content.warnings:
		print("[content-warning] ", warning_text)

	_build_ui()
	if not content.is_ok():
		_show_content_failure()
		return
	_start_game()


func _start_game() -> void:
	state = GameState.new()
	session = GameSession.new()
	if not session.setup(content, state):
		error_panel.show_errors(["無法初始化遊戲流程（內容沒有可用地圖）"], content.warnings, "啟動失敗")
		return
	save_manager = SaveManager.new()
	_load_atlas()
	_build_world()
	_wire_signals()
	gameplay_ready = true
	_on_map_changed(session.state.current_map_id, session.state.player_grid)
	print("[main] 遊戲就緒：地圖 %s，玩家 %s" % [session.state.current_map_id, str(session.state.player_grid)])
	_setup_auto_updates()
	_show_title()


# ---------------------------------------------------------------------------
# 建構
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	add_child(ui_layer)

	hud = Hud.new()
	hud.name = "HUD"
	ui_layer.add_child(hud)

	dialogue_panel = DialoguePanel.new()
	ui_layer.add_child(dialogue_panel)

	error_panel = ErrorPanel.new()
	ui_layer.add_child(error_panel)

	update_panel = UpdatePanel.new()
	update_panel.name = "UpdatePanel"
	ui_layer.add_child(update_panel)
	update_panel.install_requested.connect(_on_install_update_requested)

	title_screen = TitleScreen.new()
	title_screen.name = "TitleScreen"
	ui_layer.add_child(title_screen)
	title_screen.start_game.connect(_on_title_start_game)
	title_screen.continue_game.connect(_on_title_continue_game)
	title_screen.check_updates.connect(_on_title_check_updates)
	title_screen.set_version(GAME_VERSION)
	title_screen.close()

	touch_controls = TouchControls.new()
	ui_layer.add_child(touch_controls)
	touch_controls.move_pressed.connect(_on_touch_move)
	touch_controls.interact_pressed.connect(_request_interact)
	touch_controls.save_pressed.connect(_save_game)
	touch_controls.load_pressed.connect(_load_game)

	dialogue_panel.advance_requested.connect(_on_dialogue_advance_requested)
	dialogue_panel.choice_selected.connect(_on_dialogue_choice_selected)


func _build_world() -> void:
	world_view = WorldView.new()
	world_view.name = "WorldView"
	add_child(world_view)

	player = PlayerController.new()
	player.name = "Player"
	player.configure(session.grid.tile_size)
	player.set_atlas(atlas_texture, WorldView.extract_atlas_indices(atlas_meta))
	add_child(player)

	camera = Camera2D.new()
	camera.name = "Camera"
	camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	camera.position_smoothing_enabled = false
	player.add_child(camera)
	camera.make_current()


func _wire_signals() -> void:
	session.map_changed.connect(_on_map_changed)
	session.player_moved.connect(_on_player_moved)
	session.dialogue_line_changed.connect(_on_dialogue_line_changed)
	session.dialogue_choices_ready.connect(_on_dialogue_choices_ready)
	session.dialogue_finished.connect(_on_dialogue_finished)
	session.notice.connect(_on_notice)
	player.move_finished.connect(_on_player_move_finished)


func _load_atlas() -> void:
	atlas_texture = null
	atlas_meta = {}
	if ResourceLoader.exists(ATLAS_TEXTURE_PATH):
		var resource: Resource = load(ATLAS_TEXTURE_PATH)
		if resource is Texture2D:
			atlas_texture = resource
		else:
			print("[atlas-warning] placeholder_tiles.png 無法載入為 Texture2D")
	else:
		print("[atlas-warning] 找不到 ", ATLAS_TEXTURE_PATH, "（使用色塊佔位）")
	if FileAccess.file_exists(ATLAS_META_PATH):
		var file := FileAccess.open(ATLAS_META_PATH, FileAccess.READ)
		if file != null:
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
				atlas_meta = json.data
			file.close()
	if atlas_texture == null:
		hud.show_notice("找不到 placeholder atlas，使用色塊佔位", 6.0)


func _show_content_failure() -> void:
	var title: String = "找不到內容" if content.content_id.is_empty() else "內容載入失敗"
	error_panel.show_errors(content.errors if not content.errors.is_empty() else ["找不到內容"], content.warnings, title)
	hud.set_status("內容不可用（%d 個錯誤）" % content.errors.size())


# ---------------------------------------------------------------------------
# 輸入
# ---------------------------------------------------------------------------

func _title_active() -> bool:
	return title_screen != null and title_screen.visible


func _show_title() -> void:
	if title_screen == null:
		return
	title_screen.set_version(GAME_VERSION)
	title_screen.set_continue_available(FileAccess.file_exists(SaveManager.DEFAULT_SAVE_PATH))
	title_screen.open()
	if touch_controls != null:
		touch_controls.visible = false


func _on_title_start_game() -> void:
	if title_screen != null:
		title_screen.close()
	if touch_controls != null:
		touch_controls.refresh_visibility()
	_retry_pending_update()
	if hud != null:
		hud.show_notice("冒險開始", 2.5)


func _on_title_continue_game() -> void:
	if not FileAccess.file_exists(SaveManager.DEFAULT_SAVE_PATH):
		if hud != null:
			hud.show_notice("尚無存檔", 3.0)
		return
	_load_game()
	if title_screen != null:
		title_screen.close()
	if touch_controls != null:
		touch_controls.refresh_visibility()
	_retry_pending_update()


func _on_title_check_updates() -> void:
	if update_checker != null:
		update_checker.start()
	else:
		if hud != null:
			hud.show_notice("更新元件尚未就緒", 3.0)


func _unhandled_input(event: InputEvent) -> void:
	if _title_active():
		return
	if error_panel != null and error_panel.is_showing() and event is InputEventKey:
		var key_event: InputEventKey = event
		if key_event.pressed and key_event.keycode == KEY_ESCAPE:
			error_panel.hide_panel()
			return
	if not gameplay_ready:
		return
	if event.is_action_pressed("save_game"):
		_save_game()
		return
	if event.is_action_pressed("load_game"):
		_load_game()
		return
	if session.is_in_dialogue():
		_handle_dialogue_input(event)
		return
	if event.is_action_pressed("interact"):
		_request_interact()


func _movement_direction(event: InputEvent) -> Vector2i:
	if event.is_action_pressed("move_up"):
		return Vector2i.UP
	if event.is_action_pressed("move_down"):
		return Vector2i.DOWN
	if event.is_action_pressed("move_left"):
		return Vector2i.LEFT
	if event.is_action_pressed("move_right"):
		return Vector2i.RIGHT
	return Vector2i.ZERO


func _handle_dialogue_input(event: InputEvent) -> void:
	if dialogue_panel.has_choices():
		if event is InputEventKey:
			var key_event: InputEventKey = event
			if key_event.pressed and not key_event.echo:
				var choice_index: int = key_event.keycode - KEY_1
				if choice_index >= 0 and choice_index < dialogue_panel.choice_count():
					dialogue_panel.press_choice(choice_index)
		return
	if event.is_action_pressed("interact"):
		session.advance_dialogue()


# ---------------------------------------------------------------------------
# 連續移動（鍵盤按住／觸控方向鍵按住都由這裡輪詢）
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if not gameplay_ready or _title_active():
		return
	if session == null or player == null:
		return
	if session.is_in_dialogue() or player.is_moving:
		return
	var direction: Vector2i = _held_move_direction()
	if direction != Vector2i.ZERO:
		_request_move(direction)


func _held_move_direction() -> Vector2i:
	if Input.is_action_pressed("move_up"):
		return Vector2i.UP
	if Input.is_action_pressed("move_down"):
		return Vector2i.DOWN
	if Input.is_action_pressed("move_left"):
		return Vector2i.LEFT
	if Input.is_action_pressed("move_right"):
		return Vector2i.RIGHT
	if touch_controls != null and touch_controls.visible:
		var touch_direction: Vector2i = touch_controls.get_held_direction()
		if touch_direction != Vector2i.ZERO:
			return touch_direction
	return Vector2i.ZERO


# ---------------------------------------------------------------------------
# 移動與互動
# ---------------------------------------------------------------------------

func _request_move(direction: Vector2i) -> void:
	if player.is_moving:
		return
	var result: Dictionary = session.try_move(direction)
	if not bool(result.get("moved", false)):
		return
	if not player.step_to(result.get("target", state.player_grid)):
		session.abort_pending_move()
		return
	hud.set_prompt("")


func _try_interact() -> void:
	if session.can_interact():
		session.start_interaction()


## 互動統一入口：對話中 → 推進對話；探索中 → 觸發面向物件的互動。
## 鍵盤（E/Space/Enter）與觸控「互動」鍵都走這裡。
func _request_interact() -> void:
	if session == null or not gameplay_ready or _title_active():
		return
	if session.is_in_dialogue():
		if dialogue_panel.has_choices():
			return
		session.advance_dialogue()
		return
	_try_interact()


## 觸控方向鍵：一次一格；對話中不移動。
func _on_touch_move(direction: Vector2i) -> void:
	if not gameplay_ready or session == null or _title_active():
		return
	if session.is_in_dialogue():
		return
	_request_move(direction)


func _on_player_move_finished(_to_cell: Vector2i) -> void:
	var result: Dictionary = session.complete_move()
	_update_status()
	if bool(result.get("portal", false)):
		var transition: Dictionary = result.get("transition", {})
		if bool(transition.get("ok", false)):
			hud.show_notice("進入 " + session.grid.display_name)
	else:
		_update_prompt()


# ---------------------------------------------------------------------------
# Session / UI 訊號
# ---------------------------------------------------------------------------

func _on_map_changed(_map_id: String, grid: Vector2i) -> void:
	if world_view == null or session.grid == null:
		return
	world_view.build(session.grid, atlas_texture, atlas_meta)
	if player != null:
		player.place_at(grid)
	_update_status()
	_update_prompt()
	dialogue_panel.hide_panel()


func _on_player_moved(_from_cell: Vector2i, _to_cell: Vector2i) -> void:
	_update_status()
	_update_prompt()


func _on_dialogue_line_changed(speaker: String, text: String, line_index: int, total_lines: int) -> void:
	_sync_touch_blocking()
	dialogue_panel.show_line(speaker, text, line_index, total_lines)
	hud.set_prompt("")


func _on_dialogue_choices_ready(choice_texts: Array[String]) -> void:
	_sync_touch_blocking()
	dialogue_panel.show_choices(choice_texts)


func _on_dialogue_finished() -> void:
	_sync_touch_blocking()
	dialogue_panel.hide_panel()
	_update_prompt()


func _on_dialogue_advance_requested() -> void:
	session.advance_dialogue()


func _on_dialogue_choice_selected(choice_index: int) -> void:
	var result: Dictionary = session.choose(choice_index)
	if not bool(result.get("ok", false)):
		var choice_errors: Array = result.get("errors", [])
		error_panel.show_errors(choice_errors, [], "選項套用失敗")
	_update_status()
	_update_prompt()


# ---------------------------------------------------------------------------
# 自動更新（本體 APK + 內容 DATA）
# ---------------------------------------------------------------------------

## 啟動時自動檢查更新；不阻擋遊戲，失敗只顯示訊息。
func _setup_auto_updates() -> void:
	if update_checker != null:
		return
	update_checker = UpdateChecker.new()
	update_checker.name = "UpdateChecker"
	add_child(update_checker)
	update_checker.status_changed.connect(_on_update_status)
	update_checker.app_update_ready.connect(_on_app_update_ready)
	update_checker.app_update_result.connect(_on_app_update_result)
	update_checker.data_update_result.connect(_on_data_update_result)
	update_checker.check_finished.connect(_on_update_check_finished)
	update_checker.start()


func _on_update_status(text: String) -> void:
	if update_panel != null:
		update_panel.show_status(text)
	if title_screen != null:
		title_screen.set_status(text)


func _on_app_update_ready(info: Dictionary) -> void:
	if update_panel != null:
		update_panel.show_status("更新已下載（%s），開啟安裝程式…" % String(info.get("version", "")))


func _on_app_update_result(result: Dictionary) -> void:
	var path := String(result.get("path", ""))
	if bool(result.get("ok", false)) or bool(result.get("pending", false)):
		_pending_update_apk = path if not path.is_empty() else _pending_update_apk
	if bool(result.get("ok", false)):
		_pending_update_apk = path
		if update_panel != null:
			update_panel.show_install_button(path, "請在系統視窗完成安裝")
		return
	_pending_update_apk = path
	var message := String(result.get("error", "安裝失敗"))
	if update_panel != null:
		update_panel.show_install_button(path, message + "（點此重試）")
	if hud != null:
		hud.show_notice(message, 6.0)


func _on_data_update_result(result: Dictionary) -> void:
	if bool(result.get("ok", false)):
		if hud != null:
			hud.show_notice("內容已更新至 %s，下次啟動生效" % String(result.get("version", "")), 6.0)
		if update_panel != null:
			update_panel.show_status("內容已更新（下次啟動生效）")
	else:
		if hud != null:
			hud.show_notice("內容更新失敗，維持現有內容", 5.0)


func _on_update_check_finished() -> void:
	if update_panel == null:
		return
	if not update_panel.has_install_action():
		update_panel.hide_panel()


## 從系統設定返回或重新回到前景時，自動重試已下載的更新安裝。
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_retry_pending_update()


func _retry_pending_update() -> void:
	if _pending_update_apk.is_empty() or not FileAccess.file_exists(_pending_update_apk):
		return
	var result := AndroidInstaller.install_apk(_pending_update_apk)
	if bool(result.get("ok", false)):
		_pending_update_apk = ""
		if update_panel != null:
			update_panel.show_status("已開啟系統安裝程式")


func _on_install_update_requested(path: String) -> void:
	var result := AndroidInstaller.install_apk(path)
	if bool(result.get("ok", false)):
		if update_panel != null:
			update_panel.show_status("請在系統視窗完成安裝")
	else:
		var message := String(result.get("error", "無法開啟安裝程式"))
		if update_panel != null:
			update_panel.show_install_button(path, message + "（點此重試）")
		if hud != null:
			hud.show_notice(message, 6.0)


func _sync_touch_blocking() -> void:
	if touch_controls == null:
		return
	touch_controls.set_input_blocked(session != null and session.is_in_dialogue())


func _on_notice(text: String) -> void:
	hud.show_notice(text)


# ---------------------------------------------------------------------------
# HUD 更新
# ---------------------------------------------------------------------------

func _update_status() -> void:
	if hud == null or session == null or session.grid == null:
		return
	hud.set_status("%s｜格子 (%d, %d)｜%s｜旗標 %d｜物品 %d" % [
		session.grid.display_name,
		state.player_grid.x,
		state.player_grid.y,
		GameState.facing_to_name(state.facing),
		state.flags.size(),
		state.inventory.size(),
	])


func _update_prompt() -> void:
	_sync_touch_blocking()
	if hud == null or session == null or not gameplay_ready:
		return
	if session.is_in_dialogue():
		hud.set_prompt("")
		return
	if session.can_interact():
		var entity: Dictionary = session.get_interaction_target()
		hud.set_prompt("互動：" + _entity_display_name(entity))
	else:
		hud.set_prompt("")


func _entity_display_name(entity: Dictionary) -> String:
	if entity.is_empty():
		return ""
	var npc: Dictionary = content.get_npc(String(entity.get("id", "")))
	if not npc.is_empty():
		return String(npc.get("name", ""))
	var display_key: String = String(entity.get("display_key", ""))
	if not display_key.is_empty():
		return display_key
	return String(entity.get("id", ""))


# ---------------------------------------------------------------------------
# 存讀檔
# ---------------------------------------------------------------------------

func _save_game() -> void:
	if save_manager == null or session == null:
		return
	var result: Dictionary = save_manager.save_state(state, content.content_version)
	if bool(result.get("ok", false)):
		hud.show_notice("已存檔：%s（%d bytes）" % [result.get("path", ""), int(result.get("bytes", 0))])
		print("[save] ok path=%s bytes=%d" % [result.get("path", ""), int(result.get("bytes", 0))])
	else:
		hud.show_notice("存檔失敗：" + String(result.get("error", "未知錯誤")))
		error_panel.show_errors([String(result.get("error", "未知錯誤"))], [], "存檔失敗")


func _load_game() -> void:
	if save_manager == null or session == null:
		return
	var loaded: Dictionary = save_manager.load_save(SaveManager.DEFAULT_SAVE_PATH)
	if not bool(loaded.get("ok", false)):
		var load_errors: Array = loaded.get("errors", [String(loaded.get("error", "讀檔失敗"))])
		hud.show_notice("讀檔失敗：" + String(loaded.get("error", "")))
		error_panel.show_errors(load_errors, [], "讀檔失敗")
		return
	var restored: Dictionary = session.restore_from_save(loaded.get("data", {}))
	if not bool(restored.get("ok", false)):
		error_panel.show_errors(restored.get("errors", []), [], "存檔還原失敗")
		return
	if not (restored.get("warnings", []) as Array).is_empty():
		var warnings: Array = restored.get("warnings", [])
		error_panel.show_errors([], warnings, "讀檔警告")
	_update_status()
	_update_prompt()
	hud.show_notice("已讀取存檔")
	print("[load] ok map=%s grid=%s" % [session.state.current_map_id, str(session.state.player_grid)])
