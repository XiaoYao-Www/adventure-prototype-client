# 內容資料契約 v1（client 端實作）

本文件描述 `game-client` 如何解讀 `game-content` 倉庫的內容。內容格式的權威定義
以 `game-content` 的 `docs/CONTENT_SCHEMA.md` 與 `schemas/*.schema.json` 為準；
本文件記錄 **client 實際驗證的規則**、容錯行為與 v0.1 的暫定解釋。

- 遊戲版本：0.1.0
- 契約版本：content schema_version = 1、manifest_schema = 1
- 載入器：`scripts/content/content_repository.gd`（`ContentRepository`）
- 內容資料不執行任何程式碼；未知內容只會被拒絕或忽略，不會被執行。

## 1. 內容來源解析順序

1. CLI 使用者參數：`--content-dir=<abs path>`（`OS.get_cmdline_user_args()`；
   也接受 `--content-dir <path>`）。
2. ProjectSettings：`game/content_dir`（預設空字串）。
3. `res://content`（內建 bootstrap 範例）。

外部絕對路徑（game-content 倉庫根目錄）可讀取；`res://` 路徑亦可。載入器不修改
內容目錄中的任何檔案。

## 2. manifest.json

```json
{
  "manifest_schema": 1,
  "content_id": "base_world",
  "content_version": "0.1.0",
  "schema_version": 1,
  "min_game_version": "0.1.0",
  "dependencies": [],
  "files": [
    {"path": "world/maps/start_village.json", "sha256": "<64hex>", "size": 1234}
  ]
}
```

Client 驗證規則：

| 欄位 | 規則 | 失敗結果 |
| --- | --- | --- |
| `manifest_schema` | 整數 = 1 | E_MANIFEST_SCHEMA |
| `content_id` | 非空字串（≤128） | E_FIELD |
| `content_version` | 非空字串（≤64） | E_FIELD |
| `schema_version` | 整數 = 1 | E_CONTENT_SCHEMA |
| `min_game_version` | 非空字串；`> 0.1.0` 時拒絕載入 | E_FIELD / E_CONTENT_TOO_NEW |
| `dependencies` | 陣列；v0.1 不解析，非空時只警告 | W_MANIFEST_DEPS |
| `files` | 非空陣列、≤512 筆 | E_MANIFEST_FILES |

`files[]` 驗證：

- `path`：相對路徑、以 `/` 分隔、不得為絕對路徑、不得含 `..`／`.` 段或磁碟代號、
  必須以 `.json` 結尾、≤256 字元；重複 path → E_MANIFEST_DUP。
- **必須依 path 遞增排序**（`E_MANIFEST_UNSORTED`）。
- `sha256`：64 位小寫十六進位（`E_MANIFEST_SHA`）。
- `size`：整數、0..4 MiB（`E_MANIFEST_SIZE`）。
- 檔案必須存在（`E_FILE_MISSING`）、大小相符（`E_SIZE_MISMATCH`）、
  sha256 相符（`E_HASH_MISMATCH`）。
- **只有 path/size/sha256 全部通過的檔案才會被解析**；其他檔案跳過並記錄錯誤，
  不會中斷其他檔案的驗證（一次載入收集所有錯誤）。
- 未列於 manifest 的 `.json`（排除 `manifest.json`、`schemas/`、`docs/`、隱藏目錄）
  只產生警告 `W_UNLISTED_FILE`。

## 3. 資料檔案分類

依 manifest 內 path 前綴決定種類：

| 前綴 | 種類 | ID 欄位 |
| --- | --- | --- |
| `world/maps/` | 地圖 | `id`（例：`map_start_village`） |
| `world/regions/` | 區域 | `id` |
| `characters/npcs/` | NPC | `id` |
| `items/` | 道具 | `id` |
| `events/` | 事件 | `id` |

每筆資料都必須有 `schema_version: 1`（`E_DATA_SCHEMA`）。同一種類的 `id` 不可重複
（`E_DUP_*_ID`）。其他前綴 → 警告 `W_UNKNOWN_FILE` 並忽略。

檔案名稱與 `id` 無強制對應（例如 `world/maps/start_village.json` 的 id 是
`map_start_village`），只驗證 id 唯一。

## 4. 地圖 schema

```json
{
  "schema_version": 1,
  "id": "map_start_village",
  "name": "起始村落（暫定）",
  "size": {"width": 12, "height": 9},
  "tile_size": 16,
  "tiles": ["##########..", "..."],
  "legend": {"#": {"tile": "wall", "walkable": false}},
  "spawn": {"grid": [3, 6]},
  "entities": [{"id": "...", "type": "npc", "grid": [5, 5],
                "display_key": "npc_elder",
                "interaction": {"kind": "event", "event_id": "..."}}],
  "portals": [{"id": "...", "grid": [10, 7], "target_map_id": "map_forest_edge",
               "target_grid": [2, 5]}]
}
```

