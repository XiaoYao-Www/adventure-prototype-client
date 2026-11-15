# releases/ — 可安裝的建置成品

## android/

- `adventure-prototype-0.1.0-debug.apk`：v0.1 debug APK（arm64-v8a、minSdk 24）。
- `BUILD_INFO.md`：版本、SHA-256、簽章資訊、驗證結果與未驗證項目。

## 重要說明

- **簽章**：目前只有 debug 簽章（Android 預設 debug keystore），只能安裝測試，
  不可發布到商店。正式簽章金鑰由使用者控制，不得提交進倉庫。
- **提交政策**：依 2026-11-16 使用者的明確指示，APK 成品提交進 Git 倉庫；
  這是專案一般「不提交產生檔」規則的例外（見 `docs/project/DECISION_LOG.md`
  的 D-0017）。其他快取、`.godot/`、匯出中間檔仍不進版控。
- **重建**：見 `docs/BUILD.md` 或工作區 `tools/build_android.sh`；重建後必須更新
  `BUILD_INFO.md` 的雜湊與版本資訊。
- **內容更新**：內容在 `game-content` 倉庫；更新後需重新同步 `res://content`
  （`tools/sync_content_bundle.mjs`）並重建 APK，單純改內容不會自動反映到已建置 APK。
