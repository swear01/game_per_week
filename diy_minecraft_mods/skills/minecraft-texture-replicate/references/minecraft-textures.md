# Minecraft Texture Guidelines

## Resolutions

Use power-of-two square PNGs. Common sizes:

- `16`: vanilla-style, strictest readability requirement
- `32`: good default for modded textures
- `64`: more detail, still resource-pack friendly

## Item Prompt Template

```text
single centered Minecraft item texture sprite of {subject}, pixel art, square icon, orthographic view, readable silhouette, crisp edges, limited palette, plain background, no text, no UI, no frame, no hand, no character, no scene
```

Add material and gameplay cues: `iron`, `copper`, `enchanted`, `damaged`, `glowing`, `wooden handle`, `gem socket`, `nether style`.

## Block Prompt Template

```text
seamless square Minecraft block texture tile of {subject}, pixel art material, flat front-facing texture, repeatable pattern, crisp edges, limited palette, readable at 16x16, no perspective, no 3D cube, no text, no UI, no border
```

Add tiling cues: `connected cracks`, `small repeated stones`, `ore flecks distributed evenly`, `moss in crevices`, `subtle color variation`.

## Validation Checklist

- Filename is lowercase snake_case.
- PNG dimensions are exactly square and match requested size.
- Item texture has transparent or clean background when needed.
- Block texture does not contain perspective, a cube render, a border, or a single centered object.
- The image remains identifiable when displayed at its native Minecraft size.
- Metadata JSON preserves prompt, model, seed, and input settings.
