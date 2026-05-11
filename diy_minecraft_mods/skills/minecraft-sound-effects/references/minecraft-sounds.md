# Minecraft Sound Layout

Minecraft Java resource packs and mods place sounds under:

```text
assets/<namespace>/sounds/<path>.ogg
assets/<namespace>/sounds.json
```

`sounds.json` references sound files without the `.ogg` extension:

```json
{
  "block.copper_chime.ring": {
    "subtitle": "subtitles.copper_chime.ring",
    "sounds": ["namespace:block/copper_chime_ring"]
  }
}
```

For a mod namespace, use `namespace:path`. For overriding vanilla sounds, use the `minecraft` namespace and the vanilla sound event key.

Practical rules:

- Use short, dry, non-musical prompts for UI/block/item sounds.
- Prefer mono or simple stereo OGG Vorbis; `ffmpeg` defaults are acceptable for first-pass assets.
- Keep event ids semantic: `block.<thing>.<action>`, `item.<thing>.<action>`, `entity.<thing>.<action>`.
- Add subtitle lang keys for user-facing or repeated gameplay sounds.
