#!/usr/bin/env node
/**
 * 產生內容更新包（ZIP）與 latest_data.json（release 用）。
 *
 * 由 adventure-prototype-data 的 GitHub Actions 在推送 data-v* tag 時執行；
 * 本機也可先產生並用 Godot 測試 ContentInstaller。
 *
 * 輸出：
 *   releases/content-<content_id>-<content_version>.zip
 *   update/latest_data.json
 *   releases/RELEASE_NOTES.md
 *
 * 用法：
 *   node tools/make_content_bundle.mjs --content ../app_data_git --tag data-v0.1.0
 */
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const REPO = "XiaoYao-Www/adventure-prototype-data";

// ---------------------------------------------------------------------------
// 最小 ZIP 寫入器（store、無壓縮）：足夠給 Godot ZIPReader 解壓
// ---------------------------------------------------------------------------
const CRC_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c >>> 0;
  }
  return table;
})();

function crc32(buf) {
  let c = 0xffffffff;
  for (const byte of buf) c = CRC_TABLE[(c ^ byte) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

export function buildZip(entries) {
  const locals = [];
  const central = [];
  let offset = 0;
  for (const { name, data } of entries) {
    const nameBuf = Buffer.from(name, "utf8");
    const crc = crc32(data);
    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(20, 4);
    local.writeUInt16LE(0x0800, 6); // UTF-8 檔名
    local.writeUInt16LE(0, 8); // store
    local.writeUInt16LE(0, 10);
    local.writeUInt16LE(0x21, 12);
    local.writeUInt32LE(crc, 14);
    local.writeUInt32LE(data.length, 18);
    local.writeUInt32LE(data.length, 22);
    local.writeUInt16LE(nameBuf.length, 26);
    local.writeUInt16LE(0, 28);
    locals.push(local, nameBuf, data);

    const cd = Buffer.alloc(46);
    cd.writeUInt32LE(0x02014b50, 0);
    cd.writeUInt16LE(20, 4);
    cd.writeUInt16LE(20, 6);
    cd.writeUInt16LE(0x0800, 8);
    cd.writeUInt16LE(0, 10);
    cd.writeUInt16LE(0, 12);
    cd.writeUInt16LE(0x21, 14);
    cd.writeUInt32LE(crc, 16);
    cd.writeUInt32LE(data.length, 20);
    cd.writeUInt32LE(data.length, 24);
    cd.writeUInt16LE(nameBuf.length, 28);
    cd.writeUInt16LE(0, 30);
    cd.writeUInt16LE(0, 32);
    cd.writeUInt16LE(0, 34);
    cd.writeUInt16LE(0, 36);
    cd.writeUInt32LE(0, 38);
    cd.writeUInt32LE(offset, 42);
    central.push(cd, nameBuf);
    offset += local.length + nameBuf.length + data.length;
  }
  const centralBuf = Buffer.concat(central);
  const eocd = Buffer.alloc(22);
  eocd.writeUInt32LE(0x06054b50, 0);
  eocd.writeUInt16LE(0, 4);
  eocd.writeUInt16LE(0, 6);
  eocd.writeUInt16LE(entries.length, 8);
  eocd.writeUInt16LE(entries.length, 10);
  eocd.writeUInt32LE(centralBuf.length, 12);
  eocd.writeUInt32LE(offset, 16);
  eocd.writeUInt16LE(0, 20);
  return Buffer.concat([...locals, centralBuf, eocd]);
}

// ---------------------------------------------------------------------------

function parseArgs(argv) {
  const args = { content: ".", tag: process.env.GITHUB_REF_NAME ?? "" };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--content") args.content = argv[++i];
    else if (argv[i] === "--tag") args.tag = argv[++i];
  }
  return args;
}

function main() {
  const toolsDir = dirname(fileURLToPath(import.meta.url));
  const args = parseArgs(process.argv.slice(2));
  // 允許在 data repo 內執行：工具位置可能不在同一 repo，故以 --content 為準
  const contentDir = resolve(args.content);
  const manifestPath = join(contentDir, "manifest.json");
  if (!existsSync(manifestPath)) {
    console.error(`找不到 manifest.json：${manifestPath}`);
    process.exit(1);
  }
  const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
  const contentVersion = String(manifest.content_version ?? "");
  const contentId = String(manifest.content_id ?? "");
  if (!contentVersion || !contentId) {
    console.error("manifest 缺少 content_version/content_id");
    process.exit(1);
  }
  const tag = args.tag || `data-v${contentVersion}`;

  const entries = [];
  const manifestBytes = readFileSync(manifestPath);
  entries.push({ name: "manifest.json", data: manifestBytes });
  for (const entry of manifest.files ?? []) {
    const full = join(contentDir, entry.path);
    if (!existsSync(full)) {
      console.error(`manifest 列出的檔案不存在：${entry.path}`);
      process.exit(1);
    }
    const data = readFileSync(full);
    if (createHash("sha256").update(data).digest("hex") !== entry.sha256) {
      console.error(`sha256 不符：${entry.path}`);
      process.exit(1);
    }
    entries.push({ name: entry.path, data });
  }
  const zipName = `content-${contentId}-${contentVersion}.zip`;
  const zip = buildZip(entries);
  const releasesDir = join(contentDir, "releases");
  mkdirSync(releasesDir, { recursive: true });
  writeFileSync(join(releasesDir, zipName), zip);
  const sha256 = createHash("sha256").update(zip).digest("hex");

  const latest = {
    schema: 1,
    content_id: contentId,
    content_version: contentVersion,
    schema_version: manifest.schema_version,
    min_game_version: manifest.min_game_version,
    bundle_url: `https://github.com/${REPO}/releases/download/${tag}/${zipName}`,
    bundle_name: zipName,
    sha256,
    size: zip.length,
    tag,
    published_at: new Date().toISOString(),
  };
  const updateDir = join(contentDir, "update");
  mkdirSync(updateDir, { recursive: true });
  writeFileSync(join(updateDir, "latest_data.json"), JSON.stringify(latest, null, 2) + "\n");
  writeFileSync(
    join(releasesDir, "RELEASE_NOTES.md"),
    `# 內容包 ${contentId} ${contentVersion}（${tag}）\n\n` +
      `- 檔案：\`${zipName}\`（${zip.length} bytes）\n` +
      `- SHA-256：\`${sha256}\`\n` +
      `- schema_version：${manifest.schema_version}、min_game_version：${manifest.min_game_version}\n\n` +
      `遊戲啟動時會比對 content_version，較新時自動下載、驗證並安裝（下次啟動生效）。\n`
  );
  console.log(`WROTE ${join(releasesDir, zipName)} (${zip.length} bytes)`);
  console.log(`WROTE ${join(updateDir, "latest_data.json")}`);
  console.log(`content_id=${contentId} content_version=${contentVersion} sha256=${sha256}`);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main();
}
