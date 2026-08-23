# Plan

## Completed
- 研究階段完成 ✅（RESEARCH.md 已含：技術棧、manifest 契約、Hook/Harmony、Workshop 上傳、agent sync 體系）
- Repo agent 配置完成 ✅（agents_rule init + docs/ scaffold）
- 已確認 hapi Accessibility 正常；本地 VakuuPlayer 已重新啟用並成功載入
- Preserved Fog 開局 NRE 已修正：`FinalizeStartingRelics` 發生在 `NRun.Create` 前，正式 mod 改由 `AfterActEntered` 協調原版 overlay
- 五職業原生起始遺物已保留：移除舊 `StartingRelicsPatch`，10 件 Vakuu 遺物仍由第一幕 Ancient callback 另外取得
- v0.1.9 已發布：deploy DLL／三語 metadata 與新實機圖均已更新，明確呈現「原生起始遺物 + 10 件瓦庫遺物」

## Preserved Fog 修正（已完成；保留設計記錄）
1. **移除目前的 `LocalCardSelectPatch`**：它只改選擇判斷，會在 `NOverlayStack.Instance` 尚未存在時觸發 NRE，且會影響所有單人卡牌選擇。
2. **加入開局協調器**：只在含 `VakuuContract` 的單人新 run 啟用；`PreservedFog.AfterObtained` 暫存當下可移除牌組 snapshot 並立即完成，不執行刪牌副作用。
3. **利用原生 `AfterActEntered` hook**：`RunManager.EnterAct` 會在 `NRun.Create` 後初始化第一個 map/room、觸發 `ActEntered`、淡入，再 await `Hook.AfterActEntered`。讓 `VakuuContract.AfterActEntered()` await 協調器，避免 patch `NGame` 或 async state machine。
4. **在 hook 內執行暫存效果**：此時 `NOverlayStack.Instance`、`PlayerChoiceSynchronizer` 都已存在；用 snapshot filter 呼叫原生選牌 UI，避免 SereTalon/DistinguishedCape 後續加入的牌被 Preserved Fog 選到。等待玩家選滿 3 張後移除牌，再加入 Folly；若 map 已開啟，暫時關閉選牌後恢復。
5. **保留失敗可見性**：新增階段 log；任何 UI/Task 例外直接讓 run 啟動失敗，不隨機刪牌、不靜默 fallback。
6. **實機驗證**：新 run → 手動刪 3 張 → 10 件遺物 → 第一、第二回合及後續每回合自動出牌且控制權回到玩家，核心流程與自動回合已由使用者確認正常；不要求五角色逐一存檔／讀檔，因此不列為本版 release blocker。

## Jupyter 實機驗證狀態（核心流程已完成）
- 已通過（2026-08-24）：隔離模組的 runner 成功完成開局、Preserved Fog 手動刪 3 張、第一場實際戰鬥與第三幕指令流程。
- 已通過：事件前只含 Ironclad 原生 `BURNING_BLOOD`；Accept 後總數 11，包含原生遺物與 10 件 Vakuu 遺物。
- 已通過：`auto_phase_turns=[1, 2]`、`auto_play_turns=[1, 2]`、自動出牌 8 張；第一回合結束指令成功送出，證明自動階段後控制權可回到玩家。
- 已產生 4 張 Godot viewport 實機圖：原生起始遺物、Preserved Fog、原生＋Vakuu 遺物、自動出牌。
- Main-line audit（2026-08-21，基線 `c7a6568`；起始遺物項目由 2026-08-23 修正取代）：
  - 該基線仍包含五角色 getter 的 `StartingRelicsPatch`；2026-08-23 已移除，並以靜態回歸測試鎖定 production code 不得再攔截原生起始遺物。
  - 五角色逐一存檔／讀檔 marker 不在本次 scope：既有 harness 只跑預設 Ironclad 新局，本次也未碰使用者 save；使用者確認目前不需要逐角色回歸，因此不列為 v0.1.8 blocker。
  - Workshop「首次上傳」並非未完成：git history 的 `52f2f75`／`c6c442b` 已建立並更新 item `3784362897`。本次整合版 deploy manifest 為 v0.1.8，已由 ModUploader 完成更新；回傳 log 與 ISteam RemoteStorage 查詢均確認 exact payload。
- Opening Ancient integration（2026-08-21）：第一幕固定 Vakuu、第三幕過濾 Vakuu、單一 Accept 取得 10 件遺物、原生角色頁預覽與 VakuuContract 本地化已合併至 main；使用者已手動確認整合後實機行為。
- Release integration（2026-08-21）：合併 origin/main 的 v0.1.7 release hardening、Workshop metadata、截圖與測試工具；整合版 manifest 更新為 v0.1.8。
- Workshop 3784362897：已由 ModUploader 上傳 v0.1.8；回傳 log 顯示成功，ISteam RemoteStorage 查詢確認 title、description、public visibility 與 42882-byte payload。
- Workshop image refresh（2026-08-22）：使用者提供的四張 Steam F12 截圖已整理為 opening、ten relics、Act 1 map、auto-play 四張附加圖；新 512×512 宣傳主圖已上傳，遠端主圖 hash 與本地 payload 一致。
- Workshop v0.1.9（2026-08-24）：PR #13 合併後由 ModUploader 更新 item `3784362897`；Steam API 與 client 重新下載均確認 41,352-byte manifest `8288923953175858767`，訂閱內容為 v0.1.9，DLL SHA-256 與 deploy 完全相同。English、schinese、tchinese 描述均已加入保留原生起始遺物；遠端主圖與四張預覽的 SHA-256 集合也與本地一致。
- 觀察：第三幕 `Glory.AllAncients` 已加入 Vakuu 過濾；舊存檔已生成的第三幕房間不會重新生成。

## 收尾結論
- v0.1.9 的實作、Release deploy、三語 Workshop metadata、主圖與四張預覽圖均已完成並驗證。
- 正式 mod 沒有已知待補的 production-code TODO。
- 五個角色逐一 Save/Load 不在目前 scope；既有 serialization contract 靜態檢查已完成，使用者接受目前驗證範圍。
- 實機 harness 已確認原生遺物、10 件瓦庫遺物與自動接管流程；v0.1.9 沒有剩餘 release blocker，模組正式收尾。

## Verification Gate
- 一次性 harness 已驗證 `AfterActEntered` 內原生 `NDeckCardSelectScreen` 顯示並完成選擇；正式 mod 不保留 harness、不使用 `CardSelectCmd.UseSelector` 自動選牌。
- 2026-08-24 實機 log 已確認 Vakuu 事件前為 `relics=1 ids=BURNING_BLOOD`、接受後為 11 件遺物；本機 profile 前後 SHA-256 相同，Steam RemoteStorage 沒有遺留測試 `current_run.save`。
