#!/usr/bin/env python3
"""Drive deck_merger with LiteLLM; optional know-how load and post-game append."""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import sys
from pathlib import Path
from typing import Any

from dotenv import load_dotenv

_REPO_ROOT = Path(__file__).resolve().parents[1]
_SRC = _REPO_ROOT / "src"


def _ensure_package() -> None:
    if importlib.util.find_spec("deck_merger") is not None:
        return
    init = _SRC / "__init__.py"
    spec = importlib.util.spec_from_file_location(
        "deck_merger",
        init,
        submodule_search_locations=[str(_SRC)],
    )
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load deck_merger package from src/")
    mod = importlib.util.module_from_spec(spec)
    sys.modules["deck_merger"] = mod
    spec.loader.exec_module(mod)


_ensure_package()

from deck_merger.engine import apply_action, bootstrap_state, legal_actions  # noqa: E402
from deck_merger.hand_display import HandDisplayMode  # noqa: E402
from deck_merger.observation import DEFAULT_HAND_DISPLAY, observation_dict  # noqa: E402
from deck_merger.knowhow import (  # noqa: E402
    append_session_notes,
    load_knowhow_text,
    resolved_rules_version,
)
from deck_merger.state import GameState, relic_display_zh  # noqa: E402
from deck_merger.ui_commands import legal_action_to_command_hint, parse_player_line  # noqa: E402


def _read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _strip_markdown_fence(text: str) -> str:
    t = text.strip()
    if not t.startswith("```"):
        return t
    lines = t.split("\n")
    if lines and lines[0].startswith("```"):
        lines = lines[1:]
    if lines and lines[-1].strip().startswith("```"):
        lines = lines[:-1]
    return "\n".join(lines).strip()


def _first_nonempty_line(text: str) -> str:
    for line in _strip_markdown_fence(text).split("\n"):
        s = line.strip()
        if s:
            return s
    return ""


