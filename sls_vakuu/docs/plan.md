# Plan

## Completed
- 研究階段完成 ✅（RESEARCH.md 已含：技術棧、manifest 契約、Hook/Harmony、Workshop 上傳、agent sync 體系）
- Repo agent 配置完成 ✅（agents_rule init + docs/ scaffold）
- 已確認 hapi Accessibility 正常；本地 VakuuPlayer 已重新啟用並成功載入
- Preserved Fog 開局 NRE 已修正：`FinalizeStartingRelics` 發生在 `NRun.Create` 前，正式 mod 改由 `AfterActEntered` 協調原版 overlay

## Preserved Fog 修正（已完成；保留設計記錄）
1. **移除目前的 `LocalCardSelectPatch`**：它只改選擇判斷，會在 `NOverlayStack.Instance` 尚未存在時觸發 NRE，且會影響所有單人卡牌選擇。
2. **加入開局協調器**：只在含 `VakuuContract` 的單人新 run 啟用；`PreservedFog.AfterObtained` 暫存當下可移除牌組 snapshot 並立即完成，不執行刪牌副作用。
3. **利用原生 `AfterActEntered` hook**：`RunManager.EnterAct` 會在 `NRun.Create` 後初始化第一個 map/room、觸發 `ActEntered`、淡入，再 await `Hook.AfterActEntered`。讓 `VakuuContract.AfterActEntered()` await 協調器，避免 patch `NGame` 或 async state machine。
4. **在 hook 內執行暫存效果**：此時 `NOverlayStack.Instance`、`PlayerChoiceSynchronizer` 都已存在；用 snapshot filter 呼叫原生選牌 UI，避免 SereTalon/DistinguishedCape 後續加入的牌被 Preserved Fog 選到。等待玩家選滿 3 張後移除牌，再加入 Folly；若 map 已開啟，暫時關閉選牌後恢復。
5. **保留失敗可見性**：新增階段 log；任何 UI/Task 例外直接讓 run 啟動失敗，不隨機刪牌、不靜默 fallback。
6. **實機驗證**：新 run → 手動刪 3 張 → 10 件遺物 → 第一、第二回合及後續每回合自動出牌且控制權回到玩家，這些核心流程已完成；五角色存檔／讀檔仍是獨立的未完成回歸項目。

## Jupyter 實機驗證狀態（核心流程已完成）
- 已通過（2026-08-20）：Jupyter-compatible runner 在正常 Workshop／本機模組環境成功完成開局、Preserved Fog 手動刪 3 張、第一場實際戰鬥與第三幕指令流程。
- 已通過：10 件 Vakuu 遺物全部存在；實機總遺物為 11 件，另包含 Ironclad 原生 `BurningBlood`，本輪沒有移除角色原生遺物。
- 已通過：`auto_phase_turns=[1, 2]`、`auto_play_turns=[1, 2]`、自動出牌 9 張；第一回合結束指令成功送出，證明自動階段後控制權可回到玩家。
- 已產生並提交 5 張遊戲視窗截圖至 `assets/screenshots/`。
- Main-line audit（2026-08-21，基線 `c7a6568`）：
  - 五角色開局遺物覆蓋已靜態確認：`StartingRelicsPatch` 對 Ironclad、Silent、Defect、Regent、Necrobinder 都有精確 getter patch；deploy DLL 已用本次 Release build 重新整理，並以 IL dump 確認五個 nested `Postfix` 存在。
  - 五角色存檔／讀檔回歸仍未完成：既有 harness 只跑預設 Ironclad 新局，沒有逐角色 Save/Load marker；本次未啟動遊戲、未碰使用者 save，因此沒有把靜態結果當成實機通過。
  - Workshop「首次上傳」並非未完成：git history 的 `52f2f75`／`c6c442b` 已建立並更新 item `3784362897`。本次整合版 deploy manifest 為 v0.1.8，已由 ModUploader 完成更新；回傳 log 與 ISteam RemoteStorage 查詢均確認 exact payload。
- Opening Ancient integration（2026-08-21）：第一幕固定 Vakuu、第三幕過濾 Vakuu、單一 Accept 取得 10 件遺物、原生角色頁預覽與 VakuuContract 本地化已合併至 main；使用者已手動確認整合後實機行為。
- Release integration（2026-08-21）：合併 origin/main 的 v0.1.7 release hardening、Workshop metadata、截圖與測試工具；整合版 manifest 更新為 v0.1.8。
- Workshop 3784362897：已由 ModUploader 上傳 v0.1.8；回傳 log 顯示成功，ISteam RemoteStorage 查詢確認 title、description、public visibility 與 42882-byte payload。
- Workshop image refresh（2026-08-22）：使用者提供的四張 Steam F12 截圖已整理為 opening、ten relics、Act 1 map、auto-play 四張附加圖；新 512×512 宣傳主圖已上傳，遠端主圖 hash 與本地 payload 一致。
- 觀察：第三幕 `Glory.AllAncients` 已加入 Vakuu 過濾；舊存檔已生成的第三幕房間不會重新生成。

## 收尾結論
- v0.1.8 的實作、Release deploy、Workshop metadata、主圖與四張預覽圖均已完成並驗證。
- 正式 mod 沒有已知待補的 production-code TODO。
- 唯一保留的驗證缺口是五個角色各自的獨立 Save/Load 實機回歸；它不阻擋目前已發布的 v0.1.8，但在未測前不宣稱完整回歸通過。

## Verification Gate
- 一次性 harness 已驗證 `AfterActEntered` 內原生 `NDeckCardSelectScreen` 顯示並完成選擇；正式 mod 不保留 harness、不使用 `CardSelectCmd.UseSelector` 自動選牌。
