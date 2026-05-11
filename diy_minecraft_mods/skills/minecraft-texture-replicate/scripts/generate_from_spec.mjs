#!/usr/bin/env node
import { parseArgs } from "node:util";
import { readFile, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

function loadSpec(file) {
  return JSON.parse(file);
}

function run(cmd, args) {
  console.log(`+ ${[cmd, ...args].join(" ")}`);
  return spawnSync(cmd, args, { stdio: "inherit", env: process.env }).status ?? 1;
}

function targetPath(entry, defaultNamespace) {
  const raw = String(entry.target_id || entry.vanilla_reference || entry.id);
  if (raw.includes(":")) {
    const [namespace, id] = raw.split(":", 2);
    return [namespace, id];
  }
  return [defaultNamespace, raw];
}

async function generateOne(script, assetType, subject, outputDir, name, size, transparent, model, inputJson, skipExisting) {
  const finalPng = path.join(outputDir, `${name}.png`);
  if (skipExisting && existsSync(finalPng)) {
    return { type: assetType, id: name, status: "skipped_existing", png: finalPng };
  }
  const args = [
    script,
    "--type", assetType,
    "--subject", subject,
    "--size", String(size),
    "--output-dir", outputDir,
    "--name", name
  ];
  if (transparent) args.push("--transparent-bg");
  if (model) args.push("--model", model);
  if (inputJson) args.push("--input-json", inputJson);
  const code = run("node", args);
  return { type: assetType, id: name, status: code === 0 ? "ok" : "failed", exit_code: code, png: finalPng };
}

const { values } = parseArgs({
  options: {
    spec: { type: "string" },
    project: { type: "string" },
    "texture-size": { type: "string" },
    model: { type: "string", default: process.env.REPLICATE_MODEL },
    "input-json": { type: "string" },
    "skip-existing": { type: "boolean", default: false },
    report: { type: "string" },
    namespace: { type: "string" },
    "assets-root": { type: "string" }
  }
});

if (!process.env.REPLICATE_API_TOKEN) throw new Error("REPLICATE_API_TOKEN is required for texture generation.");
if (!values.spec) throw new Error("--spec is required.");

const specPath = path.resolve(values.spec);
const spec = loadSpec(await readFile(specPath, "utf8"));
const size = Number.parseInt(values["texture-size"] || spec.texture_size || "32", 10);
const script = path.resolve(path.dirname(new URL(import.meta.url).pathname), "generate_texture.mjs");
const results = [];

if (values["assets-root"]) {
  const defaultNamespace = values.namespace || spec.resource_pack?.namespace || spec.namespace || spec.mod_id || "minecraft";
  const assetsRoot = path.resolve(values["assets-root"]);
  for (const item of spec.items || []) {
    const [namespace, id] = targetPath(item, defaultNamespace);
    const subject = String(item.texture_prompt || item.display_name || item.id);
    results.push(await generateOne(script, "item", subject, path.join(assetsRoot, namespace, "textures", "item"), id, size, item.transparent_texture !== false, values.model, values["input-json"], values["skip-existing"]));
  }
  for (const block of spec.blocks || []) {
    const [namespace, id] = targetPath(block, defaultNamespace);
    const subject = String(block.texture_prompt || block.display_name || block.id);
    results.push(await generateOne(script, "block", subject, path.join(assetsRoot, namespace, "textures", "block"), id, size, false, values.model, values["input-json"], values["skip-existing"]));
  }
  const reportPath = path.resolve(values.report || path.join(path.dirname(assetsRoot), ".minecraft-textures.json"));
  await writeFile(reportPath, `${JSON.stringify({ spec: specPath, assets_root: assetsRoot, results }, null, 2)}\n`);
  console.log(JSON.stringify({ report: reportPath, results }, null, 2));
} else {
  if (!values.project) throw new Error("--project is required unless --assets-root is used.");
  const project = path.resolve(values.project);
  const modId = String(spec.mod_id);
  const assets = path.join(project, "src", "main", "resources", "assets", modId);
  for (const item of spec.items || []) {
    const subject = String(item.texture_prompt || item.display_name || item.id);
    results.push(await generateOne(script, "item", subject, path.join(assets, "textures", "item"), String(item.id), size, item.transparent_texture !== false, values.model, values["input-json"], values["skip-existing"]));
  }
  for (const block of spec.blocks || []) {
    const subject = String(block.texture_prompt || block.display_name || block.id);
    results.push(await generateOne(script, "block", subject, path.join(assets, "textures", "block"), String(block.id), size, false, values.model, values["input-json"], values["skip-existing"]));
  }
  const reportPath = path.resolve(values.report || path.join(project, ".minecraft-textures.json"));
  await writeFile(reportPath, `${JSON.stringify({ spec: specPath, project, results }, null, 2)}\n`);
  console.log(JSON.stringify({ report: reportPath, results }, null, 2));
}

process.exit(results.some((result) => result.status === "failed") ? 1 : 0);
