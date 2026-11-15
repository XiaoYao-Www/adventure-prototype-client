# APK 建置資訊（v0.1 debug）

| 項目 | 值 |
| --- | --- |
| 檔案 | `adventure-prototype-0.1.0-debug.apk` |
| SHA-256 | `1fda822d9b6f8d8230693fb6568702dc886b932ca9a0c06d62b25e95b11a4af3` |
| 大小 | 37,298,075 bytes（約 35.6 MiB） |
| 建置時間 | 2026-11-16 01:48（Asia/Taipei） |
| 遊戲版本 | 0.1.0（`application/config/version`） |
| 內容版本 | `base_world` 0.1.0（manifest SHA-256 `5c771076d7bb7c7188be2999a410a6703ed3c462a4da15eac43a46d5e4dd75d3`，7 檔／4525 bytes） |
| 套件 ID | `com.dsh.adventureprototype` |
| 顯示名稱 | `Adventure Prototype`（暫定，不是遊戲正式名稱） |
| versionCode / versionName | `1` / `0.1.0` |
| minSdk / targetSdk / compileSdk | 24 / 36 / 36 |
| 架構 | `arm64-v8a` only |
| 螢幕方向 | `sensor`（專案設定 `display/window/handheld/orientation=6`；產品方向尚未定案） |
| 渲染 | `gl_compatibility`（ETC2/ASTC import 已啟用） |
| 啟動圖示 | Godot 預設圖示（尚未設計遊戲 icon；不影響安裝與啟動） |
| 輸入 | 觸控虛擬方向鍵＋互動＋存檔／讀檔按鈕（Android/mobile 自動顯示）；鍵盤 WASD／方向鍵、E／Space／Enter、F5／F9 |
| 內建字型 | Noto Sans TC Variable（SIL OFL 1.1，見 `assets/fonts/OFL.txt`） |
| 簽章 | debug keystore：`CN=Android Debug, O=Android, C=US`；憑證 SHA-256 `a354606f6c0110c48e6c2e17834c442886bd71af6e39c9f17663ae4e03959632` |

## 建置環境

- Godot 4.7.2 stable（official，Linux x86_64）+ Android export templates 4.7.2.stable
- Temurin JDK 17.0.21
- Android build-tools 36.1.0、platform-tools、platform android-36
- 建置命令（工作區，會同步內容、跑測試、匯出並驗證）：

```bash
bash /workspace/自動遊戲開發/tools/build_android.sh
```

## 已執行的驗證（2026-11-16）

| 檢查 | 結果 |
| --- | --- |
| 專案 headless 測試 | **TESTS OK 288/288**（含觸控控制與 CJK 字型字形檢查） |
| `apksigner verify --print-certs` | OK，debug 憑證 |
| `aapt2 dump badging` | package/version/minSdk/targetSdk/native-code 如上表 |
| `zipalign -c -v 4` | Verification successful |
| APK 內 `assets/content/` 抽出後以 `tools/validate_content.mjs` 驗證 | CONTENT OK（0 error；快照不含 docs 的 2 個 warning） |
| APK 內 CJK 字型 | `.godot/imported/NotoSansTC-VF...fontdata` 存在（8.9MB） |
| APK 內可執行檔頭 | `assets/scripts/**/*.gdc`、`assets/.godot/exported/**/*.scn`、`lib/arm64-v8a/libgodot_android.so` |

## 未驗證（不得視為通過）

- **Android 實機／模擬器安裝、啟動、觸控手感、畫面、音效**：本環境沒有 Android 裝置與模擬器。
- 觸控按鈕的實際大小與安全區在真機上的表現（以 960x540 佈局設計，未經裝置驗證）。
- 中文在 Android 上的實際字型渲染與排版（僅驗證字型檔含字形、且被打包進 APK）。
- 正式（release）簽章與上架流程：目前只有 debug 簽章，**不可上架**。
- arm64 以外架構（armeabi-v7a／x86_64）未包含在 APK。

## 重建注意事項

1. 先同步內容快照：`node tools/sync_content_bundle.mjs --source ../app_data_git --dest content`
2. 重新匯入：`"$G" --headless --path . --import`
3. 匯出：`"$G" --headless --path . --export-debug "Android" <輸出絕對路徑>`
4. 重建後務必更新本檔的 SHA-256、大小、內容版本與建置時間（`tools/checks.sh` 會比對）。
5. Java 必須以 UTF-8 locale 執行（`LANG=C.UTF-8`），否則非 ASCII 路徑會讓 apksigner/keytool 失敗。
