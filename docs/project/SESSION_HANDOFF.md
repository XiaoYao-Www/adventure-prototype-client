# Session Handoff

> 下一輪 DSH 啟動時先讀這份，不要憑對話記憶接手。

## 下次啟動先讀（順序）

1. `docs/project/PROJECT_STATUS.md`
2. `docs/project/NEXT_ACTIONS.md`
3. `docs/project/DEVELOPMENT_LOG.md`（最近一筆：2026-11-16 第三次回饋 v0.3.0）
4. `docs/project/DECISION_LOG.md`（D-0034～D-0037 為 v0.3.0 決策）
5. `docs/project/ISSUES_AND_RISKS.md`
6. `README.md`、`docs/BUILD.md`、`docs/architecture/UPDATE_SYSTEM.md`

## 目前在哪裡

- 階段：**Phase 6**。v0.3.1 修正主頁觸控與自動更新權限卡住；v0.3.0 的內容與操作改進延續（標題主頁、對話可推進（互動鍵／點擊）、
  按住方向鍵連續移動、內容擴充（5 地圖／6 NPC／6 道具／14 事件）。
- 測試：**339/339**；內容版本 `base_world 0.2.0`（manifest 32 檔／22,572 bytes）。
- APK：`releases/android/adventure-prototype-0.3.1-debug.apk`
  （37,363,328 bytes、SHA-256 `7f480c93885c69adf655fbde630b38a87d08ab4c55dd6d7b16087e1f8297613b`、versionCode 5）。
- 自動更新與 GitHub Release 管線已上線；每日 20:00 Discord 溝通排程已建立。
- 雙倉庫：client `main`、content `main`；皆已 push。
- **尚未驗證**：實機操作手感、對話流程、主頁面、內容體驗、自動更新（本環境無 Android 裝置）。

## 下一個動作

1. 實機驗收 v0.3.1：主頁面可點開始 → 對話（互動鍵／點擊）→ 連續移動 → 探索 5 地圖；更新可否完成下載與安裝。
2. 依回饋調整手感／UI；補 Bot Token 後每日 Discord 讀訊息與回覆。
3. 決定正式 release 簽章；接入 Mini World Sprites 美術。

## 團隊

- **release-qa**（專職發布前檢查）：任何 release 前先送 QA Gate，收到 `QA GATE: PASS` 才推 tag。
- godot-engineer／content-engineer：既有實作成員（目前 inactive）。

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
- 全專案檢查：`bash tools/checks.sh`
- Discord 發送：`node tools/discord_game_send.mjs "..."`（僅 20:00–24:00）
- 每日排程：20:00「Discord 玩家溝通與每日遊戲改進」

## 不要做

- 不要在 20:00–24:00 以外發送 Discord 訊息。
- 不要 push、改 remote、force push、reset／clean 或覆蓋使用者變更。
- 不要未經核准改用 release 簽章或上架。
- 不要用「APK 建置成功」宣稱實機可玩。
- 不要把手機版受限素材（Items16）放進公開 APK。
