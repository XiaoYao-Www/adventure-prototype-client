#!/usr/bin/env node
/**
 * 內容工具鏈測試（node:test，零依賴）。
 *
 * 執行：node --test tools/tests/content_tools.test.mjs
 *
 * 測試對象：tools/validate_content.mjs、tools/build_content_manifest.mjs
 * 以暫存目錄建立最小合法內容包與各種破壞情境，確認驗證器能正確接受／拒絕。
 */
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

const TESTS_DIR = dirname(fileURLToPath(import.meta.url));
const TOOLS_DIR = dirname(TESTS_DIR);
const VALIDATOR = resolve(TOOLS_DIR, "validate_content.mjs");
const BUILDER = resolve(TOOLS_DIR, "build_content_manifest.mjs");

function writeJson(path, value) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, JSON.stringify(value, null, 2) + "\n");
}

function writeText(path, value) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, value);
}

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

/** 建立最小合法內容包（manifest.files 由 builder 產生）。回傳內容根目錄。 */
function makeContent() {
  const root = mkdtempSync(join(tmpdir(), "content-fixture-"));
  writeText(join(root, "docs/CONTENT_SCHEMA.md"), "# schema\n");
  writeText(join(root, "docs/ASSET_POLICY.md"), "# asset policy\n");
  writeJson(join(root, "world/regions/region_starting_001.json"), {
    schema_version: 1,
    id: "region_starting_001",
    name: "起始地帶（測試）",
    map_ids: ["map_start_village", "map_forest_edge"],
    notes: "測試用",
  });
  writeJson(join(root, "world/maps/map_start_village.json"), {
    schema_version: 1,
    id: "map_start_village",
    name: "測試村落",
    size: { width: 6, height: 5 },
    tile_size: 16,
    tiles: ["######", "#....#", "#.t..#", "#....#", "######"],
    legend: {
      "#": { tile: "wall", walkable: false },
      ".": { tile: "grass", walkable: true },
      t: { tile: "tree", walkable: false },
    },
    spawn: { grid: [1, 1] },
    entities: [
      {
        id: "npc_village_elder_001",
        type: "npc",
        grid: [1, 2],
        display_key: "npc_elder",
        interaction: { kind: "event", event_id: "event_elder_greeting_001" },
      },
    ],
    portals: [
      {
        id: "portal_to_forest",
        grid: [4, 3],
        target_map_id: "map_forest_edge",
        target_grid: [1, 1],
      },
    ],
  });
  writeJson(join(root, "world/maps/map_forest_edge.json"), {
    schema_version: 1,
    id: "map_forest_edge",
    name: "測試森林",
    size: { width: 5, height: 4 },
    tile_size: 16,
    tiles: ["#####", "#...#", "#...#", "#####"],
    legend: {
      "#": { tile: "wall", walkable: false },
      ".": { tile: "grass", walkable: true },
    },
    spawn: { grid: [1, 1] },
    entities: [],
    portals: [
      {
        id: "portal_to_village",
        grid: [3, 2],
        target_map_id: "map_start_village",
        target_grid: [3, 3],
      },
    ],
  });
  writeJson(join(root, "characters/npcs/npc_village_elder_001.json"), {
    schema_version: 1,
    id: "npc_village_elder_001",
    name: "村長（測試）",
    role: "長老",
    short_description: "測試用角色",
    is_adult: true,
    speech_style: "簡短",
  });
  writeJson(join(root, "items/item_herb_001.json"), {
    schema_version: 1,
    id: "item_herb_001",
    name: "藥草",
    category: "consumable",
    description: "測試用道具",
    stack_limit: 99,
  });
  writeJson(join(root, "events/event_elder_greeting_001.json"), {
    schema_version: 1,
    id: "event_elder_greeting_001",
    kind: "dialogue",
    trigger: { map_id: "map_start_village", entity_id: "npc_village_elder_001" },
    repeatable: true,
    lines: [
      { speaker_id: "npc_village_elder_001", text: "旅人，你來得正好。" },
      { speaker_id: "player", text: "這裡是？" },
    ],
    choices: [
      {
        id: "accept",
        text: "我願意幫忙",
        effects: [{ type: "set_flag", flag: "flag_met_elder", value: true }],
      },
      {
        id: "take_herb",
        text: "收下藥草",
        effects: [{ type: "give_item", item_id: "item_herb_001", qty: 1 }],
      },
    ],
  });
  writeJson(join(root, "manifest.json"), {
    manifest_schema: 1,
    content_id: "base_world",
    content_version: "0.1.0",
    schema_version: 1,
    min_game_version: "0.1.0",
    dependencies: [],
    files: [],
  });
  syncManifest(root);
  return root;
}

