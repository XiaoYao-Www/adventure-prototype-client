#!/usr/bin/env node
/**
 * 建立 game-content 的素材目錄（asset catalog）：分類、標記、雜湊、尺寸。
 *
 * 目的：讓 AI／人類不必反覆開圖就能知道「有哪些素材、屬於哪類、能不能用」。
 * 輸入是工作區 `assets/`（使用者提供的素材原始包，不在 Git 倉庫內）。
 * 輸出寫入 `game-content/asset_catalog/`（分類索引、pack 紀錄、授權摘要）。
 *
 * 用法：
 *   node tools/build_asset_catalog.mjs \
 *     --assets /workspace/自動遊戲開發/assets \
 *     --out /workspace/自動遊戲開發/app_data_git/asset_catalog
 *
 * 只使用 Node 內建模組；不連網、不修改原始素材、不搬移檔案。
 */
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

const TILE = 16;

const PACKS = {
  mini_world_sprites: {
    id: "mini_world_sprites",
    title: "16x16 Mini World Sprites",
    authors: ["Kurt Gabriel Sotelo (merchant-shade)", "octoshrimpy"],
    source_url: "https://merchant-shade.itch.io/16x16-mini-world-sprites",
    license: "CC0-1.0",
    license_url: "https://creativecommons.org/publicdomain/zero/1.0/",
    license_status: "verified",
    commercial_use: true,
    modification: true,
    redistribution: true,
    attribution_required: false,
    credit_appreciated: true,
    verified_at: "2026-11-16",
    verified_from: "itch.io 頁面 Asset license 欄位與 Information 段（free to use commercially or not、modify allowed、credit optional）",
    notes: "頁面列 CC0 1.0；仍建議在 credits 註明作者。素材版本以使用者提供的下載檔為準（最後更新 2022-12-24）。",
  },
  items16: {
    id: "items16",
    title: "Items pack (x16) / Items16",
    authors: ["Glionox"],
    source_url: "https://glionox.itch.io/items16",
    license: "custom (per itch.io page)",
    license_url: "https://glionox.itch.io/items16",
    license_status: "verified",
    commercial_use: true,
    modification: true,
    redistribution: false,
    attribution_required: false,
    credit_appreciated: true,
    verified_at: "2026-11-16",
    verified_from: "itch.io 頁面 Licence 段：Use as you want in free and commercial projects; Modify; Credits appreciated; You may not redistribute or resell this pack",
    notes: "可嵌入遊戲使用與修改，但**不得再散布或轉售原始素材包**。因此原始圖示不進公開 APK；若日後要公開，需確認內嵌方式或替換素材。",
    usage_policy: "restricted_redistribution",
  },
};

/** 依目錄與檔名推斷分類與標籤。 */
function classify(rel) {
  const segments = rel.split("/");
  const fileName = segments[segments.length - 1];
  const stem = fileName.replace(/\.[^.]+$/, "");
  const lower = stem.toLowerCase();
  const tags = [];
  let pack = "mini_world_sprites";
  let category = "unknown";

  if (segments[0] === "items") {
    pack = "items16";
    category = "item_icon";
    tags.push("item_icon", "single_tile", "16x16");
  } else {
    const sub = segments.slice(1, -1).join("/");
    const top = segments[1] ?? "";
    if (rel.includes("/Ground/")) category = "terrain_ground";
    else if (rel.includes("/Nature/")) category = "nature";
    else if (rel.includes("/Objects/")) category = "object";
    else if (rel.includes("/Animals/")) category = "animal";
    else if (rel.includes("/Miscellaneous/")) category = "misc";
    else if (rel.includes("/Buildings/")) {
      category = "building";
      const palette = segments[2] ?? "";
      if (palette) tags.push("palette_" + palette.toLowerCase());
      if (rel.includes("/Enemy/")) tags.push("enemy");
    } else if (rel.includes("/Characters/Champions/")) category = "character_champion";
    else if (rel.includes("/Characters/Monsters/")) {
      const monster = segments[3] ? segments[3].toLowerCase() : "monster";
      category = "monster_" + monster;
      tags.push("monster");
    } else if (rel.includes("/Characters/Soldiers/Melee/")) category = "character_soldier_melee";
    else if (rel.includes("/Characters/Soldiers/Ranged/")) category = "character_soldier_ranged";
    else if (rel.includes("/Characters/Soldiers/Mounted/")) category = "character_soldier_mounted";
    else if (rel.includes("/Characters/Soldiers/")) category = "character_soldier";
    else if (rel.includes("/Characters/Workers/")) category = "character_worker";
    else if (rel.includes("/Characters/")) category = "character";
    else if (rel.includes("/User Interface/")) category = "ui";
    else if (rel.includes("/Templates/")) category = "template";
    else if (segments.length === 2) category = "preview";
    else category = "misc";

    // 檔名語意關鍵字（Mini World Sprites 檔名本身有語意）
    const keywords = [
      ["grass", "grass"], ["water", "water"], ["shore", "shore"], ["cliff", "cliff"],
      ["tree", "tree"], ["pine", "pine"], ["winter", "winter"], ["cactus", "cactus"],
      ["rock", "rock"], ["chest", "chest"], ["house", "house"], ["tavern", "tavern"],
      ["tower", "tower"], ["well", "well"], ["market", "market"], ["docks", "dock"],
      ["ship", "ship"], ["barracks", "barracks"], ["keep", "keep"], ["chapel", "chapel"],
      ["workshop", "workshop"], ["mausoleum", "mausoleum"], ["portal", "portal"],
      ["skeleton", "skeleton"], ["dragon", "dragon"], ["slime", "slime"], ["orc", "orc"],
      ["demon", "demon"], ["pirate", "pirate"], ["horse", "horse"], ["boar", "boar"],
      ["chicken", "chicken"], ["sheep", "sheep"], ["knight", "knight"], ["archer", "archer"],
      ["mage", "mage"], ["worker", "worker"], ["tombstone", "tombstone"],
    ];
    for (const [needle, tag] of keywords) {
      if (lower.includes(needle)) tags.push(tag);
    }
    if (top === "MiniWorldSprites") tags.push("mini_world");
    if (!tags.includes("16x16")) tags.push("16x16_base");
  }
  return { pack, category, tags: [...new Set(tags)] };
}

