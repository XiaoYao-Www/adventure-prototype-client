#!/usr/bin/env node
/**
 * 產生遊戲客戶端的暫代（placeholder）像素圖集。
 *
 * 目的：在尚未取得任何第三方美術素材前，讓格子探索切片有可見的
 * 地形與角色佔位圖，避免「視覺優先」退化為純文字或色塊。
 *
 * 產物（皆為本專案自行生成，無第三方權利）：
 *   app_base_git/assets/generated/placeholder_tiles.png   16x16、8 格橫排（128x16）
 *   app_base_git/assets/generated/placeholder_tiles.json  圖集中繼資料
 *
 * 用法：
 *   node tools/generate_placeholder_tiles.mjs [--out-dir <dir>]
 *
 * 使用限制：只使用 Node 內建模組；不連網、不安裝套件。
 * 圖集索引固定為：
 *   0 grass  1 path  2 wall  3 water  4 tree  5 npc  6 chest  7 player
 * 客戶端（scripts/...）與 docs/ASSETS.md 必須與此索引一致。
 */
import { deflateSync } from "node:zlib";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

export const TILE_SIZE = 16;
export const ATLAS_TILES = [
  { index: 0, key: "grass", kind: "terrain" },
  { index: 1, key: "path", kind: "terrain" },
  { index: 2, key: "wall", kind: "terrain" },
  { index: 3, key: "water", kind: "terrain" },
  { index: 4, key: "tree", kind: "terrain" },
  { index: 5, key: "npc", kind: "entity" },
  { index: 6, key: "chest", kind: "entity" },
  { index: 7, key: "player", kind: "entity" },
];

// ---------- 最小 PNG 編碼器（RGBA8、無濾鏡） ----------
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

function pngChunk(type, data) {
  const typeBuf = Buffer.from(type, "ascii");
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const crcBuf = Buffer.alloc(4);
  crcBuf.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])), 0);
  return Buffer.concat([len, typeBuf, data, crcBuf]);
}

function encodePng(width, height, rgba) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 6; // color type RGBA
  ihdr[10] = 0; // compression
  ihdr[11] = 0; // filter
  ihdr[12] = 0; // interlace
  const stride = width * 4;
  const raw = Buffer.alloc((stride + 1) * height);
  for (let y = 0; y < height; y++) {
    raw[y * (stride + 1)] = 0; // filter type 0 (None)
    Buffer.from(rgba.buffer, rgba.byteOffset + y * stride, stride).copy(
      raw,
      y * (stride + 1) + 1,
    );
  }
  const idat = deflateSync(raw, { level: 9 });
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    pngChunk("IHDR", ihdr),
    pngChunk("IDAT", idat),
    pngChunk("IEND", Buffer.alloc(0)),
  ]);
}

// ---------- 繪圖工具 ----------
class Canvas {
  constructor(width, height) {
    this.width = width;
    this.height = height;
    this.data = new Uint8Array(width * height * 4);
    this.seed = 20261116;
  }
  rand() {
    // 可重現的偽隨機（LCG），確保每次產生的圖完全相同
    this.seed = (this.seed * 1664525 + 1013904223) >>> 0;
    return this.seed / 0xffffffff;
  }
  set(x, y, r, g, b, a = 255) {
    if (x < 0 || y < 0 || x >= this.width || y >= this.height) return;
    const i = (y * this.width + x) * 4;
    this.data[i] = r;
    this.data[i + 1] = g;
    this.data[i + 2] = b;
    this.data[i + 3] = a;
  }
  rect(x, y, w, h, r, g, b, a = 255) {
    for (let yy = y; yy < y + h; yy++) {
      for (let xx = x; xx < x + w; xx++) this.set(xx, yy, r, g, b, a);
    }
  }
  outlineRect(x, y, w, h, r, g, b) {
    for (let xx = x; xx < x + w; xx++) {
      this.set(xx, y, r, g, b);
      this.set(xx, y + h - 1, r, g, b);
    }
    for (let yy = y; yy < y + h; yy++) {
      this.set(x, yy, r, g, b);
      this.set(x + w - 1, yy, r, g, b);
    }
  }
  disc(cx, cy, radius, r, g, b, a = 255) {
    for (let yy = -radius; yy <= radius; yy++) {
      for (let xx = -radius; xx <= radius; xx++) {
        if (xx * xx + yy * yy <= radius * radius) {
          this.set(cx + xx, cy + yy, r, g, b, a);
        }
      }
    }
  }
}

