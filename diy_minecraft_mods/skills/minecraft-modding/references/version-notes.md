# Version Notes

Always verify the target version from the project. Do not assume tutorials for 1.19 or 1.20 still apply to 1.21.x.

## Minecraft 1.21 Data Paths

Modern 1.21 data pack paths use singular names in several places, including examples such as:

- `data/<namespace>/loot_table/...`
- `data/<namespace>/tags/block/...`
- `data/<namespace>/tags/item/...`
- `data/<namespace>/tags/entity_type/...`

Match the existing generated output if the project has datagen.

## Official Docs To Check

- NeoForge docs: https://docs.neoforged.net/
- Fabric docs: https://docs.fabricmc.net/develop/
- Architectury docs: https://docs.architectury.dev/
- Minecraft Wiki data formats: https://minecraft.wiki/w/Java_Edition_data_values

Use official docs first for API signatures. Community tutorials are useful only after confirming the target version and loader.
