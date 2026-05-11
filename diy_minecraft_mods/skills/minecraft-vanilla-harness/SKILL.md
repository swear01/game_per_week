---
name: minecraft-vanilla-harness
description: Build and use a version-aware vanilla Minecraft registry/assets index for mod planning. Use before creating or building a Minecraft mod-spec to avoid duplicating blocks, items, entities, display names, or concepts that already exist in the target vanilla Minecraft Java version, using Mojang's official version manifest, client jar assets, language files, and cached vanilla indexes.
---

# Minecraft Vanilla Harness

## Role In The Pipeline

This is the version-awareness guardrail. Run it before scaffold/texture/model generation.

It answers: "Does this item/block already exist in vanilla Minecraft for the target version?"

## Workflow

1. Resolve the target version from `mod-spec.json`.
2. Build or reuse a cached vanilla index from Mojang official metadata.
3. Check spec ids and display names against vanilla item/block/entity/lang entries.
4. Stop the build on exact duplicates unless the spec explicitly allows vanilla overlap.
5. Feed warnings back into `minecraft-mod-spec` so the mod idea becomes additive instead of repeating vanilla content.

## Commands

Build an index:

```bash
python3 skills/minecraft-vanilla-harness/scripts/build_vanilla_index.py \
  --version 26.1.2
```

Check a spec:

```bash
python3 skills/minecraft-vanilla-harness/scripts/check_spec_against_vanilla.py \
  --spec mod-spec.json
```

Use the latest release from Mojang's manifest:

```bash
python3 skills/minecraft-vanilla-harness/scripts/build_vanilla_index.py --latest-release
```

## Spec Escape Hatch

If the user intentionally wants to reimplement or extend a vanilla concept, require an explicit flag:

```json
{
  "id": "reinforced_saddle",
  "display_name": "Reinforced Saddle",
  "allow_vanilla_overlap": true,
  "vanilla_reference": "minecraft:saddle"
}
```

Do not silently bypass the harness. Make the user intent explicit in the spec.

## References

- `references/vanilla-index.md`: Index contents, cache locations, and interpretation rules.
