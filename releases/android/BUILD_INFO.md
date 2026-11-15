# APK 建置資訊（v0.3.1 debug）

| 項目 | 值 |
| --- | --- |
| 檔案 | `adventure-prototype-0.3.1-debug.apk` |
| SHA-256 | `7f480c93885c69adf655fbde630b38a87d08ab4c55dd6d7b16087e1f8297613b` |
| 大小 | 37,363,328 bytes（約 35.6 MiB） |
| 建置時間 | 2026-11-16 02:36（Asia/Taipei） |
| 版本 | 0.3.1（versionCode 5） |
| 內容版本 | `base_world` 0.2.0（32 檔／22,572 bytes） |
| 套件 ID | `com.dsh.adventureprototype` |
| minSdk / targetSdk / compileSdk | 24 / 36 / 36 |
| 架構 | `arm64-v8a` only |
| 螢幕方向 | 橫向（sensor landscape） |
| 權限 | INTERNET、REQUEST_INSTALL_PACKAGES |
| 簽章 | debug keystore（固定同一把以支援自動更新） |
| 本版修正 | ①主頁按鈕可直接觸控（不再被觸控層吃掉 release）②自動更新不再狂跳權限頁：直接啟動系統安裝，返回前景自動重試 ③主頁尺寸依 viewport 校正、按鈕完整在畫面內 |

## 驗證

- headless 測試 **TESTS OK 339/339**（新增主頁觸控點擊測試）
- 內容驗證器 CONTENT OK（5 地圖、6 NPC、6 道具、14 事件）
- APK：apksigner OK、zipalign OK、versionCode 5 / versionName 0.3.1
- 未驗證：實機主頁點擊、更新下載與系統安裝流程（本環境無 Android 裝置）
