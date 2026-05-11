#!/usr/bin/env node
import { parseArgs } from "node:util";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";

const skillRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const runtimeRequire = createRequire(path.join(skillRoot, "runtime", "package.json"));
const { default: Replicate } = await import(runtimeRequire.resolve("replicate"));
const { default: sharp } = await import(runtimeRequire.resolve("sharp"));

/** Standard Java 64×64 player-type skin UV (top-left origin, inclusive pixel ranges). Model must paint features ONLY in the named regions—never put eyes on torso or limbs. */
const ENTITY_UV_ATLAS_SUFFIX =
  " This file is a Minecraft Java 64×64 mob SKIN ATLAS (same UV as a 1.8+ player skin). Use EXACT rectangle layout: HEAD front face (where eyes/mouth belong ONLY) = pixels x=8..15, y=8..15, one 8×8 square; HEAD right x=0..7,y=8..15; HEAD left x=16..23,y=8..15; HEAD back x=24..31,y=8..15; HEAD top x=8..15,y=0..7; HEAD bottom x=16..23,y=0..7. HAT/helmet outer layer mirror those: hat front x=40..47,y=8..15; hat top x=40..47,y=0..7 (put mushroom cap brim and spots here). Torso/arms/legs occupy lower rows—do NOT draw eyeballs there. All features must align to integer 64×64 grid with crisp edges. Top-down orthographic cube faces only—never a full-body character render.";

const RD_FAST_MODEL = "retro-diffusion/rd-fast";

function slugify(value) {
  return value.trim().toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/_+/g, "_").replace(/^_+|_+$/g, "") || "texture";
}

const SPRITE_SUBJECT_REGEX = /(door|trapdoor|plant|crop|torch|lantern|stem|sapling|flower|vine|sprout|leaf)/i;
const FACE_SUBJECT_REGEX = /(top|bottom|side|front|back|north|south|east|west)/i;

function selectStyle(assetType, subject, override) {
  if (override) return override;
  if (assetType === "item") return "mc_item";
  if (assetType === "entity") return "mc_texture";
  if (SPRITE_SUBJECT_REGEX.test(subject)) return "mc_item";
  return "mc_texture";
}

function legacyIsTileableBlock(assetType, subject, style) {
  if (style !== "mc_texture") return false;
  if (assetType !== "block") return false;
  if (SPRITE_SUBJECT_REGEX.test(subject)) return false;
  if (FACE_SUBJECT_REGEX.test(subject) && /\b(top|bottom)\b/i.test(subject)) {
    return true;
  }
  return true;
}

/**
 * plan: no tiling when reference image, entity type, or --no-tile
 */
function computeTileable({ assetType, subject, style, noTileFlag, hasReferenceImage }) {
  if (noTileFlag) return false;
  if (hasReferenceImage) return false;
  if (assetType === "entity") return false;
  return legacyIsTileableBlock(assetType, subject, style);
}

function buildPrompt(assetType, subject, userPrompt, style) {
  let base;
  if (userPrompt) base = userPrompt;
  else if (style === "mc_item") base = `${subject}`;
  else if (style === "mc_texture") base = `${subject}`;
  else if (assetType === "item") base = `Minecraft item sprite, ${subject}`;
  else base = `Minecraft block texture, ${subject}`;
  if (assetType === "entity") {
    return `${base}${ENTITY_UV_ATLAS_SUFFIX}`;
  }
  return base;
}

function outputUrl(oneOutput) {
  if (typeof oneOutput === "string") return oneOutput;
  if (oneOutput && typeof oneOutput.url === "function") return String(oneOutput.url());
  if (oneOutput && typeof oneOutput.url === "string") return oneOutput.url;
  throw new Error(`Unsupported Replicate output type: ${typeof oneOutput}`);
}

