# 決策紀錄

狀態只允許：`proposed`、`accepted`、`rejected`、`superseded`。
只有使用者明確確認、或明確授權 AI 自行定案的範圍，才能標記 `accepted`；其餘為 `proposed`。

| ID | 日期 | 決策 | 狀態 | 理由／證據 | 影響範圍 |
|---|---|---|---|---|---|
| D-0001 | 2026-11-16 | 採用兩個 Git 倉庫：遊戲本體與遊戲內容分離 | accepted | 使用者明確需求 | repository boundaries |
| D-0002 | 2026-11-16 | 採用視覺優先的 2D 格子探索方向 | accepted | 使用者明確偏好格子；不喜歡純文字遊戲 | game design |
| D-0003 | 2026-11-16 | Godot 4.x + GDScript 作為技術方案 | accepted | 使用者在 2026-11-16 核准下載 Godot 4.7.2 官方 Linux 版並用於本專案 | technical stack |
| D-0004 | 2026-11-16 | 16×16 像素素材作為主要規格候選 | proposed | 使用者提供 16×16 素材包參考；尚無素材可驗證 | art pipeline |
| D-0005 | 2026-11-16 | 成人內容以可選獨立模組提供 | proposed | 使用者要求含成人內容但不只色情；實作未開始 | content packaging |
| D-0006 | 2026-11-16 | 引擎版本定案：Godot 4.7.2 stable（官方 Linux x86_64，MIT） | accepted | 使用者核准下載；實測 `4.7.2.stable.official.ed1daf0bf`；headless 匯入與測試通過 | toolchain、所有 client 程式 |
| D-0007 | 2026-11-16 | 倉庫路徑映射：`app_base_git` = game-client、`app_data_git` = game-content；不搬移、不改名、不新增第三個倉庫 | accepted | 使用者於啟動詢問中確認 | repository boundaries |
| D-0008 | 2026-11-16 | 內容格式 v1：JSON 資料 + `manifest.json`（sha256/size）+ `schemas/*.schema.json`；`schema_version=1` | accepted | 在已授權的 v0.1 技術範圍內由 Lead 決定；使用者可隨時要求變更 | content contract、client loader |
| D-0009 | 2026-11-16 | 效果白名單 v1 僅 `set_flag`、`give_item`；未知 effect type 一律拒絕、不猜測執行 | accepted | 縮小攻擊面與驗證範圍，符合「內容不執行任意程式碼」 | content contract、client loader |
| D-0010 | 2026-11-16 | 內容與呈現解耦：內容只使用語意值（`tile` key、`display_key`），client 負責對應 placeholder atlas | accepted | 讓未來替換正式素材時不必改內容資料 | content contract、art pipeline |
| D-0011 | 2026-11-16 | 保留 client 內建 `res://content` bootstrap 範例作為離線啟動 fallback | **superseded**（by D-0018） | 已被「game-content 建置快照」取代 | client repo、載入順序 |
| D-0012 | 2026-11-16 | 提交 Godot 4.7 產生的 `*.uid` 與 `*.import`，但不提交 `.godot/` 快取 | accepted | 官方建議保留 uid；`.godot/` 可由匯入重建 | git、client repo |
| D-0013 | 2026-11-16 | 起始地圖暫定規則：第一個 region（id 排序）的 `map_ids[0]`，否則取 map id 排序第一張 | proposed | 契約 v1 沒有正式 `start_map_id`；內容作者調整區域順序會改變起始點 | content contract v1.1 |
| D-0014 | 2026-11-16 | 內容包發布容器（PCK／ZIP／自訂） | proposed | 尚未做技術驗證；D-0011 的 res://content 僅為開發用 bootstrap | release、Android 更新 |
| D-0015 | 2026-11-16 | 畫面方向（直向／橫向）與戰鬥形式 | proposed | 尚未定案；v0.1 採 960×540 可調整佈局，未鎖死 | UX、game design |
| D-0016 | 2026-11-16 | Android 建置管線：Godot 非 gradle debug 匯出；arm64-v8a、minSdk 24、targetSdk 36；工具鏈（JDK 17、build-tools 36.1、platform-tools、platform android-36、export templates 4.7.2）安裝於工作區 `tools/` | accepted | 使用者明確指示自行配置環境並產出 APK；建置與驗證成功 | toolchain、release |
| D-0017 | 2026-11-16 | 將 debug APK 成品提交進 game-client 倉庫（`releases/android/`），作為「不提交產生檔」規則的明確例外 | accepted | 使用者明確要求「編譯成 APK，提交進倉庫」 | git、release |
| D-0018 | 2026-11-16 | APK 內建內容改為 game-content 的建置快照：`res://content` 由 `tools/sync_content_bundle.mjs` 從 game-content 驗證後產生，移除 `boot_*` bootstrap；此決策取代 D-0011 | accepted | 讓 APK 內含權威內容；快照可重建、manifest 雜湊可追溯 | content contract、release |
| D-0019 | 2026-11-16 | 內建 Noto Sans TC Variable（SIL OFL 1.1）作為專案預設字型 | accepted | Godot 預設字型不含 CJK、Android 不保證系統字型；授權允許內嵌散布 | client repo、art/font |
| D-0020 | 2026-11-16 | APK 螢幕方向：**橫向**（`sensor landscape`，左右橫置皆可） | accepted | 使用者 2026-11-16 明確指示「遊戲應該要是橫版（手機橫置遊玩）」 | UX、Android |
| D-0021 | 2026-11-16 | 建置 Java 工具鏈一律以 UTF-8 locale 執行（`LANG=C.UTF-8`） | accepted | 非 ASCII 工作區路徑在非 UTF-8 locale 下會讓 Java 路徑變成 `?`，導致 keytool/apksigner 失敗 | 建置流程 |
| D-0022 | 2026-11-16 | 加入觸控虛擬控制（方向鍵、互動、存檔、讀檔），mobile 自動顯示、桌機隱藏 | accepted | Android 手機無鍵盤，缺少觸控即無法遊玩；已加 12 項測試 | client UI、Android |

