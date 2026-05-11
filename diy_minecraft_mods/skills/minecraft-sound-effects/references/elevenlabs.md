# ElevenLabs Sound Effects

Primary docs:

- https://elevenlabs.io/docs/api-reference/how-to-use-text-to-sound-effects
- https://elevenlabs.io/docs/api-reference/text-to-sound-effects/convert

The workflow uses:

- environment variable: `ELEVENLABS_API_KEY`
- endpoint: `POST https://api.elevenlabs.io/v1/sound-generation`
- request header: `xi-api-key: <key>`
- content type: `application/json`
- response: generated sound effect as MP3 bytes

Useful request fields:

- `text`: prompt text
- `duration_seconds`: optional explicit duration
- `prompt_influence`: optional control for prompt adherence

ElevenLabs docs also advertise an official sound-effects skill:

```bash
npx skills add elevenlabs/skills --skill sound-effects
```

This repo still keeps a local Minecraft-specific wrapper so sound files, `sounds.json`, and reports match the mod/resource-pack pipeline.
