---
name: deck-merger-ai
description: 以 LiteLLM 執行 deck_merger 的 scripts/llm_agent.py、設定 .env 與 knowhow 版本目錄；精簡 state 觀測與 all_actions 查詢。
---

# deck_merger 外部 LLM 代理

## 何時使用

- 要跑 **`python scripts/llm_agent.py`** 或幫使用者設定 **Gemini / Groq / OpenRouter / Ollama** 等模型。
- 要解釋 **精簡 `state` 觀測**、**`all_actions`**／**`{"op":"all_actions"}`** 查詢、**一行文字指令**、或 **knowhow** 如何影響提示詞。

## 前置

- Python **3.14+**；專案根執行 **`pip install -e ".[llm]"`**。
- **`cp .env.example .env`**，填入 **`DECK_MERGER_LLM_MODEL`**（LiteLLM 模型字串）與對應 **API key**（鍵名見 [LiteLLM Providers](https://docs.litellm.ai/docs/providers)）。**勿**把 `.env` 提交版控。

## 執行

```bash
python scripts/llm_agent.py --seed 0
python scripts/llm_agent.py --learn   # 局終追加 session_notes.md
```

可加 **`--hand-display stacked|spread`**，與 `python -m deck_merger` 一致。

輸出為每步一行 JSON（`applied`／`error` 等），最後一行 `done` 摘要。

## Know-how

- 目錄：**`knowhow/<RULES_VERSION>/`**，預設 **RULES_VERSION** = `deck_merger.__version__`（與 `pyproject.toml` 同步）。
- 覆寫：環境變數 **`DECK_MERGER_KNOWHOW_VERSION`**。
- 所有 **`*.md`** 會合併注入 system 提示（總長受 **`DECK_MERGER_KNOWHOW_MAX_CHARS`** 限制）。
- **只在 `session_notes.md` 做 append**（`--learn`）；**勿在 knowhow 內放 API key**。

## 決策要點（對齊 doc/企劃書.md）

- 每步使用者訊息為 **`observation_dict`**（含 `hand_summary`、**`hand_text`**、`hand_display_mode`；**無 `hand_slots`**），**不**預設附 `legal_actions`；需要列舉時模型輸出 **`all_actions`** 一行或 **`{"op":"all_actions"}`**，下一則 `hint` 會帶 **`command_hints`** 與 **`legal_actions`**。
- **一般步**：模型輸出與終端相同之**一行文字**（`merge`／`use`／`end`／`relic` 等，以數字選牌）；**不要**輸出含 id 的 JSON 動作。
- 合成素材與產物**全進棄牌堆**；`use` 發動效果之牌結算後 **Exhaust**。
- 階段死線：**第 3／6／10 回合末**檢核里程碑 **4／6／8**（曾持有）；勝利為手牌 **`use 10`** 打出牌面 10；**第 15 回合末**仍未勝則敗北。
- **`relic_offer_queue` 非空**時只能選 **`relic 0`／`relic 1`**；開局通常先有一次二選一。

## 除錯

- 缺模型或 key：腳本會提示複製 `.env.example`。
- 解析失敗：驅動會在 `hint` 提示改送**一行文字**或查詢 `all_actions`；檢查模型是否誤輸出 JSON 動作（已不支援）。
- Prompt 模板：**`scripts/prompts/deck_merger_agent_system.md`**、反思：**`deck_merger_reflect_system.md`**。
