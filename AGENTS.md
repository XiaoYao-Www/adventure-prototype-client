# game-client 倉庫指令（Godot 遊戲本體）

你正在維護本專案的 Godot 遊戲本體。這份檔案是此 Git 倉庫內的主要工作區指令，
不可假設父目錄的 `AGENTS.md` 一定會自動載入。

## 不可違反的共通規則

- 專案是 Android 優先、2D、格子式、視覺優先的冒險探索 RPG；不是純文字遊戲。
- 開發環境（DSH）僅使用 CPU，不得要求 GPU。本倉庫的驗證以 Godot headless 為主。
- 不使用未經核准的付費 API、雲端、插件或依賴；不安裝任何未經核准的工具。
- Godot 4.x + GDScript；本倉庫目前驗證於 Godot 4.7.2 stable。
- 兩個倉庫分離：本倉庫 `game-client`（程式）、另一個 `game-content`（內容）。
- 不覆蓋使用者變更、不 reset／clean、不改 remote、不 force push、不自動發布。
- 不提交密鑰、玩家存檔、未授權素材原始包或私人資料。
- 內容資料不得執行任意程式碼；玩家存檔與內容版本分離。
- 實際未執行的測試必須標記未執行；不得假稱 APK 已在手機測試或畫面外觀已驗證。

## 本倉庫責任

只負責程式、場景、UI、輸入、格子移動、互動、遊戲規則、內容載入、存檔、測試與
Android 建置。一般地圖、事件、NPC、任務與物品定義放在 `game-content`，
不得硬編碼在程式中。

## 寫入範圍（多人協作時）

- `tools/`、`assets/generated/`、`docs/project/` 由 Captain（Lead）維護，程式 Worker
  不寫入；`assets/generated/` 的 placeholder atlas 由專案產生器生成。
- 其餘 `app_base_git/`（程式、場景、測試、`docs/architecture`、`docs/BUILD.md`、
  `docs/ASSETS.md`、根目錄說明檔）由程式 Worker 負責。
- `game-content` 倉庫（`../app_data_git/`）只讀，不寫入。

## 開始工作前讀取

1. 本檔案與 `README.md`。
2. `docs/architecture/CONTENT_CONTRACT.md`、`docs/architecture/SAVE_FORMAT.md`。
3. `docs/BUILD.md`（建置與 headless 驗證指令）。
4. 工作區共享提示詞 `../PROMPTS/03_ENGINEERING_RULES.md`、`04_CLIENT_REPO.md`、
   `06_ARCHITECTURE_AND_DATA_CONTRACTS.md`、`09_GAMEPLAY.md`、
   `13_QA_AND_ACCEPTANCE.md`、`16_PERSISTENCE_AND_HANDOFF.md`、
   `21_ANDROID_PERFORMANCE.md`。
5. `docs/project/PROJECT_STATUS.md`、`NEXT_ACTIONS.md`、`DECISION_LOG.md`、
   `SESSION_HANDOFF.md`（若 Captain 已建立；不存在時不要自行建立權威狀態文件）。

共享提示詞位於工作區根目錄 `../PROMPTS/`（本倉庫上層）。若路徑不存在，先搜尋
工作區的 `PROMPTS/`；找不到才回報缺少文件，不要自行重建另一套規範。

## 環境事實（實測）

- Godot 執行檔：`../tools/godot/Godot_v4.7.2-stable_linux.x86_64`（Linux x86_64）。
- 每次執行前設定：

```bash
export G=/workspace/自動遊戲開發/tools/godot/Godot_v4.7.2-stable_linux.x86_64
export HOME=/workspace/自動遊戲開發/tools/home
export XDG_CONFIG_HOME=$HOME/config XDG_DATA_HOME=$HOME/data
```

- stderr 的 `libfontconfig.so.1: cannot open shared object file` 是環境缺字型庫的
  非致命警告；Label 建立與中文文字不會因此 crash。不要為此安裝任何東西。
- 沒有 GPU／顯示器／Java／Android SDK：只能 headless 驗證，不能宣稱畫面外觀或
  Android 實機已驗證。

## 常用驗證指令

```bash
timeout 120 "$G" --headless --path . --import
timeout 120 "$G" --headless --path . --script res://tests/run_tests.gd \
  -- --content-dir=/workspace/自動遊戲開發/app_data_git
timeout 120 "$G" --headless --path . --quit-after 120
```

注意：`--quit-after 120` 結束碼 0 只代表主場景能載入並執行 120 幀，不代表畫面正確。
內容目錄可用 `-- --content-dir=<abs path>` 或 ProjectSettings `game/content_dir` 覆寫。

## 任務完成時

檢查 Git diff，執行可用測試，更新 `docs/architecture`／`docs/BUILD.md`／`README.md`
中受影響的部分。回報時說明：受影響的內容 schema、遊戲版本、存檔相容性、實際執行過的
命令與結果，以及未測試部分。權威專案狀態文件（`docs/project/`）由 Captain 更新。
