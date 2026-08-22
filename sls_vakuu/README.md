# VakuuPlayer — 瓦庫玩家

> 你不再向涅奧祈求祝福。第一幕開局，瓦庫會把祂的一切交給你。

Slay the Spire 2 mod：玩家開局先進入 Vakuu Ancient，接受後取得全部 10 件瓦庫遺物（含負面效果），瓦庫接管玩家每一回合自動打牌。

## 功能

- **第一幕瓦庫開局**：第一幕開局 Ancient 固定為 Vakuu；第三幕 Ancient 池移除 Vakuu
- **一次接受全部遺物**：開局沒有角色原生遺物，對話結束後只有一個「接受」選項，依序取得全部 10 件遺物
- **Preserved Fog 手動選牌**：因遺物在 `NRun` 與原生 UI 建立後才取得，保留原生手動刪除 3 張牌並加入 Folly
- **角色專屬台詞**：沿用 Vakuu 原生依角色與造訪次數分流的對話；首次造訪使用瓦庫契約開場台詞
- **每回合接管**：瓦庫從左到右自動打牌（沿用低語耳環原始邏輯），直到無牌可打、能量耗盡或打滿 13 張；打完後控制權歸還
- 選角色頁面與角色外觀保持原樣

## 安裝

**Steam Workshop**：搜尋「Vakuu Player 瓦庫玩家」訂閱（[連結](https://steamcommunity.com/sharedfiles/filedetails/?id=3784362897)）。

**本地安裝（開發用）**：複製 `deploy/VakuuPlayer/` 到遊戲 mods 目錄：
- macOS：`SlayTheSpire2.app/Contents/MacOS/mods/VakuuPlayer/`
- Windows/Linux：`<遊戲目錄>/mods/VakuuPlayer/`

## 開發

- 遊戲版本基線：v0.111.0（net9.0，引用遊戲自帶 `sts2.dll`/`0Harmony.dll`/`GodotSharp.dll`）
- 建置：`PATH="$HOME/.dotnet:$PATH" dotnet build -c Release src/VakuuPlayer/`
- 一鍵測試：`./test.sh`（build → 部署到本地 mods → 重啟遊戲）
- 完整研究筆記：`RESEARCH.md`；測試手冊：`docs/testing.md`

## 結構

```
src/VakuuPlayer/           mod 原始碼
  Relics/VakuuContract.cs   瓦庫契約（每回合接管）
  Patches/                  開局 Ancient、遺物發放、本地化
 tools/                     pck 解包器 / 反編譯器 / IL dump / Workshop 訂閱工具
deploy/VakuuPlayer/         Workshop 部署工作區（ModUploader）
docs/                       設計、測試、狀態
```

## 授權

MIT
