---
name: minecraft-texture-replicate
description: Generate Minecraft-style item, block, and entity (UV atlas) textures with Replicate—default `retro-diffusion/rd-fast` with optional img2img via `input_image`+`strength`, vanilla PNG resolution for resource packs, and post-processing to game-ready PNGs. Use for sprites, tiles, mob skin atlases, seamless block faces, transparent items, and metadata sidecars.
---

# Minecraft Texture Replicate

## Role In The Pipeline

This is phase 3. Consume `mod-spec.json` plus a scaffolded project and generate PNG files for every declared item/block texture prompt.

Primary pipeline command:

```bash
node skills/minecraft-texture-replicate/scripts/generate_from_spec.mjs \
  --spec mod-spec.json \
  --project ./Copperworks \
  --skip-existing
```

This writes `<project>/.minecraft-textures.json` for `minecraft-mod-builder` and `minecraft-modding`.

## Workflow

1. Clarify the asset target when missing: `item`, `block`, or `entity` (mob/UV atlas), subject/name, resolution, and output folder.
2. For full mod automation, prefer `scripts/generate_from_spec.mjs`.
3. For one-off assets, use `scripts/generate_texture.mjs`. It calls Replicate through the official npm package, saves the remote output immediately, post-processes it to a Minecraft texture PNG, and writes metadata next to the image.
4. Use Replicate model OpenAPI when model inputs are uncertain. For **`retro-diffusion/rd-fast`**, **`strength`**: higher ≈ more prompt; lower ≈ more **`input_image`** preserved—when that image **is** vanilla, use **~0.75+** for mob skins or they look unchanged. Read `references/replicate.md`, `references/minecraft-textures.md`, and `references/entity-mob-atlas.md`.
5. Iterate visually. AI output often needs 2-5 prompt/seed attempts before it reads well at 16x16.

## Dependency And Service Policy

- Use Replicate for requested texture generation when `REPLICATE_API_TOKEN` is available. Do not switch to hand-authored or procedural textures just to avoid the external call.
- Use the official npm `replicate` client as the only Replicate implementation for this skill. Do not add or keep a Python Replicate fallback.
- If npm packages are missing, install them inside `skills/minecraft-texture-replicate/runtime/` with `npm install --prefix skills/minecraft-texture-replicate/runtime`. Do not create `node_modules`, `package.json`, or lockfiles at the workspace root for this skill.
- If the token is missing after checking the environment, report `REPLICATE_API_TOKEN` as missing and stop unless the user explicitly asked to skip generation.
- If Replicate rejects the request, times out, or returns unusable output, report the exact stage/error and then decide whether to retry with a different prompt/model or ask the user for fallback approval.
- Save remote outputs immediately; Replicate file URLs can be temporary.

## Quick Start

Require a Replicate API token:

```bash
export REPLICATE_API_TOKEN="..."
```

Install npm dependencies if needed:

```bash
npm install --prefix skills/minecraft-texture-replicate/runtime
node skills/minecraft-texture-replicate/scripts/generate_texture.mjs \
  --type item \
  --subject "copper wrench" \
  --size 32 \
  --output-dir ./textures/item \
  --transparent-bg
```

Generate an item texture:

```bash
node skills/minecraft-texture-replicate/scripts/generate_texture.mjs \
  --type item \
  --subject "copper wrench" \
  --size 32 \
  --output-dir ./textures/item \
  --transparent-bg
```

Generate a block texture:

```bash
node skills/minecraft-texture-replicate/scripts/generate_texture.mjs \
  --type block \
  --subject "polished limestone bricks with moss in the cracks" \
  --size 32 \
  --output-dir ./textures/block
```

Entity / mob atlas (UV skin layout)—with vanilla PNG as img2img reference:

