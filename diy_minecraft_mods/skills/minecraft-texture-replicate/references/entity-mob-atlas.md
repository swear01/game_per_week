# Entity / mob texture atlas (Java Edition)

Vanilla humanoid mobs (zombie, player-shaped models) use a **square PNG** that is **not** a perspective render: it is a **2D UV atlas**. Each small rectangle is one face of the cuboid body part at **orthographic** pixel resolution. Wrong outputs often look like a **single full-body character** on a canvas—that will not map onto the in-game model.

## Layout concept

- Follow the same unfolded layout as **player skins (1.8+)** on the texture file: head and hat layers, body, arms, legs, each mapped to fixed regions of the image.
- Authoritative layout diagrams and editing steps: [Minecraft Wiki: Creating a skin](https://minecraft.wiki/w/Tutorials%3ACreating_a_skin).
- In this repo, **`generate_texture.mjs --type entity`** appends a short English suffix to your prompt so models keep **atlas** semantics (no standing pose, no scene).

## Pipeline defaults

1. **Vanilla reference (resource packs)**  
   For `texture_overrides` under `entity/` and namespace `minecraft`, [`build_resource_pack.py`](../minecraft-resource-pack-builder/scripts/build_resource_pack.py) resolves the matching version from [InventivetalentDev/minecraft-assets](https://github.com/InventivetalentDev/minecraft-assets) (cached under `~/.cache/minecraft-texture-replicate/vanilla/<version>/...`).

2. **img2img on Replicate `retro-diffusion/rd-fast`**  
   The model exposes **`input_image`** (URI) and **`strength`** (schema default **0.8**; examples often **0.9**). **Higher `strength`** follows the **prompt** more; **lower** preserves **`input_image`**. If the reference **is** the vanilla atlas, use **~0.75–0.92** for clearer retextures, or **~0.95–0.99** when you need a **strong** break from vanilla colors and silhouette.

3. **Layout blend (`entity_layout_blend`) — optional**  
   Default **omit** or **`1`**: **no** color mix with vanilla on skin pixels (trust the model); only **padding/holes** are snapped from the vanilla atlas. Use **strictly between 0 and 1** when you want `gen×t + ref×(1−t)` on non-padding pixels for a safety net.

4. **Tiling**  
   **`tile_x` / `tile_y` must stay false** for atlases. If a **reference image** is provided, tiling is forced off.

## Standard 64×64 head regions (Java humanoid skins)

These ranges use **x,y** from the **top-left** of the PNG, **inclusive** (same layout as player skins; zombies use the same atlas size):

| Region | x | y | Size |
|--------|---|---|------|
| Head front (face — **eyes/mouth only here**) | 8–15 | 8–15 | 8×8 |
| Head top | 8–15 | 0–7 | 8×8 |
| Head right | 0–7 | 8–15 | 8×8 |
| Head left | 16–23 | 8–15 | 8×8 |
| Head back | 24–31 | 8–15 | 8×8 |
| Hat overlay front | 40–47 | 8–15 | 8×8 |
| Hat overlay top | 40–47 | 0–7 | 8×8 |

`generate_texture.mjs` appends this map in prose so the model is less likely to paint eyes on the torso or limbs.

## Generation resolution (pipeline)

- For **`--type entity`**, `generate_texture.mjs` asks rd-fast for **2×** the final width/height (e.g. **128×128** when the pack uses **64×64**), then **nearest-neighbor** downscales to the game size so pixel steps align more cleanly to the atlas grid. Final output dimensions still match **`texture_size`**.

## PNG encoding

- Vanilla mob atlases (e.g. `textures/entity/zombie/zombie.png`) are often **indexed PNG** (**8-bit colormap**), not 32-bit RGBA.
- `generate_texture.mjs` re-encodes **`--type entity`** finals through Sharp with **`palette: true`** (256 colors). That aligns file format with vanilla and avoids client quirks such as a **fully black head** while the rest of the skin looks fine.

## Validation checklist

- Output PNG size matches game expectation (e.g. zombie **64×64**).
- No single centered “poster” character; instead, small face/torso/limb **patches** in grid positions.
- Side-by-side with vanilla atlas: **edges of major regions** should stay roughly aligned; raise **`strength`** if the skin still reads as vanilla.
