# Blockbench MCP Notes

Blockbench MCP plugin:

- Server URL: `http://localhost:3000/bb-mcp`
- Plugin id: `mcp`
- Default port: `3000`
- Default endpoint: `/bb-mcp`

The current local install was verified with MCP initialize and tools/list.

Use MCP for visual or iterative models. Use `scripts/model_from_spec.py` for deterministic JSON-only models.

Useful tools:

- `create_project`: create a new Blockbench project.
- `place_cube`: create one or more cuboids.
- `modify_cube`: adjust cuboid position, rotation, UV, shade, inflate.
- `add_group`: organize bones/groups.
- `list_outline`: inspect groups and cubes.
- `create_texture`: load or create a texture.
- `apply_texture`: apply texture to an element.
- `set_camera_angle`: set view for screenshots.
- `capture_screenshot`: collect visual proof.

Coordinate convention:

- Java block model space is usually 0 to 16 on each axis.
- Keep block models centered inside 0..16 unless intentionally oversized.
- If the visual model differs from collision, `minecraft-modding` must add or document the voxel shape.
