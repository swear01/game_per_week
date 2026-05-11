# NeoForge GameTest Notes

Sources:

- https://docs.neoforged.net/docs/misc/gametest/
- https://docs.neoforged.net/docs/1.20.6/misc/gametest/

NeoForge GameTests are in-game unit tests for object interactions and behavior. The modern 26.1 docs describe GameTests as a structure/template, environment, registered function, and test instance. Older 1.20.x/1.21.x docs use the annotation-style `@GameTest`, `@GameTestHolder`, and `RegisterGameTestsEvent` flow.

## Version-Sensitive Rule

Always check the target NeoForge docs before writing the test class. NeoForge's GameTest API changed between older annotation-driven docs and newer data-driven docs.

Use current docs for 26.1+ projects:

- `data/<namespace>/test_instance/<name>.json`
- `data/<namespace>/test_environment/<name>.json`
- `data/<namespace>/structure/<name>.nbt`
- registered test functions or datagen-backed test objects

Use older annotation docs only when the target project and imports match them:

- `@GameTest`
- `@GameTestHolder(MODID)`
- `RegisterGameTestsEvent`
- `GameTest#templateNamespace`

## Running

NeoForge exposes a Game Test Server run configuration in compatible templates:

```bash
./gradlew runGameTestServer
```

The Game Test Server returns an exit code based on required failed GameTests. If `runGameTestServer` is unavailable, inspect:

```bash
./gradlew tasks --all
```

NeoForge run configuration knobs to know:

- `neoforge.enabledGameTestNamespaces`: comma-separated namespaces to load.
- `neoforge.enableGameTest`: set to true for run configurations that should enable GameTests.
- `setForceExit false`: may be required on the `gameTestServer` run configuration in some NeoGradle setups so Gradle does not misreport the forced exit.

## Practical First Tests

Prefer server-safe checks first:

- item/block registry objects exist
- block placement produces the expected state
- block item exists for placeable blocks
- loot behavior matches the spec
- recipes load when the spec requested recipes

Only add client smoke checks after server GameTests and `build` are stable.

## Cautions

- Do not blindly copy old `@GameTestHolder` examples into 26.1+ projects; check current docs and imports first.
- Structure templates are `.nbt` files under `data/<namespace>/structure` in current docs.
- Keep GameTest namespace equal to `mod_id` unless the buildscript explicitly enables another namespace.
