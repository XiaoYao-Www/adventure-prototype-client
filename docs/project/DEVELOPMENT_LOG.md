# 開發紀錄

> 只記錄已發生的事實；每項測試記錄實際命令與結果。未執行的測試標記「未執行」。

## 2026-11-16 — Phase 0–3：環境盤點、雙倉庫骨架、第一個垂直切片 v0.1

### 目標

完成 Phase 0 盤點、Phase 2 文件與倉庫骨架、Phase 3 第一個垂直切片（格子探索 + 外部內容載入），
並以可重現命令驗證（CPU-only、headless）。

### 前置盤點（實際結果）

- 工作區：`/workspace/自動遊戲開發`（sandbox workspace-write）。
- 倉庫：`app_base_git`、`app_data_git`，皆 `master`、無 commit、無 remote、僅有模板 `*_AGENTS.md`。
  git 需以 `-c safe.directory='*'` 才能讀取（目錄 owner 為 nobody）。
- 環境：Debian 12、x86_64、i7-8700 6C/12T、15GB RAM、無 GPU、無顯示器、無 Java／Android SDK、
  無 preinstalled Godot、無 python3；Node v24.21.0、curl、unzip 可用；網路可用。
- Godot 最新 stable = 4.7.2（官方 GitHub release，2026-08-18）；經使用者核准下載
  Linux x86_64 版至 `tools/godot/`（74.3MB，MIT），實測 `--version` = `4.7.2.stable.official.ed1daf0bf`。
- 使用者決策：核准下載 Godot、確認倉庫映射、授權本地 commit（不 push、不改 remote）。

### 變更摘要

**game-client（`app_base_git`）**

- Godot 專案：`project.godot`（960×540、canvas_items+expand、gl_compatibility、input map）、
  `scenes/main.tscn`、`scripts/`（main、game_state、game_session、content_repository、grid_map、
  player_controller、world_view、dialogue_panel、hud、error_panel、save_manager）、`tests/`。
- 功能：格子移動與碰撞、面向格互動、逐句對話與選項、effects（set_flag/give_item）、
  portal 與抵達抑制、F5/F9 存檔讀檔、manifest sha256/size 驗證、schema/引用完整性檢查、
  缺內容顯示 ErrorPanel、`repeatable:false` 以 `completed_event_ids` 防重複。
- 內容工具（Lead）：`tools/validate_content.mjs`、`tools/build_content_manifest.mjs`、
  `tools/generate_placeholder_tiles.mjs`、`tools/tests/content_tools.test.mjs`。
- 暫代素材：`assets/generated/placeholder_tiles.png`（16×16、8 格橫排、專案自行生成、無第三方權利）。
- 文件：`AGENTS.md`、`README.md`、`docs/architecture/{CONTENT_CONTRACT,SAVE_FORMAT}.md`、
  `docs/{ASSETS,BUILD}.md`、`docs/project/*`。

**game-content（`app_data_git`）**

- `manifest.json`（`base_world 0.1.0`、`schema_version 1`、`min_game_version 0.1.0`、7 檔／4525 bytes）。
- `schemas/` 6 個（manifest/region/map/npc/item/event）；`docs/CONTENT_SCHEMA.md`、`ASSET_POLICY.md`、
  `CONTENT_CHANGELOG.md`；`world/`（1 區域、2 地圖）、`characters/npcs/`（1 NPC）、
  `items/`（1 道具）、`events/`（2 事件）；`asset_catalog/`、`optional_content/adult/`、`releases/` 佔位。
- 全部世界觀內容標示「暫定」，不是正史。

### 測試與驗證（實際命令與結果）

| 命令 | 結果 |
| --- | --- |
| `node --test app_base_git/tools/tests/content_tools.test.mjs` | 9/9 pass（合法內容、雜湊篡改、列長、legend、未知 effect、可執行檔、portal 落點、schema 必填、manifest 過期） |
| `node app_base_git/tools/validate_content.mjs app_data_git` | CONTENT OK，0 errors／0 warnings |
| `node app_base_git/tools/build_content_manifest.mjs app_data_git --check` | MANIFEST OK，7 檔／4525 bytes |
| `node app_base_git/tools/validate_content.mjs app_base_git/content` | CONTENT OK（2 warnings：bootstrap 非完整內容包、無 docs） |
| `godot --headless --path app_base_git --import` | exit 0，無 GDScript 錯誤 |
| `godot --headless --path app_base_git --script res://tests/run_tests.gd -- --content-dir=app_data_git` | **TESTS OK 265/265**，0 SKIP |
| `godot --headless --path app_base_git --quit-after 120` | exit 0，`遊戲就緒：地圖 map_boot_village，玩家 (1, 1)` |
| 同上加 `-- --content-dir=app_data_git` | exit 0，`地圖 map_start_village，玩家 (3, 6)` |
| 同上加 `-- --content-dir=/tmp/definitely_missing_content` | exit 0，`E_NO_MANIFEST` 與 ErrorPanel，不崩潰 |
| `bash tools/checks.sh`（工作區整合腳本） | ALL CHECKS PASSED |

### 過程中發現並修正的問題

- `generate_placeholder_tiles.mjs`／`validate_content.mjs` 用 `new URL(import.meta.url).pathname`
  解析路徑，遇到非 ASCII 工作區路徑會 percent-encode，導致 CLI 靜默不執行；
  已改用 `fileURLToPath`。
- 內容驗證器原本只掃描 `docs/`、`schemas/` 等目錄，未掃描內容資料目錄中的可執行檔；
  已將資料目錄納入掃描。
- client 內建 bootstrap 內容的兩個 portal 落點等於目標地圖的 portal 格（會造成立即反向傳送），
  已改為目標地圖的其他可通行格並重建 bootstrap manifest；修正後獨立驗證器通過、265/265 測試仍通過。

### 未執行（不得視為通過）

- 畫面外觀、UI 版面、字型可讀性、像素縮放：headless 無法呈現，**未驗證**。
- 實際鍵盤操作手感、Windows 端執行：**未驗證**。
- Android APK 建置與實機安裝／觸控／長寬比／音效：**未執行**（缺 JDK、Android SDK、export templates）。
- 第三方素材授權：本輪無素材，**無可審**。

### 下一步

見 `NEXT_ACTIONS.md`。
