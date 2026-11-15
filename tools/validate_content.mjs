#!/usr/bin/env node
/**
 * game-content 內容包驗證器（零依賴）。
 *
 * 用途：在提交或發布內容前，獨立檢查 game-content 倉庫的資料契約，
 * 不依賴 Godot。與 game-client 的內容載入器互為交叉驗證。
 *
 * 用法：
 *   node tools/validate_content.mjs <content_dir>
 *
 * 檢查項目：
 *   1. manifest.json 結構、版本欄位、檔案清單完整性
 *   2. 所有資料 JSON 可解析
 *   3. 內建結構規則（必填欄位、型別、列舉值）
 *   4. 若有 schemas/<type>.schema.json，額外用 JSON Schema 子集驗證
 *   5. 地圖：尺寸、legend 覆蓋、spawn/entity/portal 位置與可通行
 *   6. 引用完整性：event/map/item/npc/region/portal
 *   7. ID 唯一性與命名規則
 *   8. manifest 的 sha256 與 size 與實際檔案一致
 *   9. 禁止可執行檔、腳本、symlink
 *
 * 結束碼：0 = 通過（可能有 warnings）；1 = 有 errors。
 */
import { createHash } from "node:crypto";
import { existsSync, lstatSync, readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

const ID_RE = /^[a-z][a-z0-9_]*$/;
const SEMVER_RE = /^\d+\.\d+\.\d+$/;
const ALLOWED_TILES = new Set(["grass", "path", "wall", "water", "tree", "floor"]);
const ALLOWED_ENTITY_TYPES = new Set(["npc", "object"]);
const ALLOWED_EFFECTS = new Set(["set_flag", "give_item"]);
const ALLOWED_ITEM_CATEGORIES = new Set(["consumable", "key", "material", "equipment"]);
const FORBIDDEN_EXTENSIONS = new Set([
  ".gd", ".gdshader", ".dll", ".so", ".exe", ".sh", ".bat", ".ps1", ".cmd",
  ".js", ".mjs", ".cjs", ".py", ".jar", ".apk", ".aab", ".class", ".wasm",
]);
/** content 根目錄下會被視為資料的目錄（其餘目錄如 schemas/docs 不列入 manifest）。 */
const DATA_ROOTS = ["world", "characters", "items", "events"];

// ---------------------------------------------------------------------------
// 工具
// ---------------------------------------------------------------------------

function sha256File(path) {
  return createHash("sha256").update(readFileSync(path)).digest("hex");
}

function isPlainObject(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function deepEqual(a, b) {
  return JSON.stringify(a) === JSON.stringify(b);
}

function walkFiles(rootDir, subDir, out) {
  const abs = join(rootDir, subDir);
  if (!existsSync(abs)) return;
  for (const name of readdirSync(abs).sort()) {
    const full = join(abs, name);
    const st = lstatSync(full);
    if (st.isSymbolicLink()) {
      out.push({ rel: toRel(rootDir, full), symlink: true, size: 0 });
      continue;
    }
    if (st.isDirectory()) walkFiles(rootDir, join(subDir, name), out);
    else out.push({ rel: toRel(rootDir, full), symlink: false, size: st.size });
  }
}

function toRel(rootDir, abs) {
  return relative(rootDir, abs).split(sep).join("/");
}

function collectDataFiles(rootDir) {
  const files = [];
  for (const root of DATA_ROOTS) {
    const found = [];
    walkFiles(rootDir, root, found);
    for (const f of found) {
      if (!f.symlink && f.rel.endsWith(".json")) files.push(f.rel);
    }
  }
  return files.sort();
}

/** JSON Schema draft 2020-12 的實用子集；未知關鍵字忽略。 */
function validateSchema(schema, data, path, rootSchema, errors) {
  if (schema === true || schema === undefined) return;
  if (schema === false) {
    errors.push(`${path}: 不允許任何值（schema=false）`);
    return;
  }
  if (schema.$ref) {
    if (typeof schema.$ref !== "string" || !schema.$ref.startsWith("#/")) {
      errors.push(`${path}: 不支援的 $ref ${schema.$ref}`);
      return;
    }
    const target = schema.$ref
      .slice(2)
      .split("/")
      .reduce((acc, key) => (acc === undefined ? undefined : acc[key]), rootSchema);
    if (target === undefined) {
      errors.push(`${path}: $ref 目標不存在 ${schema.$ref}`);
      return;
    }
    return validateSchema(target, data, path, rootSchema, errors);
  }
  if ("const" in schema && !deepEqual(schema.const, data)) {
    errors.push(`${path}: 必須等於 ${JSON.stringify(schema.const)}，實際 ${JSON.stringify(data)}`);
  }
  if (Array.isArray(schema.enum) && !schema.enum.some((v) => deepEqual(v, data))) {
    errors.push(`${path}: 值 ${JSON.stringify(data)} 不在允許清單 ${JSON.stringify(schema.enum)}`);
  }
  if (schema.type !== undefined) {
    const types = Array.isArray(schema.type) ? schema.type : [schema.type];
    const matched = types.some((t) => matchType(t, data));
    if (!matched) errors.push(`${path}: 型別應為 ${types.join("|")}，實際 ${describeType(data)}`);
  }
  if (Array.isArray(schema.allOf)) {
    for (const sub of schema.allOf) validateSchema(sub, data, path, rootSchema, errors);
  }
  if (Array.isArray(schema.anyOf)) {
    const anyErrors = [];
    const ok = schema.anyOf.some((sub) => {
      const local = [];
      validateSchema(sub, data, path, rootSchema, local);
      anyErrors.push(local);
      return local.length === 0;
    });
    if (!ok) errors.push(`${path}: 不符合 anyOf 任何一個 schema`);
  }
  if (Array.isArray(schema.oneOf)) {
    let passCount = 0;
    for (const sub of schema.oneOf) {
      const local = [];
      validateSchema(sub, data, path, rootSchema, local);
      if (local.length === 0) passCount++;
    }
    if (passCount !== 1) errors.push(`${path}: oneOf 需恰好符合一個 schema（符合 ${passCount} 個）`);
  }
  if (typeof data === "string") {
    if (Number.isInteger(schema.minLength) && data.length < schema.minLength) {
      errors.push(`${path}: 長度 ${data.length} 小於 minLength ${schema.minLength}`);
    }
    if (Number.isInteger(schema.maxLength) && data.length > schema.maxLength) {
      errors.push(`${path}: 長度 ${data.length} 大於 maxLength ${schema.maxLength}`);
    }
    if (typeof schema.pattern === "string" && !new RegExp(schema.pattern, "u").test(data)) {
      errors.push(`${path}: 不符合 pattern ${schema.pattern}`);
    }
  }
  if (typeof data === "number") {
    if (typeof schema.minimum === "number" && data < schema.minimum) {
      errors.push(`${path}: ${data} 小於 minimum ${schema.minimum}`);
    }
    if (typeof schema.maximum === "number" && data > schema.maximum) {
      errors.push(`${path}: ${data} 大於 maximum ${schema.maximum}`);
    }
    if (typeof schema.multipleOf === "number" && data % schema.multipleOf !== 0) {
      errors.push(`${path}: ${data} 不是 multipleOf ${schema.multipleOf} 的倍數`);
    }
  }
  if (Array.isArray(data)) {
    if (Number.isInteger(schema.minItems) && data.length < schema.minItems) {
      errors.push(`${path}: 項目數 ${data.length} 小於 minItems ${schema.minItems}`);
    }
    if (Number.isInteger(schema.maxItems) && data.length > schema.maxItems) {
      errors.push(`${path}: 項目數 ${data.length} 大於 maxItems ${schema.maxItems}`);
    }
    if (schema.uniqueItems === true) {
      const seen = new Set();
      for (const item of data) {
        const key = JSON.stringify(item);
        if (seen.has(key)) errors.push(`${path}: uniqueItems 有重複項目 ${key}`);
        seen.add(key);
      }
    }
    if (schema.items !== undefined) {
      data.forEach((item, index) =>
        validateSchema(schema.items, item, `${path}/${index}`, rootSchema, errors),
      );
    }
  }
  if (isPlainObject(data)) {
    if (Array.isArray(schema.required)) {
      for (const key of schema.required) {
        if (!(key in data)) errors.push(`${path}: 缺少必填欄位 ${key}`);
      }
    }
    const props = schema.properties ?? {};
    for (const [key, sub] of Object.entries(props)) {
      if (key in data) validateSchema(sub, data[key], `${path}/${key}`, rootSchema, errors);
    }
    if (schema.additionalProperties === false) {
      for (const key of Object.keys(data)) {
        if (!(key in props)) errors.push(`${path}: 不允許的欄位 ${key}`);
      }
    } else if (isPlainObject(schema.additionalProperties)) {
      for (const key of Object.keys(data)) {
        if (!(key in props)) {
          validateSchema(
            schema.additionalProperties,
            data[key],
            `${path}/${key}`,
            rootSchema,
            errors,
          );
        }
      }
    }
  }
}

function matchType(type, data) {
  switch (type) {
    case "object": return isPlainObject(data);
    case "array": return Array.isArray(data);
    case "string": return typeof data === "string";
    case "number": return typeof data === "number" && Number.isFinite(data);
    case "integer": return Number.isInteger(data);
    case "boolean": return typeof data === "boolean";
    case "null": return data === null;
    default: return true; // 未知型別不視為錯誤，由其他檢查處理
  }
}

function describeType(data) {
  if (data === null) return "null";
  if (Array.isArray(data)) return "array";
  return typeof data;
}

function isInt(value) {
  return Number.isInteger(value);
}

// ---------------------------------------------------------------------------
// 主驗證流程
// ---------------------------------------------------------------------------

export function validateContentDir(contentDir) {
  const errors = [];
  const warnings = [];
  const stats = { dataFiles: 0, maps: 0, npcs: 0, items: 0, events: 0, regions: 0, bytes: 0 };
  const root = resolve(contentDir);
  const abs = (rel) => join(root, rel);

  if (!existsSync(root) || !statSync(root).isDirectory()) {
    return { ok: false, errors: [`內容目錄不存在或不是目錄：${root}`], warnings, stats };
  }

  // 1. manifest -----------------------------------------------------------------
  const manifestPath = abs("manifest.json");
  if (!existsSync(manifestPath)) {
    errors.push("缺少 manifest.json");
    return { ok: false, errors, warnings, stats };
  }
  let manifest;
  try {
    manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
  } catch (error) {
    return { ok: false, errors: [`manifest.json 無法解析：${error.message}`], warnings, stats };
  }
  if (manifest.manifest_schema !== 1) errors.push("manifest.manifest_schema 必須為 1");
  if (typeof manifest.content_id !== "string" || !ID_RE.test(manifest.content_id)) {
    errors.push("manifest.content_id 必須是小寫 snake_case");
  }
  for (const field of ["content_version", "min_game_version"]) {
    if (typeof manifest[field] !== "string" || !SEMVER_RE.test(manifest[field])) {
      errors.push(`manifest.${field} 必須是 semver（x.y.z）`);
    }
  }
  if (manifest.schema_version !== 1) errors.push("manifest.schema_version 必須為 1");
  if (!Array.isArray(manifest.dependencies)) errors.push("manifest.dependencies 必須是陣列");
  if (!Array.isArray(manifest.files) || manifest.files.length === 0) {
    errors.push("manifest.files 必須是非空陣列");
  }

  // 2. 發現資料檔與禁止檔案 ------------------------------------------------
  const dataFiles = collectDataFiles(root);
  stats.dataFiles = dataFiles.length;
  for (const rootName of ["schemas", "docs", "asset_catalog", "optional_content", "releases", ...DATA_ROOTS]) {
    const dirPath = abs(rootName);
    if (!existsSync(dirPath)) continue;
    const found = [];
    walkFiles(root, rootName, found);
    for (const f of found) {
      if (f.symlink) {
        errors.push(`${f.rel}: 禁止 symlink`);
        continue;
      }
      const ext = f.rel.slice(f.rel.lastIndexOf(".")).toLowerCase();
      if (FORBIDDEN_EXTENSIONS.has(ext)) {
        errors.push(`${f.rel}: 內容倉庫不得包含可執行檔或腳本（${ext}）`);
      }
    }
  }

  // 3. 解析所有資料 JSON ----------------------------------------------------
  const docs = new Map(); // rel -> parsed
  for (const rel of dataFiles) {
    const full = abs(rel);
    try {
      docs.set(rel, JSON.parse(readFileSync(full, "utf8")));
      stats.bytes += statSync(full).size;
    } catch (error) {
      errors.push(`${rel}: JSON 無法解析：${error.message}`);
    }
  }

  // 4. 內建結構規則 + 5. schema --------------------------------------------
  const schemaCache = new Map();
  function getSchema(kind) {
    if (schemaCache.has(kind)) return schemaCache.get(kind);
    const rel = `schemas/${kind}.schema.json`;
    if (!existsSync(abs(rel))) {
      schemaCache.set(kind, null);
      return null;
    }
    try {
      const parsed = JSON.parse(readFileSync(abs(rel), "utf8"));
      schemaCache.set(kind, parsed);
      return parsed;
    } catch (error) {
      errors.push(`${rel}: JSON 無法解析：${error.message}`);
      schemaCache.set(kind, null);
      return null;
    }
  }
  function runSchema(kind, rel, data) {
    const schema = getSchema(kind);
    if (!schema) return;
    const before = errors.length;
    validateSchema(schema, data, rel, schema, errors);
    if (errors.length !== before) {
      errors.push(`（上述 ${errors.length - before} 項來自 ${kind} schema 驗證）`);
    }
  }

  const maps = new Map();
  const npcs = new Map();
  const items = new Map();
  const events = new Map();
  const regions = new Map();

  for (const rel of dataFiles) {
    const data = docs.get(rel);
    if (data === undefined) continue;
    if (!isPlainObject(data)) {
      errors.push(`${rel}: 頂層必須是物件`);
      continue;
    }
    if (data.schema_version !== 1) errors.push(`${rel}: schema_version 必須為 1`);
    if (typeof data.id !== "string" || !ID_RE.test(data.id)) {
      errors.push(`${rel}: id 必須是小寫 snake_case`);
    }
    const dir = rel.split("/")[0];
    if (rel.includes("/regions/")) {
      runSchema("region", rel, data);
      regions.set(data.id, data);
      stats.regions++;
      if (!Array.isArray(data.map_ids) || data.map_ids.length === 0) {
        errors.push(`${rel}: map_ids 必須是非空陣列`);
      }
    } else if (rel.includes("/maps/")) {
      runSchema("map", rel, data);
      maps.set(data.id, { rel, data });
      stats.maps++;
    } else if (rel.includes("/npcs/")) {
      runSchema("npc", rel, data);
      npcs.set(data.id, data);
      stats.npcs++;
    } else if (dir === "items") {
      runSchema("item", rel, data);
      items.set(data.id, data);
      stats.items++;
    } else if (dir === "events") {
      runSchema("event", rel, data);
      events.set(data.id, { rel, data });
      stats.events++;
    } else {
      warnings.push(`${rel}: 未知的資料目錄，未納入驗證`);
    }
  }

  // 7. 全域 ID 唯一性 ------------------------------------------------------
  const seenIds = new Map();
  for (const [collectionName, collection] of [
    ["map", maps], ["npc", npcs], ["item", items], ["event", events], ["region", regions],
  ]) {
    for (const id of collection.keys()) {
      if (seenIds.has(id)) {
        errors.push(`ID 重複：${id}（${seenIds.get(id)} 與 ${collectionName}）`);
      } else {
        seenIds.set(id, collectionName);
      }
    }
  }
  const prefixRules = {
    map: /^map_[a-z0-9_]+$/,
    npc: /^npc_[a-z0-9_]+$/,
    item: /^item_[a-z0-9_]+$/,
    event: /^event_[a-z0-9_]+$/,
    region: /^region_[a-z0-9_]+$/,
  };
  for (const [kind, collection] of [["map", maps], ["npc", npcs], ["item", items], ["event", events], ["region", regions]]) {
    for (const id of collection.keys()) {
      if (!prefixRules[kind].test(id)) errors.push(`ID 命名不符 ${kind}_ 前綴規則：${id}`);
    }
  }

  // 5./6. 地圖與引用完整性 ------------------------------------------------
  const allMapIds = new Set(maps.keys());
  for (const [mapId, entry] of maps) {
    const { rel, data: map } = entry;
    const p = (suffix) => `${rel}: ${suffix}`;
    if (!isPlainObject(map.size)) {
      errors.push(p("缺少 size"));
      continue;
    }
    const width = map.size.width;
    const height = map.size.height;
    if (!isInt(width) || !isInt(height) || width <= 0 || height <= 0) {
      errors.push(p("size.width/height 必須是正整數"));
      continue;
    }
    if (map.tile_size !== 16) errors.push(p(`tile_size 必須為 16，實際 ${map.tile_size}`));
    if (!Array.isArray(map.tiles) || map.tiles.length !== height) {
      errors.push(p(`tiles 必須有 ${height} 列`));
      continue;
    }
    const legend = map.legend;
    if (!isPlainObject(legend) || Object.keys(legend).length === 0) {
      errors.push(p("缺少 legend"));
      continue;
    }
    for (const [char, def] of Object.entries(legend)) {
      if (char.length !== 1) errors.push(p(`legend 的 key 必須是單一字元：「${char}」`));
      if (!isPlainObject(def)) {
        errors.push(p(`legend.${char} 必須是物件`));
        continue;
      }
      if (!ALLOWED_TILES.has(def.tile)) {
        errors.push(p(`legend.${char}.tile 不允許：${def.tile}`));
      }
      if (typeof def.walkable !== "boolean") {
        errors.push(p(`legend.${char}.walkable 必須是 bool`));
      }
    }
    const walkableAt = (grid) => {
      const [x, y] = grid;
      const row = map.tiles[y];
      if (typeof row !== "string") return false;
      const char = row[x];
      const def = legend[char];
      return Boolean(def && def.walkable);
    };
    const inBounds = (grid) =>
      Array.isArray(grid) && grid.length === 2 && isInt(grid[0]) && isInt(grid[1]) &&
      grid[0] >= 0 && grid[1] >= 0 && grid[0] < width && grid[1] < height;
    const gridPath = (grid, suffix) => `${rel}: ${suffix} grid=${JSON.stringify(grid)}`;

    map.tiles.forEach((row, y) => {
      if (typeof row !== "string") {
        errors.push(p(`tiles[${y}] 必須是字串`));
        return;
      }
      if (row.length !== width) {
        errors.push(p(`tiles[${y}] 長度 ${row.length} 應為 ${width}`));
      }
      for (let x = 0; x < row.length; x++) {
        if (!(row[x] in legend)) errors.push(p(`tiles[${y}][${x}] 字元「${row[x]}」不在 legend`));
      }
    });

    if (!isPlainObject(map.spawn) || !inBounds(map.spawn.grid)) {
      errors.push(p("spawn.grid 必須在範圍內"));
    } else if (!walkableAt(map.spawn.grid)) {
      errors.push(gridPath(map.spawn.grid, "spawn 必須在可通行格"));
    }

    const entityIds = new Set();
    if (!Array.isArray(map.entities)) {
      errors.push(p("entities 必須是陣列"));
    } else {
      map.entities.forEach((entity, index) => {
        const where = `${rel}: entities[${index}]`;
        if (!isPlainObject(entity)) {
          errors.push(`${where} 必須是物件`);
          return;
        }
        if (typeof entity.id !== "string" || !ID_RE.test(entity.id)) {
          errors.push(`${where}.id 必須是小寫 snake_case`);
        } else if (entityIds.has(entity.id)) {
          errors.push(`${where}.id 重複：${entity.id}`);
        } else {
          entityIds.add(entity.id);
        }
        if (!ALLOWED_ENTITY_TYPES.has(entity.type)) {
          errors.push(`${where}.type 不允許：${entity.type}`);
        }
        if (!inBounds(entity.grid)) {
          errors.push(gridPath(entity.grid, `${where} 位置超出範圍`));
        } else if (!walkableAt(entity.grid)) {
          errors.push(gridPath(entity.grid, `${where} 必須在可通行格`));
        }
        if (!isPlainObject(entity.interaction) || entity.interaction.kind !== "event") {
          errors.push(`${where}.interaction.kind 目前只允許 "event"`);
        } else if (!events.has(entity.interaction.event_id)) {
          errors.push(`${where}.interaction.event_id 不存在：${entity.interaction.event_id}`);
        }
      });
    }

    const targetSeen = new Map();
    if (!Array.isArray(map.portals)) {
      errors.push(p("portals 必須是陣列"));
    } else {
      const portalGrids = new Set(map.portals.filter((o) => isPlainObject(o)).map((o) => JSON.stringify(o.grid)));
      map.portals.forEach((portal, index) => {
        const where = `${rel}: portals[${index}]`;
        if (!isPlainObject(portal)) {
          errors.push(`${where} 必須是物件`);
          return;
        }
        if (typeof portal.id !== "string" || !/^portal_[a-z0-9_]+$/.test(portal.id)) {
          errors.push(`${where}.id 必須符合 portal_ 前綴`);
        }
        if (!inBounds(portal.grid)) {
          errors.push(gridPath(portal.grid, `${where} 位置超出範圍`));
        } else if (!walkableAt(portal.grid)) {
          errors.push(gridPath(portal.grid, `${where} portal 必須在可通行格`));
        }
        if (!allMapIds.has(portal.target_map_id)) {
          errors.push(`${where}.target_map_id 不存在：${portal.target_map_id}`);
          return;
        }
        const target = maps.get(portal.target_map_id).data;
        const targetWidth = target.size.width;
        const targetHeight = target.size.height;
        const tGrid = portal.target_grid;
        const tOk =
          Array.isArray(tGrid) && tGrid.length === 2 && isInt(tGrid[0]) && isInt(tGrid[1]) &&
          tGrid[0] >= 0 && tGrid[1] >= 0 && tGrid[0] < targetWidth && tGrid[1] < targetHeight;
        if (!tOk) {
          errors.push(`${where}.target_grid 超出目標地圖範圍`);
          return;
        }
        const tRow = target.tiles[tGrid[1]];
        const tDef = target.legend[tRow[tGrid[0]]];
        if (!tDef || !tDef.walkable) {
          errors.push(`${where}.target_grid 在目標地圖不是可通行格`);
        }
        const targetPortalGrids = new Set(
          (target.portals ?? []).filter((o) => isPlainObject(o)).map((o) => JSON.stringify(o.grid)),
        );
        if (targetPortalGrids.has(JSON.stringify(tGrid))) {
          errors.push(`${where}.target_grid 落在目標地圖的 portal 上，會造成立即反向傳送`);
        }
        if (targetSeen.has(portal.target_map_id)) {
          warnings.push(`${rel}: 有多個 portal 指向同一張地圖（${portal.target_map_id}）`);
        }
        targetSeen.set(portal.target_map_id, true);
      });
    }
  }

  // region 引用
  for (const [regionId, region] of regions) {
    for (const mapId of region.map_ids ?? []) {
      if (!allMapIds.has(mapId)) errors.push(`region ${regionId}: map_ids 引用不存在的地圖 ${mapId}`);
    }
  }

  // event 內容
  for (const [eventId, entry] of events) {
    const { rel, data: event } = entry;
    const p = (suffix) => `${rel} (${eventId}): ${suffix}`;
    if (event.kind !== "dialogue") errors.push(p("kind 目前只允許 dialogue"));
    if (typeof event.repeatable !== "boolean") errors.push(p("repeatable 必須是 bool"));
    if (!Array.isArray(event.lines) || event.lines.length === 0) {
      errors.push(p("lines 必須是非空陣列"));
    } else {
      event.lines.forEach((line, index) => {
        if (!isPlainObject(line)) {
          errors.push(p(`lines[${index}] 必須是物件`));
          return;
        }
        if (typeof line.text !== "string" || line.text.trim().length === 0) {
          errors.push(p(`lines[${index}].text 不可為空`));
        } else if (line.text.length > 64) {
          warnings.push(p(`lines[${index}].text 長度 ${line.text.length} 超過 64 字，可能塞滿對話框`));
        }
        if (line.speaker_id !== "player" && !npcs.has(line.speaker_id)) {
          errors.push(p(`lines[${index}].speaker_id 不存在：${line.speaker_id}`));
        }
      });
    }
    if (event.trigger !== undefined) {
      if (!isPlainObject(event.trigger)) {
        errors.push(p("trigger 必須是物件"));
      } else {
        const mapEntry = maps.get(event.trigger.map_id);
        if (!mapEntry) {
          errors.push(p(`trigger.map_id 不存在：${event.trigger.map_id}`));
        } else {
          const entity = (mapEntry.data.entities ?? []).find((e) => e.id === event.trigger.entity_id);
          if (!entity) errors.push(p(`trigger.entity_id 不在地圖 ${event.trigger.map_id}：${event.trigger.entity_id}`));
          else if (entity.interaction?.event_id !== eventId) {
            errors.push(p(`trigger.entity_id 的 interaction.event_id 不是 ${eventId}`));
          }
        }
      }
    }
    if (event.choices !== undefined) {
      if (!Array.isArray(event.choices) || event.choices.length === 0) {
        errors.push(p("choices 若有，必須是非空陣列"));
      } else {
        const choiceIds = new Set();
        event.choices.forEach((choice, index) => {
          if (!isPlainObject(choice)) {
            errors.push(p(`choices[${index}] 必須是物件`));
            return;
          }
          if (typeof choice.id !== "string" || !ID_RE.test(choice.id)) {
            errors.push(p(`choices[${index}].id 必須是小寫 snake_case`));
          } else if (choiceIds.has(choice.id)) {
            errors.push(p(`choices[${index}].id 重複：${choice.id}`));
          } else {
            choiceIds.add(choice.id);
          }
          if (typeof choice.text !== "string" || choice.text.trim().length === 0) {
            errors.push(p(`choices[${index}].text 不可為空`));
          } else if (choice.text.length > 24) {
            warnings.push(p(`choices[${index}].text 長度 ${choice.text.length} 超過 24 字`));
          }
          if (!Array.isArray(choice.effects)) {
            errors.push(p(`choices[${index}].effects 必須是陣列`));
            return;
          }
          choice.effects.forEach((effect, effIndex) => {
            const where = `choices[${index}].effects[${effIndex}]`;
            if (!isPlainObject(effect)) {
              errors.push(p(`${where} 必須是物件`));
              return;
            }
            if (!ALLOWED_EFFECTS.has(effect.type)) {
              errors.push(p(`${where}.type 不在白名單：${effect.type}`));
              return;
            }
            if (effect.type === "set_flag") {
              if (typeof effect.flag !== "string" || !/^flag_[a-z0-9_]+$/.test(effect.flag)) {
                errors.push(p(`${where}.flag 必須符合 flag_ 前綴`));
              }
              if (typeof effect.value !== "boolean") errors.push(p(`${where}.value 必須是 bool`));
            }
            if (effect.type === "give_item") {
              if (!items.has(effect.item_id)) errors.push(p(`${where}.item_id 不存在：${effect.item_id}`));
              if (!isInt(effect.qty) || effect.qty <= 0) errors.push(p(`${where}.qty 必須是正整數`));
            }
          });
        });
      }
    }
  }

  // 6. manifest 完整性與雜湊 -------------------------------------------------
  const manifestPaths = new Set();
  for (const entry of manifest.files ?? []) {
    if (!isPlainObject(entry)) {
      errors.push("manifest.files 內含非物件項目");
      continue;
    }
    if (typeof entry.path !== "string") {
      errors.push("manifest.files[].path 必須是字串");
      continue;
    }
    if (manifestPaths.has(entry.path)) errors.push(`manifest.files 重複路徑：${entry.path}`);
    manifestPaths.add(entry.path);
    const full = abs(entry.path);
    if (!existsSync(full)) {
      errors.push(`manifest 列出但檔案不存在：${entry.path}`);
      continue;
    }
    const size = statSync(full).size;
    if (size !== entry.size) errors.push(`${entry.path}: 大小不符（manifest ${entry.size}，實際 ${size}）`);
    const hash = sha256File(full);
    if (hash !== entry.sha256) {
      errors.push(`${entry.path}: sha256 不符（manifest ${entry.sha256}，實際 ${hash}）`);
    }
    if (!/^[0-9a-f]{64}$/.test(entry.sha256 ?? "")) {
      errors.push(`${entry.path}: sha256 必須是 64 位小寫十六進位`);
    }
  }
  for (const rel of dataFiles) {
    if (!manifestPaths.has(rel)) errors.push(`資料檔未列入 manifest：${rel}`);
  }

  // 文件與出版目錄提示（warnings）
  for (const requiredDoc of ["docs/CONTENT_SCHEMA.md", "docs/ASSET_POLICY.md"]) {
    if (!existsSync(abs(requiredDoc))) warnings.push(`缺少文件 ${requiredDoc}`);
  }

  return { ok: errors.length === 0, errors, warnings, stats };
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

function main() {
  const args = process.argv.slice(2).filter((a) => !a.startsWith("--"));
  if (args.length !== 1) {
    console.error("用法：node tools/validate_content.mjs <content_dir>");
    process.exit(2);
  }
  const result = validateContentDir(args[0]);
  const { stats } = result;
  console.log("=== 內容包驗證 ===");
  console.log(`目錄：${resolve(args[0])}`);
  console.log(
    `統計：資料檔 ${stats.dataFiles}、地圖 ${stats.maps}、NPC ${stats.npcs}、道具 ${stats.items}、事件 ${stats.events}、區域 ${stats.regions}、${stats.bytes} bytes`,
  );
  for (const warning of result.warnings) console.log(`WARN  ${warning}`);
  for (const error of result.errors) console.log(`ERROR ${error}`);
  if (result.ok) {
    console.log(`CONTENT OK（${result.warnings.length} warnings）`);
    process.exit(0);
  }
  console.log(`CONTENT FAILED（${result.errors.length} errors、${result.warnings.length} warnings）`);
  process.exit(1);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main();
}
