# Template Sources

Use current web search when the target loader/version matters. Good queries:

- `FabricMC fabric-example-mod <minecraft_version> GitHub`
- `NeoForgeMDKs MDK <minecraft_version> ModDevGradle GitHub`
- `Architectury template generator <minecraft_version> GitHub`

Trusted default sources:

- Fabric example mod: https://github.com/FabricMC/fabric-example-mod
- NeoForge MDKs organization: https://github.com/NeoForgeMDKs
- Architectury docs: https://docs.architectury.dev/

Selection rules:

- Prefer loader-owned GitHub organizations.
- Prefer branches/tags/repositories matching the target Minecraft version.
- Prefer maintained templates updated recently.
- Avoid random tutorial zips unless the user explicitly approves them.
- Keep a `template_source` record in generated project metadata.
