# Notes

> Tacit knowledge an agent can't infer from reading code.

## Gotchas
- **EA 版本漂移**: STS2 每 1–2 週更新，API 簽名常變。寫任何 patch 前先讀 `release_info.json` + `sts2.runtimeconfig.json` + 反編譯 `sts2.dll` 核對，不要憑記憶
- **skillshare project config 是陣列**: targets 用 `- name: xxx` 列表格式；照抄 global config 的 map 格式會報 `cannot unmarshal !!map`（已踩過，方案已棄用）
- **manifest 陷阱**: `<game>/mods/` 下所有 `.json` 都被當候選 manifest，別在 mods 樹裡放設定檔；manifest id = dll/pck 檔名基底
- **`affects_gameplay`**: 純外觀 mod 設 `false`，否則聯機會 desync；設錯會被檢查
- **不用 NuGet 版 Harmony/GodotSharp**: 必須引用遊戲目錄內的同版副本，版本混用能編過但運行時掛
- **pool 註冊時機**: `ModHelper.AddModelToPool` 必須在池凍結前，之後丟異常

## Decisions
- **2026-08-16 不使用 skillshare 項目級 agent（`.skillshare/agents/`）**：使用者有既有的 agent sync 體系 — repo 級指令寫 `AGENTS.md`（agents_rule 工具管理，已註冊 `~/.agents/managed-repos.txt`），全局 agent 指令走 `~/.agents/AGENTS.md`（`transfer_MAC/scripts/sync-ai-agent-configs.py render` 分發到 codex/claude/gemini/opencode）。不要再自創 agent 文件。
- **STS2 技術知識集中在 `RESEARCH.md` 單一文件**：避免 docs/ 與 RESEARCH.md 雙頭管理；docs/ 只記項目狀態
