from deck_merger.state import GameState, RelicId

ALL_RELICS_LIST = list(RelicId)


def pick_two_relic_offers(state: GameState) -> tuple[RelicId, RelicId] | None:
    """從**尚未持有**的遺物中隨機抽兩個不重複選項（二選一）。若未持有不足兩個則遞減處理。"""
    pool = [r for r in ALL_RELICS_LIST if r not in state.relics]
    n = len(pool)
    if n >= 2:
        a, b = state.rng.sample(pool, k=2)
        return (a, b)
    if n == 1:
        r = pool[0]
        return (r, r)
    return None


def has_relic(state: GameState, r: RelicId) -> bool:
    return r in state.relics
