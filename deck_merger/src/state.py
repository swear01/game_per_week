from dataclasses import dataclass, field
from enum import Enum
from typing import Any

import random


class RelicId(str, Enum):
    CHAIN_GEAR = "chain_gear"
    ONE_MORE = "one_more"
    PERFECT_STORAGE = "perfect_storage"
    STEPPING_STONE = "stepping_stone"
    CAPACITOR = "capacitor"
    ONE_ONE_ONE = "one_one_one"
    FIXED_OVERDRAFT = "fixed_overdraft"
    SCRAP_REUSE = "scrap_reuse"
    MERGE_TO_HAND = "merge_to_hand"
    CALENDAR_BUFFER = "calendar_buffer"
    ASH_TAX = "ash_tax"


ALL_RELICS: tuple[RelicId, ...] = tuple(RelicId)

# 與 doc/企劃書.md §6 對齊，供介面與觀測顯示（內部仍用 RelicId / .value）
RELIC_DISPLAY_ZH: dict[RelicId, str] = {
    RelicId.CHAIN_GEAR: "【連鎖齒輪】",
    RelicId.ONE_MORE: "【One More】",
    RelicId.PERFECT_STORAGE: "【完美收納】",
    RelicId.STEPPING_STONE: "【墊腳石】",
    RelicId.CAPACITOR: "【能量電容器】",
    RelicId.ONE_ONE_ONE: "【1+1+1】",
    RelicId.FIXED_OVERDRAFT: "【定額透支】",
    RelicId.SCRAP_REUSE: "【餘料再利用】",
    RelicId.MERGE_TO_HAND: "【合成回手】",
    RelicId.CALENDAR_BUFFER: "【緩衝日曆】",
    RelicId.ASH_TAX: "【灰燼稅】",
}


def relic_display_zh(r: RelicId) -> str:
    return RELIC_DISPLAY_ZH.get(r, r.value)


# 開局遺物二選一於 relic_offer_queue 使用之階段鍵（非里程碑 1–3）
OPENING_RELIC_PHASE: int = 0


@dataclass
class Card:
    cid: int
    value: int

    def to_json(self) -> dict[str, Any]:
        return {"id": self.cid, "value": self.value}


@dataclass
class GameState:
    draw_pile: list[Card] = field(default_factory=list)
    discard: list[Card] = field(default_factory=list)
    hand: list[Card] = field(default_factory=list)

    energy: int = 3
    turn: int = 1
    merges_this_turn: int = 0
    next_merge_relaxed: bool = False

    max_value_ever_seen: int = 0
    relics: list[RelicId] = field(default_factory=list)
    relic_chosen_phases: set[int] = field(default_factory=set)
    relic_offer_queue: list[tuple[int, tuple[RelicId, RelicId]]] = field(default_factory=list)

    won: bool = False
    lost: bool = False
    loss_reason: str = ""

    next_turn_energy_bonus: int = 0
    ash_exhausts_this_turn: int = 0
    rng: random.Random = field(default_factory=random.Random)

    _next_cid: int = 1

    def observe_card_values(self, cards: list[Card]) -> None:
        for c in cards:
            if c.value > self.max_value_ever_seen:
                self.max_value_ever_seen = c.value

    def check_win(self) -> None:
        """勝利僅由打出牌面 10 觸發（見 cards.play_lexicon）；此處不另判勝。"""
        return

    def to_json(self) -> dict[str, Any]:
        return {
            "draw_pile": [c.to_json() for c in self.draw_pile],
            "discard": [c.to_json() for c in self.discard],
            "hand": [c.to_json() for c in self.hand],
            "energy": self.energy,
            "turn": self.turn,
            "merges_this_turn": self.merges_this_turn,
            "next_merge_relaxed": self.next_merge_relaxed,
            "max_value_ever_seen": self.max_value_ever_seen,
            "relics": [r.value for r in self.relics],
            "relic_chosen_phases": sorted(self.relic_chosen_phases),
            "relic_offer_queue": [
                {"phase": p, "options": [a.value, b.value]}
                for p, (a, b) in self.relic_offer_queue
            ],
            "won": self.won,
            "lost": self.lost,
            "loss_reason": self.loss_reason,
            "next_turn_energy_bonus": self.next_turn_energy_bonus,
            "ash_exhausts_this_turn": self.ash_exhausts_this_turn,
            "_next_cid": self._next_cid,
        }


def new_game(
    seed: int | None = None,
    *,
    skip_opening_relic_draft: bool = False,
) -> GameState:
    rng = random.Random(seed if seed is not None else random.randrange(1 << 30))
    st = GameState(rng=rng)
    if not skip_opening_relic_draft:
        from deck_merger.relics import pick_two_relic_offers

        opts = pick_two_relic_offers(st)
        if opts is not None:
            st.relic_offer_queue.append((OPENING_RELIC_PHASE, opts))
    deck: list[Card] = []
    for _ in range(7):
        deck.append(Card(st._next_cid, 1))
        st._next_cid += 1
    for _ in range(3):
        deck.append(Card(st._next_cid, 2))
        st._next_cid += 1
    rng.shuffle(deck)
    st.draw_pile = deck
    return st


PLAY_EFFECT_MIN_VALUE = 1
PLAY_EFFECT_MAX_VALUE = 9


def card_has_play_effect(card: Card) -> bool:
    """牌面 1–9 可發動對應之 use 效果；牌面 10 為終局打出即獲勝。"""
    if PLAY_EFFECT_MIN_VALUE <= card.value <= PLAY_EFFECT_MAX_VALUE:
        return True
    from deck_merger.rules import WIN_PLAY_FACE_VALUE

    return card.value == WIN_PLAY_FACE_VALUE