async function readOutputBytes(oneOutput) {
  if (Buffer.isBuffer(oneOutput)) return oneOutput;
  const url = outputUrl(oneOutput);
  if (/^https?:\/\//.test(url)) {
    const response = await fetch(url);
    if (!response.ok) throw new Error(`Failed to download Replicate output: HTTP ${response.status}`);
    return Buffer.from(await response.arrayBuffer());
  }
  return readFile(url);
}

function normalizeOutputs(output) {
  return Array.isArray(output) ? output : [output];
}

function removePlainBackground(raw, width, height, tolerance) {
  const cornerOffsets = [0, (width - 1) * 4, ((height - 1) * width) * 4, (height * width - 1) * 4];
  const bg = [0, 1, 2].map((channel) => Math.floor(cornerOffsets.reduce((sum, offset) => sum + raw[offset + channel], 0) / 4));
  for (let i = 0; i < raw.length; i += 4) {
    const distance = Math.max(Math.abs(raw[i] - bg[0]), Math.abs(raw[i + 1] - bg[1]), Math.abs(raw[i + 2] - bg[2]));
    if (distance <= tolerance) raw[i + 3] = 0;
  }
  return raw;
}

async function postprocessPng(rawBytes, size, transparentBg, bgTolerance, modelHandlesTransparency) {
  const metadata = await sharp(rawBytes).metadata();
  const srcW = metadata.width || size;
  const srcH = metadata.height || size;
  const side = Math.min(srcW, srcH);
  const left = Math.floor((srcW - side) / 2);
  const top = Math.floor((srcH - side) / 2);
  const needsResize = side !== size;
  let image = sharp(rawBytes).ensureAlpha().extract({ left, top, width: side, height: side });
  if (needsResize) {
    image = image.resize(size, size, { kernel: "nearest" });
  }
  if (transparentBg && !modelHandlesTransparency) {
    const { data, info } = await image.raw().toBuffer({ resolveWithObject: true });
    const cleaned = removePlainBackground(Buffer.from(data), info.width, info.height, bgTolerance);
    image = sharp(cleaned, { raw: { width: info.width, height: info.height, channels: 4 } });
  }
  return image.png({ compressionLevel: 9 }).toBuffer();
}

async function prepareReferenceRgba(absPath, size_) {
  const buf = await readFile(absPath);
  return sharp(buf).ensureAlpha().resize(size_, size_, { kernel: "nearest" }).raw().toBuffer({ resolveWithObject: true });
}

/** Vanilla atlas padding is usually near-black; keep it exact so UV holes stay valid. */
function isPaddingPixel(r, g, b, a) {
  if (a < 12) return true;
  return r < 14 && g < 14 && b < 14;
}

/**
 * Keep vanilla atlas padding/holes (transparent / near-black in reference) so UV layout stays valid;
 * does not blend visible skin pixels with vanilla.
 */
function snapEntityPaddingToReference(genRgba, refRgba, width, height) {
  const n = width * height;
  const out = Buffer.from(genRgba);
  for (let i = 0; i < n; i++) {
    const o = i * 4;
    const r0 = refRgba[o];
    const g0 = refRgba[o + 1];
    const b0 = refRgba[o + 2];
    const a0 = refRgba[o + 3];
    if (isPaddingPixel(r0, g0, b0, a0)) {
      out[o] = r0;
      out[o + 1] = g0;
      out[o + 2] = b0;
      out[o + 3] = a0;
    }
  }
  return out;
}

async function applyEntityPaddingFromReference(genPngBytes, referencePath, size_) {
  const genImg = sharp(genPngBytes).ensureAlpha().resize(size_, size_, { kernel: "nearest" });
  const { data: genData, info } = await genImg.raw().toBuffer({ resolveWithObject: true });
  if (info.width !== size_ || info.height !== size_) throw new Error("entity padding snap size mismatch");
  const { data: refData, info: refInfo } = await prepareReferenceRgba(referencePath, size_);
  if (refInfo.width !== size_ || refInfo.height !== size_) throw new Error("reference padding snap size mismatch");
  const snapped = snapEntityPaddingToReference(genData, refData, size_, size_);
  return sharp(snapped, { raw: { width: size_, height: size_, channels: 4 } }).png({ compressionLevel: 9 }).toBuffer();
}

