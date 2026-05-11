# Resource Pack Layout

Minecraft Java resource packs are folders or zip files with `pack.mcmeta` at the archive root.

Typical layout:

```text
pack.mcmeta
pack.png
assets/
  minecraft/
    textures/
    models/
    blockstates/
    lang/
    sounds.json
    sounds/
```

For mod assets, replace `minecraft` with the mod namespace.

## Pack Format

For modern versions, this repo resolves pack format from the target client jar's `version.json`:

```json
{
  "pack_version": {
    "resource_major": 84,
    "resource_minor": 0
  }
}
```

The builder writes:

```json
{
  "pack": {
    "pack_format": 84,
    "supported_formats": [84, 84],
    "description": "..."
  }
}
```

When targeting older versions, pass `--pack-format` if Mojang metadata cannot be resolved.

## Pack Thumbnail

`pack.png` is the thumbnail shown in the resource pack selection screen. The builder generates it through `minecraft-texture-replicate` using `resource_pack.icon_prompt` (or a prompt derived from `display_name`). Provide `resource_pack.icon` with a local PNG path to skip Replicate, or pass `--skip-pack-icon` to omit the thumbnail entirely. Default size is 128×128.

## Zip Rule

The zip root must contain `pack.mcmeta` directly. Do not zip the parent folder so the archive contains `PackName/pack.mcmeta`.
