# Vakuu Player Mod — 設計研究

> 需求（2026-08-16 用戶確認）：不是自訂角色，是**改造玩家** —
> ① 玩家貼圖變瓦庫 ② 開局拿到所有瓦庫遺物 ③ 瓦庫接管玩家每一回合

## 瓦庫 Vakuu — The First Demon（第一個惡魔）

- 類型：**Ancient（先古之民）**，出現在第三幕 The Glory 開頭（4 個 Ancient 之一）
- 台詞：「Give yourself to me and you will be feared as much as I.」
- 個性：傲慢契約惡魔，稱鐵衛為「傀儡之傀儡」，喜歡操控

## 瓦庫全部 10 件開局遺物（瓦庫契約取代低語耳環）

| 遺物 | 效果 | 類型 |
| --- | --- | --- |
| Vakuu's Contract 瓦庫契約（取代 Whispering Earring 低語耳環） | 每回合 +1 能量；**瓦庫在每一回合替你出牌**（左→右自動出牌直到沒牌/沒能量/13 張，之後控制權回到玩家） | 正面 |
| Blood-Soaked Rose 血染玫瑰 | 每回合 +1 能量；拾取時牌組 +1 Enthralled | 正面+代價 |
| Fiddle 小提琴 | 回合開始多抽 2；**你回合內不能抽牌** | 正面+限制 |
| Jeweled Mask 寶石面具 | 每場戰鬥開始：抽牌堆隨機 Power 入手，本場免費 | 正面 |
| Music Box 音樂盒 | 每回合第一個攻擊牌：生成 Ethereal 複製 | 正面 |
| Choices Paradox 選擇悖論 | 每場戰鬥開始：隨機 1/5 卡入手，附 Retain | 正面 |
| Preserved Fog 醃製活霧 | 拾取時刪 3 張牌；牌組 +Folly | 代價 |
| Sere Talon 原初之爪 | 拾取時 +2 隨機詛咒、+3 Wishes | 代價 |
| Distinguished Cape 卓越斗篷 | 拾取時 -9 最大生命；+3 Apparitions | 代價 |
| Lord's Parasol 領主陽傘 | 遇到商人立即獲得他賣的全部東西 | 特殊 |

**開局全拿的淨效果**：+2 能量/回合、多抽 2（但回合內不能抽）、瓦庫契約每回合接管、每戰鬥隨機 Power 免費+隨機卡 Retain、攻擊複製、-9 血、+2 詛咒、+1 Enthralled、+3 Wish、+3 Apparitions、+Folly、商人白嫖。

## 設計決策（2026-08-16 用戶確認）
- ✅ **遺物全拿，含負面效果**（-9 血、+2 詛咒、+3 Wish、+1 Enthralled、+Folly 全要）
- ✅ **每回合接管**：沿襲低語耳環原始邏輯 — 瓦庫從左到右自動打牌，直到沒牌/沒能量/打滿 13 張
- ✅ **藥水時機**：瓦庫打完牌、控制權還給玩家後，玩家才能用藥水等剩餘操作（與原遺物一致）
- 接管順序/終止條件/控制權歸還：全部沿用 WhisperingEarring 原始實作，只把「第一回合」改為「每回合」

> 注意：下方提到低語耳環「第一回合」是原版行為；本模組以瓦庫契約取代它，實際上每一回合接管，且自動出牌完成後控制權回到玩家。

## 技術方案（三部分）

### A. 玩家貼圖 → 瓦庫（外觀）
- **先例**：WatcherBeautified = 純 pck 覆蓋資源路徑（GDPC v3，Godot 4.5.x）；AnimeWaifuSilent = pck + dll
- 做法：解包遊戲 `SlayTheSpire2.pck`（godotpcktool）→ 找 ① 玩家角色戰鬥立繪/卡圖資源路徑 ② 瓦庫貼圖路徑 → mod pck 以同名路徑覆蓋（mod pck 載入優先），或 Harmony patch 資源路徑
- 需確認：各角色（Ironclad/Silent/Defect/Regent/Necrobinder）的外觀資源結構，瓦庫資源能否直接複用（尺寸/圖集格式）
- `affects_gameplay: false` 屬外觀層；但本 mod 整體改玩法 → `true`

### B. 開局給全部瓦庫遺物
- 需反編譯 `sts2.dll` 確認：角色起始遺物機制、Neow 起手流程、RelicPool
- 可能路線：BaseLib 起始遺物 API → Harmony patch 開局邏輯注入 10 件
- 注意拾取時副作用（刪牌/塞牌/掉血）都會觸發

### C. 瓦庫接管每一回合
- 現成機制：WhisperingEarring（第一回合接管）— 左→右自動打牌，直到沒牌/沒能量/13 張後還控制權
- 改法：反編譯找 WhisperingEarring 實作 → Harmony patch 把「僅第一回合」改成「每回合開始都接管」；或獨立 hook 每回合開始複製其邏輯
- 設計問題：玩家是完全旁觀（純自動）還是可干預？接管順序規則沿用原遺物邏輯

