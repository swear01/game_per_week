from typing import Any

from deck_merger.rules import (
    WIN_PLAY_FACE_VALUE,
    add_to_discard,
    draw_n,
    exhaust_card_permanently,
    new_blank_card,
)
from deck_merger.state import Card, GameState, card_has_play_effect


def _find_hand_card(state: GameState, cid: int) -> Card | None:
    for c in state.hand:
        if c.cid == cid:
            return c
    return None


def play_cost(state: GameState, card: Card, payload: dict[str, Any]) -> int | None:
    v = card.value
    if v == 1:
        tid = int(payload["target_id"])
        t = _find_hand_card(state, tid)
        if t is None or t.cid == card.cid:
            return None
        return t.value
    if v == 5:
        tid = int(payload["target_id"])
        t = _find_hand_card(state, tid)
        if t is None or t.cid == card.cid:
            return None
        return t.value
    if v == 2:
        return 1
    if v == 3:
        return 0
    if v == 4:
        return 2
    if v == 6:
        return 2
    if v == 7:
        return 0
    if v == 8:
        if "target_id" not in payload or "target_id_2" not in payload:
            return None
        t1 = _find_hand_card(state, int(payload["target_id"]))
        t2 = _find_hand_card(state, int(payload["target_id_2"]))
        if (
            t1 is None
            or t2 is None
            or t1.cid == card.cid
            or t2.cid == card.cid
            or t1.cid == t2.cid
        ):
            return None
        return 2
    if v == 9:
        if "target_id" not in payload:
            return None
        t = _find_hand_card(state, int(payload["target_id"]))
        if t is None or t.cid == card.cid:
            return None
        return 1
    if v == WIN_PLAY_FACE_VALUE:
        return 0
    return None


def play_lexicon(
    state: GameState,
    card: Card,
    payload: dict[str, Any],
) -> str | None:
    if not card_has_play_effect(card):
        return "not_playable"
    cost = play_cost(state, card, payload)
    if cost is None:
        return "bad_payload"
    if state.energy < cost:
        return "not_enough_energy"
    state.energy -= cost
    if state.energy < 0:
        state.energy = 0
        return "energy_underflow"

    if card.value == 1:
        tid = int(payload["target_id"])
        t = _find_hand_card(state, tid)
        if t is None or t.cid == card.cid or t.value != cost:
            state.energy += cost
            return "invalid_target"
        t.value = 1
        exhaust_card_permanently(state, card)
        draw_n(state, cost)
        state.check_win()
        return None

    if card.value == 2:
        draw_n(state, 2)
        add_to_discard(state, new_blank_card(state, 1))
        exhaust_card_permanently(state, card)
        state.check_win()
        return None

    if card.value == 3:
        state.energy += 2
        add_to_discard(state, new_blank_card(state, 1), new_blank_card(state, 1))
        exhaust_card_permanently(state, card)
        state.check_win()
        return None

    if card.value == 4:
        tid = int(payload["target_id"])
        t = _find_hand_card(state, tid)
        if t is None or t.cid == card.cid:
            state.energy += cost
            return "invalid_target"
        exhaust_card_permanently(state, t)
        exhaust_card_permanently(state, card)
        state.check_win()
        return None

    if card.value == 5:
        tid = int(payload["target_id"])
        t = _find_hand_card(state, tid)
        if t is None or t.cid == card.cid or t.value != cost:
            state.energy += cost
            return "invalid_target"
        clone = Card(state._next_cid, t.value)
        state._next_cid += 1
        state.hand.append(clone)
        state.observe_card_values([clone])
        exhaust_card_permanently(state, card)
        state.check_win()
        return None

    if card.value == 6:
        if len(state.discard) < 2:
            state.energy += cost
            return "discard_too_small"
        taken: list[Card] = []
        for _ in range(2):
            taken.append(state.discard.pop())
        taken.reverse()
        state.hand.extend(taken)
        state.observe_card_values(taken)
        add_to_discard(state, new_blank_card(state, 3), new_blank_card(state, 3))
        exhaust_card_permanently(state, card)
        state.check_win()
        return None

    if card.value == 7:
        moved = list(state.hand)
        state.hand.clear()
        add_to_discard(state, *moved)
        draw_n(state, len(moved))
        state.check_win()
        return None

    if card.value == 8:
        tid = int(payload["target_id"])
        tid2 = int(payload["target_id_2"])
        t1 = _find_hand_card(state, tid)
        t2 = _find_hand_card(state, tid2)
        if (
            t1 is None
            or t2 is None
            or t1.cid == card.cid
            or t2.cid == card.cid
            or t1.cid == t2.cid
        ):
            state.energy += cost
            return "invalid_target"
        exhaust_card_permanently(state, t1)
        exhaust_card_permanently(state, t2)
        exhaust_card_permanently(state, card)
        nine = new_blank_card(state, 9)
        state.hand.append(nine)
        state.observe_card_values([nine])
        state.check_win()
        return None

    if card.value == 9:
        tid = int(payload["target_id"])
        t = _find_hand_card(state, tid)
        if t is None or t.cid == card.cid:
            state.energy += cost
            return "invalid_target"
        v = t.value
        exhaust_card_permanently(state, card)
        for _ in range(9):
            state.draw_pile.append(Card(state._next_cid, v))
            state._next_cid += 1
        state.observe_card_values(state.draw_pile[-9:])
        state.check_win()
        return None

    if card.value == WIN_PLAY_FACE_VALUE:
        exhaust_card_permanently(state, card)
        state.won = True
        return None

    state.energy += cost
    return "unsupported"
