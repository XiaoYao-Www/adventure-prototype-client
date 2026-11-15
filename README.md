# game-client（Godot 4.7.2）

Android 優先、2D、格子式移動的冒險探索 RPG 遊戲本體。
本倉庫只放**程式、場景、UI、輸入、規則、內容載入器、存檔與測試**；
世界、地圖、事件、NPC、物品等內容放在另一個倉庫 `game-content`（工作區 `../app_data_git/`）。

目前版本：**0.2.1（自動更新／release 管線）**。

## 本輪已實作（v0.1）

- 格子移動：WASD／方向鍵一次一格，Tween 平滑移動；牆／水／樹與實體阻擋、不可越界；
  移動中不接受新輸入。
- 互動：面向格上的 NPC／物件顯示「E 互動」，按 E／Space／Enter 觸發事件。
- 對話框：說話者名稱（`player` 顯示「你」）、逐句顯示、最後一句後關閉；
  有 choices 時顯示按鈕，支援滑鼠點擊與數字鍵 1..N，選擇後套用 effects 再關閉。
- Effects：僅 `set_flag`（flag + bool value）與 `give_item`（item_id + 正整數 qty）；
  未知 type 或參數錯誤 → 該事件載入失敗並記錄錯誤，不崩潰、不推測執行。
- Portal：踏上傳送格切換地圖、重建 WorldView、放到 target_grid；抵達格有 portal 時
  以「抵達抑制」避免立即反向觸發。
- 存檔：F5 存、F9 讀，`user://save_01.json`；save_version=1、內容版本與玩家進度分離。
- 內容載入：manifest → sha256/size 驗證 → schema/引用完整性驗證 → 可讀錯誤；
  來源優先序 CLI `--content-dir=` > ProjectSettings `game/content_dir` > `res://content`。
- 畫面：`_draw` 繪製格子與實體（v0.1 不用 TileMapLayer），placeholder atlas 或色塊備援；
  Camera2D 整數 3x 縮放跟隨玩家。
- 觸控輸入：自繪方向鍵（可按住連走）＋互動＋存檔／讀檔；世界區域可滑動轉向與輕點互動。Android/mobile 顯示、桌機隱藏；對話開啟時不攔截對話框點擊。
- 畫面：橫向遊玩（sensor landscape，左右橫置皆可）。
- Headless 測試：332 項斷言（fixtures + 真實 game-content，實測 332/332）。
- 自動更新：啟動時檢查 GitHub Releases 的本體更新（下載 APK→驗 sha256→開啟系統安裝）與內容更新（下載內容包→驗證→user:// 安裝，下次啟動生效）。
- 發布：推送 `v*` tag 由 GitHub Actions 自動建立 release 並附上 APK 與 `update/latest.json`。

## 目錄結構

```text
game-client/
├── AGENTS.md                  # 本倉庫工作區指令
├── README.md
├── project.godot              # 960x540、canvas_items/expand、gl_compatibility、input map
├── scenes/main.tscn           # 最小場景：根 Node + scripts/core/main.gd
├── scripts/
│   ├── core/main.gd           # 主場景：組裝內容/流程/畫面/UI（新增檔，見下方說明）
│   ├── core/game_state.gd     # 玩家進度（flags/inventory/位置/completed_event_ids）
│   ├── core/game_session.gd   # 純遊戲流程：移動/互動/對話/effects/portal/存檔還原（新增檔）
│   ├── content/content_repository.gd
│   ├── grid/grid_map.gd       # class_name MapGrid（避免與 Godot 內建 GridMap 衝突）
│   ├── player/player_controller.gd
│   ├── world/world_view.gd
│   ├── ui/{dialogue_panel,hud,error_panel}.gd
│   └── save/save_manager.gd
├── content/                   # res://content：建置快照（由 tools/sync_content_bundle.mjs 從 game-content 產生）
├── assets/generated/          # placeholder atlas（由 Captain 的產生器生成）
├── tests/
│   ├── run_tests.gd           # headless 測試入口（extends SceneTree）
│   ├── test_helper.gd         # 可重用斷言輔助
│   ├── fixtures/              # 獨立於 game-content 的內容載入器 fixture
│   └── tools/generate_manifests.gd  # 開發工具：重算 fixture manifest（res://content 由 sync 工具管理）
└── docs/
    ├── architecture/CONTENT_CONTRACT.md
    ├── architecture/SAVE_FORMAT.md
    ├── ASSETS.md
    ├── BUILD.md
    └── project/               # 由 Captain 維護（狀態/決策/紀錄），程式 Worker 不寫
```

