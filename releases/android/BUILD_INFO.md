# APK 建置資訊（v0.2.0 debug）

| 項目 | 值 |
| --- | --- |
| 檔案 | `adventure-prototype-0.2.0-debug.apk` |
| SHA-256 | `eeb661af51b0b23229306432ced9a0f5d1264c8862b6c7f65fdba86b0f2e6d17` |
| 大小 | 37,340,085 bytes（約 35.6 MiB） |
| 建置時間 | 2026-11-16 02:15（Asia/Taipei） |
| 版本 | 0.2.0（versionCode 2） |
| 內容版本 | `base_world` 0.1.0（manifest SHA-256 `5c771076…75d3`，7 檔／4525 bytes） |
| 套件 ID | `com.dsh.adventureprototype` |
| minSdk / targetSdk / compileSdk | 24 / 36 / 36 |
| 架構 | `arm64-v8a` only |
| 螢幕方向 | 橫向（sensor landscape） |
| 權限 | INTERNET、REQUEST_INSTALL_PACKAGES（自動更新用） |
| 簽章 | debug keystore（CN=Android Debug；憑證 SHA-256 `a354606f…9632`）。**同一 keystore 必須持續使用，否則自動更新會因簽章不符失敗** |
| 內建字型 | Noto Sans TC Variable（SIL OFL 1.1） |
| 新增功能 | 啟動自動檢查本體更新（下載→驗證→系統安裝）與內容更新（下載→驗證→user:// 安裝，下次啟動生效） |
| 相關文件 | `docs/architecture/UPDATE_SYSTEM.md`、`docs/BUILD.md` 第 8 節 |

## 驗證（2026-11-16）

| 檢查 | 結果 |
| --- | --- |
| headless 測試 | **TESTS OK 332/332** |
| apksigner verify | OK（debug 憑證） |
| aapt2 badging | versionCode 2、versionName 0.2.0、minSdk 24、targetSdk 36、arm64-v8a |
| aapt2 xmltree | 已含 INTERNET 與 REQUEST_INSTALL_PACKAGES 權限 |
| zipalign -c -v 4 | Verification successful |

## 未驗證

- 實機安裝、觸控、橫向、自動更新下載與系統安裝流程（本環境無 Android 裝置）。
- 更新失敗/網路中斷的實機行為（程式有錯誤處理與測試，但未實機驗證）。
- 正式（release）簽章：目前為 debug 簽章，不可上架；release 金鑰須由使用者控制。
