"""精簡觀測（人類／AI 模式共用）：聚合計數 + 手牌文字，不含 legal_actions。"""

from typing import Any

from deck_merger.hand_display import HandDisplayMode, format_hand, zone_counts
from deck_merger.state import GameState, relic_display_zh

DEFAULT_HAND_DISPLAY: HandDisplayMode = "stacked"


def observation_dict(
    state: GameState,
    *,
    hand_display: HandDisplayMode = DEFAULT_HAND_DISPLAY,
) -> dict[str, Any]:
    hand_text = format_hand(state.hand, hand_display)
    return {
        "turn": state.turn,
        "energy": state.energy,
        "merges_this_turn": state.merges_this_turn,
        "next_merge_relaxed": state.next_merge_relaxed,
        "max_value_ever_seen": state.max_value_ever_seen,
        "relics": [relic_display_zh(r) for r in state.relics],
        "relic_offer_queue": [
            {"phase": p, "options": [relic_display_zh(a), relic_display_zh(b)]}
            for p, (a, b) in state.relic_offer_queue
        ],
        "won": state.won,
        "lost": state.lost,
        "loss_reason": state.loss_reason,
        "next_turn_energy_bonus": state.next_turn_energy_bonus,
        "hand_summary": zone_counts(state.hand),
        "hand_display_mode": hand_display,
        "hand_text": hand_text,
        "draw_pile_n": len(state.draw_pile),
        "discard_n": len(state.discard),
    }
