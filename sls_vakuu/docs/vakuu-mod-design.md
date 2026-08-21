# Vakuu Player Mod — 設計研究

> 需求（2026-08-18 確認）：不是自訂角色，是改造玩家；保留角色頁與角色外觀，第一幕由 Vakuu 開局，取得全部遺物，並由瓦庫接管每一回合。

## 開局流程

```text
選擇任一原生角色
→ 角色原生起始遺物為空
→ 第一幕開局進入 Vakuu Ancient
→ 顯示瓦庫開場對話
→ 只有「接受」一個選項
→ 依序取得全部 10 件瓦庫遺物
→ 離開事件，進入第一幕地圖
```

第三幕 `Glory` 的 Ancient 池移除 Vakuu，因此同一局不會在第三幕再次出現瓦庫選項。共用 Ancient 池只有 Darv，不會繞過第三幕過濾。

## 瓦庫對話

使用原生 Vakuu Ancient 的背景、立繪與對話 UI。首次造訪顯示：

1. 醒來吧。你踏入這座尖塔，不是為了向涅奧乞求祝福。
2. 你想要力量？我會把我的一切都給你——榮耀、詛咒，以及每一份代價。
3. 你不必選擇。只有弱者才會在力量面前猶豫。
4. 把自己交給我，你就能變得和我一樣，令眾生畏懼。

其餘對話保留遊戲原生 `Vakuu.DefineDialogues()`：依 Ironclad、Silent、Defect、Regent、Necrobinder 及造訪次數分流，並支援繁中、簡中、英文原生本地化。

## 瓦庫全部 10 件遺物

| 遺物 | 效果 | 類型 |
| --- | --- | --- |
| Blood-Soaked Rose 血染玫瑰 | 每回合 +1 能量；拾取時牌組 +1 Enthralled | 正面+代價 |
| Fiddle 小提琴 | 回合開始多抽 2；你回合內不能抽牌 | 正面+限制 |
| Preserved Fog 醃製活霧 | 拾取時手動刪 3 張牌；牌組 +Folly | 代價 |
| Sere Talon 原初之爪 | 拾取時 +2 隨機詛咒、+3 Wishes | 代價 |
| Distinguished Cape 卓越斗篷 | 拾取時 -9 最大生命；+3 Apparitions | 代價 |
| Choices Paradox 選擇悖論 | 每場戰鬥開始：隨機 1/5 卡入手，附 Retain | 正面 |
| Music Box 音樂盒 | 每回合第一個攻擊牌：生成 Ethereal 複製 | 正面 |
| Lord's Parasol 領主陽傘 | 遇到商人立即獲得他賣的全部東西 | 特殊 |
| Jeweled Mask 寶石面具 | 每場戰鬥開始：抽牌堆隨機 Power 入手，本場免費 | 正面 |
| Vakuu Contract 瓦庫契約 | 每回合自動接管出牌；+1 能量 | 接管 |

`Vakuu Contract` 取代原生 `Whispering Earring`。所有負面效果保留；不在開局注入 `Whispering Earring`。

## 技術決策

- 五個角色的 `StartingRelics` getter 在新局回傳空清單；原生角色頁 `SelectCharacter` scope 仍提供各角色原生遺物供預覽，離開 scope 後立即恢復空清單。
- `RunManager.SetStartedWithNeowFlag` 的新局流程強制進入第一幕開局 Ancient；不重寫 `NGame` async state machine。
- `Overgrowth` 與 `Underdocks` 的 Ancient 池只回傳 Vakuu。
- `Glory` 的 Ancient 池過濾 Vakuu。
- Patch Vakuu 的 `GenerateInitialOptions()`，取消三個隨機遺物選項，建立一個「接受」選項。
- callback 以原生 `RelicCmd.Obtain(...)` 依序取得 10 件遺物。
- `PreservedFog` 在 `NRun`、overlay 與玩家選擇 UI 建立後才執行原生手動刪牌，不使用隨機刪牌、不使用測試 harness。
- 遺物發放失敗直接保留例外，不靜默補救或改用替代行為。

## 接管機制

`VakuuContract` 沿用 `WhisperingEarring.AfterAutoPrePlayPhaseEnteredLate` 的左至右自動出牌邏輯，移除第一回合限制，最多自動打出 13 張牌；牌打完後控制權歸還玩家。
