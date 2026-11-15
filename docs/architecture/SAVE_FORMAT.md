# 存檔格式 v1（`user://save_01.json`）

玩家進度與內容版本分離：存檔只保存玩家狀態，不保存內容定義；內容更新不得覆寫存檔。
實作：`scripts/save/save_manager.gd`（`SaveManager`）、`scripts/core/game_state.gd`
（`GameState`）。存檔路徑為 Godot `user://`，**不得**提交進 Git 倉庫。

## 範例

```json
{
  "save_version": 1,
  "game_version": "0.1.0",
  "content_version": "0.1.0",
  "map_id": "map_start_village",
  "player": {"grid": [3, 6], "facing": "down"},
  "flags": {"flag_met_elder": true},
  "inventory": {"item_herb_001": 2},
  "completed_event_ids": ["event_chest_herb_001"],
  "updated_at": "2026-11-16T00:00:00Z"
}
```

## 欄位

| 欄位 | 型別 | 說明 | 讀檔缺少時 |
| --- | --- | --- | --- |
| `save_version` | int | 存檔格式版本；目前只支援 1 | 讀檔失敗 |
| `game_version` | string | 寫入存檔的遊戲版本 | 允許缺少（預設 0.1.0） |
| `content_version` | string | 寫入存檔時的內容版本 | 讀檔失敗 |
| `map_id` | string | 目前地圖 id，必須存在於目前內容 | 讀檔失敗 |
| `player.grid` | [int, int] | 格子座標，必須 ≥ 0 且在目前地圖範圍內 | 讀檔失敗 |
| `player.facing` | string | `up` / `down` / `left` / `right` | 預設 `down` |
| `flags` | object | 劇情旗標：string → bool | 視為空物件 |
| `inventory` | object | 物品：item_id → 正整數 | 視為空物件 |
| `completed_event_ids` | string[] | 已完成且 `repeatable: false` 的事件 id | 視為空陣列（向後相容） |
| `updated_at` | string | ISO8601 UTC，例如 `2026-11-16T00:00:00Z` | 讀檔失敗 |

## 寫入行為

- 路徑：`user://save_01.json`（`SaveManager.DEFAULT_SAVE_PATH`）。
- 先寫 `save_01.json.tmp`，成功後更名為正式檔；更名失敗時（例如 Windows 既有檔案）
  先刪除舊檔再更名，仍然失敗則回報錯誤（`E_SAVE_RENAME`），不留半寫入檔案。
- 存檔前檢查：必須有 `map_id`、玩家座標不可為負（`E_SAVE_STATE`）。
- F5 = 存檔（`save_game` action）、F9 = 讀檔（`load_game` action）。
- 存檔不會寫入內容目錄或 Git 工作區。

## 讀檔行為與錯誤處理

1. 找不到檔案 → `E_SAVE_NOT_FOUND`（「找不到存檔」），不改變目前狀態。
2. 檔案 > 1 MiB → `E_SAVE_TOO_LARGE`。
3. JSON 解析失敗 → `E_SAVE_JSON`（含行號），不覆寫存檔。
4. 格式驗證（`validate_save_data`）失敗 → 列出所有錯誤；**不支援的
   `save_version` 不會被覆寫或自動轉換**（`E_SAVE_VERSION`）。
5. 通過後由 `GameSession.restore_from_save()` 還原：
   - `map_id` 不存在於內容 → 還原失敗（ErrorPanel），不崩潰。
   - 座標超出地圖範圍 → 記警告並改用該地圖 spawn。
   - 存檔 `content_version` 與目前內容版本不同 → 記警告但可繼續（內容版本分離）。
6. 讀檔完成後重建 WorldView、玩家位置、HUD 與互動提示；抵達格若剛好是 portal，
   套用抵達抑制（與傳送門抵達語義一致）。

## 版本政策

- `save_version` 只在格式**不相容**時遞增。新增可選欄位（如
  `completed_event_ids`）不遞增版本，讀檔缺少時使用預設值。
- 未來 `save_version > 1` 時，client 必須：
  1. 顯示錯誤並保留原檔案（不得覆寫）；
  2. 提供版本化遷移程序（尚未實作）；
  3. 遷移後仍保留舊檔備份。
- 內容版本（`content_version`）與存檔格式版本（`save_version`）是不同概念，
  不可混用。

## 與內容版本分離的原則

- 玩家進度（flags／inventory／位置／已完成事件）屬玩家資料。
- 地圖、事件、NPC、物品定義屬內容資料，內容更新不應改寫玩家存檔。
- 內容新增事件時，存檔中的 `completed_event_ids` 只影響對應實體是否還能互動；
  不存在的 id 會被忽略。
