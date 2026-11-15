# 下一步任務

> 依依賴與優先序排列；需要使用者或環境核准的項目不得跳過。

1. **[P0｜需使用者] 實機驗證自動更新（v0.2.0 → v0.2.1）**
   - 下載並安裝 **v0.2.0** APK：
     `https://github.com/XiaoYao-Www/adventure-prototype-client/releases/download/v0.2.0/adventure-prototype-0.2.0-debug.apk`
   - 開啟遊戲：應先顯示「檢查遊戲更新…」→ 下載 v0.2.1 → 跳出系統安裝確認。
     首次需允許「安裝未知的應用程式」；完成後版本應為 0.2.1。
   - 回報 logcat（`adb logcat -s godot`）與畫面。

2. **[P0｜需使用者] 實機驗證內容更新（0.1.0 → 0.1.1）**
   - 安裝／更新到 v0.2.1 後啟動：bundled 內容 0.1.0、最新 0.1.1 →
     應顯示內容下載與「內容已更新…下次啟動生效」；重啟後村長對話多一句森林路況。
   - 若未觸發，稍等 5 分鐘再啟動（GitHub CDN 快取，R-031）。

3. **[P1｜需使用者] 正式 release 簽章決策**（R-025/R-014）：release keystore 持有方式、
   GitHub Secrets 注入、版本號策略；未決定前更新只支援同 debug 簽章。

4. **[P1] 素材接入遊戲**（Mini World Sprites CC0；Items16 僅內部測試）。

5. **[P2] 更新體驗強化**：下載進度 UI、Wi-Fi-only、失敗重試佇列、內容熱重載、更新資訊 cache-buster。

6. **[P2] 內容契約 v1.1：正式 `start_map_id`**。

7. **[P2｜需使用者] 倉庫／release 可見性決策（R-029）**。

## 每日固定（20:00–24:00）

- 讀取 Discord 玩家訊息（需 Bot Token）→ 回覆 → 至少一項遊戲改進 → 測試 → 必要時 release → 日報。
- 目前缺少：**Discord Bot Token**（R-032）。提供後即可自動讀取與回覆。
