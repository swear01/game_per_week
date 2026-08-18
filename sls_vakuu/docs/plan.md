# Plan

## 已完成

- 反編譯 v0.111.0 的 `Vakuu`、`AncientDialogueSet`、`EventOption`、`AncientEventModel`、`RelicCmd`、`RunManager`、各幕 Ancient 池。
- 確認第一幕 `Overgrowth`／`Underdocks` 原本只有 Neow；第三幕 `Glory` 原本包含 Vakuu；共用池只有 Darv。
- 確認 `RunManager.SetStartedWithNeowFlag` 是新局建立開局 Ancient 的切入點。
- 確認 `NRun` 與原生 overlay 建立後，Vakuu 事件 callback 才能安全取得 Preserved Fog。

## 本次實作

1. 五個角色的新局 `StartingRelics` 改為空清單；角色頁預覽 scope 保留原生遺物顯示，避免原生 UI 讀取空清單。
2. 第一幕 Ancient 固定為 Vakuu；第三幕 Ancient 池移除 Vakuu。
3. 新局強制走第一幕開局 Ancient 流程。
4. Vakuu 首次對話改為四句瓦庫契約台詞；其餘保留原生依角色與造訪次數分流。
5. Vakuu 初始選項改為唯一的「接受」。
6. 按下後使用 `RelicCmd.Obtain(...)` 依序取得全部 10 件遺物，`VakuuContract` 取代 `WhisperingEarring`。
7. 移除 Neow 對話覆蓋；保留原生 Vakuu 立繪、背景、事件 UI。
8. 不再使用 Preserved Fog 開局 startup defer；事件 callback 在 `NRun`／UI 建立後直接使用原生手動選牌。

## 驗證順序

- 先只執行 `dotnet build -c Release`，不部署、不重啟正在執行的遊戲。
- 使用者結束遊戲後，才部署本地 DLL 並啟動新局。
- 驗證：空遺物 → Vakuu 四句對話 → 單一接受 → 10 件遺物 → Preserved Fog 手動刪 3 張 → 第一場戰鬥每回合自動出牌。
- 回歸：五個角色、第三幕無 Vakuu、存檔載入、無 Preserved Fog 的新局。

## 風險

- 舊存檔中已生成的第三幕 Vakuu 房間不會被重新生成；第三幕過濾保證新局房間池不再提供 Vakuu。
- 目前不在使用者遊玩期間部署或重啟遊戲；實機驗證需等使用者通知。
