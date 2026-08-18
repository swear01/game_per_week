# VakuuPlayer 測試手冊

> 正確的 STS2 mod 測試方法（2026-08-16 驗證）。詳細生態參考：`RESEARCH.md` §10.5。

## 快速迭代循環（本地，零上傳）

```bash
./test.sh   # build → 複製到 MacOS/mods/VakuuPlayer → 重啟遊戲
```

- 本地 mods 目錄（macOS）：`<遊戲>/SlayTheSpire2.app/Contents/MacOS/mods/<ModId>/`
- 本地版號 > Workshop 版號時，遊戲自動停用 Workshop 版、載入本地版
- 只改 .cs → 只 build；改資源/本地化/場景 → 需 Godot Publish（打包 pck）
- 關遊戲再替換 dll/pck；mod 首次載入用獨立 save（不影響主進度）

## 驗證清單（每次迭代）

1. **初始化**：`~/Library/Application Support/SlayTheSpire2/logs/godot.log` 搜 `VakuuPlayer`
   - 期望：`Loading assembly DLL` → `Calling initializer` → `Finished mod initialization`，無 ERROR
2. **遊戲內**（用戶操作）：
   - 角色選擇：所有角色名顯示「瓦庫」
   - 開局對話：涅奧顯示、說瓦庫契約之語
   - 遺物欄：10 件瓦庫遺物（含負面效果）
   - 第一場戰鬥：每回合瓦庫左→右自動打牌（≤13 張），打完才能用藥水/結束回合
3. **回歸**：遊戲更新後跑：載入偵測 → 新 run → 各內容類型 → hover/圖鑑 → 存檔讀檔 → 事件 → GUI

## 遊戲內調試

- **開發者控制台**（mods 啟用後）：按 `` ` `` / `~` / `*` / `'` / `Shift+8`；`help`、`help card` 等
  - 可即時生成卡牌/遺物/敵人測試，`help` 看全部命令
- **BaseLib**：`showlog`（開 log 視窗）、`open logs`（開 log 目錄）
  - BaseLib 設定：Mod Configuration → BaseLib → "Open log window on startup"
- **KitLib**（建議訂閱）：測試 run（seed）、遊戲內左緣面板改卡牌/狀態、log viewer、unlock all、pseudo co-op


## 開一局的正確流程

### 手動（最穩）
1. 從 Steam 啟動遊戲並等主選單完全出現
2. `Singleplayer` → 若先進入單人子選單，選 `New Run`/開始新局
3. 角色選擇頁選任一角色（瓦庫尖塔目前不改角色頁）
4. 按 `Embark`
5. 開局 Preserved Fog 會顯示**手動選牌畫面**：選 3 張要刪的牌，再繼續
6. 進第一場戰鬥：確認瓦庫契約自動從左到右出牌

### 程式化（瓦庫研究的原生 API 路徑）
遊戲自己的流程是：

```text
NMainMenu.OpenSingleplayerSubmenu()                 // public
→ NSingleplayerSubmenu.OpenCharacterSelect()       // private，透過原生按鈕呼叫
→ NCharacterSelectScreen.InitializeSingleplayer()   // public，建立 StartRunLobby
→ StartRunLobby.BeginRunLocally(seed, modifiers)    // private，產生 acts 並通知畫面開始
→ NCharacterSelectScreen.BeginRun(...)
→ NGame.StartNewSingleplayerRun(...)
```

不要直接只呼叫 `NGame.StartNewSingleplayerRun`：它需要已建立的 lobby、角色、acts、settings 和 preload 狀態；跳過這些會造成黑屏或 run 初始化例外。臨時 harness 已成功走到 `Embarking on a singleplayer IRONCLAD run`，但 Preserved Fog 的手動 UI 仍未能在原版開局階段建立；harness 已移除，不留在正式 mod。

### 權限與實機診斷
瓦庫之前把新開的 Swift 子程序回報的 `AXIsProcessTrusted=false` 誤當成 hapi 狀態。這個 API 只檢查**呼叫它的當前 executable**，不能代表父程序 hapi。實際檢查 macOS system TCC DB 得到：

```text
kTCCServiceAccessibility
/Users/swear/.local/bin/hapi
auth_value=2 (允許)
```

目前真正阻止測試的是遊戲設定中的兩筆 `VakuuPlayer` 都曾是 `is_enabled=false`，不是 Accessibility。把 `mods_directory` 的本地 VakuuPlayer 設為 true 後，log 已確認 `Calling initializer` → `Finished mod initialization`。`osascript` 仍未獲輔助取用，那是子程序自己的 TCC 身份，與 hapi 授權不同。

## 失敗診斷案例：Preserved Fog

開局直接給 Preserved Fog 時，原版 `AfterObtained` 呼叫 `CardSelectCmd.FromDeckForRemoval`。開局階段 `LocalContext.IsMe` 尚未就緒，`ShouldSelectLocalCard` 錯走 `WaitForRemoteChoice`，單人會報：

```text
Cannot wait for remote choice in singleplayer!
```

原先只做 `LocalCardSelectPatch`（單人模式強制 `ShouldSelectLocalCard=true`）仍不夠：`FromDeckGeneric` 會在 `RunManager.FinalizeStartingRelics` 期間呼叫 `NOverlayStack.Instance`，但 `NOverlayStack.Instance` 依賴尚未建立的 `NRun`，因此會得到 `NullReferenceException`。完整修正必須把 Preserved Fog 的手動選擇延後到 `NRun`/overlay stack 建立後，或提供不依賴 `NRun` 的開局選擇 UI；不應把原效果改成隨機刪牌。

## Log

- 主 log：`~/Library/Application Support/SlayTheSpire2/logs/godot.log`（最近一次啟動）
- mod 自訂 log：`FileLog.Log(...)`（Harmony）或遊戲 Logger
- 判斷順序：先確認載入層（manifest → dll → initializer）再測內容層，避免被舊證據誤導

## IDE 除錯（可選）

1. 遊戲目錄放 `steam_appid.txt`（內容 `2868840`）→ 直接啟動遊戲連 Steamworks
2. mod 的 `.pdb` 複製到 dll 旁 → Rider/VS 斷點
3. Godot：`--remote-debug tcp://127.0.0.1:6007` 接 editor console

## 多人本地測試（需要時）

```bash
"$GAME/.../MacOS/Slay the Spire 2" -fastmp host_standard &
"$GAME/.../MacOS/Slay the Spire 2" -fastmp join -clientId 1001 &
```
