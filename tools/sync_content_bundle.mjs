#!/usr/bin/env node
/**
 * 將 game-content 內容包同步為 game-client 的內建建置快照（res://content）。
 *
 * 目的：APK 首次啟動時沒有外部內容目錄，必須內含一份可執行的初始內容。
 * 權威內容仍在 game-content 倉庫；此工具只做「驗證後複製」，不修改來源。
 *
 * 用法：
 *   node tools/sync_content_bundle.mjs [--source ../app_data_git] [--dest content]
 *
 * 行為：
 *   1. 讀取來源 manifest.json，逐檔驗證 sha256 與 size。
 *   2. 清空 dest 內既有的資料目錄（world/characters/items/events）與 manifest.json。
 *   3. 複製 manifest.json 與資料檔。
 *   4. 寫入 BUNDLE_SOURCE.json（來源版本、雜湊、同步時間），提醒此目錄為產生檔。
 *
 * 結束碼：0 = 成功；1 = 來源驗證失敗或參數錯誤。
 */
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const DATA_ROOTS = ["world", "characters", "items", "events"];

function sha256File(path) {
  return createHash("sha256").update(readFileSync(path)).digest("hex");
}

function parseArgs(argv) {
  const out = { source: null, dest: null };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--source") out.source = argv[++i];
    else if (argv[i] === "--dest") out.dest = argv[++i];
  }
  return out;
}

function main() {
  const toolsDir = dirname(fileURLToPath(import.meta.url));
  const repoRoot = resolve(toolsDir, "..");
  const args = parseArgs(process.argv.slice(2));
  const source = resolve(args.source ?? join(repoRoot, "..", "app_data_git"));
  const dest = resolve(args.dest ?? join(repoRoot, "content"));

  if (!existsSync(join(source, "manifest.json"))) {
    console.error(`來源內容缺少 manifest.json：${source}`);
    process.exit(1);
  }
  const manifest = JSON.parse(readFileSync(join(source, "manifest.json"), "utf8"));
  const errors = [];
  if (manifest.manifest_schema !== 1) errors.push("manifest_schema 必須為 1");
  if (!Array.isArray(manifest.files) || manifest.files.length === 0) {
    errors.push("manifest.files 必須是非空陣列");
  }
  let totalBytes = 0;
  for (const entry of manifest.files ?? []) {
    const full = join(source, entry.path);
    if (!existsSync(full)) {
      errors.push(`檔案不存在：${entry.path}`);
      continue;
    }
    const size = statSync(full).size;
    const sha = sha256File(full);
    if (size !== entry.size) errors.push(`${entry.path}: size 不符（manifest ${entry.size}，實際 ${size}）`);
    if (sha !== entry.sha256) errors.push(`${entry.path}: sha256 不符`);
    totalBytes += size;
  }
  if (errors.length > 0) {
    console.error("來源內容驗證失敗，未同步：");
    for (const error of errors) console.error(`  - ${error}`);
    process.exit(1);
  }

  mkdirSync(dest, { recursive: true });
  for (const root of DATA_ROOTS) rmSync(join(dest, root), { recursive: true, force: true });
  rmSync(join(dest, "manifest.json"), { force: true });
  mkdirSync(join(dest), { recursive: true });
  writeFileSync(join(dest, "manifest.json"), readFileSync(join(source, "manifest.json")));
  let copied = 0;
  for (const entry of manifest.files) {
    const target = join(dest, entry.path);
    mkdirSync(dirname(target), { recursive: true });
    writeFileSync(target, readFileSync(join(source, entry.path)));
    copied++;
  }
  const manifestSha = sha256File(join(dest, "manifest.json"));
  const meta = {
    generated: true,
    generated_by: "tools/sync_content_bundle.mjs",
    note: "此目錄是 APK 內建內容快照，不是權威內容；請勿手動編輯，重新執行同步工具。",
    source_content_dir: "game-content (app_data_git)",
    content_id: manifest.content_id,
    content_version: manifest.content_version,
    schema_version: manifest.schema_version,
    min_game_version: manifest.min_game_version,
    manifest_sha256: manifestSha,
    file_count: copied,
    total_bytes: totalBytes,
    synced_at_utc: new Date().toISOString(),
  };
  writeFileSync(join(dest, "BUNDLE_SOURCE.json"), JSON.stringify(meta, null, 2) + "\n");
  console.log(`BUNDLE OK：${copied} 個資料檔、${totalBytes} bytes → ${dest}`);
  console.log(`content_id=${manifest.content_id} content_version=${manifest.content_version} manifest_sha256=${manifestSha}`);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main();
}