function syncManifest(root) {
  const result = spawnSync(process.execPath, [BUILDER, root], { encoding: "utf8" });
  assert.equal(result.status, 0, `builder 失敗：${result.stdout}\n${result.stderr}`);
}

function runValidator(root) {
  const result = spawnSync(process.execPath, [VALIDATOR, root], { encoding: "utf8" });
  return { status: result.status, out: `${result.stdout}\n${result.stderr}` };
}

function withContent(fn) {
  const root = makeContent();
  try {
    return fn(root);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

test("合法內容包通過驗證", () => {
  withContent((root) => {
    const { status, out } = runValidator(root);
    assert.equal(status, 0, out);
    assert.match(out, /CONTENT OK/);
    assert.match(out, /地圖 2/);
  });
});

test("資料檔被篡改（雜湊不符）會被拒絕", () => {
  withContent((root) => {
    const mapPath = join(root, "world/maps/map_start_village.json");
    const map = readJson(mapPath);
    map.name = "被篡改的村落";
    writeJson(mapPath, map); // 不重建 manifest
    const { status, out } = runValidator(root);
    assert.equal(status, 1, out);
    assert.match(out, /sha256 不符/);
  });
});

test("地圖列長度不符會被拒絕", () => {
  withContent((root) => {
    const mapPath = join(root, "world/maps/map_start_village.json");
    const map = readJson(mapPath);
    map.tiles = ["######", "#....#", "#.t..#", "#....#", "#####"]; // 最後一列少 1 格
    writeJson(mapPath, map);
    syncManifest(root);
    const { status, out } = runValidator(root);
    assert.equal(status, 1, out);
    assert.match(out, /長度/);
  });
});

test("legend 未覆蓋所有字元會被拒絕", () => {
  withContent((root) => {
    const mapPath = join(root, "world/maps/map_start_village.json");
    const map = readJson(mapPath);
    delete map.legend.t;
    writeJson(mapPath, map);
    syncManifest(root);
    const { status, out } = runValidator(root);
    assert.equal(status, 1, out);
    assert.match(out, /不在 legend/);
  });
});

test("未知 effect 類型會被拒絕", () => {
  withContent((root) => {
    const eventPath = join(root, "events/event_elder_greeting_001.json");
    const event = readJson(eventPath);
    event.choices[0].effects.push({ type: "run_script", script: "evil.gd" });
    writeJson(eventPath, event);
    syncManifest(root);
    const { status, out } = runValidator(root);
    assert.equal(status, 1, out);
    assert.match(out, /不在白名單：run_script/);
  });
});

test("內容倉庫出現可執行檔會被拒絕", () => {
  withContent((root) => {
    writeText(join(root, "events/evil.gd"), "extends Node\n");
    const { status, out } = runValidator(root);
    assert.equal(status, 1, out);
    assert.match(out, /可執行檔或腳本/);
  });
});

test("portal 目標落在目標地圖 portal 上會被拒絕", () => {
  withContent((root) => {
    const mapPath = join(root, "world/maps/map_start_village.json");
    const map = readJson(mapPath);
    map.portals[0].target_grid = [3, 2]; // 森林的 portal 位置
    writeJson(mapPath, map);
    syncManifest(root);
    const { status, out } = runValidator(root);
    assert.equal(status, 1, out);
    assert.match(out, /立即反向傳送/);
  });
});

test("schema 驗證：缺少必填欄位會被拒絕", () => {
  withContent((root) => {
    writeJson(join(root, "schemas/map.schema.json"), {
      type: "object",
      required: [
        "schema_version", "id", "name", "size", "tile_size",
        "tiles", "legend", "spawn", "entities", "portals", "weather",
      ],
      properties: {
        weather: { type: "string" },
        id: { type: "string", pattern: "^map_" },
      },
    });
    const { status, out } = runValidator(root);
    assert.equal(status, 1, out);
    assert.match(out, /缺少必填欄位 weather/);
  });
});

test("builder --check 能偵測 manifest 過期，重建後一致", () => {
  withContent((root) => {
    const itemPath = join(root, "items/item_herb_001.json");
    const item = readJson(itemPath);
    item.name = "藥草二";
    writeJson(itemPath, item);
    const checkStale = spawnSync(process.execPath, [BUILDER, root, "--check"], { encoding: "utf8" });
    assert.equal(checkStale.status, 1, checkStale.stdout);
    assert.match(checkStale.stdout, /MANIFEST MISMATCH/);
    syncManifest(root);
    const checkFresh = spawnSync(process.execPath, [BUILDER, root, "--check"], { encoding: "utf8" });
    assert.equal(checkFresh.status, 0, checkFresh.stdout);
    const validated = runValidator(root);
    assert.equal(validated.status, 0, validated.out);
  });
});
