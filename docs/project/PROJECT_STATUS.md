# 專案狀態（權威）

> 本文件是專案唯一權威狀態摘要。工作區 `STATE/` 僅保留指向此處的說明。
> 最後更新：2026-11-16（Asia/Taipei），v0.3.0：主頁面、對話可推進、連續移動、內容大擴充。

## 目前階段

- **`Phase 3 — 垂直切片 v0.1：完成（headless 驗證）`**
- **`Phase 4 — Android debug APK：已建置並完成建置面驗證`**
- **`Phase 5 — 自動更新與 release 自動化：v0.2.x 完成`**
- **`Phase 6 — 玩法與內容大更新：v0.3.0（主頁面、對話操作、連續移動、5 地圖／6 NPC／14 事件）`**
- 下一步：使用者在 Android 裝置安裝測試（這是目前唯一無法由 DSH 完成的驗收）。

## 專案方向（已確認）

- Android 優先、2D、格子式移動、視覺優先的冒險探索 RPG；不是純文字遊戲。
- 引擎：**Godot 4.7.2 stable + GDScript**（已實測）。
- 雙倉庫：程式（`game-client`）與內容（`game-content`）分離；玩家存檔不進 Git。
- 執行環境 CPU-only；無 GPU、無付費 API／雲端／插件。

## 倉庫狀態

| 規格名稱 | 實際路徑 | 角色 | branch | commit |
| --- | --- | --- | --- | --- |
| `game-client` | `/workspace/自動遊戲開發/app_base_git` | 程式、場景、測試、建置、APK 成品 | `main` | **已推送**：`45b2b34` → https://github.com/XiaoYao-Www/adventure-prototype-client |
| `game-content` | `/workspace/自動遊戲開發/app_data_git` | 內容資料、schema、可發布內容來源 | `main` | **已推送**：`494eb0e` → https://github.com/XiaoYao-Www/adventure-prototype-data |

兩倉庫已設定 GitHub remote 並完成首次推送（2026-11-16）：
client `45b2b34`、data `494eb0e`，遠端 `main` 與本地一致；已用 GitHub API 與 raw 檔案驗證。
Deploy key（每倉庫一把、write）僅存在工作區 `tools/ssh/`，私鑰不進 Git。

## v0.1 可玩狀態

- **已可執行（headless）**：載入內容 → 格子移動／碰撞、互動、逐句對話＋選項、
  `set_flag`/`give_item`、雙向 portal、F5/F9 存檔讀檔、缺內容顯示錯誤。
- **Android 可操作性（第二版）**：觸控改為自繪＋手動命中測試（不依賴 Control 佈局），
  方向鍵可按住連走、世界可滑動轉向、輕點互動；存檔／讀檔按鈕；對話開啟時不攔截對話框點擊。
  螢幕方向改為**橫向**（sensor landscape）。第一版實機回報「沒有有效操作」，此版尚未實機複驗。
- **APK（v0.3.0）**：`app_base_git/releases/android/adventure-prototype-0.3.0-debug.apk`
  （37,363,165 bytes、SHA-256 `23bcb879…4040`、versionCode 4、debug 簽章、arm64-v8a、minSdk 24、橫向）。
- **v0.3.0 修正／新增**：標題主頁面（開始／繼續／檢查更新）；對話中「互動」鍵與點擊畫面皆可推進；
  按住方向鍵連續移動（main 每幀輪詢，移除舊 0.28 秒延遲）；內容擴充為 5 地圖、6 NPC、6 道具、14 事件。
- **GitHub Releases（已自動發布並驗證）**：client `v0.2.0`、`v0.2.1`；data `data-v0.1.0`、`data-v0.1.1`。
  固定更新網址：
  - 本體 `https://github.com/XiaoYao-Www/adventure-prototype-client/releases/latest/download/latest.json`
  - 內容 `https://github.com/XiaoYao-Www/adventure-prototype-data/releases/latest/download/latest_data.json`
- **更新驗證組合**：安裝 `v0.2.0` APK → 啟動自動檢查到 `v0.2.1` → 下載/驗證/開啟系統安裝；
  內容 bundled 0.1.0 對上最新 0.1.1 → 下載內容包、驗證、下次啟動生效。
- **驗證紀錄**：latest.json（v0.2.1、version_code 3、APK sha256 `4ec34e1e…b6fb`）與
  latest_data.json（0.1.1、zip sha256 `1f7b40ce…e11e`）皆實際下載比對一致；
  GitHub Actions 兩個 release run 均 success。
- **自動更新（v0.2.0）**：啟動檢查 GitHub Releases 的 `latest.json` → 下載 APK → 驗 sha256/size →
  透過 AndroidRuntime/FileProvider 開啟系統安裝程式；內容則檢查 `latest_data.json` →
  下載內容包 → 驗證 → 安裝到 `user://content_packs/`（下次啟動生效，失敗保留舊版）。
- **Release 自動化**：推送 `v*` tag 由 `.github/workflows/release.yml` 建立 GitHub Release
  並上傳 APK＋`latest.json`；內容 repo 推送 `data-v*` 由 `release-data.yml` 建立內容 release。
- **仍未驗證**：實機安裝／啟動／畫面／中文渲染／觸控手感／音效；Windows 執行。

## 已驗證能力（實際命令與結果）

