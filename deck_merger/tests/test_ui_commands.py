import pytest

from deck_merger.engine import apply_action, bootstrap_state
from deck_merger.state import Card
from deck_merger.ui_commands import parse_player_line, pick_cards_by_values


def test_parse_merge_two_by_value():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    ones = [c for c in st.hand if c.value == 1]
    if len(ones) < 2:
        pytest.skip("need two 1s")
    act = parse_player_line("merge 1 1", st)
    assert act["op"] == "merge"
    assert sorted(act["ids"]) == sorted([ones[0].cid, ones[1].cid])
    assert apply_action(st, act) is None


def test_pick_cards_insufficient_raises():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    st.hand.clear()
    st.hand.append(Card(900, 2))
    with pytest.raises(ValueError, match="沒有足夠"):
        pick_cards_by_values(st, [1, 1])


def test_parse_merge_wrong_arity():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    with pytest.raises(ValueError, match="merge"):
        parse_player_line("merge 1", st)


def test_parse_use_face_value_picks_leftmost():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    st.hand.clear()
    st.hand.extend([Card(10, 2), Card(8, 2)])
    act = parse_player_line("use 2", st)
    assert act == {"op": "play", "card_id": 10, "payload": {}}


def test_parse_use_ten():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    c10 = Card(9000, 10)
    st.hand.append(c10)
    act = parse_player_line("use 10", st)
    assert act == {"op": "play", "card_id": c10.cid, "payload": {}}


def test_parse_use_eight_two_targets():
    st = bootstrap_state(seed=0, skip_opening_relic_draft=True)
    st.hand.clear()
    c8 = Card(100, 8)
    a = Card(101, 1)
    b = Card(102, 2)
    st.hand.extend([c8, a, b])
    act = parse_player_line("use 8 1 2", st)
    assert act["op"] == "play"
    assert act["card_id"] == c8.cid
    assert act["payload"] == {"target_id": a.cid, "target_id_2": b.cid}
