from deck_merger.relics import has_relic, pick_two_relic_offers
from deck_merger.state import Card, GameState, OPENING_RELIC_PHASE, RelicId

DRAW_PER_TURN = 5
BASE_ENERGY = 3


def base_energy(state: GameState) -> int:
    """每回合重置之基礎能量（不含電容器累加、不含 next_turn_energy_bonus）。"""
    n = BASE_ENERGY
    if has_relic(state, RelicId.FIXED_OVERDRAFT):
        n += 1
    return n


def _phase_check_turn(state: GameState) -> int:
    """階段里程碑檢核用之「日曆回合」：【緩衝日曆】時為實際回合 −1。"""
    if has_relic(state, RelicId.CALENDAR_BUFFER):
        return state.turn - 1
    return state.turn


def draw_count_at_turn_start(state: GameState) -> int:
    extra = sum(1 for r in state.relics if r == RelicId.ONE_MORE)
    return DRAW_PER_TURN + extra


# 階段里程碑（曾持有之牌面數字）；勝利僅能於手牌打出 WIN_PLAY_FACE_VALUE；第 WIN_DEADLINE_TURN 回合結束仍未打出則敗北。
PHASE_THRESHOLDS = ((1, 4), (2, 6), (3, 8))
PHASE_DEADLINE_TURNS = {1: 3, 2: 6, 3: 10}
WIN_PLAY_FACE_VALUE = 10
WIN_DEADLINE_TURN = 15

_PHASE_NEED = dict(PHASE_THRESHOLDS)


def _pop_card_from_zone(card: Card, zone: list[Card]) -> bool:
    try:
        i = next(i for i, c in enumerate(zone) if c.cid == card.cid)
        zone.pop(i)
        return True
    except StopIteration:
        return False


def remove_card_from_hand(state: GameState, cid: int) -> Card | None:
    for i, c in enumerate(state.hand):
        if c.cid == cid:
            return state.hand.pop(i)
    return None


def add_to_discard(state: GameState, *cards: Card) -> None:
    for c in cards:
        state.discard.append(c)
    state.observe_card_values(list(cards))
    state.check_win()


def ensure_draw_pile(state: GameState) -> None:
    if state.draw_pile:
        return
    if not state.discard:
        return
    state.draw_pile = state.discard[:]
    state.discard.clear()
    state.rng.shuffle(state.draw_pile)


def draw_n(state: GameState, n: int) -> None:
    for _ in range(n):
        ensure_draw_pile(state)
        if not state.draw_pile:
            break
        state.hand.append(state.draw_pile.pop())


def new_blank_card(state: GameState, value: int) -> Card:
    c = Card(state._next_cid, value)
    state._next_cid += 1
    return c


def merge_relaxed_allowed(state: GameState) -> bool:
    return state.next_merge_relaxed or has_relic(state, RelicId.STEPPING_STONE)


def can_pair_merge(state: GameState, a: Card, b: Card) -> bool:
    if has_relic(state, RelicId.ONE_ONE_ONE):
        return False
    if a.cid == b.cid:
        return False
    if merge_relaxed_allowed(state):
        if abs(a.value - b.value) == 1:
            return True
    return a.value == b.value


def pair_merge_result_value(state: GameState, a: Card, b: Card) -> int | None:
    if not can_pair_merge(state, a, b):
        return None
    if a.value == b.value:
        return a.value + 1
    if merge_relaxed_allowed(state) and abs(a.value - b.value) == 1:
        return max(a.value, b.value)
    return None


def can_triple_merge(state: GameState, a: Card, b: Card, c: Card) -> bool:
    if not has_relic(state, RelicId.ONE_ONE_ONE):
        return False
    if len({a.cid, b.cid, c.cid}) != 3:
        return False
    return a.value == b.value == c.value


def triple_merge_result_value(_state: GameState, a: Card, b: Card, c: Card) -> int | None:
    if not can_triple_merge(_state, a, b, c):
        return None
    return a.value + 2


def _take_from_hand(state: GameState, card: Card) -> bool:
    return _pop_card_from_zone(card, state.hand)


def do_pair_merge(state: GameState, a: Card, b: Card) -> str | None:
    if (
        not has_relic(state, RelicId.ONE_ONE_ONE)
        and a.cid != b.cid
        and abs(a.value - b.value) == 1
        and not merge_relaxed_allowed(state)
    ):
        return "adjacent_merge_unavailable"
    v = pair_merge_result_value(state, a, b)
    if v is None:
        return "invalid_merge"
    if not (_take_from_hand(state, a) and _take_from_hand(state, b)):
        return "card_not_found"
    if state.next_merge_relaxed and not has_relic(state, RelicId.STEPPING_STONE):
        state.next_merge_relaxed = False
    prod = new_blank_card(state, v)
    add_to_discard(state, a, b)
    if has_relic(state, RelicId.MERGE_TO_HAND):
        state.hand.append(prod)
        state.observe_card_values([prod])
    else:
        add_to_discard(state, prod)
    if has_relic(state, RelicId.SCRAP_REUSE):
        add_to_discard(state, new_blank_card(state, max(1, v - 1)))
    state.merges_this_turn += 1
    if has_relic(state, RelicId.CHAIN_GEAR) and state.merges_this_turn % 3 == 0:
        state.energy += 1
    state.check_win()
    return None


