# NeoForge Notes

Confirm NeoForge from `net.neoforged`, ModDevGradle, `META-INF/neoforge.mods.toml`, or an entry class annotated with `@Mod`.

## Entry Point

The `@Mod("<modid>")` class receives/registers against the mod event bus. Register deferred registers in the constructor or in the existing local bootstrap pattern.

## Registration

NeoForge projects commonly use `DeferredRegister`, `DeferredRegister.Blocks`, `DeferredBlock`, and `DeferredItem`. Match the existing project's wrappers before adding new classes.

Typical patterns:

- Register blocks through a deferred block register.
- Register matching block items through an item register.
- Put common setup on the mod event bus.
- Put gameplay events on the NeoForge event bus only when that is the local pattern.

## Client/Server Boundary

Use client-only event subscribers or client setup events for renderers, screens, layers, and color handlers. Always run or at least build/check dedicated-server-safe code after touching client classes.

## Datagen

NeoForge datagen usually wires providers from `GatherDataEvent`. If providers exist, extend them and run `./gradlew runData`.
