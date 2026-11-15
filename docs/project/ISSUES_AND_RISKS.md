# 問題與風險

| ID | 類型 | 描述 | 嚴重度 | 狀態 | 解除條件／下一步 |
|---|---|---|---|---|---|
| R-001 | 環境 | Godot 版本與 headless 能力 | 高 | **resolved** | 實測 Godot 4.7.2：--version／--import／--script／--quit-after／--export-debug 皆正常。 |
| R-002 | 架構 | Android 端外部內容包（PCK/ZIP）載入與更新未驗證 | 高 | open | 任務 7：PoC 再決定 D-0014；目前 APK 用內建快照 + 重建流程。 |
| R-003 | 授權 | 使用者未來提供的素材包尚未逐包核對授權 | 高 | open（目前僅內建自製 placeholder 與 OFL 字型） | 取得素材後建立 asset_catalog 登錄與授權全文。 |
| R-004 | 視覺 | 不同素材包的透視、色盤、tile 尺寸可能不一致 | 中 | open（無素材） | 任務 6：同場景並排視覺測試板，由使用者決定。 |
| R-005 | 產品 | 畫面方向（直向／橫向）與戰鬥形式未定案 | 中 | open | APK 目前用 `sensor` 不鎖方向；任務 6 由使用者決定。 |
| R-006 | 環境 | 缺 JDK／Android SDK／export templates，無法建置 APK | 高 | **resolved** | 已自行安裝 JDK 17／build-tools 36.1／platform-tools／android-36／templates，APK 建置成功（D-0016）。 |
| R-007 | 驗證 | 畫面、UI 版面、字型排版、操作手感、Windows 執行未驗證 | 高 | open（部分緩解） | 字型字形與觸控訊號已測試，但畫面外觀仍需任務 1／6 的實機或桌面驗證。 |
| R-008 | 環境 | 系統缺 `libfontconfig.so.1`，Godot 啟動 stderr 警告 | 低 | open（非致命） | 專案已內建 CJK 字型；桌面若字型異常再處理。 |
| R-009 | 內容 | client `res://content` 與 game-content 內容重複 | 低 | **resolved（改為快照機制）** | D-0018：bootstrap 改為 game-content 建置快照，由 sync 工具產生並記錄來源。 |
| R-010 | 維護性 | `content_repository.gd` 約 1060 行，驗證邏輯集中 | 中 | open | 任務 7：拆分 manifest／驗證／模型模組，行為需與 288 項測試一致。 |
| R-011 | 供應鏈 | Godot 官方 release 未提供可用的 SHA256 校驗檔 | 低 | open | 已記錄下載 URL、版本與本機雜湊於 `tools/README.md`。 |
| R-012 | 語義 | `repeatable:false` 已用 `completed_event_ids` 防重複，但「無選項事件中途離開」與旗標定義檔無正式規格 | 低 | open | 任務 7 補齊。 |
| R-013 | 內容 | 起始地圖依「第一個 region 的 map_ids[0]」推定，缺正式欄位 | 中 | open（D-0013 proposed） | 任務 5 新增 `start_map_id`。 |
| R-014 | 發布 | APK 目前只有 debug 簽章，不可上架；release 金鑰未建立 | 高 | open | 任務 3：由使用者決定 release 簽章持有方式與流程。 |
| R-015 | 相容性 | APK 只含 arm64-v8a；armeabi-v7a／x86_64 不支援（模擬器多為 x86_64） | 中 | open | 需要時調整 export preset 重建（任務 7）。 |
| R-016 | 驗證 | APK 未在 Android 實機／模擬器安裝、啟動與操作 | 高 | open | 任務 1：需要使用者實機測試；本環境無 Android 裝置。 |
| R-017 | 倉庫 | APK（約 35.6MB）已提交進 Git，repo 體積會隨每次重建增加 | 中 | accepted（D-0017，使用者明確指示） | 每次重建更新 BUILD_INFO；若 repo 過大，之後改為 release 附件或 LFS（需使用者決定）。 |
| R-018 | 可用性 | 第一版觸控在實機無效；第二版改為自繪＋命中測試並有完整模擬測試，但**尚未實機複驗** | 高 | open（已重寫，待驗） | 任務 1：實機回報第二版是否可操作；仍失敗則需抓 logcat。 |
| R-019 | 字型 | 中文在 Android 的實際渲染（缺字、行距、字重）未驗證；僅驗證字型含字形且已打包 | 中 | open | 任務 1：實機截圖確認。 |
| R-020 | 環境 | 建置工具鏈在 `tools/` 不進 Git，換機器需重新安裝（腳本已文件化） | 中 | open（可接受） | `tools/build_android.sh` 與 `docs/BUILD.md` 已記錄步驟；需要時改為容器化。 |
| R-021 | 授權 | 兩包授權已核對：Mini World Sprites 為 CC0-1.0；Items16 可商用/修改但禁止再散布原始包 | 高 | **resolved（有限制）** | Items16 標 `redistributable=false`，不得進公開 APK；日後公開發布需替換或取得許可。 |
| R-022 | 美術整合 | 素材尚未替換遊戲內 placeholder（目前畫面仍是專案自製圖與色塊） | 中 | open | 任務 3：依 asset_catalog 挑選地形／角色並建置 TileSet 與替換（Items16 僅內部測試用）。 |
| R-023 | 素材 | Items16 無語意檔名／對照表，1244 張圖示尚未逐張語意分類 | 低 | open | 需要時用聯絡表定位編號再建立 mapping；不要用編號猜類型。 |
