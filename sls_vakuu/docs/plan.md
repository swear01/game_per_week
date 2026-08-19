# Plan

## In Progress
- 研究階段完成 ✅（RESEARCH.md 已含：技術棧、manifest 契約、Hook/Harmony、Workshop 上傳、agent sync 體系）
- Repo agent 配置完成 ✅（agents_rule init + docs/ scaffold）
- 已確認 hapi Accessibility 正常；本地 VakuuPlayer 已重新啟用並成功載入
- 已定位 Preserved Fog 開局 NRE：`FinalizeStartingRelics` 發生在 `NRun.Create` 前，不能直接使用原版 overlay

## Preserved Fog 修正計畫
1. **移除目前的 `LocalCardSelectPatch`**：它只改選擇判斷，會在 `NOverlayStack.Instance` 尚未存在時觸發 NRE，且會影響所有單人卡牌選擇。
2. **加入開局協調器**：只在含 `VakuuContract` 的單人新 run 啟用；`PreservedFog.AfterObtained` 暫存當下可移除牌組 snapshot 並立即完成，不執行刪牌副作用。
3. **利用原生 `AfterActEntered` hook**：`RunManager.EnterAct` 會在 `NRun.Create` 後初始化第一個 map/room、觸發 `ActEntered`、淡入，再 await `Hook.AfterActEntered`。讓 `VakuuContract.AfterActEntered()` await 協調器，避免 patch `NGame` 或 async state machine。
4. **在 hook 內執行暫存效果**：此時 `NOverlayStack.Instance`、`PlayerChoiceSynchronizer` 都已存在；用 snapshot filter 呼叫原生選牌 UI，避免 SereTalon/DistinguishedCape 後續加入的牌被 Preserved Fog 選到。等待玩家選滿 3 張後移除牌，再加入 Folly；若 map 已開啟，暫時關閉選牌後恢復。
5. **保留失敗可見性**：新增階段 log；任何 UI/Task 例外直接讓 run 啟動失敗，不隨機刪牌、不靜默 fallback。
6. **實機驗證**：新 run → 手動刪 3 張 → 10 件遺物 → 第一、第二回合及後續每回合自動出牌且控制權回到玩家；再測存檔載入、五角色與無 Preserved Fog 的回歸路徑。

## Verification Gate
- 一次性 harness 已驗證 `AfterActEntered` 內原生 `NDeckCardSelectScreen` 顯示並完成選擇；正式 mod 不保留 harness、不使用 `CardSelectCmd.UseSelector` 自動選牌。