/**
 * Per-pixel: padding -> vanilla; else out = gen * t + ref * (1-t). t = weight of model output (0..1).
 */
function blendEntityAtlas(genRgba, refRgba, width, height, genWeight) {
  const t = Math.min(1, Math.max(0, genWeight));
  const n = width * height;
  const out = Buffer.alloc(genRgba.length);
  for (let i = 0; i < n; i++) {
    const o = i * 4;
    const r0 = refRgba[o];
    const g0 = refRgba[o + 1];
    const b0 = refRgba[o + 2];
    const a0 = refRgba[o + 3];
    if (isPaddingPixel(r0, g0, b0, a0)) {
      out[o] = r0;
      out[o + 1] = g0;
      out[o + 2] = b0;
      out[o + 3] = a0;
      continue;
    }
    const r1 = genRgba[o];
    const g1 = genRgba[o + 1];
    const b1 = genRgba[o + 2];
    const a1 = genRgba[o + 3];
    out[o] = Math.round(r1 * t + r0 * (1 - t));
    out[o + 1] = Math.round(g1 * t + g0 * (1 - t));
    out[o + 2] = Math.round(b1 * t + b0 * (1 - t));
    out[o + 3] = Math.round(a1 * t + a0 * (1 - t));
  }
  return out;
}

async function postprocessEntityWithReferenceLayout(pngBytes, referencePath, size_, entityLayoutBlend) {
  const genImg = sharp(pngBytes).ensureAlpha().resize(size_, size_, { kernel: "nearest" });
  const { data: genData, info } = await genImg.raw().toBuffer({ resolveWithObject: true });
  if (info.width !== size_ || info.height !== size_) throw new Error("entity blend size mismatch");
  const { data: refData, info: refInfo } = await prepareReferenceRgba(referencePath, size_);
  if (refInfo.width !== size_ || refInfo.height !== size_) throw new Error("reference blend size mismatch");
  const blended = blendEntityAtlas(genData, refData, size_, size_, entityLayoutBlend);
  return sharp(blended, { raw: { width: size_, height: size_, channels: 4 } }).png({ compressionLevel: 9 }).toBuffer();
}

/** Java mob atlases often use 8-bit palette PNG; RGBA can render wrong (e.g. black head) on some setups. */
async function encodeEntityTexturePng(pngBuffer) {
  return sharp(pngBuffer).png({ palette: true, colours: 256, compressionLevel: 9 }).toBuffer();
}

/** Resize reference to model input square; rd-fast expects RGB-ish input. */
async function prepareReferenceImageBuffer(absPath, side) {
  const buf = await readFile(absPath);
  return sharp(buf).ensureAlpha().resize(side, side, { kernel: "nearest" }).png().toBuffer();
}

function supportsRdFastImg2Img(model) {
  return model === RD_FAST_MODEL || String(model).endsWith("/rd-fast");
}

async function writePreview(finalPng, previewPath, scale) {
  if (scale <= 0) return;
  const metadata = await sharp(finalPng).metadata();
  await sharp(finalPng)
    .resize((metadata.width || 16) * scale, (metadata.height || 16) * scale, { kernel: "nearest" })
    .png({ compressionLevel: 9 })
    .toFile(previewPath);
}

function parseJsonObject(text, label) {
  const value = JSON.parse(text);
  if (!value || Array.isArray(value) || typeof value !== "object") throw new Error(`${label} must be a JSON object`);
  return value;
}