def _extract_json_object(text: str) -> dict[str, Any]:
    text = text.strip()
    if text.startswith("```"):
        lines = text.split("\n")
        if lines and lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].strip().startswith("```"):
            lines = lines[:-1]
        text = "\n".join(lines).strip()
    try:
        out = json.loads(text)
    except json.JSONDecodeError:
        start = text.find("{")
        if start < 0:
            raise
        depth = 0
        for i in range(start, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    out = json.loads(text[start : i + 1])
                    break
        else:
            raise
    if not isinstance(out, dict):
        raise TypeError("expected JSON object")
    return out


def _interpret_model_step(raw: str) -> tuple[str, str | None]:
    """('all_actions', None) 或 ('command', 一行文字給 parse_player_line)。"""
    line = _first_nonempty_line(raw)
    if not line:
        raise ValueError("模型輸出為空")
    if line.lower() == "all_actions":
        return "all_actions", None
    if line.startswith("{"):
        obj = json.loads(line)
        if not isinstance(obj, dict):
            raise ValueError("JSON 必須為物件")
        if obj.get("op") == "all_actions":
            return "all_actions", None
        raise ValueError(
            "已廢除以 JSON 送出 merge／use 等動作；請改為與終端相同之一行文字指令，"
            "或僅用 {\"op\":\"all_actions\"} 查詢合法步。"
        )
    return "command", line


def _completion_content(model: str, messages: list[dict[str, str]], **kwargs: Any) -> str:
    from litellm import completion

    resp = completion(model=model, messages=messages, **kwargs)
    choice = resp.choices[0]
    msg = choice.message
    content = msg.content
    if content is None:
        return ""
    if isinstance(content, str):
        return content
    parts: list[str] = []
    for block in content:
        if isinstance(block, dict) and block.get("type") == "text":
            parts.append(str(block.get("text", "")))
        else:
            parts.append(str(block))
    return "".join(parts)


def _state_user_message(
    state: GameState,
    *,
    hand_display: HandDisplayMode,
    hint: str | None = None,
) -> str:
    payload: dict[str, Any] = {"state": observation_dict(state, hand_display=hand_display)}
    if hint:
        payload["hint"] = hint
    return json.dumps(payload, ensure_ascii=False, indent=2)


def _run_reflect(
    model: str,
    repo_root: Path,
    rules_version: str,
    summary: dict[str, Any],
    reflect_system_path: Path,
) -> None:
    sys_t = _read_text(reflect_system_path)
    user = json.dumps(summary, ensure_ascii=False, indent=2)
    raw = _completion_content(
        model,
        [
            {"role": "system", "content": sys_t},
            {"role": "user", "content": user},
        ],
        temperature=0.2,
    )
    try:
        obj = _extract_json_object(raw)
    except (json.JSONDecodeError, TypeError, ValueError) as e:
        print(f"[learn] skip reflect (parse error): {e}", file=sys.stderr)
        return
    note = obj.get("append_session_notes", "")
    if not isinstance(note, str) or not note.strip():
        return
    path = append_session_notes(repo_root, rules_version, note)
    print(f"[learn] appended session notes -> {path.relative_to(repo_root)}", file=sys.stderr)


def main() -> None:
    p = argparse.ArgumentParser(description="deck_merger LiteLLM agent driver")
    p.add_argument("--seed", type=int, default=None)
    p.add_argument(
        "--no-default-relics",
        action="store_true",
        help="略過開局遺物二選一（與 python -m deck_merger 旗標同義）",
    )
    p.add_argument(
        "--hand-display",
        choices=("stacked", "spread"),
        default=DEFAULT_HAND_DISPLAY,
        metavar="MODE",
        help="與 python -m deck_merger 相同：手牌字串疊加或分開",
    )
    p.add_argument(
        "--learn",
        action="store_true",
        help="局終呼叫模型反思並 append 至 knowhow/<version>/session_notes.md",
    )
    p.add_argument("--max-steps", type=int, default=2000, help="防呆最大步數")
    p.add_argument(
        "--prompt",
        type=Path,
        default=_REPO_ROOT / "scripts/prompts/deck_merger_agent_system.md",
    )
    p.add_argument(
        "--reflect-prompt",
        type=Path,
        default=_REPO_ROOT / "scripts/prompts/deck_merger_reflect_system.md",
    )
    args = p.parse_args()
    hand_display: HandDisplayMode = args.hand_display

    load_dotenv(_REPO_ROOT / ".env")
    model = os.environ.get("DECK_MERGER_LLM_MODEL", "").strip()
    if not model:
        print(
            "錯誤：請設定環境變數 DECK_MERGER_LLM_MODEL（並在 .env 放入對應 provider 的 API key）。\n"
            "可複製 .env.example 為 .env 後編輯。",
            file=sys.stderr,
        )
        sys.exit(2)

    seed = args.seed
    if seed is None and os.environ.get("DECK_MERGER_SEED", "").strip().isdigit():
        seed = int(os.environ["DECK_MERGER_SEED"])

    rules_version = resolved_rules_version()
    kh = load_knowhow_text(_REPO_ROOT, rules_version)
    system_core = _read_text(args.prompt)
    if kh:
        system_full = (
            system_core
            + "\n\n---\n\n## Know-how（規則版本 "
            + rules_version
            + "）\n\n"
            + kh
        )
    else:
        system_full = system_core + (
            f"\n\n（目前無 knowhow/{rules_version}/ 下的 .md 內容，或目錄不存在。）"
        )

    state = bootstrap_state(
        seed=seed,
        skip_opening_relic_draft=args.no_default_relics,
    )

    learn = args.learn or os.environ.get("DECK_MERGER_LEARN", "").strip().lower() in (
        "1",
        "true",
        "yes",
    )

    step = 0
    last_hint: str | None = None
    while step < args.max_steps:
        if state.won or state.lost:
            break
        legal = legal_actions(state)
        if not legal:
            print("無合法動作且未終局，結束。", file=sys.stderr)
            break
        user_msg = _state_user_message(state, hand_display=hand_display, hint=last_hint)
        last_hint = None
        try:
            raw = _completion_content(
                model,
                [
                    {"role": "system", "content": system_full},
                    {"role": "user", "content": user_msg},
                ],
                temperature=0.3,
            )
            kind, cmd_line = _interpret_model_step(raw)
            if kind == "all_actions":
                hints = [legal_action_to_command_hint(state, a) for a in legal]
                last_hint = (
                    "以下為 command_hints（每行為建議文字指令，可複製使用）；"
                    "完整 legal_actions 如下。\ncommand_hints:\n"
                    + json.dumps(hints, ensure_ascii=False, indent=2)
                    + "\n\nlegal_actions:\n"
                    + json.dumps(legal, ensure_ascii=False, indent=2)
                )
                print(
                    json.dumps(
                        {
                            "step": step,
                            "applied": {"op": "all_actions"},
                            "error": None,
                            "won": state.won,
                            "lost": state.lost,
                        },
                        ensure_ascii=False,
                    ),
                    flush=True,
                )
                step += 1
                continue
            assert cmd_line is not None
            action = parse_player_line(cmd_line, state)
        except Exception as e:  # noqa: BLE001
            print(f"模型輸出解析失敗: {e}", file=sys.stderr)
            last_hint = (
                f"解析失敗: {e}。請只輸出**一行**與終端相同之文字指令（例如 merge 1 1、end），"
                "查詢合法步請輸出 all_actions 或 {{\"op\":\"all_actions\"}}。"
            )
            step += 1
            continue

        err = apply_action(state, action)
        print(
            json.dumps(
                {
                    "step": step,
                    "applied": action,
                    "applied_text": cmd_line,
                    "error": err,
                    "won": state.won,
                    "lost": state.lost,
                },
                ensure_ascii=False,
            ),
            flush=True,
        )
        if err and err != "game_over":
            last_hint = (
                f"上一步錯誤碼: {err!r}。請改用與終端相同之一行文字指令；"
                "不確定合法步時可輸出 all_actions 或 {{\"op\":\"all_actions\"}}。"
            )
        step += 1

    print(
        json.dumps(
            {
                "done": True,
                "turn": state.turn,
                "won": state.won,
                "lost": state.lost,
                "loss_reason": state.loss_reason,
                "max_value_ever_seen": state.max_value_ever_seen,
            },
            ensure_ascii=False,
        ),
        flush=True,
    )

    if learn and (state.won or state.lost):
        summary = {
            "rules_version": rules_version,
            "won": state.won,
            "lost": state.lost,
            "loss_reason": state.loss_reason,
            "turn": state.turn,
            "max_value_ever_seen": state.max_value_ever_seen,
            "note_max_value_ever_seen": "歷史最大數字（曾出現於手牌或棄牌堆等，見企劃書 §4.2）",
            "relics": [relic_display_zh(r) for r in state.relics],
            "final_state_excerpt": {
                "energy": state.energy,
                "hand_size": len(state.hand),
                "discard_size": len(state.discard),
                "draw_pile_size": len(state.draw_pile),
            },
        }
        _run_reflect(model, _REPO_ROOT, rules_version, summary, args.reflect_prompt)


if __name__ == "__main__":
    main()