| 檢查 | 錯誤碼 |
| --- | --- |
| `size.width/height` 整數 1..256 | E_FIELD |
| `tile_size` 整數 1..128 | E_FIELD |
| `tiles` 為字串陣列、列數 = height | E_MAP_TILES |
| 每列長度 = width | E_MAP_TILES |
| `legend` 每個 key 是單一字元、值為 `{tile: 非空字串, walkable: bool}` | E_MAP_LEGEND |
| legend 覆蓋 tiles 用到的所有字元 | E_MAP_LEGEND |
| legend 有未使用的字元 | 僅警告 W_MAP_LEGEND_UNUSED |
| `spawn.grid` 在範圍內且可通行 | E_MAP_SPAWN |
| entities 為陣列、≤256 筆；`type` ∈ {`npc`, `object`}；id 不重複、`display_key` 非空 | E_MAP_ENTITY |
| entity `grid` 在範圍內且地形可通行（實體站在可通行地形上） | E_MAP_ENTITY |
| entity `interaction.kind` 必須是 `event`、`event_id` 非空 | E_MAP_ENTITY |
| portals 為陣列、≤64 筆；id 不重複；grid 在範圍內且可通行；`target_map_id` 非空；`target_grid` 為 [x,y] | E_MAP_PORTAL |
| portal 目標地圖存在、target_grid 在目標地圖範圍內且可通行 | E_MISSING_MAP_REF / E_MAP_PORTAL_TARGET |

實體會佔用格子：玩家不可進入有實體（NPC／物件）的格子。地圖本身不允許「實體站在
不可通行地形上」，避免玩家永遠無法互動。

## 5. region / NPC / item / event schema

- region：`id`、`name` 非空；`map_ids` 為非空陣列且每個 map 存在
  （`E_MISSING_MAP_REF`）；`notes` 選填。
- NPC：`id`、`name` 非空；`role`／`short_description`／`speech_style` 選填字串；
  `is_adult` 應為布林（缺少時警告 `W_NPC_IS_ADULT`，保留給成人內容模組）。
- item：`id`、`name`、`category` 非空；`stack_limit` 整數 1..9999。
- event：
  - `kind` 必須是 `dialogue`（v0.1 唯一支援）。
  - `trigger`：`{map_id, entity_id}` 都非空；map 與 entity 必須存在，且該 entity 的
    `interaction.event_id` 必須等於本 event id（雙向一致，否則 E_EVENT_TRIGGER_MISMATCH）。
  - `repeatable`：布林；缺少時警告 `W_EVENT_REPEATABLE` 並預設 true。
  - `lines`：非空陣列（≤200），每句 `{speaker_id, text}`；`speaker_id` 必須是
    `"player"` 或存在的 NPC id（`E_MISSING_NPC_REF`）。
  - `choices`：選填陣列（≤8）；每個 choice `{id, text, effects}`，id 不重複、text 非空。
  - entity 若引用不存在的 event_id → `E_MISSING_EVENT_REF`。

## 6. Effects registry（v0.1）

| type | 參數 | 規則 |
| --- | --- | --- |
| `set_flag` | `flag`: string, `value`: bool | flag 只能使用小寫字母／數字／底線、≤64 字元 |
| `give_item` | `item_id`: string, `qty`: int | qty 必須是正整數（1..9999）；item_id 必須存在於 `items/` |

- 未知 `type` → `E_EFFECT_UNKNOWN`，**該事件載入失敗**，不推測執行。
- 參數型別／範圍錯誤 → `E_FIELD`（事件同樣拒絕載入）。
- 未知的額外欄位 → 只警告 `W_EFFECT_EXTRA`，不影響載入。
- 執行期 `GameSession.apply_effects()` 仍會再做一次防禦性檢查；未知 type／錯誤參數
  會記錄錯誤且不改變狀態（測試涵蓋）。

## 7. 起始地圖（v0.1 暫定規則）

契約 v1 沒有 `start_map` 欄位。Client 的暫定規則：

1. 依 `region` id 排序，取第一個 region 的 `map_ids[0]`（且該 map 存在）。
2. 沒有 region 時，取 map id 排序第一個。

此規則屬**暫定假設**，待 Captain／內容倉庫裁決是否在 manifest 或 region 增加正式
`start_map_id` 欄位。真實內容 `base_world` 目前第一個 region 為
`region_starting_001`，`map_ids[0] = map_start_village`，符合預期。

## 8. 互動語義（v0.1）

- 互動目標 = 玩家**面向格**（最後移動方向 +1 格）。
- 面向格有實體且事件的 `repeatable`／完成狀態允許時，HUD 顯示「E 互動：<名稱>」。
- 沒有相鄰格自動搜尋；不支援同格互動。
- 事件 `repeatable: false` 完成後，事件 id 寫入存檔 `completed_event_ids`，
  該實體不再顯示提示、也不再觸發；`repeatable: true` 可重複互動。

## 9. 容錯與回報

- 缺少 manifest → `E_NO_MANIFEST`（HUD／ErrorPanel 顯示「找不到內容」），不崩潰。
- 任何驗證錯誤：載入器收集所有可讀錯誤（`E_*` code + 說明），主場景顯示 ErrorPanel
  並停止進入遊戲；不覆寫任何內容檔案。
- 單一檔案解析失敗不影響其他檔案；已驗證的資料仍保留在記憶體中供除錯顯示。
- 警告（`W_*`）不阻止遊戲啟動。

## 10. 尚未支援（v0.1）

- `dependencies` 內容相依解析、內容下載／安裝／版本切換。
- `schemas/`、`docs/`（不列入 manifest，client 不讀取）。
- 成人內容模組（`optional_content/adult/`）：內容倉庫已預留，client 本輪不載入。
- 地圖內更多 tile 種類、動畫、音效、戰鬥、任務、商店等。
