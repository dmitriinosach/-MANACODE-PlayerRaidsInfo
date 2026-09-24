const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

const ROOT = path.resolve(__dirname, "..");
const ART = path.join(ROOT, "art");
if (!fs.existsSync(ART)) fs.mkdirSync(ART);

const BTN_N = 32, BTN_R = 6, BTN_INSET = 1, RIM_TOP_A = 0.5;
const GLOW_N = 64, GLOW_CORE = 16, GLOW_R = (GLOW_N - GLOW_CORE) / 2;

const clamp = (v) => Math.max(0, Math.min(1, v));

function roundCoverage(x, y, x0, y0, x1, y1, r) {
  const S = 4;
  let hit = 0;
  for (let sy = 0; sy < S; sy++) for (let sx = 0; sx < S; sx++) {
    const px = x + (sx + 0.5) / S, py = y + (sy + 0.5) / S;
    if (px < x0 || px > x1 || py < y0 || py > y1) continue;
    const cx = px < x0 + r ? x0 + r : px > x1 - r ? x1 - r : px;
    const cy = py < y0 + r ? y0 + r : py > y1 - r ? y1 - r : py;
    const d = Math.hypot(px - cx, py - cy);
    if (d <= r) hit++;
  }
  return hit / (S * S);
}

function shade(row) {
  if (row < 8) return 1 - (row / 8) * 0.12;
  if (row < 24) return 0.88 - ((row - 8) / 16) * 0.06;
  return 0.82 - ((row - 24) / 8) * 0.12;
}

function tga(file, N, fill) {
  const px = Buffer.alloc(N * N * 4);
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const [v, a] = fill(x, y);
    const o = (y * N + x) * 4;
    const c = Math.round(clamp(v) * 255);
    px[o] = c; px[o + 1] = c; px[o + 2] = c;
    px[o + 3] = Math.round(clamp(a) * 255);
  }
  const head = Buffer.alloc(18);
  head[2] = 2;
  head.writeUInt16LE(N, 12);
  head.writeUInt16LE(N, 14);
  head[16] = 32;
  head[17] = 0x20;
  fs.writeFileSync(file, Buffer.concat([head, px]));
  return px;
}

const edge = tga(path.join(ART, "btn_edge.tga"), BTN_N, (x, y) =>
  [1, roundCoverage(x, y, 0, 0, BTN_N, BTN_N, BTN_R)]);

const fill = tga(path.join(ART, "btn_fill.tga"), BTN_N, (x, y) => {
  const cov = roundCoverage(x, y, BTN_INSET, BTN_INSET, BTN_N - BTN_INSET, BTN_N - BTN_INSET, BTN_R - BTN_INSET);
  const rim = y === BTN_INSET ? RIM_TOP_A : 1;
  return [shade(y), cov * rim];
});

const glow = tga(path.join(ART, "glow.tga"), GLOW_N, (x, y) => {
  const px = x + 0.5, py = y + 0.5;
  const lo = GLOW_R, hi = GLOW_N - GLOW_R;
  const dx = px < lo ? lo - px : px > hi ? px - hi : 0;
  const dy = py < lo ? lo - py : py > hi ? py - hi : 0;
  const d = Math.hypot(dx, dy) / GLOW_R;
  const k = 1 - clamp(d);
  return [1, k * k * (3 - 2 * k) * k];
});

const CRC = (() => { const t = new Uint32Array(256); for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; } return t; })();
function crc32(buf) { let c = 0xffffffff; for (let i = 0; i < buf.length; i++) c = CRC[(c ^ buf[i]) & 0xff] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; }
function chunk(type, data) { const len = Buffer.alloc(4); len.writeUInt32BE(data.length); const td = Buffer.concat([Buffer.from(type, "ascii"), data]); const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td)); return Buffer.concat([len, td, crc]); }
function writePng(file, W, H, rgb) {
  const raw = Buffer.alloc((W * 3 + 1) * H);
  for (let y = 0; y < H; y++) { raw[y * (W * 3 + 1)] = 0; for (let x = 0; x < W; x++) { const i = (y * W + x) * 3, o = y * (W * 3 + 1) + 1 + x * 3; raw[o] = rgb[i]; raw[o + 1] = rgb[i + 1]; raw[o + 2] = rgb[i + 2]; } }
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(W, 0); ihdr.writeUInt32BE(H, 4); ihdr[8] = 8; ihdr[9] = 2;
  fs.writeFileSync(file, Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), chunk("IHDR", ihdr), chunk("IDAT", zlib.deflateSync(raw)), chunk("IEND", Buffer.alloc(0))]));
}

const lua = fs.readFileSync(path.join(ROOT, "Util.lua"), "utf8");
const m = lua.match(/ns\.BTN = \{([\s\S]*?)\n\}/);
if (!m) { console.log("не нашёл ns.BTN в Util.lua"); process.exit(1); }
const BTN = {};
for (const mm of m[1].matchAll(/(\w+)\s*=\s*\{([^}]*)\}/g)) BTN[mm[1]] = mm[2].split(",").map(Number);

const ZOOM = 3;
const PANEL = [0.067, 0.059, 0.047];

function sample(px, N, u, v) {
  const x = Math.min(N - 1, Math.floor(u * N)), y = Math.min(N - 1, Math.floor(v * N));
  const o = (y * N + x) * 4;
  return [px[o] / 255, px[o + 3] / 255];
}

