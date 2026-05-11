---
name: minecraft-gametest
description: Add, run, and debug Minecraft Java Edition mod GameTests and test harnesses for Fabric, NeoForge, and Architectury projects. Use after a mod is scaffolded or implemented when Codex needs to create loader-specific GameTest scaffolding, verify item/block registration behavior in an in-game test framework, run Gradle test tasks such as test, build, runData, runGameTestServer, or runClientGameTest, collect screenshots/logs, and write .minecraft-test-report.json for the full Minecraft modding pipeline.
---

# Minecraft GameTest

## Role In The Pipeline

Use this after `minecraft-modding` has registered the declared content, or when a scaffold already has enough code to compile. This skill turns "the mod builds" into "the mod has loader-appropriate automated checks."

GameTest is not a replacement for manual creative-tab and visual inspection. It is the automated layer for registry presence, block placement behavior, loot/drop behavior, recipe availability, server safety, and simple world interactions.

## Workflow

1. Read the project handoff files when present:
   - `.minecraft-mod-spec.json`
   - `.minecraft-vanilla-check.json`
   - `.minecraft-scaffold.json`
   - `.minecraft-textures.json`
   - `.minecraft-models.json`
   - `.minecraft-build-report.json`
   - `.minecraft-modding-handoff.md`
2. Detect the loader from `gradle.properties`, `build.gradle`, `settings.gradle`, `fabric.mod.json`, `META-INF/neoforge.mods.toml`, and source packages.
3. Read `references/fabric-gametest.md` or `references/neoforge-gametest.md` for loader-specific setup before editing build files.
4. Add the smallest useful GameTest first:
   - mod loads
   - each declared item/block registry id resolves
   - each block can be placed as the expected block state
   - each block drops itself when the spec says `loot.drops_self`
   - server starts without client-only class loading
5. Run `scripts/run_test_matrix.py` from this repo against the generated mod project.
6. Fix the first failing compile/test/runtime error; rerun until `.minecraft-test-report.json` reflects a meaningful pass or a clear blocker.

## Commands

Run the available automated checks:

```bash
python3 skills/minecraft-gametest/scripts/run_test_matrix.py \
  --project ./Copperworks
```

Include client GameTest tasks when available:

```bash
python3 skills/minecraft-gametest/scripts/run_test_matrix.py \
  --project ./Copperworks \
  --include-client
```

Generate a starter Fabric GameTest source set from `.minecraft-mod-spec.json`:

```bash
python3 skills/minecraft-gametest/scripts/create_fabric_gametest.py \
  --project ./Copperworks
```

## Test Levels

- **Gradle build/resource checks**: `test`, `runData`, `build`.
- **Server GameTest**: `runGameTestServer` when the loader/template exposes it, or Fabric server GameTests through `build`.
- **Client GameTest**: `runClientGameTest` or equivalent Fabric Loom production task; use only when the project has client tests or visual smoke checks.
- **Manual smoke check**: still required for final visual confirmation of textures, models, creative tab placement, and interactive feel.

## Failure Policy

- If no Gradle wrapper or `gradle` executable exists, report the missing runner instead of inventing results.
- If a task is unavailable, mark it as skipped in `.minecraft-test-report.json`.
- If `build` fails before GameTest tasks, fix compile/resource errors first.
- If GameTest APIs differ by target version, search current Fabric/NeoForge docs and patch the generated test code to match the template.
- If a client GameTest fails only in headless CI, check the loader docs for XVFB or network-synchronizer JVM args before disabling the test.

## References

- `references/fabric-gametest.md`: Fabric Loader JUnit, Fabric Loom GameTest setup, and task expectations.
- `references/neoforge-gametest.md`: NeoForge GameTest setup, test data, run configuration, and task expectations.
- `references/test-cases.md`: Suggested tests generated from `mod-spec.json`.
