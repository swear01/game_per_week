# Plan

## In Progress
- 研究階段完成 ✅（RESEARCH.md 已含：技術棧、manifest 契約、Hook/Harmony、Workshop 上傳、agent sync 體系）
- Repo agent 配置完成 ✅（agents_rule init + docs/ scaffold）
- 已確認 hapi Accessibility 正常；本地 VakuuPlayer 已重新啟用並成功載入
- 已定位 Preserved Fog 開局 NRE：`FinalizeStartingRelics` 發生在 `NRun.Create` 前，不能直接使用原版 overlay

## Preserved Fog 修正計畫
1. **移除目前的 `LocalCardSelectPatch`**：它只改選擇判斷，會在 `NOverlayStack.Instance` 尚未存在時觸發 NRE，且會影響所有單人卡牌選擇。
2. **加入開局協調器**：只在含 `VakuuContract` 的單人新 run 啟用；`PreservedFog.AfterObtained` 在 `FinalizeStartingRelics` 暫存 owner 並立即完成，不執行刪牌副作用。
3. **利用原生 `AfterActEntered` hook**：`RunManager.EnterAct` 的實際順序是 `NRun.Create` → `SetActInternal` → `Hook.AfterActEntered` → 第一張 map/room。讓 `VakuuContract.AfterActEntered()` await 協調器，避免 patch `NGame` 或 async state machine。
4. **在 hook 內執行暫存效果**：此時 `NOverlayStack.Instance`、`PlayerChoiceSynchronizer` 都已存在，呼叫原生 `CardSelectCmd.FromDeckForRemoval` 顯示手動選牌；等待玩家選滿 3 張後移除牌，再加入 Folly。若測試仍顯示 `LocalContext` 未就緒，只保留針對 pending owner 且確認 `NRun.Instance != null` 的窄 patch。
5. **保留失敗可見性**：新增階段 log；任何 UI/Task 例外直接讓 run 啟動失敗，不隨機刪牌、不靜默 fallback。
6. **實機驗證**：新 run → 手動刪 3 張 → 10 件遺物 → 第一場戰鬥每回合自動出牌；再測存檔載入、五角色與無 Preserved Fog 的回歸路徑。

## Verification Gate
- 先用一次性 harness 驗證 `AfterActEntered` 內原生 `NDeckCardSelectScreen` 可以顯示並完成選擇，再寫入正式 mod。
- 正式 mod 不保留 harness、不使用 `CardSelectCmd.UseSelector` 自動選牌。
