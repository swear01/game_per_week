# Overview

## What This Is
Slay the Spire 2 (殺戮尖塔 2) 自製 mod 的開發工作區（每週遊戲開發專案）。目前處於**研究 + 環境準備**階段：完整的 mod 開發研究筆記在 `RESEARCH.md`（權威來源），本 docs/ 記錄項目狀態與方向。

## Key Concepts / Domain
- **遊戲**: STS2 Early Access **v0.111.0**（commit 41cef1ea, 2026-08-13），macOS arm64 安裝
- **Mod 形態**: C# (`net9.0`) DLL + 可選 Godot 4.5.x `.pck` 資源包 + JSON manifest
- **引用集**: 遊戲自帶 `sts2.dll` / `0Harmony.dll` / `GodotSharp.dll`（同一 data 目錄，`Private=false`），**不走 NuGet**
- **集成優先序**: 模型 override（`CardModel.OnPlay` 等，用 `CreatureCmd`/`CardPileCmd` 遊戲命令）→ 語義 Hook（`MegaCrit.Sts2.Core.Hooks.Hook`）→ Harmony patch（最後手段，精確 target）
- **入口**: `[ModInitializer]` + `ModHelper.AddModelToPool<T>()`（池凍結前註冊）
- **生態**: BaseLib（社區基礎庫）、ModTemplate-StS2（官方模板）、ModSmith（高層框架）
- **發布**: Steam Workshop，官方 `megacrit/sts2-mod-uploader`（v0.2.0，osx-arm64）

## External Resources
- 版本感知完整教程: fresh-milkshake/Modding-Tutorial（含卡/藥水/遺物/事件/GUI 章節）
- BaseLib: github.com/Alchyr/BaseLib-StS2 + BaseLib-Wiki
- 模板: github.com/Alchyr/ModTemplate-StS2
- ModSmith: github.com/cpimhoff/sts2_modsmith
- 上傳器: github.com/megacrit/sts2-mod-uploader
- AI 輔助: elliotttate/sts2-modding-mcp（反編譯/建置/部署/試玩）
- 本機遊戲路徑: `~/Library/Application Support/Steam/steamapps/common/Slay the Spire 2/`
