from deck_merger.engine import apply_action
from deck_merger.hand_display import HandDisplayMode, format_hand
from deck_merger.observation import DEFAULT_HAND_DISPLAY
from deck_merger.state import OPENING_RELIC_PHASE, GameState, relic_display_zh
from deck_merger.ui_commands import cards_help_text, parse_player_line, player_help_text

_ERR_ZH: dict[str, str] = {
    "adjacent_merge_unavailable": (
        "無法以相差 1 的兩張合成：須持有遺物【墊腳石】（永久放寬）。"
    ),
}


def _is_cards_help_line(raw: str) -> bool:
    parts = raw.strip().lower().split()
    return len(parts) == 2 and parts[0] == "help" and parts[1] == "cards"


def _print_state(state: GameState, hand_display: HandDisplayMode) -> None:
    print("\n--- 狀態 ---")
    print(
        f"回合 {state.turn}  能量 {state.energy}  "
        f"歷史最大數字 {state.max_value_ever_seen}"
    )
    if state.relics:
        print("遺物:", ", ".join(relic_display_zh(r) for r in state.relics))
    if state.relic_offer_queue:
        q = state.relic_offer_queue[0]
        phase_label = "開局" if q[0] == OPENING_RELIC_PHASE else f"階段 {q[0]}"
        print(
            f"遺物選擇（{phase_label}）: [0] {relic_display_zh(q[1][0])}  "
            f"[1] {relic_display_zh(q[1][1])}"
        )
    mode_zh = "疊加" if hand_display == "stacked" else "分開"
    print(f"手牌: {format_hand(state.hand, hand_display)}")
    print(f"抽牌堆 {len(state.draw_pile)}  棄牌堆 {len(state.discard)}")
    if state.won:
        print(">>> 勝利 <<<")
    if state.lost:
        print(">>> 敗北 <<<")
        print(state.loss_reason.strip() or "已敗北。（無法取得詳細原因）")
    print("------------")


def run_human_loop(
    state: GameState,
    *,
    hand_display: HandDisplayMode = DEFAULT_HAND_DISPLAY,
) -> None:
    print(player_help_text())
    while not state.won and not state.lost:
        _print_state(state, hand_display)
        raw = input("> ").strip().rstrip("\\")
        if not raw:
            continue
        if raw.lower() in ("q", "quit", "exit"):
            return
        if raw.lower() in ("help", "h", "?"):
            print(player_help_text())
            continue
        if _is_cards_help_line(raw):
            print(cards_help_text())
            continue
        try:
            act = parse_player_line(raw, state)
        except ValueError as e:
            print("解析錯誤:", e)
            continue
        err = apply_action(state, act)
        if err:
            detail = _ERR_ZH.get(err, err)
            print("錯誤:", detail)
    _print_state(state, hand_display)


def run_human(
    state: GameState,
    *,
    hand_display: HandDisplayMode = DEFAULT_HAND_DISPLAY,
) -> None:
    run_human_loop(state, hand_display=hand_display)
