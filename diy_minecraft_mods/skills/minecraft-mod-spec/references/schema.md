# Mod Spec Schema

Prefer JSON:

```json
{
  "mod_id": "copperworks",
  "display_name": "Copperworks",
  "loader": "fabric",
  "minecraft_version": "1.21.8",
  "package": "com.example.copperworks",
  "java_version": 21,
  "texture_size": 32,
  "items": [
    {
      "id": "copper_wrench",
      "display_name": "Copper Wrench",
      "type": "tool",
      "texture_prompt": "single centered copper wrench Minecraft item texture",
      "transparent_texture": true,
      "recipe": {
        "type": "shaped",
        "pattern": [" C ", " IC", "I  "],
        "keys": {
          "C": "minecraft:copper_ingot",
          "I": "minecraft:iron_ingot"
        }
      }
    }
  ],
  "sounds": [
    {
      "id": "item.copper_wrench.use",
      "file": "item/copper_wrench_use",
      "prompt": "short copper ratchet click, dry Minecraft tool sound effect, no music",
      "subtitle": "Copper Wrench clicks",
      "duration_seconds": 1.0
    }
  ],
  "blocks": [
    {
      "id": "polished_limestone",
      "display_name": "Polished Limestone",
      "type": "decorative",
      "material_hint": "stone",
      "hardness": 1.5,
      "requires_tool": true,
      "texture_prompt": "seamless polished limestone Minecraft block texture",
      "loot": {
        "drops_self": true
      }
    },
    {
      "id": "copper_lantern",
      "display_name": "Copper Lantern",
      "type": "decorative",
      "texture_prompt": "copper lantern Minecraft block texture",
      "model": {
        "kind": "java_elements",
        "texture": "block/copper_lantern",
        "elements": [
          {"name": "base", "from": [3, 0, 3], "to": [13, 2, 13]},
          {"name": "body", "from": [4, 2, 4], "to": [12, 12, 12]},
          {"name": "handle", "from": [6, 12, 6], "to": [10, 16, 10]}
        ]
      }
    }
  ]
}
```

Rules:

- Use lowercase snake_case for `mod_id`, item ids, and block ids.
- Run `minecraft-vanilla-harness` before building; do not duplicate vanilla ids or exact display names unless the entry declares `allow_vanilla_overlap: true`.
- When extending a vanilla concept, add `vanilla_reference`, e.g. `"minecraft:saddle"`, so the intent is visible to later phases.
- Keep `package` lowercase with dot-separated Java identifiers.
- Every item and block needs a `texture_prompt` unless it deliberately reuses a vanilla texture.
- Use `sounds[]` for short generated sound events; `minecraft-sound-effects` writes OGG files and `sounds.json`.
- Recipes can be refined later, but include intent early so the builder can create placeholders or task notes.
- Omit `model` for normal item icons, handheld tools, and cube blocks.
- Use `model.kind` only for custom geometry that should trigger `minecraft-modeling`.
