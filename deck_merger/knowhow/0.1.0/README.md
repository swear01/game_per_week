# Know-how：規則版本 0.1.0

此目錄對應 **deck_merger** 套件版本 `0.1.0`（見 `pyproject.toml` / `deck_merger.__version__`）。遊戲規則或平衡大改時請**升版套件**並新增 `knowhow/<新版本>/`，避免舊策略誤導。

## 檔案分工

| 檔案 | 用途 |
|------|------|
| `strategy.md` | 長線方針、里程碑優先級（人類或 LLM 維護） |
| `pitfalls.md` | 常見錯誤、能量／遺物陷阱 |
| `session_notes.md` | 局後反思追加（`llm_agent.py` 預設 append；`--no-learn` 關閉） |

可用環境變數 **`DECK_MERGER_KNOWHOW_VERSION`** 覆寫子目錄名稱（測試用）。**勿在此目錄存放 API key。**
