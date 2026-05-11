# Resource Pack Spec

The builder accepts the existing mod-spec fields plus a `resource_pack` object.

Project fields:

- `display_name`
- `minecraft_version`
- `mod_id` or `namespace`
- `resource_pack.namespace`: defaults to `mod_id`, use `minecraft` for vanilla overrides
- `resource_pack.description`
- `resource_pack.icon`: optional path to a local PNG to use as `pack.png` (relative paths resolve against the spec file). When set, Replicate is not called.
- `resource_pack.icon_prompt`: optional Replicate prompt for the auto-generated `pack.png`. Defaults to a prompt derived from `display_name`.
- `resource_pack.icon_size`: optional pixel size for the generated `pack.png`. Defaults to `128`.
- `resource_pack.icon_style`: optional rd-fast **`style`** for generated pack art (e.g. **`portrait`** for a head filling the canvas; **`low_res`**, **`mc_item`**). Passed as `--style` to `generate_texture.mjs`.
- `resource_pack.icon_bypass_prompt_expansion`: optional **boolean**; when **true**, adds **`--bypass-prompt-expansion`** for the pack icon call.
- `texture_size`

Item/block fields:

- `id`: local id, or vanilla id when namespace is `minecraft`
- `target_id`: optional namespaced id to override, e.g. `minecraft:saddle`
- `vanilla_reference`: optional fallback target, e.g. `minecraft:stone`
- `display_name`
- `texture_prompt`
- `transparent_texture`
- `model`: optional non-default model fields handled by `minecraft-modeling`

`texture_overrides[]` entries (in addition to `target`, `texture_prompt`, `texture_size`, `type`, `namespace`, `transparent_texture`):

- `reference_image`: optional PNG path relative to the spec file; overrides automatic vanilla texture lookup for that row
- `img2img_strength`: optional number 0–1 for `retro-diffusion/rd-fast` when a reference image is used (**higher** = more prompt; **lower** = more input image). For **vanilla** mob references, **~0.75–0.92** is typical for obvious retextures.
- `bypass_prompt_expansion`: optional boolean; when **true**, passes **`--bypass-prompt-expansion`** to `generate_texture.mjs` so rd-fast changes the prompt less (helps stick to exact motifs like “three eyes”, “red mushroom cap”, and avoids drifting back to default zombie wording).
- `seed`: optional integer; passed as **`--seed`** for reproducible Replicate runs on that texture row.
- `entity_layout_blend`: optional **0–1**; mix model with vanilla on non-padding pixels: `out = gen×t + ref×(1−t)`. **Omit or set `1`** for **no mix** (default when `entity` + `reference-image`): 100% model on skin pixels. Values **strictly between 0 and 1** pull colors back toward vanilla for layout safety. Padding/holes still follow the vanilla atlas (transparent / near-black in the reference) so UV gaps stay valid. **`0`** is treated like “no blend step” in the script (same as `1` for skipping the mix), but prefer **`1`** for clarity.

For **`type: entity`** overrides, the texture pipeline writes the final PNG as **8-bit palette** (vanilla-style indexed PNG) so clients match the format of mob atlases and avoid RGBA-only rendering glitches (e.g. a black head).

Sound fields:

- `id`: event key inside `sounds.json`
- `file`: path below `assets/<namespace>/sounds` without extension
- `prompt`: ElevenLabs sound prompt
- `subtitle`: optional display string
- `subtitle_key`: optional explicit lang key
- `duration_seconds`
- `prompt_influence`
