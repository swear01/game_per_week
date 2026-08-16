# Structure

| Path | Purpose |
|------|---------|
| `AGENTS.md` | Agent 規則（agents_rule 管理 block + 項目規則），`CLAUDE.md` 為 symlink |
| `RESEARCH.md` | **STS2 mod 開發研究筆記（權威來源）**：環境、技術棧、manifest 契約、Harmony、Workshop 上傳、agent sync 體系 |
| `docs/` | 項目狀態文件（overview/structure/notes/plan/roadmap） |
| `.skillshare/` | （已移除 — 本項目不用 skillshare 項目級 agent，改走 agents_rule 體系） |

## Module Boundaries
- `RESEARCH.md` = 外部技術事實（遊戲版本、API、工具鏈），變化時更新
- `docs/` = 本項目內部狀態（計劃、決策、踩坑）
- `AGENTS.md` 保持精簡：絕對規則 + 指針，長內容一律進 docs/ 或 RESEARCH.md
- 未來 mod 程式碼建議佈局：`src/`（C# 專案）→ `build/mods/<ModId>/`（暫存）→ 複製到遊戲 `mods/`
