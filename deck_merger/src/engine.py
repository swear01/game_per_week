from typing import Any

from deck_merger.cards import play_cost, play_lexicon
from deck_merger.rules import (
    WIN_PLAY_FACE_VALUE,
    apply_relic_choice,
    can_pair_merge,
    can_triple_merge,
    do_pair_merge,
    do_triple_merge,
    end_turn,
    start_first_turn,
)
from deck_merger.state import Card, GameState, card_has_play_effect, new_game


def bootstrap_state(
    seed: int | None = None,
    *,
    skip_opening_relic_draft: bool = False,
) -> GameState:
    st = new_game(
        seed,
        skip_opening_relic_draft=skip_opening_relic_draft,
    )
    if not st.relic_offer_queue:
        start_first_turn(st)
    return st


def _cards_in_hand(state: GameState) -> list[Card]:
    return state.hand


def _card_by_id(state: GameState, cid: int) -> Card | None:
    for c in _cards_in_hand(state):
        if c.cid == cid:
            return c
    return None


def _legal_action_key(a: dict[str, Any]) -> tuple[Any, ...]:
    """可雜湊鍵，供 legal_actions 去重（結構與引擎產出之動作一致）。"""
    op = a["op"]
    if op in ("merge", "merge3"):
        return (op, tuple(sorted(int(x) for x in a["ids"])))
    if op == "play":
        cid = int(a["card_id"])
        pl = a.get("payload") or {}
        frozen_pl = tuple((str(k), int(pl[k])) for k in sorted(pl.keys()))
        return ("play", cid, frozen_pl)
    if op == "end_turn":
        return ("end_turn",)
    raise AssertionError(f"unexpected legal action op: {op!r}")


def legal_actions(state: GameState) -> list[dict[str, Any]]:
    if state.won or state.lost:
        return []
    if state.relic_offer_queue:
        return [
            {"op": "pick_relic", "index": 0},
            {"op": "pick_relic", "index": 1},
        ]

    acts: list[dict[str, Any]] = []
    seen: set[tuple[Any, ...]] = set()

    def add_act(a: dict[str, Any]) -> None:
        key = _legal_action_key(a)
        if key not in seen:
            seen.add(key)
            acts.append(a)

    cards = _cards_in_hand(state)
    for i, a in enumerate(cards):
        for b in cards[i + 1 :]:
            if can_pair_merge(state, a, b):
                ids = sorted([a.cid, b.cid])
                add_act({"op": "merge", "ids": ids})
        for j in range(i + 1, len(cards)):
            for k in range(j + 1, len(cards)):
                b, c3 = cards[j], cards[k]
                if can_triple_merge(state, a, b, c3):
                    ids = sorted([a.cid, b.cid, c3.cid])
                    add_act({"op": "merge3", "ids": ids})

    for card in list(state.hand):
        if not card_has_play_effect(card):
            continue
        if card.value in (2, 3, WIN_PLAY_FACE_VALUE):
            cost = play_cost(state, card, {})
            if cost is not None and state.energy >= cost:
                add_act({"op": "play", "card_id": card.cid, "payload": {}})
        elif card.value == 6:
            cost = play_cost(state, card, {})
            if (
                cost is not None
                and state.energy >= cost
                and len(state.discard) >= 2
            ):
                add_act({"op": "play", "card_id": card.cid, "payload": {}})
        elif card.value == 7:
            cost = play_cost(state, card, {})
            if cost is not None and state.energy >= cost:
                add_act({"op": "play", "card_id": card.cid, "payload": {}})
        elif card.value == 8:
            if state.energy < 2:
                continue
            others = [c for c in state.hand if c.cid != card.cid]
            for i, a in enumerate(others):
                for b in others[i + 1 :]:
                    add_act(
                        {
                            "op": "play",
                            "card_id": card.cid,
                            "payload": {
                                "target_id": a.cid,
                                "target_id_2": b.cid,
                            },
                        }
                    )
        elif card.value == 9:
            for t in state.hand:
                if t.cid == card.cid:
                    continue
                payload = {"target_id": t.cid}
                cost = play_cost(state, card, payload)
                if cost is not None and state.energy >= cost:
                    add_act({"op": "play", "card_id": card.cid, "payload": payload})
        elif card.value in (1, 5):
            for t in state.hand:
                if t.cid == card.cid:
                    continue
                payload = {"target_id": t.cid}
                cost = play_cost(state, card, payload)
                if cost is not None and state.energy >= cost:
                    add_act({"op": "play", "card_id": card.cid, "payload": payload})
        elif card.value == 4:
            if state.energy < 2:
                continue
            for t in state.hand:
                if t.cid == card.cid:
                    continue
                add_act(
                    {
                        "op": "play",
                        "card_id": card.cid,
                        "payload": {"target_id": t.cid},
                    }
                )

    add_act({"op": "end_turn"})
    return acts


def apply_action(state: GameState, action: dict[str, Any]) -> str | None:
    if state.won or state.lost:
        return "game_over"
    op = action.get("op")
    if state.relic_offer_queue:
        if op != "pick_relic":
            return "relic_choice_pending"
        idx = int(action.get("index", -1))
        return apply_relic_choice(state, idx)

    if op == "merge":
        ids = action.get("ids")
        if not ids or len(ids) != 2:
            return "bad_merge"
        a = _card_by_id(state, int(ids[0]))
        b = _card_by_id(state, int(ids[1]))
        if a is None or b is None:
            return "card_not_found"
        return do_pair_merge(state, a, b)

    if op == "merge3":
        ids = action.get("ids")
        if not ids or len(ids) != 3:
            return "bad_merge3"
        cs = [_card_by_id(state, int(x)) for x in ids]
        if any(c is None for c in cs):
            return "card_not_found"
        return do_triple_merge(state, cs[0], cs[1], cs[2])

    if op == "play":
        cid = int(action["card_id"])
        card = _card_by_id(state, cid)
        if card is None or card not in state.hand:
            return "not_in_hand"
        payload = dict(action.get("payload") or {})
        return play_lexicon(state, card, payload)

    if op == "end_turn":
        end_turn(state)
        return None

    return "unknown_op"
