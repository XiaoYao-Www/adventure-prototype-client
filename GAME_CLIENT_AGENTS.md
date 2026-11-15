# game-client 倉庫指令

你正在維護 Godot 遊戲本體。這份檔案會在此 Git 倉庫內作為主要工作區指令，因此不可假設父目錄的 `AGENTS.md` 一定會自動載入。

## 不可違反的共通規則

- 專案是 Android 優先、2D、格子式、視覺優先的冒險探索 RPG；不是純文字遊戲。
- DSH 在 Unraid 上只使用 CPU，不得要求 GPU。
- 不使用未經核准的付費 API、雲端、插件或依賴。
- Godot 4.x + GDScript 是待驗證候選；先檢查現有專案與實際版本。
- 兩個倉庫分離：本倉庫 `game-client`、另一個 `game-content`。
- 不覆蓋使用者變更，不 reset／clean，不改 remote，不 force push，不自動發布。
- 不提交密鑰、玩家存檔、未授權素材原始包或私人資料。
- 內容資料不得執行任意程式碼；玩家存檔與內容版本分離。
- 實際未執行的測試必須標記未執行；不得假稱 APK 已在手機測試。

## 本倉庫責任

只負責程式、場景、UI、輸入、格子移動、互動、遊戲規則、內容載入、存檔、測試與 Android 建置。一般地圖、事件、NPC、任務與物品定義應放入 `game-content`，不得硬編碼在程式中。

## 開始工作前讀取

1. `docs/project/PROJECT_STATUS.md`
2. `docs/project/NEXT_ACTIONS.md`
3. `docs/project/DECISION_LOG.md`
4. `docs/project/SESSION_HANDOFF.md`
5. 工作區共享提示詞中的 `PROMPTS/03_ENGINEERING_RULES.md`、`04_CLIENT_REPO.md`、`06_ARCHITECTURE_AND_DATA_CONTRACTS.md`、`13_QA_AND_ACCEPTANCE.md`、`16_PERSISTENCE_AND_HANDOFF.md`、`17_CHANGE_CONTROL_AND_GIT.md`。

若共享提示詞路徑不存在，先搜尋工作區的 `PROMPTS/`；找不到才回報缺少文件，不要自行重建另一套規範。

## 任務完成時

檢查 Git diff，執行可用測試，更新專案狀態、開發紀錄、風險與交接。說明受影響的內容 schema、遊戲版本、存檔相容性與未測試部分。
