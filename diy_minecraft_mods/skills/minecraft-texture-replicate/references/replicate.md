# Replicate Notes

Use official Replicate docs or the model page whenever model input fields are uncertain. Different models accept different parameters.

## Authentication

Set `REPLICATE_API_TOKEN` before calling the script or client. Do not hard-code tokens into scripts, metadata, or resource-pack files.

## Model Selection

Default to `black-forest-labs/flux-schnell` for fast text-to-image drafts unless the user specifies another Replicate model. For better texture consistency, prefer a model that supports:

- square output or `aspect_ratio: "1:1"`
- PNG output
- seeds
- image-to-image or reference image input when iterating from an existing texture

**`retro-diffusion/rd-fast`** (used by `generate_texture.mjs` by default): OpenAPI fields include **`input_image`** (URI; local files are passed as `data:image/png;base64,...`) and **`strength`** for img2img. Schema default is **0.8**; the model’s default web example uses **0.9**. **Higher `strength` = follow the prompt more**; **lower** values preserve **`input_image`** (layout and colors). For **entity** retextures whose reference is **vanilla**, strengths **below ~0.55** usually look almost unchanged in-game; `generate_texture.mjs` therefore defaults **`--type entity` + reference** to **0.78** (overridable with `--img2img-strength` / `REPLICATE_IMG2IMG_STRENGTH`). Non–rd-fast models skip `--reference-image` with a warning.

If the selected model fails with an input schema error, inspect the model's API tab or OpenAPI schema and rerun with `--input-json`.

## Output Handling

Replicate Python client v1 returns `FileOutput` objects for generated files. Save these outputs immediately; API-created files are temporary. The helper script handles `FileOutput`, bytes, file-like values, local paths, and URL outputs.

## Common Failures

- Missing token: export `REPLICATE_API_TOKEN`.
- Missing Python packages: install `replicate` and `Pillow` in the active Python environment.
- Input schema mismatch: pass model-specific fields through `--input-json`.
- Texture is not pixel-art enough: regenerate at a larger model size, then downsample to 16/32/64 with the script.
- Item background remains visible: rerun with `--transparent-bg` only when the background is plain; otherwise use an image editor or an image model with transparent-background support.
