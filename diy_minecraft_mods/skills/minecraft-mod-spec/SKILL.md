---
name: minecraft-mod-spec
description: Convert Minecraft mod ideas into structured mod-spec files for automated mod creation. Use when Codex needs to plan a complete Java Edition mod before implementation, including mod id, loader, Minecraft version, package name, items, blocks, recipes, loot tables, tags, creative tab placement, texture prompts, generation settings, and validation for downstream minecraft-mod-scaffold and minecraft-mod-builder workflows.
---

# Minecraft Mod Spec

## Role In The Pipeline

This is phase 1. Convert the user's idea into `mod-spec.json`, the single source of truth consumed by `minecraft-mod-builder`, `minecraft-vanilla-harness`, `minecraft-mod-scaffold`, `minecraft-texture-replicate`, `minecraft-sound-effects`, and `minecraft-modding`.

Prefer JSON for machine reliability; YAML is acceptable only when the downstream script can parse it.

## Workflow

1. Turn the idea into concrete objects: items, blocks, tools, foods, ores, recipes, loot behavior, and texture prompts.
2. Choose `loader`: `fabric`, `neoforge`, or `architectury`. If not specified, default to `fabric` for the first working prototype.
3. Choose a Minecraft version. If not specified, use the latest stable version supported by the selected template after checking current official/template sources.
4. Write `mod-spec.json`.
5. Run `scripts/validate_spec.py mod-spec.json`.
6. Run `../minecraft-vanilla-harness` to check whether ids or display names already exist in the target vanilla Minecraft version.
7. Hand the validated and vanilla-checked spec to `../minecraft-mod-builder` for the complete pipeline, or `../minecraft-mod-scaffold` for scaffold-only work.

## Output Contract

`mod-spec.json` must contain enough information for every later phase:

- Scaffold phase: `mod_id`, `display_name`, `loader`, `minecraft_version`, `package`.
- Texture phase: `texture_size`, `items[].texture_prompt`, `blocks[].texture_prompt`, `transparent_texture`.
- Sound phase: optional `sounds[].id`, `sounds[].file`, `sounds[].prompt`, and subtitle metadata.
- Modeling phase: optional `items[].model` and `blocks[].model`, used only for non-default shapes.
- Modding phase: item/block ids, display names, types, hardness/material hints, recipes, loot behavior, tags, and creative tab intent.

## Required Fields

- `mod_id`: lowercase id, e.g. `copperworks`
- `display_name`: user-facing mod name
- `loader`: `fabric`, `neoforge`, or `architectury`
- `minecraft_version`: exact target version, e.g. `1.21.8`
- `package`: Java package, e.g. `com.example.copperworks`
- `items`: array, may be empty
- `blocks`: array, may be empty

## Vanilla Awareness

Before building, check the spec against the target version:

```bash
python3 skills/minecraft-vanilla-harness/scripts/check_spec_against_vanilla.py \
  --spec mod-spec.json
```

If the check finds an exact vanilla id or display name, revise the concept so it adds something new. If the user intentionally wants to overlap with vanilla, mark that entry explicitly:

```json
{
  "id": "reinforced_saddle",
  "display_name": "Reinforced Saddle",
  "allow_vanilla_overlap": true,
  "vanilla_reference": "minecraft:saddle"
}
```

## Object Fields

For each item:

- `id`: lowercase snake_case registry id
- `display_name`
- `type`: `basic`, `tool`, `food`, or custom text
- `texture_prompt`
- `transparent_texture`: usually `true`
- `recipe`: optional object
- `model`: optional object; omit for normal generated/handheld item models
- `allow_vanilla_overlap`: optional boolean; use only for intentional overlap with vanilla content
- `vanilla_reference`: optional string, e.g. `minecraft:saddle`, when extending a vanilla concept

For each block:

- `id`
- `display_name`
- `type`: `basic`, `ore`, `decorative`, or custom text
- `material_hint`: e.g. `stone`, `metal`, `wood`
- `hardness`: optional number
- `requires_tool`: optional boolean
- `texture_prompt`
- `recipe`: optional object
- `loot`: optional object
- `model`: optional object; omit for normal `cube_all` blocks
- `allow_vanilla_overlap`: optional boolean; use only for intentional overlap with vanilla content
- `vanilla_reference`: optional string, e.g. `minecraft:stone`, when extending a vanilla concept

Optional project-level fields:

- `description`
- `authors`
- `license`
- `texture_size`
- `creative_tab`
- `template_url`
- `sounds`: optional array of ElevenLabs-generated sound events for mods/resource packs

For each sound:

- `id`: sound event key, e.g. `block.copper_chime.ring`
- `file`: path under `assets/<namespace>/sounds` without `.ogg`
- `prompt`: ElevenLabs sound effect prompt
- `subtitle`: optional user-facing subtitle text
- `duration_seconds`: optional number
- `prompt_influence`: optional number

## Modeling Rule

Only declare `model` when the asset is not a default Minecraft shape.

Default cases do not need `model`:

- normal item icon: `minecraft:item/generated`
- handheld tool: `minecraft:item/handheld`
- simple cube block: `minecraft:block/cube_all`

Non-default cases should include `model.kind`, for example `java_elements`, `custom_block`, `custom_item`, `blockbench`, `geckolib`, or `entity`.

## Quick Start

Create a starter spec:

```bash
python3 skills/minecraft-mod-spec/scripts/create_spec.py \
  --mod-id copperworks \
  --display-name "Copperworks" \
  --loader fabric \
  --minecraft-version 1.21.8 \
  --package com.example.copperworks \
  --item copper_wrench:"Copper Wrench":"a copper wrench tool with worn metal handle" \
  --block polished_limestone:"Polished Limestone":"polished limestone brick block with subtle moss in cracks" \
  --output mod-spec.json
```

Validate:

```bash
python3 skills/minecraft-mod-spec/scripts/validate_spec.py mod-spec.json
```

## References

- `references/schema.md`: Complete JSON shape and example.
