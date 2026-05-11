"""玩家文字指令 → apply_action 用的 dict（人類與 --agent 共用）。"""

from __future__ import annotations

from typing import Any

from deck_merger.rules import WIN_PLAY_FACE_VALUE
from deck_merger.state import (
    PLAY_EFFECT_MAX_VALUE,
    PLAY_EFFECT_MIN_VALUE,
    Card,
    GameState,
    card_has_play_effect,
)


def pick_cards_by_values(state: GameState, values: list[int]) -> list[Card]:
    """依手牌左→右，為每個數字各取一張尚未使用的牌。"""
    used: set[int] = set()
    result: list[Card] = []
    for v in values:
        for c in state.hand:
            if c.cid in used:
                continue
            if c.value == v:
                result.append(c)
                used.add(c.cid)
                break
        else:
            raise ValueError(f"手牌沒有足夠的數字 {v}（或已用於本指令較前段）")
    return result


def parse_player_line(line: str, state: GameState) -> dict[str, Any]:
    raw = line.strip()
    if not raw:
        raise ValueError("空指令")
    parts = raw.split()
    cmd = parts[0].lower()

    if cmd == "merge":
        n = len(parts) - 1
        if n not in (2, 3):
            raise ValueError("用法: merge <數字> <數字>  或  merge <數字> <數字> <數字>")
        vals = [int(parts[i]) for i in range(1, len(parts))]
        cards = pick_cards_by_values(state, vals)
        if len(cards) == 2:
            return {"op": "merge", "ids": sorted([cards[0].cid, cards[1].cid])}
        return {"op": "merge3", "ids": sorted([c.cid for c in cards])}

    if cmd == "use":
        if len(parts) < 2:
            raise ValueError(
                "用法: use <牌面數字> …（牌面 1–9 或 10；見 help cards）"
            )
        lex_v = int(parts[1])
        lex_card: Card | None = None
        for c in state.hand:
            if c.value == lex_v:
                lex_card = c
                break
        if lex_card is None:
            raise ValueError(f"手牌沒有牌面為 {lex_v} 的牌")
        if not card_has_play_effect(lex_card):
            raise ValueError(
                f"use 僅支援牌面 {PLAY_EFFECT_MIN_VALUE}–{PLAY_EFFECT_MAX_VALUE} "
                f"或 {WIN_PLAY_FACE_VALUE}（輸入為 {lex_v}）"
            )
        if lex_v in (2, 3, 6, 7) or lex_v == WIN_PLAY_FACE_VALUE:
            if len(parts) != 2:
                raise ValueError("此牌面效果無需目標，用法: use <牌面數字>")
            return {"op": "play", "card_id": lex_card.cid, "payload": {}}
        if lex_v == 8:
            if len(parts) != 4:
                raise ValueError("用法: use 8 <目標數字> <目標數字>（消耗兩張手牌，與打出之【8】合計三張）")
            v1, v2 = int(parts[2]), int(parts[3])
            picked = pick_cards_by_values(state, [lex_v, v1, v2])
            return {
                "op": "play",
                "card_id": picked[0].cid,
                "payload": {
                    "target_id": picked[1].cid,
                    "target_id_2": picked[2].cid,
                },
            }
        if lex_v == 9:
            if len(parts) != 3:
                raise ValueError("用法: use 9 <目標數字>")
            tgt_v = int(parts[2])
            target: Card | None = None
            for c in state.hand:
                if c.cid == lex_card.cid:
                    continue
                if c.value == tgt_v:
                    target = c
                    break
            if target is None:
                raise ValueError(f"手牌沒有其他數字為 {tgt_v} 的牌可作目標")
            return {
                "op": "play",
                "card_id": lex_card.cid,
                "payload": {"target_id": target.cid},
            }
        if len(parts) != 3:
            raise ValueError("用法: use <牌面數字> <目標數字>")
        tgt_v = int(parts[2])
        target: Card | None = None
        for c in state.hand:
            if c.cid == lex_card.cid:
                continue
            if c.value == tgt_v:
                target = c
                break
        if target is None:
            raise ValueError(f"手牌沒有其他數字為 {tgt_v} 的牌可作目標")
        return {
            "op": "play",
            "card_id": lex_card.cid,
            "payload": {"target_id": target.cid},
        }

    if cmd in ("end", "done", "e"):
        if len(parts) != 1:
            raise ValueError("結束回合請只輸入 end")
        return {"op": "end_turn"}

    if cmd in ("relic", "pick"):
        if len(parts) != 2:
            raise ValueError("用法: relic 0  或  relic 1")
        idx = int(parts[1])
        if idx not in (0, 1):
            raise ValueError("遺物索引必須為 0 或 1")
        return {"op": "pick_relic", "index": idx}

    raise ValueError(f"未知指令 {cmd!r}，輸入 help 或 help cards 查看說明")


