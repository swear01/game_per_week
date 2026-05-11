import json
import sys
from typing import Any, TextIO

from deck_merger.engine import apply_action, legal_actions
from deck_merger.hand_display import HandDisplayMode
from deck_merger.observation import DEFAULT_HAND_DISPLAY, observation_dict
from deck_merger.state import GameState
from deck_merger.ui_commands import legal_action_to_command_hint, parse_player_line


def _is_all_actions_line(line: str) -> bool:
    return line.strip().lower() == "all_actions"


def _is_all_actions_json(obj: dict[str, Any]) -> bool:
    return obj.get("op") == "all_actions"


def _all_actions_payload(state: GameState, hand_display: HandDisplayMode) -> dict[str, Any]:
    acts = legal_actions(state)
    return {
        "ok": True,
        "query": "all_actions",
        "legal_actions": acts,
        "command_hints": [legal_action_to_command_hint(state, a) for a in acts],
        "state": observation_dict(state, hand_display=hand_display),
    }


def run_agent_loop(
    state: GameState,
    inp: TextIO = sys.stdin,
    out: TextIO = sys.stdout,
    *,
    hand_display: HandDisplayMode = DEFAULT_HAND_DISPLAY,
) -> None:
    for line in inp:
        line = line.strip()
        if not line:
            continue
        if _is_all_actions_line(line):
            payload = _all_actions_payload(state, hand_display)
            out.write(json.dumps(payload, ensure_ascii=False) + "\n")
            out.flush()
            if state.won or state.lost:
                break
            continue
        if line.startswith("{"):
            try:
                obj = json.loads(line)
            except json.JSONDecodeError as e:
                out.write(
                    json.dumps({"ok": False, "error": f"json: {e}"}, ensure_ascii=False) + "\n"
                )
                out.flush()
                continue
            if isinstance(obj, dict) and _is_all_actions_json(obj):
                payload = _all_actions_payload(state, hand_display)
                out.write(json.dumps(payload, ensure_ascii=False) + "\n")
                out.flush()
                if state.won or state.lost:
                    break
                continue
            out.write(
                json.dumps(
                    {
                        "ok": False,
                        "error": "僅支援 JSON 查詢 {\"op\":\"all_actions\"}；"
                        "其餘動作請送一行文字指令（與人類模式相同）。",
                    },
                    ensure_ascii=False,
                )
                + "\n"
            )
            out.flush()
            continue
        try:
            action = parse_player_line(line, state)
        except ValueError as e:
            out.write(
                json.dumps({"ok": False, "error": str(e)}, ensure_ascii=False) + "\n"
            )
            out.flush()
            continue
        err = apply_action(state, action)
        payload: dict[str, Any] = {
            "ok": err is None,
            "error": err,
            "state": observation_dict(state, hand_display=hand_display),
        }
        out.write(json.dumps(payload, ensure_ascii=False) + "\n")
        out.flush()
        if state.won or state.lost:
            break