function drawGrass(c) {
  for (let y = 0; y < 16; y++) {
    for (let x = 0; x < 16; x++) {
      const n = Math.floor(c.rand() * 22) - 11;
      c.set(x, y, 62 + n, 112 + n, 60 + n);
    }
  }
  for (let i = 0; i < 6; i++) {
    const x = Math.floor(c.rand() * 16);
    const y = Math.floor(c.rand() * 16);
    c.set(x, y, 40, 88, 44);
    c.set(x, y + 1, 46, 96, 50);
  }
}

function drawPath(c) {
  for (let y = 0; y < 16; y++) {
    for (let x = 0; x < 16; x++) {
      const n = Math.floor(c.rand() * 20) - 10;
      c.set(x, y, 158 + n, 132 + n, 86 + n);
    }
  }
  for (let i = 0; i < 5; i++) {
    c.set(Math.floor(c.rand() * 16), Math.floor(c.rand() * 16), 120, 98, 60);
  }
}

function drawWall(c) {
  c.rect(0, 0, 16, 16, 96, 96, 104);
  for (let y = 0; y < 16; y += 8) {
    c.rect(0, y, 16, 1, 64, 64, 72);
    for (let x = (y % 16 === 0 ? 3 : 7); x < 16; x += 8) {
      c.rect(x, y, 1, 8, 64, 64, 72);
    }
  }
  c.rect(0, 0, 16, 1, 124, 124, 132);
}

function drawWater(c) {
  for (let y = 0; y < 16; y++) {
    for (let x = 0; x < 16; x++) {
      const wave = Math.sin((x + y * 0.6) / 2.4) * 10;
      const n = Math.floor(c.rand() * 8);
      c.set(x, y, 32 + n, 78 + wave + n, 150 + wave * 0.8 + n);
    }
  }
  for (let x = 2; x < 14; x += 5) {
    c.set(x, 4, 96, 150, 220);
    c.set(x + 1, 4, 110, 164, 228);
  }
}

function drawTree(c) {
  drawGrass(c);
  c.rect(7, 10, 3, 5, 92, 66, 40);
  c.disc(8, 7, 6, 26, 78, 38);
  c.disc(8, 6, 4, 38, 100, 48);
  c.set(6, 4, 70, 140, 70);
  c.set(9, 3, 70, 140, 70);
}

function drawNpc(c) {
  // 透明背景；長者：灰髮、深藍長袍
  c.rect(6, 2, 4, 4, 232, 190, 152); // 臉
  c.rect(5, 1, 6, 2, 214, 214, 218); // 白髮
  c.rect(4, 6, 8, 7, 52, 70, 132); // 長袍
  c.rect(4, 12, 2, 3, 40, 54, 104);
  c.rect(10, 12, 2, 3, 40, 54, 104);
  c.rect(6, 8, 1, 4, 80, 104, 168); // 衣摺
  c.rect(9, 8, 1, 4, 80, 104, 168);
  c.rect(3, 7, 1, 4, 232, 190, 152); // 手
  c.rect(12, 7, 1, 4, 232, 190, 152);
  c.rect(6, 4, 1, 1, 40, 40, 48); // 眼
  c.rect(9, 4, 1, 1, 40, 40, 48);
}

