# 下一步任務

> 依依賴與優先序排列；需要使用者或環境核准的項目不得跳過。

1. **[P0｜需使用者] 實機驗收 v0.2.0**
   - 安裝 `releases/android/adventure-prototype-0.2.0-debug.apk`（37,340,085 bytes、
     SHA-256 `eeb661af…6d17`），確認：觸控可操作、橫向顯示、中文；啟動時右上角是否
     出現更新檢查、是否有下載／安裝提示。
   - 回報 logcat（`adb logcat -s godot`）中的更新相關訊息與畫面截圖。

2. **[P0] 驗證 GitHub Release 與更新資訊**
   - 確認 client release 資產含 APK 與 `latest.json`、data release 含內容包與
     `latest_data.json`，且 App 讀到的版本／雜湊正確。
   - 目前 v0.2.0 的 latest.json 會指向同版本（不觸發更新），可用「先發布 v0.2.1」驗證更新流程。

3. **[P1｜需使用者] 正式 release 簽章決策（R-025/R-014）**
   - 決定 release keystore 由誰持有、如何注入 CI（GitHub Secrets）、版本號策略。
   - 未決定前，自動更新只能用同一 debug keystore 簽署的 APK。

4. **[P1] 素材接入遊戲（Mini World Sprites，CC0）**
   - 以 asset_catalog 建立 TileSet 與角色動畫，替換 placeholder；Items16 僅內部測試用。

5. **[P2] 更新體驗強化**
   - 下載進度 UI、Wi-Fi-only、失敗重試佇列、內容熱重載、更新檢查頻率設定。

6. **[P2] 內容契約 v1.1：正式 `start_map_id`**。

7. **[P2｜需使用者] 倉庫／release 可見性決策（R-029）**。
