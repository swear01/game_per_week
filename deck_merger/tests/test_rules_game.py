"""遊戲規則與引擎邊界：合併、打牌、遺物、階段敗北。"""

from deck_merger.engine import apply_action, bootstrap_state, legal_actions
from deck_merger.rules import (
    BASE_ENERGY,
    DRAW_PER_TURN,
    PHASE_DEADLINE_TURNS,
    begin_next_turn,
    can_pair_merge,
    do_pair_merge,
    end_turn,
)
from deck_merger.state import Card, RelicId


def test_adjacent_merge_without_relaxed_returns_error():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    c1 = Card(st._next_cid, 1)
    st._next_cid += 1
    c2 = Card(st._next_cid, 2)
    st._next_cid += 1
    st.hand = [c1, c2]
    st.next_merge_relaxed = False
    assert not can_pair_merge(st, c1, c2)
    err = apply_action(st, {"op": "merge", "ids": sorted([c1.cid, c2.cid])})
    assert err == "adjacent_merge_unavailable"


def test_play_value_2_draws_two_adds_one_to_discard_exhausts():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    c2_play = Card(st._next_cid, 2)
    st._next_cid += 1
    d1 = Card(st._next_cid, 5)
    st._next_cid += 1
    d2 = Card(st._next_cid, 7)
    st._next_cid += 1
    st.hand = [c2_play]
    st.draw_pile = [d1, d2]
    st.energy = 3
    e0 = st.energy
    ones_before = sum(1 for x in st.discard if x.value == 1)
    assert apply_action(st, {"op": "play", "card_id": c2_play.cid, "payload": {}}) is None
    assert st.energy == e0 - 1
    assert c2_play not in st.hand
    assert st.next_merge_relaxed is False
    assert {c.cid for c in st.hand} == {d1.cid, d2.cid}
    assert sum(1 for x in st.discard if x.value == 1) == ones_before + 1


def test_stepping_stone_allows_adjacent_merge_without_play():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    st.relics.append(RelicId.STEPPING_STONE)
    c1 = Card(st._next_cid, 1)
    st._next_cid += 1
    c2 = Card(st._next_cid, 2)
    st._next_cid += 1
    st.hand = [c1, c2]
    assert can_pair_merge(st, c1, c2)
    assert apply_action(st, {"op": "merge", "ids": sorted([c1.cid, c2.cid])}) is None


def test_one_one_one_blocks_pair_merge_even_equal_values():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    st.relics.append(RelicId.ONE_ONE_ONE)
    a = Card(st._next_cid, 1)
    st._next_cid += 1
    b = Card(st._next_cid, 1)
    st._next_cid += 1
    st.hand = [a, b]
    assert not can_pair_merge(st, a, b)
    err = apply_action(st, {"op": "merge", "ids": sorted([a.cid, b.cid])})
    assert err == "invalid_merge"


def test_one_one_one_triple_merge_produces_value_plus_two():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    st.relics.append(RelicId.ONE_ONE_ONE)
    a = Card(st._next_cid, 1)
    st._next_cid += 1
    b = Card(st._next_cid, 1)
    st._next_cid += 1
    c = Card(st._next_cid, 1)
    st._next_cid += 1
    st.hand = [a, b, c]
    err = apply_action(st, {"op": "merge3", "ids": sorted([a.cid, b.cid, c.cid])})
    assert err is None
    assert st.max_value_ever_seen >= 3


def test_chain_gear_grants_energy_on_every_third_merge_this_turn():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    st.relics.append(RelicId.CHAIN_GEAR)
    a = Card(st._next_cid, 1)
    st._next_cid += 1
    b = Card(st._next_cid, 1)
    st._next_cid += 1
    st.hand = [a, b]
    st.merges_this_turn = 2
    e0 = st.energy
    assert do_pair_merge(st, a, b) is None
    assert st.merges_this_turn == 3
    assert st.energy == e0 + 1


def test_phase_two_loss_at_deadline_turn_six():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    st.max_value_ever_seen = 5
    st.turn = PHASE_DEADLINE_TURNS[2]
    st.hand = []
    end_turn(st)
    assert st.lost
    assert "階段 2" in st.loss_reason
    assert str(PHASE_DEADLINE_TURNS[2]) in st.loss_reason


def test_perfect_storage_empty_hand_grants_next_turn_energy():
    """空牌結束回合時加成能量；須避免 max 已達階段門檻而進入遺物二選一（會擋下 begin_next_turn）。"""
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    st.relics.append(RelicId.PERFECT_STORAGE)
    st.max_value_ever_seen = 3
    st.turn = 2
    st.hand.clear()
    apply_action(st, {"op": "end_turn"})
    assert not st.lost
    assert not st.relic_offer_queue
    assert st.energy == BASE_ENERGY + 1


def test_play_value_3_adds_energy_and_two_ones_to_discard():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    c3 = Card(st._next_cid, 3)
    st._next_cid += 1
    st.hand = [c3]
    e0 = st.energy
    assert apply_action(st, {"op": "play", "card_id": c3.cid, "payload": {}}) is None
    assert st.energy == e0 + 2
    assert c3 not in st.hand
    assert sum(1 for x in st.discard if x.value == 1) >= 2


