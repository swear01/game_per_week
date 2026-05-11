# Common Assets

Use datagen when the project already has providers. Otherwise hand-author small JSON files using the local format.

## Item Model

`src/main/resources/assets/<modid>/models/item/<name>.json`

```json
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "<modid>:item/<name>"
  }
}
```

For handheld tools:

```json
{
  "parent": "minecraft:item/handheld",
  "textures": {
    "layer0": "<modid>:item/<name>"
  }
}
```

## Simple Cube Block

`assets/<modid>/blockstates/<name>.json`

```json
{
  "variants": {
    "": {
      "model": "<modid>:block/<name>"
    }
  }
}
```

For non-default block or item shapes, use `minecraft-modeling` and `.minecraft-models.json` instead of these simple templates.

`assets/<modid>/models/block/<name>.json`

```json
{
  "parent": "minecraft:block/cube_all",
  "textures": {
    "all": "<modid>:block/<name>"
  }
}
```

`assets/<modid>/models/item/<name>.json`

```json
{
  "parent": "<modid>:block/<name>"
}
```

## Block Loot Table

For Minecraft 1.21 data pack paths, use singular directories such as `loot_table` and `tags/block` when the project targets modern 1.21 conventions. Match the existing repo layout if it already differs.

`data/<modid>/loot_table/blocks/<name>.json`

```json
{
  "type": "minecraft:block",
  "pools": [
    {
      "rolls": 1,
      "entries": [
        {
          "type": "minecraft:item",
          "name": "<modid>:<name>"
        }
      ],
      "conditions": [
        {
          "condition": "minecraft:survives_explosion"
        }
      ]
    }
  ]
}
```

## Language

`assets/<modid>/lang/en_us.json`

```json
{
  "block.<modid>.<name>": "Display Name",
  "item.<modid>.<name>": "Display Name"
}
```

Merge with existing keys. Preserve ordering style if the file already has one.
