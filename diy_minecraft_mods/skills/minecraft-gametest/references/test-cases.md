# Spec-Derived GameTest Cases

Use `.minecraft-mod-spec.json` to derive a first useful test suite.

## Items

For each `items[]` entry:

- registry id resolves as `<modid>:<id>`
- item can create an `ItemStack`
- item appears in the intended creative tab if the spec declares one
- recipe output resolves if the spec declares a recipe

## Blocks

For each `blocks[]` entry:

- registry id resolves as `<modid>:<id>`
- matching `BlockItem` exists unless the spec says the block is unobtainable
- helper can place the block at a local position
- helper can assert the placed block state
- loot/drop behavior matches `loot.drops_self`
- required tool and hardness behavior are checked if the loader/helper APIs make that practical

## Resources

GameTests cannot fully verify visual quality, but the test harness should still check file presence before running:

- blockstate JSON exists for each block
- block model JSON exists
- item model JSON exists
- texture PNG exists unless texture generation was explicitly skipped
- lang key exists for each user-facing name

## Report Expectations

Write `.minecraft-test-report.json` with:

- loader
- available Gradle tasks
- executed tasks and exit codes
- skipped unavailable tasks
- report/log paths when known
- remaining manual checks
