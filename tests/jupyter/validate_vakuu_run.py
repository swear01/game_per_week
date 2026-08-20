from __future__ import annotations

import re
import sys
from pathlib import Path


REQUIRED_MARKERS = (
    "[VakuuHarness] attached",
    "[VakuuPlayer] VakuuContract localization ready language=",
    "[VakuuHarness] VakuuContract localization resolved title=",
    "[VakuuPlayer] opening deferred Preserved Fog selection",
    "[VakuuHarness] confirming first 3 snapshot cards",
    "[VakuuPlayer] Preserved Fog removed cards:",
    "[VakuuHarness] starting Vakuu relics=10",
    "[VakuuHarness] first combat room entered",
    "[VakuuHarness] ending first player turn to test next turn",
    "[VakuuHarness] player control returned; end-turn issued",
    "[VakuuHarness] FINAL ",
)
VAKUU_RELIC_IDS = (
    "BLOOD_SOAKED_ROSE",
    "FIDDLE",
    "PRESERVED_FOG",
    "SERE_TALON",
    "DISTINGUISHED_CAPE",
    "CHOICES_PARADOX",
    "MUSIC_BOX",
    "LORDS_PARASOL",
    "JEWELED_MASK",
    "VAKUU_CONTRACT",
)
FORBIDDEN_MARKERS = (
    "NullReferenceException",
    "Cannot wait for remote choice",
    "[VakuuHarness] failed:",
    "event continuation failed",
    "actual map travel failed",
)


def validate_log(path: str | Path) -> dict[str, object]:
    text = Path(path).read_text(encoding="utf-8", errors="replace")
    missing = [marker for marker in REQUIRED_MARKERS if marker not in text]
    failures = [marker for marker in FORBIDDEN_MARKERS if marker in text]
    turns = [int(value) for value in re.findall(r"auto-phase turn=(\d+)", text)]
    auto_play_turns = [int(value) for value in re.findall(r"auto-played card=.*? turn=(\d+)", text)]
    distinct_turns = sorted(set(turns))
    distinct_auto_play_turns = sorted(set(auto_play_turns))
    if len(distinct_auto_play_turns) < 2:
        failures.append(f"auto-play was not observed on two turns: {distinct_auto_play_turns}")
    if not set(distinct_auto_play_turns).issubset(distinct_turns):
        failures.append(
            f"auto-play turns were not covered by auto-phase turns: phases={distinct_turns}, plays={distinct_auto_play_turns}"
        )
    final_matches = re.findall(r"\[VakuuHarness\] FINAL (.+)", text)
    if not final_matches:
        failures.append("FINAL result line was not found")
    else:
        final = final_matches[-1]
        present = re.search(r"thirdActVakuuPresent=(True|False)", final)
        if present is None or present.group(1) != "True":
            failures.append(f"Vakuu was missing from act 3 ancients: {final}")
        auto_play_count = re.search(r"firstCombatAutoPlayCount=(\d+)", final)
        if auto_play_count is None or int(auto_play_count.group(1)) < 2:
            failures.append(f"first combat auto-play count was too low: {final}")
    missing_relics = [relic_id for relic_id in VAKUU_RELIC_IDS if relic_id not in text]
    if missing_relics:
        failures.append(f"missing Vakuu relics: {missing_relics}")
    if missing or failures:
        raise AssertionError({"missing": missing, "failures": failures})
    return {
        "auto_phase_turns": distinct_turns,
        "auto_play_turns": distinct_auto_play_turns,
        "auto_play_count": len(auto_play_turns),
    }


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {Path(sys.argv[0]).name} GODOT_LOG")
    print(validate_log(sys.argv[1]))
