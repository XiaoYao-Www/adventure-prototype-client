# Session Handoff

> 下一輪 DSH 啟動時先讀這份，不要憑對話記憶接手。

## 下次啟動先讀（順序）

1. `docs/project/PROJECT_STATUS.md`
2. `docs/project/NEXT_ACTIONS.md`
3. `docs/project/DEVELOPMENT_LOG.md`（最近一筆：2026-11-16 Android APK 建置）
4. `docs/project/DECISION_LOG.md`（D-0016～D-0022 為 APK 建置與發布相關技術決策；
   D-0020 螢幕方向仍 proposed）
5. `docs/project/ISSUES_AND_RISKS.md`
6. `README.md`、`docs/BUILD.md`、`releases/android/BUILD_INFO.md`

## 目前在哪裡

- 階段：**Phase 3（v0.1 垂直切片）完成；Phase 4 的 debug APK 已建置並完成建置面驗證**。
- 測試：Godot headless **288/288**、node 內容工具 9/9、內容驗證 CONTENT OK。
- APK：`releases/android/adventure-prototype-0.1.0-debug.apk`
  （37,298,075 bytes、SHA-256 `1fda822d9b6f8d8230693fb6568702dc886b932ca9a0c06d62b25e95b11a4af3`）。
- 已內建觸控虛擬控制與 CJK 字型（Noto Sans TC，OFL）。
- **尚未驗證**：Android 實機安裝／啟動／畫面／中文渲染／觸控手感／安全區／音效；Windows 執行。
- 雙倉庫：client `master`（首個 commit `869b110`，後續 APK 建置提交見 `git log`）、
  content `master`（`7100d08`）；皆無 remote、未 push。

## 下一個動作

1. **等使用者實機安裝回報**（任務 1）：啟動、畫面、中文、觸控、互動、存檔、portal。
2. 依回饋修正觸控／版面並重建 APK（任務 2）。
3. 使用者決定 release 簽章與發布方式（任務 3，先提案不自行執行）。

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

- 倉庫：client = `app_base_git`、content = `app_data_git`（路徑映射見 D-0007）。
- git 指令需加 `-c safe.directory='*'`。
- 一鍵建置＋驗證：`bash /workspace/自動遊戲開發/tools/build_android.sh`
- 全專案檢查：`bash /workspace/自動遊戲開發/tools/checks.sh`（7 步，含 APK 簽章與雜湊比對）
- 內容變更流程：`node app_base_git/tools/build_content_manifest.mjs app_data_git` →
  `node app_base_git/tools/validate_content.mjs app_data_git` →
  `node app_base_git/tools/sync_content_bundle.mjs` → 重新匯入 → 重建 APK → 更新 BUILD_INFO。

## 不要做

- 不要 push、改 remote、force push、reset／clean 或覆蓋使用者變更。
- 不要未經使用者核准改用 release 簽章、上架或上傳 APK。
- 不要把 keystore、密碼、token 提交進 Git。
- 不要用「APK 建置成功」宣稱實機可玩；實機驗收未完成前不算通過。
- 不要自行定案世界觀、遊戲名稱、畫面方向、戰鬥形式或最終美術風格。
- 不要手動編輯 `res://content/`（由 sync 工具產生）。