const { values } = parseArgs({
  options: {
    type: { type: "string" },
    subject: { type: "string" },
    prompt: { type: "string" },
    size: { type: "string", default: "32" },
    "output-dir": { type: "string", default: "." },
    name: { type: "string" },
    model: { type: "string" },
    count: { type: "string", default: "1" },
    seed: { type: "string" },
    "input-json": { type: "string", default: "{}" },
    "transparent-bg": { type: "boolean", default: false },
    "bg-tolerance": { type: "string", default: "24" },
    "keep-raw": { type: "boolean", default: false },
    "preview-scale": { type: "string", default: "8" },
    style: { type: "string" },
    "no-tile": { type: "boolean", default: false },
    "bypass-prompt-expansion": { type: "boolean", default: false },
    "reference-image": { type: "string" },
    "img2img-strength": { type: "string" },
    "entity-layout-blend": { type: "string" }
  }
});

if (!["item", "block", "entity"].includes(values.type || "")) {
  throw new Error("--type must be item, block, or entity");
}
if (!values.subject) throw new Error("--subject is required");
if (!process.env.REPLICATE_API_TOKEN) throw new Error("Missing REPLICATE_API_TOKEN environment variable.");

const size = Number.parseInt(values.size, 10);
const count = Number.parseInt(values.count, 10);
const seed = values.seed === undefined ? undefined : Number.parseInt(values.seed, 10);
const bgTolerance = Number.parseInt(values["bg-tolerance"], 10);
const previewScale = Number.parseInt(values["preview-scale"], 10);
const style = selectStyle(values.type, values.subject, values.style);
const extraInput = parseJsonObject(values["input-json"], "--input-json");

let referencePath = values["reference-image"] ? path.resolve(values["reference-image"]) : null;
if (referencePath && !existsSync(referencePath)) {
  throw new Error(`--reference-image not found: ${referencePath}`);
}

const hasReferenceImage = Boolean(referencePath);
const prompt = buildPrompt(values.type, values.subject, values.prompt, style);
const modelHandlesTransparency = style === "mc_item";

values.model = values.model || process.env.REPLICATE_MODEL || RD_FAST_MODEL;

const tileable = computeTileable({
  assetType: values.type,
  subject: values.subject,
  style,
  noTileFlag: values["no-tile"],
  hasReferenceImage
});

// rd-fast width/height range is 16..384. For mob atlases, render at 2× target side then nearest-neighbor downscale so pixel steps snap cleaner to the in-game grid (final PNG size is still `size`).
const requestedSide =
  values.type === "entity"
    ? Math.max(16, Math.min(384, Math.max(size * 2, size)))
    : Math.max(16, Math.min(384, size));

const modelInput = {
  prompt,
  style,
  width: requestedSide,
  height: requestedSide,
  num_images: count,
  tile_x: tileable,
  tile_y: tileable,
  remove_bg: Boolean(values["transparent-bg"]) && modelHandlesTransparency,
  bypass_prompt_expansion: Boolean(values["bypass-prompt-expansion"]),
  ...extraInput
};
if (seed !== undefined) modelInput.seed = seed;

/** rd-fast OpenAPI: input_image + strength 0..1. Official default_example uses strength 0.9; schema default is 0.8.
 *  Values below ~0.55 heavily preserve the reference — fine for blocks, too weak for mob retextures where the reference IS vanilla. */
const img2imgStrength =
  values["img2img-strength"] !== undefined
    ? Number.parseFloat(values["img2img-strength"])
    : values.type === "entity" && hasReferenceImage
      ? Number.parseFloat(process.env.REPLICATE_IMG2IMG_STRENGTH || "0.78")
      : Number.parseFloat(process.env.REPLICATE_IMG2IMG_STRENGTH || "0.28");

/** After img2img, blend model onto vanilla for UV-used pixels; padding stays vanilla. */
let entityLayoutBlend = NaN;
if (values["entity-layout-blend"] !== undefined) {
  entityLayoutBlend = Number.parseFloat(values["entity-layout-blend"]);
} else if (process.env.REPLICATE_ENTITY_LAYOUT_BLEND !== undefined && process.env.REPLICATE_ENTITY_LAYOUT_BLEND !== "") {
  entityLayoutBlend = Number.parseFloat(process.env.REPLICATE_ENTITY_LAYOUT_BLEND);
} else if (values.type === "entity" && hasReferenceImage) {
  entityLayoutBlend = 1;
}

