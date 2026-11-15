# Session Handoff

> 下一輪 DSH 啟動時先讀這份，不要憑對話記憶接手。

## 下次啟動先讀（順序）

1. `docs/project/PROJECT_STATUS.md`
2. `docs/project/NEXT_ACTIONS.md`
3. `docs/project/DEVELOPMENT_LOG.md`（最近一筆：2026-11-16 第二輪回饋：觸控修正＋橫向＋素材盤點）
4. `docs/project/DECISION_LOG.md`（D-0020 橫向已 accepted；D-0023 觸控重寫；D-0024 素材導入）
5. `docs/project/ISSUES_AND_RISKS.md`
6. `README.md`、`docs/BUILD.md`、`releases/android/BUILD_INFO.md`、
   `../app_data_git/asset_catalog/`（素材目錄）

## 目前在哪裡

- 階段：**Phase 5**。v0.2.0 已建置並將由 tag 觸發 GitHub Release；功能含自動更新
  （本體 APK：下載→驗 SHA-256→系統安裝；內容 DATA：下載內容包→驗證→user:// 安裝，下次啟動生效）、
  觸控、橫向、CJK 字型；測試 **332/332**。
- APK：`releases/android/adventure-prototype-0.2.0-debug.apk`

- Release：已由 GitHub Actions 自動發布並驗證：client `v0.2.0`、`v0.2.1`；data `data-v0.1.0`、`data-v0.1.1`。
  固定更新網址（App 使用）：
  - client `/releases/latest/download/latest.json`
  - data `/releases/latest/download/latest_data.json`
- 更新資訊固定網址：client `/releases/latest/download/latest.json`、data `/releases/latest/download/latest_data.json`。
- 使用者回饋：第一版「手機沒有有效操作」→ 已重寫，**等實機複驗**；並要求橫向（已設 sensor landscape）。
- 素材：使用者提供 Mini World Sprites（CC0-1.0）＋ Items16（可商用/修改、禁止再散布），
  1451 張 16×16 PNG；已建立 catalog／授權／聯絡表（content `494eb0e`），**尚未接入遊戲**。
  Items16 不得進公開 APK。
- 雙倉庫：client `main`、content `main`；已完成 GitHub 首次推送：
  client `45b2b34`（https://github.com/XiaoYao-Www/adventure-prototype-client）、
  data `494eb0e`（https://github.com/XiaoYao-Www/adventure-prototype-data）。

## 下一個動作

0. 實機安裝 v0.2.0 驗證本體自動更新到 v0.2.1，並觀察內容是否更新到 0.1.1。
1. 依 R-025 決定正式 release 簽章；之後再用同一流程發布正式版。

0. 推送已完成；後續變更用 `bash tools/push_to_github.sh` 同步（deploy key 已授權）。

1. 使用者完成第二版 APK 實機複驗（任務 1）；若仍無法操作，取 logcat。
2. 完成素材授權核對（任務 2）→ 以真實素材替換 placeholder（任務 3）。
3. 依回饋調整觸控與橫向版面（任務 4）。

## 環境速查

```bash
export G=/workspace/自動遊戲開發/tools/godot/Godot_v4.7.2-stable_linux.x86_64
export HOME=/workspace/自動遊戲開發/tools/home
export XDG_CONFIG_HOME=$HOME/config XDG_DATA_HOME=$HOME/data
export JAVA_HOME=/workspace/自動遊戲開發/tools/jdk17
export ANDROID_HOME=/workspace/自動遊戲開發/tools/android-sdk
export LANG=C.UTF-8 LC_ALL=C.UTF-8
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/build-tools/36.1:$PATH"
```

- 一鍵建置＋驗證：`bash tools/build_android.sh`
- 全專案檢查：`bash tools/checks.sh`（7 步，含 APK 簽章與 BUILD_INFO 雜湊比對）
- 素材在**工作區** `assets/`（不在任何 repo）；分類輸出在 `app_data_git/asset_catalog/`。
- 重建 APK 後必須更新 `releases/android/BUILD_INFO.md`（`checks.sh` 會比對 SHA-256）。

## 不要做

- 不要把手機版素材（license_unverified）放進公開 APK。
- 不要 push、改 remote、force push、reset／clean 或覆蓋使用者變更。
- 不要未經使用者核准改用 release 簽章或上架。
- 不要用「APK 建置成功」宣稱實機可玩。
- 不要自行定案世界觀、遊戲名稱、戰鬥形式或最終美術風格。
- 不要手動編輯 `res://content/`（由 sync 工具產生）。
