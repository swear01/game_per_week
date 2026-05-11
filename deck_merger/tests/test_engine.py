import io
import json

from deck_merger.engine import apply_action, bootstrap_state, legal_actions
from deck_merger.observation import observation_dict
from deck_merger.relics import ALL_RELICS_LIST, pick_two_relic_offers
from deck_merger.rules import (
    DRAW_PER_TURN,
    WIN_DEADLINE_TURN,
    WIN_PLAY_FACE_VALUE,
    draw_count_at_turn_start,
)
from deck_merger.state import Card, RelicId
from deck_merger.ui_agent import run_agent_loop


def test_relic_offers_only_from_unowned_pool():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    st.relics.extend(
        [
            RelicId.CHAIN_GEAR,
            RelicId.CAPACITOR,
            RelicId.PERFECT_STORAGE,
            RelicId.ONE_ONE_ONE,
        ]
    )
    pair = pick_two_relic_offers(st)
    assert pair is not None
    a, b = pair
    owned = {
        RelicId.CHAIN_GEAR,
        RelicId.CAPACITOR,
        RelicId.PERFECT_STORAGE,
        RelicId.ONE_ONE_ONE,
    }
    assert a not in owned and b not in owned
    pool_ids = [r for r in ALL_RELICS_LIST if r not in owned]
    assert a in pool_ids and b in pool_ids


def test_opening_relic_draft_then_first_draw():
    st = bootstrap_state(seed=0)
    assert st.relic_offer_queue
    assert len(st.hand) == 0
    acts = legal_actions(st)
    assert all(a["op"] == "pick_relic" for a in acts)
    err = apply_action(st, {"op": "pick_relic", "index": 0})
    assert err is None
    assert not st.relic_offer_queue
    assert len(st.relics) == 1
    assert len(st.hand) == draw_count_at_turn_start(st)


def test_skip_opening_relic_zero_relics_and_first_draw():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    assert not st.relic_offer_queue
    assert st.relics == []
    assert len(st.hand) == DRAW_PER_TURN


def test_merge_all_go_to_discard_and_increases_max():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    assert len(st.hand) == DRAW_PER_TURN
    ones = [c for c in st.hand if c.value == 1]
    if len(ones) < 2:
        return
    a, b = ones[0], ones[1]
    err = apply_action(st, {"op": "merge", "ids": sorted([a.cid, b.cid])})
    assert err is None
    assert st.max_value_ever_seen >= 2
    assert all(c.cid not in {x.cid for x in st.hand} for c in (a, b))
    assert len(st.discard) >= 3


def test_legal_actions_merge_deduped():
    st = bootstrap_state(seed=1, skip_opening_relic_draft=True)
    ones = [c for c in st.hand if c.value == 1]
    if len(ones) < 2:
        return
    acts = legal_actions(st)
    merge_ops = [a for a in acts if a["op"] == "merge"]
    keys = {json.dumps(a, sort_keys=True) for a in merge_ops}
    assert len(keys) == len(merge_ops)


def test_play_face_value_3_energy():
    st = bootstrap_state(seed=2, skip_opening_relic_draft=True)
    c3 = Card(st._next_cid, 3)
    st._next_cid += 1
    st.hand.append(c3)
    e0 = st.energy
    err = apply_action(st, {"op": "play", "card_id": c3.cid, "payload": {}})
    assert err is None
    assert st.energy == e0 + 2


def test_play_face_value_1_costs_target_value_energy_draws_that_many():
    st = bootstrap_state(seed=2, skip_opening_relic_draft=True)
    c1 = Card(st._next_cid, 1)
    st._next_cid += 1
    c_target = Card(st._next_cid, 2)
    st._next_cid += 1
    st.hand.extend([c1, c_target])
    st.energy = 3
    draw0 = len(st.draw_pile)
    e0 = st.energy
    err = apply_action(
        st,
        {"op": "play", "card_id": c1.cid, "payload": {"target_id": c_target.cid}},
    )
    assert err is None
    assert st.energy == e0 - 2
    assert c_target.value == 1
    assert len(st.draw_pile) == draw0 - 2


def test_phase_loss_turn_3():
    st = bootstrap_state(seed=3, skip_opening_relic_draft=True)
    st.max_value_ever_seen = 0
    while st.turn < 3:
        apply_action(st, {"op": "end_turn"})
        assert not st.lost
    apply_action(st, {"op": "end_turn"})
    assert st.lost
    assert "階段 1" in st.loss_reason
    assert "第 3 回合" in st.loss_reason
    assert "4" in st.loss_reason


def test_win_by_playing_face_ten():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    c10 = Card(st._next_cid, WIN_PLAY_FACE_VALUE)
    st._next_cid += 1
    st.hand.append(c10)
    err = apply_action(st, {"op": "play", "card_id": c10.cid, "payload": {}})
    assert err is None
    assert st.won
    assert legal_actions(st) == []


def test_max_ten_without_play_does_not_win():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    st.max_value_ever_seen = WIN_PLAY_FACE_VALUE
    st.check_win()
    assert not st.won


