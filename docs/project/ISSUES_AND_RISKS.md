# 問題與風險

| ID | 類型 | 描述 | 嚴重度 | 狀態 | 解除條件／下一步 |
|---|---|---|---|---|---|
| R-001 | 環境 | Godot 版本與 headless 能力 | 高 | **resolved** | 2026-11-16 實測 Godot 4.7.2 stable：--version／--import／--script／--quit-after 皆正常。見 D-0006。 |
| R-002 | 架構 | Android 端外部內容包（PCK/ZIP）載入方案未驗證 | 高 | open | 任務 5：先做小型 PoC，再決定 D-0014。 |
| R-003 | 授權 | 使用者未來提供的素材包尚未逐包核對授權 | 高 | open（本輪無素材） | 取得素材後建立 asset_catalog 登錄與授權全文；未審核不得進公開包。 |
| R-004 | 視覺 | 不同素材包的透視、色盤、tile 尺寸可能不一致 | 中 | open（無素材） | 任務 6：建立同場景並排視覺測試板，由使用者決定。 |
| R-005 | 產品 | 畫面方向（直向／橫向）與戰鬥形式未定案 | 中 | open | v0.1 用 960×540 可調佈局，不鎖死；任務 1 視覺驗收後由使用者決定。 |
| R-006 | 環境 | 缺 JDK／Android SDK／Godot export templates，無法建置 APK | 高 | open | 任務 3：列出需求與風險請使用者核准後安裝；未核准不得自行安裝。 |
| R-007 | 驗證 | 畫面、UI 版面、字型、操作手感、Windows 執行完全未驗證 | 高 | open | 任務 1：需使用者在本機開啟專案並回報截圖與問題。headless 通過不等於畫面正常。 |
| R-008 | 環境 | 系統缺 `libfontconfig.so.1`，Godot 啟動時 stderr 警告 | 低 | open（已證實非致命） | Label 可建立、headless 邏輯不受影響；若未來桌面/Android 顯示字型異常再處理。 |
| R-009 | 內容 | client 內建 `res://content` bootstrap 與 game-content 有少量內容重複 | 低 | accepted（D-0011） | 以 `builtin_bootstrap` 與 `boot_` 前綴區隔；正式內容包方案（任務 5）完成後重新評估是否移除。 |
| R-010 | 維護性 | `content_repository.gd` 約 1058 行，驗證邏輯集中 | 中 | open | 任務 7：拆分為 manifest／驗證／模型模組，行為需與現有測試一致。 |
| R-011 | 供應鏈 | Godot 官方 release 未提供可用的 SHA256 校驗檔，下載完整性僅有本機雜湊 | 低 | open | 已記錄下載 URL、版本、檔案雜湊於 `tools/README.md`；未來若官方提供 checksum 再補比對。 |
| R-012 | 語義 | `repeatable:false` 已用 `completed_event_ids` 防重複，但「無選項事件中途離開」與事件旗標定義檔尚無正式規格 | 低 | open | 任務 7：補齊事件完成語義與旗標定義檔。 |
| R-013 | 內容 | 起始地圖目前依「第一個 region 的 map_ids[0]」推定，缺正式欄位 | 中 | open（D-0013 proposed） | 任務 2：新增 `start_map_id` 並同步兩倉庫與測試。 |

## 已解除

- R-001：Godot 環境盤點（改列為 resolved）。
