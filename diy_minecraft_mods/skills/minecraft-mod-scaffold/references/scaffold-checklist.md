# Scaffold Checklist

A scaffolded project should have:

- Gradle wrapper or clear Gradle instructions from the template.
- `gradle.properties` with Minecraft/loader versions.
- Loader metadata: `fabric.mod.json` or `META-INF/neoforge.mods.toml`.
- Main source package under `src/main/java` or equivalent subproject.
- `src/main/resources/assets/<modid>/` directories.
- Item and block model JSON for spec entries.
- Language entries for spec entries.
- Blockstate JSON and simple loot tables for spec blocks.
- A copied `mod-spec.json` or `.minecraft-mod-spec.json`.
- A note recording the template URL and scaffold command.

The scaffold is only the base. Full automation still needs registration code, textures, datagen/build, and runtime checks.
