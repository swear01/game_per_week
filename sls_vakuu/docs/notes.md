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
- **STS2 開局時 NRun 尚未建立**：`NGame.StartRun` 的順序是 preload → `RunManager.FinalizeStartingRelics()` → `RunManager.Launch()` → `NRun.Create(runState)`。因此在 Preserved Fog 的 `AfterObtained` 中強制 `ShouldSelectLocalCard=true` 會讓 `CardSelectCmd.FromDeckGeneric` 取用尚未存在的 `NOverlayStack.Instance`，產生 NRE；單獨 patch 選擇判斷不足以建立開局 UI。
- **較小的正確延後點**：`RunManager.EnterAct` 在 `NRun.Create` 後完成第一個 map/room 初始化、觸發 `ActEntered`、淡入，再 await `Hook.AfterActEntered(runState)`；該 hook 逐一 await relic 的 `AfterActEntered()`。因此可讓 `VakuuContract.AfterActEntered()` 執行暫存的 Preserved Fog 選牌，避免重寫 `NGame` 開局流程或 patch async state machine。
- **Preserved Fog 必須保存牌組 snapshot**：目前起始遺物順序中 Preserved Fog 後面還有 SereTalon、DistinguishedCape，它們會新增詛咒/Apparitions。延後選牌若直接使用當時牌組，會讓後加入的牌變成可選；協調器必須在 `AfterObtained` 保存可移除卡片，之後用 `CardSelectCmd.FromDeckGeneric` 的 filter 限制候選。實機 log 已確認即使 VakuuContract 在起始清單最後，Preserved Fog 執行時 owner.Relics 已包含它。
- **STS2 語言與 LocTable 契約**：v0.111.0 的遊戲語言碼是三字母 `eng`/`zhs`/`zht` 等；`LocTable.MergeWith` 會直接寫入底層 dictionary，因此可插入原本不存在的 `VAKUU_CONTRACT.*` keys。未知語言目前明確記錄 English fallback。

## Decisions
- **2026-08-16 不使用 skillshare 項目級 agent（`.skillshare/agents/`）**：使用者有既有的 agent sync 體系 — repo 級指令寫 `AGENTS.md`（agents_rule 工具管理，已註冊 `~/.agents/managed-repos.txt`），全局 agent 指令走 `~/.agents/AGENTS.md`（`transfer_MAC/scripts/sync-ai-agent-configs.py render` 分發到 codex/claude/gemini/opencode）。不要再自創 agent 文件。
- **STS2 技術知識集中在 `RESEARCH.md` 單一文件**：避免 docs/ 與 RESEARCH.md 雙頭管理；docs/ 只記項目狀態
