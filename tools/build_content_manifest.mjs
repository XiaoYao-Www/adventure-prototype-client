#!/usr/bin/env node
/**
 * 重建 game-content 的 manifest.json 檔案清單（sha256 + size）。
 *
 * 用途：內容資料變更後，用此工具重新產生 manifest 的 files 陣列，
 * 避免手寫雜湊出錯。只會改寫 manifest.json 的 `files` 欄位，
 * 其餘版本欄位保留原值。
 *
 * 用法：
 *   node tools/build_content_manifest.mjs <content_dir>           # 寫入
 *   node tools/build_content_manifest.mjs <content_dir> --check   # 只檢查，不寫入
 *
 * 結束碼：0 = 一致／已寫入；1 = 不一致（--check）或錯誤。
 */
import { createHash } from "node:crypto";
import { existsSync, readFileSync, readdirSync, lstatSync, statSync, writeFileSync } from "node:fs";
import { join, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

const DATA_ROOTS = ["world", "characters", "items", "events"];

function sha256File(path) {
  return createHash("sha256").update(readFileSync(path)).digest("hex");
}

function walk(rootDir, subDir, out) {
  const abs = join(rootDir, subDir);
  if (!existsSync(abs)) return;
  for (const name of readdirSync(abs).sort()) {
    const full = join(abs, name);
    const st = lstatSync(full);
    if (st.isSymbolicLink()) continue;
    if (st.isDirectory()) walk(rootDir, join(subDir, name), out);
    else if (name.endsWith(".json")) {
      out.push(relative(rootDir, full).split(sep).join("/"));
    }
  }
}

export function discoverDataFiles(contentDir) {
  const out = [];
  for (const root of DATA_ROOTS) walk(resolve(contentDir), root, out);
  return out.sort();
}

export function buildFiles(contentDir) {
  return discoverDataFiles(contentDir).map((rel) => {
    const full = join(resolve(contentDir), rel);
    return { path: rel, sha256: sha256File(full), size: statSync(full).size };
  });
}

export function main() {
  const args = process.argv.slice(2);
  const checkOnly = args.includes("--check");
  const positional = args.filter((a) => !a.startsWith("--"));
  if (positional.length !== 1) {
    console.error("用法：node tools/build_content_manifest.mjs <content_dir> [--check]");
    process.exit(2);
  }
  const contentDir = resolve(positional[0]);
  const manifestPath = join(contentDir, "manifest.json");
  if (!existsSync(manifestPath)) {
    console.error(`找不到 ${manifestPath}；請先建立含版本欄位的 manifest.json`);
    process.exit(2);
  }
  let manifest;
  try {
    manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
  } catch (error) {
    console.error(`manifest.json 無法解析：${error.message}`);
    process.exit(2);
  }
  const files = buildFiles(contentDir);
  const before = JSON.stringify(manifest.files ?? null);
  const after = JSON.stringify(files);
  if (before === after) {
    console.log(`MANIFEST OK：${files.length} 個資料檔，${files.reduce((sum, f) => sum + f.size, 0)} bytes`);
    return;
  }
  if (checkOnly) {
    const beforeSet = new Set((manifest.files ?? []).map((f) => JSON.stringify(f)));
    const afterSet = new Set(files.map((f) => JSON.stringify(f)));
    for (const entry of beforeSet) if (!afterSet.has(entry)) console.log(`MANIFEST 多餘或過期：${entry}`);
    for (const entry of afterSet) if (!beforeSet.has(entry)) console.log(`MANIFEST 缺少或需更新：${entry}`);
    console.log("MANIFEST MISMATCH");
    process.exit(1);
  }
  manifest.files = files;
  writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + "\n");
  console.log(`WROTE ${manifestPath}：${files.length} 個資料檔`);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main();
}
