#!/usr/bin/env node
/**
 * 產生遊戲本體更新資訊 update/latest.json（release 用）。
 *
 * 由 GitHub Actions 在推送 v* tag 時執行；也可在本機先驗證。
 * 讀 project.godot 的版本與 version_code、讀已提交的 debug APK 計算雜湊，
 * 產生 latest.json（App 以 releases/latest/download/latest.json 讀取）。
 *
 * 用法：
 *   node tools/make_update_manifest.mjs [--tag v0.2.0] [--apk <path>]
 */
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const REPO = "XiaoYao-Www/adventure-prototype-client";

function parseArgs(argv) {
  const args = { tag: process.env.GITHUB_REF_NAME ?? "", apk: null };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--tag") args.tag = argv[++i];
    else if (argv[i] === "--apk") args.apk = argv[++i];
  }
  return args;
}

function readProjectSetting(text, key) {
  const match = text.match(new RegExp(`^${key.replace("/", "\\/")}="?([^"\\n]+)"?$`, "m"));
  return match ? match[1].trim() : "";
}

function main() {
  const toolsDir = dirname(fileURLToPath(import.meta.url));
  const repoRoot = resolve(toolsDir, "..");
  const args = parseArgs(process.argv.slice(2));
  const tag = args.tag || "v" + readProjectSetting(readFileSync(join(repoRoot, "project.godot"), "utf8"), "config/version");
  const project = readFileSync(join(repoRoot, "project.godot"), "utf8");
  const version = readProjectSetting(project, "config/version");
  const versionCode = Number(readProjectSetting(project, "version_code") || 0);
  if (!version || !versionCode) {
    console.error("project.godot 缺少 config/version 或 game/version_code");
    process.exit(1);
  }

  let apkPath = args.apk ? resolve(args.apk) : "";
  if (!apkPath) {
    const dir = join(repoRoot, "releases", "android");
    const candidates = existsSync(dir)
      ? readdirSync(dir).filter((name) => name.endsWith(".apk")).sort()
      : [];
    if (candidates.length === 0) {
      console.error("找不到 APK（releases/android/*.apk）；請先建置");
      process.exit(1);
    }
    apkPath = join(dir, candidates[candidates.length - 1]);
  }
  if (!statSync(apkPath).isFile()) {
    console.error(`APK 不存在：${apkPath}`);
    process.exit(1);
  }
  const apkBytes = readFileSync(apkPath);
  const apkName = apkPath.split("/").pop();
  const sha256 = createHash("sha256").update(apkBytes).digest("hex");

  const latest = {
    schema: 1,
    version,
    version_code: versionCode,
    apk_url: `https://github.com/${REPO}/releases/download/${tag}/${apkName}`,
    apk_name: apkName,
    sha256,
    size: apkBytes.length,
    tag,
    published_at: new Date().toISOString(),
  };
  const outDir = join(repoRoot, "update");
  mkdirSync(outDir, { recursive: true });
  writeFileSync(join(outDir, "latest.json"), JSON.stringify(latest, null, 2) + "\n");
  writeFileSync(
    join(outDir, "RELEASE_NOTES.md"),
    `# 遊戲本體 ${version}（${tag}）\n\n` +
      `- versionCode：${versionCode}\n` +
      `- APK：\`${apkName}\`（${apkBytes.length} bytes）\n` +
      `- SHA-256：\`${sha256}\`\n\n` +
      `首次啟動會自動檢查更新；Android 會下載並開啟系統安裝程式（需允許安裝未知來源）。\n`
  );
  console.log(`WROTE ${join(outDir, "latest.json")}`);
  console.log(`version=${version} version_code=${versionCode} apk=${apkName} sha256=${sha256} size=${apkBytes.length}`);
}

main();
