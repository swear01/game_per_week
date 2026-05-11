---
name: minecraft-resource-pack-builder
description: Build complete Minecraft Java Edition resource packs from specs or existing mod/resource assets. Use when Codex needs to create pack.mcmeta, resolve version-aware resource pack format from Mojang client metadata, generate or import textures with minecraft-texture-replicate, generate OGG sounds with minecraft-sound-effects and ElevenLabs, write models/blockstates/lang/sounds.json under an assets namespace, validate pack layout, zip the pack with pack.mcmeta at the archive root, or prepare visual/audio resource overrides for vanilla Minecraft or a mod.
---

# Minecraft Resource Pack Builder

## Role In The Pipeline

Use this for resource packs, not gameplay mods. A resource pack can change visuals, models, language, fonts, sounds, particles, shaders, and other client resources. It cannot add new item/block registries by itself.

This skill coordinates:

- `minecraft-vanilla-harness` for target version metadata and vanilla asset paths
- `minecraft-texture-replicate` for item/block/**entity (mob atlas)** PNGs—`entity/` overrides use **`--type entity`**, auto-resolved vanilla **`--reference-image`** + **`retro-diffusion/rd-fast` img2img** when `minecraft_version` and namespace `minecraft` are set; generated **entity** PNGs are written as **8-bit palette** (vanilla-style) to reduce in-game rendering issues
- `minecraft-modeling` for non-default model JSON or Blockbench work
- `minecraft-sound-effects` for ElevenLabs-generated OGG sounds and `sounds.json`

## Workflow

1. Decide whether the pack overrides vanilla assets or targets a mod namespace.
   - Vanilla override namespace: `minecraft`
   - Mod/custom namespace: usually `mod_id`
2. Build the pack folder with `scripts/build_resource_pack.py`.
3. Generate textures unless the user asked to use existing assets.
4. Generate sounds through `minecraft-sound-effects` if `sounds[]` is present.
5. Validate the folder structure and create a zip.
6. Return the folder, zip, and `.minecraft-resource-pack-report.json`.

## Dependency And Service Policy

- Follow the declared resource-pack pipeline first. Do not replace it with an ad hoc local generator just to avoid Replicate, ElevenLabs, Mojang metadata, or other external services.
- If a required API key is expected but not visible in the current shell, check the environment before choosing a fallback. If the key is still missing, report the missing variable and stop unless the user explicitly asked to skip that stage.
- If npm packages required by the texture pipeline are missing, run `npm install --prefix skills/minecraft-texture-replicate/runtime` and rerun the Node script. Do not install texture dependencies into the workspace root. The Replicate texture stage is npm/Node-only.
- If a Python package required by a non-texture pipeline script is missing, install it into a repo-local virtual environment such as `.venv/` and rerun that Python script with `.venv/bin/python`. Do not use Homebrew/system Python package writes when the environment is externally managed.
- If an external service call fails after credentials and dependencies are present, report the provider, request/stage, and error. Only use a non-service fallback after explaining the failure or when the user asks for one.
- If a pipeline script exposes an environment-specific tool assumption, fix the shared script or skill instructions when practical instead of creating a one-off project tool.

## Commands

Build a resource pack from a spec:

```bash
python3 skills/minecraft-resource-pack-builder/scripts/build_resource_pack.py \
  --spec resource-pack-spec.json \
  --output ./CopperChimePack \
  --zip
```

Use existing textures/sounds only:

```bash
python3 skills/minecraft-resource-pack-builder/scripts/build_resource_pack.py \
  --spec resource-pack-spec.json \
  --output ./CopperChimePack \
  --skip-textures \
  --skip-sounds \
  --zip
```

Do **not** combine `--skip-textures` with a spec that has **`texture_overrides`** and `--force`: the output folder is wiped first, so you end up with almost no `assets/minecraft/textures/…` and the game keeps vanilla textures. The script now **refuses** that combination.

Copy the finished pack (folder + zip when `--zip`) into a game `resourcepacks` directory or repo staging folder:

```bash
python3 skills/minecraft-resource-pack-builder/scripts/build_resource_pack.py \
  --spec resource-pack-spec.json \
  --output ./CopperChimePack \
  --zip \
  --copy-to resources/resourcepacks
```

Or set **`RESOURCE_PACK_COPY_TO`** to that path so you do not need the flag each time. Relative `--copy-to` paths are resolved from the **repository root** (parent of `skills/`).

**Hot reload (no Minecraft restart):** In a **loaded world**, press **F3+T** to reload resource packs and textures (short freeze). On the **main menu**, F3+T does not apply; open **Options → Resource Packs → Done** or re-enter a world. Using an **unpacked folder** under `resourcepacks` (not only a zip) makes iteration easier when editing files on disk.

## Spec Shape

Use the existing `mod-spec.json` shape when building assets for a mod namespace. For vanilla overrides, add `resource_pack.namespace: "minecraft"` and set `target_id` or `vanilla_reference` per entry:

```json
{
  "display_name": "Copper UI Pack",
  "minecraft_version": "26.1.2",
  "resource_pack": {
    "namespace": "minecraft",
    "description": "Copper themed vanilla overrides"
  },
  "items": [
    {
      "id": "saddle",
      "target_id": "minecraft:saddle",
      "display_name": "Copper Saddle",
      "texture_prompt": "single centered copper-trimmed saddle Minecraft item texture"
    }
  ],
  "sounds": [
    {
      "id": "item.armor.equip_leather",
      "file": "item/copper_saddle_equip",
      "prompt": "short soft leather strap sound with tiny copper buckle jingle, no music"
    }
  ]
}
```

For raw vanilla texture overrides that should not emit replacement model JSON, use `texture_overrides[]`:

```json
{
  "texture_overrides": [
    {
      "target": "block/melon_side",
      "type": "block",
      "texture_prompt": "seamless Minecraft vanilla block texture, cantaloupe netted tan rind"
    },
    {
      "target": "entity/zombie/zombie",
      "type": "entity",
      "texture_size": 64,
      "img2img_strength": 0.86,
      "texture_prompt": "three-eyed mushroom zombie, red cap, muted teal shirt"
    }
  ]
}
```

`target` is relative to `assets/<namespace>/textures/` and may include or omit `.png`. Paths under `entity/` default to **`type`: `entity`** unless overridden. For namespace **`minecraft`**, the builder resolves the vanilla PNG for **`minecraft_version`** and passes it as the img2img reference (optional **`reference_image`** path relative to the spec file overrides this). Optional **`img2img_strength`** (0–1, `retro-diffusion/rd-fast`): **higher** follows the **prompt** more; **lower** keeps **`input_image`**. When the reference **is** vanilla, use roughly **0.75–0.95** for strong retextures (values **~0.5 and below** often look almost vanilla). Optional **`bypass_prompt_expansion`**: **`true`** passes **`--bypass-prompt-expansion`** so the model rewrites your prompt less (useful for exact motifs). Optional **`entity_layout_blend`**: omit or **1** for no vanilla color mix on skin pixels.

## Output Contract

- `<output>/pack.mcmeta`
- `<output>/pack.png` (auto-generated via Replicate unless `--skip-pack-icon`, or copied from `resource_pack.icon` if provided)
- `<output>/assets/<namespace>/textures/...`
- `<output>/assets/<namespace>/models/...` when models are generated
- `<output>/assets/<namespace>/blockstates/...` for block model overrides
- `<output>/assets/<namespace>/lang/en_us.json` when display/subtitle names are present
- `<output>/assets/<namespace>/sounds.json` and `sounds/**/*.ogg` when sounds are present
- `<output>/.minecraft-resource-pack-report.json`
- optional `<output>.zip`

## Failure Policy

- If the pack tries to add new gameplay content without a mod/datapack, stop and explain that resource packs cannot add registries.
- If `REPLICATE_API_TOKEN` is missing and textures are requested, check the environment and then fail unless `--skip-textures` is passed or the user explicitly approves a fallback.
- The pack thumbnail (`pack.png`) is generated through `minecraft-texture-replicate` from `resource_pack.icon_prompt` (or a prompt derived from `display_name` when absent). Provide `resource_pack.icon` with a local PNG path to bypass Replicate, or pass `--skip-pack-icon` to omit the thumbnail.
- If `ELEVENLABS_API_KEY` is missing and sounds are requested, check the environment and then fail unless `--skip-sounds` is passed or the user explicitly approves a fallback.
- If `ffmpeg` is missing, sound generation cannot produce Minecraft-ready OGG.
- If pack format cannot be resolved from the target version, require `--pack-format`.

## References

- `references/resource-pack-layout.md`: Java resource pack structure and pack format handling.
- `references/spec.md`: resource-pack spec fields.