### 與任務規格的結構差異（已於此說明）

- 任務規格列出的 `scripts/` 沒有 `main.gd`；`main.tscn` 需要腳本，因此放在
  `scripts/core/main.gd`，並額外新增 `scripts/core/game_session.gd`，
  把可測試的遊戲流程與畫面／節點組裝分離（session 為純邏輯，不建立節點）。
- `grid_map.gd` 的 `class_name` 使用 `MapGrid`，避免與 Godot 內建 3D `GridMap` 類別同名。
- `res://content/` 是 APK 內建建置快照（來源 `game-content 0.1.0`，由 `tools/sync_content_bundle.mjs` 產生）；
  正式內容一律以 `game-content` 為權威來源，不手動編輯此目錄。

## 執行

### 需要 Godot 4.7.2

```bash
export G=/workspace/自動遊戲開發/tools/godot/Godot_v4.7.2-stable_linux.x86_64
export HOME=/workspace/自動遊戲開發/tools/home
export XDG_CONFIG_HOME=$HOME/config XDG_DATA_HOME=$HOME/data
```

```bash
# 匯入（第一次或資產變更後）
timeout 120 "$G" --headless --path . --import

# 用 game-content 真實內容啟動（headless 驗證 120 幀）
timeout 120 "$G" --headless --path . --quit-after 120 -- \
  --content-dir=/workspace/自動遊戲開發/app_data_git

# 使用內建建置快照內容（game-content 0.1.0）
timeout 120 "$G" --headless --path . --quit-after 120
```

Windows／Android 上以 Godot 編輯器開啟 `project.godot` 後直接執行即可（本輪未在
Windows 或 Android 驗證；見 `docs/BUILD.md`）。

## 測試

```bash
timeout 120 "$G" --headless --path . --script res://tests/run_tests.gd \
  -- --content-dir=/workspace/自動遊戲開發/app_data_git
```

輸出最後一行為 `TESTS OK n/n` 或 `TESTS FAILED ...`，exit code 0/1。
沒有提供 `--content-dir` 時，真實內容測試會標記 `[SKIP]`，不以通過論。

## 文件

- 內容資料契約與驗證規則：[docs/architecture/CONTENT_CONTRACT.md](docs/architecture/CONTENT_CONTRACT.md)
- 存檔格式：[docs/architecture/SAVE_FORMAT.md](docs/architecture/SAVE_FORMAT.md)
- 素材與 placeholder atlas：[docs/ASSETS.md](docs/ASSETS.md)
- 建置與 headless 驗證：[docs/BUILD.md](docs/BUILD.md)

## 已知限制（v0.1）

- 視覺外觀（版面、色彩、縮放、對話框排版）**未經驗證**：環境無 GPU／顯示器，只驗證
  節點建立與 headless 執行。
- Android 建置與實機安裝**未執行**：環境沒有 Java／Android SDK／export templates。
- 沒有觸控操作（輸入 map 只有鍵盤）；Android 版需要後續補觸控與安全區排版。
- `repeatable` 事件記錄寫入存檔；`repeatable: true` 的事件可重複互動。
- 未實作：戰鬥、成人內容模組、下載器、TileMapLayer、存檔遷移（save_version > 1）。

## Android APK（v0.1，debug 簽章）

- 成品：[`releases/android/adventure-prototype-0.2.1-debug.apk`](releases/android/adventure-prototype-0.2.1-debug.apk)
  （約 35.6 MiB；建置資訊與 SHA-256 見 `releases/android/BUILD_INFO.md`）。
- 套件：`com.dsh.adventureprototype`、versionCode 1、versionName 0.1.0、minSdk 24、targetSdk 36、**arm64-v8a only**。
- 螢幕方向：橫向（sensor landscape）。
- **debug 簽章**（CN=Android Debug），只供安裝測試，不可用於商店發布。
- 安裝：`adb install -r releases/android/adventure-prototype-0.2.1-debug.apk`
  （Android 7.0 以上、arm64 裝置）。
- 本輪**未在實機或模擬器安裝驗證**（本環境無 Android 裝置）；觸控按鈕已實作但未經真機操作測試。
- 重建：見 `docs/BUILD.md`，或工作區 `tools/build_android.sh`。
