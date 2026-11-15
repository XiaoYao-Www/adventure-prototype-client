# 素材與 placeholder atlas

## v0.1 使用的素材

本輪**沒有**引入任何第三方美術素材。畫面所需素材由專案自行生成：

- `assets/generated/placeholder_tiles.png`
- `assets/generated/placeholder_tiles.json`

由 Captain 的產生器 `tools/generate_placeholder_tiles.mjs` 生成（該目錄與產生器由
Captain 維護，程式 Worker 不修改）。這些檔案是專案自行生成的暫代視覺，
**無第三方權利**；不得對外宣稱是最終美術風格，也不得聲稱為第三方素材。

## Atlas 規格

- 圖片尺寸：128 × 16 px，單格 16 × 16 px，橫向 8 格（rows = 1）。
- 索引對應：

| index | key | 用途 |
| --- | --- | --- |
| 0 | `grass` | 草地（可通行） |
| 1 | `path` | 路徑（可通行） |
| 2 | `wall` | 牆（阻擋） |
| 3 | `water` | 水（阻擋） |
| 4 | `tree` | 樹（阻擋） |
| 5 | `npc` | NPC 實體 |
| 6 | `chest` | 寶箱／物件實體 |
| 7 | `player` | 玩家角色 |

- `placeholder_tiles.json` 是中繼資料（generated / tile_size / columns / rows /
  tiles[{index,key,kind}] / license 說明）。client 的 `WorldView.extract_atlas_indices()`
  支援：
  - `{"indices": {"grass": 0, ...}}`
  - `{"tiles": {"grass": 0, ...}}` 或 `{"tiles": {"grass": {"index": 0}}}`
  - `{"tiles": [{"key": "grass", "index": 0}, ...]}`（目前實際格式）
  - `{"tile_order": ["grass", ...]}`

## 對應規則（client）

- 地形：地圖 `legend.<char>.tile` 即 atlas key（grass/path/wall/water/tree）。
- 實體：先找 `display_key` 完全相符的 atlas key；否則 `type == npc` → `npc`、
  其他 → `chest`；仍找不到時使用內建索引並記錄警告 `W_ATLAS_KEY`。
- 若 atlas 圖片或中繼資料不存在：`WorldView` 以固定色塊繪製（`FALLBACK_COLORS`），
  記錄 `W_ATLAS_MISSING` 警告並在 HUD 顯示通知；**不崩潰**。
- 縮放：Camera2D `zoom = (3, 3)` 整數倍；texture filter 使用 nearest，避免像素失真。

## 之後替換成正式美術時

1. 素材必須記錄來源、作者、版本、授權與是否允許隨遊戲／DLC 重新散布
   （工作區 `TEMPLATES/CONTENT_ASSET_RECORD.md`）。
2. 不得只因素材可下載就假設可重新散布；授權不明時不得納入。
3. 新 atlas 需維持 key 對應，或同步更新 `WorldView` 與本文件；不要讓程式依賴
   特定像素座標以外的假設。
4. v0.1 以 `_draw` 繪製；之後可換成 `TileMapLayer`，但格子語義（`MapGrid`）與
   遊戲邏輯不變。
5. 正式素材加入後，需要重新執行 `--import` 並在真機驗證視覺（本輪未驗證）。

## 授權與紀錄狀態

| 素材 | 來源 | 授權 | 狀態 |
| --- | --- | --- | --- |
| `assets/generated/placeholder_tiles.png` / `.json` | 本專案產生器生成 | 專案自有，無第三方權利 | 暫代視覺，非最終美術 |

## 字型（v0.1 APK 內建）

Android 沒有保證使用者裝置具備我們需要的正體中文字型，且 Godot 預設主題字型不含 CJK
字符；因此 v0.1 內建一套 OFL 授權的正體中文字型，並設為專案預設主題字型。

| 檔案 | 來源 | 授權 | 雜湊／版本 |
| --- | --- | --- | --- |
| `assets/fonts/NotoSansTC-VF.ttf` | Google Fonts `ofl/notosanstc`（Noto Sans TC Variable，基於 Adobe Source Han Sans） | SIL Open Font License 1.1（全文 `assets/fonts/OFL.txt`），允許內嵌、修改、再散布；保留字型名稱規範需遵守 | SHA-256 `864727d210d54f2537bbe23b3a839436c3992af72de9322af5270897246bd44f`，下載於 2026-11-16 |

- 專案設定：`project.godot` → `[gui] theme/custom_font="res://assets/fonts/NotoSansTC-VF.ttf"`。
- 本字型只用於遊戲 UI 文字；未修改字型檔，未重新命名。
- **未驗證**：Android 實機上的中文顯示、字重與行距（本環境無顯示器，headless 不呈現畫面）。
- 若之後更換字型，必須同步更新此表、`OFL.txt` 與 `tools/README.md` 紀錄。

## 使用者提供的素材（2026-11-16，尚未接入遊戲）

原始素材放在**工作區** `assets/`（不進 Git），已建立分類目錄於
`game-content/asset_catalog/`。目前 APK 仍使用上方 placeholder，尚未替換。

| 素材包 | 檔案數 | 授權 | 可否再散布 | 狀態 |
| --- | --- | --- | --- | --- |
| 16x16 Mini World Sprites（merchant-shade / octoshrimpy） | 207 | CC0-1.0 | 可 | 可接入 |
| Items16（Glionox） | 1244 | 自訂：可商用/可修改、**禁止再散布或轉售原始包** | 不可 | 僅本地／內部測試使用，不進公開 APK |

- 授權查核日：2026-11-16；依據頁面：
  https://merchant-shade.itch.io/16x16-mini-world-sprites 、
  https://glionox.itch.io/items16
- 分類／雜湊／tags：`app_data_git/asset_catalog/catalog.json`、
  `generated/index_by_category.json`；授權摘要：`asset_catalog/licenses/SUMMARY.md`。
- 聯絡表（省 token，不進版控）：工作區 `tools/asset_previews/mini_world_sprites.png`、
  `tools/asset_previews/items16.png`，對照索引為同目錄 `.json`。
- 重新產生目錄：`node tools/build_asset_catalog.mjs --assets <工作區>/assets --out <game-content>/asset_catalog`。
- 注意：Items16 沒有語意檔名，目錄只標 `item_icon`；要挑特定道具請先看聯絡表定位編號。
