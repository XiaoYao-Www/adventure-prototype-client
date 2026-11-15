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

## 2026-11-16（續）— Phase 4：Android 工具鏈與 debug APK 建置

### 目標

依使用者指示（「自己配置環境、編譯成 APK、提交進倉庫」，使用者不介入），
在 CPU-only 環境自行安裝 Android 建置工具鏈，產出可安裝的 APK，並提交進 game-client 倉庫。

### 環境建置（實際結果）

| 元件 | 版本／位置 | 驗證 |
| --- | --- | --- |
| Temurin JDK | 17.0.21，`tools/jdk17`（Adoptium API） | `java -version` OK |
| Android build-tools | 36.1.0，`tools/android-sdk/build-tools/36.1` | `apksigner --version` OK |
| Android platform-tools | latest，`tools/android-sdk/platform-tools` | `adb` 存在 |
| Android platform | android-36，`tools/android-sdk/platforms/android-36` | 目錄存在 |
| Godot Android export templates | 4.7.2.stable，`tools/home/data/godot/export_templates/4.7.2.stable` | `android_debug.apk` 存在 |
| debug keystore | `tools/android-keystore/debug.keystore`（alias `androiddebugkey`） | `keytool -list` OK |

**未使用 sdkmanager/cmdline-tools**：cmdline-tools 下載被 Google 限速到約 3KB/s（估 14 小時），
中止後直接下載 `build-tools_r36.1_linux.zip`、`platform-tools-latest-linux.zip`、
`platform-36_r02.zip` 並手動配置 SDK 目錄；速度恢復到 8–57MB/s。

### 重要問題與修正

1. **Java 在非 ASCII 路徑失效**：工作區路徑含中文，locale 非 UTF-8 時 Java 將路徑轉成 `?`，
   `keytool` 報 `Error loading java.security file`。修正：所有 Java 工具以
   `LANG=C.UTF-8 LC_ALL=C.UTF-8` 執行（已寫入 `tools/build_android.sh` 與 `docs/BUILD.md`）。
2. **Godot Android 匯出要求 ETC2/ASTC**：首次匯出失敗，需啟用
   `rendering/textures/vram_compression/import_etc2_astc=true`，重新 `--import` 後成功。
3. **CJK 字型缺失**：Godot 預設字型不含正體中文，Android 亦不保證系統字型可用；
   內建 Noto Sans TC Variable（SIL OFL 1.1，來源與雜湊記於 `docs/ASSETS.md` 與
   `assets/fonts/OFL.txt`），設為 `[gui] theme/custom_font`，並新增字形測試
   （`Font.has_char` 檢查「中」「旅」「互」）。
4. **res://content 由 bootstrap 改為建置快照**：新增 `tools/sync_content_bundle.mjs`，
   驗證 manifest sha256/size 後把 `game-content 0.1.0` 複製為 `res://content`，寫入
   `BUNDLE_SOURCE.json`；載入器忽略此中繼資料。原 `boot_*` 內容自 repo 移除（見 D-0018）。
5. **Android 無鍵盤無法操作**：補上觸控虛擬方向鍵、互動、存檔／讀檔按鈕
   （`scripts/ui/touch_controls.gd`，mobile 自動顯示），並把互動改為統一入口
   `_request_interact()`（鍵盤與觸控共用）；新增 12 項觸控測試。
6. **APK 內含內容驗證**：從 APK 抽出 `assets/content/` 以獨立驗證器檢查 → CONTENT OK。

### 測試與驗證（實際命令與結果）

| 命令／檢查 | 結果 |
| --- | --- |
| `bash tools/build_android.sh`（同步→驗證→匯入→測試→匯出→驗證） | **APK BUILD + VERIFY PASSED** |
| `node tools/sync_content_bundle.mjs` | BUNDLE OK：7 檔／4525 bytes |
| `node tools/validate_content.mjs app_data_git` | CONTENT OK（0 error／0 warning） |
| `godot --headless --path app_base_git --import` | exit 0 |
| `godot --headless ... --script res://tests/run_tests.gd -- --content-dir=app_data_git` | **TESTS OK 288/288**、0 SKIP |
| `godot --headless --path app_base_git --export-debug "Android" …` | 成功，Signed、Verifying APK DONE |
| `apksigner verify --print-certs` | OK，`CN=Android Debug, O=Android, C=US` |
| `aapt2 dump badging` | `com.dsh.adventureprototype`、versionCode 1、versionName 0.1.0、minSdk 24、targetSdk 36、arm64-v8a |
| `zipalign -c -v 4` | Verification successful |
| APK 內 `assets/content/` 驗證 | CONTENT OK（7 檔） |
| APK 內 CJK 字型 | `NotoSansTC-VF…fontdata` 存在（8.9MB） |
| `bash tools/checks.sh` | 7 步全通過（含 APK SHA-256 與 BUILD_INFO 比對） |

APK 成品：`releases/android/adventure-prototype-0.1.0-debug.apk`
（37,298,075 bytes、SHA-256 `1fda822d9b6f8d8230693fb6568702dc886b932ca9a0c06d62b25e95b11a4af3`），
建置資訊見 `releases/android/BUILD_INFO.md`。

