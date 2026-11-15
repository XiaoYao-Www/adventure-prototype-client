# 建置與驗證（Linux headless → Android APK）

## 環境（實測於 2026-11-16）

- Godot **4.7.2 stable** Linux x86_64：`/workspace/自動遊戲開發/tools/godot/Godot_v4.7.2-stable_linux.x86_64`
- Temurin **JDK 17.0.21**：`/workspace/自動遊戲開發/tools/jdk17`
- Android **build-tools 36.1.0**、**platform-tools**、**platform android-36**：
  `/workspace/自動遊戲開發/tools/android-sdk`
- Godot **Android export templates 4.7.2.stable**：
  `/workspace/自動遊戲開發/tools/home/data/godot/export_templates/4.7.2.stable/`
- debug keystore（僅供測試簽章）：`/workspace/自動遊戲開發/tools/android-keystore/debug.keystore`
- 無 GPU／顯示器 → 以 headless 建置與驗證；畫面外觀與實機行為**未驗證**。
- stderr 可能出現 `libfontconfig.so.1: cannot open shared object file`；環境缺字型庫，
  非致命。專案已內建 CJK 字型（見 `docs/ASSETS.md`）。

工具都在工作區 `tools/`（不進 Git）；Android SDK 使用說明與授權注意事項見工作區
`tools/README.md`。

### 重要：Java 必須使用 UTF-8 locale

工作區路徑含非 ASCII 字元，若 locale 不是 UTF-8，Java 會把路徑轉成 `?`，導致
`keytool`／`apksigner` 讀不到 `java.security`。執行建置前必須：

```bash
export LANG=C.UTF-8 LC_ALL=C.UTF-8
```

## 每次執行前

```bash
export G=/workspace/自動遊戲開發/tools/godot/Godot_v4.7.2-stable_linux.x86_64
export HOME=/workspace/自動遊戲開發/tools/home
export XDG_CONFIG_HOME=$HOME/config XDG_DATA_HOME=$HOME/data
export JAVA_HOME=/workspace/自動遊戲開發/tools/jdk17
export ANDROID_HOME=/workspace/自動遊戲開發/tools/android-sdk
export LANG=C.UTF-8 LC_ALL=C.UTF-8
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/build-tools/36.1:$PATH"
cd /workspace/自動遊戲開發/app_base_git
```

## 1. 同步內建內容快照（APK 用）

```bash
node tools/sync_content_bundle.mjs --source ../app_data_git --dest content
```

- 從 `game-content` 驗證 manifest 的 sha256/size 後複製到 `res://content/`。
- 產生 `content/BUNDLE_SOURCE.json`（來源版本、manifest 雜湊、同步時間）。
- **不要手動編輯 `res://content/`**；內容更新流程：改 `game-content` → 重建 manifest
  → 執行本工具 → 重建 APK。

## 2. 匯入

```bash
timeout 180 "$G" --headless --path . --import
```

第一次開啟專案、或 `assets/`、`content/` 變更後必須執行（產生 `.godot/` 快取）。
`.godot/` 不進版控。

## 3. 自動測試

```bash
timeout 240 "$G" --headless --path . --script res://tests/run_tests.gd \
  -- --content-dir=/workspace/自動遊戲開發/app_data_git
```

- 2026-11-16 實測：**TESTS OK 336/336**（含標題畫面、觸控、內容包安裝／回滾、版本比較與 CJK 字型檢查）。
- 輸出最後一行 `TESTS OK n/n` 或 `TESTS FAILED ...`；exit code 0/1。
- 無 `--content-dir` 時，真實內容測試會標記 `[SKIP]`，不得視為通過。

## 4. 建置 debug APK

```bash
mkdir -p releases/android
timeout 420 "$G" --headless --path . --export-debug "Android" \
  "$PWD/releases/android/adventure-prototype-0.3.0-debug.apk"
```

- preset 定義於 `export_presets.cfg`（非 gradle 建置、arm64-v8a、minSdk 24、targetSdk 36）。
- 2026-11-16 實測：匯出成功，輸出約 **35.6 MiB**，自動完成 zipalign → apksigner 簽章 →
  APK 驗證。
- 完整可重現流程（含驗證）在工作區 `tools/build_android.sh`。

## 5. 驗證 APK

```bash
APK=releases/android/adventure-prototype-0.3.0-debug.apk
"$ANDROID_HOME/build-tools/36.1/apksigner" verify --print-certs "$APK"
"$ANDROID_HOME/build-tools/36.1/aapt2" dump badging "$APK" | head
"$ANDROID_HOME/build-tools/36.1/zipalign" -c -v 4 "$APK"
sha256sum "$APK"
```

2026-11-16 實測結果：

| 檢查 | 結果 |
| --- | --- |
| apksigner verify | OK，`CN=Android Debug, O=Android, C=US` |
| aapt2 badging | `com.dsh.adventureprototype`、versionCode 1、versionName 0.1.0、minSdk 24、targetSdk 36、native-code arm64-v8a |
| zipalign -c 4 | Verification successful |
| APK 內 `assets/content/` | 7 個資料檔，獨立驗證器 CONTENT OK |
| APK 內字型 | `.godot/imported/NotoSansTC-VF...fontdata`（8.9MB）存在 |

## 6. 在 Windows 執行

1. 下載 Godot 4.7.2 stable 標準版（非 .NET 版）。
2. 以編輯器開啟 `project.godot`，按 F5。
3. 使用外部內容：`-- --content-dir=<game-content 絕對路徑>`，或專案設定
   `game/content_dir`。
4. 本輪**未在 Windows 實際執行**。

## 7. 尚未執行的驗證（不可寫成通過）

| 項目 | 狀態 | 原因 |
| --- | --- | --- |
| 畫面外觀／版面／字型（中文） | 未執行 | 無 GPU／顯示器；字型字形已以程式檢查，但實際排版未驗證 |
| 觸控操作手感與安全區 | 未執行 | 按鈕與訊號已有測試，但無實機可驗證實際大小與遮擋 |
| 鍵盤實際操作與 Tween 手感 | 未執行 | 無視窗 |
| Windows 執行 | 未執行 | 只有 Linux headless 環境 |
| Android 實機安裝／啟動／觸控／螢幕比例／安全區 | 未執行 | 本環境無 Android 裝置與模擬器 |
| 正式（release）簽章與上架 | 未執行 | 目前只有 debug 簽章；正式金鑰須由使用者控制 |
| 音效／動畫／戰鬥／成人模組 | 未實作 | 不在 v0.1 範圍 |


## 8. 自動更新與 release（v0.2.0）

- 本體：App 啟動時 GET `releases/latest/download/latest.json`，比 `version_code`；
  較新則下載 APK、驗 sha256/size，再以 `AndroidRuntime` + `JavaClassWrapper` 呼叫
  FileProvider 產生 content URI、啟動系統安裝程式。Android 一定顯示安裝確認，
  且首次需允許「安裝未知的應用程式」。
- 內容：GET `releases/latest/download/latest_data.json`，比 `content_version`；
  較新則下載內容包 ZIP、驗 sha256，用 `ContentInstaller` 解到 `user://content_packs/`，
  經 `ContentRepository` 完整驗證後切換 `user://content_current.json`（下次啟動生效，失敗保留舊版）。
- 發布：推送 `v*` tag → GitHub Actions `release.yml` 建立 release 並上傳
  APK + `latest.json` + BUILD_INFO；內容 repo 推送 `data-v*` tag → `release-data.yml`
  產生內容包 ZIP + `latest_data.json`。
- 詳細設計與限制見 `docs/architecture/UPDATE_SYSTEM.md`。
