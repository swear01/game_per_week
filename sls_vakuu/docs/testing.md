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