| 檢查 | 結果 |
| --- | --- |
| `node --test tools/tests/content_tools.test.mjs` | **9/9 pass** |
| `node tools/validate_content.mjs ../app_data_git` | **CONTENT OK**（7 資料檔、2 地圖、1 NPC、1 道具、2 事件、1 區域） |
| `node tools/build_content_manifest.mjs ../app_data_git --check` | **MANIFEST OK**（4525 bytes） |
| `node tools/sync_content_bundle.mjs` | **BUNDLE OK**（res://content = game-content 0.1.0 快照） |
| Godot `--import` | exit 0、無 GDScript 錯誤 |
| 更新資訊實際下載比對 | latest.json / latest_data.json / APK / 內容包 sha256 全部一致 |
| GitHub Actions release | client v0.2.0、v0.2.1、data data-v0.1.0、data-v0.1.1 全部 success |
| Godot headless 測試 | **TESTS OK 336/336**（內容、格子、對話、存檔、portal、觸控、CJK 字型、更新資訊解析、內容包安裝／回滾） |
| 主場景 headless | exit 0、`map_start_village` 玩家 `(3,6)` |
| 缺內容容錯 | `E_NO_MANIFEST`＋ErrorPanel、不崩潰 |
| APK 匯出（debug） | 成功；zipalign → apksigner → verify 全通過 |
| `apksigner verify --print-certs` | OK（`CN=Android Debug`） |
| `aapt2 dump badging` | package/version/minSdk/targetSdk/native-code 見 `releases/android/BUILD_INFO.md` |
| `zipalign -c -v 4` | Verification successful |
| APK 內 `assets/content/` 抽出驗證 | CONTENT OK（0 error） |
| `bash tools/checks.sh`（工作區整合腳本） | 7 步全通過（含 APK 簽章與 SHA-256 與 BUILD_INFO 比對） |

## 內容包與內建快照

- `game-content`：`base_world` 0.1.0、`schema_version 1`、`min_game_version 0.1.0`、
  7 檔／4525 bytes、2 張小地圖（雙向 portal）、1 NPC、1 道具、2 事件；全部標示「暫定」。
- `game-client/content/`：APK 內建建置快照（由 `tools/sync_content_bundle.mjs` 從
  `game-content` 驗證後複製；`BUNDLE_SOURCE.json` 記錄來源版本與 manifest 雜湊）。
  內容更新流程：改 `game-content` → 重建 manifest → 同步快照 → 重建 APK。

## 工具與環境（工作區 `tools/`，不進 Git）

- Godot 4.7.2 stable（MIT）；Android export templates 4.7.2.stable。
- Temurin JDK 17.0.21；Android build-tools 36.1.0、platform-tools、platform android-36。
- debug keystore（僅測試簽章）；CJK 字型 Noto Sans TC（OFL，已放入 repo）。
- Node.js v24.21.0（內容工具用，無 npm 依賴）。
- 缺少：GPU、顯示器、Android 實機／模擬器 → 只能 headless 建置與邏輯驗證。
- 重要：Java 工具需 UTF-8 locale（`LANG=C.UTF-8`），否則非 ASCII 路徑會失敗。

## 素材狀態（2026-11-16 使用者提供）

- 工作區 `assets/`：Mini World Sprites（207 張，16×16 地形／建築／角色／物件等）與
  Items16（1244 張 16×16 道具圖示），共 1451 張 PNG、2.42MB、無重複內容。
- 已完成授權核對與分類目錄（`game-content/asset_catalog/`，commit `494eb0e`）：
  Mini World Sprites **CC0-1.0**（可再散布）；Items16 可商用/可修改但**禁止再散布原始包**，
  故 item 圖示不得進公開 APK（僅內部測試）。
- 已產生聯絡表（工作區 `tools/asset_previews/`）與索引，日後不需逐張開圖。
- 目前 APK 仍使用專案自製 placeholder 與內建字型，尚未替換為這些素材。

## Discord 玩家溝通與每日節奏（2026-11-16）

- 玩家頻道：Discord「開發管理員」webhook（頻道 id `1571589032570257518`）；
  DSH profile 的 Discord 通知已指向此頻道（需重啟 DSH web 才讓 `discord_send` 工具生效；
  專用腳本 `tools/discord_game_send.mjs` 立即可用）。
- 溝通窗口：**每天 20:00–24:00（Asia/Taipei）** 才讀取與回覆；發送腳本強制此限制。
- 每日開發：已建立每天 20:00 的排程提醒，內容含「讀訊息→回覆→至少一項改進→測試→
  release→日報」。排程需 DSH web session 存活才會觸發。
- **限制**：webhook 無法讀取訊息；要讀玩家訊息需 Discord Bot Token
  （`tools/secrets/discord_bot.token`，尚未提供）。目前只能發送。

## 目前阻塞

1. **實機驗收**：需要使用者把 APK 安裝到 Android 手機（arm64、Android 7.0+），
   回報啟動、畫面、中文、觸控與存檔是否正常。
2. **正式發布**：目前只有 debug 簽章，不可上架；release 簽章金鑰須由使用者控制。
3. 觸控按鈕大小／安全區、中文排版、音效皆未在裝置上驗證。
4. 無 Android 模擬器可做自動化安裝測試。

## 下一步

見 `NEXT_ACTIONS.md`。
