---
name: minecraft-mod-scaffold
description: Create Minecraft Java Edition mod projects from a validated mod-spec and a current web template. Use when Codex needs to scaffold a new Fabric, NeoForge, or Architectury mod, search for and import a base template, copy official GitHub template repositories into a project, add initial resource folders, item/block JSON assets, lang files, texture placeholders or Replicate texture tasks, and prepare the project for minecraft-modding implementation and Gradle verification.
---

# Minecraft Mod Scaffold

## Role In The Pipeline

This is phase 2. Consume a validated `mod-spec.json`, fetch a current base template from the web, create the project directory, emit initial JSON resources, and write `.minecraft-scaffold.json`.

Do not generate PNG textures here. Do not implement loader-specific registration code here. Those belong to `minecraft-texture-replicate` and `minecraft-modding`.

## Template Policy

Use a real current template as the base. Do not hand-roll Gradle from memory for a new mod unless the user explicitly asks.

Preferred sources:

- Fabric: `https://github.com/FabricMC/fabric-example-mod.git`
- NeoForge: `https://github.com/NeoForgeMDKs/MDK-<minecraft_version>-ModDevGradle.git`, with fallback to the closest official NeoForge MDK repo.
- Architectury: search current Architectury template guidance first, then use a maintained template URL explicitly.

When unsure, search the web and official docs before scaffolding. Use official or loader-owned templates first; otherwise require a concrete `--template-url`.

## Workflow

1. Validate the spec with `../minecraft-mod-spec/scripts/validate_spec.py`.
2. Search/check template freshness if the target version is not already known.
3. Run `scripts/scaffold_from_spec.py`.
4. Confirm `.minecraft-mod-spec.json` and `.minecraft-scaffold.json` exist in the project root.
5. Hand the project to `../minecraft-texture-replicate` for PNG generation.
6. If the spec declares non-default `model.kind`, hand the project to `../minecraft-modeling`.
7. Hand the project to `../minecraft-modding` for loader-specific registration code and datagen integration.

## Quick Start

```bash
python3 skills/minecraft-mod-scaffold/scripts/scaffold_from_spec.py \
  --spec mod-spec.json \
  --output ./Copperworks
```

Use an explicit template:

```bash
python3 skills/minecraft-mod-scaffold/scripts/scaffold_from_spec.py \
  --spec mod-spec.json \
  --output ./Copperworks \
  --template-url https://github.com/FabricMC/fabric-example-mod.git
```

For NeoForge, prefer ModDevGradle unless the user has a reason to use NeoGradle:

```bash
python3 skills/minecraft-mod-scaffold/scripts/scaffold_from_spec.py \
  --spec mod-spec.json \
  --output ./Copperworks \
  --template-url https://github.com/NeoForgeMDKs/MDK-1.21.8-ModDevGradle.git
```

## After Scaffold

- Rename packages/classes only after reading the template layout.
- Keep template licenses and notices unless the user asks and licensing permits removal.
- Replace example ids, names, and package names with values from spec.
- Add registration code through `minecraft-modding`; generated JSON assets alone are not a working mod.

## Output Contract

The scaffold phase must leave:

- `<project>/.minecraft-mod-spec.json`
- `<project>/.minecraft-scaffold.json`
- `src/main/resources/assets/<modid>/models/...`
- `src/main/resources/assets/<modid>/blockstates/...` for blocks
- `src/main/resources/assets/<modid>/lang/en_us.json`
- `src/main/resources/data/<modid>/loot_table/...` for simple block drops
- texture directories for later Replicate generation

Custom model JSON may overwrite the simple scaffolded model files later. That is expected when `minecraft-modeling` runs.

## References

- `references/template-sources.md`: Template discovery and trusted sources.
- `references/scaffold-checklist.md`: Files that a complete base should contain.
