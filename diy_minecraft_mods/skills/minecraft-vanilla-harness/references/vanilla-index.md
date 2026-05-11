# Vanilla Index

The harness uses Mojang's official Java Edition version manifest:

- `https://piston-meta.mojang.com/mc/game/version_manifest_v2.json`

It resolves the selected version JSON and downloads the client jar from `downloads.client.url`.

The generated index contains:

- `items`: ids inferred from `assets/minecraft/items`, `assets/minecraft/models/item`, and `assets/minecraft/textures/item`
- `blocks`: ids inferred from `assets/minecraft/blockstates`, `assets/minecraft/models/block`, and `assets/minecraft/textures/block`
- `entities`: ids inferred from `entity.minecraft.*` language keys
- `lang`: English display names from `assets/minecraft/lang/en_us.json`

Default cache:

```text
~/.cache/minecraft-vanilla-harness/
```

Interpretation:

- Exact id match with vanilla is a strong duplicate signal.
- Exact display name match is also a strong duplicate signal.
- Similar names are warnings; Codex should inspect them and decide whether the mod idea is still meaningfully new.
- If a duplicate is intentional, require `allow_vanilla_overlap: true` and ideally `vanilla_reference`.