```bash
V=$(python3 skills/minecraft-texture-replicate/scripts/resolve_vanilla_texture.py \
  --version 1.21.1 --texture-rel entity/zombie/zombie)
node skills/minecraft-texture-replicate/scripts/generate_texture.mjs \
  --type entity \
  --subject zombie \
  --size 64 \
  --reference-image "$V" \
  --img2img-strength 0.82 \
  --output-dir ./textures/entity/zombie \
  --name zombie \
  --prompt "three-eyed mushroom zombie, teal shirt, purple pants, red mushroom cap"
```

Use a different Replicate model:

```bash
REPLICATE_MODEL="retro-diffusion/rd-plus" node skills/minecraft-texture-replicate/scripts/generate_texture.mjs \
  --type item \
  --subject "ruby pickaxe" \
  --size 32
```

Pass model-specific inputs when the selected model supports them:

```bash
node skills/minecraft-texture-replicate/scripts/generate_texture.mjs \
  --type block \
  --subject "glowing blue crystal ore" \
  --input-json '{"num_inference_steps": 4, "output_format": "png"}'
```

Generate all textures declared by a spec:

```bash
node skills/minecraft-texture-replicate/scripts/generate_from_spec.mjs \
  --spec mod-spec.json \
  --project ./Copperworks
```

## Prompt Rules

For items:

- Ask for one centered object, square icon composition, Minecraft pixel-art item texture.
- Prefer a plain or transparent background; remove background during post-processing only when it is visually simple.
- Avoid text, UI frames, dramatic shadows, hands, characters, inventories, and scene backgrounds.

For blocks:

- Ask for a flat square tile, top-down/front-on texture, seamless/repeating material.
- Emphasize readable material pattern at the requested small size.
- Avoid perspective, lighting gradients, placed blocks in a 3D scene, labels, and borders.

For `entity` (mob atlas):

- Prompts describe **per-region** colors and theme; the script appends UV-atlas guardrails (no full-body poster art).
- **Never** enable seamless tiling for entity atlases. With `--reference-image`, Replicate gets **img2img** on `retro-diffusion/rd-fast` only; other models log a warning and skip the image.
- Optional env **`REPLICATE_IMG2IMG_STRENGTH`**: for **`--type entity`** with **`--reference-image`**, default is **~0.78** when unset (blocks/items still default ~0.28). **`entity_layout_blend`**: omit or **`1`** = no vanilla color mix (default); roughly **0.55 and below** for **`strength`** mostly preserves the vanilla atlas.

## Output Rules

- **`--type entity`**: After img2img / layout blend, the script re-encodes the final PNG as an **8-bit palette** (up to 256 colors) so it matches typical vanilla mob atlases. Full RGBA entity PNGs from prior pipelines have been observed to render incorrectly in-game (e.g. an all-black head) on some clients; palette output avoids that. Item and block outputs stay **RGBA** unless you change the script.
- Save final textures as PNG in the requested resource-pack path, usually `assets/<namespace>/textures/item/`, `.../block/`, or `.../entity/...`.
- In full mod automation, save final textures under `<project>/src/main/resources/assets/<modid>/textures/...`.
- Keep a metadata JSON file next to each texture with model, prompt, seed, input settings, and source output path.
- Keep the batch report at `<project>/.minecraft-textures.json`.
- Inspect the final PNG at native resolution and scaled up with nearest-neighbor preview before considering it done.
- If the texture is for a Minecraft mod, use lowercase snake_case filenames.

## Resources

- `scripts/generate_texture.mjs`: Replicate generation and PNG post-processing utility.
- `scripts/resolve_vanilla_texture.py`: cache vanilla `textures/...` PNGs for a Java version (GitHub minecraft-assets + jar fallback).
- `references/entity-mob-atlas.md`: mob UV atlas rules and img2img defaults.
- `scripts/generate_from_spec.mjs`: Batch generation from `mod-spec.json` into a scaffolded mod project.
- `references/replicate.md`: Replicate API notes and common failure handling.
- `references/minecraft-textures.md`: Texture prompt recipes and validation checklist.
