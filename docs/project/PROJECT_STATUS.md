# 專案狀態（權威）

> 本文件是專案唯一權威狀態摘要。工作區 `STATE/` 僅保留指向此處的說明。
> 最後更新：2026-11-16（Asia/Taipei），由 Captain（Lead）於 v0.1 整合後更新。

## 目前階段

- **`Phase 3 — 第一個垂直切片（v0.1）：headless 驗證完成`**
- 下一個階段：`Phase 4 — 視覺／操作人工驗收與 Android 匯出路徑`

## 專案方向（已確認）

- Android 優先、2D、格子式移動、視覺優先的冒險探索 RPG；不是純文字遊戲。
- 引擎：**Godot 4.7.2 stable + GDScript**（已實測）。
- 雙倉庫：程式（`game-client`）與內容（`game-content`）分離；玩家存檔不進 Git。
- 執行環境 CPU-only；無 GPU、無付費 API／雲端／插件。

## 倉庫狀態

| 規格名稱 | 實際路徑 | 角色 | branch | 首個 commit |
| --- | --- | --- | --- | --- |
| `game-client` | `/workspace/自動遊戲開發/app_base_git` | 程式、場景、測試、建置、專案文件 | `master` | 2026-11-16 建立（見 `git log`） |
| `game-content` | `/workspace/自動遊戲開發/app_data_git` | 內容資料、schema、可發布內容來源 | `master` | 2026-11-16 建立（見 `git log`） |

兩倉庫皆無 remote、未 push（依專案規則不得自動推送到遠端）。

## 可玩狀態

- **可以 headless 執行並通過自動測試**：載入 `game-content` → 格子移動／碰撞、面向格互動、
  逐句對話與選項、`set_flag`/`give_item`、雙向 portal、F5/F9 存檔讀檔、缺內容顯示錯誤。
- **尚未驗證**：畫面外觀與版面、實際鍵盤操作手感、Windows 端執行、Android APK 建置、
  Android 實機安裝／觸控／長寬比／音效。
- 主場景預設會先用 client 內建 `res://content` bootstrap，再允許 `--content-dir` 指向 `game-content`。

## 已驗證能力（實際命令與結果）

| 檢查 | 命令 | 結果 |
| --- | --- | --- |
| 內容工具鏈單元測試 | `node --test tools/tests/content_tools.test.mjs`（client） | **9/9 pass** |
| 內容包獨立驗證 | `node tools/validate_content.mjs ../app_data_git` | **CONTENT OK**（7 資料檔、2 地圖、1 NPC、1 道具、2 事件、區域 1） |
| manifest 一致性 | `node tools/build_content_manifest.mjs ../app_data_git --check` | **MANIFEST OK**（7 檔、4525 bytes） |
| placeholder atlas 可重現 | `bash tools/checks.sh` 第 4 步 | png/json 與 repo 內容一致 |
| Godot 專案匯入 | `godot --headless --path . --import` | exit 0、無 GDScript 錯誤 |
| Godot 自動測試 | `godot --headless --path . --script res://tests/run_tests.gd -- --content-dir=../app_data_git` | **TESTS OK 265/265**、0 SKIP |
| 主場景載入 | `godot --headless --path . --quit-after 120` | exit 0、遊戲就緒 `map_start_village` 玩家 `(3,6)` |
| 缺內容容錯 | 同上加 `-- --content-dir=/tmp/definitely_missing_content` | exit 0、顯示 `E_NO_MANIFEST`、不崩潰 |
| 整合腳本 | `bash tools/checks.sh` | **ALL CHECKS PASSED** |

`bash tools/checks.sh`（工作區 `tools/checks.sh`）可一次重跑上述 1–6 步。

## 內容包狀態

- `game-content`：`content_id = base_world`、`content_version = 0.1.0`、`schema_version = 1`、
  `min_game_version = 0.1.0`、7 個資料檔／4525 bytes、雙向 portal 的 2 張小地圖、1 NPC、
  1 道具、2 事件。全部世界觀內容標示「暫定」，**不是正史**。
- `game-client/content/`：`builtin_bootstrap 0.1.0`（7 檔／3864 bytes，id 以 `boot_` 區隔），
  只作離線啟動 fallback，非權威內容。

## 工具與環境

- Godot：`tools/godot/Godot_v4.7.2-stable_linux.x86_64`（MIT、官方 GitHub release、
  下載檔 SHA-256 `cadd3204…29e4`；官方未提供可用的 checksum 清單可供比對）。
- Node.js v24.21.0（只用在內容驗證工具，不安裝 npm 套件）。
- 缺少：JDK、Android SDK／build-tools、Godot Android export templates → **無法建置 APK**。
- 缺少：GPU、顯示器 → 只能 headless；`libfontconfig.so.1` 缺失為非致命警告。
- 可寫入範圍：工作區與兩個倉庫；Godot 執行須指定 `HOME`／`XDG_*` 至 `tools/home`。

## 目前阻塞

1. 視覺與操作驗收需要使用者在本機（Windows + Godot 編輯器或可呈現畫面的環境）開啟專案。
2. Android 匯出需要使用者核准安裝 JDK／Android SDK／export templates（約 1.2GB）。
3. 素材包尚未提供，授權未審核（本輪無任何第三方素材）。

## 下一步

見 `NEXT_ACTIONS.md`。
