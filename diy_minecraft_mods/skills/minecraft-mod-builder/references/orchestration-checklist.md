# Orchestration Checklist

A "complete enough to hand to the user" generated mod should have:

- A validated `mod-spec.json` or `.minecraft-mod-spec.json`.
- A `.minecraft-vanilla-check.json` report with no unresolved exact duplicates, or explicit intentional overlap in the spec.
- A scaffold based on a current Fabric/NeoForge/Architectury template.
- Registered items and blocks in source code.
- Matching resource JSON files for items/blocks.
- PNG textures generated or explicitly skipped by user choice.
- OGG sounds and `sounds.json` generated or explicitly skipped when `sounds[]` is declared.
- Custom models generated or explicitly skipped when spec entries declare non-default `model.kind`.
- Language entries for all user-facing names.
- Loot tables for blocks that should drop themselves.
- Recipes where the spec requested them.
- A successful Gradle build, or a concise error report with the next fix.
- A `.minecraft-test-report.json` from `minecraft-gametest`, or a documented reason GameTest could not run for this template/version.
- A jar path under `build/libs` or loader subproject `build/libs`.

Runtime checks still matter:

- Launch client and confirm items/blocks appear in inventory/creative tab.
- Place and break blocks.
- Confirm dedicated server start if any client-only code changed.