if (hasReferenceImage && supportsRdFastImg2Img(values.model)) {
  const refBuf = await prepareReferenceImageBuffer(referencePath, requestedSide);
  modelInput.input_image = `data:image/png;base64,${refBuf.toString("base64")}`;
  if (modelInput.strength === undefined) {
    modelInput.strength = Math.min(1, Math.max(0, img2imgStrength));
  }
} else if (hasReferenceImage && !supportsRdFastImg2Img(values.model)) {
  console.warn(
    `[generate_texture] --reference-image ignored: model "${values.model}" is not retro-diffusion/rd-fast (no known input_image schema).`
  );
}

// Never tile mob atlases or ref-based generations; extraInput cannot re-enable
if (!tileable || hasReferenceImage || values.type === "entity") {
  modelInput.tile_x = false;
  modelInput.tile_y = false;
}

const outputDir = path.resolve(values["output-dir"]);
await mkdir(outputDir, { recursive: true });
const base = slugify(values.name || values.subject);
const stamp = new Date().toISOString().replace(/[-:]/g, "").replace(/\.\d{3}Z$/, "Z");
const replicate = new Replicate({ auth: process.env.REPLICATE_API_TOKEN });
const output = await replicate.run(values.model, { input: modelInput });
const saved = [];

let index = 0;
for (const oneOutput of normalizeOutputs(output)) {
  index += 1;
  const suffix = count === 1 ? "" : `_${String(index).padStart(2, "0")}`;
  const finalPath = path.join(outputDir, `${base}${suffix}.png`);
  const rawPath = path.join(outputDir, `${base}${suffix}.raw.png`);
  const previewPath = path.join(outputDir, `${base}${suffix}.preview.png`);
  const metadataPath = path.join(outputDir, `${base}${suffix}.json`);
  const rawBytes = await readOutputBytes(oneOutput);
  if (values["keep-raw"]) await writeFile(rawPath, rawBytes);
  let finalBytes = await postprocessPng(rawBytes, size, values["transparent-bg"], bgTolerance, modelHandlesTransparency);
  const blendEntityLayout =
    values.type === "entity" &&
    referencePath &&
    !Number.isNaN(entityLayoutBlend) &&
    entityLayoutBlend > 0 &&
    entityLayoutBlend < 1;
  if (blendEntityLayout) {
    finalBytes = await postprocessEntityWithReferenceLayout(finalBytes, referencePath, size, entityLayoutBlend);
  } else if (values.type === "entity" && referencePath) {
    finalBytes = await applyEntityPaddingFromReference(finalBytes, referencePath, size);
  }
  if (values.type === "entity") {
    finalBytes = await encodeEntityTexturePng(finalBytes);
  }
  await writeFile(finalPath, finalBytes);
  await writePreview(finalPath, previewPath, previewScale);
  const metadata = {
    created_at_utc: stamp,
    type: values.type,
    subject: values.subject,
    model: values.model,
    style,
    tileable: Boolean(modelInput.tile_x && modelInput.tile_y),
    prompt,
    size,
    seed,
    reference_image: referencePath,
    img2img: Boolean(modelInput.input_image),
    entity_layout_blend:
      values.type === "entity" && referencePath && !Number.isNaN(entityLayoutBlend) ? entityLayoutBlend : undefined,
    input: { ...modelInput, input_image: modelInput.input_image ? "[data:uri omitted]" : undefined },
    final_png: finalPath,
    preview_png: previewScale > 0 && existsSync(previewPath) ? previewPath : null,
    raw_png: values["keep-raw"] ? rawPath : null
  };
  await writeFile(metadataPath, `${JSON.stringify(metadata, null, 2)}\n`);
  saved.push({ png: finalPath, metadata: metadataPath });
}

console.log(JSON.stringify({ saved }, null, 2));