function pngInfo(buf) {
  const signature = buf.subarray(0, 8).toString("hex");
  if (signature !== "89504e470d0a1a0a") return null;
  return {
    width: buf.readUInt32BE(16),
    height: buf.readUInt32BE(20),
    bit_depth: buf[24],
    color_type: buf[25],
  };
}

function walk(dir, rel, out) {
  for (const name of readdirSync(dir).sort()) {
    const full = join(dir, name);
    const st = statSync(full);
    const nextRel = rel ? rel + "/" + name : name;
    if (st.isDirectory()) walk(full, nextRel, out);
    else out.push({ rel: nextRel, full, size: st.size });
  }
}

function parseArgs(argv) {
  const args = { assets: null, out: null };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--assets") args.assets = argv[++i];
    else if (argv[i] === "--out") args.out = argv[++i];
  }
  return args;
}

function main() {
  const toolsDir = dirname(fileURLToPath(import.meta.url));
  const repoRoot = resolve(toolsDir, "..");
  const args = parseArgs(process.argv.slice(2));
  const assetsRoot = resolve(args.assets ?? join(repoRoot, "..", "assets"));
  const outRoot = resolve(args.out ?? join(repoRoot, "..", "app_data_git", "asset_catalog"));

  if (!existsSync(assetsRoot)) {
    console.error(`找不到素材目錄：${assetsRoot}`);
    process.exit(1);
  }
  const raw = [];
  walk(assetsRoot, "", raw);
  const pngs = raw.filter((f) => f.rel.toLowerCase().endsWith(".png"));
  const nonPng = raw.filter((f) => !f.rel.toLowerCase().endsWith(".png"));

  const assets = [];
  const packCounts = {};
  const categoryCounts = {};
  const hashSeen = new Map();
  const duplicates = [];
  for (const file of pngs) {
    const buf = readFileSync(file.full);
    const info = pngInfo(buf);
    if (!info) {
      nonPng.push({ rel: file.rel, size: file.size, reason: "not a valid PNG" });
      continue;
    }
    const sha256 = createHash("sha256").update(buf).digest("hex");
    if (hashSeen.has(sha256)) duplicates.push({ rel: file.rel, duplicate_of: hashSeen.get(sha256) });
    else hashSeen.set(sha256, file.rel);
    const { pack, category, tags } = classify(file.rel);
    const tileGrid = {
      cols: Math.floor(info.width / TILE),
      rows: Math.floor(info.height / TILE),
    };
    const isSingleTile = info.width === TILE && info.height === TILE;
    const entry = {
      path: file.rel,
      pack,
      category,
      tags,
      width: info.width,
      height: info.height,
      bytes: file.size,
      sha256,
      tile_size: TILE,
      tile_grid: tileGrid,
      single_tile: isSingleTile,
      sprite_sheet: !isSingleTile && tileGrid.cols >= 1 && tileGrid.rows >= 1,
      license_status: PACKS[pack].license_status,
      redistributable: PACKS[pack].redistribution,
    };
    assets.push(entry);
    packCounts[pack] = (packCounts[pack] ?? 0) + 1;
    categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
  }

  // 排序：pack → category → path，方便人眼與工具掃描
  assets.sort((a, b) =>
    a.pack.localeCompare(b.pack) || a.category.localeCompare(b.category) || a.path.localeCompare(b.path),
  );

  mkdirSync(outRoot, { recursive: true });
  for (const sub of ["packs", "licenses", "generated"]) mkdirSync(join(outRoot, sub), { recursive: true });

  const catalog = {
    catalog_version: 1,
    generated_at: new Date().toISOString(),
    generated_by: "game-client/tools/build_asset_catalog.mjs",
    source_root: "工作區 assets/（原始素材包，不進 Git）",
    tile_size: TILE,
    totals: {
      files_on_disk: raw.length,
      png: pngs.length,
      non_png: nonPng.length,
      bytes_png: pngs.reduce((sum, f) => sum + f.size, 0),
      duplicates: duplicates.length,
      packs: Object.keys(PACKS).length,
    },
    pack_counts: packCounts,
    category_counts: categoryCounts,
    tag_vocabulary: {
      terrain_ground: "可鋪設的地形圖塊（草、水、岸、崖）",
      nature: "自然物（樹、岩石、植物）",
      object: "可放置物件（寶箱、告示、傳送門等）",
      animal: "動物／家畜",
      building: "建築（含 5 種配色與敵方建築）",
      character_soldier_melee: "近戰士兵角色表",
      character_soldier_ranged: "遠程士兵角色表",
      character_soldier_mounted: "騎兵角色表",
      character_worker: "工人角色表",
      character_champion: "英雄／冠軍角色表",
      "monster_variants": "怪物角色表（依類型分類）",
      ui: "介面元素（面板、游標等）",
      template: "空白模板／參考圖",
      preview: "素材預覽圖（非遊戲用）",
      item_icon: "16x16 道具圖示（Items16，禁止再散布原始包）",
    },
    non_png_files: nonPng,
    duplicates,
    assets,
  };

  writeFileSync(join(outRoot, "catalog.json"), JSON.stringify(catalog, null, 2) + "\n");

  // 精簡索引（依分類分組的 path 清單，適合快速查詢、不必讀大檔）
  const byCategory = {};
  for (const asset of assets) {
    (byCategory[asset.category] ??= []).push({
      path: asset.path,
      pack: asset.pack,
      size: [asset.width, asset.height],
      tags: asset.tags,
      sha256: asset.sha256,
    });
  }
  writeFileSync(
    join(outRoot, "generated", "index_by_category.json"),
    JSON.stringify({ generated_at: catalog.generated_at, categories: byCategory }, null, 2) + "\n",
  );

  // pack 紀錄
  for (const [packId, pack] of Object.entries(PACKS)) {
    const count = packCounts[packId] ?? 0;
    const bytes = assets.filter((a) => a.pack === packId).reduce((sum, a) => sum + a.bytes, 0);
    writeFileSync(
      join(outRoot, "packs", `${packId}.json`),
      JSON.stringify({ ...pack, file_count: count, bytes, catalog_generated_at: catalog.generated_at }, null, 2) + "\n",
    );
  }

  // 授權摘要（Markdown，便於人與 AI 快速閱讀）
  const licenseLines = [
    "# 素材授權摘要",
    "",
    `> 產生時間：${catalog.generated_at}；來源：itch.io 頁面（2026-11-16 查核）。`,
    "> 本檔為摘要，正式使用前仍應保存完整授權頁面快照。",
    "",
  ];
  for (const [packId, pack] of Object.entries(PACKS)) {
    licenseLines.push(`## ${pack.title}（\`${packId}\`）`, "");
    licenseLines.push(`- 作者：${pack.authors.join("、")}`);
    licenseLines.push(`- 來源：${pack.source_url}`);
    licenseLines.push(`- 授權：${pack.license}（狀態：${pack.license_status}）`);
    licenseLines.push(`- 商用：${pack.commercial_use ? "可" : "不可"}；修改：${pack.modification ? "可" : "不可"}；再散布：${pack.redistribution ? "可" : "**不可**"}`);
    licenseLines.push(`- 署名：${pack.attribution_required ? "必須" : "非必須（作者樂見）"}`);
    licenseLines.push(`- 覆核依據：${pack.verified_from}`);
    if (pack.usage_policy) licenseLines.push(`- 使用限制政策：\`${pack.usage_policy}\``);
    licenseLines.push(`- 備註：${pack.notes}`, "");
  }
  writeFileSync(join(outRoot, "licenses", "SUMMARY.md"), licenseLines.join("\n") + "\n");

  console.log("=== 素材目錄已建立 ===");
  console.log(`PNG：${catalog.totals.png}，非 PNG：${catalog.totals.non_png}，重複：${catalog.totals.duplicates}`);
  console.log("packs：", JSON.stringify(packCounts));
  console.log("categories：", JSON.stringify(categoryCounts));
  console.log(`輸出：${outRoot}`);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main();
}
