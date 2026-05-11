# deck_merger

終端機上的《數字合成 × 牌組構築》原型，規則見 [doc/企劃書.md](doc/企劃書.md)。

## 需求

- Python **3.14+**

## 安裝

在專案根目錄（本檔所在目錄）：

```bash
python3 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -e .
```

若要跑測試：

```bash
pip install -e ".[dev]"
pytest tests/ -v
```

未執行 `pip install -e .` 時，`tests/conftest.py` 仍會嘗試載入 `src/` 下的套件，但建議仍以 editable 安裝為準。

## 啟動遊戲

**人類模式**（與 `--agent`／LLM **同一套文字指令**；啟動時會印說明）：

```bash
python -m deck_merger
```

手牌顯示模式（預設疊加）：

```bash
python -m deck_merger --hand-display stacked   # 例：1×3, 2×2
python -m deck_merger --hand-display spread    # 例：1 1 1 2 2
```

若已安裝 entry point，也可：

```bash
deck-merger
```

**AI／腳本模式**（stdin **每行一則與人類相同之文字指令**；stdout 回傳精簡 `state` 觀測，**不含** `legal_actions`；啟動時先印一行含 `bootstrap: true` 的 JSON）：

```bash
python -m deck_merger --agent --seed 0
```

與人類一致可加 `--hand-display`，觀測中的 `hand_text`／`hand_display_mode` 會對應。

### 指令一覽（人類、`--agent`、`scripts/llm_agent.py` 相同）

| 指令 | 說明 |
|------|------|
| `merge v1 v2` | 二合一；`v1`、`v2` 為牌面數字，由左而右各取一張 |
| `merge v1 v2 v3` | 三合一（須規則允許，如遺物【1+1+1】） |
| `use L` | 發動牌面 **L** 之效果（無目標者如 **2**、**3**、**6**、**7**、**10**；細節見 `help cards`）；`L` 為 **1–9** 或 **10** |
| `use L T` | 需單一目標：**1**、**4**、**5**、**9**（`T` 為另一張手牌之牌面數字） |
| `use 8 T1 T2` | 牌面 **8**：`T1`、`T2` 為另兩張素材牌之牌面數字（左而右各取一張，與【8】合計三張） |
| `end` | 結束回合 |
| `relic 0` / `relic 1` | 遺物二選一 |
| `help` | （僅人類）說明 |

狀態欄位 **`max_value_ever_seen`**：介面說明為**歷史最大數字**（曾出現於手牌或棄牌堆等，見企劃書 §4.2）。

### 查詢合法步

需要完整列舉時，stdin 送一行純文字 **`all_actions`**，或 JSON **`{"op":"all_actions"}`**（不推進局面）。回應內含 `legal_actions`、可選 **`command_hints`**（每筆合法步對應一行建議文字指令）、以及當前觀測。

## 常用參數

| 參數 | 說明 |
|------|------|
| `--seed N` | 固定亂數種子，方便重現 |
| `--no-default-relics` | **略過開局遺物二選一**，零遺物直接開始第一回合（測試／腳本用） |
| `--agent` | 管道模式（文字指令 + 上述查詢） |
| `--hand-display stacked\|spread` | 手牌字串：疊加或分開 |

## 開局遺物二選一

新局預設先進入與里程碑相同的**遺物二選一**（選項僅自尚未持有池隨機），選定後才抽起手牌。若要略過（零遺物、立刻抽牌）請加 **`--no-default-relics`**。

## 階段獎勵（遺物二選一）

通過里程碑後觸發的**遺物二選一**，選項僅自**玩家尚未持有**的遺物池中隨機抽出，不會重複提供已擁有遺物。完整列表與設計意圖見 [企劃書 §6](doc/企劃書.md)。

## 外部 LLM 代理（LiteLLM）

以 **LiteLLM** 統一呼叫各家模型（Gemini、Groq、OpenRouter、Ollama 等），驅動腳本為 **`scripts/llm_agent.py`**。金鑰與模型**只放在專案根目錄 `.env`**（勿提交；已列於 `.gitignore`）。

1. 安裝 LLM 依賴：`pip install -e ".[llm]"`（或 `pip install -r requirements.txt` 一併含 dev）。
2. 複製範本：`cp .env.example .env`，編輯 **`DECK_MERGER_LLM_MODEL`** 與對應 provider 的 API key（鍵名見 [LiteLLM Providers](https://docs.litellm.ai/docs/providers)）。
3. 執行一局：

   ```bash
   python scripts/llm_agent.py --seed 0
   ```

   可加 **`--hand-display`**，與主程式一致。

4. **Know-how（依規則版本）**：策略筆記放在 **`knowhow/<套件版本>/`**（預設與 `deck_merger.__version__` 相同，例如 `knowhow/0.1.0/`）。每步會將該目錄下所有 `.md` 注入提示詞。可用 **`DECK_MERGER_KNOWHOW_VERSION`** 覆寫子目錄名。
5. **局後學習**：加上 **`--learn`** 或設定 **`DECK_MERGER_LEARN=1`**，局終會再呼叫模型並將 JSON 中的 `append_session_notes` **追加**到 `session_notes.md`（有長度上限）。

模型**每步應輸出一行文字指令**（與終端相同），或 `all_actions`／`{"op":"all_actions"}` 查詢合法步。系統提示詞：`scripts/prompts/deck_merger_agent_system.md`。Cursor 內可搭配專案 Skill **`.cursor/skills/deck-merger-ai/SKILL.md`**。

### 免費／低門檻 API（額度以各站為準）

| 服務 | 說明 |
|------|------|
| [Google AI Studio（Gemini）](https://aistudio.google.com/) | 常見免費額度，適合原型 |
| [Groq](https://console.groq.com/) | 速度快，有免費層 |
| [OpenRouter](https://openrouter.ai/) | 多模型聚合，部分標 `:free` |
| [Ollama](https://ollama.com/)（本機） | 無雲端 key；LiteLLM 可對本機 OpenAI 相容埠 |

## 專案結構（摘要）

- `src/`：套件原始碼（安裝後匯入名稱仍為 `deck_merger`）
- `doc/`：企劃書與里程碑
- `knowhow/`：版本化策略筆記（供 LLM 代理讀取／可選局後追加）
- `scripts/`：`llm_agent.py`、prompt 模板
- `tests/`：`pytest`