function sliceUV(t, size, corner, N) {
  if (t < corner) return t / N;
  if (t >= size - corner) return (N - (size - t)) / N;
  return (corner + ((t - corner) / (size - 2 * corner)) * (N - 2 * corner)) / N;
}

function drawSlice(img, W, px, N, corner, x0, y0, w, h, col, a, add) {
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const [v, ta] = sample(px, N, sliceUV(x, w, corner, N), sliceUV(y, h, corner, N));
    const aa = ta * a;
    if (aa <= 0) continue;
    for (let zy = 0; zy < ZOOM; zy++) for (let zx = 0; zx < ZOOM; zx++) {
      const o = (((y0 + y) * ZOOM + zy) * W + (x0 + x) * ZOOM + zx) * 3;
      for (let c = 0; c < 3; c++) {
        const src = v * col[c];
        const dst = img[o + c] / 255;
        img[o + c] = Math.round(clamp(add ? dst + src * aa : dst * (1 - aa) + src * aa) * 255);
      }
    }
  }
}

function fillRect(img, W, x0, y0, w, h, col, a) {
  for (let y = y0 * ZOOM; y < (y0 + h) * ZOOM; y++) for (let x = x0 * ZOOM; x < (x0 + w) * ZOOM; x++) {
    const o = (y * W + x) * 3;
    for (let c = 0; c < 3; c++) img[o + c] = Math.round(clamp(img[o + c] / 255 * (1 - a) + col[c] * a) * 255);
  }
}

const states = [
  ["idle", BTN.bg, BTN.border, BTN.text],
  ["hover", BTN.bgHover, BTN.borderHover, BTN.textHover],
  ["down", BTN.bgDown, BTN.borderHover, BTN.textHover],
  ["on", BTN.bgOn, BTN.borderOn, BTN.textOn],
  ["onHover", BTN.bgOnHover, BTN.borderOn, BTN.textOn],
  ["off", BTN.bgOff, BTN.borderOff, BTN.textOff],
  ["onOff", BTN.bgOnOff, BTN.borderOff, BTN.textOnOff],
];

const PW = 420, PH = 200;
const W = PW * ZOOM, H = PH * ZOOM;
const img = Buffer.alloc(W * H * 3);
fillRect(img, W, 0, 0, PW, PH, PANEL, 1);

let bx = 10, by = 12;
for (const [name, bg, br, tx] of states) {
  const bw = 76, bh = 20;
  drawSlice(img, W, edge, BTN_N, 8, bx, by, bw, bh, br, br[3] == null ? 1 : br[3], false);
  drawSlice(img, W, fill, BTN_N, 8, bx, by, bw, bh, bg, bg[3] == null ? 1 : bg[3], false);
  fillRect(img, W, bx + 22, by + 8, 32, 4, tx, 1);
  bx += bw + 8;
  if (bx + bw > PW) { bx = 10; by += bh + 12; }
}

const hx = 60, hy = 96, hw = 180, hh = 70, G = 24;
fillRect(img, W, 0, hy - 40, PW, PH - (hy - 40), [0, 0, 0], 0.72);
fillRect(img, W, hx, hy, hw, hh, [0.16, 0.14, 0.11], 1);
const GOLD = [1, 0.82, 0];
const gc = GLOW_R;
const pieces = [
  [hx - G, hy - G, G, G, 0, 0], [hx, hy - G, hw, G, 1, 0], [hx + hw, hy - G, G, G, 2, 0],
  [hx - G, hy, G, hh, 0, 1], [hx + hw, hy, G, hh, 2, 1],
  [hx - G, hy + hh, G, G, 0, 2], [hx, hy + hh, hw, G, 1, 2], [hx + hw, hy + hh, G, G, 2, 2],
];
const U = [0, gc / GLOW_N, (GLOW_N - gc) / GLOW_N, 1];
for (const [x0, y0, w, h, cu, cv] of pieces) {
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const u = U[cu] + (x + 0.5) / w * (U[cu + 1] - U[cu]);
    const v = U[cv] + (y + 0.5) / h * (U[cv + 1] - U[cv]);
    const [, ta] = sample(glow, GLOW_N, u, v);
    const aa = ta * 0.7;
    for (let zy = 0; zy < ZOOM; zy++) for (let zx = 0; zx < ZOOM; zx++) {
      const o = (((y0 + y) * ZOOM + zy) * W + (x0 + x) * ZOOM + zx) * 3;
      for (let c = 0; c < 3; c++) img[o + c] = Math.round(clamp(img[o + c] / 255 + GOLD[c] * aa) * 255);
    }
  }
}
fillRect(img, W, hx - 3, hy - 3, hw + 6, 1, GOLD, 1);
fillRect(img, W, hx - 3, hy + hh + 2, hw + 6, 1, GOLD, 1);
fillRect(img, W, hx - 3, hy - 3, 1, hh + 6, GOLD, 1);
fillRect(img, W, hx + hw + 2, hy - 3, 1, hh + 6, GOLD, 1);

const out = process.argv[2] || path.join(ROOT, "tools", "ui_art.png");
writePng(out, W, H, img);
console.log("art/btn_edge.tga, art/btn_fill.tga " + BTN_N + "x" + BTN_N + ", art/glow.tga " + GLOW_N + "x" + GLOW_N + "; превью " + out);
