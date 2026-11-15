# 自動更新設計（v0.2.0）

> 目的：符合使用者長期要求——遊戲每次啟動自動檢查本體更新並安裝；本體不需更新時，
> 自動檢查並抓取最新內容。任何失敗都不得破壞可玩狀態。

## 1. 本體更新（APK）

1. 啟動後（Android 且 `game/update_enabled=true`）GET
   `https://github.com/XiaoYao-Www/adventure-prototype-client/releases/latest/download/latest.json`。
2. 比對 `version_code`（或 version semver）；較新才繼續。
3. 以 `HTTPRequest.download_file` 下載 `apk_url` 到 `user://updates/app-<version>.apk`。
4. 驗證 size 與 SHA-256（不符即刪除/保留舊檔並顯示錯誤）。
5. `AndroidInstaller.install_apk()`：
   - 取得 `Engine.get_singleton("AndroidRuntime").getActivity()`。
   - 檢查 `REQUEST_INSTALL_PACKAGES`；沒有就先開啟系統「安裝未知應用程式」設定頁。
   - `androidx.core.content.FileProvider.getUriForFile`（authority：
     `com.dsh.adventureprototype.fileprovider`；Godot 範本已開放 app files 目錄）。
   - `Intent.ACTION_VIEW` + MIME `application/vnd.android.package-archive` 啟動系統安裝程式。
6. 下載失敗／安裝失敗：顯示訊息與「重試安裝」按鈕；不影響目前遊戲。

限制：Android 不允許一般 App 靜默安裝，**系統一定會顯示安裝確認**；首次要允許未知來源。
APK 簽章必須與已安裝版本相同（本專案固定使用工作區 `tools/android-keystore/debug.keystore`）。

## 2. 內容更新（DATA）

1. 本體不需更新時，GET
   `https://github.com/XiaoYao-Www/adventure-prototype-data/releases/latest/download/latest_data.json`。
2. 比對 `content_version` 與目前版本（已安裝版本優先，否則內建 `res://content`）。
3. 下載內容包 ZIP（根目錄含 `manifest.json` + 資料目錄）到 `user://updates/`。
4. 驗證 SHA-256／size → `ContentInstaller.install_zip`：
   - 解壓到 `user://content_packs/v<version>/`（拒絕 `../` 等不安全路徑）。
   - 用 `ContentRepository` 做完整驗證（manifest/sha256/schema/引用/版本）。
   - 寫入 `user://content_current.json`；舊版記錄到 `user://content_previous.json` 供回滾。
5. 驗證失敗：刪除新版本目錄、保留舊版本；顯示錯誤，遊戲照常使用現有內容。
6. 生效時機：**下次啟動**（啟動時 `ContentRepository.resolve_content_dir` 會優先使用已安裝內容）。

## 3. 發布流程（GitHub Actions）

- 本體：push tag `v*` → `.github/workflows/release.yml`
  → `tools/make_update_manifest.mjs` 產生 `latest.json`
  → `gh release create --latest` 上傳 APK、latest.json、BUILD_INFO。
- 內容：push tag `data-v*` → `release-data.yml`
  → 從 client repo 取得 `tools/make_content_bundle.mjs` 產生 ZIP 與 latest_data.json
  → `gh release create --latest` 上傳。
- App 永遠讀 `releases/latest/download/*.json`（固定網址，不需 GitHub API token）。

## 4. 測試與未驗證

- 已測（headless）：版本比較、manifest 解析與拒絕不安全網址、內容包安裝／版本切換／回滾／
  雜湊不符／不安全 ZIP 路徑、非 Android 不安裝。共 332 項測試。
- 未測：實機下載與系統安裝 UI、`user://` 路徑與 FileProvider 在真機的組合、
  網路中斷/更新失敗的真機行為、release 簽章（仍為 debug）。
- 診斷：logcat 過濾 `Godot`／`[touch]`／Godot 的 HTTP 錯誤訊息。

## 5. 未來工作

- 正式 release 簽章（金鑰由使用者持有）與 CI 注入 secrets。
- 內容更新後熱重載（目前下次啟動生效）。
- 更新失敗重試佇列、Wi-Fi-only 設定、下載進度 UI。
- 若需要完全靜默安裝，需系統權限或企業 MDM，不屬於一般 App 範圍。
