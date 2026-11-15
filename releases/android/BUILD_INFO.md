# APK 建置資訊（v0.3.0 debug）

| 項目 | 值 |
| --- | --- |
| 檔案 | `adventure-prototype-0.3.0-debug.apk` |
| SHA-256 | `23bcb879804ede61041dc1c7f46a16d2f276d4cc6ca75e8e76ea737382114040` |
| 大小 | 37,363,165 bytes（約 35.6 MiB） |
| 建置時間 | 2026-11-16 02:28（Asia/Taipei） |
| 版本 | 0.3.0（versionCode 4） |
| 內容版本 | `base_world` 0.2.0（32 檔／22,572 bytes；5 地圖、6 NPC、6 道具、14 事件） |
| 套件 ID | `com.dsh.adventureprototype` |
| minSdk / targetSdk / compileSdk | 24 / 36 / 36 |
| 架構 | `arm64-v8a` only |
| 螢幕方向 | 橫向（sensor landscape） |
| 權限 | INTERNET、REQUEST_INSTALL_PACKAGES |
| 簽章 | debug keystore（CN=Android Debug；固定同一把以支援自動更新） |
| 本版重點 | 標題主頁面；對話可用「互動」鍵／點擊畫面推進；按住方向鍵連續移動（輪詢）；內容擴充為 5 地圖／6 NPC／14 事件 |

## 驗證

- headless 測試 **TESTS OK 336/336**
- 內容驗證器 CONTENT OK（32 檔、5 地圖、6 NPC、6 道具、14 事件）
- APK：apksigner OK、zipalign OK、versionCode 4 / versionName 0.3.0
- 未驗證：實機安裝、觸控手感、對話與移動體驗、更新流程（本環境無 Android 裝置）
