# game-client 內容工具（Node.js，零依賴）

這些工具只做「內容資料的靜態驗證與發布輔助」，不是遊戲執行邏輯，也不會被包進 APK。
執行環境：Node.js 18+（本專案驗證於 v24.21.0）。不安裝 npm 套件、不連網。

## validate_content.mjs

獨立驗證 `game-content` 內容包，和遊戲內載入器互為交叉驗證。

```sh
node tools/validate_content.mjs /workspace/自動遊戲開發/app_data_git
```

檢查：manifest 結構與版本、JSON 可解析、內建結構規則、schema（若存在）、地圖尺寸與
legend、spawn／entity／portal 可通行、引用完整性、ID 唯一與命名、sha256/size、
禁止可執行檔與 symlink。exit code：0 = 通過、1 = 有 error、2 = 用法錯誤。

## build_content_manifest.mjs

內容變更後重建 `manifest.json` 的 `files`（sha256 + size）：

```sh
node tools/build_content_manifest.mjs /workspace/自動遊戲開發/app_data_git
node tools/build_content_manifest.mjs /workspace/自動遊戲開發/app_data_git --check
```

只改寫 `files` 欄位，版本欄位保留。`--check` 不寫入，只用來確認 manifest 是否過期。

## generate_placeholder_tiles.mjs

產生暫代像素圖集（本專案自行生成，無第三方權利）：

```sh
node tools/generate_placeholder_tiles.mjs
```

輸出 `assets/generated/placeholder_tiles.png`（16x16、8 格橫排）與
`placeholder_tiles.json`。索引固定：0 grass、1 path、2 wall、3 water、4 tree、
5 npc、6 chest、7 player。正式美術定案後應整批替換，不可混用不同來源。

## 測試

```sh
node --test tools/tests/content_tools.test.mjs
```

以暫存目錄建立合法內容包與 8 種破壞情境，確認驗證器與 manifest 產生器行為正確。
測試會自行清理暫存目錄，不需要 Godot。

## 素材目錄與聯絡表工具

```bash
# 1) 建立 game-content/asset_catalog（分類、tags、sha256、授權摘要）
node app_base_git/tools/build_asset_catalog.mjs \
  --assets /workspace/自動遊戲開發/assets \
  --out /workspace/自動遊戲開發/app_data_git/asset_catalog

# 2) 產生聯絡表（省 token 的素材總覽，輸出到工作區 tools/asset_previews）
"$G" --headless --path app_base_git --script res://tools/make_contact_sheets.gd -- \
  --assets=/workspace/自動遊戲開發/assets \
  --out=/workspace/自動遊戲開發/tools/asset_previews
```

- 原始素材在工作區 `assets/`（不進 Git）；Items16 授權禁止再散布，不得放進公開 APK。
- 聯絡表依列優先排列，格子索引對照同目錄 `.json`，不必逐張開圖。
