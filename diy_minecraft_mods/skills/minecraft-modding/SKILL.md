---
name: minecraft-modding
description: Build, inspect, and modify Minecraft Java Edition mods for Fabric, NeoForge, or Architectury projects, including Java/Kotlin registration code, Gradle build setup, resources, datagen, recipes, loot tables, tags, lang files, item and block JSON models, and runtime verification. Use when Codex works on Minecraft mod source code or assets; route texture creation for items and blocks through the repo-local minecraft-texture-replicate skill.
---

# Minecraft Modding

## Role In The Pipeline

This is the main engineering phase after spec validation, vanilla duplicate checking, scaffold, texture generation, and custom modeling. Consume a scaffolded project plus `.minecraft-modding-handoff.md`, then implement or repair the loader-specific code until the generated assets are actually registered and the Gradle build is meaningful.

Read these handoff files first when present:

- `.minecraft-mod-spec.json`
- `.minecraft-vanilla-check.json`
- `.minecraft-scaffold.json`
- `.minecraft-textures.json`
- `.minecraft-sounds.json`
- `.minecraft-models.json`
- `.minecraft-build-report.json`
- `.minecraft-test-report.json`
- `.minecraft-modding-handoff.md`

## Routing

- Use this skill for Java/Kotlin Minecraft mod work: registries, events, blocks, items, entities, networking, datagen, JSON assets, Gradle, and loader APIs.
- Do not use it for Paper/Bukkit plugins, pure datapacks, or command-only vanilla scripting unless the repo is actually a mod project.
- Use `../minecraft-texture-replicate` for item and block PNG texture creation if `.minecraft-textures.json` is missing or incomplete. Do not invent placeholder textures when the user asked for generated art.
- Use `../minecraft-sound-effects` for OGG sound generation if `sounds[]` exists and `.minecraft-sounds.json` is missing or incomplete. Sound generation is ElevenLabs-only in this repo.

## First Pass

1. Identify the loader and Minecraft version from `gradle.properties`, `build.gradle`, `settings.gradle`, `fabric.mod.json`, `META-INF/neoforge.mods.toml`, and source package names.
2. Read `.minecraft-modding-handoff.md`, `.minecraft-mod-spec.json`, and `.minecraft-vanilla-check.json` when present.
3. Read existing registration patterns before adding code. Match local class names, package layout, helper methods, registry wrappers, and datagen style.
4. Confirm whether the project is Fabric, NeoForge, or Architectury/multiloader before using loader-specific APIs.
5. Search official docs when APIs are unclear or version-sensitive. Minecraft 1.21.x APIs move quickly.

Useful probes:

```bash
rg -n "net\\.neoforged|moddevgradle|neoforge|NeoForge" gradle.properties build.gradle settings.gradle src
rg -n "fabric-loom|fabric\\.mod\\.json|ModInitializer|ClientModInitializer" gradle.properties build.gradle settings.gradle src
rg -n "architectury|common\\(|fabric\\(|neoforge\\(" build.gradle settings.gradle
cat gradle.properties
```

## Build And Verify

Prefer the repo's wrapper:

```bash
./gradlew build
./gradlew runData
./gradlew runClient
./gradlew runServer
./gradlew runGameTestServer
```

Use only commands that exist in the project. If a run task is missing, inspect Gradle tasks:

```bash
./gradlew tasks --all
```

After `./gradlew build`, jars usually appear under `build/libs/` or the loader subproject's `build/libs/`.

## Pipeline Completion Rules

For every declared item/block in `.minecraft-mod-spec.json`, confirm:

- `.minecraft-vanilla-check.json` has no unresolved exact duplicate errors, or the spec explicitly documents intentional overlap.
- Java/Kotlin registry object exists.
- Registry id exactly matches the spec id.
- Model JSON references the generated texture path.
- Texture PNG exists or texture generation was explicitly skipped.
- Sound OGG and `sounds.json` entries exist for every declared `sounds[]` entry, or sound generation was explicitly skipped.
- Custom model JSON exists or `.minecraft-models.json` documents remaining Blockbench/renderer work.
- Lang key exists.
- Block has matching `BlockItem` unless intentionally unobtainable.
- Block drop/loot behavior matches the spec.
- Creative tab visibility is implemented when requested.
- `minecraft-gametest` has run the available test matrix after implementation, or the remaining blocker is documented in `.minecraft-test-report.json`.

## Asset Workflow

Every new registered item or block should include the matching assets unless the project uses datagen to create them:

- Item: `assets/<modid>/models/item/<name>.json`, `assets/<modid>/textures/item/<name>.png`, lang entry, creative tab entry, recipe if craftable.
- Block: block registration, `BlockItem`, blockstate JSON, block model JSON, item model JSON, `assets/<modid>/textures/block/<name>.png`, loot table, lang entry, tags if needed.
- Sound: `assets/<modid>/sounds/<path>.ogg`, `assets/<modid>/sounds.json`, optional subtitle lang key, and source code calls/events where gameplay uses that sound.

When creating PNG textures:

```bash
node skills/minecraft-texture-replicate/scripts/generate_texture.mjs \
  --type item \
  --subject "ruby pickaxe" \
  --size 32 \
  --output-dir src/main/resources/assets/<modid>/textures/item \
  --name ruby_pickaxe \
  --transparent-bg
```

```bash
node skills/minecraft-texture-replicate/scripts/generate_texture.mjs \
  --type block \
  --subject "glowing blue crystal ore" \
  --size 32 \
  --output-dir src/main/resources/assets/<modid>/textures/block \
  --name blue_crystal_ore
```

If working inside a nested mod project, adjust the path back to this repo's `skills/minecraft-texture-replicate/scripts/generate_texture.mjs` or call the script by absolute path.

## Common Tasks

When adding a block:

1. Register the `Block`.
2. Register the matching `BlockItem`.
3. Add or generate blockstate, block model, item model, texture, loot table, language, and mining/tool tags.
4. Verify in-game placement, breaking drops, item model in inventory, and creative tab visibility.

When adding an item:

1. Register the `Item`.
2. Add or generate item model, texture, language, creative tab entry, and recipe if needed.
3. Verify inventory rendering, localization, recipe unlock, and server/client safety.

When adding an entity:

1. Register `EntityType`.
2. Keep renderer/model/client registration on the physical client only.
3. Add spawn egg, attributes, spawn rules, biome modifiers, language, and texture/model assets as required.
4. Verify both client run and dedicated server run.

## References

- `references/common-assets.md`: JSON templates and resource checklist.
- `references/fabric.md`: Fabric project signatures and registration reminders.
- `references/neoforge.md`: NeoForge project signatures and registration reminders.
- `references/version-notes.md`: Version-sensitive 1.21.x notes and doc links.