### 未執行（不得視為通過）

- Android 實機／模擬器安裝、啟動、畫面、中文渲染、觸控手感、安全區、音效：**未驗證**
  （本環境無 Android 裝置與模擬器）。
- Windows 端執行：**未驗證**。
- release 簽章與上架：**未執行**（目前只有 debug 簽章）。

### 下一步

見 `NEXT_ACTIONS.md`。

## 2026-11-16（第二輪回饋）— 手機觸控失效修正、橫向、素材盤點

### 使用者回饋

1. 遊戲在手機上沒有有效的操作方法。
2. 遊戲應為橫向（手機橫置）。
3. 使用者提供了遊戲素材，要求自行分類標記，避免重複看圖。

### 變更

- 觸控控制重寫（`scripts/ui/touch_controls.gd`）：不再使用 Button/Control 佈局，
  改為自繪按鈕 + 手動命中測試；支援按住連走（0.28s 後每 0.14s 一步）、世界滑動轉向、
  世界輕點互動；對話開啟時 `set_input_blocked()` 不攔截對話框點擊。
- 螢幕方向改為橫向（`display/window/handheld/orientation=4`，sensor landscape）。
- 測試新增觸控命中、連走、滑動、阻擋、隱藏等案例；總數 288 → **300**。
- 重建 APK（debug）：37,302,171 bytes、SHA-256 `6bd14f00f983cfb0f8b8ddd83baed6066990735130352f50e143e242e4c02470`。
- 追加觸控診斷輸出後再重建：37,310,532 bytes、SHA-256 `8707ce53b4460bc229fab2403a30cf584a01eeb35edf7715933eaf244ce21b62`
  （logcat 可看到 `[touch] ready ...` 與首次觸控的命中結果，便於實機追查）。

### 素材盤點（工作區 `assets/`）

- Mini World Sprites（作者 Shade／merchant-shade.itch.io、16×16）：地形、自然、建築（5 種配色）、
  角色（士兵／工人／怪物／冠軍）、動物、物件、UI、Templates；共 207 張 PNG。
- Items16（作者 glionox／glionox.itch.io、16×16）：1244 張道具圖示，檔名 item1..item1244。
- 合計 1451 張 PNG、2.42MB、sha256 無重複；授權狀態需逐包核對（來源頁面）。
- 分類與標記輸出至 `game-content/asset_catalog/`；本輪尚未替換遊戲內 placeholder 美術。

### 驗證

- `bash tools/build_android.sh`：TESTS OK 300/300、APK 匯出＋簽章＋zipalign 驗證通過。
- 未驗證：實機觸控與橫向顯示（本環境無 Android 裝置）。

### 素材目錄與標記（同日完成）

- 建立 `app_base_git/tools/build_asset_catalog.mjs`：解析 PNG 尺寸／sha256、
  依目錄與檔名分類，輸出 `game-content/asset_catalog/`（catalog、packs、licenses、index）。
- 建立 `app_base_git/tools/make_contact_sheets.gd`：用 Godot Image API 產生
  `mini_world_sprites.png`（207 張）與 `items16.png`（1244 張）聯絡表 + 對照索引，
  只讀兩張總覽即可分類，不必逐張看圖。
- 授權核對（itch.io）：Mini World Sprites = CC0-1.0；Items16 = 可商用/可修改、
  禁止再散布或轉售原始包 → 標記 `redistributable=false`，不進公開 APK。
- 提交 content repo：`494eb0e`（asset_catalog + ASSET_POLICY + changelog）。
- 限制：Items16 無語意檔名與對照表，目前只標 `item_icon`，尚未逐張語意分類。

### GitHub 遠端連接（同日）

- 使用者建立兩個遠端倉庫（public、空、預設 `main`）：
  - `XiaoYao-Www/adventure-prototype-client` → 本地 `app_base_git`
  - `XiaoYao-Www/adventure-prototype-data` → 本地 `app_data_git`
- 已設定 `origin`（SSH）、本地分支 `master` 改名為 `main`、每個倉庫指定獨立 deploy key
  （`tools/ssh/id_ed25519_{client,data}`，私鑰不進 Git）。
- 現況：GitHub SSH 可連（22/443 皆可），但金鑰尚未加入 GitHub → `Permission denied (publickey)`。
- 待使用者把兩把公鑰加入對應 repo 的 Deploy keys（Allow write access），
  執行 `bash tools/push_to_github.sh` 即完成首次推送並驗證。

### GitHub 首次推送（2026-11-16）

- 使用者在兩個 repo 的 Deploy keys（Allow write access）加入公鑰後，SSH 認證成功。
- `bash tools/push_to_github.sh` 推送完成：
  - client `45b2b34bd77022e95830b93283d4ed5b64506d04` → `refs/heads/main`
  - data `494eb0e0587918eceb46bd4044919380dd0f301f` → `refs/heads/main`
- 驗證：`git ls-remote origin main` 與本地 HEAD 一致；GitHub API commits/main 回傳相同 SHA；
  `raw.githubusercontent.com` 可讀到兩倉庫 README。
- 註：GitHub API 的 repo `size` 欄位即時顯示 0（更新有延遲），但 commits 與 raw 內容已確認。