def test_play_value_4_exhausts_target_and_self():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    c4 = Card(st._next_cid, 4)
    st._next_cid += 1
    tgt = Card(st._next_cid, 5)
    st._next_cid += 1
    st.hand = [c4, tgt]
    st.energy = 3
    assert (
        apply_action(
            st,
            {"op": "play", "card_id": c4.cid, "payload": {"target_id": tgt.cid}},
        )
        is None
    )
    assert c4 not in st.hand and tgt not in st.hand


def test_play_value_5_clones_target_in_hand():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    c5 = Card(st._next_cid, 5)
    st._next_cid += 1
    tgt = Card(st._next_cid, 3)
    st._next_cid += 1
    st.hand = [c5, tgt]
    st.energy = 5
    hand_before = len(st.hand)
    assert (
        apply_action(
            st,
            {"op": "play", "card_id": c5.cid, "payload": {"target_id": tgt.cid}},
        )
        is None
    )
    assert len(st.hand) == hand_before
    assert sum(1 for c in st.hand if c.value == 3) == 2
    assert c5 not in st.hand


def test_merge3_bad_id_count_returns_bad_merge3():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    a = Card(st._next_cid, 1)
    st._next_cid += 1
    b = Card(st._next_cid, 1)
    st._next_cid += 1
    st.hand = [a, b]
    err = apply_action(st, {"op": "merge3", "ids": [a.cid, b.cid]})
    assert err == "bad_merge3"


def test_legal_actions_includes_merge3_when_one_one_one_and_three_same():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    st.relics.append(RelicId.ONE_ONE_ONE)
    st.hand.clear()
    for _ in range(3):
        st.hand.append(Card(st._next_cid, 2))
        st._next_cid += 1
    acts = legal_actions(st)
    assert any(a["op"] == "merge3" for a in acts)


def test_draw_count_one_more_relic():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    from deck_merger.rules import draw_count_at_turn_start

    assert draw_count_at_turn_start(st) == DRAW_PER_TURN
    st.relics.append(RelicId.ONE_MORE)
    assert draw_count_at_turn_start(st) == DRAW_PER_TURN + 1


def test_begin_next_turn_draws_one_more_when_relic_owned():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    st.relics.append(RelicId.ONE_MORE)
    st.hand.clear()
    st.discard.clear()
    for _ in range(12):
        st.draw_pile.append(Card(st._next_cid, 1))
        st._next_cid += 1
    begin_next_turn(st)
    assert len(st.hand) == DRAW_PER_TURN + 1


def test_play_value_6_moves_discard_top_two_to_hand_and_adds_two_threes():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    d1 = Card(st._next_cid, 4)
    st._next_cid += 1
    d2 = Card(st._next_cid, 5)
    st._next_cid += 1
    st.discard.extend([d1, d2])
    c6 = Card(st._next_cid, 6)
    st._next_cid += 1
    st.hand = [c6]
    st.energy = 3
    assert apply_action(st, {"op": "play", "card_id": c6.cid, "payload": {}}) is None
    assert c6 not in st.hand
    assert len(st.discard) == 2
    assert all(x.value == 3 for x in st.discard)
    assert {c.cid for c in st.hand} == {d1.cid, d2.cid}


def test_play_value_7_moves_all_hand_to_discard_then_draws_same_count():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    c7 = Card(st._next_cid, 7)
    st._next_cid += 1
    o = Card(st._next_cid, 2)
    st._next_cid += 1
    st.hand = [c7, o]
    for _ in range(10):
        st.draw_pile.append(Card(st._next_cid, 1))
        st._next_cid += 1
    n_draw = len(st.draw_pile)
    assert apply_action(st, {"op": "play", "card_id": c7.cid, "payload": {}}) is None
    assert len(st.discard) == 2
    assert c7 in st.discard and o in st.discard
    assert len(st.hand) == 2
    assert len(st.draw_pile) == n_draw - 2


def test_play_value_8_exhausts_two_targets_and_self_puts_nine_in_hand():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    c8 = Card(st._next_cid, 8)
    st._next_cid += 1
    a = Card(st._next_cid, 1)
    st._next_cid += 1
    b = Card(st._next_cid, 2)
    st._next_cid += 1
    st.hand = [c8, a, b]
    st.energy = 3
    assert (
        apply_action(
            st,
            {
                "op": "play",
                "card_id": c8.cid,
                "payload": {"target_id": a.cid, "target_id_2": b.cid},
            },
        )
        is None
    )
    assert len(st.hand) == 1 and st.hand[0].value == 9


def test_play_value_9_appends_nine_copies_to_draw_pile():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    c9 = Card(st._next_cid, 9)
    st._next_cid += 1
    tgt = Card(st._next_cid, 2)
    st._next_cid += 1
    st.hand = [c9, tgt]
    st.energy = 2
    dp0 = len(st.draw_pile)
    assert (
        apply_action(
            st,
            {"op": "play", "card_id": c9.cid, "payload": {"target_id": tgt.cid}},
        )
        is None
    )
    assert c9 not in st.hand
    assert len(st.draw_pile) == dp0 + 9
    assert all(c.value == 2 for c in st.draw_pile[-9:])