def player_help_text() -> str:
    return """指令（合成／發動效果皆以牌面數字為準，同數字由左而右各取一張）:
  merge <數字> <數字>           — 二合一
  merge <數字> <數字> <數字>     — 三合一（須有【1+1+1】遺物）
  use <牌面數字>                — 牌面 2、3、6、7、10 之效果（無目標；10 為打出即獲勝）
  use <牌面數字> <目標數字>     — 牌面 1、4、5、9（目標為另一張牌的數字）
  use 8 <數字> <數字>           — 牌面 8：再選兩張手牌（牌面數字）與【8】一併消耗，生成一張 9
  end                           — 結束回合
  relic 0 / relic 1             — 遺物二選一
查詢合法步（僅 --agent 等管道）: all_actions 或 {"op":"all_actions"}
其他: help（指令列表）| help cards（牌效果）| q 離開"""


def cards_help_text() -> str:
    return """【牌面效果速查】（牌面 1–9、10 可用 use；耗能見當下能量）

合成（merge）
  • 二合一：兩張同數字 → 棄牌區出現「數字+1」空白牌。
  • 三合一：三張同數字 → 「數字+2」（須持有遺物【1+1+1】）。
  • 放寬合成：持有遺物【墊腳石】時，可用相差 1 的兩張二合一，結果為較大數字。

牌面【1】  use 1 <目標數字>
  不耗能量：目標變成 1 點空白牌，並從抽牌堆補牌「變更前目標數字」張。

牌面【2】  use 2
  耗 1 能量：從抽牌堆抽 2 張；棄牌區多一張 1 點空白牌。

牌面【3】  use 3
  耗 0 能量：當回合能量 +2；棄牌區多兩張 1 點空白牌。

牌面【4】  use 4 <目標數字>
  耗 2 能量：目標與本牌皆從遊戲移除（消耗）。

牌面【5】  use 5 <目標數字>
  耗能＝目標數字：在手牌複製一張與目標相同牌面數字的牌。

牌面【6】  use 6
  耗 2 能量：棄牌堆頂端 2 張（實作取最後置入之 2 張）移入手牌；棄牌堆再置入 2 張牌面「3」空白牌。

牌面【7】  use 7
  耗 0 能量：當下手牌**全部**（含本牌）置入棄牌堆；再從抽牌堆抽**相同張數**。

牌面【8】  use 8 <目標數字> <目標數字>
  耗 2 能量：消耗打出之【8】與所選兩張手牌（永久移出本局）；在手牌生成一張牌面「9」空白牌。

牌面【9】  use 9 <目標數字>
  耗 1 能量：以目標之牌面數字，在抽牌堆**末尾**置入 9 張相同數字之新牌；本牌 Exhaust。

牌面【10】  use 10
  耗 0 能量：從手牌打出後立即獲勝（須於第 15 回合結束前達成）。

輸入 help 可看指令列表。"""


# 向後相容別名
parse_human_command = parse_player_line
human_help_text = player_help_text


def legal_action_to_command_hint(state: GameState, action: dict[str, Any]) -> str:
    op = action.get("op")
    if op == "end_turn":
        return "end"
    if op == "pick_relic":
        return f"relic {int(action['index'])}"
    if op == "merge":
        ids = [int(x) for x in action["ids"]]
        idset = set(ids)
        cards = [c for c in state.hand if c.cid in idset]
        vals = [str(c.value) for c in cards]
        return "merge " + " ".join(vals)
    if op == "merge3":
        ids = [int(x) for x in action["ids"]]
        idset = set(ids)
        cards = [c for c in state.hand if c.cid in idset]
        vals = [str(c.value) for c in cards]
        return "merge " + " ".join(vals)
    if op == "play":
        cid = int(action["card_id"])
        lex = next((c for c in state.hand if c.cid == cid), None)
        if lex is None:
            return f"play card_id={cid}"
        pl = action.get("payload") or {}
        tid = pl.get("target_id")
        tid2 = pl.get("target_id_2")
        if tid is None:
            return f"use {lex.value}"
        if tid2 is None:
            tgt = next((c for c in state.hand if c.cid == int(tid)), None)
            if tgt is None:
                return f"use {lex.value}"
            return f"use {lex.value} {tgt.value}"
        tgt1 = next((c for c in state.hand if c.cid == int(tid)), None)
        tgt2 = next((c for c in state.hand if c.cid == int(tid2)), None)
        if tgt1 is None or tgt2 is None:
            return f"use {lex.value}"
        return f"use {lex.value} {tgt1.value} {tgt2.value}"
    return str(action)
