"""手牌聚合、疊加／分開顯示（observation 與終端共用）。"""

from collections import Counter
from typing import Any, Literal

from deck_merger.state import Card

HandDisplayMode = Literal["stacked", "spread"]


def zone_counts(cards: list[Card]) -> list[dict[str, Any]]:
    ctr: Counter[int] = Counter()
    for c in cards:
        ctr[c.value] += 1
    return [{"value": v, "n": n} for v, n in sorted(ctr.items())]


def format_hand_stacked(cards: list[Card]) -> str:
    parts = zone_counts(cards)
    if not parts:
        return "（空）"
    return ", ".join(f"{x['value']}×{x['n']}" for x in parts)


def format_hand_spread(cards: list[Card]) -> str:
    if not cards:
        return "（空）"
    return " ".join(str(c.value) for c in cards)


def format_hand(cards: list[Card], mode: HandDisplayMode) -> str:
    return format_hand_stacked(cards) if mode == "stacked" else format_hand_spread(cards)