function drawChest(c) {
  // 透明背景；木箱 + 金鎖
  c.rect(3, 6, 10, 7, 146, 96, 48);
  c.outlineRect(3, 6, 10, 7, 92, 58, 28);
  c.rect(3, 9, 10, 1, 92, 58, 28);
  c.rect(4, 4, 8, 2, 168, 116, 60); // 蓋
  c.outlineRect(4, 4, 8, 2, 92, 58, 28);
  c.rect(7, 9, 2, 2, 232, 196, 72); // 鎖
  c.set(7, 10, 160, 120, 24);
  c.set(8, 10, 160, 120, 24);
}

function drawPlayer(c) {
  // 透明背景；冒險者：綠衣、棕髮
  c.rect(6, 2, 4, 4, 236, 196, 160);
  c.rect(5, 1, 6, 2, 104, 70, 40); // 頭髮
  c.rect(5, 3, 1, 2, 104, 70, 40);
  c.rect(6, 5, 1, 1, 40, 40, 48);
  c.rect(9, 5, 1, 1, 40, 40, 48);
  c.rect(4, 6, 8, 7, 56, 132, 76); // 綠色外衣
  c.rect(4, 12, 2, 3, 48, 60, 52); // 褲
  c.rect(10, 12, 2, 3, 48, 60, 52);
  c.rect(3, 7, 1, 4, 236, 196, 160); // 手
  c.rect(12, 7, 1, 4, 236, 196, 160);
  c.rect(7, 6, 2, 3, 196, 168, 96); // 背帶
}

const DRAWERS = [drawGrass, drawPath, drawWall, drawWater, drawTree, drawNpc, drawChest, drawPlayer];

export function buildAtlas() {
  const cols = ATLAS_TILES.length;
  const width = cols * TILE_SIZE;
  const height = TILE_SIZE;
  const atlas = new Canvas(width, height);
  ATLAS_TILES.forEach((tile, col) => {
    const tileCanvas = new Canvas(TILE_SIZE, TILE_SIZE);
    tileCanvas.seed = 20261116 + tile.index * 7919;
    DRAWERS[tile.index](tileCanvas);
    const ox = col * TILE_SIZE;
    for (let y = 0; y < TILE_SIZE; y++) {
      for (let x = 0; x < TILE_SIZE; x++) {
        const i = (y * TILE_SIZE + x) * 4;
        atlas.set(
          ox + x,
          y,
          tileCanvas.data[i],
          tileCanvas.data[i + 1],
          tileCanvas.data[i + 2],
          tileCanvas.data[i + 3],
        );
      }
    }
  });
  return { canvas: atlas, width, height };
}

function parseArgs(argv) {
  let outDir = null;
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--out-dir") outDir = argv[++i];
  }
  return { outDir };
}

function main() {
  const defaultOut = resolve(
    dirname(fileURLToPath(import.meta.url)),
    "..",
    "assets",
    "generated",
  );
  const { outDir } = parseArgs(process.argv.slice(2));
  const target = outDir ? resolve(outDir) : defaultOut;
  const { canvas, width, height } = buildAtlas();
  const png = encodePng(width, height, canvas.data);
  mkdirSync(target, { recursive: true });
  writeFileSync(join(target, "placeholder_tiles.png"), png);
  const meta = {
    generated: true,
    generated_by: "tools/generate_placeholder_tiles.mjs",
    version: 1,
    tile_size: TILE_SIZE,
    columns: ATLAS_TILES.length,
    rows: 1,
    image: "placeholder_tiles.png",
    image_size: { width, height },
    tiles: ATLAS_TILES,
    license: "本檔案由本專案自行生成，無第三方權利；不得聲稱為第三方素材。",
    note: "暫代視覺，正式美術尚未選定；不得用於對外宣稱最終風格。",
  };
  writeFileSync(
    join(target, "placeholder_tiles.json"),
    JSON.stringify(meta, null, 2) + "\n",
  );
  console.log(`WROTE ${join(target, "placeholder_tiles.png")} (${width}x${height}, ${png.length} bytes)`);
  console.log(`WROTE ${join(target, "placeholder_tiles.json")}`);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main();
}
