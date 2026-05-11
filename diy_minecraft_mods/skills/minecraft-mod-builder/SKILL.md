---
name: minecraft-mod-builder
description: "Orchestrate end-to-end Minecraft mod generation from a mod-spec: scaffold from a current template, generate item and block textures through minecraft-texture-replicate, add or verify resources, run Gradle datagen/build tasks, collect jar outputs, and report remaining implementation gaps. Use when Codex is asked to fully automate creating, building, or packaging a Minecraft Java Edition mod from a structured spec or natural-language idea."
---

# Minecraft Mod Builder

## Role In The Pipeline

Use this as the entrypoint for "make a complete Minecraft mod" requests. It coordinates the full pipeline:

- `../minecraft-mod-spec` for `mod-spec.json`
- `../minecraft-vanilla-harness` for target-version duplicate checks against vanilla Minecraft
- `../minecraft-mod-scaffold` for template-based project creation
- `../minecraft-texture-replicate` for generated item/block PNGs
- `../minecraft-sound-effects` for ElevenLabs-generated OGG sounds and `sounds.json`
- `../minecraft-modeling` only for non-default model shapes
- `../minecraft-modding` for loader-specific Java/Kotlin implementation and debugging
- `../minecraft-gametest` for automated test matrix and GameTest verification after implementation

## Pipeline Contract

The skills exchange these files:

- `mod-spec.json`: source of truth from `minecraft-mod-spec`.
- `<project>/.minecraft-mod-spec.json`: copied spec inside the generated project.
- `<project>/.minecraft-vanilla-check.json`: vanilla id/name duplicate report from `minecraft-vanilla-harness`.
- `<project>/.minecraft-scaffold.json`: template source and scaffold metadata.
- `<project>/.minecraft-textures.json`: generated texture results from `minecraft-texture-replicate`.
- `<project>/.minecraft-sounds.json`: generated sound results from `minecraft-sound-effects`, only when `sounds[]` is declared.
- `<project>/.minecraft-models.json`: custom model results from `minecraft-modeling`, only when needed.
- `<project>/.minecraft-build-report.json`: Gradle and jar summary from this builder.
- `<project>/.minecraft-modding-handoff.md`: required handoff for `minecraft-modding`.
- `<project>/.minecraft-test-report.json`: automated test matrix and GameTest results from `minecraft-gametest`.

## End-To-End Workflow

1. If the user gave only an idea, first create and validate `mod-spec.json` with `minecraft-mod-spec`.
2. Run `minecraft-vanilla-harness` for the target Minecraft version. Revise exact duplicate ids/names unless the spec explicitly sets `allow_vanilla_overlap`.
3. Scaffold a project with `minecraft-mod-scaffold`; search current official templates first when version/template is uncertain.
4. Generate item/block textures by calling `minecraft-texture-replicate/scripts/generate_from_spec.mjs`.
5. If `sounds[]` is declared, generate OGG assets and `sounds.json` with `minecraft-sound-effects`.
6. If any spec entry declares a non-default `model.kind`, run `minecraft-modeling/scripts/model_from_spec.py`.
7. Run available Gradle tasks for an early signal.
8. Use `minecraft-modding` on `.minecraft-modding-handoff.md` to implement registry code, datagen wiring, custom model/sound integration, and compile fixes.
9. Use `minecraft-gametest` to run the available test matrix and add loader-specific GameTests when the project supports them.
10. Run Gradle/test tasks again until build succeeds or the remaining issue is clearly reported.
11. Return jar paths, verification commands, runtime checks, and `.minecraft-test-report.json`.

## Scripted Orchestration

For a first pass:

```bash
python3 skills/minecraft-mod-builder/scripts/build_from_spec.py \
  --spec mod-spec.json \
  --output ./Copperworks
```

Use a known template:

```bash
python3 skills/minecraft-mod-builder/scripts/build_from_spec.py \
  --spec mod-spec.json \
  --output ./Copperworks \
  --template-url https://github.com/FabricMC/fabric-example-mod.git
```

The script handles template scaffold, texture generation, and Gradle tasks. It does not replace Codex reviewing/patching Java code when template registration patterns differ.

The script runs the vanilla duplicate harness by default before scaffold. Use `--skip-vanilla-check` only when the user explicitly accepts that the spec may duplicate vanilla content, or `--vanilla-warnings-only` when collecting findings during exploration.

Skip texture generation during dry runs:

```bash
python3 skills/minecraft-mod-builder/scripts/build_from_spec.py \
  --spec mod-spec.json \
  --output ./Copperworks \
  --skip-textures
```

Skip custom model generation:

```bash
python3 skills/minecraft-mod-builder/scripts/build_from_spec.py \
  --spec mod-spec.json \
  --output ./Copperworks \
  --skip-modeling
```

## Failure Policy

- If Replicate is not configured, stop texture generation unless `--skip-textures` is passed.
- If ElevenLabs is not configured, stop sound generation unless `--skip-sounds` is passed.
- If the vanilla harness reports exact duplicates, revise the spec before generating assets unless the overlap is intentional and declared.
- If Gradle tasks fail, inspect the first compiler/resource error and fix the project rather than skipping build.
- If the template is stale or incompatible with the requested Minecraft version, search for a better template and rerun scaffold with `--template-url`.
- If the script finishes with no jar, continue with `minecraft-modding` using `.minecraft-modding-handoff.md`.
- If `.minecraft-models.json` reports `handoff_required`, use Blockbench MCP or file-based modeling before claiming the model phase is complete.
- If `.minecraft-test-report.json` is missing after implementation, use `minecraft-gametest` before calling the mod complete.

## References

- `references/orchestration-checklist.md`: Completion criteria for a generated mod.
