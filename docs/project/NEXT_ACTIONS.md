# 下一步任務

> 依依賴與優先序排列；需要使用者或環境核准的項目不得跳過。

1. **[P0｜需使用者] 實機複驗第二版 APK**
   - 內容：安裝 `releases/android/adventure-prototype-0.1.0-debug.apk`（37,302,171 bytes、
     SHA-256 `6bd14f00…2470`，橫向、arm64、Android 7+），確認：能否橫置啟動、
     左下方向鍵與右下互動鍵是否顯示、按住方向鍵是否連續移動、滑動/輕點是否有效、
     中文是否正常、選項是否可點。
   - 若仍無法操作：提供 logcat（`adb logcat -s godot`）或畫面截圖；必要時加 log 診斷。
   - 驗收：回報可操作／不可操作與具體現象。

2. **[完成] 素材授權核對與 `asset_catalog`**
   - 已完成：CC0（Mini World Sprites）與限制再散布（Items16）已核對並記錄；
     分類、tags、sha256、聯絡表已建立（content commit `494eb0e`）。
   - 後續：公開發布前需處理 Items16 限制（替換或授權）。

3. **[P1] 用真實素材替換 placeholder 美術**
   - 內容：從 `asset_catalog` 挑選 16×16 地形（草/路/水/牆/樹）、角色與物件，
     建立 TileSet/atlas 與動畫對應，替換 `_draw` placeholder；維持現有格子語義與測試。
   - 驗收：APK 畫面使用真實素材、格子比例與碰撞正確、300+ 測試通過、重建 APK。
   - 依賴：任務 2（授權）與任務 1（先確認操控可用）。

4. **[P1] 依實機回饋調整觸控與橫向版面**
   - 內容：修正安全區、按鈕大小/位置、字級、對話框遮擋；必要時加虛擬搖桿或長按連走參數調整。
   - 驗收：問題逐項關閉、測試與 APK 重建。
   - 依賴：任務 1。

5. **[P2] APK 圖示與啟動畫面**
   - 內容：用已分類素材製作 launcher icon（192/432）與簡短啟動畫面；
     設定 `application/config/icon` 與 export preset launcher icons。
   - 驗收：匯出無「No project icon」警告、圖示在裝置顯示正常。
   - 依賴：任務 3。

6. **[P2] 內容契約 v1.1：正式 `start_map_id`**
   - 內容：manifest/region 加入起始地圖欄位，同步 schema、內容、client 與測試。
   - 驗收：兩倉庫測試通過、舊內容 fallback 可讀。
   - 依賴：可與任務 3 並行。

7. **[P3] 發布與更新機制**
   - 內容：release 簽章決策（使用者持有金鑰）、版本號規則、內容更新 → APK 重建流程、
     Android 內容包（PCK）PoC。
   - 驗收：決策紀錄與可重現文件；金鑰不進 Git。
   - 依賴：任務 1、任務 3。

## 不要做（本階段）

- 不要把 `license_unverified` 素材放進公開 APK 或對外宣稱風格已定案。
- 不要未經使用者確認改用 release 簽章、上架或上傳 APK。
- 不要用「APK 建置成功」宣稱實機可玩；實機驗收未完成前不算通過。
- 不要自行定案世界觀、遊戲名稱、戰鬥形式或最終美術風格。
