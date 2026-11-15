# 建置與 headless 驗證

## 環境（實測）

- Godot **4.7.2 stable** Linux x86_64：`/workspace/自動遊戲開發/tools/godot/Godot_v4.7.2-stable_linux.x86_64`
- 無 GPU／顯示器 → 只能 headless 驗證。
- 無 Java／Android SDK／Godot export templates → **Android 尚未建置**（見最後一節）。
- stderr 可能出現 `libfontconfig.so.1: cannot open shared object file`；這是環境缺字型庫，
  非致命（Label 可建立，headless 不影響邏輯）。不要為此安裝套件。

每次執行前：

```bash
export G=/workspace/自動遊戲開發/tools/godot/Godot_v4.7.2-stable_linux.x86_64
export HOME=/workspace/自動遊戲開發/tools/home
export XDG_CONFIG_HOME=$HOME/config XDG_DATA_HOME=$HOME/data
cd /workspace/自動遊戲開發/app_base_git
```

## 1. 匯入

```bash
timeout 120 "$G" --headless --path . --import
```

- 第一次開啟專案、或 `assets/generated/` 變更後必須執行（會產生 `.godot/` 快取與
  貼圖 import 資料）。
- 成功結束碼 0；`.godot/` 不進版控（見 `.gitignore`）。

## 2. 自動測試

```bash
timeout 120 "$G" --headless --path . --script res://tests/run_tests.gd \
  -- --content-dir=/workspace/自動遊戲開發/app_data_git
```

- 選用參數：`--fixtures-dir=<path>`（預設 `res://tests/fixtures`）。
- 輸出最後一行：`TESTS OK n/n` 或 `TESTS FAILED ...`；exit code 0/1。
- 沒有 `--content-dir` 或 game-content 尚無 `manifest.json` 時，真實內容測試標記
  `[SKIP]`，**不得**視為通過。
- 測試涵蓋：格子邊界／可通行／portal、內容載入（manifest 雜湊成功／篡改失敗、
  缺 manifest、未知 effect、引用完整性、地圖幾何、不安全路徑）、effects、
  對話流程、repeatable=false 完成紀錄、portal 與抵達抑制、存檔往返／版本錯誤、
  輸入 map、WorldView atlas、PlayerController Tween、主場景 headless 載入。

## 3. 主場景 headless 啟動

```bash
# 使用內建 res://content bootstrap
timeout 120 "$G" --headless --path . --quit-after 120

# 使用 game-content 真實內容
timeout 120 "$G" --headless --path . --quit-after 120 -- \
  --content-dir=/workspace/自動遊戲開發/app_data_git
```

- `--quit-after 120`：執行 120 幀後結束；exit code 0 代表主場景載入、初始化與
  前 120 幀沒有 GDScript 錯誤。
- **不代表畫面正確**：沒有顯示器／GPU，視覺外觀（版面、色彩、縮放、對話框）未驗證。
- 內容路徑不存在時應顯示 ErrorPanel 且不崩潰（可測試：
  `-- --content-dir=/tmp/definitely_missing_content`）。

## 4. 在 Windows 執行（未驗證）

1. 下載 Godot 4.7.2 stable 標準版（非 .NET 版）。
2. 以編輯器開啟 `project.godot`，按 F5。
3. 若要使用外部內容：命令列 `-- --content-dir=<game-content 絕對路徑>`，
   或在專案設定把 `game/content_dir` 設為內容目錄。
4. 本輪**未在 Windows 實際執行**；只驗證 headless Linux。

## 5. Android 建置（本輪未執行）

目前**尚未建置 APK**，環境缺少：

- Java（JDK 17 以上，Godot 4.x 要求）
- Android SDK + build-tools + platform-tools
- Godot 的 Android export templates（4.7.2）
- 實機或模擬器（驗證安裝、觸控、螢幕比例、安全區）

已就緒的部分：

- `project.godot` 使用 `gl_compatibility` 渲染（適合中低階 Android）。
- viewport 960x540、`canvas_items` + `expand` 可適應不同長寬比。
- 整數 3x 縮放（Camera2D zoom）避免像素失真。
- 未實作觸控輸入；Android 版需要補觸控虛擬按鍵與安全區排版（後續任務）。

未來建置步驟（待工具就緒）：

```bash
# 需要 export_presets.cfg 與 Android SDK/templates
"$G" --headless --path . --export-debug "Android" build/app-debug.apk
```

注意：
- 匯出時需要把 `*.json`（內容、`res://content/`、`assets/generated/*.json`）納入
  export filter，否則匯出後的 PCK 不含 JSON 檔。
- 目前不建議把 `res://content` 的 bootstrap 當成正式內容；正式內容應由
  `game-content` 提供（外部目錄或內容包，尚未實作下載／安裝）。

## 6. 尚未執行的驗證（不可寫成通過）

| 項目 | 狀態 | 原因 |
| --- | --- | --- |
| 視覺外觀／版面／像素縮放 | 未執行 | 無 GPU／顯示器 |
| 鍵盤實際操作與 Tween 手感 | 未執行（Tween 邏輯已測） | 無視窗 |
| Windows 執行 | 未執行 | 本輪只驗證 Linux headless |
| Android APK 建置 | 未執行 | 缺 Java/SDK/templates |
| Android 實機安裝、觸控、長寬比、安全區 | 未執行 | 無實機 |
| 音效／動畫／戰鬥／成人模組 | 未實作 | 不在 v0.1 範圍 |
