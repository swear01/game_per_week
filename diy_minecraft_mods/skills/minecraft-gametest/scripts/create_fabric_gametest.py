#!/usr/bin/env python3
"""Create a starter Fabric GameTest source set from a Minecraft mod spec."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


def load_spec(project: Path, spec_path: str | None) -> dict[str, Any]:
    path = Path(spec_path).expanduser().resolve() if spec_path else project / ".minecraft-mod-spec.json"
    if not path.exists():
        raise SystemExit(f"Spec not found: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def pascal(value: str) -> str:
    return "".join(part.capitalize() for part in re.split(r"[^a-zA-Z0-9]+", value) if part) or "Mod"


def write_if_missing(path: Path, text: str, force: bool) -> bool:
    if path.exists() and not force:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return True


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", required=True)
    parser.add_argument("--spec")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--client", action="store_true", help="Also create a client GameTest skeleton.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    project = Path(args.project).expanduser().resolve()
    spec = load_spec(project, args.spec)
    mod_id = str(spec["mod_id"])
    package = str(spec["package"]) + ".gametest"
    class_name = pascal(mod_id) + "GameTest"
    package_dir = Path(*package.split("."))

    fabric_mod = {
        "schemaVersion": 1,
        "id": f"{mod_id}-test",
        "version": "1.0.0",
        "name": f"{spec.get('display_name', mod_id)} GameTests",
        "environment": "*",
        "entrypoints": {"fabric-gametest": [f"{package}.{class_name}"]},
    }

    java = f"""package {package};

import net.fabricmc.fabric.api.gametest.v1.GameTest;
import net.minecraft.gametest.framework.GameTestHelper;

public final class {class_name} {{
    @GameTest
    public void modLoads(GameTestHelper helper) {{
        helper.succeed();
    }}
}}
"""

    changed: list[str] = []
    mod_path = project / "src/gametest/resources/fabric.mod.json"
    java_path = project / "src/gametest/java" / package_dir / f"{class_name}.java"
    if write_if_missing(mod_path, json.dumps(fabric_mod, indent=2) + "\n", args.force):
        changed.append(str(mod_path))
    if write_if_missing(java_path, java, args.force):
        changed.append(str(java_path))

    if args.client:
        client_class = pascal(mod_id) + "ClientGameTest"
        fabric_mod["entrypoints"]["fabric-client-gametest"] = [f"{package}.{client_class}"]
        client_java = f"""package {package};

import net.fabricmc.fabric.api.client.gametest.v1.FabricClientGameTest;
import net.fabricmc.fabric.api.client.gametest.v1.context.ClientGameTestContext;
import net.fabricmc.fabric.api.client.gametest.v1.context.TestSingleplayerContext;

@SuppressWarnings("UnstableApiUsage")
public final class {client_class} implements FabricClientGameTest {{
    @Override
    public void runTest(ClientGameTestContext context) {{
        try (TestSingleplayerContext singleplayer = context.worldBuilder().create()) {{
            singleplayer.getClientLevel().waitForChunksRender();
            context.takeScreenshot("{mod_id}-client-smoke");
        }}
    }}
}}
"""
        client_path = project / "src/gametest/java" / package_dir / f"{client_class}.java"
        write_if_missing(mod_path, json.dumps(fabric_mod, indent=2) + "\n", True)
        if write_if_missing(client_path, client_java, args.force):
            changed.append(str(client_path))

    print(
        json.dumps(
            {
                "changed": changed,
                "next": [
                    "Patch build.gradle with fabricApi.configureTests if missing.",
                    "Run minecraft-gametest/scripts/run_test_matrix.py.",
                ],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