def test_win_deadline_loss_turn_15():
    """階段已滿足但未達勝利門檻時，第 15 回合結束判敗。"""
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    st.max_value_ever_seen = 9
    for _ in range(400):
        if st.lost or st.won:
            break
        acts = legal_actions(st)
        if any(a["op"] == "pick_relic" for a in acts):
            err = apply_action(st, {"op": "pick_relic", "index": 0})
            assert err is None
        else:
            err = apply_action(st, {"op": "end_turn"})
            assert err is None
    assert st.lost
    assert str(WIN_DEADLINE_TURN) in st.loss_reason
    assert str(WIN_PLAY_FACE_VALUE) in st.loss_reason
    assert "use" in st.loss_reason


def test_relic_choice_blocks_other_ops():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    st.max_value_ever_seen = 4
    apply_action(st, {"op": "end_turn"})
    if not st.relic_offer_queue:
        return
    err = apply_action(st, {"op": "end_turn"})
    assert err == "relic_choice_pending"
    acts = legal_actions(st)
    assert all(a["op"] == "pick_relic" for a in acts)
    err = apply_action(st, {"op": "pick_relic", "index": 0})
    assert err is None
    assert len(st.relics) >= 1


def test_agent_all_actions_line_and_observation():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    out = io.StringIO()
    inp = io.StringIO("all_actions\n")
    run_agent_loop(st, inp=inp, out=out)
    line = out.getvalue().strip().split("\n")[-1]
    obj = json.loads(line)
    assert obj["ok"] is True
    assert obj["query"] == "all_actions"
    assert "legal_actions" in obj
    assert "command_hints" in obj
    assert len(obj["command_hints"]) == len(obj["legal_actions"])
    assert "hand_summary" in obj["state"]
    assert "hand_text" in obj["state"]
    assert obj["state"] == observation_dict(st)


def test_agent_rejects_non_query_json_action():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    ones = [c for c in st.hand if c.value == 1]
    if len(ones) < 2:
        return
    out = io.StringIO()
    bad = json.dumps({"op": "merge", "ids": sorted([ones[0].cid, ones[1].cid])}) + "\n"
    inp = io.StringIO(bad)
    run_agent_loop(st, inp=inp, out=out)
    line = out.getvalue().strip().split("\n")[-1]
    obj = json.loads(line)
    assert obj["ok"] is False
    assert "error" in obj


def test_fixed_overdraft_sets_energy_four_after_start_first_turn():
    from deck_merger.rules import start_first_turn
    from deck_merger.state import new_game

    st = new_game(seed=0, skip_opening_relic_draft=True)
    st.relics.append(RelicId.FIXED_OVERDRAFT)
    start_first_turn(st)
    assert st.energy == 4


def test_capacitor_and_overdraft_first_turn_energy_seven():
    from deck_merger.rules import start_first_turn
    from deck_merger.state import new_game

    st = new_game(seed=0, skip_opening_relic_draft=True)
    st.relics.extend([RelicId.CAPACITOR, RelicId.FIXED_OVERDRAFT])
    start_first_turn(st)
    assert st.energy == 7


def test_calendar_buffer_delays_phase1_fail_to_turn4_end():
    st = bootstrap_state(seed=3, skip_opening_relic_draft=True)
    st.relics.append(RelicId.CALENDAR_BUFFER)
    st.max_value_ever_seen = 0
    while st.turn < 3:
        apply_action(st, {"op": "end_turn"})
        assert not st.lost
    assert st.turn == 3
    apply_action(st, {"op": "end_turn"})
    assert not st.lost
    assert st.turn == 4
    apply_action(st, {"op": "end_turn"})
    assert st.lost
    assert "階段 1" in st.loss_reason


def test_scrap_reuse_adds_card_value_product_minus_one():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    st.relics.append(RelicId.SCRAP_REUSE)
    ones = [c for c in st.hand if c.value == 1]
    if len(ones) < 2:
        return
    err = apply_action(st, {"op": "merge", "ids": sorted([ones[0].cid, ones[1].cid])})
    assert err is None
    assert st.max_value_ever_seen >= 2
    assert sum(1 for c in st.discard if c.value == 1) >= 2


def test_merge_to_hand_keeps_product_in_hand():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    st.relics.append(RelicId.MERGE_TO_HAND)
    ones = [c for c in st.hand if c.value == 1]
    if len(ones) < 2:
        return
    a, b = ones[0], ones[1]
    h0 = len(st.hand)
    err = apply_action(st, {"op": "merge", "ids": sorted([a.cid, b.cid])})
    assert err is None
    assert len(st.hand) == h0 - 1
    assert any(c.value == 2 for c in st.hand)


def test_ash_tax_extra_draw_next_turn_after_exhaust():
    st = bootstrap_state(seed=2, skip_opening_relic_draft=True)
    st.relics.append(RelicId.ASH_TAX)
    c3 = Card(st._next_cid, 3)
    st._next_cid += 1
    st.hand.append(c3)
    err = apply_action(st, {"op": "play", "card_id": c3.cid, "payload": {}})
    assert err is None
    apply_action(st, {"op": "end_turn"})
    assert len(st.hand) == DRAW_PER_TURN + 1


def test_agent_apply_returns_observation_without_legal_actions():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    ones = [c for c in st.hand if c.value == 1]
    if len(ones) < 2:
        return
    out = io.StringIO()
    inp = io.StringIO("merge 1 1\n")
    run_agent_loop(st, inp=inp, out=out)
    line = out.getvalue().strip().split("\n")[-1]
    obj = json.loads(line)
    assert "legal_actions" not in obj
    assert "hand_summary" in obj["state"]
