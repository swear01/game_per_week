# Fabric GameTest Notes

Source: https://docs.fabricmc.net/develop/automatic-testing

Fabric automated testing has two useful layers:

- Unit tests through Fabric Loader JUnit for helper classes and registry-dependent Java logic.
- GameTests for in-game server features; Fabric also supports client game tests for end-to-end client checks.

## Build Setup

For Fabric Loom projects, add or verify this shape in `build.gradle` before creating GameTests:

```gradle
fabricApi {
    configureTests {
        createSourceSet = true
        modId = "<modid>-test-${project.name}"
        enableGameTests = true
        enableClientGameTests = true
        eula = true
    }
}
```

When `createSourceSet = true`, Fabric expects the GameTest test mod in:

```text
src/gametest/resources/fabric.mod.json
src/gametest/java/<package>/...
```

The Fabric docs show entrypoints like:

```json
{
  "schemaVersion": 1,
  "id": "example-mod-test",
  "version": "1.0.0",
  "name": "Example mod",
  "environment": "*",
  "entrypoints": {
    "fabric-gametest": ["com.example.docs.ExampleModGameTest"],
    "fabric-client-gametest": ["com.example.docs.ExampleModClientGameTest"]
  }
}
```

## Running

- Server GameTests run automatically with `./gradlew build` when configured.
- Client GameTests can be run with `./gradlew runClientGameTest` when the task exists.
- CI client tests may need XVFB and sometimes a JVM arg for Fabric's network synchronizer depending on the current Fabric docs and version.

## Practical First Tests

Start with server tests:

- registry lookup for each spec item/block id
- block placement by `helper.setBlock(...)`
- block state assertion after placement
- drop/loot checks when the helper API supports the needed interaction

Use client tests only for client-only behavior:

- model/texture screenshot smoke checks
- screen/widget checks
- renderer initialization checks

## Cautions

- Fabric docs are versioned. Confirm import packages against the target version when compile errors mention moved Minecraft classes.
- Do not add visual screenshot tests before server GameTests and `build` are stable.
- Ordinary JUnit is not enough for registry-dependent Minecraft code unless Fabric Loader JUnit and bootstrap setup are correct.
