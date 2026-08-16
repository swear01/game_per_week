# Vakuu Player Mod — 設計研究

> 需求（2026-08-16 用戶確認）：不是自訂角色，是**改造玩家** —
> ① 玩家貼圖變瓦庫 ② 開局拿到所有瓦庫遺物 ③ 瓦庫接管玩家每一回合

## 瓦庫 Vakuu — The First Demon（第一個惡魔）

- 類型：**Ancient（先古之民）**，出現在第三幕 The Glory 開頭（4 個 Ancient 之一）
- 台詞：「Give yourself to me and you will be feared as much as I.」
- 個性：傲慢契約惡魔，稱鐵衛為「傀儡之傀儡」，喜歡操控

## 瓦庫全部 10 件遺物（開局全給清單）

| 遺物 | 效果 | 類型 |
| --- | --- | --- |
| Whispering Earring 低語耳環 | 每回合 +1 能量；**Vakuu 打你的第一回合**（左→右自動出牌直到沒牌/沒能量/13 張） | 正面 |
| Blood-Soaked Rose 血染玫瑰 | 每回合 +1 能量；拾取時牌組 +1 Enthralled | 正面+代價 |
| Fiddle 小提琴 | 回合開始多抽 2；**你回合內不能抽牌** | 正面+限制 |
| Jeweled Mask 寶石面具 | 每場戰鬥開始：抽牌堆隨機 Power 入手，本場免費 | 正面 |
| Music Box 音樂盒 | 每回合第一個攻擊牌：生成 Ethereal 複製 | 正面 |
| Choices Paradox 選擇悖論 | 每場戰鬥開始：隨機 1/5 卡入手，附 Retain | 正面 |
| Preserved Fog 醃製活霧 | 拾取時刪 3 張牌；牌組 +Folly | 代價 |
| Sere Talon 原初之爪 | 拾取時 +2 隨機詛咒、+3 Wishes | 代價 |
| Distinguished Cape 卓越斗篷 | 拾取時 -9 最大生命；+3 Apparitions | 代價 |
| Lord's Parasol 領主陽傘 | 遇到商人立即獲得他賣的全部東西 | 特殊 |

**開局全拿的淨效果**：+2 能量/回合、多抽 2（但回合內不能抽）、首回合接管→改每回合、每戰鬥隨機 Power 免費+隨機卡 Retain、攻擊複製、-9 血、+2 詛咒、+1 Enthralled、+3 Wish、+3 Apparitions、+Folly、商人白嫖。

⚠️ 待用戶決策：全拿含負面嗎？還是只拿正面 6 件？

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

## 下一步（需工具）
1. `brew install dotnet-sdk`（編譯必需）
2. 拿 godotpcktool（遊戲 `tools/` 或 GitHub）解包遊戲 pck，收集瓦庫 + 玩家資源路徑
3. ILSpy / STS2 Modding MCP 反編譯 `sts2.dll`：WhisperingEarring 實作、起始遺物流程、角色外觀載入
4. 用 Alchyr/ModTemplate-StS2 或裸 csproj 起專案
