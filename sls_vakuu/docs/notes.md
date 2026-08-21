# Notes

> Tacit knowledge an agent can't infer from reading code.

## Gotchas
- **EA 版本漂移**: STS2 每 1–2 週更新，API 簽名常變。寫任何 patch 前先讀 `release_info.json` + `sts2.runtimeconfig.json` + 反編譯 `sts2.dll` 核對，不要憑記憶
- **skillshare project config 是陣列**: targets 用 `- name: xxx` 列表格式；照抄 global config 的 map 格式會報 `cannot unmarshal !!map`（已踩過，方案已棄用）
- **manifest 陷阱**: `<game>/mods/` 下所有 `.json` 都被當候選 manifest，別在 mods 樹裡放設定檔；manifest id = dll/pck 檔名基底
- **`affects_gameplay`**: 純外觀 mod 設 `false`，否則聯機會 desync；設錯會被檢查
- **不用 NuGet 版 Harmony/GodotSharp**: 必須引用遊戲目錄內的同版副本，版本混用能編過但運行時掛
- **pool 註冊時機**: `ModHelper.AddModelToPool` 必須在池凍結前，之後丟異常

## Verified gotchas
- **Accessibility 授權要查對 executable**：`AXIsProcessTrusted()` 只回報目前呼叫者；從 agent shell 開的 Swift helper 回 `false`，不能推論 launchd 的 `/Users/swear/.local/bin/hapi`。2026-08-18 查 system TCC DB 確認 hapi 的 `kTCCServiceAccessibility` `auth_value=2`。本次測試真正的阻礙是 STS2 `settings.save` 將 local/Workshop `VakuuPlayer` 的 `is_enabled` 都設成 `false`，不是 hapi 權限。
- **STS2 開局時 NRun 尚未建立**：`NGame.StartRun` 的順序是 preload → `RunManager.FinalizeStartingRelics()` → `RunManager.Launch()` → `NRun.Create(runState)`。因此 Preserved Fog 不可從角色 `StartingRelics` 直接取得；本 mod 改在第一幕 Vakuu callback、NRun 與原生 overlay 建立後使用 `RelicCmd.Obtain`。
- **Ancient 池來源**：第一幕的 `Overgrowth`／`Underdocks` 各自提供 Ancient 池，第三幕 `Glory` 另有自己的池，共用池目前只有 Darv。移除第三幕 Vakuu 只需過濾 `Glory.AllAncients`。
- **Vakuu 對話分流**：原生 `Vakuu.DefineDialogues()` 按 Ironclad、Silent、Defect、Regent、Necrobinder 及造訪次數建立對話；本 mod 只替換首次造訪開場，保留其他分流。
- **角色頁起始遺物契約**：原生 `NCharacterSelectScreen.SelectCharacter()` 直接讀取 `StartingRelics[0]` 顯示預覽；清空 getter 會讓角色頁 index exception。正式 patch 只在 `SelectCharacter` 呼叫期間保留原生 getter 結果，Finalizer 後仍回傳空清單，讓新局序列化與 `Player.PopulateStartingRelics()` 保持空遺物。
- **自製遺物本地化**：`VakuuContract` 沒有遊戲內 `relics` 表的既有 key；`LocTable.MergeWith()` 會直接新增字典項目，因此 `LoadTablesFromPath` 必須注入 `title`、`description`、`flavor`，否則取得遺物後的 hover／圖鑑會查到缺失 key。

## Decisions
- **2026-08-16 不使用 skillshare 項目級 agent（`.skillshare/agents/`）**：使用者有既有的 agent sync 體系 — repo 級指令寫 `AGENTS.md`（agents_rule 工具管理，已註冊 `~/.agents/managed-repos.txt`），全局 agent 指令走 `~/.agents/AGENTS.md`（`transfer_MAC/scripts/sync-ai-agent-configs.py render` 分發到 codex/claude/gemini/opencode）。不要再自創 agent 文件。
- **STS2 技術知識集中在 `RESEARCH.md` 單一文件**：避免 docs/ 與 RESEARCH.md 雙頭管理；docs/ 只記項目狀態
