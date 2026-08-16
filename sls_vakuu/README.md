# VakuuPlayer — 瓦庫玩家

> 你不再是一般的爬塔者——你是第一個惡魔**瓦庫（Vakuu）**。連涅奧都換上了瓦庫的契約之語。

Slay the Spire 2 mod：玩家開局獲得瓦庫全部 10 件遺物（含負面效果），瓦庫接管每一回合自動打牌。

## 功能

- **開局全部瓦庫遺物**：低語耳環由「瓦庫契約」取代（每回合接管 +1 能量），另含血染玫瑰、小提琴、寶石面具、音樂盒、選擇悖論、醃製活霧、原初之爪、卓越斗篷、領主陽傘
- **每回合接管**：瓦庫從左到右自動打牌（沿用低語耳環原始邏輯），直到無牌可打、能量耗盡或打滿 13 張；打完後控制權歸還，之後才能使用藥水等
- **涅奧台詞**：開局對話顯示涅奧，但說的是瓦庫的契約之語（「把你自己交給我，你就能變得和我一樣萬眾畏懼」）
- 選角色頁面保持原樣

## 安裝

**Steam Workshop**：搜尋「Vakuu Player 瓦庫玩家」訂閱（[連結](https://steamcommunity.com/sharedfiles/filedetails/?id=3784362897)）。

**本地安裝（開發用）**：複製 `deploy/VakuuPlayer/` 到遊戲 mods 目錄：
- macOS：`SlayTheSpire2.app/Contents/MacOS/mods/VakuuPlayer/`
- Windows/Linux：`<遊戲目錄>/mods/VakuuPlayer/`

## 開發

- 遊戲版本基線：v0.111.0（net9.0，引用遊戲自帶 `sts2.dll`/`0Harmony.dll`/`GodotSharp.dll`）
- 建置：`dotnet build -c Release src/VakuuPlayer/`
- 一鍵測試：`./test.sh`（build → 部署到本地 mods → 重啟遊戲）
- 完整研究筆記：`RESEARCH.md`；測試手冊：`docs/testing.md`

## 結構

```
src/VakuuPlayer/          mod 原始碼
  Relics/VakuuContract.cs   瓦庫契約（每回合接管）
  Patches/                  開局遺物、涅奧台詞覆蓋
tools/                     pck 解包器 / 反編譯器 / IL dump / Workshop 訂閱工具
deploy/VakuuPlayer/       Workshop 部署工作區（ModUploader）
docs/                      設計、測試、狀態
```

## 授權

MIT
