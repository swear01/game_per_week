---
name: minecraft-sound-effects
description: Generate, import, convert, and register Minecraft Java Edition sound effects for mods and resource packs using ElevenLabs Sound Generation API. Use when Codex needs to create short OGG sound assets, update sounds.json under an assets namespace, add subtitles/lang keys, batch-generate sounds from mod-spec or resource-pack specs, integrate sound reports into minecraft-modding or minecraft-resource-pack-builder workflows, or validate Minecraft sound file layout.
---

# Minecraft Sound Effects

## Role In The Pipeline

Use this whenever a mod or resource pack declares custom sounds. This skill is fixed to ElevenLabs for generation and `ffmpeg` for Minecraft-ready OGG conversion.

Inputs:

- `ELEVENLABS_API_KEY`
- `mod-spec.json`, `.minecraft-mod-spec.json`, or a resource-pack spec with `sounds[]`
- output root that contains or should contain `assets/<namespace>/...`

Outputs:

- `assets/<namespace>/sounds/<path>.ogg`
- `assets/<namespace>/sounds.json`
- optional subtitle keys in `assets/<namespace>/lang/en_us.json`
- `.minecraft-sounds.json`

## Workflow

1. Read `sounds[]` from the spec. If missing, ask for or infer short one-shot sound events only when the user requested sound work.
2. Generate audio through ElevenLabs Sound Generation API.
3. Convert the returned MP3 to OGG Vorbis with `ffmpeg`.
4. Write or merge `sounds.json`.
5. Write a `.minecraft-sounds.json` report and hand it back to `minecraft-modding` or `minecraft-resource-pack-builder`.
6. Keep the generated MP3 only as metadata/debug output; Minecraft Java resources should reference `.ogg` files without the extension.

## Spec Shape

```json
{
  "sounds": [
    {
      "id": "block.copper_chime.ring",
      "file": "block/copper_chime_ring",
      "prompt": "short bright copper bell chime, dry, game sound effect, no music",
      "subtitle": "Copper Chime rings",
      "duration_seconds": 1.2,
      "prompt_influence": 0.5
    }
  ]
}
```

`id` is the sound event key inside `sounds.json`. `file` is the path below `assets/<namespace>/sounds` without extension.

## Commands

Generate all sounds from a spec:

```bash
ELEVENLABS_API_KEY=... python3 skills/minecraft-sound-effects/scripts/generate_sounds_from_spec.py \
  --spec mod-spec.json \
  --assets-root ./ResourcePack/assets
```

Generate one sound:

```bash
ELEVENLABS_API_KEY=... python3 skills/minecraft-sound-effects/scripts/generate_sound.py \
  --text "short stone door scrape, low grit, no music" \
  --output ./ResourcePack/assets/minecraft/sounds/block/stone_door_open.ogg
```

## References

- `references/elevenlabs.md`: ElevenLabs endpoint and environment variables.
- `references/minecraft-sounds.md`: Minecraft sound layout and `sounds.json` rules.