| D-0023 | 2026-11-16 | 觸控控制改為「自繪 UI + 手動命中測試」實作（不再用 Button 節點）；支援按住連走、世界滑動轉向、輕點互動；對話時阻擋 | accepted | 第一版實機回報「沒有有效操作方法」，需移除 Control 佈局依賴並增加可測試性；已用 InputEvent 模擬測試 | client UI、Android 輸入 |
| D-0024 | 2026-11-16 | 導入使用者提供的素材：Mini World Sprites 與 Items16；先建立 asset_catalog 分類／雜湊／授權狀態，暫不進 APK | accepted | 使用者要求自行分類與標記；授權尚未逐包核對（license_unverified），不得發布 | art pipeline、content repo |
| D-0025 | 2026-11-16 | 素材授權分類：Mini World Sprites 採 CC0-1.0 可再散布；Items16 僅「內部使用」不得進公開 APK（redistributable=false） | accepted | itch.io 頁面授權已核對（2026-11-16）；專案規則要求再散布受限素材必須隔離 | art pipeline、release |
| D-0026 | 2026-11-16 | 兩個 GitHub 遠端倉庫：client=adventure-prototype-client、data=adventure-prototype-data；本地分支改為 `main` 對齊遠端預設分支；採每倉庫一把 SSH deploy key（write） | accepted | 使用者提供兩個 GitHub repo 並要求連接；deploy key 最小權限 | repository、release |

## 變更規則

- 不可覆寫歷史；決策改變時新增一筆並將舊決策標為 `superseded`。
- 涉及世界觀、美學、發行方式的決策，需使用者確認後才可從 `proposed` 轉 `accepted`。
