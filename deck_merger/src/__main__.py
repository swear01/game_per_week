import argparse
import json
import sys

from deck_merger.engine import bootstrap_state
from deck_merger.hand_display import HandDisplayMode
from deck_merger.observation import DEFAULT_HAND_DISPLAY, observation_dict
from deck_merger.ui_agent import run_agent_loop
from deck_merger.ui_human import run_human


def main(argv: list[str] | None = None) -> None:
    p = argparse.ArgumentParser(description="deck_merger terminal prototype")
    p.add_argument(
        "--agent",
        action="store_true",
        help="管道模式：stdin 一行文字指令（與人類相同）或 all_actions / {\"op\":\"all_actions\"} 查詢",
    )
    p.add_argument("--seed", type=int, default=None)
    p.add_argument(
        "--no-default-relics",
        action="store_true",
        help="略過開局遺物二選一，零遺物直接開始第一回合（測試／腳本用）",
    )
    p.add_argument(
        "--hand-display",
        choices=("stacked", "spread"),
        default=DEFAULT_HAND_DISPLAY,
        metavar="MODE",
        help="手牌顯示：stacked=疊加（1×k）；spread=分開逐張（人類與 --agent 觀測一致）",
    )
    args = p.parse_args(argv)
    hand_display: HandDisplayMode = args.hand_display

    state = bootstrap_state(
        seed=args.seed,
        skip_opening_relic_draft=args.no_default_relics,
    )
    if args.agent:
        sys.stdout.write(
            json.dumps(
                {
                    "ok": True,
                    "bootstrap": True,
                    "state": observation_dict(state, hand_display=hand_display),
                },
                ensure_ascii=False,
            )
            + "\n"
        )
        sys.stdout.flush()
        run_agent_loop(state, hand_display=hand_display)
    else:
        run_human(state, hand_display=hand_display)


if __name__ == "__main__":
    main(sys.argv[1:])
