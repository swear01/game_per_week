# Karst Terrain

Karst Terrain is a NeoForge 1.21.1 mod that adds a new Overworld biome: Karst Highlands.

## Content

- `karst_terrain:limestone`
- `karst_terrain:weathered_limestone`
- Creative tab: `Karst Terrain`
- `karst_terrain:karst_highlands` Overworld biome
- TerraBlender integration for Overworld biome placement
- Guizhou-inspired porous karst surface, caverns, and semi-underground rivers

Version `0.2.0` does not add new blocks or items. The new terrain features use existing limestone blocks, `minecraft:cave_air`, `minecraft:water`, and small amounts of vanilla dripstone decoration.

## Requirements

Runtime:

- Minecraft `1.21.1`
- NeoForge `21.1.228` or newer compatible 1.21.1 build
- TerraBlender for NeoForge `1.21.1-4.1.0.8` or newer compatible build

Development:

- Java 21
- The included Gradle wrapper (`./gradlew`)

TerraBlender is required because the mod registers a custom biome into Overworld generation. It is not bundled inside the Karst Terrain jar.

## Installation

1. Install Minecraft `1.21.1` with NeoForge.
2. Download TerraBlender for NeoForge `1.21.1`.
3. Put both jars in the instance `mods` folder:
   - `karst_terrain-0.2.0.jar`
   - the matching TerraBlender NeoForge jar
4. Create a new world or explore new chunks in an existing world.

## World Generation

Karst Terrain adds `karst_terrain:karst_highlands` as a new Overworld biome. It is placed in mountain-like inland climate slots via TerraBlender, so vanilla biomes are not directly modified.

Generated features:

- porous limestone surface with aligned sinkholes, fissures, exposed rock, and low limestone terraces
- continuous semi-underground river channels with stable water levels, appearing in low open cuts and disappearing under higher covered sections
- limestone caverns with occasional pools and vanilla dripstone decoration
- limestone strata replacing stone underground and in exposed mountain stone
- weathered limestone pockets near higher terrain

The mod does not modify vanilla biomes or the global Overworld noise settings. Karst terrain features are only attached to `karst_terrain:karst_highlands`.

Locate it with:

```mcfunction
/locate biome karst_terrain:karst_highlands
```

## Build

```bash
./gradlew clean build
```

The built jar is written to:

```text
build/libs/karst_terrain-0.2.0.jar
```

Build outputs are intentionally ignored by git. Use the GitHub Release jar for normal installation, or build locally with the command above.

## Test Commands

```bash
./gradlew runClient
./gradlew runServer
./gradlew runData
```

Manual worldgen check:

```mcfunction
/locate biome karst_terrain:karst_highlands
```

## License

This project was generated from the NeoForge MDK template. See `TEMPLATE_LICENSE.txt` for the template license notice.
