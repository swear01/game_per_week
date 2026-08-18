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
- mod 程式碼佈局：`src/VakuuPlayer/`（C# 專案）→ `build/mods/<ModId>/`（暫存）→ 複製到遊戲 `mods/`
- `Patches/VakuuActPatch.cs`：第一幕固定 Vakuu、第三幕移除 Vakuu、強制新局開局 Ancient
- `Patches/VakuuEventPatch.cs`：首次對話、單一接受選項、10 件遺物發放
- `Patches/LocOverridesPatch.cs`：Vakuu 開場與接受選項的繁中／簡中／英文文字