### 貼圖研究結果（2026-08-16，pck 解包確認）
- **玩家角色 = Spine 骨骼動畫**：`animations/characters/<角色>/<角色>.skel + .atlas + .png`（ironclad/silent/defect/regent/necrobinder）
- **瓦庫沒有 Spine 資源**，只有：
  - `images/ancients/vakuu_placeholder.png`（2560×1200 大立繪，事件背景 `scenes/events/background_scenes/vakuu.tscn` 用它）
  - `images/ui/run_history/vakuu.png`（85×85 小頭像，LA8）
  - `images/packed/map/ancients/ancient_node_vakuu.png`（地圖圖示）
  - `images/relics/vakuus_cape.png`（遺物圖）
- 原始 png 不在 pck 內（Godot export 只存 `.ctex` 壓縮紋理，GST2 格式）
- 貼圖方案候選：
  - A. 玩家角色節點 → 瓦庫大立繪（靜態圖代替 Spine 動畫，需 patch 角色載入）
  - B. 替換 Spine atlas 貼圖（骨骼動作套瓦庫圖，效果差）
  - C. 只換肖像/HUD 頭像（最簡單）
- 待反編譯 `sts2.dll` 確認：角色載入點、WhisperingEarring 實作、起始遺物流程

### 反編譯研究結果（2026-08-16，sts2.dll v0.111.0 實測）

**接管機制（完整）**：`MegaCrit.Sts2.Core.Models.Relics.WhisperingEarring`
- `AfterAutoPrePlayPhaseEnteredLate(PlayerChoiceContext, Player)` override — 遊戲每回合經過 AutoPrePlayPhase（Late）時調用所有遺物此方法
- 接管條件：`Owner.PlayerCombatState.TurnNumber <= 1` ← **只接管第一回合的開關**
- 流程：`CardSelectCmd.PushSelector(new VakuuCardSelector())`（左→右 row-major 選牌）→ 循環：<13 張 && 戰鬥未結束 && 玩家未按結束回合 && 仍同回合 → 手牌取 `CanPlay()` 的牌 → `GetTarget`（敵人=最左，友方=隨機）→ `card.SpendResources()` → `CardCmd.AutoPlay(choiceContext, card, target, AutoPlayType.Default, true, false)`
- 打完 TalkCmd 台詞（approval/warning）
- 藥水限制：PushSelector 期間玩家不能操作，天然滿足「瓦庫打完才能用藥水」
- **每回合接管改法：Harmony Transpiler patch 把 `TurnNumber <= 1` 比較改為恆真**（或改成 `TurnNumber >= 0`）

**開局遺物**：`MegaCrit.Sts2.Core.Models.Characters.<角色> : CharacterModel`，`StartingRelics` getter（如 Ironclad → BurningBlood）；消費點 `RunManager.FinalizeStartingRelics()`（角色選擇流程中）
- 改法：patch 各角色 `StartingRelics` getter（Postfix 追加瓦庫 10 件）或 hook FinalizeStartingRelics
- 10 件遺物類名確認：`WhisperingEarring` `BloodSoakedRose` `Fiddle` `PreservedFog` `SereTalon` `DistinguishedCape` `ChoicesParadox` `MusicBox` `LordsParasol` `JeweledMask`（全在 `MegaCrit.Sts2.Core.Models.Relics`）

**貼圖（未完成）**：玩家 = Spine（`MegaCrit.Sts2.Core.Bindings.MegaSpine`），角色類在 `Models.Characters`；瓦庫無 Spine。替換方案 A/C 的具體載入點待查（角色顯示節點實例化位置）

## 測試記錄（2026-08-16）
- ✅ **正解：macOS 本地 mods 目錄 = `SlayTheSpire2.app/Contents/MacOS/mods/`**（遊戲根目錄 `mods/` 是錯的）— 已驗證：本地版號高於 Workshop 版時遊戲自動停用 Workshop 版
- ✅ 迭代：`./test.sh`（build → 複製 → 重啟），零上傳
- Workshop ID：`3784362897`（發佈用；開發不再需要）

## 已建立工具鏈（本 repo `tools/`）
- `pcktool/` — 自寫 Godot pck 解包器（v3 格式，自動掃尾找目錄；用法 `list <pck> <filter>` / `extract <pck> <out> <filter>`）
- `decomp/` — 基於 ILSpy 庫的類型反編譯器（`decomp <dll> <typeFilter>`）
- 外部：`~/.dotnet`（.NET 9.0.317，brew cask 需 sudo 改用官方 installer）、`~/.local/tools/ilspy`（ILSpy GUI 包內庫）

## 下一步（需工具）
1. `brew install dotnet-sdk`（編譯必需）
2. 拿 godotpcktool（遊戲 `tools/` 或 GitHub）解包遊戲 pck，收集瓦庫 + 玩家資源路徑
3. ILSpy / STS2 Modding MCP 反編譯 `sts2.dll`：WhisperingEarring 實作、起始遺物流程、角色外觀載入
4. 用 Alchyr/ModTemplate-StS2 或裸 csproj 起專案
