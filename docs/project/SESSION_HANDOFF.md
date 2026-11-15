# Session Handoff

> 下一輪 DSH 啟動時先讀這份，不要憑對話記憶接手。

## 下次啟動先讀（順序）

1. `docs/project/PROJECT_STATUS.md`
2. `docs/project/NEXT_ACTIONS.md`
3. `docs/project/DEVELOPMENT_LOG.md`（最近一筆：2026-11-16 v0.1）
4. `docs/project/DECISION_LOG.md`（D-0006～D-0012 為本輪技術決策；D-0013～D-0015 仍 proposed）
5. `docs/project/ISSUES_AND_RISKS.md`
6. `README.md`、`docs/BUILD.md`、`docs/architecture/CONTENT_CONTRACT.md`

## 目前在哪裡

- 階段：**Phase 3 完成（v0.1 垂直切片 headless 驗證通過 265/265）**。
- 雙倉庫皆已在 2026-11-16 建立首個本地 commit；`master`、無 remote、未 push。
- `bash /workspace/自動遊戲開發/tools/checks.sh` 可重跑 6 步整合檢查（內容工具測試、內容驗證、
  manifest 一致性、atlas 可重現、Godot 匯入、Godot headless 測試）。
- 尚未驗證：畫面外觀、操作手感、Windows 執行、Android APK／實機、觸控、音效。

## 下一個動作

1. 等使用者完成視覺／操作驗收（任務 1），依回饋修 UI 或確認可接受。
2. 若使用者同意，進入任務 3 的 Android 工具鏈提案（先提案、不自行安裝）。
3. 可並行：任務 2（契約 v1.1 `start_map_id`），先改契約再同步兩倉庫與測試。

## 環境速查

```bash
export G=/workspace/自動遊戲開發/tools/godot/Godot_v4.7.2-stable_linux.x86_64
export HOME=/workspace/自動遊戲開發/tools/home
export XDG_CONFIG_HOME=$HOME/config XDG_DATA_HOME=$HOME/data
```

- 倉庫：client = `app_base_git`、content = `app_data_git`（路徑映射見 D-0007）。
- git 指令需加 `-c safe.directory='*'`。
- 內容變更後：`node app_base_git/tools/build_content_manifest.mjs app_data_git` 再
  `node app_base_git/tools/validate_content.mjs app_data_git`。

## 不要做

- 不要 push、改 remote、force push、reset／clean 或覆蓋使用者變更。
- 不要在未核准下安裝 JDK／Android SDK／export templates／npm 套件／Godot 插件。
- 不要用 headless 測試成功宣稱畫面或 Android 實機正常。
- 不要自行定案世界觀、遊戲名稱、畫面方向、戰鬥形式或最終美術風格。
- 不要把玩家存檔或未授權素材提交進任何倉庫。
