# Fabric Notes

Confirm Fabric from `fabric.mod.json`, `fabric-loom`, or source classes implementing `ModInitializer`.

## Entry Points

- Common initialization: class implementing `ModInitializer`.
- Client-only registration: class implementing `ClientModInitializer`.
- Datagen: Fabric data generator entrypoint when configured.

## Registration

Modern Fabric examples use vanilla registries through `Registry.register` and IDs through `Identifier.of(modid, path)`. Match the existing project's helper wrappers if present.

For 1.21.2+ style projects, block and item settings may require registry keys. Official Fabric docs show current helper patterns; check them when adding blocks/items in a fresh 1.21.x project.

## Client/Server Boundary

Keep renderers, keybindings, screens, and model layer registration in client entrypoints or client-only packages. Verify dedicated server startup after client-facing changes.

## Datagen

If Fabric datagen exists, add model, recipe, loot, tag, and language providers rather than hand-writing generated JSON. Run the project's datagen task before build.