def do_triple_merge(state: GameState, a: Card, b: Card, c: Card) -> str | None:
    v = triple_merge_result_value(state, a, b, c)
    if v is None:
        return "invalid_merge"
    if not (_take_from_hand(state, a) and _take_from_hand(state, b) and _take_from_hand(state, c)):
        return "card_not_found"
    prod = new_blank_card(state, v)
    add_to_discard(state, a, b, c)
    if has_relic(state, RelicId.MERGE_TO_HAND):
        state.hand.append(prod)
        state.observe_card_values([prod])
    else:
        add_to_discard(state, prod)
    if has_relic(state, RelicId.SCRAP_REUSE):
        add_to_discard(state, new_blank_card(state, max(1, v - 1)))
    state.merges_this_turn += 1
    if has_relic(state, RelicId.CHAIN_GEAR) and state.merges_this_turn % 3 == 0:
        state.energy += 1
    state.check_win()
    return None


def _phase_satisfied(state: GameState, phase: int) -> bool:
    return state.max_value_ever_seen >= _PHASE_NEED[phase]


def _phase_fail_at_turn_end(state: GameState) -> str | None:
    t = _phase_check_turn(state)
    for phase, need in PHASE_THRESHOLDS:
        deadline = PHASE_DEADLINE_TURNS[phase]
        if t == deadline and not _phase_satisfied(state, phase):
            return (
                f"階段 {phase} 未達標：第 {state.turn} 回合結束時，"
                f"「歷史最大數字」須至少 {need}，但未達成。"
            )
    return None


def _win_deadline_fail_at_turn_end(state: GameState) -> str | None:
    if state.turn == WIN_DEADLINE_TURN and not state.won:
        return (
            f"第 {WIN_DEADLINE_TURN} 回合結束時仍未勝利："
            f"須從手牌打出牌面【{WIN_PLAY_FACE_VALUE}】（use {WIN_PLAY_FACE_VALUE}）以獲勝。"
        )
    return None


def _enqueue_relic_offers(state: GameState) -> None:
    already_queued = {p for p, _ in state.relic_offer_queue}
    for phase, _need in PHASE_THRESHOLDS:
        if phase in state.relic_chosen_phases or phase in already_queued:
            continue
        if _phase_satisfied(state, phase):
            opts = pick_two_relic_offers(state)
            if opts is None:
                state.relic_chosen_phases.add(phase)
                continue
            state.relic_offer_queue.append((phase, opts))


def discard_hand(state: GameState) -> None:
    moved = state.hand[:]
    state.hand.clear()
    for c in moved:
        state.discard.append(c)
    state.observe_card_values(moved)
    state.check_win()


def _apply_start_of_turn_energy(state: GameState) -> None:
    bonus = state.next_turn_energy_bonus
    state.next_turn_energy_bonus = 0
    base = base_energy(state)
    if has_relic(state, RelicId.CAPACITOR):
        state.energy += base + bonus
    else:
        state.energy = base + bonus
    if state.energy < 0:
        state.energy = 0


def begin_next_turn(state: GameState) -> None:
    state.turn += 1
    ash_extra = state.ash_exhausts_this_turn
    state.ash_exhausts_this_turn = 0
    state.merges_this_turn = 0
    state.next_merge_relaxed = False
    _apply_start_of_turn_energy(state)
    draw_n(state, draw_count_at_turn_start(state) + ash_extra)


def start_first_turn(state: GameState) -> None:
    state.observe_card_values(state.hand + state.discard + state.draw_pile)
    draw_n(state, draw_count_at_turn_start(state))
    if has_relic(state, RelicId.CAPACITOR) and has_relic(state, RelicId.FIXED_OVERDRAFT):
        # 開局 `GameState.energy` 預設 3；第一次回合開始須與「電容器 += 基礎」銜接（3 + 4 = 7）
        state.energy += base_energy(state) + state.next_turn_energy_bonus
    elif not has_relic(state, RelicId.CAPACITOR):
        state.energy = base_energy(state) + state.next_turn_energy_bonus
    state.check_win()


def end_turn(state: GameState) -> str | None:
    if state.won or state.lost:
        return "game_over"

    cleared = len(state.hand) == 0
    if has_relic(state, RelicId.PERFECT_STORAGE) and cleared:
        state.next_turn_energy_bonus += 1

    discard_hand(state)

    if state.won:
        return None

    reason = _phase_fail_at_turn_end(state)
    if reason:
        state.lost = True
        state.loss_reason = reason
        return None

    if state.won:
        return None

    reason = _win_deadline_fail_at_turn_end(state)
    if reason:
        state.lost = True
        state.loss_reason = reason
        return None

    if state.won:
        return None

    _enqueue_relic_offers(state)

    if state.relic_offer_queue:
        return None

    begin_next_turn(state)
    return None


def apply_relic_choice(state: GameState, index: int) -> str | None:
    if not state.relic_offer_queue or index not in (0, 1):
        return "invalid_relic_pick"
    phase, (a, b) = state.relic_offer_queue.pop(0)
    chosen = a if index == 0 else b
    if chosen not in state.relics:
        state.relics.append(chosen)
    state.relic_chosen_phases.add(phase)
    if not state.relic_offer_queue and not state.won and not state.lost:
        if phase == OPENING_RELIC_PHASE:
            start_first_turn(state)
        else:
            begin_next_turn(state)
    return None


def exhaust_card_permanently(state: GameState, card: Card) -> None:
    remove_card_from_hand(state, card.cid)
    if has_relic(state, RelicId.ASH_TAX):
        state.ash_exhausts_this_turn += 1
