# Spec Model Fields

Default assets do not need `model`.

Use `model` only for non-default geometry:

```json
{
  "id": "copper_lantern",
  "display_name": "Copper Lantern",
  "texture_prompt": "copper lantern Minecraft block texture",
  "model": {
    "kind": "java_elements",
    "texture": "block/copper_lantern",
    "elements": [
      {"name": "base", "from": [3, 0, 3], "to": [13, 2, 13]},
      {"name": "body", "from": [4, 2, 4], "to": [12, 12, 12]},
      {"name": "handle", "from": [6, 12, 6], "to": [10, 16, 10]}
    ]
  }
}
```

Supported `kind` values:

- `default`: no modeling phase
- `generated`: default item icon
- `handheld`: default handheld item
- `cube_all`: default block cube
- `java_elements`: generate vanilla Java model JSON from `elements`
- `custom_block`: same as `java_elements`, but semantically a block
- `custom_item`: same as `java_elements`, but semantically an item
- `blockbench`: use Blockbench MCP or file-based `.bbmodel` workflow
- `geckolib`: model/animation workflow; requires later modding implementation
- `entity`: model/renderer workflow; requires later modding implementation

Element fields:

- `name`
- `from`: `[x, y, z]`
- `to`: `[x, y, z]`
- `rotation`: optional object with `origin`, `axis`, `angle`, `rescale`
- `shade`: optional boolean
- `faces`: optional object for explicit UV/texture control

If `faces` is omitted, the generator assigns every face to `#all`.
